//
//  HealthKitDataService.swift
//  shoePrint
//
//  Created by Simon Naud on 11/04/2025.
//

import Foundation
import HealthKit
import Combine

/// High-level service for HealthKit data operations with iOS permission bug workaround
/// Provides a clean interface for fetching and processing health data
@MainActor
final class HealthKitDataService: ObservableObject {
    
    // MARK: - Properties
    
    private let healthStore = HKHealthStore()
    private let healthKitManager: HealthKitManager
    
    @Published var permissionStatus: HealthKitPermissionStatus = .notDetermined
    @Published var isLoading = false
    @Published var lastError: HealthKitError?
    
    // MARK: - Initialization
    
    init(healthKitManager: HealthKitManager) {
        self.healthKitManager = healthKitManager
        checkPermissionStatus()
    }
    
    // MARK: - Permission Management
    
    /// Checks current HealthKit permission status (iOS may report incorrect status)
    func checkPermissionStatus() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("❌ HealthKitDataService: HealthKit not available")
            permissionStatus = .denied
            return
        }
        
        let types = [HKQuantityType(.stepCount), HKQuantityType(.distanceWalkingRunning)]
        let statuses = types.map { healthStore.authorizationStatus(for: $0) }
        
        print("🔍 HealthKitDataService: Authorization statuses: \(statuses)")
        
        if statuses.allSatisfy({ $0 == .sharingAuthorized }) {
            permissionStatus = .authorized
        } else if statuses.contains(.notDetermined) {
            permissionStatus = .notDetermined
        } else {
            permissionStatus = .denied
        }
        
        print("  - Overall status: \(permissionStatus)")
    }
    
    /// Requests HealthKit permissions for step count and walking distance
    func requestPermissions() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }
        
        isLoading = true
        lastError = nil
        
        do {
            try await healthKitManager.requestPermissions()
            checkPermissionStatus()
        } catch {
            lastError = HealthKitError.queryFailed(error)
            throw error
        }
        
        isLoading = false
    }
    
    /// Force override permission status when real data access is detected
    func overridePermissionStatus(to status: HealthKitPermissionStatus) {
        print("🔓 HealthKitDataService: Overriding permission status to \(status)")
        permissionStatus = status
    }
    
    // MARK: - Data Fetching
    
    /// Fetches walking sessions for a specified date range
    func fetchWalkingSessions(config: HealthKitQueryConfig) async throws -> [WalkingSession] {
        print("📊 HealthKitDataService: Fetching walking sessions...")
        
        isLoading = true
        lastError = nil
        
        do {
            async let stepsData = fetchQuantityData(
                type: HKQuantityType(.stepCount),
                config: config,
                unit: .count()
            )
            async let distanceData = fetchQuantityData(
                type: HKQuantityType(.distanceWalkingRunning),
                config: config,
                unit: .meter()
            )
            
            let (steps, distances) = try await (stepsData, distanceData)
            
            print("📊 HealthKitDataService: Fetched \(steps.count) step entries, \(distances.count) distance entries")
            
            let sessions = createWalkingSessions(steps: steps, distances: distances)
            
            isLoading = false
            return sessions.filter { $0.isSignificant }
            
        } catch {
            isLoading = false
            print("❌ HealthKitDataService: Error fetching sessions: \(error)")
            let healthKitError = error as? HealthKitError ?? HealthKitError.queryFailed(error)
            lastError = healthKitError
            throw healthKitError
        }
    }
    
    /// Fetches aggregated health data summary for a period
    func fetchHealthDataSummary(config: HealthKitQueryConfig) async throws -> HealthDataSummary {
        let sessions = try await fetchWalkingSessions(config: config)
        
        return HealthDataSummary(
            startDate: config.startDate,
            endDate: config.endDate,
            totalSteps: sessions.reduce(0) { $0 + $1.totalSteps },
            totalDistance: sessions.reduce(0) { $0 + $1.totalDistance },
            sessions: sessions
        )
    }
}

// MARK: - Private Methods

private extension HealthKitDataService {
    
    /// Generic method to fetch quantity data from HealthKit
    func fetchQuantityData(
        type: HKQuantityType,
        config: HealthKitQueryConfig,
        unit: HKUnit
    ) async throws -> [QuantityDataPoint] {
        
        let predicate = HKQuery.predicateForSamples(
            withStart: config.startDate,
            end: config.endDate
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: [.cumulativeSum],
                anchorDate: config.startDate,
                intervalComponents: config.interval
            )
            
            query.initialResultsHandler = { _, collection, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.queryFailed(error))
                    return
                }
                
                guard let collection = collection else {
                    continuation.resume(throwing: HealthKitError.dataNotFound)
                    return
                }
                
                var dataPoints: [QuantityDataPoint] = []
                
                collection.enumerateStatistics(
                    from: config.startDate,
                    to: config.endDate
                ) { statistics, _ in
                    if let sum = statistics.sumQuantity() {
                        let value = sum.doubleValue(for: unit)
                        dataPoints.append(QuantityDataPoint(
                            date: statistics.startDate,
                            value: value
                        ))
                    }
                }
                
                continuation.resume(returning: dataPoints)
            }
            
            healthStore.execute(query)
        }
    }
    
    /// Creates walking sessions from steps and distance data
    func createWalkingSessions(
        steps: [QuantityDataPoint],
        distances: [QuantityDataPoint]
    ) -> [WalkingSession] {
        
        // Group data by day for session creation
        let groupedSteps = Dictionary(grouping: steps) { point in
            Calendar.current.startOfDay(for: point.date)
        }
        
        let distanceDict = Dictionary(grouping: distances) { point in
            Calendar.current.startOfDay(for: point.date)
        }
        
        var sessions: [WalkingSession] = []
        
        for (date, daySteps) in groupedSteps {
            let dayDistances = distanceDict[date] ?? []
            
            let totalSteps = Int(daySteps.reduce(0) { $0 + $1.value })
            let totalDistance = dayDistances.reduce(0) { $0 + $1.value }
            
            // Only create sessions for days with significant activity
            if totalSteps > 500 {
                let endDate = Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date
                let averagePace = totalSteps > 0 ? Double(totalSteps) / (24 * 60) : 0
                
                let session = WalkingSession(
                    startDate: date,
                    endDate: endDate,
                    totalSteps: totalSteps,
                    totalDistance: totalDistance,
                    averagePace: averagePace,
                    source: "HealthKit"
                )
                sessions.append(session)
            }
        }
        
        return sessions.sorted { $0.startDate < $1.startDate }
    }
}

// MARK: - Helper Data Structure

private struct QuantityDataPoint {
    let date: Date
    let value: Double
} 
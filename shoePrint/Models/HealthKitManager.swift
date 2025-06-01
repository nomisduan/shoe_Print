//
//  HealthKitManager.swift
//  shoePrint
//
//  Created by Simon Naud on 11/04/2025.
//

import Foundation
import HealthKit

/// HealthKit-specific error types
enum HealthKitManagerError: LocalizedError {
    case notAvailable
    case permissionDenied
    case queryFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device"
        case .permissionDenied:
            return "Permission to access health data was denied"
        case .queryFailed(let error):
            return "Health data query failed: \(error.localizedDescription)"
        }
    }
}

/// Manages HealthKit access with iOS permission bug workarounds
@MainActor
class HealthKitManager: ObservableObject {
    
    // MARK: - Properties
    
    @Published var isAuthorized = false
    
    private let healthStore = HKHealthStore()
    private let stepType = HKQuantityType(.stepCount)
    private let distanceType = HKQuantityType(.distanceWalkingRunning)
    
    // UserDefaults key for persisting override status
    private let authOverrideKey = "HealthKitAuthorizationOverride"
    
    // MARK: - Initialization
    
    init() {
        checkHealthKitAvailability()
        loadPersistedAuthorizationStatus()
        checkCurrentAuthorizationStatus()
        
        print("🔐 HealthKitManager initialized with authorization: \(isAuthorized)")
    }
    
    // MARK: - Public API
    
    /// Requests permissions for required HealthKit data types
    func requestPermissions() async throws {
        print("🔐 HealthKitManager: Starting permission request...")
        
        guard HKHealthStore.isHealthDataAvailable() else {
            print("❌ HealthKit not available")
            throw HealthKitManagerError.notAvailable
        }
        
        let typesToRead: Set<HKObjectType> = [stepType, distanceType]
        
        do {
            print("📋 Requesting authorization for: Steps, Walking/Running Distance")
            
            // ✅ Use async/await properly with error handling
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                healthStore.requestAuthorization(toShare: [], read: typesToRead) { success, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            print("❌ HealthKit authorization error: \(error)")
                            continuation.resume(throwing: error)
                        } else {
                            print("✅ HealthKit authorization completed with success: \(success)")
                            
                            // ✅ Always check status after authorization, regardless of success flag
                            self.checkCurrentAuthorizationStatus()
                            
                            // ✅ Small delay to ensure authorization status is updated
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                self.checkCurrentAuthorizationStatus()
                                print("🔄 Final authorization status: \(self.isAuthorized)")
                            }
                            
                            continuation.resume()
                        }
                    }
                }
            }
            
        } catch {
            print("❌ Error requesting HealthKit permissions: \(error)")
            await MainActor.run {
                self.isAuthorized = false
            }
            throw error
        }
    }
    
    /// Force override authorization status (workaround for iOS bugs)
    func overrideAuthorizationStatus(to authorized: Bool) {
        print("🔓 HealthKitManager: Overriding authorization status to \(authorized)")
        isAuthorized = authorized
        savePersistedAuthorizationStatus(authorized)
    }
    
    /// Fetches hourly step and distance data for a specific date
    func fetchHourlyData(for date: Date) async -> [(hour: Int, steps: Int, distance: Double)] {
        print("📊 HealthKitManager: Attempting to fetch hourly data...")
        
        let calendar = Calendar.current
        var hourlyData: [(hour: Int, steps: Int, distance: Double)] = []
        
        for hour in 0..<24 {
            let timeRange = createHourTimeRange(for: date, hour: hour, calendar: calendar)
            
            async let steps = fetchSteps(from: timeRange.start, to: timeRange.end)
            async let distance = fetchDistance(from: timeRange.start, to: timeRange.end)
            
            let (stepCount, distanceValue) = await (steps, distance)
            hourlyData.append((hour: hour, steps: stepCount, distance: distanceValue))
        }
        
        updateAuthorizationStatusIfNeeded(hourlyData: hourlyData)
        
        print("📊 HealthKitManager: Fetched \(hourlyData.count) hourly data points")
        return hourlyData
    }
}

// MARK: - Private Methods

private extension HealthKitManager {
    
    func checkHealthKitAvailability() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("❌ HealthKit is not available on this device")
            return
        }
        print("✅ HealthKit is available on this device")
    }
    
    func checkCurrentAuthorizationStatus() {
        let stepAuthStatus = healthStore.authorizationStatus(for: stepType)
        let distanceAuthStatus = healthStore.authorizationStatus(for: distanceType)
        
        print("🔍 Current HealthKit Authorization Status:")
        print("  - Steps: \(authorizationStatusDescription(stepAuthStatus))")
        print("  - Distance: \(authorizationStatusDescription(distanceAuthStatus))")
        
        let newAuthorized = stepAuthStatus == .sharingAuthorized && distanceAuthStatus == .sharingAuthorized
        
        // ✅ Only update if status actually changed to trigger UI updates
        if isAuthorized != newAuthorized {
            isAuthorized = newAuthorized
            print("🔄 Authorization status changed to: \(isAuthorized)")
            
            // ✅ Save the new status
            if isAuthorized {
                savePersistedAuthorizationStatus(true)
            }
        }
        
        print("  - Overall authorized: \(isAuthorized)")
    }
    
    func authorizationStatusDescription(_ status: HKAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "Not Determined"
        case .sharingDenied: return "Denied"
        case .sharingAuthorized: return "Authorized"
        @unknown default: return "Unknown"
        }
    }
    
    func createHourTimeRange(for date: Date, hour: Int, calendar: Calendar) -> (start: Date, end: Date) {
        let startOfHour = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date
        let endOfHour = calendar.date(byAdding: .hour, value: 1, to: startOfHour) ?? date
        return (start: startOfHour, end: endOfHour)
    }
    
    func updateAuthorizationStatusIfNeeded(hourlyData: [(hour: Int, steps: Int, distance: Double)]) {
        if !hourlyData.isEmpty && !isAuthorized {
            print("✅ HealthKitManager: Data fetch successful, updating authorization status")
            isAuthorized = true
        }
    }
    
    func loadPersistedAuthorizationStatus() {
        if UserDefaults.standard.object(forKey: authOverrideKey) != nil {
            let savedStatus = UserDefaults.standard.bool(forKey: authOverrideKey)
            if savedStatus {
                print("🔓 HealthKitManager: Loading persisted authorization override (true)")
                isAuthorized = true
            } else {
                print("🔓 HealthKitManager: Found persisted authorization override (false)")
            }
        } else {
            print("🔓 HealthKitManager: No persisted authorization override found")
        }
    }
    
    func savePersistedAuthorizationStatus(_ authorized: Bool) {
        UserDefaults.standard.set(authorized, forKey: authOverrideKey)
        print("🔓 HealthKitManager: Saved authorization status: \(authorized)")
    }
}

// MARK: - Data Fetching

private extension HealthKitManager {
    
    func fetchSteps(from startDate: Date, to endDate: Date) async -> Int {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error = error {
                    print("❌ Error fetching steps: \(error)")
                    continuation.resume(returning: 0)
                    return
                }
                
                let steps = result?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
                continuation.resume(returning: Int(steps))
            }
            
            healthStore.execute(query)
        }
    }
    
    func fetchDistance(from startDate: Date, to endDate: Date) async -> Double {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: distanceType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error = error {
                    print("❌ Error fetching distance: \(error)")
                    continuation.resume(returning: 0.0)
                    return
                }
                
                let distance = result?.sumQuantity()?.doubleValue(for: HKUnit.meterUnit(with: .kilo)) ?? 0
                continuation.resume(returning: distance)
            }
            
            healthStore.execute(query)
        }
    }
} 
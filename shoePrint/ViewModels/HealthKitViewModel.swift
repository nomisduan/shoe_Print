//
//  HealthKitViewModel.swift
//  shoePrint
//
//  Created by Simon Naud on 11/04/2025.
//

import Foundation
import SwiftData
import Combine
import HealthKit

/// HealthKit view model with iOS permission bug workaround and clean data access
@MainActor
final class HealthKitViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isPermissionGranted = false
    @Published var isLoading = false
    @Published var error: String?
    @Published var hourlyStepData: [HourlyStepData] = []
    @Published var isHealthKitAvailable = false
    
    // MARK: - Private Properties
    
    private let _healthKitManager: HealthKitManager
    
    // MARK: - Public Properties
    
    /// Exposes the HealthKitManager for sharing across services
    var healthKitManager: HealthKitManager { _healthKitManager }
    private let sessionService: SessionService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(healthKitManager: HealthKitManager, sessionService: SessionService) {
        self._healthKitManager = healthKitManager
        self.sessionService = sessionService
        
        checkHealthKitAvailability()
        setupBindings()
        
        // ✅ Recheck authorization status on startup to ensure consistency
        Task {
            await recheckAuthorizationStatus()
        }
    }
    
    // MARK: - Public Methods
    
    /// Requests HealthKit permissions
    func requestPermissions() async {
        print("🔐 HealthKitViewModel: Starting permission request...")
        isLoading = true
        error = nil
        
        do {
            try await _healthKitManager.requestPermissions()
            
            // ✅ Wait for authorization status to be properly updated
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // iOS bug workaround: Sometimes authorization status doesn't update immediately
            if !isPermissionGranted {
                print("⚠️ HealthKit permission status not updated - trying workaround...")
                
                // Wait a bit longer and try to fetch data to verify real authorization
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                
                print("📊 Testing data access to verify real authorization...")
                let testData = await _healthKitManager.fetchHourlyData(for: Date())
                
                if !testData.isEmpty {
                    print("✅ HealthKit data accessible despite permission status - overriding")
                    _healthKitManager.overrideAuthorizationStatus(to: true)
                } else {
                    print("❌ No HealthKit data accessible - permissions likely denied")
                }
            } else {
                print("✅ HealthKit permissions granted successfully")
            }
            
        } catch {
            print("❌ HealthKit permission request failed: \(error)")
            self.error = "Failed to request HealthKit permissions: \(error.localizedDescription)"
        }
        
        isLoading = false
        print("🔐 HealthKitViewModel: Permission request completed. Granted: \(isPermissionGranted)")
    }
    
    /// Force override authorization status (workaround for iOS bugs)
    func overridePermissionStatus() {
        _healthKitManager.overrideAuthorizationStatus(to: true)
    }
    
    /// Fetches raw hourly steps for a specific date (no attribution)
    /// ✅ Simplified - attribution is now handled separately by AttributionService
    func fetchHourlySteps(for date: Date) async -> [HourlyStepData] {
        if isPermissionGranted {
            // Step 1: Check for auto-management tasks (real session management)
            await sessionService.checkAndAutoCloseInactiveSessions()
            await sessionService.checkAndAutoStartDefaultShoe()
            
            // Step 2: Get raw HealthKit data (no attribution)
            return await fetchRawHealthKitData(for: date)
        } else {
            print("🔬 Generating sample hourly data for testing (HealthKit not authorized)")
            return generateSampleHourlyData(for: date)
        }
    }
    
    /// Fetches total HealthKit data since January 1st of current year
    func fetchYearToDateTotals() async -> (steps: Int, distance: Double) {
        if !isPermissionGranted {
            print("🔬 Using sample data for year-to-date totals (HealthKit not authorized)")
            return (steps: Int.random(in: 500_000...2_000_000), distance: Double.random(in: 400...1500))
        }
        
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let startOfYear = calendar.date(from: DateComponents(year: currentYear, month: 1, day: 1)) ?? Date()
        let now = Date()
        
        print("📊 Fetching HealthKit data from \(startOfYear) to \(now)")
        
        // Calculate all dates from start of year to today
        var totalSteps = 0
        var totalDistance = 0.0
        var currentDate = startOfYear
        
        while currentDate <= now {
            let dailyData = await _healthKitManager.fetchHourlyData(for: currentDate)
            
            let dailySteps = dailyData.reduce(0) { $0 + $1.steps }
            let dailyDistance = dailyData.reduce(0.0) { $0 + $1.distance }
            
            totalSteps += dailySteps
            totalDistance += dailyDistance
            
            // Move to next day
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? now
        }
        
        print("📊 Year-to-date totals: \(totalSteps) steps, \(totalDistance) km")
        return (steps: totalSteps, distance: totalDistance)
    }
    
    /// Rechecks authorization status (useful on app startup)
    func recheckAuthorizationStatus() async {
        print("🔄 HealthKitViewModel: Rechecking authorization status...")
        await MainActor.run {
            _healthKitManager.checkCurrentAuthorizationStatus()
            print("🔄 HealthKitViewModel: Authorization status after recheck: \(isPermissionGranted)")
        }
    }
    
    // MARK: - Private Methods
    
    private func checkHealthKitAvailability() {
        isHealthKitAvailable = HKHealthStore.isHealthDataAvailable()
    }
    
    private func setupBindings() {
        _healthKitManager.$isAuthorized
            .receive(on: DispatchQueue.main)
            .assign(to: \.isPermissionGranted, on: self)
            .store(in: &cancellables)
    }
    
    /// Fetches raw HealthKit data without any attribution information
    private func fetchRawHealthKitData(for date: Date) async -> [HourlyStepData] {
        let hourlyData = await _healthKitManager.fetchHourlyData(for: date)
        
        return hourlyData.compactMap { data in
            guard data.steps > 0 else { return nil }
            
            return HourlyStepData(
                hour: data.hour,
                date: Calendar.current.date(bySettingHour: data.hour, minute: 0, second: 0, of: date) ?? date,
                steps: data.steps,
                distance: data.distance,
                assignedShoe: nil // Always nil - attributions come from sessions
            )
        }
    }
    
    /// Generates sample hourly data for testing when HealthKit is not available
    private func generateSampleHourlyData(for date: Date) -> [HourlyStepData] {
        let calendar = Calendar.current
        var sampleData: [HourlyStepData] = []
        
        // Generate realistic step data for 8 AM to 10 PM
        for hour in 8..<22 {
            let hourDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date
            let steps = Int.random(in: 100...800)
            // Generate realistic distance: roughly 0.762 meters per step, converted to km
            let distance = Double(steps) * 0.000762
            
            sampleData.append(HourlyStepData(
                hour: hour,
                date: hourDate,
                steps: steps,
                distance: distance,
                assignedShoe: nil
            ))
        }
        
        return sampleData
    }
}

// MARK: - Helper Methods

private extension HealthKitViewModel {
    
    func formatStepCount(_ steps: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: steps)) ?? "0"
    }
    
    func formatDistance(_ distanceInMeters: Double) -> String {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .providedUnit
        formatter.numberFormatter.maximumFractionDigits = 1
        
        let distance = Measurement(value: distanceInMeters / 1000, unit: UnitLength.kilometers)
        return formatter.string(from: distance)
    }
}

// MARK: - HourlyStepData Model

/// Model representing hourly step data with optional shoe attribution
struct HourlyStepData: Identifiable {
    let id = UUID()
    let hour: Int
    let date: Date
    let steps: Int
    let distance: Double // Real distance from HealthKit in kilometers
    var assignedShoe: Shoe?
    
    var timeString: String {
        "\(hour):00"
    }
    
    var stepsFormatted: String {
        "\(steps) steps"
    }
    
    var distanceFormatted: String {
        return distance.formattedDistance
    }
} 
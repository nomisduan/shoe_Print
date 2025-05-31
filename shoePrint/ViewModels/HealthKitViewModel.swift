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
    
    private let healthKitManager: HealthKitManager
    private let shoeSessionService: ShoeSessionService
    private let modelContext: ModelContext
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext, healthKitManager: HealthKitManager) {
        self.modelContext = modelContext
        self.healthKitManager = healthKitManager
        self.shoeSessionService = ShoeSessionService(modelContext: modelContext)
        
        checkHealthKitAvailability()
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    /// Requests HealthKit permissions
    func requestPermissions() async {
        isLoading = true
        do {
            try await healthKitManager.requestPermissions()
            
            // iOS bug workaround: Sometimes authorization status doesn't update immediately
            if !isPermissionGranted {
                print("⚠️ HealthKit permission bug detected - trying workaround...")
                
                // Wait a bit and try to fetch data to verify real authorization
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                
                let testData = await healthKitManager.fetchHourlyData(for: Date())
                if !testData.isEmpty {
                    print("✅ HealthKit data accessible despite permission status - overriding")
                    healthKitManager.overrideAuthorizationStatus(to: true)
                }
            }
            
            self.error = nil
        } catch {
            self.error = "Failed to request HealthKit permissions: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    /// Force override authorization status (workaround for iOS bugs)
    func overridePermissionStatus() {
        healthKitManager.overrideAuthorizationStatus(to: true)
    }
    
    /// Fetches hourly steps for a specific date
    func fetchHourlySteps(for date: Date) async -> [HourlyStepData] {
        if isPermissionGranted {
            // Step 1: Check for auto-management tasks
            await shoeSessionService.checkAndAutoCloseInactiveSessions()
            await shoeSessionService.checkAndAutoStartDefaultShoe()
            
            // Step 2: Get raw HealthKit data
            let rawHealthKitData = await fetchRawHealthKitData(for: date)
            
            // Step 3: Apply session-based attribution
            let attributedData = await shoeSessionService.getHourlyStepDataForDate(date, healthKitData: rawHealthKitData)
            
            return attributedData
        } else {
            print("🔬 Generating sample hourly data for testing (HealthKit not authorized)")
            return generateSampleHourlyData(for: date)
        }
    }
    
    // MARK: - Private Methods
    
    private func checkHealthKitAvailability() {
        isHealthKitAvailable = HKHealthStore.isHealthDataAvailable()
    }
    
    private func setupBindings() {
        healthKitManager.$isAuthorized
            .receive(on: DispatchQueue.main)
            .assign(to: \.isPermissionGranted, on: self)
            .store(in: &cancellables)
    }
    
    /// Fetches raw HealthKit data without any attribution information
    private func fetchRawHealthKitData(for date: Date) async -> [HourlyStepData] {
        let hourlyData = await healthKitManager.fetchHourlyData(for: date)
        
        return hourlyData.compactMap { data in
            guard data.steps > 0 else { return nil }
            
            return HourlyStepData(
                hour: data.hour,
                date: Calendar.current.date(bySettingHour: data.hour, minute: 0, second: 0, of: date) ?? date,
                steps: data.steps,
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
            
            sampleData.append(HourlyStepData(
                hour: hour,
                date: hourDate,
                steps: steps,
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
    var assignedShoe: Shoe?
    
    var timeString: String {
        "\(hour):00"
    }
    
    var stepsFormatted: String {
        "\(steps) steps"
    }
} 
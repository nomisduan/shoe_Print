//
//  MockHealthKitManager.swift
//  shoePrintTests
//
//  Portfolio Refactor: Mock implementation for testing HealthKit functionality
//

import Foundation
@testable import shoePrint

/// Mock implementation of HealthKitManager for testing
/// ✅ Provides controlled test data and behavior simulation
final class MockHealthKitManager: HealthKitManager {
    
    // MARK: - Test Control Properties
    
    var mockPermissionGranted = false
    var mockError: String?
    var mockIsLoading = false
    var mockHourlyStepsData: [HourlyStepData] = []
    
    // MARK: - Override Properties
    
    override var isPermissionGranted: Bool {
        mockPermissionGranted
    }
    
    override var error: String? {
        mockError
    }
    
    override var isLoading: Bool {
        mockIsLoading
    }
    
    // MARK: - Override Methods
    
    override func requestPermissions() async {
        mockIsLoading = true
        
        // Simulate async delay
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        mockIsLoading = false
        mockPermissionGranted = true
        mockError = nil
    }
    
    override func fetchHourlySteps(for date: Date) async -> [HourlyStepData] {
        return mockHourlyStepsData
    }
    
    override func overridePermissionStatus() {
        mockPermissionGranted = true
        mockError = nil
    }
    
    // MARK: - Test Helper Methods
    
    /// Sets up mock data for a typical day with varying step counts
    func setupTypicalDayData(for date: Date = Date()) {
        mockHourlyStepsData = createMockHourlyData(for: date)
    }
    
    /// Sets up empty data (no steps)
    func setupEmptyData() {
        mockHourlyStepsData = []
    }
    
    /// Simulates permission denied scenario
    func simulatePermissionDenied() {
        mockPermissionGranted = false
        mockError = "HealthKit permission denied"
    }
    
    /// Simulates network or data fetch error
    func simulateDataFetchError() {
        mockError = "Failed to fetch health data"
    }
    
    /// Creates realistic mock hourly step data
    private func createMockHourlyData(for date: Date) -> [HourlyStepData] {
        let calendar = Calendar.current
        var hourlyData: [HourlyStepData] = []
        
        // Create data for 24 hours with realistic patterns
        for hour in 0...23 {
            guard let hourDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date) else {
                continue
            }
            
            let steps = generateRealisticStepCount(for: hour)
            let distance = Double(steps) * 0.0008 // Approximate: 1250 steps per km
            
            let hourData = HourlyStepData(
                id: UUID(),
                date: hourDate,
                hour: hour,
                steps: steps,
                distance: distance,
                assignedShoe: nil
            )
            
            hourlyData.append(hourData)
        }
        
        return hourlyData
    }
    
    /// Generates realistic step counts based on time of day
    private func generateRealisticStepCount(for hour: Int) -> Int {
        switch hour {
        case 0...5:
            return 0 // Sleeping
        case 6...8:
            return Int.random(in: 200...600) // Morning routine
        case 9...11:
            return Int.random(in: 400...800) // Active morning
        case 12...13:
            return Int.random(in: 300...700) // Lunch time
        case 14...17:
            return Int.random(in: 500...1000) // Afternoon activity
        case 18...20:
            return Int.random(in: 400...900) // Evening activity
        case 21...23:
            return Int.random(in: 100...400) // Winding down
        default:
            return 0
        }
    }
}
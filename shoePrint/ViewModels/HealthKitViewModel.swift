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
    @Published var recentSessions: [WalkingSession] = []
    @Published var weeklyStats: HealthDataSummary?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    private let healthKitManager: HealthKitManager
    private let healthKitDataService: HealthKitDataService
    private let dataAttributionService: DataAttributionService
    private let hourlyAttributionService: HourlyAttributionService
    private let intelligentActivationService: IntelligentActivationService
    private let modelContext: ModelContext
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext, healthKitManager: HealthKitManager) {
        self.modelContext = modelContext
        self.healthKitManager = healthKitManager
        self.healthKitDataService = HealthKitDataService(healthKitManager: healthKitManager)
        self.dataAttributionService = DataAttributionService(modelContext: modelContext)
        self.hourlyAttributionService = HourlyAttributionService(modelContext: modelContext)
        self.intelligentActivationService = IntelligentActivationService(modelContext: modelContext)
        
        setupBindings()
        checkInitialPermissionStatus()
    }
    
    // MARK: - Public API
    
    /// Requests HealthKit permissions with iOS bug workaround
    func requestPermissions() async {
        do {
            try await healthKitManager.requestPermissions()
            
            // ⚠️ iOS bug: authorization status is often incorrect!
            // Always test real data access regardless of reported status
            print("🔄 Testing real data access regardless of reported permission status...")
            await testRealDataAccess()
            
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// Fetches hourly steps for a specific date
    func fetchHourlySteps(for date: Date) async -> [HourlyStepData] {
        if isPermissionGranted {
            // Step 0: Run intelligent activation checks
            await intelligentActivationService.checkAndDeactivateInactiveShoes()
            await intelligentActivationService.checkAndActivateDefaultShoe()
            
            // Step 1: Get raw HealthKit data (source of truth for steps)
            let rawHealthKitData = await fetchRawHealthKitData(for: date)
            
            // Step 2: Get existing attributions from database (source of truth for attributions)
            let existingAttributions = await fetchExistingHourlyAttributions(for: date)
            
            // Step 3: Merge the two sources
            let mergedData = mergeHealthKitDataWithAttributions(rawHealthKitData, existingAttributions)
            
            // Step 4: Split data into attributed and unattributed
            let unattributedData = mergedData.filter { $0.assignedShoe == nil }
            let attributedData = mergedData.filter { $0.assignedShoe != nil }
            
            // Step 5: Only apply auto-attribution to recent unattributed data
            let processedUnattributedData = await applyAutoAttributionToRecentData(unattributedData)
            
            // Step 6: Combine attributed and processed unattributed data
            let finalData = attributedData + processedUnattributedData
            
            return finalData.sorted { $0.hour < $1.hour }
        } else {
            print("🔬 Generating sample hourly data for testing (HealthKit not authorized)")
            return generateSampleHourlyData(for: date)
        }
    }
    
    /// Syncs recent HealthKit data
    func syncRecentData() async {
        guard isPermissionGranted else { return }
        
        await performDataSync()
    }
    
    /// Refreshes health data (alias for syncRecentData for clarity)
    func refreshHealthData() async {
        await syncRecentData()
    }
    
    /// Attributes a walking session to a specific shoe
    func attributeSessionToShoe(_ session: WalkingSession, to shoe: Shoe) async {
        await dataAttributionService.attributeSessionToShoe(session, to: shoe)
    }
    
    /// Attributes hourly steps to a specific shoe
    /// - Parameters:
    ///   - hourData: The hourly step data to attribute
    ///   - shoe: The shoe to attribute the steps to
    func attributeHourlyStepsToShoe(_ hourData: HourlyStepData, to shoe: Shoe) async {
        await hourlyAttributionService.attributeHourToShoe(hourData, to: shoe)
    }
    
    /// Removes attribution for specific hourly data
    /// - Parameter hourData: The hourly data to remove attribution for
    func removeHourlyAttribution(_ hourData: HourlyStepData) async {
        await hourlyAttributionService.removeAttributionForHour(hourData)
    }
    
    /// Checks if hourly data is attributed
    /// - Parameter hourData: The hourly data to check
    /// - Returns: True if the hour has been attributed
    func isHourlyDataAttributed(_ hourData: HourlyStepData) -> Bool {
        return hourlyAttributionService.isHourAttributed(hourData)
    }
}

// MARK: - Data Fetching

private extension HealthKitViewModel {
    
    /// Fetches raw HealthKit data without any attribution information
    func fetchRawHealthKitData(for date: Date) async -> [HourlyStepData] {
        let hourlyData = await healthKitManager.fetchHourlyData(for: date)
        
        return hourlyData.compactMap { data in
            guard data.steps > 0 else { return nil }
            
            return HourlyStepData(
                hour: data.hour,
                date: Calendar.current.date(bySettingHour: data.hour, minute: 0, second: 0, of: date) ?? date,
                steps: data.steps,
                assignedShoe: nil // Always nil - attributions come from database
            )
        }
    }
    
    /// Fetches existing hourly attributions from the database for a specific date
    func fetchExistingHourlyAttributions(for date: Date) async -> [String: Shoe] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
        
        let descriptor = FetchDescriptor<StepEntry>(
            predicate: #Predicate<StepEntry> { entry in
                entry.source == "hourly" && 
                entry.startDate >= startOfDay && 
                entry.startDate < endOfDay
            }
        )
        
        do {
            let entries = try modelContext.fetch(descriptor)
            
            var attributions: [String: Shoe] = [:]
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd-HH"
            
            for entry in entries {
                if let shoe = entry.shoe {
                    let hourKey = formatter.string(from: entry.startDate)
                    attributions[hourKey] = shoe
                }
            }
            
            print("📚 Found \(attributions.count) existing hourly attributions for \(formatter.string(from: date))")
            return attributions
            
        } catch {
            print("❌ Error fetching existing attributions: \(error)")
            return [:]
        }
    }
    
    /// Merges raw HealthKit data with existing attributions from database
    func mergeHealthKitDataWithAttributions(_ healthKitData: [HourlyStepData], _ attributions: [String: Shoe]) -> [HourlyStepData] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH"
        
        return healthKitData.map { hourData in
            var mergedData = hourData
            let hourKey = formatter.string(from: hourData.date)
            
            // Apply existing attribution if found
            if let attributedShoe = attributions[hourKey] {
                mergedData.assignedShoe = attributedShoe
                print("🔗 Restored attribution for \(hourData.timeString): \(attributedShoe.brand) \(attributedShoe.model)")
            }
            
            return mergedData
        }
    }
    
    func performDataSync() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate) ?? endDate
            let config = HealthKitQueryConfig.dailyQuery(from: startDate, to: endDate)
            
            recentSessions = try await healthKitDataService.fetchWalkingSessions(config: config)
            weeklyStats = try await healthKitDataService.fetchHealthDataSummary(config: config)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// Applies auto-attribution only to recent unattributed data (after activation timestamp)
    private func applyAutoAttributionToRecentData(_ unattributedData: [HourlyStepData]) async -> [HourlyStepData] {
        // Only process if we have unattributed data
        guard !unattributedData.isEmpty else { return [] }
        
        // Get active shoes for automatic attribution
        let activeShoes = await getActiveShoes()
        
        // Only auto-attribute if there's exactly one active shoe
        guard activeShoes.count == 1, let activeShoe = activeShoes.first else {
            print("📊 No auto-attribution: \(activeShoes.count) active shoes")
            return unattributedData
        }
        
        // Get activation timestamp
        guard let activatedAt = activeShoe.activatedAt else {
            print("📊 No auto-attribution: No activation timestamp")
            return unattributedData
        }
        
        // Filter only data after activation
        let recentData = unattributedData.filter { hourData in
            hourData.date >= activatedAt
        }
        
        let preActivationData = unattributedData.filter { hourData in
            hourData.date < activatedAt
        }
        
        print("📊 Auto-attribution: \(recentData.count) recent hours, \(preActivationData.count) pre-activation hours (skipped)")
        
        // Apply auto-attribution to recent data only
        let processedRecentData = await hourlyAttributionService.processHourlyDataWithAutoAttribution(recentData)
        
        // Return combined data (pre-activation unchanged + processed recent)
        return preActivationData + processedRecentData
    }
    
    /// Gets all currently active shoes
    private func getActiveShoes() async -> [Shoe] {
        let descriptor = FetchDescriptor<Shoe>(
            predicate: #Predicate<Shoe> { shoe in
                shoe.isActive == true && shoe.archived == false
            }
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("❌ Error fetching active shoes: \(error)")
            return []
        }
    }
}

// MARK: - Sample Data Generation

private extension HealthKitViewModel {
    
    /// Generates realistic sample hourly data for testing purposes
    func generateSampleHourlyData(for date: Date) -> [HourlyStepData] {
        let calendar = Calendar.current
        let activityPattern = createRealisticActivityPattern()
        
        let sampleData = activityPattern.map { hour, steps in
            HourlyStepData(
                hour: hour,
                date: calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date,
                steps: steps,
                assignedShoe: nil
            )
        }
        
        return sampleData.sorted { $0.hour < $1.hour }
    }
    
    /// Creates a realistic daily activity pattern
    func createRealisticActivityPattern() -> [Int: Int] {
        return [
            7: 245,   // Morning wake up
            8: 520,   // Getting ready
            9: 180,   // Commute
            10: 320,  // Work activities
            11: 150,  // Office
            12: 680,  // Lunch break
            13: 120,  // Afternoon
            14: 290,  // Meetings
            15: 180,  // Work
            16: 240,  // Afternoon break
            17: 420,  // End of work
            18: 750,  // Commute/evening walk
            19: 320,  // Dinner prep
            20: 180,  // Evening
            21: 90,   // Relaxing
            22: 45    // Bedtime prep
        ]
    }
}

// MARK: - Permission Management & iOS Bug Workaround

private extension HealthKitViewModel {
    
    /// Tests real data access and updates permission status accordingly
    /// This works around iOS bugs where permission status is reported incorrectly
    func testRealDataAccess() async {
        print("🧪 HealthKitViewModel: Testing real data access...")
        isLoading = true
        
        let healthStore = HKHealthStore()
        let stepType = HKQuantityType(.stepCount)
        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.date(byAdding: .day, value: -1, to: Date()),
            end: Date(),
            options: .strictStartDate
        )
        
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: stepType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: nil
            ) { _, samples, error in
                DispatchQueue.main.async {
                    self.handleDataAccessResult(samples: samples, error: error)
                    self.isLoading = false
                    continuation.resume()
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    func handleDataAccessResult(samples: [HKSample]?, error: Error?) {
        if let error = error {
            print("🚫 HealthKitViewModel: Real data access FAILED - \(error.localizedDescription)")
            isPermissionGranted = false
            errorMessage = "Cannot access HealthKit data: \(error.localizedDescription)"
        } else if let samples = samples, !samples.isEmpty {
            print("🎉 HealthKitViewModel: Real data access SUCCESS! Found \(samples.count) samples")
            enableHealthKitAccess()
        } else {
            print("📭 HealthKitViewModel: No data available")
            isPermissionGranted = false
            errorMessage = "No HealthKit data available"
        }
    }
    
    func enableHealthKitAccess() {
        isPermissionGranted = true
        errorMessage = nil
        
        // Synchronize authorization status across all components
        healthKitDataService.overridePermissionStatus(to: .authorized)
        healthKitManager.overrideAuthorizationStatus(to: true)
        
        // Load initial data
        Task {
            await syncRecentData()
        }
    }
    
    func checkInitialPermissionStatus() {
        // ⚠️ iOS bug: permission status is often incorrect!
        // Always test real data access instead of trusting the reported status
        print("🔍 HealthKitViewModel: Skipping unreliable permission status check, testing real data access...")
        Task {
            await testRealDataAccess()
        }
    }
}

// MARK: - Reactive Bindings

private extension HealthKitViewModel {
    
    func setupBindings() {
        setupHealthKitManagerBindings()
        setupDataServiceBindings()
    }
    
    func setupHealthKitManagerBindings() {
        healthKitManager.$isAuthorized
            .receive(on: DispatchQueue.main)
            .assign(to: \.isPermissionGranted, on: self)
            .store(in: &cancellables)
    }
    
    func setupDataServiceBindings() {
        healthKitDataService.$lastError
            .receive(on: DispatchQueue.main)
            .map { $0?.localizedDescription }
            .assign(to: \.errorMessage, on: self)
            .store(in: &cancellables)
        
        healthKitDataService.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: \.isLoading, on: self)
            .store(in: &cancellables)
    }
}

// MARK: - Computed Properties

extension HealthKitViewModel {
    
    /// Returns unattributed walking sessions that need manual attribution
    var unattributedSessions: [WalkingSession] {
        dataAttributionService.unattributedSessions
    }
    
    /// Returns true if there are sessions pending attribution
    var hasPendingAttributions: Bool {
        !unattributedSessions.isEmpty
    }
    
    /// Returns formatted weekly step count
    var weeklyStepsFormatted: String {
        formatStepCount(weeklyStats?.totalSteps ?? 0)
    }
    
    /// Returns formatted weekly distance
    var weeklyDistanceFormatted: String {
        formatDistance(weeklyStats?.totalDistance ?? 0)
    }
    
    /// Returns formatted today's step count (approximation)
    var todayStepsFormatted: String {
        let todaySteps = (weeklyStats?.totalSteps ?? 0) / 7
        return formatStepCount(todaySteps)
    }
    
    /// Returns active days count
    var activeDaysCount: Int {
        weeklyStats?.activeDays ?? 0
    }
}

// MARK: - Helper Methods

private extension HealthKitViewModel {
    
    func formatStepCount(_ steps: Int) -> String {
        NumberFormatter.stepFormatter.string(from: NSNumber(value: steps)) ?? "0"
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
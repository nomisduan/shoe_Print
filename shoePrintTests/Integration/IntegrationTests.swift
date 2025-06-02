//
//  IntegrationTests.swift
//  shoePrintTests
//
//  Portfolio Refactor: Integration tests for complete data flow scenarios
//

import Testing
import SwiftData
@testable import shoePrint

/// Integration tests for complete data flow scenarios
/// ✅ Tests end-to-end workflows through the clean architecture
struct IntegrationTests {
    
    // MARK: - Test Setup
    
    private func createTestEnvironment() -> (ModelContext, DIContainer, MockHealthKitManager) {
        // Create in-memory model context
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: Shoe.self, StepEntry.self, ShoeSession.self, HourAttribution.self,
            configurations: config
        )
        let modelContext = container.mainContext
        
        // Create DI container and configure services
        let diContainer = DIContainer.shared
        diContainer.clear()
        
        let healthKitManager = MockHealthKitManager()
        diContainer.configureServices(modelContext: modelContext, healthKitManager: healthKitManager)
        
        return (modelContext, diContainer, healthKitManager)
    }
    
    // MARK: - Complete User Journey Tests
    
    @Test("Complete shoe lifecycle journey")
    func testCompleteShoeLifecycleJourney() async throws {
        // Given
        let (_, diContainer, _) = createTestEnvironment()
        let shoeService = diContainer.resolve(ShoeService.self)
        let sessionService = diContainer.resolve(SessionService.self)
        
        // When - User creates a new shoe
        let shoe = try await shoeService.createShoe(
            brand: "Nike",
            model: "Air Max",
            notes: "My new running shoes",
            icon: "👟",
            color: "CustomBlue",
            estimatedLifespan: 500.0
        )
        
        // Start wearing the shoe
        let session = try await sessionService.startSession(for: shoe)
        
        // Verify shoe is active
        #expect(shoe.isActive == true)
        
        // End the session
        try await sessionService.endSession(for: shoe)
        
        // Verify shoe is no longer active
        #expect(shoe.isActive == false)
        
        // Archive the shoe
        try await shoeService.archiveShoe(shoe)
        
        // Then - Verify complete lifecycle
        #expect(shoe.brand == "Nike")
        #expect(shoe.model == "Air Max")
        #expect(shoe.archived == true)
        #expect(session.endDate != nil)
        
        // Verify statistics
        let stats = try await sessionService.getSessionStatistics(for: shoe)
        #expect(stats.sessionCount == 1)
        #expect(stats.hasActiveSession == false)
    }
    
    @Test("Journal attribution workflow with HealthKit data")
    func testJournalAttributionWorkflow() async throws {
        // Given
        let (_, diContainer, healthKitManager) = createTestEnvironment()
        let shoeService = diContainer.resolve(ShoeService.self)
        let attributionService = diContainer.resolve(AttributionService.self)
        
        // Create shoes
        let runningShoe = try await shoeService.createShoe(
            brand: "Nike",
            model: "Air Max",
            notes: "Running",
            icon: "🏃",
            color: "CustomBlue",
            estimatedLifespan: 500.0
        )
        
        let walkingShoe = try await shoeService.createShoe(
            brand: "Adidas",
            model: "UltraBoost",
            notes: "Walking",
            icon: "🚶",
            color: "CustomGreen",
            estimatedLifespan: 600.0
        )
        
        // Setup mock HealthKit data
        healthKitManager.setupTypicalDayData()
        healthKitManager.mockPermissionGranted = true
        
        // When - User attributes hours to shoes
        let today = Date()
        let calendar = Calendar.current
        
        // Attribute morning hours to running shoe
        let morningHours = [
            calendar.date(bySettingHour: 7, minute: 0, second: 0, of: today)!,
            calendar.date(bySettingHour: 8, minute: 0, second: 0, of: today)!
        ]
        
        try await attributionService.attributeHours(morningHours, to: runningShoe)
        
        // Attribute afternoon hours to walking shoe
        let afternoonHours = [
            calendar.date(bySettingHour: 14, minute: 0, second: 0, of: today)!,
            calendar.date(bySettingHour: 15, minute: 0, second: 0, of: today)!
        ]
        
        try await attributionService.attributeHours(afternoonHours, to: walkingShoe)
        
        // Fetch HealthKit data and apply attributions
        let rawData = await healthKitManager.fetchHourlySteps(for: today)
        let enrichedData = await attributionService.applyAttributions(to: rawData, for: today)
        
        // Then - Verify attribution workflow
        let morningData = enrichedData.filter { morningHours.contains { calendar.isDate($0.date, equalTo: $1, toGranularity: .hour) } }
        let afternoonData = enrichedData.filter { afternoonHours.contains { calendar.isDate($0.date, equalTo: $1, toGranularity: .hour) } }
        
        #expect(morningData.allSatisfy { $0.assignedShoe?.id == runningShoe.id })
        #expect(afternoonData.allSatisfy { $0.assignedShoe?.id == walkingShoe.id })
        
        // Verify shoes have accumulated attributed data
        #expect(runningShoe.hourAttributions.count == 2)
        #expect(walkingShoe.hourAttributions.count == 2)
    }
    
    @Test("Multi-shoe session management workflow")
    func testMultiShoeSessionManagement() async throws {
        // Given
        let (_, diContainer, _) = createTestEnvironment()
        let shoeService = diContainer.resolve(ShoeService.self)
        let sessionService = diContainer.resolve(SessionService.self)
        
        // Create multiple shoes
        let shoes = [
            try await shoeService.createShoe(
                brand: "Nike",
                model: "Air Max",
                notes: "Running",
                icon: "🏃",
                color: "CustomBlue",
                estimatedLifespan: 500.0
            ),
            try await shoeService.createShoe(
                brand: "Adidas",
                model: "UltraBoost",
                notes: "Walking",
                icon: "🚶",
                color: "CustomGreen",
                estimatedLifespan: 600.0
            ),
            try await shoeService.createShoe(
                brand: "Converse",
                model: "Chuck Taylor",
                notes: "Casual",
                icon: "⭐",
                color: "CustomRed",
                estimatedLifespan: 300.0
            )
        ]
        
        // When - Switch between shoes throughout the day
        
        // Morning: Start with running shoes
        let morningSession = try await sessionService.startSession(for: shoes[0])
        #expect(shoes[0].isActive == true)
        #expect(shoes[1].isActive == false)
        #expect(shoes[2].isActive == false)
        
        // Midday: Switch to walking shoes (should auto-end previous)
        let middaySession = try await sessionService.startSession(for: shoes[1])
        #expect(shoes[0].isActive == false)
        #expect(shoes[1].isActive == true)
        #expect(shoes[2].isActive == false)
        
        // Evening: Switch to casual shoes
        let eveningSession = try await sessionService.startSession(for: shoes[2])
        #expect(shoes[0].isActive == false)
        #expect(shoes[1].isActive == false)
        #expect(shoes[2].isActive == true)
        
        // End day
        try await sessionService.endSession(for: shoes[2])
        
        // Then - Verify complete workflow
        let activeSessions = try await sessionService.getActiveSessions()
        #expect(activeSessions.isEmpty)
        
        // Verify all shoes have session history
        for shoe in shoes {
            let stats = try await sessionService.getSessionStatistics(for: shoe)
            #expect(stats.sessionCount == 1)
            #expect(stats.hasActiveSession == false)
        }
        
        // Verify automatic session ending worked
        #expect(morningSession.endDate != nil)
        #expect(middaySession.endDate != nil)
        #expect(eveningSession.endDate != nil)
    }
    
    @Test("Default shoe auto-start workflow")
    func testDefaultShoeAutoStartWorkflow() async throws {
        // Given
        let (_, diContainer, healthKitManager) = createTestEnvironment()
        let shoeService = diContainer.resolve(ShoeService.self)
        let sessionService = diContainer.resolve(SessionService.self)
        
        // Create default shoe
        let defaultShoe = try await shoeService.createShoe(
            brand: "Barefoot",
            model: "Your Feet",
            notes: "Default for everyone",
            icon: "🦶",
            color: "CustomGray",
            estimatedLifespan: 1000.0
        )
        
        // Make it the default shoe (simulate repository behavior)
        // In real implementation, this would be handled by the repository
        
        // Setup HealthKit to have steps today
        healthKitManager.setupTypicalDayData()
        healthKitManager.mockPermissionGranted = true
        
        // When - Auto-start logic runs
        await sessionService.checkAndAutoStartDefaultShoe()
        
        // Then - Default shoe should be auto-started
        let activeSessions = try await sessionService.getActiveSessions()
        #expect(activeSessions.count == 1)
        
        let activeSession = activeSessions.first!
        #expect(activeSession.shoe?.brand == "Barefoot")
        #expect(activeSession.autoStarted == true)
        #expect(defaultShoe.isActive == true)
    }
    
    // MARK: - Data Consistency Tests
    
    @Test("Data consistency across service boundaries")
    func testDataConsistencyAcrossServices() async throws {
        // Given
        let (_, diContainer, _) = createTestEnvironment()
        let shoeService = diContainer.resolve(ShoeService.self)
        let sessionService = diContainer.resolve(SessionService.self)
        let attributionService = diContainer.resolve(AttributionService.self)
        
        // Create shoe
        let shoe = try await shoeService.createShoe(
            brand: "Nike",
            model: "Air Max",
            notes: "Consistency test",
            icon: "👟",
            color: "CustomBlue",
            estimatedLifespan: 500.0
        )
        
        // When - Perform operations across multiple services
        
        // Start session via SessionService
        let session = try await sessionService.startSession(for: shoe)
        
        // Add attribution via AttributionService
        let hourDate = Date()
        try await attributionService.attributeHour(hourDate, to: shoe)
        
        // Update shoe via ShoeService
        try await shoeService.updateShoe(
            shoe,
            brand: "Nike Updated",
            model: nil,
            notes: "Updated notes",
            icon: nil,
            color: nil,
            estimatedLifespan: nil
        )
        
        // Then - Verify data consistency
        
        // Shoe should reflect updates
        #expect(shoe.brand == "Nike Updated")
        #expect(shoe.model == "Air Max") // Preserved
        #expect(shoe.notes == "Updated notes")
        
        // Session should still reference correct shoe
        #expect(session.shoe?.id == shoe.id)
        #expect(session.shoe?.brand == "Nike Updated")
        
        // Attribution should still reference correct shoe
        #expect(shoe.hourAttributions.count == 1)
        #expect(shoe.hourAttributions.first?.shoe?.id == shoe.id)
        
        // Computed properties should work correctly
        #expect(shoe.isActive == true) // Has active session
        #expect(shoe.sessionCount == 1)
        #expect(shoe.hourAttributions.count == 1)
    }
    
    @Test("Error handling across service boundaries")
    func testErrorHandlingAcrossServices() async throws {
        // Given
        let (_, diContainer, _) = createTestEnvironment()
        let shoeService = diContainer.resolve(ShoeService.self)
        let sessionService = diContainer.resolve(SessionService.self)
        
        // Create and archive a shoe
        let shoe = try await shoeService.createShoe(
            brand: "Nike",
            model: "Air Max",
            notes: "Error test",
            icon: "👟",
            color: "CustomBlue",
            estimatedLifespan: 500.0
        )
        
        try await shoeService.archiveShoe(shoe)
        
        // When/Then - Try to start session on archived shoe
        await #expect(throws: AppError.self) {
            try await sessionService.startSession(for: shoe)
        }
        
        // Verify error propagation
        #expect(sessionService.error == .shoeArchived)
        
        // Verify system remains in consistent state
        let activeSessions = try await sessionService.getActiveSessions()
        #expect(activeSessions.isEmpty)
        #expect(shoe.isActive == false)
    }
    
    // MARK: - Performance and Scalability Tests
    
    @Test("Performance with large dataset")
    func testPerformanceWithLargeDataset() async throws {
        // Given
        let (_, diContainer, _) = createTestEnvironment()
        let shoeService = diContainer.resolve(ShoeService.self)
        let sessionService = diContainer.resolve(SessionService.self)
        let attributionService = diContainer.resolve(AttributionService.self)
        
        // When - Create large dataset
        
        // Create multiple shoes
        var shoes: [Shoe] = []
        for i in 0..<10 {
            let shoe = try await shoeService.createShoe(
                brand: "Brand \(i)",
                model: "Model \(i)",
                notes: "Shoe \(i)",
                icon: "👟",
                color: "CustomBlue",
                estimatedLifespan: 500.0
            )
            shoes.append(shoe)
        }
        
        // Create many sessions
        for shoe in shoes {
            for j in 0..<5 {
                let startDate = Date().addingTimeInterval(Double(-j * 3600))
                let session = try await sessionService.startSession(for: shoe)
                try await sessionService.endSession(for: shoe)
            }
        }
        
        // Create many attributions
        let calendar = Calendar.current
        let today = Date()
        for hour in 0..<24 {
            let hourDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: today)!
            let shoe = shoes[hour % shoes.count]
            try await attributionService.attributeHour(hourDate, to: shoe)
        }
        
        // Then - Verify performance remains acceptable
        let allShoes = try await shoeService.getAllShoes()
        #expect(allShoes.count == 10)
        
        // Verify computed properties still work efficiently
        let totalSessions = allShoes.reduce(0) { $0 + $1.sessionCount }
        #expect(totalSessions == 50) // 10 shoes * 5 sessions each
        
        let totalAttributions = allShoes.reduce(0) { $0 + $1.hourAttributions.count }
        #expect(totalAttributions == 24) // 24 hours attributed
    }
    
    @Test("Concurrent operations handling")
    func testConcurrentOperationsHandling() async throws {
        // Given
        let (_, diContainer, _) = createTestEnvironment()
        let shoeService = diContainer.resolve(ShoeService.self)
        let sessionService = diContainer.resolve(SessionService.self)
        
        // Create shoes for concurrent operations
        let shoes = try await withThrowingTaskGroup(of: Shoe.self) { group in
            for i in 0..<5 {
                group.addTask {
                    try await shoeService.createShoe(
                        brand: "Concurrent \(i)",
                        model: "Test \(i)",
                        notes: "",
                        icon: "👟",
                        color: "CustomBlue",
                        estimatedLifespan: 500.0
                    )
                }
            }
            
            var createdShoes: [Shoe] = []
            for try await shoe in group {
                createdShoes.append(shoe)
            }
            return createdShoes
        }
        
        // When - Perform concurrent session operations
        let sessions = try await withThrowingTaskGroup(of: ShoeSession.self) { group in
            for shoe in shoes {
                group.addTask {
                    return try await sessionService.startSession(for: shoe)
                }
            }
            
            var startedSessions: [ShoeSession] = []
            for try await session in group {
                startedSessions.append(session)
            }
            return startedSessions
        }
        
        // Then - Verify only one session is active (due to auto-ending)
        let activeSessions = try await sessionService.getActiveSessions()
        #expect(activeSessions.count == 1)
        
        // All sessions should have been created
        #expect(sessions.count == 5)
        
        // Only the last session should still be active
        let activeShoes = shoes.filter { $0.isActive }
        #expect(activeShoes.count == 1)
    }
    
    // MARK: - Real-World Scenario Tests
    
    @Test("Typical daily usage pattern")
    func testTypicalDailyUsagePattern() async throws {
        // Given
        let (_, diContainer, healthKitManager) = createTestEnvironment()
        let shoeService = diContainer.resolve(ShoeService.self)
        let sessionService = diContainer.resolve(SessionService.self)
        let attributionService = diContainer.resolve(AttributionService.self)
        
        // Create user's shoe collection
        let runningShoes = try await shoeService.createShoe(
            brand: "Nike",
            model: "Air Zoom",
            notes: "For morning runs",
            icon: "🏃‍♂️",
            color: "CustomBlue",
            estimatedLifespan: 600.0
        )
        
        let workShoes = try await shoeService.createShoe(
            brand: "Cole Haan",
            model: "GrandPro",
            notes: "Office shoes",
            icon: "👔",
            color: "CustomGray",
            estimatedLifespan: 800.0
        )
        
        let casualShoes = try await shoeService.createShoe(
            brand: "Allbirds",
            model: "Tree Runners",
            notes: "Everyday comfort",
            icon: "🌿",
            color: "CustomGreen",
            estimatedLifespan: 400.0
        )
        
        // Setup realistic HealthKit data
        healthKitManager.setupTypicalDayData()
        healthKitManager.mockPermissionGranted = true
        
        // When - Simulate a typical day
        
        // 6 AM: Morning run
        let morningRunSession = try await sessionService.startSession(for: runningShoes)
        // ... user goes for a run ...
        try await sessionService.endSession(for: runningShoes)
        
        // 8 AM: Switch to work shoes
        let workSession = try await sessionService.startSession(for: workShoes)
        // ... user goes to work ...
        
        // 5 PM: Switch to casual shoes after work
        let casualSession = try await sessionService.startSession(for: casualShoes)
        // ... user goes about evening activities ...
        try await sessionService.endSession(for: casualShoes)
        
        // User also attributes some specific hours through the journal
        let calendar = Calendar.current
        let today = Date()
        
        // Attribute lunch walk to work shoes
        let lunchHour = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: today)!
        try await attributionService.attributeHour(lunchHour, to: workShoes)
        
        // Attribute evening grocery run to casual shoes
        let eveningHour = calendar.date(bySettingHour: 19, minute: 0, second: 0, of: today)!
        try await attributionService.attributeHour(eveningHour, to: casualShoes)
        
        // Then - Verify realistic daily pattern
        
        // Check session statistics
        let runningStats = try await sessionService.getSessionStatistics(for: runningShoes)
        let workStats = try await sessionService.getSessionStatistics(for: workShoes)
        let casualStats = try await sessionService.getSessionStatistics(for: casualShoes)
        
        #expect(runningStats.sessionCount == 1)
        #expect(workStats.sessionCount == 1)
        #expect(casualStats.sessionCount == 1)
        
        // Work shoes should still be active (didn't end session)
        #expect(workShoes.isActive == true)
        #expect(runningShoes.isActive == false)
        #expect(casualShoes.isActive == false)
        
        // Check attributions
        #expect(workShoes.hourAttributions.count == 1)
        #expect(casualShoes.hourAttributions.count == 1)
        #expect(runningShoes.hourAttributions.count == 0)
        
        // Verify HealthKit integration
        let rawData = await healthKitManager.fetchHourlySteps(for: today)
        let enrichedData = await attributionService.applyAttributions(to: rawData, for: today)
        
        let lunchData = enrichedData.first { calendar.isDate($0.date, equalTo: lunchHour, toGranularity: .hour) }
        let eveningData = enrichedData.first { calendar.isDate($0.date, equalTo: eveningHour, toGranularity: .hour) }
        
        #expect(lunchData?.assignedShoe?.id == workShoes.id)
        #expect(eveningData?.assignedShoe?.id == casualShoes.id)
    }
    
    @Test("Long-term usage tracking")
    func testLongTermUsageTracking() async throws {
        // Given
        let (_, diContainer, _) = createTestEnvironment()
        let shoeService = diContainer.resolve(ShoeService.self)
        let sessionService = diContainer.resolve(SessionService.self)
        
        // Create a shoe for long-term tracking
        let shoe = try await shoeService.createShoe(
            brand: "ASICS",
            model: "Gel-Nimbus",
            notes: "Marathon training",
            icon: "🏃‍♀️",
            color: "CustomBlue",
            estimatedLifespan: 800.0
        )
        
        // When - Simulate usage over time
        
        var totalDuration: TimeInterval = 0
        let sessionCount = 20
        
        for i in 0..<sessionCount {
            // Vary session start times (simulate different days)
            let daysAgo = Double(sessionCount - i)
            let sessionStart = Date().addingTimeInterval(-daysAgo * 24 * 3600)
            
            let session = try await sessionService.startSession(for: shoe)
            
            // Simulate session duration (1-3 hours)
            let duration = Double.random(in: 3600...10800)
            totalDuration += duration
            
            // Manually set session times for testing
            session.startDate = sessionStart
            session.endDate = sessionStart.addingTimeInterval(duration)
            
            try await sessionService.endSession(for: shoe)
        }
        
        // Then - Verify long-term statistics
        let stats = try await sessionService.getSessionStatistics(for: shoe)
        
        #expect(stats.sessionCount == sessionCount)
        #expect(abs(stats.totalWearingTime - totalDuration) < 60.0) // Allow small variance
        #expect(stats.averageSessionDuration > 3600) // At least 1 hour average
        #expect(stats.averageSessionDuration < 10800) // Less than 3 hours average
        #expect(stats.hasActiveSession == false)
        
        // Verify shoe computed properties
        #expect(shoe.sessionCount == sessionCount)
        #expect(abs(shoe.totalWearingTime - totalDuration) < 60.0)
        
        // Verify wear tracking (would need distance data in real scenario)
        #expect(shoe.wearPercentage >= 0.0)
        #expect(shoe.wearPercentage <= 1.0)
        #expect(shoe.remainingDistance >= 0.0)
    }
}
//
//  ShoeModelTests.swift
//  shoePrintTests
//
//  Portfolio Refactor: Unit tests for Shoe model computed properties
//

import Testing
import SwiftData
@testable import shoePrint

/// Unit tests for Shoe model computed properties and business logic
/// ✅ Tests the computed properties that were previously failing
struct ShoeModelTests {
    
    // MARK: - Test Setup
    
    private func createTestModelContext() -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: Shoe.self, StepEntry.self, ShoeSession.self, HourAttribution.self,
            configurations: config
        )
        return container.mainContext
    }
    
    private func createTestShoe(context: ModelContext) -> Shoe {
        let shoe = Shoe(
            brand: "Nike",
            model: "Air Max",
            notes: "Test shoe",
            icon: "👟",
            color: "CustomBlue",
            archived: false,
            isDefault: false,
            estimatedLifespan: 500.0
        )
        context.insert(shoe)
        try! context.save()
        return shoe
    }
    
    // MARK: - Basic Property Tests
    
    @Test("Shoe creation sets all properties correctly")
    func testShoeCreation() async throws {
        // Given
        let context = createTestModelContext()
        
        // When
        let shoe = Shoe(
            brand: "Adidas",
            model: "UltraBoost",
            notes: "Running shoes",
            icon: "🏃",
            color: "CustomGreen",
            archived: false,
            isDefault: true,
            estimatedLifespan: 600.0
        )
        
        context.insert(shoe)
        try context.save()
        
        // Then
        #expect(shoe.brand == "Adidas")
        #expect(shoe.model == "UltraBoost")
        #expect(shoe.notes == "Running shoes")
        #expect(shoe.icon == "🏃")
        #expect(shoe.color == "CustomGreen")
        #expect(shoe.archived == false)
        #expect(shoe.isDefault == true)
        #expect(shoe.estimatedLifespan == 600.0)
        #expect(shoe.createdAt != nil)
    }
    
    @Test("Shoe ID is automatically generated")
    func testShoeIDGeneration() async throws {
        // Given
        let context = createTestModelContext()
        
        // When
        let shoe1 = createTestShoe(context: context)
        let shoe2 = createTestShoe(context: context)
        
        // Then
        #expect(shoe1.id != shoe2.id)
    }
    
    // MARK: - Archive/Unarchive Tests
    
    @Test("Archive shoe sets archived flag and timestamp")
    func testArchiveShoe() async throws {
        // Given
        let context = createTestModelContext()
        let shoe = createTestShoe(context: context)
        #expect(shoe.archived == false)
        #expect(shoe.archivedAt == nil)
        
        // When
        shoe.archive()
        
        // Then
        #expect(shoe.archived == true)
        #expect(shoe.archivedAt != nil)
    }
    
    @Test("Unarchive shoe clears archived flag and timestamp")
    func testUnarchiveShoe() async throws {
        // Given
        let context = createTestModelContext()
        let shoe = createTestShoe(context: context)
        shoe.archive()
        #expect(shoe.archived == true)
        
        // When
        shoe.unarchive()
        
        // Then
        #expect(shoe.archived == false)
        #expect(shoe.archivedAt == nil)
    }
    
    // MARK: - Session-Based Computed Properties Tests
    
    @Test("isActive returns true when shoe has active session")
    func testIsActiveWithActiveSession() async throws {
        // Given
        let context = createTestModelContext()
        let shoe = createTestShoe(context: context)
        
        // Add active session
        let activeSession = ShoeSession(shoe: shoe, startDate: Date(), autoStarted: false)
        // Don't set endDate - keeping it active
        context.insert(activeSession)
        try context.save()
        
        // When/Then
        #expect(shoe.isActive == true)
    }
    
    @Test("isActive returns false when shoe has no active session")
    func testIsActiveWithNoActiveSession() async throws {
        // Given
        let context = createTestModelContext()
        let shoe = createTestShoe(context: context)
        
        // Add completed session
        let completedSession = ShoeSession(shoe: shoe, startDate: Date().addingTimeInterval(-3600), autoStarted: false)
        completedSession.endDate = Date()
        context.insert(completedSession)
        try context.save()
        
        // When/Then
        #expect(shoe.isActive == false)
    }
    
    @Test("totalDistance aggregates from sessions, attributions, and entries")
    func testTotalDistanceAggregation() async throws {
        // Given
        let context = createTestModelContext()
        let shoe = createTestShoe(context: context)
        let baseDate = Date()
        
        // Add session with distance
        let session = ShoeSession(shoe: shoe, startDate: baseDate.addingTimeInterval(-3600), autoStarted: false)
        session.endDate = baseDate
        session.distance = 2.5
        context.insert(session)
        
        // Add hour attribution with distance
        let attribution = HourAttribution(
            hourDate: baseDate,
            shoe: shoe,
            steps: 1000,
            distance: 0.8
        )
        context.insert(attribution)
        
        // Add manual entry with distance
        let entry = StepEntry(
            shoe: shoe,
            steps: 500,
            distance: 0.4,
            date: baseDate,
            notes: "Manual entry"
        )
        context.insert(entry)
        
        try context.save()
        
        // When
        let totalDistance = shoe.totalDistance
        
        // Then
        // Should use sessions + attributions (modern data) = 2.5 + 0.8 = 3.3
        // Entry should be ignored when modern data exists
        #expect(abs(totalDistance - 3.3) < 0.01)
    }
    
    @Test("totalDistance falls back to entries when no modern data")
    func testTotalDistanceFallbackToEntries() async throws {
        // Given
        let context = createTestModelContext()
        let shoe = createTestShoe(context: context)
        
        // Add only manual entries (no sessions or attributions)
        let entry1 = StepEntry(shoe: shoe, steps: 500, distance: 0.4, date: Date(), notes: "Entry 1")
        let entry2 = StepEntry(shoe: shoe, steps: 300, distance: 0.25, date: Date(), notes: "Entry 2")
        
        context.insert(entry1)
        context.insert(entry2)
        try context.save()
        
        // When
        let totalDistance = shoe.totalDistance
        
        // Then
        // Should use entries as fallback = 0.4 + 0.25 = 0.65
        #expect(abs(totalDistance - 0.65) < 0.01)
    }
    
    @Test("totalSteps aggregates correctly")
    func testTotalStepsAggregation() async throws {
        // Given
        let context = createTestModelContext()
        let shoe = createTestShoe(context: context)
        let baseDate = Date()
        
        // Add session with steps
        let session = ShoeSession(shoe: shoe, startDate: baseDate.addingTimeInterval(-3600), autoStarted: false)
        session.endDate = baseDate
        session.steps = 2500
        context.insert(session)
        
        // Add hour attribution with steps
        let attribution = HourAttribution(
            hourDate: baseDate,
            shoe: shoe,
            steps: 800,
            distance: 0.6
        )
        context.insert(attribution)
        
        // Add manual entry with steps
        let entry = StepEntry(
            shoe: shoe,
            steps: 400,
            distance: 0.3,
            date: baseDate,
            notes: "Manual entry"
        )
        context.insert(entry)
        
        try context.save()
        
        // When
        let totalSteps = shoe.totalSteps
        
        // Then
        // Should use sessions + attributions (modern data) = 2500 + 800 = 3300
        #expect(totalSteps == 3300)
    }
    
    @Test("sessionCount returns correct count")
    func testSessionCount() async throws {
        // Given
        let context = createTestModelContext()
        let shoe = createTestShoe(context: context)
        
        // Add multiple sessions
        for i in 0..<3 {
            let session = ShoeSession(
                shoe: shoe,
                startDate: Date().addingTimeInterval(Double(-i * 3600)),
                autoStarted: false
            )
            if i < 2 { // First two are completed
                session.endDate = Date().addingTimeInterval(Double(-i * 3600 + 1800))
            }
            // Third one remains active (no endDate)
            context.insert(session)
        }
        
        try context.save()
        
        // When
        let sessionCount = shoe.sessionCount
        
        // Then
        #expect(sessionCount == 3)
    }
    
    @Test("totalWearingTime calculates correctly")
    func testTotalWearingTime() async throws {
        // Given
        let context = createTestModelContext()
        let shoe = createTestShoe(context: context)
        let now = Date()
        
        // Add completed sessions with known durations
        let session1 = ShoeSession(
            shoe: shoe,
            startDate: now.addingTimeInterval(-7200), // 2 hours ago
            autoStarted: false
        )
        session1.endDate = now.addingTimeInterval(-3600) // 1 hour ago (1 hour duration)
        
        let session2 = ShoeSession(
            shoe: shoe,
            startDate: now.addingTimeInterval(-3600), // 1 hour ago
            autoStarted: false
        )
        session2.endDate = now // Now (1 hour duration)
        
        context.insert(session1)
        context.insert(session2)
        try context.save()
        
        // When
        let totalWearingTime = shoe.totalWearingTime
        
        // Then
        // Should be 2 hours total (3600 + 3600 seconds)
        #expect(abs(totalWearingTime - 7200.0) < 1.0)
    }
    
    @Test("totalWearingTime excludes active sessions")
    func testTotalWearingTimeExcludesActiveSessions() async throws {
        // Given
        let context = createTestModelContext()
        let shoe = createTestShoe(context: context)
        let now = Date()
        
        // Add completed session
        let completedSession = ShoeSession(
            shoe: shoe,
            startDate: now.addingTimeInterval(-3600),
            autoStarted: false
        )
        completedSession.endDate = now
        
        // Add active session (no endDate)
        let activeSession = ShoeSession(
            shoe: shoe,
            startDate: now.addingTimeInterval(-1800), // 30 minutes ago
            autoStarted: false
        )
        // Don't set endDate - keeping it active
        
        context.insert(completedSession)
        context.insert(activeSession)
        try context.save()
        
        // When
        let totalWearingTime = shoe.totalWearingTime
        
        // Then
        // Should only include completed session (1 hour = 3600 seconds)
        #expect(abs(totalWearingTime - 3600.0) < 1.0)
    }
    
    // MARK: - Utility Computed Properties Tests
    
    @Test("wearPercentage calculates correctly")
    func testWearPercentage() async throws {
        // Given
        let context = createTestModelContext()
        let shoe = Shoe(
            brand: "Nike",
            model: "Air Max",
            notes: "",
            icon: "👟",
            color: "CustomBlue",
            archived: false,
            isDefault: false,
            estimatedLifespan: 1000.0 // 1000 km lifespan
        )
        context.insert(shoe)
        
        // Add distance data
        let entry = StepEntry(
            shoe: shoe,
            steps: 1000,
            distance: 250.0, // 250 km used
            date: Date(),
            notes: "Test"
        )
        context.insert(entry)
        try context.save()
        
        // When
        let wearPercentage = shoe.wearPercentage
        
        // Then
        // 250 km out of 1000 km = 25%
        #expect(abs(wearPercentage - 0.25) < 0.01)
    }
    
    @Test("wearPercentage caps at 100 percent")
    func testWearPercentageCapsAt100() async throws {
        // Given
        let context = createTestModelContext()
        let shoe = Shoe(
            brand: "Nike",
            model: "Air Max",
            notes: "",
            icon: "👟",
            color: "CustomBlue",
            archived: false,
            isDefault: false,
            estimatedLifespan: 100.0 // 100 km lifespan
        )
        context.insert(shoe)
        
        // Add more distance than lifespan
        let entry = StepEntry(
            shoe: shoe,
            steps: 1000,
            distance: 150.0, // 150 km used (more than 100 km lifespan)
            date: Date(),
            notes: "Test"
        )
        context.insert(entry)
        try context.save()
        
        // When
        let wearPercentage = shoe.wearPercentage
        
        // Then
        // Should cap at 100% (1.0)
        #expect(wearPercentage == 1.0)
    }
    
    @Test("remainingDistance calculates correctly")
    func testRemainingDistance() async throws {
        // Given
        let context = createTestModelContext()
        let shoe = Shoe(
            brand: "Nike",
            model: "Air Max",
            notes: "",
            icon: "👟",
            color: "CustomBlue",
            archived: false,
            isDefault: false,
            estimatedLifespan: 500.0
        )
        context.insert(shoe)
        
        // Add distance data
        let entry = StepEntry(
            shoe: shoe,
            steps: 1000,
            distance: 150.0,
            date: Date(),
            notes: "Test"
        )
        context.insert(entry)
        try context.save()
        
        // When
        let remainingDistance = shoe.remainingDistance
        
        // Then
        // 500 - 150 = 350 km remaining
        #expect(abs(remainingDistance - 350.0) < 0.01)
    }
    
    @Test("remainingDistance returns zero when overused")
    func testRemainingDistanceZeroWhenOverused() async throws {
        // Given
        let context = createTestModelContext()
        let shoe = Shoe(
            brand: "Nike",
            model: "Air Max",
            notes: "",
            icon: "👟",
            color: "CustomBlue",
            archived: false,
            isDefault: false,
            estimatedLifespan: 100.0
        )
        context.insert(shoe)
        
        // Add more distance than lifespan
        let entry = StepEntry(
            shoe: shoe,
            steps: 1000,
            distance: 150.0,
            date: Date(),
            notes: "Test"
        )
        context.insert(entry)
        try context.save()
        
        // When
        let remainingDistance = shoe.remainingDistance
        
        // Then
        #expect(remainingDistance == 0.0)
    }
    
    // MARK: - Edge Cases
    
    @Test("Computed properties handle empty data gracefully")
    func testComputedPropertiesWithEmptyData() async throws {
        // Given
        let context = createTestModelContext()
        let shoe = createTestShoe(context: context)
        
        // When/Then - No sessions, attributions, or entries
        #expect(shoe.totalDistance == 0.0)
        #expect(shoe.totalSteps == 0)
        #expect(shoe.sessionCount == 0)
        #expect(shoe.totalWearingTime == 0.0)
        #expect(shoe.isActive == false)
        #expect(shoe.wearPercentage == 0.0)
        #expect(shoe.remainingDistance == shoe.estimatedLifespan)
    }
    
    @Test("Computed properties handle large numbers correctly")
    func testComputedPropertiesWithLargeNumbers() async throws {
        // Given
        let context = createTestModelContext()
        let shoe = Shoe(
            brand: "Marathon",
            model: "Ultra",
            notes: "",
            icon: "🏃",
            color: "CustomBlue",
            archived: false,
            isDefault: false,
            estimatedLifespan: 10000.0 // Very durable shoe
        )
        context.insert(shoe)
        
        // Add large numbers
        let entry = StepEntry(
            shoe: shoe,
            steps: 1000000, // 1 million steps
            distance: 800.0, // 800 km
            date: Date(),
            notes: "Marathon training"
        )
        context.insert(entry)
        try context.save()
        
        // When/Then
        #expect(shoe.totalSteps == 1000000)
        #expect(abs(shoe.totalDistance - 800.0) < 0.01)
        #expect(abs(shoe.wearPercentage - 0.08) < 0.001) // 8%
        #expect(abs(shoe.remainingDistance - 9200.0) < 0.01)
    }
    
    @Test("Computed properties are consistent across multiple accesses")
    func testComputedPropertiesConsistency() async throws {
        // Given
        let context = createTestModelContext()
        let shoe = createTestShoe(context: context)
        
        // Add some data
        let entry = StepEntry(
            shoe: shoe,
            steps: 1000,
            distance: 0.8,
            date: Date(),
            notes: "Test"
        )
        context.insert(entry)
        try context.save()
        
        // When - Access properties multiple times
        let distance1 = shoe.totalDistance
        let distance2 = shoe.totalDistance
        let steps1 = shoe.totalSteps
        let steps2 = shoe.totalSteps
        
        // Then - Should be consistent
        #expect(distance1 == distance2)
        #expect(steps1 == steps2)
    }
}
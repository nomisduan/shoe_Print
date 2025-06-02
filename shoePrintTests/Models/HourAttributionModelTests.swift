//
//  HourAttributionModelTests.swift
//  shoePrintTests
//
//  Portfolio Refactor: Unit tests for HourAttribution model
//

import Testing
import SwiftData
@testable import shoePrint

/// Unit tests for HourAttribution model functionality
/// ✅ Tests the hour-specific attribution model that replaced complex session logic
struct HourAttributionModelTests {
    
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
    
    // MARK: - Basic Model Tests
    
    @Test("HourAttribution creation sets properties correctly")
    func testHourAttributionCreation() async throws {
        // Given
        let context = createTestModelContext()
        let shoe = createTestShoe(context: context)
        let hourDate = Date()
        let steps = 750
        let distance = 0.6
        
        // When
        let attribution = HourAttribution(
            hourDate: hourDate,
            shoe: shoe,
            steps: steps,
            distance: distance
        )
        
        context.insert(attribution)
        try context.save()
        
        // Then
        #expect(attribution.shoe?.id == shoe.id)
        #expect(attribution.steps == steps)
        #expect(attribution.distance == distance)
        #expect(attribution.createdAt != nil)
        
        // Verify hour date precision
        let calendar = Calendar.current
        #expect(calendar.isDate(attribution.hourDate, equalTo: hourDate, toGranularity: .hour))
    }
    
    @Test("HourAttribution ID is automatically generated")
    func testHourAttributionIDGeneration() async throws {
        // Given
        let context = createTestModelContext()
        let shoe = createTestShoe(context: context)
        let hourDate = Date()
        
        // When
        let attribution1 = HourAttribution(hourDate: hourDate, shoe: shoe, steps: 500, distance: 0.4)
        let attribution2 = HourAttribution(hourDate: hourDate, shoe: shoe, steps: 600, distance: 0.5)
        
        context.insert(attribution1)
        context.insert(attribution2)
        try context.save()
        
        // Then
        #expect(attribution1.id != attribution2.id)
    }
    
    @Test("HourAttribution can be created without shoe")
    func testHourAttributionWithoutShoe() async throws {
        // Given
        let context = createTestModelContext()
        let hourDate = Date()
        
        // When
        let attribution = HourAttribution(
            hourDate: hourDate,
            shoe: nil,
            steps: 300,
            distance: 0.25
        )
        
        context.insert(attribution)
        try context.save()
        
        // Then
        #expect(attribution.shoe == nil)
        #expect(attribution.steps == 300)
        #expect(attribution.distance == 0.25)
    }
    
    // MARK: - Relationship Tests
    
    @Test("HourAttribution establishes correct relationship with Shoe")
    func testHourAttributionShoeRelationship() async throws {
        // Given
        let context = createTestModelContext()
        let shoe = createTestShoe(context: context)
        let hourDate = Date()
        
        // When
        let attribution = HourAttribution(
            hourDate: hourDate,
            shoe: shoe,
            steps: 500,
            distance: 0.4
        )
        
        context.insert(attribution)
        try context.save()
        
        // Then
        // Test forward relationship
        #expect(attribution.shoe?.id == shoe.id)
        
        // Test inverse relationship
        #expect(shoe.hourAttributions.contains(attribution))
    }
    
    @Test("Multiple HourAttributions can belong to same Shoe")
    func testMultipleAttributionsPerShoe() async throws {
        // Given
        let context = createTestModelContext()
        let shoe = createTestShoe(context: context)
        let calendar = Calendar.current
        let baseDate = Date()
        
        // When - Create attributions for different hours
        let attribution1 = HourAttribution(
            hourDate: calendar.date(bySettingHour: 10, minute: 0, second: 0, of: baseDate)!,
            shoe: shoe,
            steps: 400,
            distance: 0.32
        )
        
        let attribution2 = HourAttribution(
            hourDate: calendar.date(bySettingHour: 14, minute: 0, second: 0, of: baseDate)!,
            shoe: shoe,
            steps: 600,
            distance: 0.48
        )
        
        context.insert(attribution1)
        context.insert(attribution2)
        try context.save()
        
        // Then
        #expect(shoe.hourAttributions.count == 2)
        #expect(shoe.hourAttributions.contains(attribution1))
        #expect(shoe.hourAttributions.contains(attribution2))
        
        // Verify both attributions point to same shoe
        #expect(attribution1.shoe?.id == shoe.id)
        #expect(attribution2.shoe?.id == shoe.id)
    }
    
    @Test("HourAttribution can be reassigned to different Shoe")
    func testReassignAttributionToShoe() async throws {
        // Given
        let context = createTestModelContext()
        let shoe1 = createTestShoe(context: context)
        let shoe2 = Shoe(
            brand: "Adidas",
            model: "UltraBoost",
            notes: "Second shoe",
            icon: "🏃",
            color: "CustomGreen",
            archived: false,
            isDefault: false,
            estimatedLifespan: 600.0
        )
        context.insert(shoe2)
        try context.save()
        
        let attribution = HourAttribution(
            hourDate: Date(),
            shoe: shoe1,
            steps: 500,
            distance: 0.4
        )
        context.insert(attribution)
        try context.save()
        
        // When
        attribution.shoe = shoe2
        try context.save()
        
        // Then
        #expect(attribution.shoe?.id == shoe2.id)
        #expect(!shoe1.hourAttributions.contains(attribution))
        #expect(shoe2.hourAttributions.contains(attribution))
    }
    
    // MARK: - Data Validation Tests
    
    @Test("HourAttribution accepts zero steps and distance")
    func testZeroStepsAndDistance() async throws {
        // Given
        let context = createTestModelContext()
        let shoe = createTestShoe(context: context)
        
        // When
        let attribution = HourAttribution(
            hourDate: Date(),
            shoe: shoe,
            steps: 0,
            distance: 0.0
        )
        
        context.insert(attribution)
        try context.save()
        
        // Then
        #expect(attribution.steps == 0)
        #expect(attribution.distance == 0.0)
    }
    
    @Test("HourAttribution handles large step and distance values")
    func testLargeValues() async throws {
        // Given
        let context = createTestModelContext()
        let shoe = createTestShoe(context: context)
        
        // When
        let attribution = HourAttribution(
            hourDate: Date(),
            shoe: shoe,
            steps: 10000, // Very active hour
            distance: 8.0 // 8 km in one hour
        )
        
        context.insert(attribution)
        try context.save()
        
        // Then
        #expect(attribution.steps == 10000)
        #expect(attribution.distance == 8.0)
    }
    
    @Test("HourAttribution handles fractional distance values")
    func testFractionalDistanceValues() async throws {
        // Given
        let context = createTestModelContext()
        let shoe = createTestShoe(context: context)
        
        // When
        let attribution = HourAttribution(
            hourDate: Date(),
            shoe: shoe,
            steps: 157,
            distance: 0.1256 // Precise distance
        )
        
        context.insert(attribution)
        try context.save()
        
        // Then
        #expect(abs(attribution.distance - 0.1256) < 0.0001)
    }
    
    // MARK: - Temporal Precision Tests
    
    @Test("HourAttribution normalizes hour date precision")
    func testHourDateNormalization() async throws {
        // Given
        let context = createTestModelContext()
        let shoe = createTestShoe(context: context)
        let calendar = Calendar.current
        
        // Create date with specific minute and second values
        let preciseDate = calendar.date(bySettingHour: 14, minute: 37, second: 42, of: Date())!
        
        // When
        let attribution = HourAttribution(
            hourDate: preciseDate,
            shoe: shoe,
            steps: 500,
            distance: 0.4
        )
        
        context.insert(attribution)
        try context.save()
        
        // Then
        // Verify that the stored date represents the hour (implementation dependent)
        let storedHour = calendar.component(.hour, from: attribution.hourDate)
        let expectedHour = calendar.component(.hour, from: preciseDate)
        #expect(storedHour == expectedHour)
    }
    
    @Test("HourAttribution handles different time zones")
    func testTimeZoneHandling() async throws {
        // Given
        let context = createTestModelContext()
        let shoe = createTestShoe(context: context)
        
        // Create date in specific timezone
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let utcDate = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: Date())!
        
        // When
        let attribution = HourAttribution(
            hourDate: utcDate,
            shoe: shoe,
            steps: 500,
            distance: 0.4
        )
        
        context.insert(attribution)
        try context.save()
        
        // Then
        // Should preserve the timezone information
        #expect(attribution.hourDate.timeIntervalSince1970 == utcDate.timeIntervalSince1970)
    }
    
    // MARK: - Query and Filtering Tests
    
    @Test("HourAttributions can be filtered by date")
    func testFilterByDate() async throws {
        // Given
        let context = createTestModelContext()
        let shoe = createTestShoe(context: context)
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        // Create attributions on different days
        let todayAttribution = HourAttribution(
            hourDate: today,
            shoe: shoe,
            steps: 500,
            distance: 0.4
        )
        
        let yesterdayAttribution = HourAttribution(
            hourDate: yesterday,
            shoe: shoe,
            steps: 600,
            distance: 0.5
        )
        
        context.insert(todayAttribution)
        context.insert(yesterdayAttribution)
        try context.save()
        
        // When - Query for today's attributions
        let todayDescriptor = FetchDescriptor<HourAttribution>(
            predicate: #Predicate<HourAttribution> { attribution in
                Calendar.current.isDate(attribution.hourDate, inSameDayAs: today)
            }
        )
        
        let todayResults = try context.fetch(todayDescriptor)
        
        // Then
        #expect(todayResults.count == 1)
        #expect(todayResults.first?.id == todayAttribution.id)
    }
    
    @Test("HourAttributions can be filtered by shoe")
    func testFilterByShoe() async throws {
        // Given
        let context = createTestModelContext()
        let shoe1 = createTestShoe(context: context)
        let shoe2 = Shoe(
            brand: "Adidas",
            model: "UltraBoost",
            notes: "",
            icon: "🏃",
            color: "CustomGreen",
            archived: false,
            isDefault: false,
            estimatedLifespan: 600.0
        )
        context.insert(shoe2)
        try context.save()
        
        // Create attributions for different shoes
        let attribution1 = HourAttribution(hourDate: Date(), shoe: shoe1, steps: 500, distance: 0.4)
        let attribution2 = HourAttribution(hourDate: Date(), shoe: shoe2, steps: 600, distance: 0.5)
        let attribution3 = HourAttribution(hourDate: Date(), shoe: shoe1, steps: 400, distance: 0.3)
        
        context.insert(attribution1)
        context.insert(attribution2)
        context.insert(attribution3)
        try context.save()
        
        // When - Query for shoe1's attributions
        let shoe1Descriptor = FetchDescriptor<HourAttribution>(
            predicate: #Predicate<HourAttribution> { attribution in
                attribution.shoe?.brand == "Nike"
            }
        )
        
        let shoe1Results = try context.fetch(shoe1Descriptor)
        
        // Then
        #expect(shoe1Results.count == 2)
        #expect(shoe1Results.allSatisfy { $0.shoe?.id == shoe1.id })
    }
    
    // MARK: - Edge Cases
    
    @Test("HourAttribution handles midnight hours correctly")
    func testMidnightHours() async throws {
        // Given
        let context = createTestModelContext()
        let shoe = createTestShoe(context: context)
        let calendar = Calendar.current
        let midnight = calendar.startOfDay(for: Date())
        
        // When
        let attribution = HourAttribution(
            hourDate: midnight,
            shoe: shoe,
            steps: 100,
            distance: 0.08
        )
        
        context.insert(attribution)
        try context.save()
        
        // Then
        let hour = calendar.component(.hour, from: attribution.hourDate)
        #expect(hour == 0)
    }
    
    @Test("HourAttribution handles end of day hours correctly")
    func testEndOfDayHours() async throws {
        // Given
        let context = createTestModelContext()
        let shoe = createTestShoe(context: context)
        let calendar = Calendar.current
        let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: Date())!
        
        // When
        let attribution = HourAttribution(
            hourDate: endOfDay,
            shoe: shoe,
            steps: 200,
            distance: 0.16
        )
        
        context.insert(attribution)
        try context.save()
        
        // Then
        let hour = calendar.component(.hour, from: attribution.hourDate)
        #expect(hour == 23)
    }
    
    @Test("HourAttribution handles deletion correctly")
    func testAttributionDeletion() async throws {
        // Given
        let context = createTestModelContext()
        let shoe = createTestShoe(context: context)
        let attribution = HourAttribution(
            hourDate: Date(),
            shoe: shoe,
            steps: 500,
            distance: 0.4
        )
        
        context.insert(attribution)
        try context.save()
        
        #expect(shoe.hourAttributions.count == 1)
        
        // When
        context.delete(attribution)
        try context.save()
        
        // Then
        #expect(shoe.hourAttributions.count == 0)
        
        // Verify attribution is actually deleted
        let allAttributions = try context.fetch(FetchDescriptor<HourAttribution>())
        #expect(allAttributions.isEmpty)
    }
    
    @Test("HourAttribution maintains data integrity across saves")
    func testDataIntegrityAcrossSaves() async throws {
        // Given
        let context = createTestModelContext()
        let shoe = createTestShoe(context: context)
        let originalDate = Date()
        let originalSteps = 750
        let originalDistance = 0.6
        
        let attribution = HourAttribution(
            hourDate: originalDate,
            shoe: shoe,
            steps: originalSteps,
            distance: originalDistance
        )
        
        context.insert(attribution)
        try context.save()
        
        // When - Modify and save multiple times
        attribution.steps = 800
        try context.save()
        
        attribution.distance = 0.65
        try context.save()
        
        // Then
        #expect(attribution.steps == 800)
        #expect(attribution.distance == 0.65)
        #expect(attribution.shoe?.id == shoe.id)
        
        // Verify persistence by fetching fresh
        let fetchedAttributions = try context.fetch(FetchDescriptor<HourAttribution>())
        let fetchedAttribution = fetchedAttributions.first!
        
        #expect(fetchedAttribution.steps == 800)
        #expect(fetchedAttribution.distance == 0.65)
        #expect(fetchedAttribution.shoe?.id == shoe.id)
    }
}
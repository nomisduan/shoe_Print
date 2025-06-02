//
//  AttributionServiceTests.swift
//  shoePrintTests
//
//  Portfolio Refactor: Unit tests for AttributionService business logic
//

import Testing
import Foundation
@testable import shoePrint

/// Unit tests for attribution service business logic
/// ✅ Tests hourly attribution logic, data enrichment, and temporal operations
struct AttributionServiceTests {
    
    // MARK: - Test Setup
    
    private func createTestService() -> (AttributionService, MockAttributionRepository) {
        let repository = MockAttributionRepository()
        repository.reset()
        let service = AttributionService(attributionRepository: repository)
        return (service, repository)
    }
    
    // MARK: - Attribution Creation Tests
    
    @Test("Attribute hour creates new attribution")
    func testAttributeHour() async throws {
        // Given
        let (service, repository) = createTestService()
        let shoe = TestFixtures.createTestShoe()
        let calendar = Calendar.current
        let hourDate = calendar.date(bySettingHour: 14, minute: 30, second: 45, of: Date())!
        
        // When
        try await service.attributeHour(hourDate, to: shoe)
        
        // Then
        let attributions = try await repository.fetchAttributions(for: Date())
        #expect(attributions.count == 1)
        
        let attribution = attributions.first!
        #expect(attribution.shoe?.id == shoe.id)
        
        // Verify hour precision (minutes/seconds should be normalized)
        let expectedHour = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: Date())!
        #expect(calendar.isDate(attribution.hourDate, equalTo: expectedHour, toGranularity: .hour))
    }
    
    @Test("Attribute hour overwrites existing attribution")
    func testAttributeHourOverwrites() async throws {
        // Given
        let (service, repository) = createTestService()
        let originalShoe = TestFixtures.createTestShoe(brand: "Original")
        let newShoe = TestFixtures.createTestShoe(brand: "New")
        let hourDate = Date()
        
        // Create existing attribution
        let existingAttribution = TestFixtures.createTestAttribution(
            hourDate: hourDate,
            shoe: originalShoe,
            steps: 300
        )
        repository.addTestAttribution(existingAttribution)
        
        // When
        try await service.attributeHour(hourDate, to: newShoe)
        
        // Then
        let attributions = try await repository.fetchAttributions(for: Date())
        #expect(attributions.count == 1) // Should still be 1 (overwritten)
        #expect(attributions.first?.shoe?.id == newShoe.id)
    }
    
    @Test("Attribute multiple hours creates multiple attributions")
    func testAttributeMultipleHours() async throws {
        // Given
        let (service, repository) = createTestService()
        let shoe = TestFixtures.createTestShoe()
        let calendar = Calendar.current
        let baseDate = Date()
        
        let hourDates = [
            calendar.date(bySettingHour: 10, minute: 0, second: 0, of: baseDate)!,
            calendar.date(bySettingHour: 14, minute: 0, second: 0, of: baseDate)!,
            calendar.date(bySettingHour: 18, minute: 0, second: 0, of: baseDate)!
        ]
        
        // When
        try await service.attributeHours(hourDates, to: shoe)
        
        // Then
        let attributions = try await repository.fetchAttributions(for: baseDate)
        #expect(attributions.count == 3)
        #expect(attributions.allSatisfy { $0.shoe?.id == shoe.id })
        
        // Verify all hours are covered
        let attributedHours = Set(attributions.map { calendar.component(.hour, from: $0.hourDate) })
        #expect(attributedHours.contains(10))
        #expect(attributedHours.contains(14))
        #expect(attributedHours.contains(18))
    }
    
    // MARK: - Attribution Removal Tests
    
    @Test("Remove attribution for hour deletes existing attribution")
    func testRemoveAttributionForHour() async throws {
        // Given
        let (service, repository) = createTestService()
        let shoe = TestFixtures.createTestShoe()
        let hourDate = Date()
        
        // Create existing attribution
        let attribution = TestFixtures.createTestAttribution(hourDate: hourDate, shoe: shoe)
        repository.addTestAttribution(attribution)
        
        // When
        try await service.removeAttribution(for: hourDate)
        
        // Then
        let attributions = try await repository.fetchAttributions(for: Date())
        #expect(attributions.isEmpty)
    }
    
    @Test("Remove attribution for hour with no attribution does nothing")
    func testRemoveAttributionForHourWithNoAttribution() async throws {
        // Given
        let (service, _) = createTestService()
        let hourDate = Date()
        
        // When - Should not throw error
        try await service.removeAttribution(for: hourDate)
        
        // Then - Should complete successfully
        #expect(true) // If we reach here, no error was thrown
    }
    
    @Test("Remove attributions for multiple hours")
    func testRemoveAttributionsForMultipleHours() async throws {
        // Given
        let (service, repository) = createTestService()
        let shoe = TestFixtures.createTestShoe()
        let calendar = Calendar.current
        let baseDate = Date()
        
        // Create attributions for hours 10, 11, 12, 13
        for hour in 10...13 {
            let hourDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: baseDate)!
            let attribution = TestFixtures.createTestAttribution(hourDate: hourDate, shoe: shoe)
            repository.addTestAttribution(attribution)
        }
        
        // Hours to remove: 10, 12
        let hoursToRemove = [
            calendar.date(bySettingHour: 10, minute: 0, second: 0, of: baseDate)!,
            calendar.date(bySettingHour: 12, minute: 0, second: 0, of: baseDate)!
        ]
        
        // When
        try await service.removeAttributions(for: hoursToRemove)
        
        // Then
        let remainingAttributions = try await repository.fetchAttributions(for: baseDate)
        #expect(remainingAttributions.count == 2)
        
        let remainingHours = Set(remainingAttributions.map { calendar.component(.hour, from: $0.hourDate) })
        #expect(remainingHours.contains(11))
        #expect(remainingHours.contains(13))
        #expect(!remainingHours.contains(10))
        #expect(!remainingHours.contains(12))
    }
    
    // MARK: - Data Enrichment Tests
    
    @Test("Apply attributions enriches hourly step data")
    func testApplyAttributions() async throws {
        // Given
        let (service, repository) = createTestService()
        let shoe = TestFixtures.createTestShoe()
        let baseDate = Date()
        
        // Create some attributions
        let calendar = Calendar.current
        let hour14 = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: baseDate)!
        let hour16 = calendar.date(bySettingHour: 16, minute: 0, second: 0, of: baseDate)!
        
        let attribution14 = TestFixtures.createTestAttribution(hourDate: hour14, shoe: shoe)
        let attribution16 = TestFixtures.createTestAttribution(hourDate: hour16, shoe: shoe)
        repository.addTestAttribution(attribution14)
        repository.addTestAttribution(attribution16)
        
        // Create raw hourly step data
        let rawData = TestFixtures.createHourlyStepData(for: baseDate)
        
        // When
        let enrichedData = await service.applyAttributions(to: rawData, for: baseDate)
        
        // Then
        #expect(enrichedData.count == rawData.count)
        
        // Find the enriched hours
        let enrichedHour14 = enrichedData.first { $0.hour == 14 }
        let enrichedHour16 = enrichedData.first { $0.hour == 16 }
        let unenrichedHour10 = enrichedData.first { $0.hour == 10 }
        
        #expect(enrichedHour14?.assignedShoe?.id == shoe.id)
        #expect(enrichedHour16?.assignedShoe?.id == shoe.id)
        #expect(unenrichedHour10?.assignedShoe == nil)
    }
    
    @Test("Apply attributions preserves original data structure")
    func testApplyAttributionsPreservesData() async throws {
        // Given
        let (service, _) = createTestService()
        let baseDate = Date()
        let rawData = TestFixtures.createHourlyStepData(for: baseDate)
        
        // When
        let enrichedData = await service.applyAttributions(to: rawData, for: baseDate)
        
        // Then
        #expect(enrichedData.count == rawData.count)
        
        for (original, enriched) in zip(rawData, enrichedData) {
            #expect(enriched.id == original.id)
            #expect(enriched.hour == original.hour)
            #expect(enriched.steps == original.steps)
            #expect(enriched.distance == original.distance)
            
            // Date should be same hour (might have different minute/second precision)
            let calendar = Calendar.current
            #expect(calendar.isDate(enriched.date, equalTo: original.date, toGranularity: .hour))
        }
    }
    
    @Test("Apply attributions handles empty raw data")
    func testApplyAttributionsEmptyRawData() async throws {
        // Given
        let (service, _) = createTestService()
        let baseDate = Date()
        let emptyData: [HourlyStepData] = []
        
        // When
        let enrichedData = await service.applyAttributions(to: emptyData, for: baseDate)
        
        // Then
        #expect(enrichedData.isEmpty)
    }
    
    @Test("Apply attributions handles missing attributions gracefully")
    func testApplyAttributionsMissingAttributions() async throws {
        // Given
        let (service, _) = createTestService()
        let baseDate = Date()
        let rawData = TestFixtures.createHourlyStepData(for: baseDate)
        
        // When - No attributions exist in repository
        let enrichedData = await service.applyAttributions(to: rawData, for: baseDate)
        
        // Then
        #expect(enrichedData.count == rawData.count)
        #expect(enrichedData.allSatisfy { $0.assignedShoe == nil })
    }
    
    // MARK: - Temporal Precision Tests
    
    @Test("Service normalizes hour dates correctly")
    func testHourDateNormalization() async throws {
        // Given
        let (service, repository) = createTestService()
        let shoe = TestFixtures.createTestShoe()
        let calendar = Calendar.current
        
        // Create date with non-zero minutes and seconds
        let messyDate = calendar.date(bySettingHour: 14, minute: 37, second: 42, of: Date())!
        
        // When
        try await service.attributeHour(messyDate, to: shoe)
        
        // Then
        let attributions = try await repository.fetchAttributions(for: Date())
        let attribution = attributions.first!
        
        // Should be normalized to exact hour
        let normalizedHour = calendar.component(.hour, from: attribution.hourDate)
        let normalizedMinute = calendar.component(.minute, from: attribution.hourDate)
        let normalizedSecond = calendar.component(.second, from: attribution.hourDate)
        
        #expect(normalizedHour == 14)
        #expect(normalizedMinute == 0)
        #expect(normalizedSecond == 0)
    }
    
    @Test("Service handles cross-day hour operations")
    func testCrossDayHourOperations() async throws {
        // Given
        let (service, repository) = createTestService()
        let shoe = TestFixtures.createTestShoe()
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        // Create attributions on different days
        let todayHour = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: today)!
        let yesterdayHour = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: yesterday)!
        
        // When
        try await service.attributeHour(todayHour, to: shoe)
        try await service.attributeHour(yesterdayHour, to: shoe)
        
        // Then
        let todayAttributions = try await repository.fetchAttributions(for: today)
        let yesterdayAttributions = try await repository.fetchAttributions(for: yesterday)
        
        #expect(todayAttributions.count == 1)
        #expect(yesterdayAttributions.count == 1)
        #expect(todayAttributions.first?.id != yesterdayAttributions.first?.id)
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Service handles repository errors")
    func testRepositoryErrorHandling() async throws {
        // Given
        let (service, repository) = createTestService()
        let shoe = TestFixtures.createTestShoe()
        let hourDate = Date()
        let expectedError = AppError.dataNotFound("Repository error")
        repository.setShouldThrowError(true, error: expectedError)
        
        // When/Then
        await #expect(throws: AppError.self) {
            try await service.attributeHour(hourDate, to: shoe)
        }
    }
    
    @Test("Service propagates specific error types")
    func testSpecificErrorPropagation() async throws {
        // Given
        let (service, repository) = createTestService()
        let shoe = TestFixtures.createTestShoe()
        let hourDate = Date()
        let specificError = AppError.validationFailed("Specific validation error")
        repository.setShouldThrowError(true, error: specificError)
        
        // When/Then
        do {
            try await service.attributeHour(hourDate, to: shoe)
            #expect(Bool(false), "Should have thrown an error")
        } catch let error as AppError {
            if case .validationFailed(let message) = error {
                #expect(message == "Specific validation error")
            } else {
                #expect(Bool(false), "Wrong error type: \(error)")
            }
        }
    }
    
    // MARK: - Edge Cases
    
    @Test("Service handles attribution at midnight")
    func testAttributionAtMidnight() async throws {
        // Given
        let (service, repository) = createTestService()
        let shoe = TestFixtures.createTestShoe()
        let calendar = Calendar.current
        let midnight = calendar.startOfDay(for: Date())
        
        // When
        try await service.attributeHour(midnight, to: shoe)
        
        // Then
        let attributions = try await repository.fetchAttributions(for: Date())
        #expect(attributions.count == 1)
        
        let attribution = attributions.first!
        let hour = calendar.component(.hour, from: attribution.hourDate)
        #expect(hour == 0)
    }
    
    @Test("Service handles attribution near DST boundaries")
    func testAttributionNearDSTBoundaries() async throws {
        // Given
        let (service, repository) = createTestService()
        let shoe = TestFixtures.createTestShoe()
        let calendar = Calendar.current
        
        // Use a specific date that might be near DST (November 1st)
        let dstDate = DateComponents(calendar: calendar, year: 2024, month: 11, day: 1, hour: 2).date!
        
        // When
        try await service.attributeHour(dstDate, to: shoe)
        
        // Then
        let attributions = try await repository.fetchAttributions(for: dstDate)
        #expect(attributions.count == 1)
        
        let attribution = attributions.first!
        let hour = calendar.component(.hour, from: attribution.hourDate)
        #expect(hour == 2)
    }
    
    @Test("Service handles large batch operations")
    func testLargeBatchOperations() async throws {
        // Given
        let (service, repository) = createTestService()
        let shoe = TestFixtures.createTestShoe()
        let calendar = Calendar.current
        let baseDate = Date()
        
        // Create 24 hours (full day)
        let hourDates = (0..<24).compactMap { hour in
            calendar.date(bySettingHour: hour, minute: 0, second: 0, of: baseDate)
        }
        
        // When
        try await service.attributeHours(hourDates, to: shoe)
        
        // Then
        let attributions = try await repository.fetchAttributions(for: baseDate)
        #expect(attributions.count == 24)
        #expect(attributions.allSatisfy { $0.shoe?.id == shoe.id })
        
        // Verify all hours are present
        let attributedHours = Set(attributions.map { calendar.component(.hour, from: $0.hourDate) })
        #expect(attributedHours.count == 24)
        for hour in 0..<24 {
            #expect(attributedHours.contains(hour))
        }
    }
    
    @Test("Service handles concurrent attribution operations")
    func testConcurrentAttributionOperations() async throws {
        // Given
        let (service, repository) = createTestService()
        let shoes = TestFixtures.createTestShoeCollection()
        let calendar = Calendar.current
        let baseDate = Date()
        
        // When - Attribute different hours concurrently
        let tasks = (10..<14).map { hour in
            Task {
                let hourDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: baseDate)!
                let shoe = shoes[hour % shoes.count]
                try await service.attributeHour(hourDate, to: shoe)
            }
        }
        
        // Wait for all tasks to complete
        try await withThrowingTaskGroup(of: Void.self) { group in
            for task in tasks {
                group.addTask { try await task.value }
            }
            
            for try await _ in group {
                // Wait for completion
            }
        }
        
        // Then
        let attributions = try await repository.fetchAttributions(for: baseDate)
        #expect(attributions.count == 4) // Hours 10, 11, 12, 13
        
        let attributedHours = Set(attributions.map { calendar.component(.hour, from: $0.hourDate) })
        #expect(attributedHours.contains(10))
        #expect(attributedHours.contains(11))
        #expect(attributedHours.contains(12))
        #expect(attributedHours.contains(13))
    }
}
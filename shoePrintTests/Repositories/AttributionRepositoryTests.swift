//
//  AttributionRepositoryTests.swift
//  shoePrintTests
//
//  Portfolio Refactor: Unit tests for AttributionRepository functionality
//

import Testing
import Foundation
@testable import shoePrint

/// Unit tests for attribution repository functionality  
/// ✅ Tests hourly attribution data access with temporal precision
struct AttributionRepositoryTests {
    
    // MARK: - Test Setup
    
    private func createTestRepository() -> MockAttributionRepository {
        let repository = MockAttributionRepository()
        repository.reset()
        return repository
    }
    
    private func createTestShoes() -> [Shoe] {
        return TestFixtures.createTestShoeCollection()
    }
    
    // MARK: - Fetch Attribution Tests
    
    @Test("Fetch attributions for date returns day's attributions")
    func testFetchAttributionsForDate() async throws {
        // Given
        let repository = createTestRepository()
        let shoes = createTestShoes()
        let targetDate = Date()
        let calendar = Calendar.current
        
        // Create attributions for target date
        let todayAttributions = TestFixtures.createDayAttributions(date: targetDate, shoes: Array(shoes.prefix(2)))
        for attribution in todayAttributions {
            repository.addTestAttribution(attribution)
        }
        
        // Create attribution for different date
        let yesterday = calendar.date(byAdding: .day, value: -1, to: targetDate)!
        let yesterdayAttribution = TestFixtures.createTestAttribution(
            hourDate: yesterday,
            shoe: shoes[0]
        )
        repository.addTestAttribution(yesterdayAttribution)
        
        // When
        let result = try await repository.fetchAttributions(for: targetDate)
        
        // Then
        #expect(result.count == todayAttributions.count)
        
        // Verify all returned attributions are from target date
        for attribution in result {
            #expect(calendar.isDate(attribution.hourDate, inSameDayAs: targetDate))
        }
    }
    
    @Test("Fetch attribution for specific hour returns correct attribution")
    func testFetchAttributionForHour() async throws {
        // Given
        let repository = createTestRepository()
        let shoe = TestFixtures.createTestShoe()
        let calendar = Calendar.current
        let targetDate = Date()
        
        // Create attribution for specific hour
        let targetHour = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: targetDate)!
        let attribution = TestFixtures.createTestAttribution(
            hourDate: targetHour,
            shoe: shoe,
            steps: 750,
            distance: 0.6
        )
        repository.addTestAttribution(attribution)
        
        // Create attribution for different hour
        let differentHour = calendar.date(bySettingHour: 15, minute: 0, second: 0, of: targetDate)!
        let differentAttribution = TestFixtures.createTestAttribution(
            hourDate: differentHour,
            shoe: shoe
        )
        repository.addTestAttribution(differentAttribution)
        
        // When
        let result = try await repository.fetchAttribution(for: targetHour)
        
        // Then
        #expect(result != nil)
        #expect(result?.steps == 750)
        #expect(result?.distance == 0.6)
        #expect(result?.shoe?.id == shoe.id)
    }
    
    @Test("Fetch attribution for hour without attribution returns nil")
    func testFetchAttributionForHourWithoutAttribution() async throws {
        // Given
        let repository = createTestRepository()
        let calendar = Calendar.current
        let targetHour = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: Date())!
        
        // When
        let result = try await repository.fetchAttribution(for: targetHour)
        
        // Then
        #expect(result == nil)
    }
    
    // MARK: - Create Attribution Tests
    
    @Test("Create attribution successfully creates new attribution")
    func testCreateAttribution() async throws {
        // Given
        let repository = createTestRepository()
        let shoe = TestFixtures.createTestShoe()
        let hourDate = Date()
        let steps = 500
        let distance = 0.4
        
        // When
        let result = try await repository.createAttribution(
            hourDate: hourDate,
            shoe: shoe,
            steps: steps,
            distance: distance
        )
        
        // Then
        #expect(result.shoe?.id == shoe.id)
        #expect(result.steps == steps)
        #expect(result.distance == distance)
        
        // Verify hour precision (same hour, ignore minutes/seconds)
        let calendar = Calendar.current
        #expect(calendar.isDate(result.hourDate, equalTo: hourDate, toGranularity: .hour))
    }
    
    @Test("Create attribution with zero steps")
    func testCreateAttributionWithZeroSteps() async throws {
        // Given
        let repository = createTestRepository()
        let shoe = TestFixtures.createTestShoe()
        let hourDate = Date()
        
        // When
        let result = try await repository.createAttribution(
            hourDate: hourDate,
            shoe: shoe,
            steps: 0,
            distance: 0.0
        )
        
        // Then
        #expect(result.steps == 0)
        #expect(result.distance == 0.0)
        #expect(result.shoe?.id == shoe.id)
    }
    
    // MARK: - Update Attribution Tests
    
    @Test("Update attribution modifies properties correctly")
    func testUpdateAttribution() async throws {
        // Given
        let repository = createTestRepository()
        let originalShoe = TestFixtures.createTestShoe(brand: "Original")
        let newShoe = TestFixtures.createTestShoe(brand: "Updated")
        
        let attribution = TestFixtures.createTestAttribution(
            shoe: originalShoe,
            steps: 300,
            distance: 0.24
        )
        repository.addTestAttribution(attribution)
        
        // When
        try await repository.updateAttribution(
            attribution,
            shoe: newShoe,
            steps: 600,
            distance: 0.48
        )
        
        // Then
        #expect(attribution.shoe?.id == newShoe.id)
        #expect(attribution.steps == 600)
        #expect(attribution.distance == 0.48)
    }
    
    @Test("Update attribution with nil values preserves existing properties")
    func testUpdateAttributionWithNilValues() async throws {
        // Given
        let repository = createTestRepository()
        let shoe = TestFixtures.createTestShoe()
        let attribution = TestFixtures.createTestAttribution(
            shoe: shoe,
            steps: 300,
            distance: 0.24
        )
        repository.addTestAttribution(attribution)
        
        // When - only update steps, preserve shoe and distance
        try await repository.updateAttribution(
            attribution,
            shoe: nil,
            steps: 500,
            distance: nil
        )
        
        // Then
        #expect(attribution.shoe?.id == shoe.id) // Preserved
        #expect(attribution.steps == 500) // Updated
        #expect(attribution.distance == 0.24) // Preserved
    }
    
    // MARK: - Delete Attribution Tests
    
    @Test("Delete attribution removes from collection")
    func testDeleteAttribution() async throws {
        // Given
        let repository = createTestRepository()
        let shoe = TestFixtures.createTestShoe()
        let attribution = TestFixtures.createTestAttribution(shoe: shoe)
        repository.addTestAttribution(attribution)
        
        let initialAttributions = try await repository.fetchAttributions(for: Date())
        #expect(initialAttributions.count == 1)
        
        // When
        try await repository.deleteAttribution(attribution)
        
        // Then
        let finalAttributions = try await repository.fetchAttributions(for: Date())
        #expect(finalAttributions.count == 0)
    }
    
    @Test("Delete attributions for multiple hours")
    func testDeleteAttributionsForHours() async throws {
        // Given
        let repository = createTestRepository()
        let shoe = TestFixtures.createTestShoe()
        let calendar = Calendar.current
        let baseDate = Date()
        
        // Create attributions for hours 10, 11, 12, 13
        let hours = [10, 11, 12, 13]
        var attributions: [HourAttribution] = []
        
        for hour in hours {
            let hourDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: baseDate)!
            let attribution = TestFixtures.createTestAttribution(hourDate: hourDate, shoe: shoe)
            repository.addTestAttribution(attribution)
            attributions.append(attribution)
        }
        
        // Hours to delete: 10, 12 (should leave 11, 13)
        let hoursToDelete = [
            calendar.date(bySettingHour: 10, minute: 0, second: 0, of: baseDate)!,
            calendar.date(bySettingHour: 12, minute: 0, second: 0, of: baseDate)!
        ]
        
        // When
        try await repository.deleteAttributions(for: hoursToDelete)
        
        // Then
        let remainingAttributions = try await repository.fetchAttributions(for: baseDate)
        #expect(remainingAttributions.count == 2)
        
        // Verify correct hours remain
        let remainingHours = remainingAttributions.map { calendar.component(.hour, from: $0.hourDate) }
        #expect(remainingHours.contains(11))
        #expect(remainingHours.contains(13))
        #expect(!remainingHours.contains(10))
        #expect(!remainingHours.contains(12))
    }
    
    // MARK: - Temporal Precision Tests
    
    @Test("Attribution respects hour-level granularity")
    func testAttributionHourGranularity() async throws {
        // Given
        let repository = createTestRepository()
        let shoe = TestFixtures.createTestShoe()
        let calendar = Calendar.current
        let baseDate = Date()
        
        // Create attribution at exact hour
        let exactHour = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: baseDate)!
        let attribution = TestFixtures.createTestAttribution(hourDate: exactHour, shoe: shoe)
        repository.addTestAttribution(attribution)
        
        // Test queries with different minute/second values in same hour
        let sameHourDifferentMinute = calendar.date(bySettingHour: 14, minute: 30, second: 45, of: baseDate)!
        
        // When
        let result = try await repository.fetchAttribution(for: sameHourDifferentMinute)
        
        // Then
        #expect(result != nil)
        #expect(result?.shoe?.id == shoe.id)
    }
    
    @Test("Attribution distinguishes between different hours")
    func testAttributionHourDistinction() async throws {
        // Given
        let repository = createTestRepository()
        let shoe = TestFixtures.createTestShoe()
        let calendar = Calendar.current
        let baseDate = Date()
        
        // Create attribution at 14:00
        let hour14 = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: baseDate)!
        let attribution14 = TestFixtures.createTestAttribution(hourDate: hour14, shoe: shoe, steps: 400)
        repository.addTestAttribution(attribution14)
        
        // Create attribution at 15:00
        let hour15 = calendar.date(bySettingHour: 15, minute: 0, second: 0, of: baseDate)!
        let attribution15 = TestFixtures.createTestAttribution(hourDate: hour15, shoe: shoe, steps: 600)
        repository.addTestAttribution(attribution15)
        
        // When
        let result14 = try await repository.fetchAttribution(for: hour14)
        let result15 = try await repository.fetchAttribution(for: hour15)
        
        // Then
        #expect(result14?.steps == 400)
        #expect(result15?.steps == 600)
        #expect(result14?.id != result15?.id)
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Repository throws expected errors")
    func testRepositoryErrorHandling() async throws {
        // Given
        let repository = createTestRepository()
        let shoe = TestFixtures.createTestShoe()
        let hourDate = Date()
        let expectedError = AppError.dataNotFound("Test error")
        repository.setShouldThrowError(true, error: expectedError)
        
        // When/Then
        await #expect(throws: AppError.self) {
            try await repository.fetchAttributions(for: Date())
        }
        
        await #expect(throws: AppError.self) {
            try await repository.createAttribution(
                hourDate: hourDate,
                shoe: shoe,
                steps: 500,
                distance: 0.4
            )
        }
    }
    
    // MARK: - Edge Cases
    
    @Test("Repository handles empty attribution collection")
    func testEmptyAttributionCollection() async throws {
        // Given
        let repository = createTestRepository()
        let hourDate = Date()
        
        // When
        let attributions = try await repository.fetchAttributions(for: Date())
        let attribution = try await repository.fetchAttribution(for: hourDate)
        
        // Then
        #expect(attributions.isEmpty)
        #expect(attribution == nil)
    }
    
    @Test("Handles attributions across date boundaries")
    func testAttributionsAcrossDateBoundaries() async throws {
        // Given
        let repository = createTestRepository()
        let shoe = TestFixtures.createTestShoe()
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        // Create attributions on different days
        let todayAttribution = TestFixtures.createTestAttribution(hourDate: today, shoe: shoe)
        let yesterdayAttribution = TestFixtures.createTestAttribution(hourDate: yesterday, shoe: shoe)
        
        repository.addTestAttribution(todayAttribution)
        repository.addTestAttribution(yesterdayAttribution)
        
        // When
        let todayResults = try await repository.fetchAttributions(for: today)
        let yesterdayResults = try await repository.fetchAttributions(for: yesterday)
        
        // Then
        #expect(todayResults.count == 1)
        #expect(yesterdayResults.count == 1)
        #expect(todayResults.first?.id != yesterdayResults.first?.id)
    }
    
    @Test("Handles multiple attributions for same shoe on same day")
    func testMultipleAttributionsSameShoeDay() async throws {
        // Given
        let repository = createTestRepository()
        let shoe = TestFixtures.createTestShoe()
        let calendar = Calendar.current
        let baseDate = Date()
        
        // Create multiple attributions for same shoe, different hours
        let attribution1 = TestFixtures.createTestAttribution(
            hourDate: calendar.date(bySettingHour: 10, minute: 0, second: 0, of: baseDate)!,
            shoe: shoe,
            steps: 300
        )
        let attribution2 = TestFixtures.createTestAttribution(
            hourDate: calendar.date(bySettingHour: 14, minute: 0, second: 0, of: baseDate)!,
            shoe: shoe,
            steps: 500
        )
        
        repository.addTestAttribution(attribution1)
        repository.addTestAttribution(attribution2)
        
        // When
        let dayAttributions = try await repository.fetchAttributions(for: baseDate)
        
        // Then
        #expect(dayAttributions.count == 2)
        let totalSteps = dayAttributions.reduce(0) { $0 + $1.steps }
        #expect(totalSteps == 800) // 300 + 500
    }
}
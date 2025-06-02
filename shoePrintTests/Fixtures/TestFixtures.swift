//
//  TestFixtures.swift
//  shoePrintTests
//
//  Portfolio Refactor: Test fixtures and mock data for consistent testing
//

import Foundation
@testable import shoePrint

/// Test fixtures providing consistent mock data for testing
/// ✅ Centralized test data creation for maintainable tests
struct TestFixtures {
    
    // MARK: - Shoe Fixtures
    
    static func createTestShoe(
        brand: String = "Nike",
        model: String = "Air Max",
        notes: String = "Test shoe",
        icon: String = "👟",
        color: String = "CustomBlue",
        archived: Bool = false,
        isDefault: Bool = false,
        estimatedLifespan: Double = 500.0
    ) -> Shoe {
        return Shoe(
            brand: brand,
            model: model,
            notes: notes,
            icon: icon,
            color: color,
            archived: archived,
            isDefault: isDefault,
            estimatedLifespan: estimatedLifespan
        )
    }
    
    /// Creates a collection of diverse test shoes
    static func createTestShoeCollection() -> [Shoe] {
        return [
            createTestShoe(brand: "Nike", model: "Air Max", icon: "👟", color: "CustomBlue"),
            createTestShoe(brand: "Adidas", model: "UltraBoost", icon: "🏃", color: "CustomGreen"),
            createTestShoe(brand: "Converse", model: "Chuck Taylor", icon: "⭐", color: "CustomRed"),
            createTestShoe(brand: "Barefoot", model: "Your Feet", icon: "🦶", color: "CustomGray", isDefault: true),
            createTestShoe(brand: "New Balance", model: "990v5", icon: "🏃‍♂️", color: "CustomPurple", archived: true)
        ]
    }
    
    /// Creates the default barefoot shoe
    static func createDefaultShoe() -> Shoe {
        return createTestShoe(
            brand: "Barefoot",
            model: "Your Feet",
            notes: "Default shoe for everyone",
            icon: "🦶",
            color: "CustomBlue",
            isDefault: true,
            estimatedLifespan: 1000.0
        )
    }
    
    // MARK: - Session Fixtures
    
    static func createTestSession(
        shoe: Shoe,
        startDate: Date = Date().addingTimeInterval(-3600), // 1 hour ago
        endDate: Date? = Date(),
        autoStarted: Bool = false,
        autoClosed: Bool = false
    ) -> ShoeSession {
        let session = ShoeSession(
            shoe: shoe,
            startDate: startDate,
            autoStarted: autoStarted
        )
        session.endDate = endDate
        session.autoClosed = autoClosed
        return session
    }
    
    /// Creates an active (ongoing) session
    static func createActiveSession(shoe: Shoe) -> ShoeSession {
        return createTestSession(shoe: shoe, endDate: nil)
    }
    
    /// Creates a collection of sessions for testing
    static func createTestSessionCollection(shoes: [Shoe]) -> [ShoeSession] {
        guard shoes.count >= 2 else { return [] }
        
        let now = Date()
        let calendar = Calendar.current
        
        return [
            // Today's active session
            createActiveSession(shoe: shoes[0]),
            
            // Yesterday's completed session
            createTestSession(
                shoe: shoes[1],
                startDate: calendar.date(byAdding: .day, value: -1, to: now)!,
                endDate: calendar.date(byAdding: .day, value: -1, to: now)!.addingTimeInterval(3600)
            ),
            
            // Week-old session
            createTestSession(
                shoe: shoes[0],
                startDate: calendar.date(byAdding: .day, value: -7, to: now)!,
                endDate: calendar.date(byAdding: .day, value: -7, to: now)!.addingTimeInterval(7200)
            )
        ]
    }
    
    // MARK: - Attribution Fixtures
    
    static func createTestAttribution(
        hourDate: Date = Date(),
        shoe: Shoe,
        steps: Int = 500,
        distance: Double = 0.4
    ) -> HourAttribution {
        return HourAttribution(
            hourDate: hourDate,
            shoe: shoe,
            steps: steps,
            distance: distance
        )
    }
    
    /// Creates hourly attributions for a full day
    static func createDayAttributions(date: Date, shoes: [Shoe]) -> [HourAttribution] {
        guard !shoes.isEmpty else { return [] }
        
        let calendar = Calendar.current
        var attributions: [HourAttribution] = []
        
        // Create attributions for active hours (6 AM to 10 PM)
        for hour in 6...22 {
            guard let hourDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date) else {
                continue
            }
            
            let shoe = shoes[hour % shoes.count] // Distribute across shoes
            let steps = generateRealisticSteps(for: hour)
            let distance = Double(steps) * 0.0008 // Approximate conversion
            
            let attribution = createTestAttribution(
                hourDate: hourDate,
                shoe: shoe,
                steps: steps,
                distance: distance
            )
            
            attributions.append(attribution)
        }
        
        return attributions
    }
    
    // MARK: - HealthKit Data Fixtures
    
    /// Creates realistic hourly step data for testing
    static func createHourlyStepData(
        for date: Date = Date(),
        withShoeAttributions: Bool = false,
        shoes: [Shoe] = []
    ) -> [HourlyStepData] {
        let calendar = Calendar.current
        var hourlyData: [HourlyStepData] = []
        
        for hour in 0...23 {
            guard let hourDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date) else {
                continue
            }
            
            let steps = generateRealisticSteps(for: hour)
            let distance = Double(steps) * 0.0008
            
            let assignedShoe: Shoe? = if withShoeAttributions && !shoes.isEmpty && steps > 0 {
                shoes[hour % shoes.count]
            } else {
                nil
            }
            
            let hourData = HourlyStepData(
                id: UUID(),
                date: hourDate,
                hour: hour,
                steps: steps,
                distance: distance,
                assignedShoe: assignedShoe
            )
            
            hourlyData.append(hourData)
        }
        
        return hourlyData
    }
    
    // MARK: - Helper Methods
    
    /// Generates realistic step counts based on time of day
    private static func generateRealisticSteps(for hour: Int) -> Int {
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
    
    /// Creates test dates relative to today
    static func createTestDates() -> [Date] {
        let calendar = Calendar.current
        let today = Date()
        
        return [
            today, // Today
            calendar.date(byAdding: .day, value: -1, to: today)!, // Yesterday
            calendar.date(byAdding: .day, value: -7, to: today)!, // A week ago
            calendar.date(byAdding: .month, value: -1, to: today)! // A month ago
        ]
    }
    
    /// Creates test error scenarios
    static func createTestErrors() -> [AppError] {
        return [
            .dataNotFound("Test shoe not found"),
            .healthKitPermissionDenied,
            .sessionAlreadyActive,
            .sessionNotFound,
            .shoeArchived,
            .sessionInvalidState("Test invalid state"),
            .validationFailed("Test validation failed")
        ]
    }
}
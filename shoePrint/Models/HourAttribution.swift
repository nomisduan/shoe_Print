//
//  HourAttribution.swift
//  shoePrint
//
//  Portfolio Refactor: Simplified attribution system
//

import Foundation
import SwiftData

/// Represents an hour-specific attribution of activity to a shoe
/// ✅ Simplified replacement for hour-specific sessions
@Model
final class HourAttribution {
    
    // MARK: - Properties
    
    /// The specific hour this attribution covers (always at :00 minutes)
    var hourDate: Date
    
    /// The shoe this hour is attributed to
    var shoe: Shoe?
    
    /// Steps for this specific hour (from HealthKit)
    var steps: Int
    
    /// Distance for this specific hour in kilometers (from HealthKit)
    var distance: Double
    
    /// When this attribution was created
    var createdAt: Date
    
    // MARK: - Initialization
    
    init(
        hourDate: Date,
        shoe: Shoe? = nil,
        steps: Int = 0,
        distance: Double = 0.0,
        createdAt: Date = Date()
    ) {
        // Normalize to hour start (e.g., 14:23 -> 14:00)
        let calendar = Calendar.current
        self.hourDate = calendar.date(bySettingHour: calendar.component(.hour, from: hourDate), 
                                     minute: 0, second: 0, of: hourDate) ?? hourDate
        self.shoe = shoe
        self.steps = steps
        self.distance = distance
        self.createdAt = createdAt
    }
    
    // MARK: - Computed Properties
    
    /// Human-readable hour string (e.g., "14:00")
    var hourString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: hourDate)
    }
    
    /// Date without time for grouping by day
    var dayDate: Date {
        Calendar.current.startOfDay(for: hourDate)
    }
}
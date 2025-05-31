//
//  ShoeSession.swift
//  shoePrint
//
//  Created by Simon Naud on 31/05/2025.
//

import Foundation
import SwiftData

/// Represents a usage session for a specific shoe
/// A session has a start date and optionally an end date (nil = currently active)
@Model
final class ShoeSession {
    
    // MARK: - Properties
    
    var startDate: Date
    var endDate: Date?              // nil = session is currently active
    var autoStarted: Bool           // true if auto-started (default shoe)
    var autoClosed: Bool            // true if auto-closed due to inactivity
    var shoe: Shoe?                 // Relationship to the shoe
    
    // MARK: - Initialization
    
    init(
        startDate: Date = Date(),
        endDate: Date? = nil,
        autoStarted: Bool = false,
        autoClosed: Bool = false,
        shoe: Shoe? = nil
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.autoStarted = autoStarted
        self.autoClosed = autoClosed
        self.shoe = shoe
    }
    
    // MARK: - Computed Properties
    
    /// Returns true if this session is currently active (no end date)
    var isActive: Bool {
        endDate == nil
    }
    
    /// Returns the duration of the session
    var duration: TimeInterval {
        let end = endDate ?? Date()
        return end.timeIntervalSince(startDate)
    }
    
    /// Returns the duration in hours
    var durationInHours: Double {
        duration / 3600.0
    }
    
    /// Returns formatted duration string
    var durationFormatted: String {
        let hours = Int(durationInHours)
        let minutes = Int((durationInHours - Double(hours)) * 60)
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    /// Returns the session date range as a string
    var dateRangeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        
        let startString = formatter.string(from: startDate)
        
        if let endDate = endDate {
            let endString = formatter.string(from: endDate)
            return "\(startString) - \(endString)"
        } else {
            return "\(startString) - Active"
        }
    }
    
    // MARK: - Session Management
    
    /// Closes the session with the current timestamp
    /// - Parameter autoClosed: Whether the session was auto-closed due to inactivity
    func closeSession(autoClosed: Bool = false) {
        guard isActive else { return }
        
        endDate = Date()
        self.autoClosed = autoClosed
        
        print("🔒 Session closed for \(shoe?.brand ?? "Unknown") \(shoe?.model ?? "") - Duration: \(durationFormatted)")
    }
    
    /// Checks if this session overlaps with a given date range
    /// - Parameters:
    ///   - start: Start date to check
    ///   - end: End date to check
    /// - Returns: True if the session overlaps with the given range
    func overlaps(start: Date, end: Date) -> Bool {
        let sessionEnd = endDate ?? Date()
        
        // Session starts before range ends AND session ends after range starts
        return startDate < end && sessionEnd > start
    }
    
    /// Checks if this session covers a specific hour
    /// - Parameter hour: The date representing the hour to check
    /// - Returns: True if the session was active during that hour
    func coversHour(_ hour: Date) -> Bool {
        let calendar = Calendar.current
        let hourStart = calendar.dateInterval(of: .hour, for: hour)?.start ?? hour
        let hourEnd = calendar.date(byAdding: .hour, value: 1, to: hourStart) ?? hour
        
        return overlaps(start: hourStart, end: hourEnd)
    }
    
    /// Returns all complete hours covered by this session
    /// - Returns: Array of Date objects representing the start of each covered hour
    func getCoveredHours() -> [Date] {
        let calendar = Calendar.current
        let sessionEnd = endDate ?? Date()
        
        var hours: [Date] = []
        var currentHour = calendar.dateInterval(of: .hour, for: startDate)?.start ?? startDate
        
        while currentHour < sessionEnd {
            // Only include completed hours (except for active sessions)
            let nextHour = calendar.date(byAdding: .hour, value: 1, to: currentHour) ?? currentHour
            
            if isActive || nextHour <= sessionEnd {
                hours.append(currentHour)
            }
            
            currentHour = nextHour
        }
        
        return hours
    }
} 
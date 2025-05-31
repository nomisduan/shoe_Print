//
//  Date+Extensions.swift
//  shoePrint
//
//  Created by Simon Naud on 11/04/2025.
//

import Foundation

extension Date {
    
    // MARK: - Date Formatting
    
    /// Formats date for display in the UI
    /// Example: "Jan 15, 2025"
    var displayFormat: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }
    
    /// Formats date with time for detailed views
    /// Example: "Jan 15, 2025 at 2:30 PM"
    var displayFormatWithTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
    
    /// Formats date for compact display
    /// Example: "15/01" for current year, "15/01/24" for other years
    var compactFormat: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDate(self, equalTo: Date(), toGranularity: .year) {
            formatter.dateFormat = "dd/MM"
        } else {
            formatter.dateFormat = "dd/MM/yy"
        }
        
        return formatter.string(from: self)
    }
    
    /// Relative time format for recent dates
    /// Examples: "Today", "Yesterday", "2 days ago", "Jan 15"
    var relativeFormat: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.dateTimeStyle = .named
        
        let calendar = Calendar.current
        let now = Date()
        
        // For dates within the last week, use relative formatting
        let daysAgo = now.timeIntervalSince(self) / (24 * 60 * 60) // Convert to days
        if daysAgo < 7 {
            return formatter.localizedString(for: self, relativeTo: now)
        } else {
            // For older dates, use compact format
            return compactFormat
        }
    }
    
    // MARK: - Date Calculations
    
    /// Returns the start of the day for this date
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
    
    /// Returns the end of the day for this date
    var endOfDay: Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: 1, to: startOfDay)?.addingTimeInterval(-1) ?? self
    }
    
    /// Returns the start of the week for this date (Monday)
    var startOfWeek: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return calendar.date(from: components) ?? self
    }
    
    /// Returns the start of the month for this date
    var startOfMonth: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: components) ?? self
    }
    
    /// Returns true if this date is today
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
    
    /// Returns true if this date is yesterday
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }
    
    /// Returns true if this date is within the current week
    var isThisWeek: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .weekOfYear)
    }
    
    /// Returns true if this date is within the current month
    var isThisMonth: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .month)
    }
    
    // MARK: - Date Ranges
    
    /// Creates a date range from this date to another date
    /// - Parameter endDate: The end date of the range
    /// - Returns: A DateInterval representing the range
    func dateInterval(to endDate: Date) -> DateInterval {
        DateInterval(start: min(self, endDate), end: max(self, endDate))
    }
    
    /// Returns an array of dates for each day between this date and the end date
    /// - Parameter endDate: The end date (inclusive)
    /// - Returns: Array of dates for each day in the range
    func daysBetween(and endDate: Date) -> [Date] {
        let calendar = Calendar.current
        let startDate = self.startOfDay
        let endDate = endDate.startOfDay
        
        var dates: [Date] = []
        var currentDate = startDate
        
        while currentDate <= endDate {
            dates.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return dates
    }
    
    // MARK: - HealthKit Query Helpers
    
    /// Returns a date that's a specified number of days ago
    /// - Parameter days: Number of days to subtract
    /// - Returns: The calculated date
    static func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
    }
    
    /// Returns a date that's a specified number of weeks ago
    /// - Parameter weeks: Number of weeks to subtract
    /// - Returns: The calculated date
    static func weeksAgo(_ weeks: Int) -> Date {
        Calendar.current.date(byAdding: .weekOfYear, value: -weeks, to: Date()) ?? Date()
    }
    
    /// Returns a date that's a specified number of months ago
    /// - Parameter months: Number of months to subtract
    /// - Returns: The calculated date
    static func monthsAgo(_ months: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: -months, to: Date()) ?? Date()
    }
} 
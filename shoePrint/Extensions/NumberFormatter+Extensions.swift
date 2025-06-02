import Foundation

extension NumberFormatter {
    
    /// Formatter for distance values with 1 decimal place and thousand separators
    static let distance: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        formatter.groupingSeparator = " "
        formatter.decimalSeparator = "."
        formatter.usesGroupingSeparator = true
        return formatter
    }()
    
    /// Formatter for step counts with thousand separators, no decimals
    static let steps: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        formatter.groupingSeparator = " "
        formatter.decimalSeparator = "."
        formatter.usesGroupingSeparator = true
        return formatter
    }()
    
    /// Formatter for compact step display (e.g., 1.3M for 1,300,000)
    static let compactSteps: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        formatter.groupingSeparator = " "
        formatter.decimalSeparator = "."
        formatter.usesGroupingSeparator = true
        return formatter
    }()
}

extension Double {
    
    /// Format distance with 1 decimal place and thousand separators
    var formattedDistance: String {
        return NumberFormatter.distance.string(from: NSNumber(value: self)) ?? String(format: "%.1f", self)
    }
    
    /// Format step count with thousand separators
    var formattedSteps: String {
        return NumberFormatter.steps.string(from: NSNumber(value: self)) ?? String(format: "%.0f", self)
    }
    
    /// Format step count in compact form (1.3M for millions)
    var formattedCompactSteps: String {
        if self >= 1_000_000 {
            let millions = self / 1_000_000
            return NumberFormatter.compactSteps.string(from: NSNumber(value: millions))?.appending("M") ?? String(format: "%.1fM", millions)
        } else if self >= 1_000 {
            let thousands = self / 1_000
            return NumberFormatter.compactSteps.string(from: NSNumber(value: thousands))?.appending("k") ?? String(format: "%.1fk", thousands)
        } else {
            return NumberFormatter.steps.string(from: NSNumber(value: self)) ?? String(format: "%.0f", self)
        }
    }
}

extension Int {
    
    /// Format step count with thousand separators
    var formattedSteps: String {
        return NumberFormatter.steps.string(from: NSNumber(value: self)) ?? "\(self)"
    }
    
    /// Format step count in compact form (1.3M for millions)
    var formattedCompactSteps: String {
        return Double(self).formattedCompactSteps
    }
} 
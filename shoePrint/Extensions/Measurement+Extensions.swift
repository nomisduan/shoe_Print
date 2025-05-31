//
//  Measurement+Extensions.swift
//  shoePrint
//
//  Created by Simon Naud on 11/04/2025.
//

import Foundation

extension Measurement where UnitType == UnitLength {
    
    /// Formats distance for display based on user's locale preferences
    /// Automatically converts between metric and imperial systems
    var formattedForDisplay: String {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .providedUnit
        formatter.numberFormatter.maximumFractionDigits = 1
        
        // Convert to user's preferred unit system
        let userDistance = self.converted(to: preferredUnit)
        return formatter.string(from: userDistance)
    }
    
    /// Returns the user's preferred distance unit based on locale
    private var preferredUnit: UnitLength {
        let locale = Locale.current
        let measurementSystem = locale.measurementSystem
        
        switch measurementSystem {
        case .metric:
            return .kilometers
        case .us, .uk:
            return .miles
        default:
            return .kilometers
        }
    }
}

extension NumberFormatter {
    
    /// Shared formatter for step counts
    static let stepFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = Locale.current.groupingSeparator
        return formatter
    }()
    
    /// Shared formatter for distances
    static let distanceFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 1
        return formatter
    }()
}

extension Double {
    
    /// Formats a distance value (in meters) for display
    var formattedAsDistance: String {
        let measurement = Measurement(value: self / 1000, unit: UnitLength.kilometers)
        return measurement.formattedForDisplay
    }
    
    /// Formats a step count for display with proper grouping
    var formattedAsSteps: String {
        return NumberFormatter.stepFormatter.string(from: NSNumber(value: self)) ?? "0"
    }
}

extension Int {
    
    /// Formats an integer step count for display
    var formattedAsSteps: String {
        return NumberFormatter.stepFormatter.string(from: NSNumber(value: self)) ?? "0"
    }
} 
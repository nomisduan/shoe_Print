//
//  HealthKitDataModels.swift
//  shoePrint
//
//  Created by Simon Naud on 11/04/2025.
//

import Foundation
import HealthKit

// MARK: - HealthKit Data Models

/// Represents a consolidated walking activity session extracted from HealthKit data
struct WalkingSession: Identifiable, Codable {
    var id = UUID()
    let startDate: Date
    let endDate: Date
    let totalSteps: Int
    let totalDistance: Double // in meters
    let averagePace: Double // steps per minute
    let source: String // HealthKit source identifier
    
    /// Duration of the walking session in minutes
    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate) / 60
    }
    
    /// Distance in kilometers for display purposes
    var distanceInKilometers: Double {
        totalDistance / 1000
    }
    
    /// Determines if this session is significant enough to be tracked
    var isSignificant: Bool {
        duration >= 5 && totalSteps >= 100 // Minimum 5 minutes and 100 steps
    }
}

/// Raw HealthKit data point for steps
struct HealthKitStepsData {
    let date: Date
    let steps: Int
    let source: String
}

/// Raw HealthKit data point for distance
struct HealthKitDistanceData {
    let date: Date
    let distance: Double // in meters
    let source: String
}

/// Aggregated health data for a specific time period
struct HealthDataSummary {
    let startDate: Date
    let endDate: Date
    let totalSteps: Int
    let totalDistance: Double // in meters
    let sessions: [WalkingSession]
    
    /// Number of active days in the period
    var activeDays: Int {
        Set(sessions.map { Calendar.current.startOfDay(for: $0.startDate) }).count
    }
    
    /// Average daily steps
    var averageDailySteps: Double {
        activeDays > 0 ? Double(totalSteps) / Double(activeDays) : 0
    }
}

/// Health data permission status
enum HealthKitPermissionStatus {
    case notDetermined
    case denied
    case authorized
    case restricted
    
    var isAuthorized: Bool {
        self == .authorized
    }
}

// MARK: - HealthKit Query Parameters

/// Configuration for HealthKit data queries
struct HealthKitQueryConfig {
    let startDate: Date
    let endDate: Date
    let interval: DateComponents // Sampling interval (e.g., hourly, daily)
    
    static func hourlyQuery(from startDate: Date, to endDate: Date) -> HealthKitQueryConfig {
        HealthKitQueryConfig(
            startDate: startDate,
            endDate: endDate,
            interval: DateComponents(hour: 1)
        )
    }
    
    static func dailyQuery(from startDate: Date, to endDate: Date) -> HealthKitQueryConfig {
        HealthKitQueryConfig(
            startDate: startDate,
            endDate: endDate,
            interval: DateComponents(day: 1)
        )
    }
}

// MARK: - Error Handling

/// HealthKit-specific error types
enum HealthKitError: LocalizedError {
    case notAvailable
    case permissionDenied
    case dataNotFound
    case queryFailed(Error)
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device"
        case .permissionDenied:
            return "Permission to access health data was denied"
        case .dataNotFound:
            return "No health data found for the specified period"
        case .queryFailed(let error):
            return "Health data query failed: \(error.localizedDescription)"
        case .invalidData:
            return "Invalid health data received"
        }
    }
}

// MARK: - Extensions

extension WalkingSession {
    /// Formatted distance string
    var distanceFormatted: String {
        let distance = Measurement(value: totalDistance / 1000.0, unit: UnitLength.kilometers)
        return distance.formattedForDisplay
    }
} 
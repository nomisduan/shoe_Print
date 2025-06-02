//
//  AppError.swift
//  shoePrint
//
//  Portfolio Refactor: Comprehensive error handling
//

import Foundation

/// Comprehensive error types for the application
/// ✅ Structured error handling for better user experience and debugging
enum AppError: Error, LocalizedError, Equatable {
    
    // MARK: - Data Errors
    case dataNotFound(String)
    case dataCorrupted(String)
    case saveFailed(String)
    case deleteFailed(String)
    case validationFailed(String)
    
    // MARK: - HealthKit Errors
    case healthKitNotAvailable
    case healthKitPermissionDenied
    case healthKitDataUnavailable
    case healthKitQueryFailed(String)
    
    // MARK: - Session Errors
    case sessionAlreadyActive
    case sessionNotFound
    case sessionConflict(String)
    case sessionInvalidState(String)
    
    // MARK: - Attribution Errors
    case attributionAlreadyExists
    case attributionNotFound
    case attributionConflict(String)
    case invalidHourDate(String)
    
    // MARK: - Shoe Errors
    case shoeNotFound
    case shoeAlreadyExists
    case shoeValidationFailed(String)
    case shoeArchived
    case defaultShoeConflict
    
    // MARK: - Network Errors (for future API integration)
    case networkUnavailable
    case requestTimeout
    case serverError(Int)
    case invalidResponse
    
    // MARK: - General Errors
    case unknown(String)
    case configurationError(String)
    case permissionDenied(String)
    case resourceUnavailable(String)
    
    // MARK: - LocalizedError Implementation
    
    var errorDescription: String? {
        switch self {
        // Data Errors
        case .dataNotFound(let details):
            return "Data not found: \(details)"
        case .dataCorrupted(let details):
            return "Data corrupted: \(details)"
        case .saveFailed(let details):
            return "Save failed: \(details)"
        case .deleteFailed(let details):
            return "Delete failed: \(details)"
        case .validationFailed(let details):
            return "Validation failed: \(details)"
            
        // HealthKit Errors
        case .healthKitNotAvailable:
            return "HealthKit is not available on this device"
        case .healthKitPermissionDenied:
            return "HealthKit permission denied. Please enable in Settings."
        case .healthKitDataUnavailable:
            return "HealthKit data is not available"
        case .healthKitQueryFailed(let details):
            return "HealthKit query failed: \(details)"
            
        // Session Errors
        case .sessionAlreadyActive:
            return "A session is already active for this shoe"
        case .sessionNotFound:
            return "Session not found"
        case .sessionConflict(let details):
            return "Session conflict: \(details)"
        case .sessionInvalidState(let details):
            return "Invalid session state: \(details)"
            
        // Attribution Errors
        case .attributionAlreadyExists:
            return "Attribution already exists for this hour"
        case .attributionNotFound:
            return "Attribution not found"
        case .attributionConflict(let details):
            return "Attribution conflict: \(details)"
        case .invalidHourDate(let details):
            return "Invalid hour date: \(details)"
            
        // Shoe Errors
        case .shoeNotFound:
            return "Shoe not found"
        case .shoeAlreadyExists:
            return "Shoe already exists"
        case .shoeValidationFailed(let details):
            return "Shoe validation failed: \(details)"
        case .shoeArchived:
            return "Cannot perform operation on archived shoe"
        case .defaultShoeConflict:
            return "Only one shoe can be set as default"
            
        // Network Errors
        case .networkUnavailable:
            return "Network unavailable"
        case .requestTimeout:
            return "Request timeout"
        case .serverError(let code):
            return "Server error: \(code)"
        case .invalidResponse:
            return "Invalid server response"
            
        // General Errors
        case .unknown(let details):
            return "Unknown error: \(details)"
        case .configurationError(let details):
            return "Configuration error: \(details)"
        case .permissionDenied(let details):
            return "Permission denied: \(details)"
        case .resourceUnavailable(let details):
            return "Resource unavailable: \(details)"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .healthKitPermissionDenied:
            return "User has not granted permission to access HealthKit data"
        case .sessionAlreadyActive:
            return "Only one session can be active per shoe at a time"
        case .shoeArchived:
            return "Archived shoes cannot be used for new operations"
        case .networkUnavailable:
            return "Device is not connected to the internet"
        default:
            return nil
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .healthKitPermissionDenied:
            return "Go to Settings > Privacy & Security > Health > shoePrint and enable all permissions"
        case .sessionAlreadyActive:
            return "End the current session before starting a new one"
        case .shoeArchived:
            return "Unarchive the shoe first or use a different shoe"
        case .networkUnavailable:
            return "Check your internet connection and try again"
        default:
            return nil
        }
    }
    
    // MARK: - Helper Properties
    
    /// Returns true if this is a user-facing error that should be shown in UI
    var isUserFacing: Bool {
        switch self {
        case .healthKitPermissionDenied, .healthKitNotAvailable, .shoeArchived, .sessionAlreadyActive:
            return true
        case .networkUnavailable, .requestTimeout:
            return true
        default:
            return false
        }
    }
    
    /// Returns true if this error should be logged for debugging
    var shouldLog: Bool {
        switch self {
        case .unknown, .dataCorrupted, .saveFailed, .deleteFailed:
            return true
        case .serverError, .invalidResponse:
            return true
        default:
            return false
        }
    }
    
    /// Returns appropriate logging level
    var logLevel: LogLevel {
        switch self {
        case .dataCorrupted, .unknown:
            return .error
        case .saveFailed, .deleteFailed, .serverError:
            return .warning
        case .healthKitPermissionDenied, .sessionAlreadyActive:
            return .info
        default:
            return .debug
        }
    }
}

/// Logging levels for error handling
enum LogLevel {
    case debug
    case info
    case warning
    case error
    case critical
}
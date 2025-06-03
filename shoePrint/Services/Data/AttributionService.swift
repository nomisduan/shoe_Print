//
//  AttributionService.swift
//  shoePrint
//
//  Portfolio Refactor: Simplified attribution system
//

import Foundation
import SwiftData

/// Service for managing hour-specific attributions in the Journal
/// ✅ Simplified replacement for complex hour session management
@MainActor
final class AttributionService: ObservableObject {
    
    // MARK: - Properties
    
    private let attributionRepository: AttributionRepositoryProtocol
    private let sessionRepository: SessionRepositoryProtocol
    private let healthKitManager: HealthKitManager
    
    @Published var isProcessing = false
    @Published var error: AppError?
    
    // MARK: - Initialization
    
    init(
        attributionRepository: AttributionRepositoryProtocol,
        sessionRepository: SessionRepositoryProtocol,
        healthKitManager: HealthKitManager
    ) {
        self.attributionRepository = attributionRepository
        self.sessionRepository = sessionRepository
        self.healthKitManager = healthKitManager
    }
    
    // MARK: - Attribution Management
    
    /// Attributes a specific hour to a shoe
    /// ✅ Much simpler than complex session creation
    func attributeHour(_ hourDate: Date, to shoe: Shoe) async throws {
        guard !shoe.archived else {
            throw AppError.shoeArchived
        }
        
        isProcessing = true
        error = nil
        defer { isProcessing = false }
        
        do {
            let normalizedHour = normalizeToHourStart(hourDate)
            
            // Check if hour is already attributed
            if try await attributionRepository.isHourAttributed(normalizedHour) {
                // Remove existing attribution first
                try await removeAttribution(for: normalizedHour)
            }
            
            // Get HealthKit data for this hour
            let healthData = await getHealthKitData(for: normalizedHour)
            
            // Create new attribution
            let attribution = HourAttribution(
                hourDate: normalizedHour,
                shoe: shoe,
                steps: healthData.steps,
                distance: healthData.distance
            )
            
            try await attributionRepository.saveAttribution(attribution)
            print("✅ Attributed hour \(normalizedHour.formatted(.dateTime.hour().minute())) to \(shoe.brand) \(shoe.model)")
            
        } catch {
            let appError = error as? AppError ?? AppError.saveFailed(error.localizedDescription)
            self.error = appError
            throw appError
        }
    }
    
    /// Attributes multiple hours to a shoe (batch operation)
    func attributeHours(_ hourDates: [Date], to shoe: Shoe) async throws {
        guard !shoe.archived else {
            throw AppError.shoeArchived
        }
        
        isProcessing = true
        error = nil
        defer { isProcessing = false }
        
        do {
            var attributions: [HourAttribution] = []
            
            for hourDate in hourDates {
                let normalizedHour = normalizeToHourStart(hourDate)
                let healthData = await getHealthKitData(for: normalizedHour)
                
                let attribution = HourAttribution(
                    hourDate: normalizedHour,
                    shoe: shoe,
                    steps: healthData.steps,
                    distance: healthData.distance
                )
                
                attributions.append(attribution)
            }
            
            // Remove existing attributions for these hours
            try await attributionRepository.deleteAttributions(for: hourDates)
            
            // Save new attributions
            try await attributionRepository.saveAttributions(attributions)
            print("✅ Batch attributed \(hourDates.count) hours to \(shoe.brand) \(shoe.model)")
            
        } catch {
            let appError = error as? AppError ?? AppError.saveFailed(error.localizedDescription)
            self.error = appError
            throw appError
        }
    }
    
    /// Removes attribution for a specific hour
    func removeAttribution(for hourDate: Date) async throws {
        let normalizedHour = normalizeToHourStart(hourDate)
        
        do {
            if let attribution = try await attributionRepository.fetchAttribution(for: normalizedHour) {
                try await attributionRepository.deleteAttribution(attribution)
                print("🗑️ Removed attribution for hour \(normalizedHour.formatted(.dateTime.hour().minute()))")
            }
        } catch {
            let appError = error as? AppError ?? AppError.deleteFailed(error.localizedDescription)
            self.error = appError
            throw appError
        }
    }
    
    /// Removes attributions for multiple hours (batch operation)
    func removeAttributions(for hourDates: [Date]) async throws {
        do {
            try await attributionRepository.deleteAttributions(for: hourDates)
            print("🗑️ Removed \(hourDates.count) attributions")
        } catch {
            let appError = error as? AppError ?? AppError.deleteFailed(error.localizedDescription)
            self.error = appError
            throw appError
        }
    }
    
    // MARK: - Attribution Queries
    
    /// Gets all attributions for a specific date
    func getAttributions(for date: Date) async throws -> [HourAttribution] {
        do {
            return try await attributionRepository.fetchAttributions(for: date)
        } catch {
            let appError = error as? AppError ?? AppError.dataNotFound(error.localizedDescription)
            self.error = appError
            throw appError
        }
    }
    
    /// Gets attribution for a specific hour (if any)
    func getAttribution(for hourDate: Date) async throws -> HourAttribution? {
        do {
            return try await attributionRepository.fetchAttribution(for: hourDate)
        } catch {
            let appError = error as? AppError ?? AppError.dataNotFound(error.localizedDescription)
            self.error = appError
            throw appError
        }
    }
    
    /// Applies attributions to hourly step data for Journal display
    /// ✅ Combines HourAttributions AND active sessions for complete attribution
    func applyAttributions(to hourlyData: [HourlyStepData], for date: Date) async -> [HourlyStepData] {
        do {
            // Get explicit hour attributions
            let attributions = try await getAttributions(for: date)
            let attributionsByHour = Dictionary(grouping: attributions) { 
                Calendar.current.component(.hour, from: $0.hourDate) 
            }
            
            // ✅ Also get active sessions that cover this date
            let sessions = await getSessionsForDate(date)
            
            return hourlyData.map { hourData in
                var attributed = hourData
                
                // Priority 1: Explicit hour attributions (manual attribution)
                if let attribution = attributionsByHour[hourData.hour]?.first {
                    attributed.assignedShoe = attribution.shoe
                    return attributed
                }
                
                // Priority 2: Active session attribution (automatic)
                for session in sessions {
                    if session.coversHour(hourData.date) {
                        attributed.assignedShoe = session.shoe
                        break
                    }
                }
                
                return attributed
            }
        } catch {
            print("❌ Failed to apply attributions: \(error)")
            return hourlyData
        }
    }
    
    // MARK: - Session Integration (Private)
    
    /// Gets sessions that overlap with a specific date
    private func getSessionsForDate(_ date: Date) async -> [ShoeSession] {
        do {
            return try await sessionRepository.fetchSessionsForDate(date)
        } catch {
            print("❌ Failed to fetch sessions for date: \(error)")
            return []
        }
    }
    
    // MARK: - Helper Methods
    
    /// Normalizes a date to the start of the hour (e.g., 14:23 -> 14:00)
    private func normalizeToHourStart(_ date: Date) -> Date {
        let calendar = Calendar.current
        return calendar.date(bySettingHour: calendar.component(.hour, from: date), 
                           minute: 0, second: 0, of: date) ?? date
    }
    
    /// Gets HealthKit data for a specific hour
    private func getHealthKitData(for hourDate: Date) async -> (steps: Int, distance: Double) {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: hourDate)
        let hour = calendar.component(.hour, from: hourDate)
        
        // Fetch HealthKit data for the day
        let hourlyData = await healthKitManager.fetchHourlyData(for: dayStart)
        
        // Find data for the specific hour
        if let hourData = hourlyData.first(where: { $0.hour == hour }) {
            return (steps: hourData.steps, distance: hourData.distance)
        } else {
            return (steps: 0, distance: 0.0)
        }
    }
    
    // MARK: - Error Handling
    
    /// Clears the current error
    func clearError() {
        error = nil
    }
}
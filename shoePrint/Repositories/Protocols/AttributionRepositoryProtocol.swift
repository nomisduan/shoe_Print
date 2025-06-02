//
//  AttributionRepositoryProtocol.swift
//  shoePrint
//
//  Portfolio Refactor: Repository pattern implementation
//

import Foundation

/// Protocol defining attribution data access operations
/// ✅ Abstracts SwiftData implementation for journal hour attributions
protocol AttributionRepositoryProtocol {
    
    // MARK: - CRUD Operations
    
    /// Fetches all attributions
    func fetchAllAttributions() async throws -> [HourAttribution]
    
    /// Fetches attributions for a specific shoe
    func fetchAttributions(for shoe: Shoe) async throws -> [HourAttribution]
    
    /// Fetches attributions for a specific date
    func fetchAttributions(for date: Date) async throws -> [HourAttribution]
    
    /// Fetches attribution for a specific hour (if any)
    func fetchAttribution(for hourDate: Date) async throws -> HourAttribution?
    
    /// Saves an attribution (insert or update)
    func saveAttribution(_ attribution: HourAttribution) async throws
    
    /// Deletes an attribution
    func deleteAttribution(_ attribution: HourAttribution) async throws
    
    // MARK: - Batch Operations
    
    /// Saves multiple attributions
    func saveAttributions(_ attributions: [HourAttribution]) async throws
    
    /// Deletes attributions for specific hours
    func deleteAttributions(for hourDates: [Date]) async throws
    
    /// Deletes all attributions for a shoe
    func deleteAllAttributions(for shoe: Shoe) async throws
    
    // MARK: - Specialized Queries
    
    /// Gets attributions for a date range
    func fetchAttributions(from startDate: Date, to endDate: Date) async throws -> [HourAttribution]
    
    /// Gets attribution count for a shoe
    func getAttributionCount(for shoe: Shoe) async throws -> Int
    
    /// Gets total attributed steps for a shoe
    func getTotalAttributedSteps(for shoe: Shoe) async throws -> Int
    
    /// Gets total attributed distance for a shoe
    func getTotalAttributedDistance(for shoe: Shoe) async throws -> Double
    
    /// Checks if an hour is already attributed
    func isHourAttributed(_ hourDate: Date) async throws -> Bool
    
    /// Gets all days with attributions for a shoe
    func getAttributionDays(for shoe: Shoe) async throws -> [Date]
}
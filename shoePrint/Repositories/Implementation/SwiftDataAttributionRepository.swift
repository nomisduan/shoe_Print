//
//  SwiftDataAttributionRepository.swift
//  shoePrint
//
//  Portfolio Refactor: SwiftData implementation of AttributionRepository
//

import Foundation
import SwiftData

/// SwiftData implementation of AttributionRepositoryProtocol
/// ✅ Concrete implementation for journal hour attribution management
@MainActor
final class SwiftDataAttributionRepository: AttributionRepositoryProtocol {
    
    // MARK: - Properties
    
    private let modelContext: ModelContext
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - CRUD Operations
    
    func fetchAllAttributions() async throws -> [HourAttribution] {
        let descriptor = FetchDescriptor<HourAttribution>(
            sortBy: [SortDescriptor(\.hourDate, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    func fetchAttributions(for shoe: Shoe) async throws -> [HourAttribution] {
        let allAttributions = try await fetchAllAttributions()
        return allAttributions.filter { attribution in
            attribution.shoe?.persistentModelID == shoe.persistentModelID
        }
    }
    
    func fetchAttributions(for date: Date) async throws -> [HourAttribution] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
        
        let descriptor = FetchDescriptor<HourAttribution>(
            predicate: #Predicate<HourAttribution> { attribution in
                attribution.hourDate >= startOfDay && attribution.hourDate < endOfDay
            },
            sortBy: [SortDescriptor(\.hourDate, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    func fetchAttribution(for hourDate: Date) async throws -> HourAttribution? {
        let normalizedHour = normalizeToHourStart(hourDate)
        
        let descriptor = FetchDescriptor<HourAttribution>(
            predicate: #Predicate<HourAttribution> { attribution in
                attribution.hourDate == normalizedHour
            }
        )
        return try modelContext.fetch(descriptor).first
    }
    
    func saveAttribution(_ attribution: HourAttribution) async throws {
        modelContext.insert(attribution)
        try modelContext.save()
    }
    
    func deleteAttribution(_ attribution: HourAttribution) async throws {
        modelContext.delete(attribution)
        try modelContext.save()
    }
    
    // MARK: - Batch Operations
    
    func saveAttributions(_ attributions: [HourAttribution]) async throws {
        for attribution in attributions {
            modelContext.insert(attribution)
        }
        try modelContext.save()
    }
    
    func deleteAttributions(for hourDates: [Date]) async throws {
        let normalizedHours = hourDates.map(normalizeToHourStart)
        let allAttributions = try await fetchAllAttributions()
        
        let toDelete = allAttributions.filter { attribution in
            normalizedHours.contains(attribution.hourDate)
        }
        
        for attribution in toDelete {
            modelContext.delete(attribution)
        }
        
        if !toDelete.isEmpty {
            try modelContext.save()
        }
    }
    
    func deleteAllAttributions(for shoe: Shoe) async throws {
        let attributions = try await fetchAttributions(for: shoe)
        
        for attribution in attributions {
            modelContext.delete(attribution)
        }
        
        if !attributions.isEmpty {
            try modelContext.save()
        }
    }
    
    // MARK: - Specialized Queries
    
    func fetchAttributions(from startDate: Date, to endDate: Date) async throws -> [HourAttribution] {
        let descriptor = FetchDescriptor<HourAttribution>(
            predicate: #Predicate<HourAttribution> { attribution in
                attribution.hourDate >= startDate && attribution.hourDate < endDate
            },
            sortBy: [SortDescriptor(\.hourDate, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    func getAttributionCount(for shoe: Shoe) async throws -> Int {
        let attributions = try await fetchAttributions(for: shoe)
        return attributions.count
    }
    
    func getTotalAttributedSteps(for shoe: Shoe) async throws -> Int {
        let attributions = try await fetchAttributions(for: shoe)
        return attributions.reduce(0) { $0 + $1.steps }
    }
    
    func getTotalAttributedDistance(for shoe: Shoe) async throws -> Double {
        let attributions = try await fetchAttributions(for: shoe)
        return attributions.reduce(0.0) { $0 + $1.distance }
    }
    
    func isHourAttributed(_ hourDate: Date) async throws -> Bool {
        let attribution = try await fetchAttribution(for: hourDate)
        return attribution != nil
    }
    
    func getAttributionDays(for shoe: Shoe) async throws -> [Date] {
        let attributions = try await fetchAttributions(for: shoe)
        let uniqueDays = Set(attributions.map { attribution in
            Calendar.current.startOfDay(for: attribution.hourDate)
        })
        return Array(uniqueDays).sorted()
    }
    
    // MARK: - Helper Methods
    
    /// Normalizes a date to the start of the hour
    private func normalizeToHourStart(_ date: Date) -> Date {
        let calendar = Calendar.current
        return calendar.date(bySettingHour: calendar.component(.hour, from: date),
                           minute: 0, second: 0, of: date) ?? date
    }
}
//
//  Shoe.swift
//  shoePrint
//
//  Created by Simon Naud on 11/04/2025.
//

import Foundation
import SwiftData

/// Represents a shoe in the user's collection with session-based tracking
/// Uses proper computed properties for SwiftUI reactivity
/// Note: @Model classes are automatically Observable in SwiftData
@Model
final class Shoe {
    var timestamp: Date
    var brand: String
    var model: String
    var notes: String
    var icon: String
    var color: String
    var archived: Bool
    var isDefault: Bool // Default shoe for automatic daily activation
    var purchaseDate: Date?
    var purchasePrice: Double?
    var estimatedLifespan: Double // in kilometers
    var entries: [StepEntry]
    
    // MARK: - Relationships
    
    /// Sessions represent actual wearing periods (start/stop tracking)
    @Relationship(deleteRule: .cascade, inverse: \ShoeSession.shoe)
    var sessions: [ShoeSession] = []
    
    /// Hour attributions represent Journal attributions (simplified system)
    @Relationship(deleteRule: .cascade, inverse: \HourAttribution.shoe)
    var hourAttributions: [HourAttribution] = []
    
    // MARK: - Computed Properties (SwiftUI Reactive)
    
    /// Returns true if this shoe has an active session (currently being worn)
    /// ✅ Proper computed property - triggers SwiftUI updates when sessions change
    var isActive: Bool {
        return sessions.contains { $0.isActive }
    }
    
    /// Returns the timestamp when the shoe was last activated
    /// ✅ Proper computed property - derived from active session
    var activatedAt: Date? {
        return sessions.first(where: { $0.isActive })?.startDate
    }
    
    /// Returns the total distance for this shoe from all sources
    /// ✅ Proper computed property - aggregates from sessions, attributions, and entries
    var totalDistance: Double {
        let sessionDistance = sessions.reduce(0.0) { $0 + $1.distance }
        let attributionDistance = hourAttributions.reduce(0.0) { $0 + $1.distance }
        let entriesDistance = entries.reduce(0.0) { $0 + $1.distance }
        
        // Use sessions + attributions if available, otherwise fall back to entries
        let modernDistance = sessionDistance + attributionDistance
        return modernDistance > 0 ? modernDistance : entriesDistance
    }
    
    /// Returns the lifespan progress (0.0 to 1.0)
    /// ✅ Proper computed property - derived from totalDistance
    var lifespanProgress: Double {
        guard estimatedLifespan > 0 else { return 0.0 }
        return min(totalDistance / estimatedLifespan, 1.0)
    }

    init(timestamp: Date = .now, brand: String = "barefoot", model: String = "yours", notes: String = "", icon: String = "🦶", color: String = "CustomPurple", archived: Bool = false, isDefault: Bool = false, purchaseDate: Date? = nil, purchasePrice: Double? = nil, estimatedLifespan: Double = 800.0, entries: [StepEntry] = []) {
        self.timestamp = timestamp
        self.brand = brand
        self.model = model
        self.notes = notes
        self.icon = icon
        self.color = color
        self.archived = archived
        self.isDefault = isDefault
        self.purchaseDate = purchaseDate
        self.purchasePrice = purchasePrice
        self.estimatedLifespan = estimatedLifespan
        self.entries = entries
        
        print("🏗️ Initialized shoe \(brand) \(model) with \(entries.count) entries")
    }
    
    
    // MARK: - Session Access Methods
    
    /// Returns the currently active session, if any
    /// ✅ Computed property - automatically updates when sessions change
    var activeSession: ShoeSession? {
        return sessions.first(where: { $0.isActive })
    }
    
    /// Gets active session using database query (when relationships might not be loaded)
    func getActiveSession(using modelContext: ModelContext) async -> ShoeSession? {
        do {
            let descriptor = FetchDescriptor<ShoeSession>(
                predicate: #Predicate<ShoeSession> { session in
                    session.endDate == nil
                }
            )
            let activeSessions = try modelContext.fetch(descriptor)
            return activeSessions.first { session in
                session.shoe?.persistentModelID == self.persistentModelID
            }
        } catch {
            print("❌ Error fetching active session for \(brand) \(model): \(error)")
            return nil
        }
    }
    
    
    /// Returns all sessions for today
    var todaySessions: [ShoeSession] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? Date()
        
        return sessions.filter { session in
            session.overlaps(start: today, end: tomorrow)
        }
    }
    
    /// Returns the total time worn today in hours
    var todayWearTime: Double {
        todaySessions.reduce(0) { total, session in
            let sessionEnd = session.endDate ?? Date()
            let today = Calendar.current.startOfDay(for: Date())
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? Date()
            
            // Clamp session to today's bounds
            let clampedStart = max(session.startDate, today)
            let clampedEnd = min(sessionEnd, tomorrow)
            
            if clampedStart < clampedEnd {
                return total + clampedEnd.timeIntervalSince(clampedStart) / 3600.0
            }
            return total
        }
    }
    
    // MARK: - Explicit Refresh Methods (SwiftData-Safe)
    
    /// Legacy method for compatibility - no longer needed with proper computed properties
    /// ✅ Computed properties now automatically reflect current state
    @available(*, deprecated, message: "No longer needed with proper computed properties")
    func refreshComputedProperties(using modelContext: ModelContext) async {
        print("ℹ️ refreshComputedProperties called but no longer needed - computed properties are now reactive")
        // No-op - computed properties automatically update when relationships change
    }
    
    /// Legacy method for compatibility - no longer needed with proper computed properties
    @available(*, deprecated, message: "No longer needed with proper computed properties")
    func refreshComputedPropertiesFromMemory() {
        print("ℹ️ refreshComputedPropertiesFromMemory called but no longer needed - computed properties are now reactive")
        // No-op - computed properties automatically update when relationships change
    }
    
    /// Legacy method for compatibility - no longer needed with proper computed properties
    @available(*, deprecated, message: "No longer needed with proper computed properties")
    func refreshDistanceFromDatabase(using modelContext: ModelContext) async {
        print("ℹ️ refreshDistanceFromDatabase called but no longer needed - totalDistance is now computed")
        // No-op - totalDistance is now a computed property that automatically reflects current sessions
    }
    
    // MARK: - Session-based Computed Properties
    
    /// Returns total steps from all sources (real HealthKit data)
    var totalSteps: Int {
        let sessionSteps = sessions.reduce(0) { $0 + $1.steps }
        let attributionSteps = hourAttributions.reduce(0) { $0 + $1.steps }
        let entriesSteps = entries.reduce(0) { $0 + $1.steps }
        
        // Use sessions + attributions if available, otherwise fall back to entries
        let modernSteps = sessionSteps + attributionSteps
        return modernSteps > 0 ? modernSteps : entriesSteps
    }
    
    /// Returns the number of days this shoe has been used
    var usageDays: Int {
        let calendar = Calendar.current
        
        var uniqueDays = Set<Date>()
        
        // Add days from sessions
        uniqueDays.formUnion(sessions.map { calendar.startOfDay(for: $0.startDate) })
        
        // Add days from hour attributions
        uniqueDays.formUnion(hourAttributions.map { calendar.startOfDay(for: $0.hourDate) })
        
        // If no modern data, fall back to entries
        if uniqueDays.isEmpty {
            uniqueDays.formUnion(entries.map { calendar.startOfDay(for: $0.startDate) })
        }
        
        return uniqueDays.count
    }
    
    /// Returns the last time this shoe was used
    var lastUsed: Date? {
        var dates: [Date] = []
        
        // Add dates from sessions
        dates.append(contentsOf: sessions.compactMap { $0.endDate })
        dates.append(contentsOf: sessions.map { $0.startDate })
        
        // Add dates from hour attributions
        dates.append(contentsOf: hourAttributions.map { $0.hourDate })
        
        // If no modern data, fall back to entries
        if dates.isEmpty {
            dates.append(contentsOf: entries.map { $0.endDate })
        }
        
        return dates.max()
    }
    
    /// Returns total hours this shoe has been worn
    var totalWearTimeHours: Double {
        return sessions.reduce(0) { $0 + $1.durationInHours }
    }
    
    /// Returns total repairs performed on this shoe
    var totalRepairs: Int {
        return entries.filter { $0.repair }.count
    }
    
    // MARK: - Business Logic Methods
    
    func archive() {
        archived = true
    }
    
    func unarchive() {
        archived = false
    }
    
    /// Safely sets this shoe as default, ensuring only one shoe is default at a time
    /// - Parameters:
    ///   - default: Whether to make this shoe the default
    ///   - modelContext: SwiftData context to fetch and update other shoes
    func setDefault(_ default: Bool, in modelContext: ModelContext) {
        guard !archived else { 
            print("⚠️ Cannot set archived shoe as default: \(brand) \(model)")
            return 
        }
        
        if `default` {
            // Remove default status from all other shoes first
            removeDefaultFromAllOtherShoes(in: modelContext)
            isDefault = true
            print("✅ Set as default shoe: \(brand) \(model)")
        } else {
            isDefault = false
            print("➖ Removed default status: \(brand) \(model)")
        }
    }
    
    /// Removes default status from all other shoes in the database
    private func removeDefaultFromAllOtherShoes(in modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Shoe>(
            predicate: #Predicate<Shoe> { shoe in
                shoe.isDefault == true
            }
        )
        
        do {
            let defaultShoes = try modelContext.fetch(descriptor)
            for shoe in defaultShoes {
                if shoe.persistentModelID != self.persistentModelID {
                    shoe.isDefault = false
                    print("➖ Removed default status: \(shoe.brand) \(shoe.model)")
                }
            }
            try modelContext.save()
        } catch {
            print("❌ Error removing default status from other shoes: \(error)")
        }
    }
}

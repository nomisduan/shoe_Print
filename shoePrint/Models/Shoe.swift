//
//  Shoe.swift
//  shoePrint
//
//  Created by Simon Naud on 11/04/2025.
//

import Foundation
import SwiftData

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
    
    // MARK: - Session Relationship
    @Relationship(deleteRule: .cascade, inverse: \ShoeSession.shoe)
    var sessions: [ShoeSession] = []

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
    }
    
    // MARK: - Session-based Computed Properties
    
    /// Returns the currently active session, if any
    var activeSession: ShoeSession? {
        sessions.first(where: { $0.isActive })
    }
    
    /// Returns true if this shoe has an active session (currently being worn)
    var isActive: Bool {
        activeSession != nil
    }
    
    /// Returns the timestamp when the shoe was last activated (for compatibility)
    var activatedAt: Date? {
        activeSession?.startDate
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
    
    // MARK: - Computed Properties
    
    var totalDistance: Double {
        entries.reduce(0) { $0 + $1.distance }
    }
    
    var totalSteps: Int {
        entries.reduce(0) { $0 + $1.steps }
    }
    
    var totalRepairs: Int {
        entries.filter { $0.repair }.count
    }
    
    var lastUsed: Date? {
        entries.map { $0.endDate }.max()
    }
    
    var usageDays: Int {
        let calendar = Calendar.current
        let uniqueDays = Set(entries.map { calendar.startOfDay(for: $0.startDate) })
        return uniqueDays.count
    }
    
    var lifespanProgress: Double {
        guard estimatedLifespan > 0 else { return 0.0 }
        return min(totalDistance / estimatedLifespan, 1.0)
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

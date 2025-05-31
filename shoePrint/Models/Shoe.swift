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
    var isActive: Bool // Currently worn shoe
    var isDefault: Bool // Default shoe for automatic daily activation
    var activatedAt: Date? // Timestamp when the shoe was activated
    var purchaseDate: Date?
    var purchasePrice: Double?
    var estimatedLifespan: Double // in kilometers
    var entries: [StepEntry]
    
    init(timestamp: Date = .now, brand: String = "barefoot", model: String = "yours", notes: String = "", icon: String = "🦶", color: String = "CustomPurple", archived: Bool = false, isActive: Bool = false, isDefault: Bool = false, activatedAt: Date? = nil, purchaseDate: Date? = nil, purchasePrice: Double? = nil, estimatedLifespan: Double = 800.0, entries: [StepEntry] = []) {
        self.timestamp = timestamp
        self.brand = brand
        self.model = model
        self.notes = notes
        self.icon = icon
        self.color = color
        self.archived = archived
        self.isActive = isActive
        self.isDefault = isDefault
        self.activatedAt = activatedAt
        self.purchaseDate = purchaseDate
        self.purchasePrice = purchasePrice
        self.estimatedLifespan = estimatedLifespan
        self.entries = entries
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
        isActive = false // Archived shoe cannot be active
    }
    
    func unarchive() {
        archived = false
    }
    
    /// Safely sets this shoe as active, ensuring only one shoe is active at a time
    /// - Parameters:
    ///   - active: Whether to make this shoe active
    ///   - modelContext: SwiftData context to fetch and update other shoes
    func setActive(_ active: Bool, in modelContext: ModelContext) {
        guard !archived else { 
            print("⚠️ Cannot activate archived shoe: \(brand) \(model)")
            return 
        }
        
        if active {
            // Deactivate all other shoes first
            deactivateAllOtherShoes(in: modelContext)
            isActive = true
            activatedAt = Date() // Set activation timestamp for future data attribution
            print("✅ Activated shoe: \(brand) \(model) at \(activatedAt!)")
        } else {
            isActive = false
            activatedAt = nil // Clear activation timestamp
            print("➖ Deactivated shoe: \(brand) \(model)")
        }
    }
    
    /// Deactivates all other shoes in the database
    private func deactivateAllOtherShoes(in modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Shoe>(
            predicate: #Predicate<Shoe> { shoe in
                shoe.isActive == true
            }
        )
        
        do {
            let activeShoes = try modelContext.fetch(descriptor)
            for shoe in activeShoes {
                if shoe.persistentModelID != self.persistentModelID {
                    shoe.isActive = false
                    shoe.activatedAt = nil // Clear activation timestamp
                    print("➖ Deactivated shoe: \(shoe.brand) \(shoe.model)")
                }
            }
            try modelContext.save()
        } catch {
            print("❌ Error deactivating other shoes: \(error)")
        }
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

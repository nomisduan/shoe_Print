//
//  ShoeMigrationPlan.swift
//  shoePrint
//
//  Created by Simon Naud on 31/05/2025.
//

import Foundation
import SwiftData

/// Schema migration plan for transitioning from old Shoe model to session-based architecture
enum ShoeMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [ShoeSchemaV1.self, ShoeSchemaV2.self]
    }
    
    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }
    
    static let migrateV1toV2 = MigrationStage.custom(
        fromVersion: ShoeSchemaV1.self,
        toVersion: ShoeSchemaV2.self,
        willMigrate: { context in
            print("🔄 Starting migration from V1 to V2...")
        },
        didMigrate: { context in
            print("✅ Migration from V1 to V2 completed")
        }
    )
}

/// Original schema (V1) with isActive and activatedAt
enum ShoeSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    
    static var models: [any PersistentModel.Type] {
        [Shoe.self, StepEntry.self]
    }
    
    @Model
    final class Shoe {
        var timestamp: Date
        var brand: String
        var model: String
        var notes: String
        var icon: String
        var color: String
        var archived: Bool
        var isActive: Bool
        var activatedAt: Date?
        var isDefault: Bool
        var purchaseDate: Date?
        var purchasePrice: Double?
        var estimatedLifespan: Double
        var entries: [StepEntry]
        
        init(timestamp: Date = .now, brand: String = "barefoot", model: String = "yours", notes: String = "", icon: String = "🦶", color: String = "CustomPurple", archived: Bool = false, isActive: Bool = false, activatedAt: Date? = nil, isDefault: Bool = false, purchaseDate: Date? = nil, purchasePrice: Double? = nil, estimatedLifespan: Double = 500.0, entries: [StepEntry] = []) {
            self.timestamp = timestamp
            self.brand = brand
            self.model = model
            self.notes = notes
            self.icon = icon
            self.color = color
            self.archived = archived
            self.isActive = isActive
            self.activatedAt = activatedAt
            self.isDefault = isDefault
            self.purchaseDate = purchaseDate
            self.purchasePrice = purchasePrice
            self.estimatedLifespan = estimatedLifespan
            self.entries = entries
        }
    }
    
    @Model
    final class StepEntry {
        var timestamp: Date
        var startDate: Date
        var endDate: Date
        var steps: Int
        var distance: Double
        var source: String
        var shoe: Shoe?
        
        init(timestamp: Date = .now, startDate: Date = .now, endDate: Date = .now, steps: Int = 0, distance: Double = 0.0, source: String = "manual", shoe: Shoe? = nil) {
            self.timestamp = timestamp
            self.startDate = startDate
            self.endDate = endDate
            self.steps = steps
            self.distance = distance
            self.source = source
            self.shoe = shoe
        }
    }
}

/// New schema (V2) with ShoeSession relationship
enum ShoeSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    
    static var models: [any PersistentModel.Type] {
        [Shoe.self, StepEntry.self, ShoeSession.self]
    }
    
    @Model
    final class Shoe {
        var timestamp: Date
        var brand: String
        var model: String
        var notes: String
        var icon: String
        var color: String
        var archived: Bool
        var isDefault: Bool
        var purchaseDate: Date?
        var purchasePrice: Double?
        var estimatedLifespan: Double
        var entries: [StepEntry]
        
        @Relationship(deleteRule: .cascade, inverse: \ShoeSession.shoe)
        var sessions: [ShoeSession] = []
        
        init(timestamp: Date = .now, brand: String = "barefoot", model: String = "yours", notes: String = "", icon: String = "🦶", color: String = "CustomPurple", archived: Bool = false, isDefault: Bool = false, purchaseDate: Date? = nil, purchasePrice: Double? = nil, estimatedLifespan: Double = 500.0, entries: [StepEntry] = []) {
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
    }
    
    @Model
    final class StepEntry {
        var timestamp: Date
        var startDate: Date
        var endDate: Date
        var steps: Int
        var distance: Double
        var source: String
        var shoe: Shoe?
        
        init(timestamp: Date = .now, startDate: Date = .now, endDate: Date = .now, steps: Int = 0, distance: Double = 0.0, source: String = "manual", shoe: Shoe? = nil) {
            self.timestamp = timestamp
            self.startDate = startDate
            self.endDate = endDate
            self.steps = steps
            self.distance = distance
            self.source = source
            self.shoe = shoe
        }
    }
    
    @Model
    final class ShoeSession {
        var startDate: Date
        var endDate: Date?
        var autoStarted: Bool
        var autoClosed: Bool
        var shoe: Shoe?
        
        init(startDate: Date = Date(), endDate: Date? = nil, autoStarted: Bool = false, autoClosed: Bool = false, shoe: Shoe? = nil) {
            self.startDate = startDate
            self.endDate = endDate
            self.autoStarted = autoStarted
            self.autoClosed = autoClosed
            self.shoe = shoe
        }
    }
} 
//
//  ShoePropertyService.swift
//  shoePrint
//
//  Created by Simon Naud on 31/05/2025.
//

import Foundation
import SwiftData

/// Centralized service for managing shoe computed properties
/// ✅ Provides SwiftData-safe methods for property updates
@MainActor
final class ShoePropertyService {
    
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Batch Operations
    
    /// Refreshes computed properties for multiple shoes efficiently
    func refreshMultipleShoes(_ shoes: [Shoe]) async {
        print("🔄 Batch refreshing \(shoes.count) shoes...")
        
        // Batch fetch all sessions to minimize database queries
        // Note: SwiftData predicates don't support contains() with arrays, so we'll fetch all sessions
        let allSessionsDescriptor = FetchDescriptor<ShoeSession>()
        
        do {
            let allSessions = try modelContext.fetch(allSessionsDescriptor)
            
            // Filter and group sessions by the shoes we're updating
            let shoeIDs = Set(shoes.map { $0.persistentModelID })
            let relevantSessions = allSessions.filter { session in
                guard let shoeID = session.shoe?.persistentModelID else { return false }
                return shoeIDs.contains(shoeID)
            }
            
            // Group sessions by shoe for efficient processing
            let sessionsByShoe = Dictionary(grouping: relevantSessions) { session in
                session.shoe?.persistentModelID
            }
            
            // Update each shoe with its sessions
            for shoe in shoes {
                let shoeSessions = sessionsByShoe[shoe.persistentModelID] ?? []
                await refreshShoeWithSessions(shoe, sessions: shoeSessions)
            }
            
            print("✅ Batch refresh completed for \(shoes.count) shoes")
        } catch {
            print("❌ Error in batch refresh: \(error)")
            // Fallback to individual refresh
            for shoe in shoes {
                await shoe.refreshComputedProperties(using: modelContext)
            }
        }
    }
    
    /// Refreshes all shoes in the database
    func refreshAllShoes() async {
        let descriptor = FetchDescriptor<Shoe>()
        
        do {
            let allShoes = try modelContext.fetch(descriptor)
            await refreshMultipleShoes(allShoes)
        } catch {
            print("❌ Error fetching all shoes for refresh: \(error)")
        }
    }
    
    // MARK: - Individual Operations
    
    /// Refreshes a single shoe with pre-fetched sessions (for efficiency)
    private func refreshShoeWithSessions(_ shoe: Shoe, sessions: [ShoeSession]) async {
        let activeSessions = sessions.filter { $0.endDate == nil }
        // ✅ Use fallback pattern to avoid double-counting
        let sessionDistance = sessions.reduce(0) { $0 + $1.distance }
        let newDistance: Double
        if !sessions.isEmpty {
            newDistance = sessionDistance
        } else {
            newDistance = shoe.entries.reduce(0) { $0 + $1.distance }
        }
        
        // Update computed properties
        let wasActive = shoe.isActive
        let oldDistance = shoe.totalDistance
        
        shoe.isActive = !activeSessions.isEmpty
        shoe.activatedAt = activeSessions.first?.startDate
        shoe.totalDistance = newDistance
        shoe.lifespanProgress = min(shoe.totalDistance / max(shoe.estimatedLifespan, 1.0), 1.0)
        
        if wasActive != shoe.isActive || abs(oldDistance - shoe.totalDistance) > 0.01 {
            print("🔄 Updated \(shoe.brand) \(shoe.model): active \(wasActive)→\(shoe.isActive), distance \(String(format: "%.1f", oldDistance))→\(String(format: "%.1f", shoe.totalDistance)) km")
        }
    }
    
    // MARK: - Session-Triggered Updates
    
    /// Updates shoes affected by session changes
    func updateShoesAfterSessionChange(affectedShoes: [Shoe]) async {
        guard !affectedShoes.isEmpty else { return }
        
        print("🔄 Updating \(affectedShoes.count) shoes after session change...")
        await refreshMultipleShoes(affectedShoes)
    }
    
    /// Updates a single shoe after its session changes
    func updateShoeAfterSessionChange(_ shoe: Shoe) async {
        await shoe.refreshComputedProperties(using: modelContext)
    }
    
    // MARK: - Validation & Diagnostics
    
    /// Validates computed properties against database state
    func validateShoeProperties(_ shoe: Shoe) async -> Bool {
        do {
            // Fetch all sessions and filter manually (SwiftData predicate limitation)
            let allSessionsDescriptor = FetchDescriptor<ShoeSession>()
            let allSessions = try modelContext.fetch(allSessionsDescriptor)
            let actualSessions = allSessions.filter { session in
                session.shoe?.persistentModelID == shoe.persistentModelID
            }
            
            // Calculate expected values
            let expectedIsActive = actualSessions.contains { $0.endDate == nil }
            let expectedDistance = actualSessions.reduce(0) { $0 + $1.distance } + 
                                 shoe.entries.reduce(0) { $0 + $1.distance }
            
            // Check for discrepancies
            let activeCorrect = shoe.isActive == expectedIsActive
            let distanceCorrect = abs(shoe.totalDistance - expectedDistance) < 0.01
            
            if !activeCorrect || !distanceCorrect {
                print("⚠️ Property mismatch for \(shoe.brand) \(shoe.model):")
                print("   Active: expected \(expectedIsActive), got \(shoe.isActive)")
                print("   Distance: expected \(String(format: "%.1f", expectedDistance)), got \(String(format: "%.1f", shoe.totalDistance))")
                return false
            }
            
            return true
        } catch {
            print("❌ Error validating properties for \(shoe.brand) \(shoe.model): \(error)")
            return false
        }
    }
    
    /// Runs validation on all shoes and fixes any inconsistencies
    func validateAndFixAllShoes() async {
        print("🔍 Validating all shoe properties...")
        
        let descriptor = FetchDescriptor<Shoe>()
        do {
            let allShoes = try modelContext.fetch(descriptor)
            var invalidShoes: [Shoe] = []
            
            for shoe in allShoes {
                let isValid = await validateShoeProperties(shoe)
                if !isValid {
                    invalidShoes.append(shoe)
                }
            }
            
            if !invalidShoes.isEmpty {
                print("🔧 Fixing \(invalidShoes.count) shoes with invalid properties...")
                await refreshMultipleShoes(invalidShoes)
            } else {
                print("✅ All shoe properties are valid")
            }
        } catch {
            print("❌ Error validating shoes: \(error)")
        }
    }
}
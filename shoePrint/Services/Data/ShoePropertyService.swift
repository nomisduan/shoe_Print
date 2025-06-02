//
//  ShoePropertyService.swift
//  shoePrint
//
//  Created by Simon Naud on 31/05/2025.
//

import Foundation
import SwiftData

/// Centralized service for managing shoe data operations
/// ✅ With proper computed properties, this service is mainly for data validation and batch operations
@MainActor
final class ShoePropertyService {
    
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Batch Operations
    
    /// Forces SwiftData to refresh relationships for multiple shoes
    /// ✅ With proper computed properties, this mainly ensures relationship loading
    func refreshMultipleShoes(_ shoes: [Shoe]) async {
        print("🔄 Refreshing \(shoes.count) shoes (computed properties are now reactive)...")
        
        // Force relationship refresh by accessing them
        for shoe in shoes {
            // Accessing computed properties forces relationship loading in SwiftData
            let _ = shoe.isActive
            let _ = shoe.totalDistance
            let _ = shoe.totalSteps
        }
        
        print("✅ Relationship refresh completed for \(shoes.count) shoes")
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
    
    
    // MARK: - Session-Triggered Updates
    
    /// Forces relationship refresh for shoes affected by session changes
    func updateShoesAfterSessionChange(affectedShoes: [Shoe]) async {
        guard !affectedShoes.isEmpty else { return }
        
        print("🔄 Triggering computed property updates for \(affectedShoes.count) shoes...")
        await refreshMultipleShoes(affectedShoes)
    }
    
    /// Forces relationship refresh for a single shoe after session changes
    func updateShoeAfterSessionChange(_ shoe: Shoe) async {
        // Force computed property access to trigger relationship loading
        let _ = shoe.isActive
        let _ = shoe.totalDistance
        print("🔄 Triggered computed property update for \(shoe.brand) \(shoe.model)")
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
//
//  IntelligentActivationService.swift
//  shoePrint
//
//  Created by Simon Naud on 11/04/2025.
//

import Foundation
import SwiftData

/// Service responsible for intelligent shoe activation and deactivation
/// Handles auto-deactivation after inactivity and auto-activation of default shoes
@MainActor
final class IntelligentActivationService: ObservableObject {
    
    // MARK: - Properties
    
    private let modelContext: ModelContext
    private let inactivityThreshold: TimeInterval = 5 * 60 * 60 // 5 hours in seconds
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Public Methods
    
    /// Checks for inactive shoes and deactivates them if they've been inactive for too long
    func checkAndDeactivateInactiveShoes() async {
        let activeShoes = await getActiveShoes()
        let now = Date()
        
        for shoe in activeShoes {
            if let activatedAt = shoe.activatedAt {
                let timeSinceActivation = now.timeIntervalSince(activatedAt)
                
                // Check if there are any recent steps for this shoe
                let hasRecentSteps = await hasRecentSteps(for: shoe, within: inactivityThreshold)
                
                if !hasRecentSteps && timeSinceActivation > inactivityThreshold {
                    print("⏰ Auto-deactivating \(shoe.brand) \(shoe.model) after \(timeSinceActivation/3600) hours of inactivity")
                    shoe.setActive(false, in: modelContext)
                }
            }
        }
    }
    
    /// Activates default shoe if no shoe is currently active and there are new steps today
    func checkAndActivateDefaultShoe() async {
        // Only proceed if no shoe is currently active
        let activeShoes = await getActiveShoes()
        guard activeShoes.isEmpty else { return }
        
        // Check if there are steps today that aren't attributed to any shoe
        let hasUnattributedStepsToday = await hasUnattributedStepsToday()
        guard hasUnattributedStepsToday else { return }
        
        // Get the default shoe
        let defaultShoe = await getDefaultShoe()
        guard let defaultShoe = defaultShoe else {
            print("📱 No default shoe set - cannot auto-activate")
            return
        }
        
        print("🚀 Auto-activating default shoe: \(defaultShoe.brand) \(defaultShoe.model)")
        defaultShoe.setActive(true, in: modelContext)
    }
    
    // MARK: - Private Helper Methods
    
    /// Gets all currently active shoes
    private func getActiveShoes() async -> [Shoe] {
        let descriptor = FetchDescriptor<Shoe>(
            predicate: #Predicate<Shoe> { shoe in
                shoe.isActive == true && shoe.archived == false
            }
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("❌ Error fetching active shoes: \(error)")
            return []
        }
    }
    
    /// Gets the default shoe
    private func getDefaultShoe() async -> Shoe? {
        let descriptor = FetchDescriptor<Shoe>(
            predicate: #Predicate<Shoe> { shoe in
                shoe.isDefault == true && shoe.archived == false
            }
        )
        
        do {
            let defaultShoes = try modelContext.fetch(descriptor)
            return defaultShoes.first
        } catch {
            print("❌ Error fetching default shoe: \(error)")
            return nil
        }
    }
    
    /// Checks if a shoe has recent steps within the specified time interval
    private func hasRecentSteps(for shoe: Shoe, within timeInterval: TimeInterval) async -> Bool {
        let now = Date()
        let cutoffTime = now.addingTimeInterval(-timeInterval)
        
        // Get the persistent ID first to avoid complex predicate expressions
        let shoeID = shoe.persistentModelID
        
        let descriptor = FetchDescriptor<StepEntry>(
            predicate: #Predicate<StepEntry> { entry in
                entry.startDate >= cutoffTime
            }
        )
        
        do {
            let recentEntries = try modelContext.fetch(descriptor)
            // Filter entries that belong to this shoe
            let shoeEntries = recentEntries.filter { entry in
                entry.shoe?.persistentModelID == shoeID
            }
            return !shoeEntries.isEmpty
        } catch {
            print("❌ Error checking recent steps for shoe: \(error)")
            return false
        }
    }
    
    /// Checks if there are unattributed steps today
    private func hasUnattributedStepsToday() async -> Bool {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? Date()
        
        // Check for hourly entries without attribution
        let descriptor = FetchDescriptor<StepEntry>(
            predicate: #Predicate<StepEntry> { entry in
                entry.source == "hourly" &&
                entry.shoe == nil &&
                entry.startDate >= startOfDay &&
                entry.startDate < endOfDay
            }
        )
        
        do {
            let unattributedEntries = try modelContext.fetch(descriptor)
            return !unattributedEntries.isEmpty
        } catch {
            print("❌ Error checking unattributed steps: \(error)")
            return false
        }
    }
} 
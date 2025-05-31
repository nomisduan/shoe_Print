//
//  DataAttributionService.swift
//  shoePrint
//
//  Created by Simon Naud on 11/04/2025.
//

import Foundation
import SwiftData

/// Service responsible for attributing walking sessions to specific shoes
/// Handles the business logic of connecting HealthKit data to shoe usage
@MainActor
final class DataAttributionService: ObservableObject {
    
    // MARK: - Properties
    
    private let modelContext: ModelContext
    
    @Published var unattributedSessions: [WalkingSession] = []
    @Published var isProcessing = false
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Attribution Logic
    
    /// Processes new walking sessions and determines attribution strategy
    /// - Parameter sessions: Array of walking sessions from HealthKit
    func processWalkingSessions(_ sessions: [WalkingSession]) async {
        isProcessing = true
        
        // Filter out sessions that are already attributed
        let newSessions = await filterUnattributedSessions(sessions)
        
        // Try automatic attribution first
        let (autoAttributed, remaining) = await attemptAutomaticAttribution(newSessions)
        
        // Save automatically attributed sessions
        for attribution in autoAttributed {
            await saveAttribution(attribution)
        }
        
        // Store remaining sessions for manual attribution
        unattributedSessions = remaining
        
        isProcessing = false
    }
    
    /// Manually attributes a walking session to a specific shoe
    /// - Parameters:
    ///   - session: The walking session to attribute
    ///   - shoe: The shoe to attribute the session to
    func attributeSessionToShoe(_ session: WalkingSession, to shoe: Shoe) async {
        let stepEntry = createStepEntry(from: session, for: shoe)
        
        modelContext.insert(stepEntry)
        
        do {
            try modelContext.save()
            
            // Remove from unattributed sessions
            unattributedSessions.removeAll { $0.id == session.id }
            
            print("✅ Successfully attributed session to \(shoe.brand) \(shoe.model)")
        } catch {
            print("❌ Failed to save attribution: \(error)")
        }
    }
    
    /// Bulk attribution of multiple sessions to a single shoe
    /// - Parameters:
    ///   - sessions: Array of sessions to attribute
    ///   - shoe: The target shoe
    func attributeSessionsToShoe(_ sessions: [WalkingSession], to shoe: Shoe) async {
        for session in sessions {
            let stepEntry = createStepEntry(from: session, for: shoe)
            modelContext.insert(stepEntry)
        }
        
        do {
            try modelContext.save()
            
            // Remove attributed sessions
            let attributedIds = Set(sessions.map { $0.id })
            unattributedSessions.removeAll { attributedIds.contains($0.id) }
            
            print("✅ Successfully attributed \(sessions.count) sessions to \(shoe.brand) \(shoe.model)")
        } catch {
            print("❌ Failed to save bulk attribution: \(error)")
        }
    }
    
    /// Dismisses a walking session (marks as not relevant for tracking)
    /// - Parameter session: The session to dismiss
    func dismissSession(_ session: WalkingSession) {
        unattributedSessions.removeAll { $0.id == session.id }
    }
    
    // MARK: - Private Methods
    
    /// Filters out sessions that have already been attributed to shoes
    private func filterUnattributedSessions(_ sessions: [WalkingSession]) async -> [WalkingSession] {
        // Fetch existing step entries to avoid duplicates
        let descriptor = FetchDescriptor<StepEntry>(
            predicate: #Predicate<StepEntry> { entry in
                entry.source == "HealthKit"
            }
        )
        
        do {
            let existingEntries = try modelContext.fetch(descriptor)
            let existingDates = Set(existingEntries.map { 
                Calendar.current.startOfDay(for: $0.startDate) 
            })
            
            return sessions.filter { session in
                let sessionDay = Calendar.current.startOfDay(for: session.startDate)
                return !existingDates.contains(sessionDay)
            }
        } catch {
            print("❌ Error fetching existing entries: \(error)")
            return sessions
        }
    }
    
    /// Attempts to automatically attribute sessions based on active shoe and usage patterns
    private func attemptAutomaticAttribution(_ sessions: [WalkingSession]) async -> ([SessionAttribution], [WalkingSession]) {
        var attributed: [SessionAttribution] = []
        var remaining: [WalkingSession] = []
        
        // Fetch active shoes
        let activeShoeDescriptor = FetchDescriptor<Shoe>(
            predicate: #Predicate<Shoe> { shoe in
                shoe.isActive && !shoe.archived
            }
        )
        
        do {
            let activeShoes = try modelContext.fetch(activeShoeDescriptor)
            
            for session in sessions {
                if let attribution = await autoAttributeSession(session, to: activeShoes) {
                    attributed.append(attribution)
                } else {
                    remaining.append(session)
                }
            }
        } catch {
            print("❌ Error fetching active shoes: \(error)")
            remaining = sessions
        }
        
        return (attributed, remaining)
    }
    
    /// Attempts to automatically attribute a single session
    private func autoAttributeSession(_ session: WalkingSession, to activeShoes: [Shoe]) async -> SessionAttribution? {
        // Strategy 1: If there's exactly one active shoe, attribute to it
        if activeShoes.count == 1 {
            return SessionAttribution(session: session, shoe: activeShoes[0])
        }
        
        // Strategy 2: Use usage patterns (could be expanded with ML in the future)
        // For now, we'll be conservative and only auto-attribute in clear cases
        
        return nil
    }
    
    /// Saves an attribution by creating a StepEntry
    private func saveAttribution(_ attribution: SessionAttribution) async {
        let stepEntry = createStepEntry(from: attribution.session, for: attribution.shoe)
        modelContext.insert(stepEntry)
        
        do {
            try modelContext.save()
            print("✅ Auto-attributed session to \(attribution.shoe.brand) \(attribution.shoe.model)")
        } catch {
            print("❌ Failed to save auto-attribution: \(error)")
        }
    }
    
    /// Creates a StepEntry from a WalkingSession and Shoe
    private func createStepEntry(from session: WalkingSession, for shoe: Shoe) -> StepEntry {
        return StepEntry(
            startDate: session.startDate,
            endDate: session.endDate,
            steps: session.totalSteps,
            distance: session.distanceInKilometers,
            repair: false,
            shoe: shoe,
            source: session.source
        )
    }
}

// MARK: - Supporting Types

/// Represents an attribution of a walking session to a specific shoe
struct SessionAttribution {
    let session: WalkingSession
    let shoe: Shoe
} 
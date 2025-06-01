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
    var sessions: [ShoeSession] = [] {
        didSet {
            // Automatically update computed properties when sessions change
            _isActive = computeIsActive()
            _activatedAt = computeActivatedAt()
            // Update distance when sessions change
            updateTotalDistance()
        }
    }
    
    // MARK: - Stored Properties for Observable State
    
    /// Stored property for active state (observable by SwiftUI)
    private var _isActive: Bool = false
    
    /// Stored property for activation date (observable by SwiftUI)
    private var _activatedAt: Date? = nil
    
    /// Stored property for total distance (observable by SwiftUI)
    private var _totalDistance: Double = 0.0 {
        didSet {
            // Update lifespan progress when distance changes
            _lifespanProgress = computeLifespanProgress()
        }
    }
    
    /// Stored property for lifespan progress (observable by SwiftUI)
    private var _lifespanProgress: Double = 0.0

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
        
        // Initialize computed properties
        self._isActive = false
        self._activatedAt = nil
        // Initialize with entries distance (sessions will be empty at init)
        self._totalDistance = entries.reduce(0) { $0 + $1.distance }
        self._lifespanProgress = computeLifespanProgress()
        
        print("🏗️ DEBUG: Initialized shoe \(brand) \(model) with distance: \(_totalDistance) km from \(entries.count) entries")
    }
    
    // MARK: - Public Observable Properties
    
    /// Returns true if this shoe has an active session (currently being worn)
    var isActive: Bool {
        get { _isActive }
        set { _isActive = newValue }
    }
    
    /// Returns the timestamp when the shoe was last activated
    var activatedAt: Date? {
        get { _activatedAt }
        set { _activatedAt = newValue }
    }
    
    /// Returns the total distance for this shoe
    var totalDistance: Double {
        get { _totalDistance }
        set { _totalDistance = newValue }
    }
    
    /// Returns the lifespan progress (0.0 to 1.0)
    var lifespanProgress: Double {
        get { _lifespanProgress }
        set { _lifespanProgress = newValue }
    }
    
    // MARK: - Session-based Computed Properties (for internal use)
    
    /// Returns the currently active session, if any
    var activeSession: ShoeSession? {
        sessions.first(where: { $0.isActive })
    }
    
    /// Computes if the shoe is currently active
    private func computeIsActive() -> Bool {
        return activeSession != nil
    }
    
    /// Computes the activation date
    private func computeActivatedAt() -> Date? {
        return activeSession?.startDate
    }
    
    /// Computes the lifespan progress
    private func computeLifespanProgress() -> Double {
        guard estimatedLifespan > 0 else { return 0.0 }
        return min(_totalDistance / estimatedLifespan, 1.0)
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
    
    // MARK: - Methods to Update Observable Properties
    
    /// Updates the active state based on current sessions
    func updateActiveState() {
        let newActiveState = computeIsActive()
        let newActivatedAt = computeActivatedAt()
        
        if _isActive != newActiveState || _activatedAt != newActivatedAt {
            _isActive = newActiveState
            _activatedAt = newActivatedAt
            print("🔄 Updated active state for \(brand) \(model): active=\(_isActive)")
        }
    }
    
    /// Updates the total distance based on current sessions (not entries)
    func updateTotalDistance() {
        let newDistance = computeTotalDistanceFromSessions()
        if _totalDistance != newDistance {
            let oldDistance = _totalDistance
            _totalDistance = newDistance
            print("🔄 Updated total distance for \(brand) \(model): \(oldDistance) -> \(_totalDistance) km")
        }
    }
    
    /// Forces a refresh of the total distance calculation
    /// Call this when you suspect the distance might be out of sync
    func refreshDistance() {
        print("🔄 Force refreshing distance for \(brand) \(model)")
        _totalDistance = computeTotalDistanceFromSessions()
        _lifespanProgress = computeLifespanProgress()
    }
    
    /// Call this after SwiftData has loaded all relationships
    /// This ensures that sessions are available for distance calculation
    func refreshAfterRelationshipsLoaded() {
        print("📊 DEBUG: Refreshing \(brand) \(model) after relationships loaded")
        print("📊 DEBUG: Found \(sessions.count) sessions")
        refreshDistance()
        updateActiveState()
    }
    
    /// Computes total distance from all sessions for this shoe
    private func computeTotalDistanceFromSessions() -> Double {
        // Use real stored data from sessions
        let sessionDistance = sessions.reduce(0) { total, session in
            return total + session.distance
        }
        
        // Also include legacy entries for backward compatibility
        let entriesDistance = entries.reduce(0) { $0 + $1.distance }
        
        let totalDistance = sessionDistance + entriesDistance
        
        print("🔍 Distance calculation for \(brand) \(model):")
        print("   - Sessions: \(sessions.count) sessions = \(sessionDistance) km (real data)")
        print("   - Entries: \(entries.count) entries = \(entriesDistance) km (legacy)") 
        print("   - Total: \(totalDistance) km")
        
        return totalDistance
    }
    
    /// Updates all computed properties
    func updateComputedProperties() {
        updateActiveState()
        updateTotalDistance()
    }
    
    // MARK: - Session-based Computed Properties
    
    /// Returns total steps from all sessions (real data)
    var totalStepsFromSessions: Int {
        return sessions.reduce(0) { total, session in
            return total + session.steps
        }
    }
    
    /// Returns the number of days this shoe has been used
    var usageDaysFromSessions: Int {
        let calendar = Calendar.current
        let uniqueDays = Set(sessions.map { session in
            calendar.startOfDay(for: session.startDate)
        })
        return uniqueDays.count
    }
    
    /// Returns the last time this shoe was used
    var lastUsedFromSessions: Date? {
        return sessions.compactMap { $0.endDate }.max() ?? sessions.map { $0.startDate }.max()
    }
    
    /// Returns total hours this shoe has been worn
    var totalWearTimeHours: Double {
        return sessions.reduce(0) { total, session in
            total + session.durationInHours
        }
    }
    
    // MARK: - Legacy Computed Properties (for backward compatibility)
    
    var totalSteps: Int {
        // Use session-based calculation if sessions exist, otherwise fall back to entries
        if !sessions.isEmpty {
            return totalStepsFromSessions
        } else {
            return entries.reduce(0) { $0 + $1.steps }
        }
    }
    
    var totalRepairs: Int {
        entries.filter { $0.repair }.count
    }
    
    var lastUsed: Date? {
        // Use session-based calculation if sessions exist, otherwise fall back to entries
        if !sessions.isEmpty {
            return lastUsedFromSessions
        } else {
            return entries.map { $0.endDate }.max()
        }
    }
    
    var usageDays: Int {
        // Use session-based calculation if sessions exist, otherwise fall back to entries
        if !sessions.isEmpty {
            return usageDaysFromSessions
        } else {
            let calendar = Calendar.current
            let uniqueDays = Set(entries.map { calendar.startOfDay(for: $0.startDate) })
            return uniqueDays.count
        }
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

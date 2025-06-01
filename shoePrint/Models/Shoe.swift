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
    // ✅ Removed broken didSet pattern - relationships load asynchronously in SwiftData
    @Relationship(deleteRule: .cascade, inverse: \ShoeSession.shoe)
    var sessions: [ShoeSession] = []
    
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
    /// ⚠️ Only reliable if relationships are loaded - prefer database queries
    var activeSession: ShoeSession? {
        sessions.first(where: { $0.isActive })
    }
    
    /// Gets active session using database query (always reliable)
    func getActiveSession(using modelContext: ModelContext) async -> ShoeSession? {
        do {
            // Fetch all active sessions and filter manually (SwiftData predicate limitation)
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
    
    // MARK: - Explicit Refresh Methods (SwiftData-Safe)
    
    /// Refreshes all computed properties using database queries
    /// ✅ Safe for SwiftData - doesn't rely on relationship loading state
    func refreshComputedProperties(using modelContext: ModelContext) async {
        print("🔄 Refreshing computed properties for \(brand) \(model) using database queries")
        
        do {
            // ✅ Add delay to ensure database consistency after deletions
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
            
            // ✅ Wrap database operations in error handling to prevent SwiftData macro crashes
            let (activeSessions, allSessions) = await withTaskGroup(of: (activeSessions: [ShoeSession], allSessions: [ShoeSession]).self) { group in
                group.addTask {
                    do {
                        // Query active sessions directly from database
                        let activeSessionsDescriptor = FetchDescriptor<ShoeSession>(
                            predicate: #Predicate<ShoeSession> { session in
                                session.endDate == nil
                            }
                        )
                        let allActiveSessions = try modelContext.fetch(activeSessionsDescriptor)
                        let activeSessions = allActiveSessions.compactMap { session -> ShoeSession? in
                            // ✅ Additional safety check to prevent SwiftData macro crashes
                            do {
                                // Try to access session properties safely
                                let _ = session.startDate
                                let _ = session.endDate
                                
                                guard let shoeID = session.shoe?.persistentModelID else { 
                                    print("⚠️ Found session with nil shoe reference - skipping")
                                    return nil
                                }
                                
                                if shoeID == self.persistentModelID {
                                    return session
                                }
                                return nil
                            } catch {
                                print("❌ Session property access failed (likely deleted): \(error.localizedDescription)")
                                return nil
                            }
                        }
                        
                        // Query all sessions for distance calculation
                        let allSessionsDescriptor = FetchDescriptor<ShoeSession>()
                        let allSessionsInDB = try modelContext.fetch(allSessionsDescriptor)
                        let allSessions = allSessionsInDB.compactMap { session -> ShoeSession? in
                            // ✅ Additional safety check to prevent SwiftData macro crashes
                            do {
                                // Try to access session properties safely
                                let _ = session.startDate
                                let _ = session.distance
                                let _ = session.steps
                                
                                guard let shoeID = session.shoe?.persistentModelID else { 
                                    print("⚠️ Found session with nil shoe reference - skipping")
                                    return nil
                                }
                                
                                if shoeID == self.persistentModelID {
                                    return session
                                }
                                return nil
                            } catch {
                                print("❌ Session property access failed (likely deleted): \(error.localizedDescription)")
                                return nil
                            }
                        }
                        
                        return (activeSessions: activeSessions, allSessions: allSessions)
                        
                    } catch {
                        print("❌ Database query failed: \(error.localizedDescription)")
                        return (activeSessions: [], allSessions: [])
                    }
                }
                
                // Return the result from the task
                for await result in group {
                    return result
                }
                return (activeSessions: [], allSessions: [])
            }
            
            // Update computed properties with fresh data
            let wasActive = _isActive
            let oldDistance = _totalDistance
            
            _isActive = !activeSessions.isEmpty
            _activatedAt = activeSessions.first?.startDate
            
            // ✅ Calculate total distance using fallback pattern with error handling
            let sessionDistance = allSessions.reduce(0) { total, session in
                do {
                    // ✅ Safe distance access with additional validation
                    let distance = session.distance
                    guard distance >= 0 else {
                        print("⚠️ Invalid session distance: \(distance) - skipping")
                        return total
                    }
                    return total + distance
                } catch {
                    print("❌ Failed to access session distance (likely deleted): \(error.localizedDescription)")
                    return total
                }
            }
            
            if !allSessions.isEmpty {
                // ✅ Use session-based calculation (new system)
                _totalDistance = sessionDistance
                print("📊 Using session-based distance: \(String(format: "%.1f", sessionDistance)) km from \(allSessions.count) sessions")
            } else {
                // ✅ Fallback to entries-based calculation (legacy system)
                let entriesDistance = entries.reduce(0) { total, entry in
                    guard entry.distance >= 0 else {
                        print("⚠️ Invalid entry distance: \(entry.distance) - skipping")
                        return total
                    }
                    return total + entry.distance
                }
                _totalDistance = entriesDistance
                print("📊 Using entries-based distance: \(String(format: "%.1f", entriesDistance)) km from \(entries.count) entries")
            }
            _lifespanProgress = computeLifespanProgress()
            
            print("✅ Properties updated: active \(wasActive)→\(_isActive), distance \(String(format: "%.1f", oldDistance))→\(String(format: "%.1f", _totalDistance)) km")
            
        } catch {
            print("❌ Critical error refreshing computed properties for \(brand) \(model): \(error.localizedDescription)")
            // ✅ Enhanced fallback with error isolation
            Task { @MainActor in
                do {
                    // ✅ Additional delay for crash recovery
                    try await Task.sleep(nanoseconds: 100_000_000) // 100ms
                    print("🔄 Attempting fallback memory refresh for \(brand) \(model)")
                    refreshComputedPropertiesFromMemory()
                } catch {
                    print("❌ Fallback also failed for \(brand) \(model): \(error.localizedDescription)")
                    // ✅ Final safe state - just reset to known values
                    _isActive = false
                    _activatedAt = nil
                    print("🛡️ Reset to safe state for \(brand) \(model)")
                }
            }
        }
    }
    
    /// Quick refresh using already-loaded relationships (fallback)
    /// ⚠️ Only use when you know relationships are loaded
    func refreshComputedPropertiesFromMemory() {
        let wasActive = _isActive
        let oldDistance = _totalDistance
        
        _isActive = sessions.contains { $0.isActive }
        _activatedAt = sessions.first(where: { $0.isActive })?.startDate
        
        // ✅ Use fallback pattern to avoid double-counting
        if !sessions.isEmpty {
            _totalDistance = sessions.reduce(0) { $0 + $1.distance }
        } else {
            _totalDistance = entries.reduce(0) { $0 + $1.distance }
        }
        _lifespanProgress = computeLifespanProgress()
        
        print("🔄 Memory refresh for \(brand) \(model): active \(wasActive)→\(_isActive), distance \(String(format: "%.1f", oldDistance))→\(String(format: "%.1f", _totalDistance)) km")
    }
    
    /// Forces a complete refresh of distance from database
    func refreshDistanceFromDatabase(using modelContext: ModelContext) async {
        do {
            let allSessionsDescriptor = FetchDescriptor<ShoeSession>()
            let allSessionsInDB = try modelContext.fetch(allSessionsDescriptor)
            let sessions = allSessionsInDB.filter { session in
                session.shoe?.persistentModelID == self.persistentModelID
            }
            
            // ✅ Use fallback pattern to avoid double-counting
            let newDistance: Double
            if !sessions.isEmpty {
                newDistance = sessions.reduce(0) { $0 + $1.distance }
            } else {
                newDistance = entries.reduce(0) { $0 + $1.distance }
            }
            
            if abs(_totalDistance - newDistance) > 0.01 { // Only update if significant change
                let oldDistance = _totalDistance
                _totalDistance = newDistance
                _lifespanProgress = computeLifespanProgress()
                print("📊 Distance updated for \(brand) \(model): \(String(format: "%.1f", oldDistance)) → \(String(format: "%.1f", _totalDistance)) km")
            }
        } catch {
            print("❌ Error refreshing distance for \(brand) \(model): \(error)")
        }
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

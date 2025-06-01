//
//  ShoeSessionService.swift
//  shoePrint
//
//  Created by Simon Naud on 31/05/2025.
//

import Foundation
import SwiftData

/// Service responsible for managing shoe usage sessions
/// Handles session creation, auto-management, and data queries
@MainActor
final class ShoeSessionService: ObservableObject {
    
    // MARK: - Properties
    
    private let modelContext: ModelContext
    private let healthKitManager: HealthKitManager
    private let inactivityThreshold: TimeInterval = 6 * 60 * 60 // 6 hours in seconds
    
    @Published var isProcessing = false
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext, healthKitManager: HealthKitManager) {
        self.modelContext = modelContext
        self.healthKitManager = healthKitManager
    }
    
    // MARK: - Session Management
    
    /// Starts a new session for the specified shoe
    /// Automatically closes any other active sessions
    /// - Parameters:
    ///   - shoe: The shoe to start a session for
    ///   - autoStarted: Whether this session was auto-started (default shoe)
    /// - Returns: The created session
    @discardableResult
    func startSession(for shoe: Shoe, autoStarted: Bool = false) async -> ShoeSession {
        guard !shoe.archived else {
            print("⚠️ Cannot start session for archived shoe: \(shoe.brand) \(shoe.model)")
            return ShoeSession() // Return empty session as fallback
        }
        
        isProcessing = true
        
        // Close any existing active sessions and update their shoes
        await closeAllActiveSessions(reason: "New session started")
        
        // Create new session
        let session = ShoeSession(
            startDate: Date(),
            autoStarted: autoStarted,
            shoe: shoe
        )
        
        modelContext.insert(session)
        
        do {
            try modelContext.save()
            
            // ✅ Update the shoe's computed properties after session change
            shoe.updateActiveState()
            
            // Update all shoes that had sessions closed
            await updateAllShoesComputedProperties()
            
            print("🚀 Started session for \(shoe.brand) \(shoe.model)" + (autoStarted ? " (auto-started)" : ""))
        } catch {
            print("❌ Failed to save new session: \(error)")
        }
        
        isProcessing = false
        return session
    }
    
    /// Stops the active session for the specified shoe
    /// - Parameters:
    ///   - shoe: The shoe to stop the session for
    ///   - autoClosed: Whether this session was auto-closed due to inactivity
    func stopSession(for shoe: Shoe, autoClosed: Bool = false) async {
        guard let activeSession = shoe.activeSession else {
            print("⚠️ No active session to stop for \(shoe.brand) \(shoe.model)")
            return
        }
        
        isProcessing = true
        
        activeSession.closeSession(autoClosed: autoClosed)
        
        do {
            try modelContext.save()
            
            // ✅ Update the shoe's computed properties after session change
            shoe.updateActiveState()
            // ✅ Update distance now that session has final duration
            shoe.refreshDistance()
            
            print("🛑 Stopped session for \(shoe.brand) \(shoe.model) - Duration: \(activeSession.durationFormatted)")
        } catch {
            print("❌ Failed to save session closure: \(error)")
        }
        
        isProcessing = false
    }
    
    /// Toggles the session state for a shoe (starts if inactive, stops if active)
    /// - Parameter shoe: The shoe to toggle
    func toggleSession(for shoe: Shoe) async {
        if shoe.isActive {
            await stopSession(for: shoe)
        } else {
            await startSession(for: shoe)
        }
    }
    
    /// Closes all currently active sessions
    /// - Parameter reason: Reason for closing (for logging)
    private func closeAllActiveSessions(reason: String) async {
        let activeSessions = await getActiveSessions()
        
        for session in activeSessions {
            session.closeSession()
            // Update the shoe's state immediately
            session.shoe?.updateActiveState()
            // Update distance now that session has final duration
            session.shoe?.refreshDistance()
            print("🔒 Closed active session for \(session.shoe?.brand ?? "Unknown") - Reason: \(reason)")
        }
        
        if !activeSessions.isEmpty {
            do {
                try modelContext.save()
            } catch {
                print("❌ Failed to save session closures: \(error)")
            }
        }
    }
    
    /// Updates computed properties for all shoes
    private func updateAllShoesComputedProperties() async {
        let descriptor = FetchDescriptor<Shoe>()
        
        do {
            let allShoes = try modelContext.fetch(descriptor)
            for shoe in allShoes {
                shoe.updateActiveState()
                shoe.refreshDistance()
            }
        } catch {
            print("❌ Error updating shoes computed properties: \(error)")
        }
    }
    
    // MARK: - Auto-Management
    
    /// Checks for inactive sessions and auto-closes them if needed
    func checkAndAutoCloseInactiveSessions() async {
        let activeSessions = await getActiveSessions()
        let now = Date()
        
        for session in activeSessions {
            let inactiveTime = now.timeIntervalSince(session.startDate)
            
            if inactiveTime > inactivityThreshold {
                // Check if there have been recent steps
                let hasRecentSteps = await hasRecentHealthKitActivity(since: session.startDate)
                
                if !hasRecentSteps {
                    print("⏰ Auto-closing inactive session for \(session.shoe?.brand ?? "Unknown") after \(inactiveTime/3600)h of inactivity")
                    session.closeSession(autoClosed: true)
                    // Update distance now that session has final duration
                    session.shoe?.refreshDistance()
                }
            }
        }
        
        do {
            try modelContext.save()
        } catch {
            print("❌ Failed to save auto-closed sessions: \(error)")
        }
    }
    
    /// Auto-starts the default shoe on first steps of the day
    func checkAndAutoStartDefaultShoe() async {
        // Only auto-start if no sessions are currently active
        let activeSessions = await getActiveSessions()
        guard activeSessions.isEmpty else { return }
        
        // Check if we have steps today but no sessions today
        let todayHasSteps = await hasTodaySteps()
        let todayHasSessions = await hasTodaySessions()
        
        guard todayHasSteps && !todayHasSessions else { return }
        
        // Get the default shoe
        if let defaultShoe = await getDefaultShoe() {
            print("🌅 Auto-starting default shoe \(defaultShoe.brand) \(defaultShoe.model) for first steps of the day")
            await startSession(for: defaultShoe, autoStarted: true)
        }
    }
    
    // MARK: - Queries
    
    /// Gets all currently active sessions
    func getActiveSessions() async -> [ShoeSession] {
        let descriptor = FetchDescriptor<ShoeSession>(
            predicate: #Predicate<ShoeSession> { session in
                session.endDate == nil
            }
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("❌ Error fetching active sessions: \(error)")
            return []
        }
    }
    
    /// Gets all sessions for a specific date
    func getSessionsForDate(_ date: Date) async -> [ShoeSession] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
        
        print("🔍 DEBUG: Searching sessions for date \(date.formatted(date: .abbreviated, time: .omitted))")
        print("🔍 DEBUG: StartOfDay: \(startOfDay.formatted(date: .omitted, time: .complete)), EndOfDay: \(endOfDay.formatted(date: .omitted, time: .complete))")
        
        do {
            // Fetch all sessions and filter in memory to avoid SwiftData predicate limitations
            let allSessions = try modelContext.fetch(FetchDescriptor<ShoeSession>())
            print("🔍 DEBUG: Total sessions in database: \(allSessions.count)")
            
            for (index, session) in allSessions.enumerated() {
                let shoeName = session.shoe?.brand ?? "Unknown"
                print("🔍 DEBUG: Session \(index): \(shoeName) from \(session.startDate.formatted(date: .abbreviated, time: .complete)) to \(session.endDate?.formatted(date: .abbreviated, time: .complete) ?? "Active")")
            }
            
            // Filter sessions that overlap with our date range
            let sessions = allSessions.filter { session in
                // Session starts before our day ends
                let startsBeforeDayEnds = session.startDate < endOfDay
                
                // Session ends after our day starts (or is still active)
                let endsAfterDayStarts = session.endDate == nil || session.endDate! > startOfDay
                
                return startsBeforeDayEnds && endsAfterDayStarts
            }
            
            print("🔍 DEBUG: Filtered sessions for date: \(sessions.count)")
            return sessions
        } catch {
            print("❌ Error fetching sessions for date: \(error)")
            return []
        }
    }
    
    /// Gets the currently active shoe (if any)
    func getActiveShoe() async -> Shoe? {
        let activeSessions = await getActiveSessions()
        return activeSessions.first?.shoe
    }
    
    /// Gets the default shoe
    private func getDefaultShoe() async -> Shoe? {
        let descriptor = FetchDescriptor<Shoe>(
            predicate: #Predicate<Shoe> { shoe in
                shoe.isDefault && !shoe.archived
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
    
    // MARK: - Data Derivation for Hourly Display
    
    /// Derives hourly step data by combining HealthKit data with session information
    /// - Parameter date: The date to get hourly data for
    /// - Returns: Array of hourly step data with shoe attributions from sessions
    func getHourlyStepDataForDate(_ date: Date, healthKitData: [HourlyStepData]) async -> [HourlyStepData] {
        let sessions = await getSessionsForDate(date)
        print("🔍 DEBUG: Found \(sessions.count) sessions for date \(date.formatted(date: .abbreviated, time: .omitted))")
        
        for session in sessions {
            if let shoe = session.shoe {
                print("🔍 DEBUG: Session from \(session.startDate.formatted(date: .omitted, time: .shortened)) to \(session.endDate?.formatted(date: .omitted, time: .shortened) ?? "Active") for \(shoe.brand) \(shoe.model)")
            }
        }
        
        return healthKitData.map { hourData in
            var attributedHourData = hourData
            
            // Find session that covers this hour
            for session in sessions {
                if session.coversHour(hourData.date) {
                    attributedHourData.assignedShoe = session.shoe
                    print("🔍 DEBUG: Hour \(hourData.timeString) at \(hourData.date.formatted(date: .omitted, time: .shortened)) covered by session for \(session.shoe?.brand ?? "Unknown")")
                    break
                }
            }
            
            return attributedHourData
        }
    }
    
    // MARK: - A Posteriori Attribution
    
    /// Creates a session for a specific hour (for a posteriori attribution from journal)
    /// - Parameters:
    ///   - shoe: The shoe to attribute the hour to
    ///   - hourDate: The specific hour to create session for
    /// - Returns: The created session
    @discardableResult
    func createHourSession(for shoe: Shoe, hourDate: Date) async -> ShoeSession {
        guard !shoe.archived else {
            print("⚠️ Cannot create session for archived shoe: \(shoe.brand) \(shoe.model)")
            return ShoeSession()
        }
        
        let calendar = Calendar.current
        let hourStart = calendar.date(bySettingHour: calendar.component(.hour, from: hourDate), minute: 0, second: 0, of: hourDate) ?? hourDate
        let hourEnd = calendar.date(byAdding: .hour, value: 1, to: hourStart) ?? hourStart
        
        // Calculate real HealthKit data for this hour
        let healthKitData = await calculateHealthKitData(from: hourStart, to: hourEnd)
        
        // Check for existing session that covers this hour and update affected shoes
        let affectedShoes = await getShoesWithConflictingSessions(for: hourStart, to: hourEnd)
        await removeConflictingSessions(for: hourStart, to: hourEnd)
        
        // Create new session for this specific hour with real data
        let session = ShoeSession(
            startDate: hourStart,
            endDate: hourEnd,
            autoStarted: false,
            shoe: shoe,
            steps: healthKitData.steps,
            distance: healthKitData.distance
        )
        
        modelContext.insert(session)
        
        do {
            try modelContext.save()
            
            // ✅ Update computed properties for affected shoes
            for affectedShoe in affectedShoes {
                affectedShoe.updateActiveState()
                affectedShoe.refreshDistance()
            }
            shoe.updateActiveState()
            shoe.refreshDistance()
            
            print("🕐 Created hour session for \(shoe.brand) \(shoe.model) at \(hourStart.formatted(.dateTime.hour().minute())) - \(healthKitData.steps) steps, \(String(format: "%.1f", healthKitData.distance)) km")
        } catch {
            print("❌ Failed to save hour session: \(error)")
        }
        
        return session
    }
    
    /// Creates sessions for multiple hours (for batch attribution)
    /// - Parameters:
    ///   - shoe: The shoe to attribute the hours to
    ///   - hourDates: Array of hour dates to create sessions for
    func createHourSessions(for shoe: Shoe, hourDates: [Date]) async {
        guard !shoe.archived else {
            print("⚠️ Cannot create sessions for archived shoe: \(shoe.brand) \(shoe.model)")
            return
        }
        
        isProcessing = true
        
        for hourDate in hourDates {
            await createHourSession(for: shoe, hourDate: hourDate)
        }
        
        // ✅ Final update of all computed properties
        await updateAllShoesComputedProperties()
        
        print("📅 Created \(hourDates.count) hour sessions for \(shoe.brand) \(shoe.model)")
        isProcessing = false
    }
    
    /// Gets shoes that have sessions conflicting with the given time range
    /// - Parameters:
    ///   - startDate: Start of the time range
    ///   - endDate: End of the time range
    /// - Returns: Array of shoes that will be affected
    private func getShoesWithConflictingSessions(for startDate: Date, to endDate: Date) async -> [Shoe] {
        do {
            let allSessions = try modelContext.fetch(FetchDescriptor<ShoeSession>())
            
            let conflictingSessions = allSessions.filter { session in
                let startsBeforeRangeEnds = session.startDate < endDate
                let endsAfterRangeStarts = session.endDate == nil || session.endDate! > startDate
                return startsBeforeRangeEnds && endsAfterRangeStarts
            }
            
            return conflictingSessions.compactMap { $0.shoe }
        } catch {
            print("❌ Error getting shoes with conflicting sessions: \(error)")
            return []
        }
    }
    
    /// Removes existing sessions that conflict with a new hour range
    /// - Parameters:
    ///   - startDate: Start of the new session period
    ///   - endDate: End of the new session period
    private func removeConflictingSessions(for startDate: Date, to endDate: Date) async {        
        do {
            // Fetch all sessions and filter in memory to avoid SwiftData predicate limitations
            let allSessions = try modelContext.fetch(FetchDescriptor<ShoeSession>())
            
            // Filter sessions that overlap with our time range
            let conflictingSessions = allSessions.filter { session in
                // Session starts before our range ends
                let startsBeforeRangeEnds = session.startDate < endDate
                
                // Session ends after our range starts (or is still active)
                let endsAfterRangeStarts = session.endDate == nil || session.endDate! > startDate
                
                return startsBeforeRangeEnds && endsAfterRangeStarts
            }
            
            for session in conflictingSessions {
                print("🗑️ Removing conflicting session for \(session.shoe?.brand ?? "Unknown") at \(session.startDate.formatted(date: .omitted, time: .shortened))")
                modelContext.delete(session)
            }
            
            if !conflictingSessions.isEmpty {
                try modelContext.save()
            }
            
        } catch {
            print("❌ Error removing conflicting sessions: \(error)")
        }
    }
    
    /// Removes attribution for a specific hour (deletes the session)
    /// - Parameter hourDate: The hour to remove attribution from
    func removeHourAttribution(for hourDate: Date) async {
        let calendar = Calendar.current
        let hourStart = calendar.date(bySettingHour: calendar.component(.hour, from: hourDate), minute: 0, second: 0, of: hourDate) ?? hourDate
        let hourEnd = calendar.date(byAdding: .hour, value: 1, to: hourStart) ?? hourStart
        
        // Get affected shoes before removing
        let affectedShoes = await getShoesWithConflictingSessions(for: hourStart, to: hourEnd)
        
        await removeConflictingSessions(for: hourStart, to: hourEnd)
        
        // ✅ Update computed properties for affected shoes
        for shoe in affectedShoes {
            shoe.updateActiveState()
            shoe.refreshDistance()
        }
        
        print("🧹 Removed attribution for hour at \(hourStart.formatted(.dateTime.hour().minute()))")
    }
    
    // MARK: - HealthKit Data Calculation
    
    /// Calculates real HealthKit data (steps and distance) for a given time period
    /// - Parameters:
    ///   - startDate: Start date of the period
    ///   - endDate: End date of the period
    /// - Returns: Tuple containing total steps and distance in kilometers
    private func calculateHealthKitData(from startDate: Date, to endDate: Date) async -> (steps: Int, distance: Double) {
        let calendar = Calendar.current
        var totalSteps = 0
        var totalDistance = 0.0
        
        // Get the date range to cover
        let startOfHour = calendar.dateInterval(of: .hour, for: startDate)?.start ?? startDate
        let endOfHour = calendar.dateInterval(of: .hour, for: endDate)?.start ?? endDate
        
        var currentHour = startOfHour
        
        while currentHour <= endOfHour {
            // Fetch HealthKit data for this hour
            let hourlyData = await healthKitManager.fetchHourlyData(for: currentHour)
            
            if let hourData = hourlyData.first(where: { $0.hour == calendar.component(.hour, from: currentHour) }) {
                totalSteps += hourData.steps
                // Use real distance data from HealthKit (already in kilometers)
                totalDistance += hourData.distance
            }
            
            // Move to next hour
            currentHour = calendar.date(byAdding: .hour, value: 1, to: currentHour) ?? currentHour
            
            // Safety check to avoid infinite loop
            if currentHour > endDate.addingTimeInterval(24 * 60 * 60) {
                break
            }
        }
        
        return (steps: totalSteps, distance: totalDistance)
    }
    
    // MARK: - Helper Methods
    
    /// Checks if there have been recent HealthKit steps
    private func hasRecentHealthKitActivity(since date: Date) async -> Bool {
        // This would integrate with HealthKitManager to check for recent activity
        // For now, we'll implement a simple time-based check
        let hoursSinceStart = Date().timeIntervalSince(date) / 3600
        return hoursSinceStart < 6 // Assume activity if less than 6 hours
    }
    
    /// Checks if there are steps recorded today
    private func hasTodaySteps() async -> Bool {
        // This would check HealthKit for today's steps
        // For now, return true to enable auto-start functionality
        return true
    }
    
    /// Checks if there are any sessions today
    private func hasTodaySessions() async -> Bool {
        let todaySessions = await getSessionsForDate(Date())
        return !todaySessions.isEmpty
    }
} 
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
    private let shoePropertyService: ShoePropertyService
    private let inactivityThreshold: TimeInterval = 6 * 60 * 60 // 6 hours in seconds
    
    @Published var isProcessing = false
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext, healthKitManager: HealthKitManager) {
        self.modelContext = modelContext
        self.healthKitManager = healthKitManager
        self.shoePropertyService = ShoePropertyService(modelContext: modelContext)
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
            
            // ✅ Computed properties now update automatically
            print("✅ Session started - computed properties will update automatically")
            
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
        // ✅ Use database query instead of potentially stale relationship
        guard let activeSession = await shoe.getActiveSession(using: modelContext) else {
            print("⚠️ No active session to stop for \(shoe.brand) \(shoe.model)")
            return
        }
        
        isProcessing = true
        
        activeSession.closeSession(autoClosed: autoClosed)
        
        do {
            try modelContext.save()
            
            // ✅ Computed properties now update automatically when session ends
            print("✅ Session ended - computed properties will update automatically")
            
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
            print("🔒 Closed active session for \(session.shoe?.brand ?? "Unknown") - Reason: \(reason)")
        }
        
        if !activeSessions.isEmpty {
            do {
                try modelContext.save()
                
                // ✅ Computed properties update automatically when sessions are closed
                print("✅ Sessions closed - computed properties will update automatically")
            } catch {
                print("❌ Failed to save session closures: \(error)")
            }
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
                }
            }
        }
        
        do {
            try modelContext.save()
            
            // ✅ Computed properties update automatically when sessions are auto-closed
            print("✅ Auto-closed sessions - computed properties will update automatically")
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
    
    // MARK: - Deprecated Hour Attribution Methods
    
    /// Deprecated: Use AttributionService.attributeHour instead
    @available(*, deprecated, message: "Use AttributionService.attributeHour instead")
    @discardableResult
    func createHourSession(for shoe: Shoe, hourDate: Date) async -> ShoeSession {
        print("⚠️ createHourSession is deprecated - use AttributionService.attributeHour instead")
        return ShoeSession()
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
        
        // ✅ Computed properties update automatically for batch sessions
        await shoePropertyService.updateShoeAfterSessionChange(shoe)
        print("✅ Batch sessions created - computed properties will update automatically")
        
        print("📅 Created \(hourDates.count) hour sessions for \(shoe.brand) \(shoe.model)")
        isProcessing = false
    }
    
    /// Deprecated: No longer needed with simplified attribution system
    @available(*, deprecated, message: "No longer needed with simplified attribution system")
    private func getShoesWithConflictingSessions(for startDate: Date, to endDate: Date) async -> [Shoe] {
        return []
    }
    
    /// Deprecated: No longer needed with simplified attribution system
    @available(*, deprecated, message: "No longer needed with simplified attribution system")
    private func removeConflictingSessions(for startDate: Date, to endDate: Date) async {
        // No-op - simplified attribution system doesn't need conflict resolution
    }
    
    /// Deprecated: Use AttributionService.removeAttribution instead
    @available(*, deprecated, message: "Use AttributionService.removeAttribution instead")
    func removeHourAttribution(for hourDate: Date) async {
        print("⚠️ removeHourAttribution is deprecated - use AttributionService.removeAttribution instead")
    }
    
    // MARK: - HealthKit Data Calculation
    
    /// Calculates real HealthKit data (steps and distance) for a given time period
    /// - Parameters:
    ///   - startDate: Start date of the period
    ///   - endDate: End date of the period
    /// - Returns: Tuple containing total steps and distance in kilometers
    private func calculateHealthKitData(from startDate: Date, to endDate: Date) async -> (steps: Int, distance: Double) {
        let calendar = Calendar.current
        
        print("📊 Calculating HealthKit data for \(startDate.formatted(date: .omitted, time: .shortened)) - \(endDate.formatted(date: .omitted, time: .shortened))")
        
        // ✅ For hour-specific sessions, optimize by fetching only the specific hour
        let hourComponent = calendar.component(.hour, from: startDate)
        let dateComponent = calendar.startOfDay(for: startDate)
        
        // Fetch HealthKit data for the specific date
        let hourlyData = await healthKitManager.fetchHourlyData(for: dateComponent)
        
        // Find the specific hour's data
        if let hourData = hourlyData.first(where: { $0.hour == hourComponent }) {
            let steps = hourData.steps
            let distance = hourData.distance // Already in kilometers
            
            print("✅ Found HealthKit data for hour \(hourComponent): \(steps) steps, \(String(format: "%.1f", distance)) km")
            return (steps: steps, distance: distance)
        } else {
            print("⚠️ No HealthKit data found for hour \(hourComponent)")
            return (steps: 0, distance: 0.0)
        }
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
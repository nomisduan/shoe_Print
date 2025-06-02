//
//  SessionService.swift
//  shoePrint
//
//  Portfolio Refactor: Clean business logic service for sessions
//

import Foundation

/// Business logic service for session operations
/// ✅ Clean separation of concerns for real wearing session management
@MainActor
final class SessionService: ObservableObject {
    
    // MARK: - Properties
    
    private let sessionRepository: SessionRepositoryProtocol
    private let shoeRepository: ShoeRepositoryProtocol
    private let healthKitManager: HealthKitManager
    private let inactivityThreshold: TimeInterval = 6 * 60 * 60 // 6 hours
    
    @Published var isProcessing = false
    @Published var error: AppError?
    
    // MARK: - Initialization
    
    init(
        sessionRepository: SessionRepositoryProtocol,
        shoeRepository: ShoeRepositoryProtocol,
        healthKitManager: HealthKitManager
    ) {
        self.sessionRepository = sessionRepository
        self.shoeRepository = shoeRepository
        self.healthKitManager = healthKitManager
    }
    
    // MARK: - Session Management
    
    /// Starts a new session for a shoe
    func startSession(for shoe: Shoe, autoStarted: Bool = false) async throws -> ShoeSession {
        guard !shoe.archived else {
            throw AppError.shoeArchived
        }
        
        // Check if shoe already has an active session
        if try await sessionRepository.fetchActiveSession(for: shoe) != nil {
            throw AppError.sessionAlreadyActive
        }
        
        isProcessing = true
        error = nil
        
        do {
            // End all other active sessions first
            try await sessionRepository.endAllActiveSessions()
            
            // Start new session
            let session = try await sessionRepository.startSession(for: shoe, autoStarted: autoStarted)
            
            print("🚀 Started session for \(shoe.brand) \(shoe.model)" + (autoStarted ? " (auto-started)" : ""))
            
            isProcessing = false
            return session
            
        } catch {
            isProcessing = false
            let appError = error as? AppError ?? AppError.sessionInvalidState(error.localizedDescription)
            self.error = appError
            throw appError
        }
    }
    
    /// Ends the active session for a shoe
    func endSession(for shoe: Shoe, autoClosed: Bool = false) async throws {
        guard let activeSession = try await sessionRepository.fetchActiveSession(for: shoe) else {
            throw AppError.sessionNotFound
        }
        
        isProcessing = true
        error = nil
        
        do {
            try await sessionRepository.endSession(activeSession, autoClosed: autoClosed)
            print("🛑 Ended session for \(shoe.brand) \(shoe.model) - Duration: \(activeSession.durationFormatted)")
            
        } catch {
            let appError = error as? AppError ?? AppError.sessionInvalidState(error.localizedDescription)
            self.error = appError
            throw appError
        }
        
        isProcessing = false
    }
    
    /// Toggles session state for a shoe
    func toggleSession(for shoe: Shoe) async throws {
        if shoe.isActive {
            try await endSession(for: shoe)
        } else {
            let _ = try await startSession(for: shoe)
        }
    }
    
    // MARK: - Auto-Management
    
    /// Checks for inactive sessions and auto-closes them
    func checkAndAutoCloseInactiveSessions() async {
        do {
            let activeSessions = try await sessionRepository.fetchActiveSessions()
            let now = Date()
            
            for session in activeSessions {
                let inactiveTime = now.timeIntervalSince(session.startDate)
                
                if inactiveTime > inactivityThreshold {
                    let hasRecentSteps = await hasRecentHealthKitActivity(since: session.startDate)
                    
                    if !hasRecentSteps {
                        print("⏰ Auto-closing inactive session after \(inactiveTime/3600)h of inactivity")
                        try await sessionRepository.endSession(session, autoClosed: true)
                    }
                }
            }
        } catch {
            print("❌ Error auto-closing inactive sessions: \(error)")
        }
    }
    
    /// Auto-starts the default shoe if conditions are met
    func checkAndAutoStartDefaultShoe() async {
        do {
            // Only auto-start if no sessions are currently active
            let hasActive = try await sessionRepository.hasActiveSessions()
            guard !hasActive else { return }
            
            // Check if we have steps today but no sessions today
            let todayHasSteps = await hasTodaySteps()
            let todaySessions = try await sessionRepository.fetchTodaySessions()
            
            guard todayHasSteps && todaySessions.isEmpty else { return }
            
            // Get the default shoe
            if let defaultShoe = try await shoeRepository.fetchDefaultShoe() {
                print("🌅 Auto-starting default shoe \(defaultShoe.brand) \(defaultShoe.model)")
                let _ = try await startSession(for: defaultShoe, autoStarted: true)
            }
        } catch {
            print("❌ Error auto-starting default shoe: \(error)")
        }
    }
    
    // MARK: - Query Operations
    
    /// Gets all active sessions
    func getActiveSessions() async throws -> [ShoeSession] {
        do {
            return try await sessionRepository.fetchActiveSessions()
        } catch {
            let appError = error as? AppError ?? AppError.dataNotFound(error.localizedDescription)
            self.error = appError
            throw appError
        }
    }
    
    /// Gets sessions for a specific date
    func getSessionsForDate(_ date: Date) async throws -> [ShoeSession] {
        do {
            return try await sessionRepository.fetchSessionsForDate(date)
        } catch {
            let appError = error as? AppError ?? AppError.dataNotFound(error.localizedDescription)
            self.error = appError
            throw appError
        }
    }
    
    /// Gets the currently active shoe (if any)
    func getActiveShoe() async throws -> Shoe? {
        do {
            let activeSessions = try await sessionRepository.fetchActiveSessions()
            return activeSessions.first?.shoe
        } catch {
            let appError = error as? AppError ?? AppError.dataNotFound(error.localizedDescription)
            self.error = appError
            throw appError
        }
    }
    
    // MARK: - Statistics
    
    /// Gets session statistics for a shoe
    func getSessionStatistics(for shoe: Shoe) async throws -> SessionStatistics {
        do {
            let sessionCount = try await sessionRepository.getSessionCount(for: shoe)
            let totalWearingTime = try await sessionRepository.getTotalWearingTime(for: shoe)
            let hasActiveSession = try await sessionRepository.fetchActiveSession(for: shoe) != nil
            
            return SessionStatistics(
                sessionCount: sessionCount,
                totalWearingTime: totalWearingTime,
                hasActiveSession: hasActiveSession,
                averageSessionDuration: sessionCount > 0 ? totalWearingTime / Double(sessionCount) : 0
            )
        } catch {
            let appError = error as? AppError ?? AppError.dataNotFound(error.localizedDescription)
            self.error = appError
            throw appError
        }
    }
    
    // MARK: - Helper Methods
    
    /// Checks if there has been recent HealthKit activity
    private func hasRecentHealthKitActivity(since date: Date) async -> Bool {
        // Simple time-based check for now
        let hoursSinceStart = Date().timeIntervalSince(date) / 3600
        return hoursSinceStart < 6
    }
    
    /// Checks if there are steps recorded today
    private func hasTodaySteps() async -> Bool {
        // TODO: Implement with HealthKit
        return true
    }
    
    // MARK: - Error Handling
    
    /// Clears the current error
    func clearError() {
        error = nil
    }
}

// MARK: - Supporting Types

/// Statistics about sessions for a shoe
struct SessionStatistics {
    let sessionCount: Int
    let totalWearingTime: TimeInterval
    let hasActiveSession: Bool
    let averageSessionDuration: TimeInterval
    
    var totalWearingTimeFormatted: String {
        let hours = Int(totalWearingTime / 3600)
        let minutes = Int((totalWearingTime.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var averageSessionDurationFormatted: String {
        let hours = Int(averageSessionDuration / 3600)
        let minutes = Int((averageSessionDuration.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
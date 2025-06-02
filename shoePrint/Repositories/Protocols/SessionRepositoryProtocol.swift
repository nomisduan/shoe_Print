//
//  SessionRepositoryProtocol.swift
//  shoePrint
//
//  Portfolio Refactor: Repository pattern implementation
//

import Foundation

/// Protocol defining session data access operations
/// ✅ Abstracts SwiftData implementation for real wearing sessions
protocol SessionRepositoryProtocol {
    
    // MARK: - CRUD Operations
    
    /// Fetches all sessions
    func fetchAllSessions() async throws -> [ShoeSession]
    
    /// Fetches sessions for a specific shoe
    func fetchSessions(for shoe: Shoe) async throws -> [ShoeSession]
    
    /// Fetches sessions for a specific date range
    func fetchSessions(from startDate: Date, to endDate: Date) async throws -> [ShoeSession]
    
    /// Fetches a specific session by ID
    func fetchSession(byId id: String) async throws -> ShoeSession?
    
    /// Saves a session (insert or update)
    func saveSession(_ session: ShoeSession) async throws
    
    /// Deletes a session
    func deleteSession(_ session: ShoeSession) async throws
    
    // MARK: - Active Session Management
    
    /// Fetches all currently active sessions
    func fetchActiveSessions() async throws -> [ShoeSession]
    
    /// Fetches active session for a specific shoe (if any)
    func fetchActiveSession(for shoe: Shoe) async throws -> ShoeSession?
    
    /// Starts a new session for a shoe
    func startSession(for shoe: Shoe, autoStarted: Bool) async throws -> ShoeSession
    
    /// Ends a session
    func endSession(_ session: ShoeSession, autoClosed: Bool) async throws
    
    /// Ends all active sessions
    func endAllActiveSessions() async throws
    
    // MARK: - Specialized Queries
    
    /// Gets sessions for a specific date
    func fetchSessionsForDate(_ date: Date) async throws -> [ShoeSession]
    
    /// Gets sessions for today
    func fetchTodaySessions() async throws -> [ShoeSession]
    
    /// Checks if there are any active sessions
    func hasActiveSessions() async throws -> Bool
    
    /// Gets total session count for a shoe
    func getSessionCount(for shoe: Shoe) async throws -> Int
    
    /// Gets total wearing time for a shoe
    func getTotalWearingTime(for shoe: Shoe) async throws -> TimeInterval
}
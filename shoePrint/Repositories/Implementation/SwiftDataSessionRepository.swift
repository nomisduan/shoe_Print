//
//  SwiftDataSessionRepository.swift
//  shoePrint
//
//  Portfolio Refactor: SwiftData implementation of SessionRepository
//

import Foundation
import SwiftData

/// SwiftData implementation of SessionRepositoryProtocol
/// ✅ Concrete implementation for real wearing session management
@MainActor
final class SwiftDataSessionRepository: SessionRepositoryProtocol {
    
    // MARK: - Properties
    
    private let modelContext: ModelContext
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - CRUD Operations
    
    func fetchAllSessions() async throws -> [ShoeSession] {
        let descriptor = FetchDescriptor<ShoeSession>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    func fetchSessions(for shoe: Shoe) async throws -> [ShoeSession] {
        let allSessions = try await fetchAllSessions()
        return allSessions.filter { session in
            session.shoe?.persistentModelID == shoe.persistentModelID
        }
    }
    
    func fetchSessions(from startDate: Date, to endDate: Date) async throws -> [ShoeSession] {
        let allSessions = try await fetchAllSessions()
        return allSessions.filter { session in
            // Session overlaps with date range
            let sessionStart = session.startDate
            let sessionEnd = session.endDate ?? Date()
            
            return sessionStart < endDate && sessionEnd > startDate
        }
    }
    
    func fetchSession(byId id: String) async throws -> ShoeSession? {
        // For now, we'll fetch all sessions and filter by ID string representation
        let allSessions = try await fetchAllSessions()
        return allSessions.first { session in
            String(describing: session.persistentModelID) == id
        }
    }
    
    func saveSession(_ session: ShoeSession) async throws {
        modelContext.insert(session)
        try modelContext.save()
    }
    
    func deleteSession(_ session: ShoeSession) async throws {
        modelContext.delete(session)
        try modelContext.save()
    }
    
    // MARK: - Active Session Management
    
    func fetchActiveSessions() async throws -> [ShoeSession] {
        let descriptor = FetchDescriptor<ShoeSession>(
            predicate: #Predicate<ShoeSession> { session in
                session.endDate == nil
            },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    func fetchActiveSession(for shoe: Shoe) async throws -> ShoeSession? {
        let activeSessions = try await fetchActiveSessions()
        return activeSessions.first { session in
            session.shoe?.persistentModelID == shoe.persistentModelID
        }
    }
    
    func startSession(for shoe: Shoe, autoStarted: Bool = false) async throws -> ShoeSession {
        // End any existing active sessions first
        try await endAllActiveSessions()
        
        let session = ShoeSession(
            startDate: Date(),
            endDate: nil,
            autoStarted: autoStarted,
            shoe: shoe
        )
        
        try await saveSession(session)
        return session
    }
    
    func endSession(_ session: ShoeSession, autoClosed: Bool = false) async throws {
        session.endDate = Date()
        session.autoClosed = autoClosed
        try modelContext.save()
    }
    
    /// Updates an existing session (saves changes to the context)
    func updateSession(_ session: ShoeSession) async throws {
        // Session is already updated in memory, just save the context
        try modelContext.save()
    }
    
    func endAllActiveSessions() async throws {
        let activeSessions = try await fetchActiveSessions()
        
        for session in activeSessions {
            try await endSession(session, autoClosed: false)
        }
    }
    
    // MARK: - Specialized Queries
    
    func fetchSessionsForDate(_ date: Date) async throws -> [ShoeSession] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
        
        return try await fetchSessions(from: startOfDay, to: endOfDay)
    }
    
    func fetchTodaySessions() async throws -> [ShoeSession] {
        return try await fetchSessionsForDate(Date())
    }
    
    func hasActiveSessions() async throws -> Bool {
        let activeSessions = try await fetchActiveSessions()
        return !activeSessions.isEmpty
    }
    
    func getSessionCount(for shoe: Shoe) async throws -> Int {
        let sessions = try await fetchSessions(for: shoe)
        return sessions.count
    }
    
    func getTotalWearingTime(for shoe: Shoe) async throws -> TimeInterval {
        let sessions = try await fetchSessions(for: shoe)
        return sessions.reduce(0) { total, session in
            total + session.duration
        }
    }
}
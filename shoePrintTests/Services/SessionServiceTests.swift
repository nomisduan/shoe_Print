//
//  SessionServiceTests.swift
//  shoePrintTests
//
//  Portfolio Refactor: Unit tests for SessionService business logic
//

import Testing
import Foundation
@testable import shoePrint

/// Unit tests for session service business logic
/// ✅ Tests session management, auto-management, and business rules
struct SessionServiceTests {
    
    // MARK: - Test Setup
    
    private func createTestService() -> (SessionService, MockSessionRepository, MockShoeRepository, MockHealthKitManager) {
        let sessionRepository = MockSessionRepository()
        sessionRepository.reset()
        
        let shoeRepository = MockShoeRepository()
        shoeRepository.reset()
        
        let healthKitManager = MockHealthKitManager()
        
        let service = SessionService(
            sessionRepository: sessionRepository,
            shoeRepository: shoeRepository,
            healthKitManager: healthKitManager
        )
        
        return (service, sessionRepository, shoeRepository, healthKitManager)
    }
    
    // MARK: - Start Session Tests
    
    @Test("Start session creates new session successfully")
    func testStartSessionSuccess() async throws {
        // Given
        let (service, sessionRepository, _, _) = createTestService()
        let shoe = TestFixtures.createTestShoe()
        
        // When
        let result = try await service.startSession(for: shoe)
        
        // Then
        #expect(result.shoe?.id == shoe.id)
        #expect(result.endDate == nil)
        #expect(result.autoStarted == false)
        #expect(service.error == nil)
        #expect(!service.isProcessing)
    }
    
    @Test("Start auto session marks as auto started")
    func testStartAutoSession() async throws {
        // Given
        let (service, _, _, _) = createTestService()
        let shoe = TestFixtures.createTestShoe()
        
        // When
        let result = try await service.startSession(for: shoe, autoStarted: true)
        
        // Then
        #expect(result.autoStarted == true)
    }
    
    @Test("Start session for archived shoe fails")
    func testStartSessionForArchivedShoe() async throws {
        // Given
        let (service, _, _, _) = createTestService()
        let archivedShoe = TestFixtures.createTestShoe(archived: true)
        
        // When/Then
        await #expect(throws: AppError.self) {
            try await service.startSession(for: archivedShoe)
        }
        
        // Verify specific error type
        #expect(service.error == .shoeArchived)
    }
    
    @Test("Start session when shoe already has active session fails")
    func testStartSessionWhenAlreadyActive() async throws {
        // Given
        let (service, sessionRepository, _, _) = createTestService()
        let shoe = TestFixtures.createTestShoe()
        
        // Add existing active session
        let existingSession = TestFixtures.createActiveSession(shoe: shoe)
        sessionRepository.addTestSession(existingSession)
        
        // When/Then
        await #expect(throws: AppError.self) {
            try await service.startSession(for: shoe)
        }
        
        #expect(service.error == .sessionAlreadyActive)
    }
    
    @Test("Start session ends other active sessions first")
    func testStartSessionEndsOtherActiveSessions() async throws {
        // Given
        let (service, sessionRepository, _, _) = createTestService()
        let shoes = TestFixtures.createTestShoeCollection()
        
        // Add active session for different shoe
        let otherActiveSession = TestFixtures.createActiveSession(shoe: shoes[0])
        sessionRepository.addTestSession(otherActiveSession)
        
        // When
        let _ = try await service.startSession(for: shoes[1])
        
        // Then
        let activeSessions = try await sessionRepository.fetchActiveSessions()
        #expect(activeSessions.count == 1) // Only the new session should be active
        #expect(activeSessions.first?.shoe?.id == shoes[1].id)
    }
    
    // MARK: - End Session Tests
    
    @Test("End session successfully closes active session")
    func testEndSessionSuccess() async throws {
        // Given
        let (service, sessionRepository, _, _) = createTestService()
        let shoe = TestFixtures.createTestShoe()
        let activeSession = TestFixtures.createActiveSession(shoe: shoe)
        sessionRepository.addTestSession(activeSession)
        
        // When
        try await service.endSession(for: shoe)
        
        // Then
        #expect(activeSession.endDate != nil)
        #expect(service.error == nil)
        #expect(!service.isProcessing)
    }
    
    @Test("End session with auto close marks as auto closed")
    func testEndSessionAutoClose() async throws {
        // Given
        let (service, sessionRepository, _, _) = createTestService()
        let shoe = TestFixtures.createTestShoe()
        let activeSession = TestFixtures.createActiveSession(shoe: shoe)
        sessionRepository.addTestSession(activeSession)
        
        // When
        try await service.endSession(for: shoe, autoClosed: true)
        
        // Then
        #expect(activeSession.autoClosed == true)
    }
    
    @Test("End session for shoe without active session fails")
    func testEndSessionNoActiveSession() async throws {
        // Given
        let (service, _, _, _) = createTestService()
        let shoe = TestFixtures.createTestShoe()
        
        // When/Then
        await #expect(throws: AppError.self) {
            try await service.endSession(for: shoe)
        }
        
        #expect(service.error == .sessionNotFound)
    }
    
    // MARK: - Toggle Session Tests
    
    @Test("Toggle session starts session for inactive shoe")
    func testToggleSessionStartsForInactiveShoe() async throws {
        // Given
        let (service, _, _, _) = createTestService()
        let shoe = TestFixtures.createTestShoe()
        
        // When
        try await service.toggleSession(for: shoe)
        
        // Then
        let activeSessions = try await service.getActiveSessions()
        #expect(activeSessions.count == 1)
        #expect(activeSessions.first?.shoe?.id == shoe.id)
    }
    
    @Test("Toggle session ends session for active shoe")
    func testToggleSessionEndsForActiveShoe() async throws {
        // Given
        let (service, sessionRepository, _, _) = createTestService()
        let shoe = TestFixtures.createTestShoe()
        let activeSession = TestFixtures.createActiveSession(shoe: shoe)
        sessionRepository.addTestSession(activeSession)
        
        // When
        try await service.toggleSession(for: shoe)
        
        // Then
        #expect(activeSession.endDate != nil)
        let activeSessions = try await service.getActiveSessions()
        #expect(activeSessions.isEmpty)
    }
    
    // MARK: - Query Operations Tests
    
    @Test("Get active sessions returns all active sessions")
    func testGetActiveSessions() async throws {
        // Given
        let (service, sessionRepository, _, _) = createTestService()
        let shoes = TestFixtures.createTestShoeCollection()
        
        // Add multiple active sessions
        let session1 = TestFixtures.createActiveSession(shoe: shoes[0])
        let session2 = TestFixtures.createActiveSession(shoe: shoes[1])
        sessionRepository.addTestSession(session1)
        sessionRepository.addTestSession(session2)
        
        // Add completed session (should not be included)
        let completedSession = TestFixtures.createTestSession(shoe: shoes[2])
        sessionRepository.addTestSession(completedSession)
        
        // When
        let result = try await service.getActiveSessions()
        
        // Then
        #expect(result.count == 2)
        #expect(result.allSatisfy { $0.endDate == nil })
    }
    
    @Test("Get sessions for date returns correct sessions")
    func testGetSessionsForDate() async throws {
        // Given
        let (service, sessionRepository, _, _) = createTestService()
        let shoe = TestFixtures.createTestShoe()
        let targetDate = Date()
        let calendar = Calendar.current
        
        // Session on target date
        let todaySession = TestFixtures.createTestSession(
            shoe: shoe,
            startDate: targetDate
        )
        sessionRepository.addTestSession(todaySession)
        
        // Session on different date
        let yesterday = calendar.date(byAdding: .day, value: -1, to: targetDate)!
        let yesterdaySession = TestFixtures.createTestSession(
            shoe: shoe,
            startDate: yesterday
        )
        sessionRepository.addTestSession(yesterdaySession)
        
        // When
        let result = try await service.getSessionsForDate(targetDate)
        
        // Then
        #expect(result.count == 1)
        #expect(calendar.isDate(result.first!.startDate, inSameDayAs: targetDate))
    }
    
    @Test("Get active shoe returns currently active shoe")
    func testGetActiveShoe() async throws {
        // Given
        let (service, sessionRepository, _, _) = createTestService()
        let shoe = TestFixtures.createTestShoe()
        let activeSession = TestFixtures.createActiveSession(shoe: shoe)
        sessionRepository.addTestSession(activeSession)
        
        // When
        let result = try await service.getActiveShoe()
        
        // Then
        #expect(result != nil)
        #expect(result?.id == shoe.id)
    }
    
    @Test("Get active shoe returns nil when no active sessions")
    func testGetActiveShoeNone() async throws {
        // Given
        let (service, _, _, _) = createTestService()
        
        // When
        let result = try await service.getActiveShoe()
        
        // Then
        #expect(result == nil)
    }
    
    // MARK: - Statistics Tests
    
    @Test("Get session statistics calculates correctly")
    func testGetSessionStatistics() async throws {
        // Given
        let (service, sessionRepository, _, _) = createTestService()
        let shoe = TestFixtures.createTestShoe()
        let now = Date()
        
        // Add completed sessions with known durations
        let session1 = TestFixtures.createTestSession(
            shoe: shoe,
            startDate: now.addingTimeInterval(-7200), // 2 hours ago
            endDate: now.addingTimeInterval(-3600)     // 1 hour ago (1 hour duration)
        )
        
        let session2 = TestFixtures.createTestSession(
            shoe: shoe,
            startDate: now.addingTimeInterval(-3600),  // 1 hour ago
            endDate: now                               // Now (1 hour duration)
        )
        
        sessionRepository.addTestSession(session1)
        sessionRepository.addTestSession(session2)
        
        // Add active session
        let activeSession = TestFixtures.createActiveSession(shoe: shoe)
        sessionRepository.addTestSession(activeSession)
        
        // When
        let result = try await service.getSessionStatistics(for: shoe)
        
        // Then
        #expect(result.sessionCount == 3)
        #expect(result.totalWearingTime == 7200.0) // 2 hours total (active session excluded)
        #expect(result.hasActiveSession == true)
        #expect(result.averageSessionDuration == 3600.0) // 1 hour average
    }
    
    @Test("Get session statistics for shoe with no sessions")
    func testGetSessionStatisticsNoSessions() async throws {
        // Given
        let (service, _, _, _) = createTestService()
        let shoe = TestFixtures.createTestShoe()
        
        // When
        let result = try await service.getSessionStatistics(for: shoe)
        
        // Then
        #expect(result.sessionCount == 0)
        #expect(result.totalWearingTime == 0)
        #expect(result.hasActiveSession == false)
        #expect(result.averageSessionDuration == 0)
    }
    
    // MARK: - Auto Management Tests
    
    @Test("Auto start default shoe when conditions are met")
    func testAutoStartDefaultShoe() async throws {
        // Given
        let (service, sessionRepository, shoeRepository, _) = createTestService()
        let defaultShoe = TestFixtures.createDefaultShoe()
        shoeRepository.addTestShoe(defaultShoe)
        
        // When
        await service.checkAndAutoStartDefaultShoe()
        
        // Then
        let activeSessions = try await sessionRepository.fetchActiveSessions()
        #expect(activeSessions.count == 1)
        #expect(activeSessions.first?.shoe?.id == defaultShoe.id)
        #expect(activeSessions.first?.autoStarted == true)
    }
    
    @Test("Auto start default shoe skipped when active session exists")
    func testAutoStartDefaultShoeSkippedWhenActiveExists() async throws {
        // Given
        let (service, sessionRepository, shoeRepository, _) = createTestService()
        let defaultShoe = TestFixtures.createDefaultShoe()
        let otherShoe = TestFixtures.createTestShoe()
        shoeRepository.addTestShoe(defaultShoe)
        shoeRepository.addTestShoe(otherShoe)
        
        // Add existing active session
        let existingSession = TestFixtures.createActiveSession(shoe: otherShoe)
        sessionRepository.addTestSession(existingSession)
        
        // When
        await service.checkAndAutoStartDefaultShoe()
        
        // Then
        let activeSessions = try await sessionRepository.fetchActiveSessions()
        #expect(activeSessions.count == 1) // Should still be just the existing session
        #expect(activeSessions.first?.shoe?.id == otherShoe.id)
    }
    
    @Test("Auto close inactive sessions after threshold")
    func testAutoCloseInactiveSessions() async throws {
        // Given
        let (service, sessionRepository, _, _) = createTestService()
        let shoe = TestFixtures.createTestShoe()
        
        // Create session that started over 6 hours ago (past threshold)
        let inactiveSession = TestFixtures.createTestSession(
            shoe: shoe,
            startDate: Date().addingTimeInterval(-25200), // 7 hours ago
            endDate: nil // Still active
        )
        sessionRepository.addTestSession(inactiveSession)
        
        // When
        await service.checkAndAutoCloseInactiveSessions()
        
        // Then
        #expect(inactiveSession.endDate != nil)
        #expect(inactiveSession.autoClosed == true)
    }
    
    @Test("Auto close preserves recent sessions")
    func testAutoClosePreservesRecentSessions() async throws {
        // Given
        let (service, sessionRepository, _, _) = createTestService()
        let shoe = TestFixtures.createTestShoe()
        
        // Create recent session (within threshold)
        let recentSession = TestFixtures.createTestSession(
            shoe: shoe,
            startDate: Date().addingTimeInterval(-1800), // 30 minutes ago
            endDate: nil // Still active
        )
        sessionRepository.addTestSession(recentSession)
        
        // When
        await service.checkAndAutoCloseInactiveSessions()
        
        // Then
        #expect(recentSession.endDate == nil) // Should remain active
        #expect(recentSession.autoClosed == false)
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Service handles repository errors correctly")
    func testRepositoryErrorHandling() async throws {
        // Given
        let (service, sessionRepository, _, _) = createTestService()
        let shoe = TestFixtures.createTestShoe()
        let expectedError = AppError.dataNotFound("Repository error")
        sessionRepository.setShouldThrowError(true, error: expectedError)
        
        // When/Then
        await #expect(throws: AppError.self) {
            try await service.startSession(for: shoe)
        }
        
        #expect(service.error != nil)
    }
    
    @Test("Service clears error on successful operation")
    func testErrorClearing() async throws {
        // Given
        let (service, sessionRepository, _, _) = createTestService()
        let shoe = TestFixtures.createTestShoe()
        
        // Set error first
        sessionRepository.setShouldThrowError(true, error: .dataNotFound("Test error"))
        
        do {
            try await service.getActiveSessions()
        } catch {
            // Expected to fail
        }
        
        #expect(service.error != nil)
        
        // Reset repository
        sessionRepository.setShouldThrowError(false)
        
        // When
        let _ = try await service.getActiveSessions()
        
        // Then
        #expect(service.error == nil)
    }
    
    @Test("Clear error method works")
    func testClearError() async throws {
        // Given
        let (service, sessionRepository, _, _) = createTestService()
        sessionRepository.setShouldThrowError(true, error: .dataNotFound("Test"))
        
        do {
            try await service.getActiveSessions()
        } catch {}
        
        #expect(service.error != nil)
        
        // When
        service.clearError()
        
        // Then
        #expect(service.error == nil)
    }
    
    // MARK: - Edge Cases
    
    @Test("Service handles concurrent session operations")
    func testConcurrentSessionOperations() async throws {
        // Given
        let (service, _, _, _) = createTestService()
        let shoes = TestFixtures.createTestShoeCollection()
        
        // When - Start multiple sessions concurrently
        let tasks = shoes.prefix(3).map { shoe in
            Task {
                try await service.startSession(for: shoe)
            }
        }
        
        let results = try await withThrowingTaskGroup(of: ShoeSession.self) { group in
            for task in tasks {
                group.addTask { try await task.value }
            }
            
            var sessions: [ShoeSession] = []
            for try await session in group {
                sessions.append(session)
            }
            return sessions
        }
        
        // Then - Only one session should be active (due to endAllActiveSessions)
        let activeSessions = try await service.getActiveSessions()
        #expect(activeSessions.count == 1)
        #expect(results.count == 3) // All operations should complete
    }
    
    @Test("Service handles session for same shoe multiple times")
    func testMultipleSessionsForSameShoe() async throws {
        // Given
        let (service, _, _, _) = createTestService()
        let shoe = TestFixtures.createTestShoe()
        
        // Start first session
        let _ = try await service.startSession(for: shoe)
        
        // When/Then - Try to start second session for same shoe
        await #expect(throws: AppError.self) {
            try await service.startSession(for: shoe)
        }
        
        #expect(service.error == .sessionAlreadyActive)
    }
}
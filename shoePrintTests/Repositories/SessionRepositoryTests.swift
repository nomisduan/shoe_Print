//
//  SessionRepositoryTests.swift
//  shoePrintTests
//
//  Portfolio Refactor: Unit tests for SessionRepository functionality
//

import Testing
import Foundation
@testable import shoePrint

/// Unit tests for session repository functionality
/// ✅ Tests session data access with proper isolation and edge cases
struct SessionRepositoryTests {
    
    // MARK: - Test Setup
    
    private func createTestRepository() -> MockSessionRepository {
        let repository = MockSessionRepository()
        repository.reset()
        return repository
    }
    
    private func createTestShoes() -> [Shoe] {
        return TestFixtures.createTestShoeCollection()
    }
    
    // MARK: - Active Session Tests
    
    @Test("Fetch active sessions returns only ongoing sessions")
    func testFetchActiveSessions() async throws {
        // Given
        let repository = createTestRepository()
        let shoes = createTestShoes()
        
        // Add active session
        let activeSession = TestFixtures.createActiveSession(shoe: shoes[0])
        repository.addTestSession(activeSession)
        
        // Add completed session
        let completedSession = TestFixtures.createTestSession(shoe: shoes[1])
        repository.addTestSession(completedSession)
        
        // When
        let result = try await repository.fetchActiveSessions()
        
        // Then
        #expect(result.count == 1)
        #expect(result.first?.endDate == nil)
        #expect(result.first?.shoe?.id == shoes[0].id)
    }
    
    @Test("Fetch active session for specific shoe")
    func testFetchActiveSessionForShoe() async throws {
        // Given
        let repository = createTestRepository()
        let shoes = createTestShoes()
        
        let activeSession = TestFixtures.createActiveSession(shoe: shoes[0])
        repository.addTestSession(activeSession)
        
        // When
        let result = try await repository.fetchActiveSession(for: shoes[0])
        
        // Then
        #expect(result != nil)
        #expect(result?.endDate == nil)
        #expect(result?.shoe?.id == shoes[0].id)
    }
    
    @Test("Fetch active session returns nil for shoe without active session")
    func testFetchActiveSessionForShoeWithoutSession() async throws {
        // Given
        let repository = createTestRepository()
        let shoes = createTestShoes()
        
        // Add session for different shoe
        let session = TestFixtures.createActiveSession(shoe: shoes[0])
        repository.addTestSession(session)
        
        // When
        let result = try await repository.fetchActiveSession(for: shoes[1])
        
        // Then
        #expect(result == nil)
    }
    
    @Test("Has active sessions returns true when sessions exist")
    func testHasActiveSessionsTrue() async throws {
        // Given
        let repository = createTestRepository()
        let shoes = createTestShoes()
        
        let activeSession = TestFixtures.createActiveSession(shoe: shoes[0])
        repository.addTestSession(activeSession)
        
        // When
        let result = try await repository.hasActiveSessions()
        
        // Then
        #expect(result == true)
    }
    
    @Test("Has active sessions returns false when no sessions exist")
    func testHasActiveSessionsFalse() async throws {
        // Given
        let repository = createTestRepository()
        
        // When
        let result = try await repository.hasActiveSessions()
        
        // Then
        #expect(result == false)
    }
    
    // MARK: - Session Lifecycle Tests
    
    @Test("Start session creates new session")
    func testStartSession() async throws {
        // Given
        let repository = createTestRepository()
        let shoe = TestFixtures.createTestShoe()
        
        // When
        let result = try await repository.startSession(for: shoe, autoStarted: false)
        
        // Then
        #expect(result.shoe?.id == shoe.id)
        #expect(result.endDate == nil)
        #expect(result.autoStarted == false)
        #expect(result.autoClosed == false)
    }
    
    @Test("Start auto session marks as auto started")
    func testStartAutoSession() async throws {
        // Given
        let repository = createTestRepository()
        let shoe = TestFixtures.createTestShoe()
        
        // When
        let result = try await repository.startSession(for: shoe, autoStarted: true)
        
        // Then
        #expect(result.autoStarted == true)
    }
    
    @Test("End session sets end date")
    func testEndSession() async throws {
        // Given
        let repository = createTestRepository()
        let shoe = TestFixtures.createTestShoe()
        let session = TestFixtures.createActiveSession(shoe: shoe)
        repository.addTestSession(session)
        
        // When
        try await repository.endSession(session, autoClosed: false)
        
        // Then
        #expect(session.endDate != nil)
        #expect(session.autoClosed == false)
    }
    
    @Test("End session with auto close marks as auto closed")
    func testEndSessionAutoClose() async throws {
        // Given
        let repository = createTestRepository()
        let shoe = TestFixtures.createTestShoe()
        let session = TestFixtures.createActiveSession(shoe: shoe)
        repository.addTestSession(session)
        
        // When
        try await repository.endSession(session, autoClosed: true)
        
        // Then
        #expect(session.endDate != nil)
        #expect(session.autoClosed == true)
    }
    
    @Test("End all active sessions closes all ongoing sessions")
    func testEndAllActiveSessions() async throws {
        // Given
        let repository = createTestRepository()
        let shoes = createTestShoes()
        
        // Create multiple active sessions
        let session1 = TestFixtures.createActiveSession(shoe: shoes[0])
        let session2 = TestFixtures.createActiveSession(shoe: shoes[1])
        repository.addTestSession(session1)
        repository.addTestSession(session2)
        
        // When
        try await repository.endAllActiveSessions()
        
        // Then
        let activeSessions = try await repository.fetchActiveSessions()
        #expect(activeSessions.isEmpty)
        #expect(session1.endDate != nil)
        #expect(session2.endDate != nil)
    }
    
    // MARK: - Date-Based Queries Tests
    
    @Test("Fetch sessions for date returns sessions from that day")
    func testFetchSessionsForDate() async throws {
        // Given
        let repository = createTestRepository()
        let shoes = createTestShoes()
        let targetDate = Date()
        let calendar = Calendar.current
        
        // Session on target date
        let todaySession = TestFixtures.createTestSession(
            shoe: shoes[0],
            startDate: targetDate,
            endDate: targetDate.addingTimeInterval(3600)
        )
        repository.addTestSession(todaySession)
        
        // Session on different date
        let yesterdayDate = calendar.date(byAdding: .day, value: -1, to: targetDate)!
        let yesterdaySession = TestFixtures.createTestSession(
            shoe: shoes[1],
            startDate: yesterdayDate,
            endDate: yesterdayDate.addingTimeInterval(3600)
        )
        repository.addTestSession(yesterdaySession)
        
        // When
        let result = try await repository.fetchSessionsForDate(targetDate)
        
        // Then
        #expect(result.count == 1)
        #expect(result.first?.shoe?.id == shoes[0].id)
    }
    
    @Test("Fetch today sessions returns current day sessions")
    func testFetchTodaySessions() async throws {
        // Given
        let repository = createTestRepository()
        let shoes = createTestShoes()
        let now = Date()
        
        // Today's session
        let todaySession = TestFixtures.createTestSession(shoe: shoes[0], startDate: now)
        repository.addTestSession(todaySession)
        
        // Yesterday's session
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let yesterdaySession = TestFixtures.createTestSession(shoe: shoes[1], startDate: yesterday)
        repository.addTestSession(yesterdaySession)
        
        // When
        let result = try await repository.fetchTodaySessions()
        
        // Then
        #expect(result.count == 1)
        #expect(result.first?.shoe?.id == shoes[0].id)
    }
    
    // MARK: - Statistics Tests
    
    @Test("Get session count returns correct count for shoe")
    func testGetSessionCount() async throws {
        // Given
        let repository = createTestRepository()
        let shoes = createTestShoes()
        
        // Add sessions for specific shoe
        let session1 = TestFixtures.createTestSession(shoe: shoes[0])
        let session2 = TestFixtures.createTestSession(shoe: shoes[0])
        let session3 = TestFixtures.createTestSession(shoe: shoes[1]) // Different shoe
        
        repository.addTestSession(session1)
        repository.addTestSession(session2)
        repository.addTestSession(session3)
        
        // When
        let result = try await repository.getSessionCount(for: shoes[0])
        
        // Then
        #expect(result == 2)
    }
    
    @Test("Get total wearing time calculates correctly")
    func testGetTotalWearingTime() async throws {
        // Given
        let repository = createTestRepository()
        let shoe = TestFixtures.createTestShoe()
        let now = Date()
        
        // Session 1: 1 hour
        let session1 = TestFixtures.createTestSession(
            shoe: shoe,
            startDate: now.addingTimeInterval(-7200), // 2 hours ago
            endDate: now.addingTimeInterval(-3600)    // 1 hour ago
        )
        
        // Session 2: 2 hours
        let session2 = TestFixtures.createTestSession(
            shoe: shoe,
            startDate: now.addingTimeInterval(-3600), // 1 hour ago
            endDate: now.addingTimeInterval(3600)     // 1 hour from now
        )
        
        repository.addTestSession(session1)
        repository.addTestSession(session2)
        
        // When
        let result = try await repository.getTotalWearingTime(for: shoe)
        
        // Then
        let expectedTime = 3600.0 + 7200.0 // 1 hour + 2 hours
        #expect(abs(result - expectedTime) < 1.0) // Allow small floating point differences
    }
    
    @Test("Get total wearing time excludes active sessions")
    func testGetTotalWearingTimeExcludesActiveSessions() async throws {
        // Given
        let repository = createTestRepository()
        let shoe = TestFixtures.createTestShoe()
        
        // Completed session
        let completedSession = TestFixtures.createTestSession(shoe: shoe)
        repository.addTestSession(completedSession)
        
        // Active session (no end date)
        let activeSession = TestFixtures.createActiveSession(shoe: shoe)
        repository.addTestSession(activeSession)
        
        // When
        let result = try await repository.getTotalWearingTime(for: shoe)
        
        // Then
        let expectedTime = completedSession.endDate!.timeIntervalSince(completedSession.startDate)
        #expect(abs(result - expectedTime) < 1.0)
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Repository throws expected errors")
    func testRepositoryErrorHandling() async throws {
        // Given
        let repository = createTestRepository()
        let shoe = TestFixtures.createTestShoe()
        let expectedError = AppError.dataNotFound("Test error")
        repository.setShouldThrowError(true, error: expectedError)
        
        // When/Then
        await #expect(throws: AppError.self) {
            try await repository.fetchActiveSessions()
        }
        
        await #expect(throws: AppError.self) {
            try await repository.startSession(for: shoe, autoStarted: false)
        }
    }
    
    // MARK: - Edge Cases
    
    @Test("Repository handles empty session collection")
    func testEmptySessionCollection() async throws {
        // Given
        let repository = createTestRepository()
        let shoe = TestFixtures.createTestShoe()
        
        // When
        let activeSessions = try await repository.fetchActiveSessions()
        let activeSession = try await repository.fetchActiveSession(for: shoe)
        let hasActive = try await repository.hasActiveSessions()
        let sessionCount = try await repository.getSessionCount(for: shoe)
        let totalTime = try await repository.getTotalWearingTime(for: shoe)
        
        // Then
        #expect(activeSessions.isEmpty)
        #expect(activeSession == nil)
        #expect(hasActive == false)
        #expect(sessionCount == 0)
        #expect(totalTime == 0)
    }
    
    @Test("Handles sessions spanning midnight correctly")
    func testSessionsSpanningMidnight() async throws {
        // Given
        let repository = createTestRepository()
        let shoe = TestFixtures.createTestShoe()
        let calendar = Calendar.current
        
        // Session starting yesterday and ending today
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        let todayMidnight = calendar.startOfDay(for: Date())
        let today = todayMidnight.addingTimeInterval(3600) // 1 AM today
        
        let spanningSession = TestFixtures.createTestSession(
            shoe: shoe,
            startDate: yesterday.addingTimeInterval(82800), // 11 PM yesterday
            endDate: today
        )
        repository.addTestSession(spanningSession)
        
        // When
        let yesterdaySessions = try await repository.fetchSessionsForDate(yesterday)
        let todaySessions = try await repository.fetchSessionsForDate(Date())
        
        // Then
        // Session should appear in yesterday's results (based on start date)
        #expect(yesterdaySessions.count == 1)
        #expect(todaySessions.count == 0)
    }
}
//
//  MockRepositories.swift
//  shoePrintTests
//
//  Portfolio Refactor: Mock repository implementations for testing
//

import Foundation
import SwiftData
@testable import shoePrint

// MARK: - Mock Shoe Repository

/// Mock implementation of ShoeRepositoryProtocol for testing
final class MockShoeRepository: ShoeRepositoryProtocol {
    
    // MARK: - Test Storage
    
    private var shoes: [Shoe] = []
    private var shouldThrowError = false
    private var errorToThrow: AppError = .dataNotFound("Mock error")
    
    // MARK: - Test Control Methods
    
    func setShouldThrowError(_ shouldThrow: Bool, error: AppError = .dataNotFound("Mock error")) {
        shouldThrowError = shouldThrow
        errorToThrow = error
    }
    
    func reset() {
        shoes.removeAll()
        shouldThrowError = false
    }
    
    func addTestShoe(_ shoe: Shoe) {
        shoes.append(shoe)
    }
    
    // MARK: - ShoeRepositoryProtocol Implementation
    
    func fetchAllShoes() async throws -> [Shoe] {
        if shouldThrowError { throw errorToThrow }
        return shoes
    }
    
    func fetchActiveShoes() async throws -> [Shoe] {
        if shouldThrowError { throw errorToThrow }
        return shoes.filter { !$0.archived }
    }
    
    func fetchArchivedShoes() async throws -> [Shoe] {
        if shouldThrowError { throw errorToThrow }
        return shoes.filter { $0.archived }
    }
    
    func fetchShoe(by id: PersistentIdentifier) async throws -> Shoe? {
        if shouldThrowError { throw errorToThrow }
        return shoes.first { $0.id.description == id.description }
    }
    
    func fetchDefaultShoe() async throws -> Shoe? {
        if shouldThrowError { throw errorToThrow }
        return shoes.first { $0.isDefault }
    }
    
    func createShoe(brand: String, model: String, notes: String, icon: String, color: String, estimatedLifespan: Double) async throws -> Shoe {
        if shouldThrowError { throw errorToThrow }
        
        let shoe = Shoe(
            brand: brand,
            model: model,
            notes: notes,
            icon: icon,
            color: color,
            archived: false,
            isDefault: false,
            estimatedLifespan: estimatedLifespan
        )
        
        shoes.append(shoe)
        return shoe
    }
    
    func updateShoe(_ shoe: Shoe, brand: String?, model: String?, notes: String?, icon: String?, color: String?, estimatedLifespan: Double?) async throws {
        if shouldThrowError { throw errorToThrow }
        
        // In a real repository, this would update the persistent model
        // For testing, we'll just simulate the update
        if let brand = brand { shoe.brand = brand }
        if let model = model { shoe.model = model }
        if let notes = notes { shoe.notes = notes }
        if let icon = icon { shoe.icon = icon }
        if let color = color { shoe.color = color }
        if let lifespan = estimatedLifespan { shoe.estimatedLifespan = lifespan }
    }
    
    func deleteShoe(_ shoe: Shoe) async throws {
        if shouldThrowError { throw errorToThrow }
        shoes.removeAll { $0.id == shoe.id }
    }
    
    func archiveShoe(_ shoe: Shoe) async throws {
        if shouldThrowError { throw errorToThrow }
        shoe.archive()
    }
    
    func unarchiveShoe(_ shoe: Shoe) async throws {
        if shouldThrowError { throw errorToThrow }
        shoe.unarchive()
    }
}

// MARK: - Mock Session Repository

/// Mock implementation of SessionRepositoryProtocol for testing
final class MockSessionRepository: SessionRepositoryProtocol {
    
    // MARK: - Test Storage
    
    private var sessions: [ShoeSession] = []
    private var shouldThrowError = false
    private var errorToThrow: AppError = .dataNotFound("Mock error")
    
    // MARK: - Test Control Methods
    
    func setShouldThrowError(_ shouldThrow: Bool, error: AppError = .dataNotFound("Mock error")) {
        shouldThrowError = shouldThrow
        errorToThrow = error
    }
    
    func reset() {
        sessions.removeAll()
        shouldThrowError = false
    }
    
    func addTestSession(_ session: ShoeSession) {
        sessions.append(session)
    }
    
    // MARK: - SessionRepositoryProtocol Implementation
    
    func fetchActiveSessions() async throws -> [ShoeSession] {
        if shouldThrowError { throw errorToThrow }
        return sessions.filter { $0.endDate == nil }
    }
    
    func fetchActiveSession(for shoe: Shoe) async throws -> ShoeSession? {
        if shouldThrowError { throw errorToThrow }
        return sessions.first { $0.shoe?.id == shoe.id && $0.endDate == nil }
    }
    
    func fetchSessionsForDate(_ date: Date) async throws -> [ShoeSession] {
        if shouldThrowError { throw errorToThrow }
        let calendar = Calendar.current
        return sessions.filter { session in
            calendar.isDate(session.startDate, inSameDayAs: date)
        }
    }
    
    func fetchTodaySessions() async throws -> [ShoeSession] {
        if shouldThrowError { throw errorToThrow }
        return try await fetchSessionsForDate(Date())
    }
    
    func hasActiveSessions() async throws -> Bool {
        if shouldThrowError { throw errorToThrow }
        return !sessions.filter { $0.endDate == nil }.isEmpty
    }
    
    func startSession(for shoe: Shoe, autoStarted: Bool) async throws -> ShoeSession {
        if shouldThrowError { throw errorToThrow }
        
        let session = ShoeSession(
            shoe: shoe,
            startDate: Date(),
            autoStarted: autoStarted
        )
        
        sessions.append(session)
        return session
    }
    
    func endSession(_ session: ShoeSession, autoClosed: Bool) async throws {
        if shouldThrowError { throw errorToThrow }
        session.endDate = Date()
        session.autoClosed = autoClosed
    }
    
    func endAllActiveSessions() async throws {
        if shouldThrowError { throw errorToThrow }
        let activeSessions = sessions.filter { $0.endDate == nil }
        for session in activeSessions {
            session.endDate = Date()
        }
    }
    
    func getSessionCount(for shoe: Shoe) async throws -> Int {
        if shouldThrowError { throw errorToThrow }
        return sessions.filter { $0.shoe?.id == shoe.id }.count
    }
    
    func getTotalWearingTime(for shoe: Shoe) async throws -> TimeInterval {
        if shouldThrowError { throw errorToThrow }
        let shoeSessions = sessions.filter { $0.shoe?.id == shoe.id && $0.endDate != nil }
        return shoeSessions.reduce(0) { total, session in
            total + (session.endDate?.timeIntervalSince(session.startDate) ?? 0)
        }
    }
}

// MARK: - Mock Attribution Repository

/// Mock implementation of AttributionRepositoryProtocol for testing
final class MockAttributionRepository: AttributionRepositoryProtocol {
    
    // MARK: - Test Storage
    
    private var attributions: [HourAttribution] = []
    private var shouldThrowError = false
    private var errorToThrow: AppError = .dataNotFound("Mock error")
    
    // MARK: - Test Control Methods
    
    func setShouldThrowError(_ shouldThrow: Bool, error: AppError = .dataNotFound("Mock error")) {
        shouldThrowError = shouldThrow
        errorToThrow = error
    }
    
    func reset() {
        attributions.removeAll()
        shouldThrowError = false
    }
    
    func addTestAttribution(_ attribution: HourAttribution) {
        attributions.append(attribution)
    }
    
    // MARK: - AttributionRepositoryProtocol Implementation
    
    func fetchAttributions(for date: Date) async throws -> [HourAttribution] {
        if shouldThrowError { throw errorToThrow }
        let calendar = Calendar.current
        return attributions.filter { attribution in
            calendar.isDate(attribution.hourDate, inSameDayAs: date)
        }
    }
    
    func fetchAttribution(for hourDate: Date) async throws -> HourAttribution? {
        if shouldThrowError { throw errorToThrow }
        let calendar = Calendar.current
        return attributions.first { attribution in
            calendar.isDate(attribution.hourDate, equalTo: hourDate, toGranularity: .hour)
        }
    }
    
    func createAttribution(hourDate: Date, shoe: Shoe, steps: Int, distance: Double) async throws -> HourAttribution {
        if shouldThrowError { throw errorToThrow }
        
        let attribution = HourAttribution(
            hourDate: hourDate,
            shoe: shoe,
            steps: steps,
            distance: distance
        )
        
        attributions.append(attribution)
        return attribution
    }
    
    func updateAttribution(_ attribution: HourAttribution, shoe: Shoe?, steps: Int?, distance: Double?) async throws {
        if shouldThrowError { throw errorToThrow }
        
        if let shoe = shoe { attribution.shoe = shoe }
        if let steps = steps { attribution.steps = steps }
        if let distance = distance { attribution.distance = distance }
    }
    
    func deleteAttribution(_ attribution: HourAttribution) async throws {
        if shouldThrowError { throw errorToThrow }
        attributions.removeAll { $0.id == attribution.id }
    }
    
    func deleteAttributions(for hourDates: [Date]) async throws {
        if shouldThrowError { throw errorToThrow }
        let calendar = Calendar.current
        attributions.removeAll { attribution in
            hourDates.contains { hourDate in
                calendar.isDate(attribution.hourDate, equalTo: hourDate, toGranularity: .hour)
            }
        }
    }
}
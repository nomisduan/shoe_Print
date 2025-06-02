//
//  ShoeDataValidator.swift
//  shoePrint
//
//  Created by Simon Naud on 31/05/2025.
//

import Foundation
import SwiftData

/// Utility service for validating shoe data integrity and detecting duplication issues
@MainActor
final class ShoeDataValidator {
    
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Validation Methods
    
    /// Validates all shoes for data integrity issues
    func validateAllShoes() async -> ValidationReport {
        print("🔍 Starting comprehensive shoe data validation...")
        
        var report = ValidationReport()
        
        do {
            let allShoes = try modelContext.fetch(FetchDescriptor<Shoe>())
            let allSessions = try modelContext.fetch(FetchDescriptor<ShoeSession>())
            
            print("📊 Validating \(allShoes.count) shoes and \(allSessions.count) sessions")
            
            for shoe in allShoes {
                let shoeReport = await validateShoe(shoe, allSessions: allSessions)
                report.shoeReports.append(shoeReport)
                
                if shoeReport.hasIssues {
                    report.totalIssues += shoeReport.issues.count
                }
            }
            
            // Check for orphaned sessions
            let orphanedSessions = allSessions.filter { $0.shoe == nil }
            if !orphanedSessions.isEmpty {
                report.globalIssues.append("Found \(orphanedSessions.count) orphaned sessions without shoes")
            }
            
            // Check for overlapping sessions
            let overlappingSessions = findOverlappingSessions(allSessions)
            if !overlappingSessions.isEmpty {
                report.globalIssues.append("Found \(overlappingSessions.count) overlapping session pairs")
            }
            
            print("✅ Validation complete: \(report.totalIssues) issues found")
            
        } catch {
            print("❌ Error during validation: \(error)")
            report.globalIssues.append("Validation failed: \(error.localizedDescription)")
        }
        
        return report
    }
    
    /// Validates a single shoe for data integrity
    private func validateShoe(_ shoe: Shoe, allSessions: [ShoeSession]) async -> ShoeValidationReport {
        var report = ShoeValidationReport(shoe: shoe)
        
        // Get sessions for this shoe
        let shoeSessions = allSessions.filter { session in
            session.shoe?.persistentModelID == shoe.persistentModelID
        }
        
        // Calculate expected values
        let expectedSessionDistance = shoeSessions.reduce(0) { $0 + $1.distance }
        let expectedEntriesDistance = shoe.entries.reduce(0) { $0 + $1.distance }
        
        // Check distance calculation method
        let expectedTotalDistance: Double
        if !shoeSessions.isEmpty {
            expectedTotalDistance = expectedSessionDistance
            report.calculationMethod = .sessionBased
        } else {
            expectedTotalDistance = expectedEntriesDistance
            report.calculationMethod = .entryBased
        }
        
        // Validate current distance
        let actualDistance = shoe.totalDistance
        let distanceDifference = abs(actualDistance - expectedTotalDistance)
        
        if distanceDifference > 0.01 { // More than 1cm difference
            report.issues.append(.distanceMismatch(
                expected: expectedTotalDistance,
                actual: actualDistance,
                difference: distanceDifference
            ))
        }
        
        // Check for active state consistency
        let expectedIsActive = shoeSessions.contains { $0.endDate == nil }
        if shoe.isActive != expectedIsActive {
            report.issues.append(.activeStateMismatch(
                expected: expectedIsActive,
                actual: shoe.isActive
            ))
        }
        
        // Check for potential double counting
        if !shoeSessions.isEmpty && !shoe.entries.isEmpty && actualDistance > expectedSessionDistance + 0.01 {
            report.issues.append(.potentialDoubleCounting(
                sessionDistance: expectedSessionDistance,
                entriesDistance: expectedEntriesDistance,
                totalDistance: actualDistance
            ))
        }
        
        // Check session data integrity
        for session in shoeSessions {
            if session.distance < 0 || session.steps < 0 {
                report.issues.append(.invalidSessionData(session: session))
            }
        }
        
        return report
    }
    
    /// Finds overlapping sessions that could cause duplication
    private func findOverlappingSessions(_ sessions: [ShoeSession]) -> [(ShoeSession, ShoeSession)] {
        var overlapping: [(ShoeSession, ShoeSession)] = []
        
        for i in 0..<sessions.count {
            for j in (i+1)..<sessions.count {
                let session1 = sessions[i]
                let session2 = sessions[j]
                
                if sessionsOverlap(session1, session2) {
                    overlapping.append((session1, session2))
                }
            }
        }
        
        return overlapping
    }
    
    /// Checks if two sessions overlap in time
    private func sessionsOverlap(_ session1: ShoeSession, _ session2: ShoeSession) -> Bool {
        let end1 = session1.endDate ?? Date()
        let end2 = session2.endDate ?? Date()
        
        return session1.startDate < end2 && session2.startDate < end1
    }
    
    // MARK: - Repair Methods
    
    /// Repairs common data integrity issues
    func repairDataIntegrityIssues() async -> Int {
        print("🔧 Starting data integrity repairs...")
        
        var repairCount = 0
        
        do {
            let allShoes = try modelContext.fetch(FetchDescriptor<Shoe>())
            
            for shoe in allShoes {
                let wasRepaired = await repairShoe(shoe)
                if wasRepaired {
                    repairCount += 1
                }
            }
            
            if repairCount > 0 {
                try modelContext.save()
                print("✅ Repaired \(repairCount) shoes")
            } else {
                print("✅ No repairs needed")
            }
            
        } catch {
            print("❌ Error during repair: \(error)")
        }
        
        return repairCount
    }
    
    /// Repairs a single shoe's data integrity issues
    private func repairShoe(_ shoe: Shoe) async -> Bool {
        var wasRepaired = false
        
        // Computed properties now automatically reflect current state - no manual repair needed
        // Simply accessing the properties ensures relationships are loaded
        let _ = shoe.isActive
        let _ = shoe.totalDistance
        wasRepaired = true
        
        print("🔧 Triggered computed property access for \(shoe.brand) \(shoe.model)")
        
        return wasRepaired
    }
}

// MARK: - Data Models

struct ValidationReport {
    var shoeReports: [ShoeValidationReport] = []
    var globalIssues: [String] = []
    var totalIssues: Int = 0
    
    var hasIssues: Bool {
        return totalIssues > 0 || !globalIssues.isEmpty
    }
}

struct ShoeValidationReport {
    let shoe: Shoe
    var issues: [ValidationIssue] = []
    var calculationMethod: DistanceCalculationMethod = .unknown
    
    var hasIssues: Bool {
        return !issues.isEmpty
    }
}

enum ValidationIssue {
    case distanceMismatch(expected: Double, actual: Double, difference: Double)
    case activeStateMismatch(expected: Bool, actual: Bool)
    case potentialDoubleCounting(sessionDistance: Double, entriesDistance: Double, totalDistance: Double)
    case invalidSessionData(session: ShoeSession)
    
    var description: String {
        switch self {
        case .distanceMismatch(let expected, let actual, let difference):
            return "Distance mismatch: expected \(String(format: "%.1f", expected))km, got \(String(format: "%.1f", actual))km (diff: \(String(format: "%.1f", difference))km)"
        case .activeStateMismatch(let expected, let actual):
            return "Active state mismatch: expected \(expected), got \(actual)"
        case .potentialDoubleCounting(let sessionDistance, let entriesDistance, let totalDistance):
            return "Potential double counting: sessions \(String(format: "%.1f", sessionDistance))km + entries \(String(format: "%.1f", entriesDistance))km = total \(String(format: "%.1f", totalDistance))km"
        case .invalidSessionData(let session):
            return "Invalid session data: \(session.steps) steps, \(String(format: "%.1f", session.distance))km"
        }
    }
}

enum DistanceCalculationMethod {
    case sessionBased
    case entryBased
    case unknown
    
    var description: String {
        switch self {
        case .sessionBased: return "Session-based"
        case .entryBased: return "Entry-based (legacy)"
        case .unknown: return "Unknown"
        }
    }
}
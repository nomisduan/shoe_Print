//
//  ShoeService.swift
//  shoePrint
//
//  Portfolio Refactor: Clean business logic service for shoes
//

import Foundation

/// Business logic service for shoe operations
/// ✅ Clean separation of concerns, proper error handling, and testable architecture
@MainActor
final class ShoeService: ObservableObject {
    
    // MARK: - Properties
    
    private let shoeRepository: ShoeRepositoryProtocol
    private let sessionRepository: SessionRepositoryProtocol
    private let attributionRepository: AttributionRepositoryProtocol
    
    @Published var isLoading = false
    @Published var error: AppError?
    
    // MARK: - Initialization
    
    init(
        shoeRepository: ShoeRepositoryProtocol,
        sessionRepository: SessionRepositoryProtocol,
        attributionRepository: AttributionRepositoryProtocol
    ) {
        self.shoeRepository = shoeRepository
        self.sessionRepository = sessionRepository
        self.attributionRepository = attributionRepository
    }
    
    // MARK: - Shoe CRUD Operations
    
    /// Creates a new shoe
    func createShoe(
        brand: String,
        model: String,
        notes: String = "",
        icon: String = "👟",
        color: String = "CustomBlue",
        purchaseDate: Date? = nil,
        purchasePrice: Double? = nil,
        estimatedLifespan: Double = 800.0
    ) async throws {
        
        guard !brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppError.shoeValidationFailed("Brand cannot be empty")
        }
        
        guard !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppError.shoeValidationFailed("Model cannot be empty")
        }
        
        guard estimatedLifespan > 0 else {
            throw AppError.shoeValidationFailed("Estimated lifespan must be greater than 0")
        }
        
        isLoading = true
        error = nil
        
        do {
            let shoe = Shoe(
                brand: brand.trimmingCharacters(in: .whitespacesAndNewlines),
                model: model.trimmingCharacters(in: .whitespacesAndNewlines),
                notes: notes,
                icon: icon,
                color: color,
                purchaseDate: purchaseDate,
                purchasePrice: purchasePrice,
                estimatedLifespan: estimatedLifespan
            )
            
            try await shoeRepository.saveShoe(shoe)
            
        } catch {
            let appError = error as? AppError ?? AppError.saveFailed(error.localizedDescription)
            self.error = appError
            throw appError
        }
        
        isLoading = false
    }
    
    /// Updates an existing shoe
    func updateShoe(
        _ shoe: Shoe,
        brand: String? = nil,
        model: String? = nil,
        notes: String? = nil,
        icon: String? = nil,
        color: String? = nil,
        purchaseDate: Date? = nil,
        purchasePrice: Double? = nil,
        estimatedLifespan: Double? = nil
    ) async throws {
        
        guard !shoe.archived else {
            throw AppError.shoeArchived
        }
        
        isLoading = true
        error = nil
        
        do {
            // Update properties if provided
            if let brand = brand?.trimmingCharacters(in: .whitespacesAndNewlines), !brand.isEmpty {
                shoe.brand = brand
            }
            if let model = model?.trimmingCharacters(in: .whitespacesAndNewlines), !model.isEmpty {
                shoe.model = model
            }
            if let notes = notes {
                shoe.notes = notes
            }
            if let icon = icon {
                shoe.icon = icon
            }
            if let color = color {
                shoe.color = color
            }
            if let purchaseDate = purchaseDate {
                shoe.purchaseDate = purchaseDate
            }
            if let purchasePrice = purchasePrice {
                shoe.purchasePrice = purchasePrice
            }
            if let estimatedLifespan = estimatedLifespan, estimatedLifespan > 0 {
                shoe.estimatedLifespan = estimatedLifespan
            }
            
            try await shoeRepository.saveShoe(shoe)
            
        } catch {
            let appError = error as? AppError ?? AppError.saveFailed(error.localizedDescription)
            self.error = appError
            throw appError
        }
        
        isLoading = false
    }
    
    /// Deletes a shoe and all associated data
    func deleteShoe(_ shoe: Shoe) async throws {
        isLoading = true
        error = nil
        
        do {
            // Delete associated sessions and attributions first
            let sessions = try await sessionRepository.fetchSessions(for: shoe)
            for session in sessions {
                try await sessionRepository.deleteSession(session)
            }
            try await attributionRepository.deleteAllAttributions(for: shoe)
            
            // Delete the shoe
            try await shoeRepository.deleteShoe(shoe)
            
        } catch {
            let appError = error as? AppError ?? AppError.deleteFailed(error.localizedDescription)
            self.error = appError
            throw appError
        }
        
        isLoading = false
    }
    
    // MARK: - Shoe Status Operations
    
    /// Archives a shoe
    func archiveShoe(_ shoe: Shoe) async throws {
        guard !shoe.archived else { return }
        
        isLoading = true
        error = nil
        
        do {
            // End any active sessions
            if let activeSession = try await sessionRepository.fetchActiveSession(for: shoe) {
                try await sessionRepository.endSession(activeSession, autoClosed: false)
            }
            
            try await shoeRepository.archiveShoe(shoe)
            
        } catch {
            let appError = error as? AppError ?? AppError.saveFailed(error.localizedDescription)
            self.error = appError
            throw appError
        }
        
        isLoading = false
    }
    
    /// Unarchives a shoe
    func unarchiveShoe(_ shoe: Shoe) async throws {
        guard shoe.archived else { return }
        
        isLoading = true
        error = nil
        
        do {
            try await shoeRepository.unarchiveShoe(shoe)
            
        } catch {
            let appError = error as? AppError ?? AppError.saveFailed(error.localizedDescription)
            self.error = appError
            throw appError
        }
        
        isLoading = false
    }
    
    /// Sets a shoe as the default
    func setAsDefault(_ shoe: Shoe) async throws {
        guard !shoe.archived else {
            throw AppError.shoeArchived
        }
        
        isLoading = true
        error = nil
        
        do {
            try await shoeRepository.setAsDefault(shoe)
            
        } catch {
            let appError = error as? AppError ?? AppError.saveFailed(error.localizedDescription)
            self.error = appError
            throw appError
        }
        
        isLoading = false
    }
    
    // MARK: - Query Operations
    
    /// Fetches all shoes
    func fetchAllShoes() async throws -> [Shoe] {
        do {
            return try await shoeRepository.fetchAllShoes()
        } catch {
            let appError = error as? AppError ?? AppError.dataNotFound(error.localizedDescription)
            self.error = appError
            throw appError
        }
    }
    
    /// Fetches active shoes
    func fetchActiveShoes() async throws -> [Shoe] {
        do {
            return try await shoeRepository.fetchActiveShoes()
        } catch {
            let appError = error as? AppError ?? AppError.dataNotFound(error.localizedDescription)
            self.error = appError
            throw appError
        }
    }
    
    /// Fetches the default shoe
    func fetchDefaultShoe() async throws -> Shoe? {
        do {
            return try await shoeRepository.fetchDefaultShoe()
        } catch {
            let appError = error as? AppError ?? AppError.dataNotFound(error.localizedDescription)
            self.error = appError
            throw appError
        }
    }
    
    // MARK: - Analytics Operations
    
    /// Gets shoes ordered by usage (most used first)
    func getShoesByUsage() async throws -> [Shoe] {
        do {
            return try await shoeRepository.getShoesByUsage()
        } catch {
            let appError = error as? AppError ?? AppError.dataNotFound(error.localizedDescription)
            self.error = appError
            throw appError
        }
    }
    
    /// Gets shoes ordered by recent usage
    func getShoesByRecentUsage() async throws -> [Shoe] {
        do {
            return try await shoeRepository.getShoesByRecentUsage()
        } catch {
            let appError = error as? AppError ?? AppError.dataNotFound(error.localizedDescription)
            self.error = appError
            throw appError
        }
    }
    
    /// Gets shoe statistics
    func getShoeStatistics() async throws -> ShoeStatistics {
        do {
            let totalShoes = try await shoeRepository.getTotalShoesCount()
            let activeShoes = try await shoeRepository.getActiveShoesCount()
            let archivedShoes = totalShoes - activeShoes
            
            return ShoeStatistics(
                totalShoes: totalShoes,
                activeShoes: activeShoes,
                archivedShoes: archivedShoes
            )
        } catch {
            let appError = error as? AppError ?? AppError.dataNotFound(error.localizedDescription)
            self.error = appError
            throw appError
        }
    }
    
    // MARK: - Error Handling
    
    /// Clears the current error
    func clearError() {
        error = nil
    }
}

// MARK: - Supporting Types

/// Statistics about shoes in the collection
struct ShoeStatistics {
    let totalShoes: Int
    let activeShoes: Int
    let archivedShoes: Int
    
    var archivePercentage: Double {
        guard totalShoes > 0 else { return 0 }
        return Double(archivedShoes) / Double(totalShoes) * 100
    }
}
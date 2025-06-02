//
//  ShoeRepositoryProtocol.swift
//  shoePrint
//
//  Portfolio Refactor: Repository pattern implementation
//

import Foundation

/// Protocol defining shoe data access operations
/// ✅ Abstracts SwiftData implementation for testability and flexibility
protocol ShoeRepositoryProtocol {
    
    // MARK: - CRUD Operations
    
    /// Fetches all shoes (including archived)
    func fetchAllShoes() async throws -> [Shoe]
    
    /// Fetches active (non-archived) shoes
    func fetchActiveShoes() async throws -> [Shoe]
    
    /// Fetches archived shoes
    func fetchArchivedShoes() async throws -> [Shoe]
    
    /// Fetches a specific shoe by ID
    func fetchShoe(byId id: String) async throws -> Shoe?
    
    /// Saves a shoe (insert or update)
    func saveShoe(_ shoe: Shoe) async throws
    
    /// Deletes a shoe
    func deleteShoe(_ shoe: Shoe) async throws
    
    // MARK: - Specialized Queries
    
    /// Fetches the default shoe (if any)
    func fetchDefaultShoe() async throws -> Shoe?
    
    /// Sets a shoe as default (ensuring only one default exists)
    func setAsDefault(_ shoe: Shoe) async throws
    
    /// Removes default status from all shoes
    func clearAllDefaults() async throws
    
    /// Archives a shoe
    func archiveShoe(_ shoe: Shoe) async throws
    
    /// Unarchives a shoe
    func unarchiveShoe(_ shoe: Shoe) async throws
    
    // MARK: - Statistics & Analytics
    
    /// Gets total shoes count
    func getTotalShoesCount() async throws -> Int
    
    /// Gets active shoes count
    func getActiveShoesCount() async throws -> Int
    
    /// Gets shoes ordered by most used (total distance)
    func getShoesByUsage() async throws -> [Shoe]
    
    /// Gets shoes ordered by most recent usage
    func getShoesByRecentUsage() async throws -> [Shoe]
}
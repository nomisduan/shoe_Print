//
//  SwiftDataShoeRepository.swift
//  shoePrint
//
//  Portfolio Refactor: SwiftData implementation of ShoeRepository
//

import Foundation
import SwiftData

/// SwiftData implementation of ShoeRepositoryProtocol
/// ✅ Concrete implementation that can be swapped for testing or different storage
@MainActor
final class SwiftDataShoeRepository: ShoeRepositoryProtocol {
    
    // MARK: - Properties
    
    private let modelContext: ModelContext
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - CRUD Operations
    
    func fetchAllShoes() async throws -> [Shoe] {
        let descriptor = FetchDescriptor<Shoe>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    func fetchActiveShoes() async throws -> [Shoe] {
        let descriptor = FetchDescriptor<Shoe>(
            predicate: #Predicate<Shoe> { shoe in
                !shoe.archived
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    func fetchArchivedShoes() async throws -> [Shoe] {
        let descriptor = FetchDescriptor<Shoe>(
            predicate: #Predicate<Shoe> { shoe in
                shoe.archived
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    func fetchShoe(byId id: String) async throws -> Shoe? {
        // For now, we'll fetch all shoes and filter by ID string representation
        // This is a limitation of current SwiftData predicate system
        let allShoes = try await fetchAllShoes()
        return allShoes.first { shoe in
            String(describing: shoe.persistentModelID) == id
        }
    }
    
    func saveShoe(_ shoe: Shoe) async throws {
        modelContext.insert(shoe)
        try modelContext.save()
    }
    
    func deleteShoe(_ shoe: Shoe) async throws {
        modelContext.delete(shoe)
        try modelContext.save()
    }
    
    // MARK: - Specialized Queries
    
    func fetchDefaultShoe() async throws -> Shoe? {
        let descriptor = FetchDescriptor<Shoe>(
            predicate: #Predicate<Shoe> { shoe in
                shoe.isDefault && !shoe.archived
            }
        )
        return try modelContext.fetch(descriptor).first
    }
    
    func setAsDefault(_ shoe: Shoe) async throws {
        // First clear all defaults
        try await clearAllDefaults()
        
        // Set this shoe as default
        shoe.isDefault = true
        try modelContext.save()
    }
    
    func clearAllDefaults() async throws {
        let descriptor = FetchDescriptor<Shoe>(
            predicate: #Predicate<Shoe> { shoe in
                shoe.isDefault
            }
        )
        let defaultShoes = try modelContext.fetch(descriptor)
        
        for shoe in defaultShoes {
            shoe.isDefault = false
        }
        
        if !defaultShoes.isEmpty {
            try modelContext.save()
        }
    }
    
    func archiveShoe(_ shoe: Shoe) async throws {
        shoe.archived = true
        // Remove default status if archived
        if shoe.isDefault {
            shoe.isDefault = false
        }
        try modelContext.save()
    }
    
    func unarchiveShoe(_ shoe: Shoe) async throws {
        shoe.archived = false
        try modelContext.save()
    }
    
    // MARK: - Statistics & Analytics
    
    func getTotalShoesCount() async throws -> Int {
        let descriptor = FetchDescriptor<Shoe>()
        return try modelContext.fetch(descriptor).count
    }
    
    func getActiveShoesCount() async throws -> Int {
        let descriptor = FetchDescriptor<Shoe>(
            predicate: #Predicate<Shoe> { shoe in
                !shoe.archived
            }
        )
        return try modelContext.fetch(descriptor).count
    }
    
    func getShoesByUsage() async throws -> [Shoe] {
        let shoes = try await fetchActiveShoes()
        // Sort by total distance (computed property)
        return shoes.sorted { $0.totalDistance > $1.totalDistance }
    }
    
    func getShoesByRecentUsage() async throws -> [Shoe] {
        let shoes = try await fetchActiveShoes()
        // Sort by last used date (computed property)
        return shoes.sorted { (shoe1, shoe2) in
            guard let date1 = shoe1.lastUsed else { return false }
            guard let date2 = shoe2.lastUsed else { return true }
            return date1 > date2
        }
    }
}
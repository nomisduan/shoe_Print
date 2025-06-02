//
//  ShoeRepositoryTests.swift
//  shoePrintTests
//
//  Portfolio Refactor: Unit tests for ShoeRepository functionality
//

import Testing
import SwiftData
@testable import shoePrint

/// Unit tests for shoe repository functionality
/// ✅ Tests data access layer with proper isolation and mocking
struct ShoeRepositoryTests {
    
    // MARK: - Test Setup
    
    private func createTestRepository() -> MockShoeRepository {
        let repository = MockShoeRepository()
        repository.reset()
        return repository
    }
    
    private func createTestShoes() -> [Shoe] {
        return TestFixtures.createTestShoeCollection()
    }
    
    // MARK: - Fetch Tests
    
    @Test("Fetch all shoes returns complete collection")
    func testFetchAllShoes() async throws {
        // Given
        let repository = createTestRepository()
        let testShoes = createTestShoes()
        
        for shoe in testShoes {
            repository.addTestShoe(shoe)
        }
        
        // When
        let result = try await repository.fetchAllShoes()
        
        // Then
        #expect(result.count == testShoes.count)
        #expect(result.contains { $0.brand == "Nike" })
        #expect(result.contains { $0.brand == "Adidas" })
    }
    
    @Test("Fetch active shoes excludes archived shoes")
    func testFetchActiveShoes() async throws {
        // Given
        let repository = createTestRepository()
        let testShoes = createTestShoes()
        
        for shoe in testShoes {
            repository.addTestShoe(shoe)
        }
        
        // When
        let result = try await repository.fetchActiveShoes()
        
        // Then
        let archivedCount = testShoes.filter { $0.archived }.count
        let expectedActiveCount = testShoes.count - archivedCount
        #expect(result.count == expectedActiveCount)
        #expect(result.allSatisfy { !$0.archived })
    }
    
    @Test("Fetch archived shoes returns only archived shoes")
    func testFetchArchivedShoes() async throws {
        // Given
        let repository = createTestRepository()
        let testShoes = createTestShoes()
        
        for shoe in testShoes {
            repository.addTestShoe(shoe)
        }
        
        // When
        let result = try await repository.fetchArchivedShoes()
        
        // Then
        let expectedArchivedCount = testShoes.filter { $0.archived }.count
        #expect(result.count == expectedArchivedCount)
        #expect(result.allSatisfy { $0.archived })
    }
    
    @Test("Fetch default shoe returns default shoe")
    func testFetchDefaultShoe() async throws {
        // Given
        let repository = createTestRepository()
        let testShoes = createTestShoes()
        
        for shoe in testShoes {
            repository.addTestShoe(shoe)
        }
        
        // When
        let result = try await repository.fetchDefaultShoe()
        
        // Then
        #expect(result != nil)
        #expect(result?.isDefault == true)
        #expect(result?.brand == "Barefoot")
    }
    
    @Test("Fetch default shoe returns nil when no default exists")
    func testFetchDefaultShoeWhenNoneExists() async throws {
        // Given
        let repository = createTestRepository()
        let nonDefaultShoe = TestFixtures.createTestShoe(isDefault: false)
        repository.addTestShoe(nonDefaultShoe)
        
        // When
        let result = try await repository.fetchDefaultShoe()
        
        // Then
        #expect(result == nil)
    }
    
    // MARK: - Create Tests
    
    @Test("Create shoe successfully creates new shoe")
    func testCreateShoe() async throws {
        // Given
        let repository = createTestRepository()
        
        // When
        let result = try await repository.createShoe(
            brand: "Test Brand",
            model: "Test Model",
            notes: "Test Notes",
            icon: "🧪",
            color: "CustomBlue",
            estimatedLifespan: 600.0
        )
        
        // Then
        #expect(result.brand == "Test Brand")
        #expect(result.model == "Test Model")
        #expect(result.notes == "Test Notes")
        #expect(result.icon == "🧪")
        #expect(result.color == "CustomBlue")
        #expect(result.estimatedLifespan == 600.0)
        #expect(!result.archived)
        #expect(!result.isDefault)
    }
    
    // MARK: - Update Tests
    
    @Test("Update shoe modifies properties correctly")
    func testUpdateShoe() async throws {
        // Given
        let repository = createTestRepository()
        let shoe = TestFixtures.createTestShoe()
        repository.addTestShoe(shoe)
        
        // When
        try await repository.updateShoe(
            shoe,
            brand: "Updated Brand",
            model: "Updated Model",
            notes: "Updated Notes",
            icon: "🔄",
            color: "CustomGreen",
            estimatedLifespan: 700.0
        )
        
        // Then
        #expect(shoe.brand == "Updated Brand")
        #expect(shoe.model == "Updated Model")
        #expect(shoe.notes == "Updated Notes")
        #expect(shoe.icon == "🔄")
        #expect(shoe.color == "CustomGreen")
        #expect(shoe.estimatedLifespan == 700.0)
    }
    
    @Test("Update shoe with nil values preserves existing properties")
    func testUpdateShoeWithNilValues() async throws {
        // Given
        let repository = createTestRepository()
        let shoe = TestFixtures.createTestShoe(brand: "Original Brand", model: "Original Model")
        repository.addTestShoe(shoe)
        
        // When
        try await repository.updateShoe(
            shoe,
            brand: "Updated Brand",
            model: nil, // Should preserve original
            notes: nil,
            icon: nil,
            color: nil,
            estimatedLifespan: nil
        )
        
        // Then
        #expect(shoe.brand == "Updated Brand")
        #expect(shoe.model == "Original Model") // Preserved
    }
    
    // MARK: - Archive Tests
    
    @Test("Archive shoe sets archived flag")
    func testArchiveShoe() async throws {
        // Given
        let repository = createTestRepository()
        let shoe = TestFixtures.createTestShoe(archived: false)
        repository.addTestShoe(shoe)
        
        // When
        try await repository.archiveShoe(shoe)
        
        // Then
        #expect(shoe.archived == true)
    }
    
    @Test("Unarchive shoe clears archived flag")
    func testUnarchiveShoe() async throws {
        // Given
        let repository = createTestRepository()
        let shoe = TestFixtures.createTestShoe(archived: true)
        repository.addTestShoe(shoe)
        
        // When
        try await repository.unarchiveShoe(shoe)
        
        // Then
        #expect(shoe.archived == false)
    }
    
    // MARK: - Delete Tests
    
    @Test("Delete shoe removes from collection")
    func testDeleteShoe() async throws {
        // Given
        let repository = createTestRepository()
        let shoe = TestFixtures.createTestShoe()
        repository.addTestShoe(shoe)
        
        let initialCount = try await repository.fetchAllShoes().count
        #expect(initialCount == 1)
        
        // When
        try await repository.deleteShoe(shoe)
        
        // Then
        let finalCount = try await repository.fetchAllShoes().count
        #expect(finalCount == 0)
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Repository throws expected errors")
    func testRepositoryErrorHandling() async throws {
        // Given
        let repository = createTestRepository()
        let expectedError = AppError.dataNotFound("Test error")
        repository.setShouldThrowError(true, error: expectedError)
        
        // When/Then
        await #expect(throws: AppError.self) {
            try await repository.fetchAllShoes()
        }
        
        await #expect(throws: AppError.self) {
            try await repository.createShoe(
                brand: "Test",
                model: "Test",
                notes: "",
                icon: "👟",
                color: "CustomBlue",
                estimatedLifespan: 500.0
            )
        }
    }
    
    // MARK: - Edge Cases
    
    @Test("Repository handles empty collection")
    func testEmptyCollection() async throws {
        // Given
        let repository = createTestRepository()
        
        // When
        let allShoes = try await repository.fetchAllShoes()
        let activeShoes = try await repository.fetchActiveShoes()
        let archivedShoes = try await repository.fetchArchivedShoes()
        let defaultShoe = try await repository.fetchDefaultShoe()
        
        // Then
        #expect(allShoes.isEmpty)
        #expect(activeShoes.isEmpty)
        #expect(archivedShoes.isEmpty)
        #expect(defaultShoe == nil)
    }
    
    @Test("Repository handles multiple default shoes correctly")
    func testMultipleDefaultShoes() async throws {
        // Given
        let repository = createTestRepository()
        let defaultShoe1 = TestFixtures.createTestShoe(brand: "Default 1", isDefault: true)
        let defaultShoe2 = TestFixtures.createTestShoe(brand: "Default 2", isDefault: true)
        
        repository.addTestShoe(defaultShoe1)
        repository.addTestShoe(defaultShoe2)
        
        // When
        let result = try await repository.fetchDefaultShoe()
        
        // Then
        #expect(result != nil)
        #expect(result?.isDefault == true)
        // Should return the first default shoe found
    }
}
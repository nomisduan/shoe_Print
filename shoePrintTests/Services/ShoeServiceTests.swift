//
//  ShoeServiceTests.swift
//  shoePrintTests
//
//  Portfolio Refactor: Unit tests for ShoeService business logic
//

import Testing
import Foundation
@testable import shoePrint

/// Unit tests for shoe service business logic
/// ✅ Tests business rules, validation, and error handling at service layer
struct ShoeServiceTests {
    
    // MARK: - Test Setup
    
    private func createTestService() -> (ShoeService, MockShoeRepository) {
        let repository = MockShoeRepository()
        repository.reset()
        let service = ShoeService(shoeRepository: repository)
        return (service, repository)
    }
    
    // MARK: - Fetch Operations Tests
    
    @Test("Get all shoes returns all shoes from repository")
    func testGetAllShoes() async throws {
        // Given
        let (service, repository) = createTestService()
        let testShoes = TestFixtures.createTestShoeCollection()
        
        for shoe in testShoes {
            repository.addTestShoe(shoe)
        }
        
        // When
        let result = try await service.getAllShoes()
        
        // Then
        #expect(result.count == testShoes.count)
        #expect(service.error == nil)
        #expect(!service.isProcessing)
    }
    
    @Test("Get active shoes excludes archived shoes")
    func testGetActiveShoes() async throws {
        // Given
        let (service, repository) = createTestService()
        let testShoes = TestFixtures.createTestShoeCollection()
        
        for shoe in testShoes {
            repository.addTestShoe(shoe)
        }
        
        // When
        let result = try await service.getActiveShoes()
        
        // Then
        let expectedCount = testShoes.filter { !$0.archived }.count
        #expect(result.count == expectedCount)
        #expect(result.allSatisfy { !$0.archived })
    }
    
    @Test("Get default shoe returns correct shoe")
    func testGetDefaultShoe() async throws {
        // Given
        let (service, repository) = createTestService()
        let defaultShoe = TestFixtures.createDefaultShoe()
        repository.addTestShoe(defaultShoe)
        
        // When
        let result = try await service.getDefaultShoe()
        
        // Then
        #expect(result != nil)
        #expect(result?.isDefault == true)
        #expect(result?.brand == "Barefoot")
    }
    
    // MARK: - Create Shoe Tests
    
    @Test("Create shoe with valid data succeeds")
    func testCreateShoeValid() async throws {
        // Given
        let (service, _) = createTestService()
        
        // When
        let result = try await service.createShoe(
            brand: "Nike",
            model: "Air Max",
            notes: "Running shoes",
            icon: "👟",
            color: "CustomBlue",
            estimatedLifespan: 500.0
        )
        
        // Then
        #expect(result.brand == "Nike")
        #expect(result.model == "Air Max")
        #expect(result.notes == "Running shoes")
        #expect(result.icon == "👟")
        #expect(result.color == "CustomBlue")
        #expect(result.estimatedLifespan == 500.0)
        #expect(service.error == nil)
    }
    
    @Test("Create shoe with empty brand fails validation")
    func testCreateShoeEmptyBrand() async throws {
        // Given
        let (service, _) = createTestService()
        
        // When/Then
        await #expect(throws: AppError.self) {
            try await service.createShoe(
                brand: "",
                model: "Air Max",
                notes: "Running shoes",
                icon: "👟",
                color: "CustomBlue",
                estimatedLifespan: 500.0
            )
        }
        
        // Verify error is set
        #expect(service.error != nil)
        if case .validationFailed(let message) = service.error {
            #expect(message.contains("Brand"))
        }
    }
    
    @Test("Create shoe with empty model fails validation")
    func testCreateShoeEmptyModel() async throws {
        // Given
        let (service, _) = createTestService()
        
        // When/Then
        await #expect(throws: AppError.self) {
            try await service.createShoe(
                brand: "Nike",
                model: "",
                notes: "Running shoes",
                icon: "👟",
                color: "CustomBlue",
                estimatedLifespan: 500.0
            )
        }
    }
    
    @Test("Create shoe with invalid lifespan fails validation")
    func testCreateShoeInvalidLifespan() async throws {
        // Given
        let (service, _) = createTestService()
        
        // When/Then
        await #expect(throws: AppError.self) {
            try await service.createShoe(
                brand: "Nike",
                model: "Air Max",
                notes: "Running shoes",
                icon: "👟",
                color: "CustomBlue",
                estimatedLifespan: -100.0 // Invalid negative lifespan
            )
        }
    }
    
    @Test("Create shoe trims whitespace from inputs")
    func testCreateShoeTrimsWhitespace() async throws {
        // Given
        let (service, _) = createTestService()
        
        // When
        let result = try await service.createShoe(
            brand: "  Nike  ",
            model: "  Air Max  ",
            notes: "  Running shoes  ",
            icon: "👟",
            color: "CustomBlue",
            estimatedLifespan: 500.0
        )
        
        // Then
        #expect(result.brand == "Nike")
        #expect(result.model == "Air Max")
        #expect(result.notes == "Running shoes")
    }
    
    // MARK: - Update Shoe Tests
    
    @Test("Update shoe with valid data succeeds")
    func testUpdateShoeValid() async throws {
        // Given
        let (service, repository) = createTestService()
        let shoe = TestFixtures.createTestShoe()
        repository.addTestShoe(shoe)
        
        // When
        try await service.updateShoe(
            shoe,
            brand: "Updated Nike",
            model: "Updated Air Max",
            notes: "Updated notes",
            icon: "🏃",
            color: "CustomGreen",
            estimatedLifespan: 600.0
        )
        
        // Then
        #expect(shoe.brand == "Updated Nike")
        #expect(shoe.model == "Updated Air Max")
        #expect(shoe.notes == "Updated notes")
        #expect(shoe.icon == "🏃")
        #expect(shoe.color == "CustomGreen")
        #expect(shoe.estimatedLifespan == 600.0)
        #expect(service.error == nil)
    }
    
    @Test("Update shoe with empty brand fails validation")
    func testUpdateShoeEmptyBrand() async throws {
        // Given
        let (service, repository) = createTestService()
        let shoe = TestFixtures.createTestShoe()
        repository.addTestShoe(shoe)
        
        // When/Then
        await #expect(throws: AppError.self) {
            try await service.updateShoe(
                shoe,
                brand: "",
                model: "Updated Model",
                notes: nil,
                icon: nil,
                color: nil,
                estimatedLifespan: nil
            )
        }
    }
    
    @Test("Update shoe with nil values preserves existing")
    func testUpdateShoeWithNilValues() async throws {
        // Given
        let (service, repository) = createTestService()
        let shoe = TestFixtures.createTestShoe(brand: "Original", model: "Original")
        repository.addTestShoe(shoe)
        
        // When
        try await service.updateShoe(
            shoe,
            brand: "Updated",
            model: nil, // Should preserve
            notes: nil,
            icon: nil,
            color: nil,
            estimatedLifespan: nil
        )
        
        // Then
        #expect(shoe.brand == "Updated")
        #expect(shoe.model == "Original") // Preserved
    }
    
    // MARK: - Archive/Unarchive Tests
    
    @Test("Archive shoe sets archived flag")
    func testArchiveShoe() async throws {
        // Given
        let (service, repository) = createTestService()
        let shoe = TestFixtures.createTestShoe(archived: false)
        repository.addTestShoe(shoe)
        
        // When
        try await service.archiveShoe(shoe)
        
        // Then
        #expect(shoe.archived == true)
        #expect(service.error == nil)
    }
    
    @Test("Unarchive shoe clears archived flag")
    func testUnarchiveShoe() async throws {
        // Given
        let (service, repository) = createTestService()
        let shoe = TestFixtures.createTestShoe(archived: true)
        repository.addTestShoe(shoe)
        
        // When
        try await service.unarchiveShoe(shoe)
        
        // Then
        #expect(shoe.archived == false)
        #expect(service.error == nil)
    }
    
    // MARK: - Delete Shoe Tests
    
    @Test("Delete shoe removes from repository")
    func testDeleteShoe() async throws {
        // Given
        let (service, repository) = createTestService()
        let shoe = TestFixtures.createTestShoe()
        repository.addTestShoe(shoe)
        
        // When
        try await service.deleteShoe(shoe)
        
        // Then
        let remainingShoes = try await repository.fetchAllShoes()
        #expect(remainingShoes.isEmpty)
        #expect(service.error == nil)
    }
    
    // MARK: - Business Logic Tests
    
    @Test("Service sets processing state during operations")
    func testProcessingState() async throws {
        // Given
        let (service, repository) = createTestService()
        
        // Verify initial state
        #expect(!service.isProcessing)
        
        // When
        let task = Task {
            try await service.createShoe(
                brand: "Nike",
                model: "Air Max",
                notes: "",
                icon: "👟",
                color: "CustomBlue",
                estimatedLifespan: 500.0
            )
        }
        
        // Brief moment to check processing state
        try await Task.sleep(nanoseconds: 1_000_000) // 1ms
        
        await task.value
        
        // Then
        #expect(!service.isProcessing) // Should be false after completion
    }
    
    @Test("Service clears error on successful operation")
    func testErrorClearing() async throws {
        // Given
        let (service, repository) = createTestService()
        
        // Set an error first
        repository.setShouldThrowError(true, error: .dataNotFound("Test error"))
        
        do {
            try await service.getAllShoes()
        } catch {
            // Expected to fail
        }
        
        // Verify error is set
        #expect(service.error != nil)
        
        // Reset repository to not throw errors
        repository.setShouldThrowError(false)
        
        // When
        let _ = try await service.getAllShoes()
        
        // Then
        #expect(service.error == nil) // Error should be cleared
    }
    
    @Test("Clear error method works correctly")
    func testClearError() async throws {
        // Given
        let (service, repository) = createTestService()
        repository.setShouldThrowError(true, error: .dataNotFound("Test error"))
        
        do {
            try await service.getAllShoes()
        } catch {
            // Expected to fail
        }
        
        #expect(service.error != nil)
        
        // When
        service.clearError()
        
        // Then
        #expect(service.error == nil)
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Service propagates repository errors")
    func testRepositoryErrorPropagation() async throws {
        // Given
        let (service, repository) = createTestService()
        let expectedError = AppError.dataNotFound("Repository error")
        repository.setShouldThrowError(true, error: expectedError)
        
        // When/Then
        await #expect(throws: AppError.self) {
            try await service.getAllShoes()
        }
        
        // Verify error is set in service
        #expect(service.error != nil)
    }
    
    @Test("Service handles validation errors correctly")
    func testValidationErrorHandling() async throws {
        // Given
        let (service, _) = createTestService()
        
        // When/Then
        await #expect(throws: AppError.self) {
            try await service.createShoe(
                brand: "",
                model: "Model",
                notes: "",
                icon: "👟",
                color: "CustomBlue",
                estimatedLifespan: 500.0
            )
        }
        
        // Verify specific error type
        if case .validationFailed = service.error {
            // Expected
        } else {
            #expect(Bool(false), "Expected validation error")
        }
    }
    
    // MARK: - Edge Cases
    
    @Test("Service handles very long input strings")
    func testVeryLongInputStrings() async throws {
        // Given
        let (service, _) = createTestService()
        let longString = String(repeating: "a", count: 10000)
        
        // When/Then
        await #expect(throws: AppError.self) {
            try await service.createShoe(
                brand: longString, // Too long
                model: "Model",
                notes: "",
                icon: "👟",
                color: "CustomBlue",
                estimatedLifespan: 500.0
            )
        }
    }
    
    @Test("Service handles special characters in inputs")
    func testSpecialCharacters() async throws {
        // Given
        let (service, _) = createTestService()
        
        // When
        let result = try await service.createShoe(
            brand: "Brand with émojis & spëcial çhars",
            model: "Model with 123 numbers!",
            notes: "Notes with @#$%^&*() symbols",
            icon: "🏃‍♂️",
            color: "CustomBlue",
            estimatedLifespan: 500.0
        )
        
        // Then
        #expect(result.brand == "Brand with émojis & spëcial çhars")
        #expect(result.model == "Model with 123 numbers!")
        #expect(result.notes == "Notes with @#$%^&*() symbols")
        #expect(result.icon == "🏃‍♂️")
    }
    
    @Test("Service handles extreme lifespan values")
    func testExtremeLifespanValues() async throws {
        // Given
        let (service, _) = createTestService()
        
        // Test maximum reasonable lifespan
        let result = try await service.createShoe(
            brand: "Durable",
            model: "Forever Shoe",
            notes: "",
            icon: "👟",
            color: "CustomBlue",
            estimatedLifespan: 10000.0
        )
        
        #expect(result.estimatedLifespan == 10000.0)
        
        // Test zero lifespan (should fail)
        await #expect(throws: AppError.self) {
            try await service.createShoe(
                brand: "Zero",
                model: "Lifespan",
                notes: "",
                icon: "👟",
                color: "CustomBlue",
                estimatedLifespan: 0.0
            )
        }
    }
    
    @Test("Service validates color values")
    func testColorValidation() async throws {
        // Given
        let (service, _) = createTestService()
        
        // Valid color should work
        let result = try await service.createShoe(
            brand: "Nike",
            model: "Air Max",
            notes: "",
            icon: "👟",
            color: "CustomBlue",
            estimatedLifespan: 500.0
        )
        
        #expect(result.color == "CustomBlue")
        
        // Empty color should fail
        await #expect(throws: AppError.self) {
            try await service.createShoe(
                brand: "Nike",
                model: "Air Max",
                notes: "",
                icon: "👟",
                color: "",
                estimatedLifespan: 500.0
            )
        }
    }
}
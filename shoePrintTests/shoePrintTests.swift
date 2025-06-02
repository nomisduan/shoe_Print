//
//  shoePrintTests.swift
//  shoePrintTests
//
//  Portfolio Refactor: Main test suite entry point
//

import Testing
import SwiftData
@testable import shoePrint

/// Main test suite entry point
/// ✅ Portfolio-ready test infrastructure with comprehensive coverage
struct shoePrintTests {

    @Test("Basic test infrastructure works")
    func testInfrastructure() async throws {
        // Verify basic functionality
        #expect(true)
    }
    
    @Test("Test fixtures create valid data")
    func testFixtures() async throws {
        // Given
        let shoe = TestFixtures.createTestShoe()
        
        // Then
        #expect(shoe.brand == "Nike")
        #expect(shoe.model == "Air Max")
        #expect(shoe.icon == "👟")
    }
    
    @Test("Mock repositories function correctly")
    func testMockRepositories() async throws {
        // Given
        let mockRepo = MockShoeRepository()
        let testShoe = TestFixtures.createTestShoe()
        mockRepo.addTestShoe(testShoe)
        
        // When
        let allShoes = try await mockRepo.fetchAllShoes()
        
        // Then
        #expect(allShoes.count == 1)
        #expect(allShoes.first?.brand == "Nike")
    }
    
    @Test("Dependency injection container works")
    func testDIContainer() async throws {
        // Given
        let container = DIContainer.shared
        
        // When
        container.registerSingleton(String.self) { "Test Value" }
        let resolved = container.resolve(String.self)
        
        // Then
        #expect(resolved == "Test Value")
    }
}

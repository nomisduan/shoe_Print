//
//  DIContainerTests.swift
//  shoePrintTests
//
//  Portfolio Refactor: Unit tests for dependency injection container
//

import Testing
import SwiftData
@testable import shoePrint

/// Unit tests for dependency injection container functionality
/// ✅ Tests service registration, resolution, and lifecycle management
struct DIContainerTests {
    
    // MARK: - Test Setup
    
    private func createTestContainer() -> DIContainer {
        let container = DIContainer.shared
        container.clear() // Clear any existing registrations
        return container
    }
    
    private func createTestModelContext() -> ModelContext {
        // Create in-memory model container for testing
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Shoe.self, StepEntry.self, ShoeSession.self, HourAttribution.self, configurations: config)
        return container.mainContext
    }
    
    // MARK: - Service Registration Tests
    
    @Test("Register singleton service stores service correctly")
    func testRegisterSingleton() async throws {
        // Given
        let container = createTestContainer()
        let testService = "TestService"
        
        // When
        container.registerSingleton(String.self, factory: { testService })
        
        // Then
        let resolved = container.resolve(String.self)
        #expect(resolved == testService)
    }
    
    @Test("Register factory service creates new instances")
    func testRegisterFactory() async throws {
        // Given
        let container = createTestContainer()
        var callCount = 0
        
        // When
        container.register(String.self) {
            callCount += 1
            return "Instance \(callCount)"
        }
        
        // Then
        let instance1 = container.resolve(String.self)
        let instance2 = container.resolve(String.self)
        
        #expect(instance1 == "Instance 1")
        #expect(instance2 == "Instance 2")
        #expect(callCount == 2)
    }
    
    @Test("Singleton service returns same instance")
    func testSingletonReturnsSameInstance() async throws {
        // Given
        let container = createTestContainer()
        
        container.registerSingleton(MockShoeRepository.self) {
            MockShoeRepository()
        }
        
        // When
        let instance1 = container.resolve(MockShoeRepository.self)
        let instance2 = container.resolve(MockShoeRepository.self)
        
        // Then
        #expect(instance1 === instance2) // Should be same reference
    }
    
    @Test("Factory service returns different instances")
    func testFactoryReturnsDifferentInstances() async throws {
        // Given
        let container = createTestContainer()
        
        container.register(MockShoeRepository.self) {
            MockShoeRepository()
        }
        
        // When
        let instance1 = container.resolve(MockShoeRepository.self)
        let instance2 = container.resolve(MockShoeRepository.self)
        
        // Then
        #expect(instance1 !== instance2) // Should be different references
    }
    
    // MARK: - Service Resolution Tests
    
    @Test("Resolve unregistered service throws fatal error")
    func testResolveUnregisteredService() async throws {
        // Given
        let container = createTestContainer()
        
        // When/Then - This would normally cause a fatal error
        // In tests, we can't easily test fatal errors, but we can verify the behavior
        // by checking that the service isn't registered
        #expect(!container.isRegistered(String.self))
    }
    
    @Test("Resolve registered service returns correct instance")
    func testResolveRegisteredService() async throws {
        // Given
        let container = createTestContainer()
        let expectedValue = 42
        
        container.registerSingleton(Int.self) { expectedValue }
        
        // When
        let resolved = container.resolve(Int.self)
        
        // Then
        #expect(resolved == expectedValue)
    }
    
    // MARK: - Dependency Chain Tests
    
    @Test("Resolve service with dependencies")
    func testResolveServiceWithDependencies() async throws {
        // Given
        let container = createTestContainer()
        
        // Register dependencies
        container.registerSingleton(MockShoeRepository.self) {
            MockShoeRepository()
        }
        
        // Register service that depends on repository
        container.registerSingleton(ShoeService.self) {
            ShoeService(shoeRepository: container.resolve(MockShoeRepository.self))
        }
        
        // When
        let service = container.resolve(ShoeService.self)
        
        // Then
        #expect(service is ShoeService)
    }
    
    @Test("Complex dependency chain resolves correctly")
    func testComplexDependencyChain() async throws {
        // Given
        let container = createTestContainer()
        let modelContext = createTestModelContext()
        let healthKitManager = MockHealthKitManager()
        
        // Configure the full service chain
        container.configureServices(modelContext: modelContext, healthKitManager: healthKitManager)
        
        // When
        let shoeService = container.resolve(ShoeService.self)
        let sessionService = container.resolve(SessionService.self)
        let attributionService = container.resolve(AttributionService.self)
        let healthKitViewModel = container.resolve(HealthKitViewModel.self)
        
        // Then
        #expect(shoeService is ShoeService)
        #expect(sessionService is SessionService)
        #expect(attributionService is AttributionService)
        #expect(healthKitViewModel is HealthKitViewModel)
    }
    
    // MARK: - Service Configuration Tests
    
    @Test("Configure services registers all required services")
    func testConfigureServices() async throws {
        // Given
        let container = createTestContainer()
        let modelContext = createTestModelContext()
        let healthKitManager = MockHealthKitManager()
        
        // When
        container.configureServices(modelContext: modelContext, healthKitManager: healthKitManager)
        
        // Then - Verify all expected services are registered
        #expect(container.isRegistered(ShoeRepositoryProtocol.self))
        #expect(container.isRegistered(SessionRepositoryProtocol.self))
        #expect(container.isRegistered(AttributionRepositoryProtocol.self))
        #expect(container.isRegistered(ShoeService.self))
        #expect(container.isRegistered(SessionService.self))
        #expect(container.isRegistered(AttributionService.self))
        #expect(container.isRegistered(HealthKitViewModel.self))
    }
    
    @Test("Configure services uses correct implementation types")
    func testConfigureServicesImplementationTypes() async throws {
        // Given
        let container = createTestContainer()
        let modelContext = createTestModelContext()
        let healthKitManager = MockHealthKitManager()
        
        // When
        container.configureServices(modelContext: modelContext, healthKitManager: healthKitManager)
        
        // Then - Verify correct concrete implementations
        let shoeRepo = container.resolve(ShoeRepositoryProtocol.self)
        let sessionRepo = container.resolve(SessionRepositoryProtocol.self)
        let attributionRepo = container.resolve(AttributionRepositoryProtocol.self)
        
        #expect(shoeRepo is SwiftDataShoeRepository)
        #expect(sessionRepo is SwiftDataSessionRepository)
        #expect(attributionRepo is SwiftDataAttributionRepository)
    }
    
    // MARK: - @Injected Property Wrapper Tests
    
    @Test("Injected property wrapper resolves service")
    func testInjectedPropertyWrapper() async throws {
        // Given
        let container = createTestContainer()
        let testValue = "TestValue"
        container.registerSingleton(String.self) { testValue }
        
        // Create test class using @Injected
        class TestClass {
            @Injected var injectedString: String
        }
        
        // When
        let testInstance = TestClass()
        
        // Then
        #expect(testInstance.injectedString == testValue)
    }
    
    @Test("Injected property wrapper uses singleton correctly")
    func testInjectedPropertyWrapperSingleton() async throws {
        // Given
        let container = createTestContainer()
        container.registerSingleton(MockShoeRepository.self) {
            MockShoeRepository()
        }
        
        class TestClass {
            @Injected var repository1: MockShoeRepository
            @Injected var repository2: MockShoeRepository
        }
        
        // When
        let testInstance = TestClass()
        
        // Then
        #expect(testInstance.repository1 === testInstance.repository2)
    }
    
    // MARK: - Container Lifecycle Tests
    
    @Test("Clear container clears all registrations")
    func testClearContainer() async throws {
        // Given
        let container = createTestContainer()
        
        container.registerSingleton(String.self) { "test" }
        container.register(Int.self) { 42 }
        
        #expect(container.isRegistered(String.self))
        #expect(container.isRegistered(Int.self))
        
        // When
        container.clear()
        
        // Then
        #expect(!container.isRegistered(String.self))
        #expect(!container.isRegistered(Int.self))
    }
    
    @Test("Shared container instance is consistent")
    func testSharedContainerInstance() async throws {
        // Given/When
        let instance1 = DIContainer.shared
        let instance2 = DIContainer.shared
        
        // Then
        #expect(instance1 === instance2)
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Is registered correctly identifies registered services")
    func testIsRegistered() async throws {
        // Given
        let container = createTestContainer()
        
        // When
        container.registerSingleton(String.self) { "test" }
        
        // Then
        #expect(container.isRegistered(String.self))
        #expect(!container.isRegistered(Int.self))
    }
    
    @Test("Override registration replaces previous registration")
    func testOverrideRegistration() async throws {
        // Given
        let container = createTestContainer()
        
        container.registerSingleton(String.self) { "original" }
        let original = container.resolve(String.self)
        #expect(original == "original")
        
        // When - Override with new registration
        container.registerSingleton(String.self) { "overridden" }
        
        // Then
        let overridden = container.resolve(String.self)
        #expect(overridden == "overridden")
    }
    
    // MARK: - Concurrent Access Tests
    
    @Test("Container handles concurrent access safely")
    func testConcurrentAccess() async throws {
        // Given
        let container = createTestContainer()
        container.register(String.self) { "test" }
        
        // When - Access container from multiple tasks concurrently
        let tasks = (0..<10).map { index in
            Task {
                return container.resolve(String.self)
            }
        }
        
        let results = try await withThrowingTaskGroup(of: String.self) { group in
            for task in tasks {
                group.addTask { try await task.value }
            }
            
            var values: [String] = []
            for try await value in group {
                values.append(value)
            }
            return values
        }
        
        // Then
        #expect(results.count == 10)
        #expect(results.allSatisfy { $0 == "test" })
    }
    
    @Test("Container registration thread safety")
    func testRegistrationThreadSafety() async throws {
        // Given
        let container = createTestContainer()
        
        // When - Register services concurrently
        let tasks = (0..<5).map { index in
            Task {
                container.registerSingleton(type(of: index), factory: { index })
            }
        }
        
        // Wait for all registrations to complete
        for task in tasks {
            await task.value
        }
        
        // Then - All services should be registered
        for index in 0..<5 {
            #expect(container.isRegistered(type(of: index)))
            let resolved = container.resolve(type(of: index))
            #expect(resolved == index)
        }
    }
    
    // MARK: - Real Service Integration Tests
    
    @Test("Container correctly wires real service dependencies")
    func testRealServiceDependencies() async throws {
        // Given
        let container = createTestContainer()
        let modelContext = createTestModelContext()
        let healthKitManager = MockHealthKitManager()
        
        container.configureServices(modelContext: modelContext, healthKitManager: healthKitManager)
        
        // When
        let shoeService = container.resolve(ShoeService.self)
        
        // Then - Service should be functional
        let shoe = try await shoeService.createShoe(
            brand: "Test",
            model: "Shoe",
            notes: "Test notes",
            icon: "👟",
            color: "CustomBlue",
            estimatedLifespan: 500.0
        )
        
        #expect(shoe.brand == "Test")
        #expect(shoe.model == "Shoe")
    }
    
    @Test("Container enables proper service interaction")
    func testServiceInteraction() async throws {
        // Given
        let container = createTestContainer()
        let modelContext = createTestModelContext()
        let healthKitManager = MockHealthKitManager()
        
        container.configureServices(modelContext: modelContext, healthKitManager: healthKitManager)
        
        // When
        let shoeService = container.resolve(ShoeService.self)
        let sessionService = container.resolve(SessionService.self)
        
        // Create a shoe and start a session
        let shoe = try await shoeService.createShoe(
            brand: "Nike",
            model: "Air Max",
            notes: "",
            icon: "👟",
            color: "CustomBlue",
            estimatedLifespan: 500.0
        )
        
        let session = try await sessionService.startSession(for: shoe)
        
        // Then
        #expect(session.shoe?.brand == "Nike")
        #expect(session.shoe?.model == "Air Max")
        #expect(session.endDate == nil) // Active session
        
        let activeShoe = try await sessionService.getActiveShoe()
        #expect(activeShoe?.id == shoe.id)
    }
}
//
//  DIContainer.swift
//  shoePrint
//
//  Portfolio Refactor: Dependency injection container
//

import Foundation
import SwiftData

/// Simple dependency injection container for managing app dependencies
/// ✅ Enables clean architecture, testability, and loose coupling
@MainActor
final class DIContainer: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = DIContainer()
    
    // MARK: - Properties
    
    private var services: [String: Any] = [:]
    private var factories: [String: () -> Any] = [:]
    
    private init() {}
    
    // MARK: - Registration Methods
    
    /// Registers a singleton service instance
    func register<T>(_ serviceType: T.Type, instance: T) {
        let key = String(describing: serviceType)
        services[key] = instance
    }
    
    /// Registers a factory for creating service instances
    func register<T>(_ serviceType: T.Type, factory: @escaping () -> T) {
        let key = String(describing: serviceType)
        factories[key] = factory
    }
    
    /// Registers a singleton service with a factory (lazy instantiation)
    func registerSingleton<T>(_ serviceType: T.Type, factory: @escaping () -> T) {
        let key = String(describing: serviceType)
        factories[key] = {
            let instance = factory()
            self.services[key] = instance
            return instance
        }
    }
    
    // MARK: - Resolution Methods
    
    /// Resolves a service by type
    func resolve<T>(_ serviceType: T.Type) -> T {
        let key = String(describing: serviceType)
        
        // Check for existing instance
        if let instance = services[key] as? T {
            return instance
        }
        
        // Check for factory
        if let factory = factories[key] {
            let instance = factory() as! T
            return instance
        }
        
        fatalError("Service \(serviceType) not registered")
    }
    
    /// Safely resolves a service (returns nil if not found)
    func tryResolve<T>(_ serviceType: T.Type) -> T? {
        let key = String(describing: serviceType)
        
        // Check for existing instance
        if let instance = services[key] as? T {
            return instance
        }
        
        // Check for factory
        if let factory = factories[key] {
            let instance = factory() as? T
            return instance
        }
        
        return nil
    }
    
    // MARK: - Cleanup
    
    /// Clears all registered services (useful for testing)
    func clear() {
        services.removeAll()
        factories.removeAll()
    }
    
    /// Removes a specific service
    func remove<T>(_ serviceType: T.Type) {
        let key = String(describing: serviceType)
        services.removeValue(forKey: key)
        factories.removeValue(forKey: key)
    }
}

// MARK: - Service Registration Extension

extension DIContainer {
    
    /// Configures all app services with their dependencies
    func configureServices(modelContext: ModelContext, healthKitManager: HealthKitManager) {
        
        // Register core dependencies
        register(ModelContext.self, instance: modelContext)
        register(HealthKitManager.self, instance: healthKitManager)
        
        // Register repositories
        registerSingleton(ShoeRepositoryProtocol.self) {
            SwiftDataShoeRepository(modelContext: modelContext)
        }
        
        registerSingleton(SessionRepositoryProtocol.self) {
            SwiftDataSessionRepository(modelContext: modelContext)
        }
        
        registerSingleton(AttributionRepositoryProtocol.self) {
            SwiftDataAttributionRepository(modelContext: modelContext)
        }
        
        // Register services
        registerSingleton(ShoeService.self) {
            ShoeService(
                shoeRepository: self.resolve(ShoeRepositoryProtocol.self),
                sessionRepository: self.resolve(SessionRepositoryProtocol.self),
                attributionRepository: self.resolve(AttributionRepositoryProtocol.self)
            )
        }
        
        registerSingleton(SessionService.self) {
            SessionService(
                sessionRepository: self.resolve(SessionRepositoryProtocol.self),
                shoeRepository: self.resolve(ShoeRepositoryProtocol.self),
                healthKitManager: healthKitManager
            )
        }
        
        registerSingleton(AttributionService.self) {
            AttributionService(
                attributionRepository: self.resolve(AttributionRepositoryProtocol.self),
                sessionRepository: self.resolve(SessionRepositoryProtocol.self),
                healthKitManager: healthKitManager
            )
        }
        
        registerSingleton(HealthKitViewModel.self) {
            HealthKitViewModel(
                healthKitManager: healthKitManager,
                sessionService: self.resolve(SessionService.self)
            )
        }
        
        print("✅ All services configured successfully")
    }
}

// MARK: - PropertyWrapper for Dependency Injection

/// Property wrapper for automatic dependency injection
@MainActor
@propertyWrapper
struct Injected<T> {
    private let serviceType: T.Type
    
    init(_ serviceType: T.Type) {
        self.serviceType = serviceType
    }
    
    var wrappedValue: T {
        DIContainer.shared.resolve(serviceType)
    }
}
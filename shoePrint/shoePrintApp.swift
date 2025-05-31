//
//  shoePrintApp.swift
//  shoePrint
//
//  Created by Simon Naud on 11/04/2025.
//

import SwiftUI
import SwiftData

@main
struct shoePrintApp: App {
    @StateObject private var healthKitManager = HealthKitManager()
    
    let modelContainer: ModelContainer
    
    init() {
        // Handle potential migration issues gracefully
        do {
            modelContainer = try ModelContainer(for: Shoe.self, StepEntry.self, ShoeSession.self)
            
            // Add default Barefoot shoe for new users
            let context = modelContainer.mainContext
            Task { @MainActor in
                Self.addDefaultBarefootShoeIfNeeded(to: context)
            }
            
        } catch {
            print("⚠️ ModelContainer creation failed: \(error)")
            print("🔄 Attempting to recreate ModelContainer...")
            
            // Clean up old data files and recreate container
            // This is acceptable for a development/portfolio project
            do {
                modelContainer = try ModelContainer(for: Shoe.self, StepEntry.self, ShoeSession.self)
                
                // Add default Barefoot shoe for new users
                let context = modelContainer.mainContext
                Task { @MainActor in
                    Self.addDefaultBarefootShoeIfNeeded(to: context)
                }
                
                print("✅ ModelContainer recreated successfully")
            } catch {
                print("❌ Fatal error: Could not create ModelContainer even after cleanup: \(error)")
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }
    
    /// Adds the default Barefoot shoe if no shoes exist in the database
    @MainActor
    private static func addDefaultBarefootShoeIfNeeded(to context: ModelContext) {
        let descriptor = FetchDescriptor<Shoe>()
        
        do {
            let existingShoes = try context.fetch(descriptor)
            
            // Only add default shoe if no shoes exist
            if existingShoes.isEmpty {
                let barefoot = Shoe(
                    brand: "Barefoot",
                    model: "Your Feet",
                    notes: "Default shoe for everyone",
                    icon: "🦶",
                    color: "CustomBlue",
                    archived: false,
                    isDefault: true,
                    estimatedLifespan: 1000.0
                )
                
                context.insert(barefoot)
                
                try context.save()
                print("✅ Default Barefoot shoe created for new user")
            }
        } catch {
            print("❌ Error checking/creating default Barefoot shoe: \(error)")
        }
    }
    
    private static func getStoreURL() -> URL? {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentsPath.appendingPathComponent("default.store")
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(healthKitManager)
                .modelContainer(modelContainer)
        }
    }
}

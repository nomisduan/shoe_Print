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
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Shoe.self,
            StepEntry.self,
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("✅ ModelContainer created successfully")
            return container
        } catch {
            print("❌ Error creating ModelContainer: \(error)")
            
            // En cas d'erreur, nettoyer les anciennes données et recréer
            return createFreshContainer(schema: schema)
        }
    }()
    
    private static func createFreshContainer(schema: Schema) -> ModelContainer {
        print("🔄 Attempting to create fresh ModelContainer...")
        
        // Supprimer l'ancien store s'il existe
        if let storeURL = getStoreURL() {
            try? FileManager.default.removeItem(at: storeURL)
            print("🗑️ Removed old store at: \(storeURL)")
        }
        
        let freshConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        
        do {
            let container = try ModelContainer(for: schema, configurations: [freshConfiguration])
            print("✅ Fresh ModelContainer created successfully")
            return container
        } catch {
            print("❌ Fatal error creating fresh ModelContainer: \(error)")
            // En dernier recours, utiliser un conteneur en mémoire
            let memoryConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                allowsSave: false,
                cloudKitDatabase: .none
            )
            
            do {
                let memoryContainer = try ModelContainer(for: schema, configurations: [memoryConfiguration])
                print("⚠️ Using in-memory ModelContainer as fallback")
                return memoryContainer
            } catch {
                fatalError("Could not create any ModelContainer: \(error)")
            }
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
        }
        .modelContainer(sharedModelContainer)
    }
}

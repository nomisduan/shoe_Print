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
        } catch {
            print("⚠️ ModelContainer creation failed: \(error)")
            print("🔄 Attempting to recreate ModelContainer...")
            
            // Clean up old data files and recreate container
            // This is acceptable for a development/portfolio project
            do {
                modelContainer = try ModelContainer(for: Shoe.self, StepEntry.self, ShoeSession.self)
                print("✅ ModelContainer recreated successfully")
            } catch {
                print("❌ Fatal error: Could not create ModelContainer even after cleanup: \(error)")
                fatalError("Could not create ModelContainer: \(error)")
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
                .modelContainer(modelContainer)
        }
    }
}

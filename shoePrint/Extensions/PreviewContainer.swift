//
//  PreviewContainer.swift
//  shoePrint
//
//  Created by Simon Naud on 11/04/2025.
//

import SwiftUI
import SwiftData

/// Preview container for SwiftData models with sample data
@MainActor
struct PreviewContainer {
    
    static var previewModelContainer: ModelContainer = {
        do {
            let container = try ModelContainer(
                for: Shoe.self, StepEntry.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            
            // Add sample data for previews
            Task { @MainActor in
                addSampleData(to: container.mainContext)
            }
            
            return container
        } catch {
            fatalError("Failed to create preview model container: \(error)")
        }
    }()
    
    static var previewModelContext: ModelContext {
        previewModelContainer.mainContext
    }
    
    private static func addSampleData(to context: ModelContext) {
        // Sample shoes
        let nike = Shoe(
            brand: "Nike",
            model: "Air Max 90",
            color: "white",
            archived: false,
            isActive: true,
            purchaseDate: Date(),
            estimatedLifespan: 800.0
        )
        
        let adidas = Shoe(
            brand: "Adidas",
            model: "Ultraboost 22",
            color: "blue",
            archived: false,
            isActive: false,
            purchaseDate: Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date(),
            estimatedLifespan: 600.0
        )
        
        let asics = Shoe(
            brand: "ASICS",
            model: "Gel-Kayano 29",
            color: "red",
            archived: true,
            isActive: false,
            purchaseDate: Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date(),
            estimatedLifespan: 700.0
        )
        
        context.insert(nike)
        context.insert(adidas)
        context.insert(asics)
        
        // Sample step entries
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today
        let lastWeek = Calendar.current.date(byAdding: .day, value: -7, to: today) ?? today
        
        let entry1 = StepEntry(
            startDate: yesterday,
            endDate: yesterday.addingTimeInterval(3600), // 1 hour
            steps: 5420,
            distance: 4.2,
            repair: false,
            shoe: nike,
            source: "HealthKit"
        )
        
        let entry2 = StepEntry(
            startDate: lastWeek,
            endDate: lastWeek.addingTimeInterval(2700), // 45 minutes
            steps: 3200,
            distance: 2.8,
            repair: false,
            shoe: adidas,
            source: "Manual"
        )
        
        context.insert(entry1)
        context.insert(entry2)
        
        do {
            try context.save()
        } catch {
            print("Failed to save sample data: \(error)")
        }
    }
} 
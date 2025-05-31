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
                for: Shoe.self, StepEntry.self, ShoeSession.self,
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
        // Default Barefoot shoe for all users
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
        
        // Sample step entries - create these first
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today
        let lastWeek = Calendar.current.date(byAdding: .day, value: -7, to: today) ?? today
        
        let entry1 = StepEntry(
            startDate: yesterday,
            endDate: yesterday.addingTimeInterval(3600), // 1 hour
            steps: 5420,
            distance: 4.2,
            repair: false,
            source: "HealthKit"
        )
        
        let entry2 = StepEntry(
            startDate: lastWeek,
            endDate: lastWeek.addingTimeInterval(2700), // 45 minutes
            steps: 3200,
            distance: 2.8,
            repair: false,
            source: "Manual"
        )
        
        let entry3 = StepEntry(
            startDate: today.addingTimeInterval(-7200), // 2 hours ago
            endDate: today.addingTimeInterval(-5400), // 1.5 hours ago
            steps: 2100,
            distance: 1.8,
            repair: false,
            source: "HealthKit"
        )
        
        let entry4 = StepEntry(
            startDate: yesterday.addingTimeInterval(-3600), // Yesterday, 1 hour earlier
            endDate: yesterday.addingTimeInterval(-1800), // Yesterday, 30 min earlier
            steps: 1800,
            distance: 1.5,
            repair: false,
            source: "HealthKit"
        )
        
        let entry5 = StepEntry(
            startDate: lastWeek.addingTimeInterval(3600), // Last week, 1 hour later
            endDate: lastWeek.addingTimeInterval(5400), // Last week, 1.5 hours later
            steps: 4500,
            distance: 3.8,
            repair: false,
            source: "Manual"
        )
        
        let entry6 = StepEntry(
            startDate: today.addingTimeInterval(-14400), // 4 hours ago
            endDate: today.addingTimeInterval(-10800), // 3 hours ago
            steps: 800,
            distance: 0.6,
            repair: false,
            source: "HealthKit"
        )
        
        // Sample shoes - use the entries created above
        let nike = Shoe(
            brand: "Nike",
            model: "Air Max 90",
            icon: "👟",
            color: "CustomBlue",
            entries: [entry1, entry2, entry3]
        )
        
        let adidas = Shoe(
            brand: "Adidas",
            model: "Ultraboost 22",
            icon: "🏃‍♂️",
            color: "CustomGreen",
            entries: [entry4, entry5]
        )
        
        let asics = Shoe(
            brand: "ASICS",
            model: "Gel-Kayano 29",
            icon: "⭐",
            color: "CustomRed",
            entries: [entry6]
        )
        
        // Set the shoe relationships for entries
        entry1.shoe = nike
        entry2.shoe = nike
        entry3.shoe = nike
        entry4.shoe = adidas
        entry5.shoe = adidas
        entry6.shoe = asics
        
        // Insert everything into context - Barefoot first so it's the default
        context.insert(barefoot)
        context.insert(nike)
        context.insert(adidas)
        context.insert(asics)
        context.insert(entry1)
        context.insert(entry2)
        context.insert(entry3)
        context.insert(entry4)
        context.insert(entry5)
        context.insert(entry6)
        
        do {
            try context.save()
        } catch {
            print("Failed to save sample data: \(error)")
        }
    }
} 
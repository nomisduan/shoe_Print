//
//  HourlyAttributionService.swift
//  shoePrint
//
//  Created by Simon Naud on 11/04/2025.
//

import Foundation
import SwiftData

/// Service responsible for handling hourly step attributions from HealthKit data
/// Manages the attribution of specific hours to shoes and persists them as StepEntries
@MainActor
final class HourlyAttributionService: ObservableObject {
    
    // MARK: - Properties
    
    private let modelContext: ModelContext
    
    @Published var isProcessing = false
    @Published var savedAttributions: [String: Shoe] = [:] // hour key -> shoe mapping
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadExistingAttributions()
    }
    
    // MARK: - Attribution Methods
    
    /// Processes hourly data and applies automatic attribution where possible
    /// - Parameter hourlyData: Array of unattributed hourly step data to process
    /// - Returns: Array of processed hourly data with automatic attributions applied
    func processHourlyDataWithAutoAttribution(_ hourlyData: [HourlyStepData]) async -> [HourlyStepData] {
        var processedData = hourlyData
        
        // Get active shoes for automatic attribution
        let activeShoes = await getActiveShoes()
        
        // Only auto-attribute if there's exactly one active shoe
        guard activeShoes.count == 1, let activeShoe = activeShoes.first else {
            print("📊 HourlyAttributionService: \(activeShoes.count) active shoes found - no automatic attribution")
            return processedData
        }
        
        print("🤖 Auto-attributing \(hourlyData.count) hours to: \(activeShoe.brand) \(activeShoe.model)")
        
        // Apply automatic attribution to all provided data
        for i in 0..<processedData.count {
            if processedData[i].assignedShoe == nil {
                // Create and save StepEntry for this hour
                await attributeHourToShoe(processedData[i], to: activeShoe)
                
                // Update the local data structure
                processedData[i].assignedShoe = activeShoe
                print("✅ Auto-attributed \(processedData[i].timeString): \(processedData[i].steps) steps")
            }
        }
        
        return processedData
    }
    
    /// Attributes steps from a specific hour to a shoe
    /// - Parameters:
    ///   - hourData: The hourly step data to attribute
    ///   - shoe: The shoe to attribute the steps to
    func attributeHourToShoe(_ hourData: HourlyStepData, to shoe: Shoe) async {
        isProcessing = true
        
        // Create start and end dates for the hour
        let calendar = Calendar.current
        let startDate = calendar.date(bySettingHour: hourData.hour, minute: 0, second: 0, of: hourData.date) ?? hourData.date
        let endDate = calendar.date(byAdding: .hour, value: 1, to: startDate) ?? startDate
        
        // Check if an entry already exists for this hour
        let existingEntry = await findExistingEntry(for: startDate, endDate: endDate)
        
        if let existing = existingEntry {
            // Update existing entry
            existing.shoe = shoe
            existing.steps = hourData.steps
            print("🔄 Updated existing hourly entry for \(hourData.timeString) - \(shoe.brand) \(shoe.model)")
        } else {
            // Create new entry
            let stepEntry = StepEntry(
                startDate: startDate,
                endDate: endDate,
                steps: hourData.steps,
                distance: estimateDistance(from: hourData.steps),
                repair: false,
                shoe: shoe,
                source: "hourly"
            )
            
            modelContext.insert(stepEntry)
            print("➕ Created new hourly entry for \(hourData.timeString) - \(shoe.brand) \(shoe.model)")
        }
        
        // Save the attribution mapping
        let hourKey = createHourKey(for: hourData)
        savedAttributions[hourKey] = shoe
        
        do {
            try modelContext.save()
            print("✅ Successfully saved hourly attribution")
        } catch {
            print("❌ Failed to save hourly attribution: \(error)")
        }
        
        isProcessing = false
    }
    
    /// Removes attribution for a specific hour
    /// - Parameter hourData: The hourly data to remove attribution for
    func removeAttributionForHour(_ hourData: HourlyStepData) async {
        isProcessing = true
        
        let calendar = Calendar.current
        let startDate = calendar.date(bySettingHour: hourData.hour, minute: 0, second: 0, of: hourData.date) ?? hourData.date
        let endDate = calendar.date(byAdding: .hour, value: 1, to: startDate) ?? startDate
        
        if let existingEntry = await findExistingEntry(for: startDate, endDate: endDate) {
            modelContext.delete(existingEntry)
            
            let hourKey = createHourKey(for: hourData)
            savedAttributions.removeValue(forKey: hourKey)
            
            do {
                try modelContext.save()
                print("🗑️ Removed hourly attribution for \(hourData.timeString)")
            } catch {
                print("❌ Failed to remove hourly attribution: \(error)")
            }
        }
        
        isProcessing = false
    }
    
    /// Gets the attributed shoe for a specific hour, if any
    /// - Parameter hourData: The hourly data to check
    /// - Returns: The attributed shoe, or nil if no attribution exists
    func getAttributedShoe(for hourData: HourlyStepData) -> Shoe? {
        let hourKey = createHourKey(for: hourData)
        return savedAttributions[hourKey]
    }
    
    /// Checks if a specific hour has been attributed
    /// - Parameter hourData: The hourly data to check
    /// - Returns: True if the hour has been attributed to a shoe
    func isHourAttributed(_ hourData: HourlyStepData) -> Bool {
        getAttributedShoe(for: hourData) != nil
    }
    
    // MARK: - Private Methods
    
    /// Fetches currently active shoes
    private func getActiveShoes() async -> [Shoe] {
        let descriptor = FetchDescriptor<Shoe>(
            predicate: #Predicate<Shoe> { shoe in
                shoe.isActive && !shoe.archived
            }
        )
        
        do {
            let activeShoes = try modelContext.fetch(descriptor)
            return activeShoes
        } catch {
            print("❌ Error fetching active shoes: \(error)")
            return []
        }
    }
    
    /// Loads existing hourly attributions from the database
    private func loadExistingAttributions() {
        let descriptor = FetchDescriptor<StepEntry>(
            predicate: #Predicate<StepEntry> { entry in
                entry.source == "hourly"
            }
        )
        
        do {
            let hourlyEntries = try modelContext.fetch(descriptor)
            
            for entry in hourlyEntries {
                if let shoe = entry.shoe {
                    let hourKey = createHourKey(from: entry.startDate)
                    savedAttributions[hourKey] = shoe
                }
            }
            
            print("📚 Loaded \(savedAttributions.count) existing hourly attributions")
        } catch {
            print("❌ Error loading existing attributions: \(error)")
        }
    }
    
    /// Finds an existing StepEntry for the specified time range
    private func findExistingEntry(for startDate: Date, endDate: Date) async -> StepEntry? {
        let descriptor = FetchDescriptor<StepEntry>(
            predicate: #Predicate<StepEntry> { entry in
                entry.source == "hourly" && 
                entry.startDate == startDate &&
                entry.endDate == endDate
            }
        )
        
        do {
            let entries = try modelContext.fetch(descriptor)
            return entries.first
        } catch {
            print("❌ Error finding existing entry: \(error)")
            return nil
        }
    }
    
    /// Creates a unique key for an hour attribution
    private func createHourKey(for hourData: HourlyStepData) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH"
        return formatter.string(from: hourData.date)
    }
    
    /// Creates a unique key from a date
    private func createHourKey(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH"
        return formatter.string(from: date)
    }
    
    /// Estimates distance from step count
    private func estimateDistance(from steps: Int) -> Double {
        // Average step length is approximately 0.762 meters
        let distanceInMeters = Double(steps) * 0.762
        return distanceInMeters / 1000.0 // Convert to kilometers
    }
} 
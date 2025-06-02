//
//  ShoeGridView.swift
//  shoePrint
//
//  Created by Simon Naud on 11/04/2025.
//

import SwiftUI
import SwiftData

struct ShoeGridView: View {
    @Query private var shoes: [Shoe]
    @Environment(\.modelContext) private var modelContext
    
    @Binding var shoeToDelete: Shoe?
    @Binding var showDeleteAlert: Bool
    
    @Binding var shoeToArchive: Shoe?
    @Binding var showArchiveAlert: Bool
    
    @Binding var shoeToEdit: Shoe?
    @Binding var showEditSheet: Bool
    
    let healthKitViewModel: HealthKitViewModel?
    
    @State private var showStepsInHeader = false // false = show distance, true = show steps
    @State private var yearToDateSteps = 0
    @State private var yearToDateDistance = 0.0
   
    let columns = [
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20)
    ]
    
    // Computed properties for statistics
    private var activeShoes: [Shoe] {
        shoes.filter { !$0.archived }
    }
    
    private var totalRepairs: Int {
        return activeShoes.reduce(0) { total, shoe in
            total + shoe.entries.filter { $0.repair }.count
        }
    }
    
    var body: some View {
        ScrollView {
            VStack {
                HStack{
                    VStack(alignment: .leading){
                        HStack{
                            Image(systemName: "shoe.2.fill")
                                .foregroundStyle(.yellow)
                            Text("\(activeShoes.count)")
                                .fontWeight(.semibold)
                                .fontDesign(.monospaced)
                        }
                        Text("Footwears")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Divider()
                    VStack(alignment: .leading){
                        HStack{
                            Image(systemName: showStepsInHeader ? "shoeprints.fill" : "figure.walk")
                                .foregroundStyle(showStepsInHeader ? .green : .blue)
                            if showStepsInHeader {
                                Text(yearToDateSteps.formattedCompactSteps)
                                    .fontWeight(.semibold)
                                    .fontDesign(.monospaced)
                                    .foregroundColor(.primary)
                            } else {
                                Text(yearToDateDistance.formattedDistance)
                                    .fontWeight(.semibold)
                                    .fontDesign(.monospaced)
                                    .foregroundColor(.primary)
                            }
                        }
                        
                        Text(showStepsInHeader ? "Steps this year" : "Kilometers this year")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Divider()
                    VStack(alignment: .leading){
                        HStack{
                            Image(systemName: "wrench.and.screwdriver.fill")
                                .foregroundStyle(.purple)
                            Text("\(totalRepairs)")
                                .fontWeight(.semibold)
                                .fontDesign(.monospaced)
                        }
                        Text("Repairs")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .frame(height: 50)
              
            LazyVGrid(columns: columns, spacing: 15) {
                ForEach(activeShoes) { shoe in
                    ShoeCardView(
                        shoe: shoe,
                        onDelete: {
                            shoeToDelete = shoe
                            showDeleteAlert = true
                        },
                        onArchive: {
                            shoeToArchive = shoe
                            showArchiveAlert = true
                        },
                        onEdit: {
                            shoeToEdit = shoe
                            showEditSheet = true
                        }
                    )
                    .id("\(shoe.id)-\(shoe.isActive ? "active" : "inactive")") // Force view refresh
                }
            }
            }
            .padding(.horizontal)
        }
        .onAppear {
            // Debug: Vérifier le chargement des données persistées
            print("🔍 ShoeGridView onAppear - Loaded \(shoes.count) shoes total")
            let activeCount = shoes.filter { !$0.archived }.count
            let archivedCount = shoes.filter { $0.archived }.count
            print("📊 Active shoes: \(activeCount), Archived shoes: \(archivedCount)")
            
            for shoe in shoes.prefix(3) { // Afficher les 3 premières pour debug
                print("👟 \(shoe.brand) \(shoe.model) - Active: \(shoe.isActive), Archived: \(shoe.archived)")
                // ✅ Computed properties now update automatically - no manual refresh needed
            }
            
            // Load HealthKit year-to-date totals
            Task {
                await loadYearToDateTotals()
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Loads year-to-date totals from HealthKit
    private func loadYearToDateTotals() async {
        guard let viewModel = healthKitViewModel else {
            print("⚠️ No HealthKitViewModel available for year-to-date totals")
            return
        }
        
        let totals = await viewModel.fetchYearToDateTotals()
        
        await MainActor.run {
            yearToDateSteps = totals.steps
            yearToDateDistance = totals.distance
            print("📊 Loaded year-to-date totals: \(yearToDateSteps.formattedSteps) steps, \(yearToDateDistance.formattedDistance) km")
        }
    }
}



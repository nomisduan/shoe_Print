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
   
    let columns = [
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20)
    ]
    
    // Computed properties for statistics
    private var activeShoes: [Shoe] {
        shoes.filter { !$0.archived }
    }
    
    private var totalKilometersThisYear: Double {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let startOfYear = calendar.date(from: DateComponents(year: currentYear, month: 1, day: 1)) ?? Date()
        let endOfYear = calendar.date(from: DateComponents(year: currentYear + 1, month: 1, day: 1)) ?? Date()
        
        return shoes.reduce(0) { total, shoe in
            // Calculate distance from sessions in this year for ALL shoes (including archived)
            let yearSessions = shoe.sessions.filter { session in
                session.startDate >= startOfYear && session.startDate < endOfYear
            }
            
            // Use real stored distance data from sessions
            let yearlyDistance = yearSessions.reduce(0) { sessionTotal, session in
                return sessionTotal + session.distance
            }
            
            return total + yearlyDistance
        }
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
                        }
                        Text("Footwears")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Divider()
                    VStack(alignment: .leading){
                        HStack{
                            Image(systemName: "shoeprints.fill")
                                .foregroundStyle(.green)
                            Text(String(format: "%.1f", totalKilometersThisYear))
                                .fontWeight(.semibold)
                        }
                        Text("Kilometers this year")
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
                // Force refresh distance after relationships are loaded
                shoe.refreshAfterRelationshipsLoaded()
            }
        }
    }
}



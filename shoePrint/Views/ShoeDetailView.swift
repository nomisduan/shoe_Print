//
//  ShoeDetailView.swift
//  shoePrint
//
//  Created by Simon Naud on 31/05/2025.
//

import SwiftUI
import SwiftData

struct ShoeDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    let shoe: Shoe
    @State private var showingEditSheet = false
    
    // Gestion des unités selon les réglages locaux
    private var distanceUnit: String {
        let formatter = MeasurementFormatter()
        let measurement = Measurement(value: 1000, unit: UnitLength.meters)
        let formatted = formatter.string(from: measurement)
        return formatted.contains("mi") ? "mi" : "km"
    }
    
    private func formatDistance(_ distanceInKm: Double) -> String {
        let distanceInMeters = distanceInKm * 1000
        let measurement = Measurement(value: distanceInMeters, unit: UnitLength.meters)
        
        let formatter = MeasurementFormatter()
        formatter.unitStyle = .short
        formatter.numberFormatter.maximumFractionDigits = 1
        
        if distanceUnit == "mi" {
            let milesValue = measurement.converted(to: .miles).value
            return String(format: "%.1f mi", milesValue)
        } else {
            return String(format: "%.0f km", distanceInKm)
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header avec rounded rectangle full width
                HStack(spacing: 16) {
                    Text(shoe.icon)
                        .font(.system(size: 80))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(shoe.brand.uppercased())
                            .font(.title2)
                            .fontWeight(.black)
                            .italic()
                        Text(shoe.model)
                            .font(.title3)
                            .foregroundColor(.secondary)
                        
                        if shoe.isActive {
                            HStack {
                                Image(systemName: "circle.fill")
                                    .foregroundColor(.green)
                                Text("Wearing")
                                    .fontWeight(.medium)
                            }
                            .padding(.top, 4)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(shoe.color))
                .cornerRadius(16)
                
                // Statistiques principales - 4 rectangles égaux
                VStack(spacing: 16) {
                    Text("Statistics")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            StatCard(
                                title: "Total Distance",
                                value: formatDistance(shoe.totalDistance),
                                icon: "figure.walk",
                                color: .blue
                            )
                            
                            StatCard(
                                title: "Total Steps",
                                value: "\(shoe.totalSteps)",
                                icon: "shoeprints.fill",
                                color: .green
                            )
                        }
                        
                        HStack(spacing: 12) {
                            StatCard(
                                title: "Usage Days",
                                value: "\(shoe.usageDays)",
                                icon: "calendar",
                                color: .orange
                            )
                            
                            StatCard(
                                title: "Repairs",
                                value: "\(shoe.totalRepairs)",
                                icon: "wrench.and.screwdriver.fill",
                                color: .purple
                            )
                        }
                    }
                }
                
                // Progression de durée de vie
                VStack(spacing: 12) {
                    Text("Lifespan Progress")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(spacing: 8) {
                        HStack {
                            Text(formatDistance(shoe.totalDistance))
                            Spacer()
                            Text(formatDistance(shoe.estimatedLifespan))
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        
                        ProgressView(value: shoe.lifespanProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: shoe.lifespanProgress > 0.8 ? .red : .blue))
                        
                        Text("\(Int(shoe.lifespanProgress * 100))% of estimated lifespan")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                }
                
                // Informations d'achat
                if shoe.purchaseDate != nil || shoe.purchasePrice != nil {
                    VStack(spacing: 12) {
                        Text("Purchase Information")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        VStack(spacing: 8) {
                            if let purchaseDate = shoe.purchaseDate {
                                HStack {
                                    Text("Purchase Date:")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(purchaseDate.formatted(date: .abbreviated, time: .omitted))
                                }
                            }
                            
                            if let purchasePrice = shoe.purchasePrice {
                                HStack {
                                    Text("Purchase Price:")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(String(format: "%.2f €", purchasePrice))
                                }
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                
                // Notes
                if !shoe.notes.isEmpty {
                    VStack(spacing: 12) {
                        Text("Notes")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text(shoe.notes)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                    }
                }
                
                // Actions
                VStack(spacing: 12) {
                    Button(action: {
                        shoe.setActive(!shoe.isActive, in: context)
                    }) {
                        HStack {
                            Image(systemName: shoe.isActive ? "pause.circle.fill" : "play.circle.fill")
                            Text(shoe.isActive ? "Stop Wearing" : "Start Wearing")
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(shoe.isActive ? Color.red : Color.green)
                        .cornerRadius(12)
                    }
                    
                    Button(action: {
                        // Ajouter une réparation
                        let repairEntry = StepEntry(
                            startDate: Date(),
                            endDate: Date(),
                            steps: 0,
                            distance: 0.0,
                            repair: true,
                            shoe: shoe,
                            source: "manual"
                        )
                        context.insert(repairEntry)
                        try? context.save()
                    }) {
                        HStack {
                            Image(systemName: "wrench.and.screwdriver.fill")
                            Text("Add Repair")
                        }
                        .foregroundColor(.purple)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            showingEditSheet = true
                        }) {
                            HStack {
                                Image(systemName: "pencil")
                                Text("Edit Shoe")
                            }
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                        }
                        
                        Button(action: {
                            shoe.archive()
                            try? context.save()
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "archivebox")
                                Text("Archive")
                            }
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Shoe Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEditSheet) {
            EditPairView(shoeToEdit: shoe)
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    NavigationView {
        ShoeDetailView(shoe: Shoe(brand: "Nike", model: "Air Max", icon: "👟", color: "CustomBlue"))
    }
} 
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
    
    private func formatDistance(_ distanceKm: Double) -> (value: String, unit: String) {
        let formatter = MeasurementFormatter()
        let testMeasurement = Measurement(value: 1000, unit: UnitLength.meters)
        let testFormatted = formatter.string(from: testMeasurement)
        let preferredUnit = testFormatted.contains("mi") ? "mi" : "km"
        
        if preferredUnit == "mi" {
            let miles = distanceKm * 0.621371
            return (value: miles.formattedDistance, unit: "mi")
        } else {
            return (value: distanceKm.formattedDistance, unit: "km")
        }
    }
    
    private func formatSteps(_ steps: Int) -> (value: String, unit: String) {
        return (value: steps.formattedSteps, unit: "steps")
    }
    
    private func formatWearTime(_ totalHours: Double) -> (value: String, unit: String) {
        if totalHours < 1 {
            let minutes = Int(totalHours * 60)
            return (value: "\(minutes)", unit: "min")
        } else if totalHours < 24 {
            return (value: String(format: "%.1f", totalHours), unit: "hours")
        } else {
            let days = Int(totalHours / 24)
            let remainingHours = Int(totalHours.truncatingRemainder(dividingBy: 24))
            if remainingHours > 0 {
                return (value: "\(days).\(remainingHours)", unit: "days")
            } else {
                return (value: "\(days)", unit: "days")
            }
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
                            WearingIndicatorDetail()
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
                            let distanceData = formatDistance(shoe.totalDistance)
                            StatCard(
                                title: "Total Distance",
                                value: distanceData.value,
                                unit: distanceData.unit,
                                icon: "figure.walk",
                                color: .blue
                            )
                            
                            let stepsData = formatSteps(shoe.totalSteps)
                            StatCard(
                                title: "Total Steps",
                                value: stepsData.value,
                                unit: stepsData.unit,
                                icon: "shoeprints.fill",
                                color: .green
                            )
                        }
                        
                        HStack(spacing: 12) {
                            let wearTimeData = formatWearTime(shoe.totalWearTimeHours)
                            StatCard(
                                title: "Wear Time",
                                value: wearTimeData.value,
                                unit: wearTimeData.unit,
                                icon: "clock.fill",
                                color: .mint
                            )
                            
                            StatCard(
                                title: "Repairs",
                                value: "\(shoe.totalRepairs)",
                                unit: "repairs",
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
                            let currentDistance = formatDistance(shoe.totalDistance)
                            let maxDistance = formatDistance(shoe.estimatedLifespan)
                            Text("\(currentDistance.value) \(currentDistance.unit)")
                            Spacer()
                            Text("\(maxDistance.value) \(maxDistance.unit)")
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
                    .background(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1.5)
                    )
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
                        Task {
                            let sessionService = ShoeSessionService(modelContext: context, healthKitManager: HealthKitManager())
                            await sessionService.toggleSession(for: shoe)
                        }
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
                        shoe.setDefault(!shoe.isDefault, in: context)
                    }) {
                        HStack {
                            Image(systemName: shoe.isDefault ? "star.fill" : "star")
                            Text(shoe.isDefault ? "Remove as Default" : "Set as Default")
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(shoe.isDefault ? Color.orange : Color.blue)
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
                        .disabled(shoe.brand.lowercased() == "barefoot")
                        .opacity(shoe.brand.lowercased() == "barefoot" ? 0.5 : 1.0)
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
    let unit: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            // Icon and title in the same HStack
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.headline) // Reduced from .title2 to .headline
                    .foregroundColor(color)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            // Value and unit aligned leading
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontDesign(.monospaced) // Monospaced font for values
                    .foregroundColor(.primary)
                
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary) // Grayed out unit
                
                Spacer() // Push to leading
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.clear) // No background color
        .overlay(
            RoundedRectangle(cornerRadius: 20) // Increased corner radius
                .stroke(Color.gray.opacity(0.3), lineWidth: 1.5) // Increased stroke thickness from 1 to 1.5
        )
    }
}

/// Detail view animated wearing indicator with pulse effect
struct WearingIndicatorDetail: View {
    @State private var isPulsing = false
    
    var body: some View {
        HStack {
            Image(systemName: "circle.fill")
                .foregroundColor(.green)
                .scaleEffect(isPulsing ? 1.2 : 1.0)
                .opacity(isPulsing ? 0.6 : 1.0)
                .animation(
                    Animation.easeInOut(duration: 1.0)
                        .repeatForever(autoreverses: true),
                    value: isPulsing
                )
            Text("Wearing")
                .fontWeight(.medium)
        }
        .onAppear {
            isPulsing = true
        }
    }
}

#Preview {
    NavigationView {
        ShoeDetailView(shoe: Shoe(brand: "Nike", model: "Air Max", icon: "👟", color: "CustomBlue"))
    }
} 
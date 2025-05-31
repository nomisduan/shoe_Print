//
//  ShoeCardView.swift
//  shoePrint
//
//  Created by Simon Naud on 11/04/2025.
//

import SwiftUI
import SwiftData

struct ShoeCardView: View {
    let shoe : Shoe
    var onDelete: () -> Void = {}
    var onArchive: () -> Void = {}
    var onEdit: () -> Void = {}
    
    @Environment(\.modelContext) private var context
    @State private var showingDetailSheet = false
    @State private var isPressed = false
    @State private var isLongPressing = false
    
    // Gestion des unités selon les réglages locaux
    private var distanceUnit: String {
        let formatter = MeasurementFormatter()
        let measurement = Measurement(value: 1000, unit: UnitLength.meters)
        let formatted = formatter.string(from: measurement)
        return formatted.contains("mi") ? "mi" : "km"
    }
    
    private var formattedDistance: String {
        let distanceInMeters = shoe.totalDistance * 1000 // shoe.totalDistance est en km
        let measurement = Measurement(value: distanceInMeters, unit: UnitLength.meters)
        
        let formatter = MeasurementFormatter()
        formatter.unitStyle = .short
        formatter.numberFormatter.maximumFractionDigits = 0
        
        // Convertir vers l'unité appropriée selon les réglages
        if distanceUnit == "mi" {
            let milesValue = measurement.converted(to: .miles).value
            return String(format: "%.0f", milesValue)
        } else {
            let kmValue = measurement.converted(to: .kilometers).value
            return String(format: "%.0f", kmValue)
        }
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 25)
                .foregroundStyle(Color(shoe.color))
                .frame(width: 180, height: 250)
                .scaleEffect(isPressed ? 0.90 : (isLongPressing ? 1.05 : 1.0))
                .animation(.easeInOut(duration: isLongPressing ? 0.3 : 0.1), value: isPressed)
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isLongPressing)

            VStack(alignment: .leading) {
                HStack{
                    // Voyant active en haut aligné leading
                    if shoe.isActive {
                        HStack {
                            Image(systemName: "circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text("Wearing")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    } else {
                        // Espace vide pour garder l'alignement
                        HStack {
                            Text("")
                                .font(.caption)
                        }
                    }
                    
                    Spacer()
                }
                
                Spacer()
                
                // Emoji centré
                Text(shoe.icon)
                    .font(.system(size: 70))
                    .frame(maxWidth: .infinity, alignment: .center)
                
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    Text(shoe.brand.uppercased())
                        .font(.title3)
                        .fontWeight(.black)
                        .italic()
                    Text(shoe.model)
                        
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text(formattedDistance)
                            .fontDesign(.monospaced)
                            .font(.title)
                        Text(distanceUnit)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding() // ajoute de l'espace intérieur
            .frame(maxWidth: .infinity, alignment: .leading) // aligne à gauche dans le ZStack
        }
        .frame(width: 190, height: 250) // pour que le ZStack soit bien taillé
        .onTapGesture {
            // Tap simple : ouvrir details
            showingDetailSheet = true
        }
        .onLongPressGesture(minimumDuration: 0.3, maximumDistance: 10) {
            // Long press completed: toggle active state
            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
            impactFeedback.impactOccurred()
            
            // Change state and return to normal size immediately
            withAnimation(.easeOut(duration: 0.2)) {
                shoe.setActive(!shoe.isActive, in: context)
                // Return to normal size immediately
                isLongPressing = false
                isPressed = false
            }
        } onPressingChanged: { pressing in
            // Immediate feedback during press
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }
        .sheet(isPresented: $showingDetailSheet) {
            NavigationView {
                ShoeDetailView(shoe: shoe)
            }
        }
    }
}


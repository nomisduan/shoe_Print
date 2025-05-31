//
//  ShoeCardView.swift
//  shoePrint
//
//  Created by Simon Naud on 11/04/2025.
//

import SwiftUI
import SwiftData

struct ShoeCardView: View {
    let shoe: Shoe
    var onDelete: () -> Void = {}
    var onArchive: () -> Void = {}
    var onEdit: () -> Void = {}
    
    @Environment(\.modelContext) private var context
    @State private var showingDetailSheet = false
    @State private var isPressed = false
    @State private var isLongPressing = false
    
    // Distance formatting logic
    private var distanceUnit: String {
        let formatter = MeasurementFormatter()
        let measurement = Measurement(value: 1000, unit: UnitLength.meters)
        let formatted = formatter.string(from: measurement)
        return formatted.contains("mi") ? "mi" : "km"
    }
    
    private var formattedDistance: String {
        let distanceInMeters = shoe.totalDistance * 1000 // shoe.totalDistance is in km
        let measurement = Measurement(value: distanceInMeters, unit: UnitLength.meters)
        
        let formatter = MeasurementFormatter()
        formatter.unitStyle = .short
        formatter.numberFormatter.maximumFractionDigits = 0
        
        // Convert to appropriate unit based on locale settings
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
                HStack {
                    // Active indicator aligned leading
                    if shoe.isActive {
                        WearingIndicator()
                    } else {
                        // Empty space to maintain alignment
                        HStack {
                            Text("")
                                .font(.caption)
                        }
                    }
                    
                    Spacer()
                    
                    // Default shoe indicator aligned trailing
                    if shoe.isDefault {
                        DefaultShoeIndicator()
                    }
                }
                
                Spacer()
                
                // Centered emoji
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
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 190, height: 250)
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

/// Animated wearing indicator with pulse effect
struct WearingIndicator: View {
    @State private var isPulsing = false
    
    var body: some View {
        HStack {
            Image(systemName: "circle.fill")
                .foregroundColor(.green)
                .font(.caption)
                .scaleEffect(isPulsing ? 1.2 : 1.0)
                .opacity(isPulsing ? 0.6 : 1.0)
                .animation(
                    Animation.easeInOut(duration: 1.0)
                        .repeatForever(autoreverses: true),
                    value: isPulsing
                )
            Text("Wearing")
                .font(.caption)
                .fontWeight(.medium)
        }
        .onAppear {
            isPulsing = true
        }
    }
}

/// Default shoe indicator
struct DefaultShoeIndicator: View {
    var body: some View {
        HStack {
            Image(systemName: "star.fill")
                .foregroundColor(.orange)
                .font(.caption)
            Text("Default")
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.orange.opacity(0.2))
        .cornerRadius(8)
    }
}


//
//  HealthDashboardView.swift
//  shoePrint
//
//  Created by Simon Naud on 11/04/2025.
//

import SwiftUI
import SwiftData

/// Clean and intuitive health dashboard for hourly step attribution to shoes
struct HealthDashboardView: View {
    
    // MARK: - Properties
    
    @ObservedObject var healthKitViewModel: HealthKitViewModel
    @Query private var shoes: [Shoe]
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedDate = Date()
    @State private var showingDatePicker = false
    @State private var hourlySteps: [HourlyStepData] = []
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                dateSelector
                
                contentView
                
                Spacer()
            }
            .navigationTitle("Health")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await loadHourlyData()
            }
            .refreshable {
                await loadHourlyData()
            }
        }
    }
}

// MARK: - Content Views

private extension HealthDashboardView {
    
    @ViewBuilder
    var contentView: some View {
        if !healthKitViewModel.isPermissionGranted {
            HealthPermissionView(healthKitViewModel: healthKitViewModel)
        } else if hourlySteps.isEmpty {
            EmptyDataView()
        } else {
            hourlyStepsList
        }
    }
    
    var dateSelector: some View {
        HStack {
            Text(selectedDate, style: .date)
                .font(.title2)
                .fontWeight(.semibold)
            
            Spacer()
            
            Button {
                showingDatePicker = true
            } label: {
                Image(systemName: "calendar")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .sheet(isPresented: $showingDatePicker) {
            DatePickerSheet(selectedDate: $selectedDate) {
                Task { await loadHourlyData() }
            }
        }
    }
    
    var hourlyStepsList: some View {
        List {
            ForEach(Array(hourlySteps.enumerated()), id: \.element.id) { index, hourData in
                HourlyStepRow(
                    hourData: hourData,
                    shoes: availableShoes,
                    onShoeSelected: { shoe in
                        attributeStepsToShoe(at: index, shoe: shoe)
                    }
                )
            }
        }
        .listStyle(PlainListStyle())
    }
    
    var availableShoes: [Shoe] {
        shoes.filter { !$0.archived }
    }
}

// MARK: - Actions

private extension HealthDashboardView {
    
    func loadHourlyData() async {
        hourlySteps = await healthKitViewModel.fetchHourlySteps(for: selectedDate)
    }
    
    func attributeStepsToShoe(at index: Int, shoe: Shoe) {
        let hourData = hourlySteps[index]
        
        Task {
            await healthKitViewModel.attributeHourlyStepsToShoe(hourData, to: shoe)
            
            // Update local state
            hourlySteps[index].assignedShoe = shoe
            
            print("✅ Attributed \(hourData.steps) steps at \(hourData.timeString) to \(shoe.brand) \(shoe.model)")
        }
    }
}

// MARK: - Supporting Views

/// Permission request view for HealthKit access
struct HealthPermissionView: View {
    let healthKitViewModel: HealthKitViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Accès HealthKit requis")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Autorisez l'accès aux données de santé pour voir vos pas par heure")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Autoriser l'accès") {
                Task {
                    await healthKitViewModel.requestPermissions()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

/// Empty state view when no data is available
struct EmptyDataView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "figure.walk")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Aucune donnée")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Aucune activité détectée pour cette date")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

/// Row view for displaying hourly step data with shoe attribution
struct HourlyStepRow: View {
    @State private var hourData: HourlyStepData
    let shoes: [Shoe]
    let onShoeSelected: (Shoe) -> Void
    
    @State private var showingShoeSelector = false
    
    init(hourData: HourlyStepData, shoes: [Shoe], onShoeSelected: @escaping (Shoe) -> Void) {
        self._hourData = State(initialValue: hourData)
        self.shoes = shoes
        self.onShoeSelected = onShoeSelected
    }
    
    var body: some View {
        HStack {
            timeView
            stepsView
            Spacer()
            attributionView
        }
        .padding(.vertical, 8)
        .sheet(isPresented: $showingShoeSelector) {
            ShoeSelectionSheet(shoes: shoes) { selectedShoe in
                onShoeSelected(selectedShoe)
                hourData.assignedShoe = selectedShoe
            }
        }
    }
}

// MARK: - HourlyStepRow Components

private extension HourlyStepRow {
    
    var timeView: some View {
        Text(hourData.timeString)
            .font(.system(.body, design: .monospaced))
            .fontWeight(.medium)
            .frame(width: 60, alignment: .leading)
    }
    
    var stepsView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(hourData.steps)")
                .font(.headline)
                .fontWeight(.semibold)
            Text("pas")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    var attributionView: some View {
        if let assignedShoe = hourData.assignedShoe {
            assignedShoeView(assignedShoe)
        } else {
            attributionButton
        }
    }
    
    func assignedShoeView(_ shoe: Shoe) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(hex: shoe.color) ?? .blue)
                .frame(width: 12, height: 12)
            
            Text("\(shoe.brand) \(shoe.model)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
        .onTapGesture {
            showingShoeSelector = true
        }
    }
    
    var attributionButton: some View {
        Button {
            showingShoeSelector = true
        } label: {
            Text("Attribuer")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
        }
    }
}

/// Date picker sheet for selecting a specific date
struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    let onDateChanged: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                DatePicker(
                    "Sélectionner une date",
                    selection: $selectedDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(GraphicalDatePickerStyle())
                .padding()
                
                Spacer()
            }
            .navigationTitle("Choisir une date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annuler") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("OK") {
                        onDateChanged()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

/// Sheet for selecting a shoe to attribute steps to
struct ShoeSelectionSheet: View {
    let shoes: [Shoe]
    let onShoeSelected: (Shoe) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(shoes) { shoe in
                    ShoeSelectionRowView(shoe: shoe) {
                        onShoeSelected(shoe)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Choisir une paire")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Annuler") { dismiss() }
                }
            }
        }
    }
}

/// Reusable shoe row view for the selection sheet
struct ShoeSelectionRowView: View {
    let shoe: Shoe
    let onTap: () -> Void
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color(hex: shoe.color) ?? .blue)
                .frame(width: 20, height: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(shoe.brand) \(shoe.model)")
                    .font(.headline)
                
                if !shoe.notes.isEmpty {
                    Text(shoe.notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if shoe.isActive {
                ActiveShoeLabel()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

/// Active shoe indicator label
struct ActiveShoeLabel: View {
    var body: some View {
        Text("Actif")
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.green)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.green.opacity(0.1))
            .cornerRadius(6)
    }
}

// MARK: - Preview

#Preview {
    let viewModel = HealthKitViewModel(
        modelContext: PreviewContainer.previewModelContext,
        healthKitManager: HealthKitManager()
    )
    
    HealthDashboardView(healthKitViewModel: viewModel)
        .modelContainer(PreviewContainer.previewModelContainer)
} 
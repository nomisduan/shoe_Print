//
//  HealthDashboardView.swift
//  shoePrint
//
//  Created by Simon Naud on 11/04/2025.
//

import SwiftUI
import SwiftData

/// Visual journal for hourly step attribution to shoes
struct HealthDashboardView: View {
    
    // MARK: - Properties
    
    @ObservedObject var healthKitViewModel: HealthKitViewModel
    @Query private var shoes: [Shoe]
    @Environment(\.modelContext) private var modelContext
    @State private var shoeSessionService: ShoeSessionService?
    
    @State private var selectedDate = Date()
    @State private var showingDatePicker = false
    @State private var hourlySteps: [HourlyStepData] = []
    @State private var selectedHours: Set<UUID> = []
    @State private var isSelectionMode = false
    @State private var showingBatchAttributionSheet = false
    
    // MARK: - Body
    
    var body: some View {
        contentView
            .navigationTitle("Journal")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if isSelectionMode {
                        Button {
                            if selectedHours.count == hourlySteps.count {
                                selectedHours.removeAll()
                            } else {
                                selectedHours = Set(hourlySteps.map(\.id))
                            }
                        } label: {
                            Text("Select All")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.accentColor)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.gray.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    // Select/Cancel capsule button
                    Button {
                        if isSelectionMode {
                            exitSelectionMode()
                        } else {
                            enterSelectionMode()
                        }
                    } label: {
                        Text(isSelectionMode ? "Cancel" : "Select")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.accentColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.gray.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
            }
            .task {
                await loadHourlyData()
            }
            .refreshable {
                await loadHourlyData()
            }
            .sheet(isPresented: $showingBatchAttributionSheet) {
                BatchAttributionSheet(
                    selectedHours: selectedHours,
                    hourlySteps: hourlySteps,
                    shoes: availableShoes,
                    onShoeSelected: { shoe in
                        await attributeSelectedHoursToShoe(shoe)
                    },
                    onRemoveAttribution: {
                        await removeSelectedHoursAttribution()
                    }
                )
            }
            .overlay(alignment: .bottom) {
                // Floating attribute button when hours are selected
                if isSelectionMode && !selectedHours.isEmpty {
                    Button("Attribute \(selectedHours.count) hours") {
                        showingBatchAttributionSheet = true
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .onAppear {
                if shoeSessionService == nil {
                    shoeSessionService = ShoeSessionService(modelContext: modelContext)
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
            hourlyStepsJournal
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
        .padding(.horizontal)
        .padding(.vertical, 12)
        .sheet(isPresented: $showingDatePicker) {
            DatePickerSheet(selectedDate: $selectedDate) {
                Task { await loadHourlyData() }
            }
        }
    }
    
    var hourlyStepsJournal: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Date selector header - scrollable comme les indicateurs dans Collection
                dateSelector
                
                // Journal content
                LazyVStack(spacing: 12) {
                    ForEach(Array(hourlySteps.enumerated()), id: \.element.id) { index, hourData in
                        HourlyStepBarView(
                            hourData: hourData,
                            maxSteps: maxStepsInDay,
                            isSelected: selectedHours.contains(hourData.id),
                            isSelectionMode: isSelectionMode,
                            onTap: {
                                toggleSelection(for: hourData.id)
                            },
                            onAttributionTap: {
                                showAttributionSheet(for: index)
                            }
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)
            }
        }
    }
    
    var availableShoes: [Shoe] {
        shoes.filter { !$0.archived }
    }
    
    var maxStepsInDay: Int {
        hourlySteps.map(\.steps).max() ?? 1
    }
}

// MARK: - Actions

private extension HealthDashboardView {
    
    func loadHourlyData() async {
        // Get raw HealthKit data
        let rawHealthKitData = await healthKitViewModel.fetchHourlySteps(for: selectedDate)
        print("🔍 DEBUG: Loaded \(rawHealthKitData.count) raw HealthKit data points")
        
        // Use ShoeSessionService to add session-based shoe attributions
        if let service = shoeSessionService {
            hourlySteps = await service.getHourlyStepDataForDate(selectedDate, healthKitData: rawHealthKitData)
            print("🔍 DEBUG: After session enrichment: \(hourlySteps.count) data points")
            
            // Debug: Print attribution status for each hour
            for (index, hourData) in hourlySteps.enumerated() {
                if let shoe = hourData.assignedShoe {
                    print("🔍 DEBUG: Hour \(hourData.timeString) attributed to \(shoe.brand) \(shoe.model)")
                } else {
                    print("🔍 DEBUG: Hour \(hourData.timeString) not attributed")
                }
            }
        } else {
            hourlySteps = rawHealthKitData
            print("🔍 DEBUG: No ShoeSessionService available, using raw data")
        }
        
        selectedHours.removeAll()
    }
    
    func attributeStepsToShoe(at index: Int, shoe: Shoe) {
        let hourData = hourlySteps[index]
        
        Task {
            guard let service = shoeSessionService else { return }
            
            // Create a session for this specific hour
            await service.createHourSession(for: shoe, hourDate: hourData.date)
            
            // Reload the data to reflect the session-based attribution
            await loadHourlyData()
            
            print("✅ Attributed \(hourData.steps) steps at \(hourData.timeString) to \(shoe.brand) \(shoe.model)")
        }
    }
    
    func showAttributionSheet(for index: Int) {
        // Create and show a single attribution sheet
        // We'll implement this with a state variable to track which hour to attribute
        showingBatchAttributionSheet = true
        selectedHours = [hourlySteps[index].id]
    }
    
    func enterSelectionMode() {
        isSelectionMode = true
        selectedHours.removeAll()
    }
    
    func exitSelectionMode() {
        isSelectionMode = false
        selectedHours.removeAll()
    }
    
    func toggleSelection(for hourId: UUID) {
        if selectedHours.contains(hourId) {
            selectedHours.remove(hourId)
        } else {
            selectedHours.insert(hourId)
        }
    }
    
    func attributeSelectedHoursToShoe(_ shoe: Shoe) async {
        guard let service = shoeSessionService else { return }
        
        let selectedHourData = hourlySteps.filter { selectedHours.contains($0.id) }
        let hourDates = selectedHourData.map(\.date)
        
        // Create sessions for all selected hours
        await service.createHourSessions(for: shoe, hourDates: hourDates)
        
        // Reload the data to reflect the session-based attribution
        await loadHourlyData()
        
        exitSelectionMode()
        
        print("✅ Batch attributed \(selectedHourData.count) hours to \(shoe.brand) \(shoe.model)")
    }
    
    func removeSelectedHoursAttribution() async {
        guard let service = shoeSessionService else { return }
        
        let selectedHourData = hourlySteps.filter { selectedHours.contains($0.id) }
        
        for hourData in selectedHourData {
            await service.removeHourAttribution(for: hourData.date)
        }
        
        // Reload the data to reflect the session-based attribution
        await loadHourlyData()
        
        exitSelectionMode()
        
        print("🗑️ Removed attribution for \(selectedHourData.count) hours")
    }
}

// MARK: - Supporting Views

/// Visual bar representation of hourly step data
struct HourlyStepBarView: View {
    let hourData: HourlyStepData
    let maxSteps: Int
    let isSelected: Bool
    let isSelectionMode: Bool
    let onTap: () -> Void
    let onAttributionTap: () -> Void
    
    private var maxBarWidth: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let padding: CGFloat = isSelectionMode ? 140 : 100 // Account for checkmark, padding, distance column, and margins
        return screenWidth - padding
    }
    
    private var barWidth: CGFloat {
        let ratio = CGFloat(hourData.steps) / CGFloat(max(maxSteps, 1))
        let calculatedWidth = maxBarWidth * ratio
        return max(60, min(calculatedWidth, maxBarWidth)) // Minimum 60, maximum maxBarWidth
    }
    
    private var barHeight: CGFloat {
        50 // Taller rectangles
    }
    
    private var barColor: Color {
        if let shoe = hourData.assignedShoe {
            // Use the color directly from Assets.xcassets (CustomPurple, CustomBlue, etc.)
            return Color(shoe.color)
        } else {
            return Color.clear
        }
    }
    
    private var strokeColor: Color {
        if isSelected {
            return .blue
        } else if hourData.assignedShoe != nil {
            return Color.clear
        } else {
            return .gray
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Selection checkbox
            if isSelectionMode {
                Button {
                    onTap()
                } label: {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(isSelected ? .blue : .gray)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Step bar rectangle
            RoundedRectangle(cornerRadius: 12)
                .fill(barColor)
                .stroke(strokeColor, lineWidth: isSelected ? 3 : (hourData.assignedShoe == nil ? 1.5 : 0))
                .frame(width: barWidth, height: barHeight)
                .overlay(
                    VStack {
                        Spacer()
                        rectangleContent
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6),
                    alignment: .bottomLeading
                )
                .animation(.easeInOut(duration: 0.2), value: barWidth)
                .animation(.easeInOut(duration: 0.2), value: barColor)
                .animation(.easeInOut(duration: 0.2), value: isSelected)
                .contentShape(Rectangle())
                .onTapGesture {
                    if isSelectionMode {
                        onTap()
                    } else {
                        onAttributionTap()
                    }
                }
            
            Spacer()
            
            // Distance display aligned to the right
            distanceDisplay
        }
    }
    
    @ViewBuilder
    private var rectangleContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Shoe emoji if attributed
            if let shoe = hourData.assignedShoe {
                Text(shoe.icon)
                    .font(.title3)
            }
            
            // Hour label
            Text(hourData.timeString)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.medium)
        }
    }
    
    private var distanceDisplay: some View {
        let distance = Double(hourData.steps) * 0.000762
        let formattedDistance = distance < 1.0 ? String(format: "%.1f", distance) : String(format: "%.0f", distance)
        
        return VStack(alignment: .leading, spacing: 1) {
            Text(formattedDistance)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(.primary)
            
            Text("km")
                .font(.system(size: 10, weight: .regular))
                .foregroundColor(.secondary)
        }
        .frame(width: 40, alignment: .leading)
    }
}

/// Sheet for batch attribution of selected hours
struct BatchAttributionSheet: View {
    let selectedHours: Set<UUID>
    let hourlySteps: [HourlyStepData]
    let shoes: [Shoe]
    let onShoeSelected: (Shoe) async -> Void
    let onRemoveAttribution: () async -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    private var selectedHourData: [HourlyStepData] {
        hourlySteps.filter { selectedHours.contains($0.id) }
    }
    
    private var totalSteps: Int {
        selectedHourData.reduce(0) { $0 + $1.steps }
    }
    
    private var totalDistance: Double {
        // Estimate: roughly 0.762 meters per step (average adult)
        Double(totalSteps) * 0.000762 // Convert to kilometers
    }
    
    private var timeRange: String {
        let sortedHours = selectedHourData.sorted { $0.hour < $1.hour }
        
        if sortedHours.isEmpty {
            return ""
        } else if sortedHours.count == 1 {
            return sortedHours.first!.timeString
        } else {
            return "\(sortedHours.first!.timeString) - \(sortedHours.last!.timeString)"
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                // Time and distance info
                VStack(alignment: .leading, spacing: 8) {
                    Text(timeRange)
                        .font(.title2)
                        .fontWeight(.medium)
                    
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f", totalDistance))
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                        Text("km")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                
                // Shoe selection grid
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8)
                    ], spacing: 16) {
                        ForEach(shoes) { shoe in
                            MiniShoeCardView(shoe: shoe) {
                                Task {
                                    await onShoeSelected(shoe)
                                    dismiss()
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                
                // Remove attribution option
                Button {
                    Task {
                        await onRemoveAttribution()
                        dismiss()
                    }
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text("Remove Attribution")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                Spacer()
            }
            .navigationTitle("Attributing \(selectedHours.count) hours")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

/// Permission request view for HealthKit access
struct HealthPermissionView: View {
    let healthKitViewModel: HealthKitViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("HealthKit Access Required")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Allow access to health data to see your hourly steps")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Allow Access") {
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
            
            Text("No Data")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("No activity detected for this date")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
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
                    "Select Date",
                    selection: $selectedDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(GraphicalDatePickerStyle())
                .padding()
                
                Spacer()
            }
            .navigationTitle("Choose Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
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

/// Reusable shoe row view for the selection sheet
struct ShoeSelectionRowView: View {
    let shoe: Shoe
    let onTap: () -> Void
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color(hex: shoe.color) ?? .blue)
                .frame(width: 20, height: 20)
            
            Text(shoe.icon)
                .font(.title2)
            
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
        Text("Active")
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
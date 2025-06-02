//
//  JournalView.swift
//  shoePrint
//
//  Created by Simon Naud on 11/04/2025.
//

import SwiftUI
import SwiftData

/// Visual journal for hourly step attribution to shoes
struct JournalView: View {
    
    // MARK: - Properties
    
    @ObservedObject var healthKitViewModel: HealthKitViewModel
    @Query private var shoes: [Shoe]
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var diContainer: DIContainer
    @State private var attributionService: AttributionService?
    
    @State private var selectedDate = Date()
    @State private var currentWeekOffset = 0 // For week navigation
    @State private var showingDatePicker = false
    @State private var hourlySteps: [HourlyStepData] = []
    @State private var selectedHours: Set<UUID> = []
    @State private var isSelectionMode = false
    @State private var showingBatchAttributionSheet = false
    @State private var displayedMonth = Date() // Track the currently displayed month for header
    
    // MARK: - Body
    
    var body: some View {
        contentView
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Custom title
                ToolbarItem(placement: .principal) {
                    HStack {
                        Text("JOURNAL")
                            .font(.largeTitle)
                            .fontWeight(.black)
                            .italic()
                            .foregroundColor(.primary)
                        Spacer()
                    }
                }
                
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
                if attributionService == nil {
                    // ✅ Get AttributionService from DI container
                    attributionService = diContainer.resolve(AttributionService.self)
                }
            }
            .onChange(of: selectedDate) { _, _ in
                // Reload when date changes
                Task {
                    await loadHourlyData()
                }
                print("🔄 HealthDashboard: Date changed, reloading data")
            }
    }
}

// MARK: - Content Views

private extension JournalView {
    
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
        VStack(spacing: 16) { // Increased from 6 to 16 for more breathing room
            // Month header with Today button and calendar button
            HStack {
                Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Today button
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedDate = Date()
                        currentWeekOffset = 0
                        displayedMonth = Date()
                    }
                    Task { await loadHourlyData() }
                } label: {
                    Text("Today")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Capsule())
                }
                
                Button {
                    showingDatePicker = true
                } label: {
                    Image(systemName: "calendar")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            
            // Week selector with infinite scroll
            infiniteWeekSelector
            
            // Daily statistics with StatCard design from ShoeDetailView
            HStack(spacing: 12) {
                StatCard(
                    title: NSLocalizedString("Distance", comment: "Distance label"),
                    value: totalDailyDistance.formattedDistance,
                    unit: "km",
                    icon: "figure.walk",
                    color: .blue
                )
                
                StatCard(
                    title: NSLocalizedString("Steps", comment: "Steps label"),
                    value: totalDailySteps.formattedSteps,
                    unit: "steps",
                    icon: "shoeprints.fill",
                    color: .green
                )
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 16) // Increased from 6 to 16 for more breathing room
        .sheet(isPresented: $showingDatePicker) {
            DatePickerSheet(selectedDate: $selectedDate) {
                Task { await loadHourlyData() }
                // Update displayed month and week offset based on selected date
                let calendar = Calendar.current
                let weekDifference = calendar.dateInterval(of: .weekOfYear, for: selectedDate)!.start.timeIntervalSince(calendar.dateInterval(of: .weekOfYear, for: Date())!.start) / (7 * 24 * 60 * 60)
                currentWeekOffset = Int(weekDifference)
                displayedMonth = selectedDate
            }
        }
    }
    
    var infiniteWeekSelector: some View {
        let calendar = Calendar.current
        let screenWidth = UIScreen.main.bounds.width
        
        return ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    // Generate weeks more simply for better performance
                    ForEach(-5...5, id: \.self) { weekOffset in
                        let weekDate = calendar.date(byAdding: .weekOfYear, value: currentWeekOffset + weekOffset, to: Date()) ?? Date()
                        let currentWeek = calendar.dateInterval(of: .weekOfYear, for: weekDate) ?? DateInterval(start: Date(), end: Date())
                        
                        HStack(spacing: 0) {
                            ForEach(0..<7, id: \.self) { dayOffset in
                                let date = calendar.date(byAdding: .day, value: dayOffset, to: currentWeek.start) ?? Date()
                                let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                                let isToday = calendar.isDateInToday(date)
                                let isFuture = date > Date()
                                let isClickable = !isFuture
                                
                                VStack(spacing: 6) {
                                    // Day name - single letter abbreviation
                                    Text(singleLetterDayName(for: date))
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(isClickable ? .secondary : .secondary.opacity(0.5))
                                    
                                    // Day number
                                    Text(date.formatted(.dateTime.day()))
                                        .font(.headline)
                                        .fontWeight(isSelected ? .bold : .medium)
                                        .foregroundColor(
                                            isSelected ? .white : 
                                            (isToday ? .blue : // Today number in blue
                                             (isClickable ? .primary : .primary.opacity(0.5)))
                                        )
                                        .frame(width: 32, height: 32)
                                        .background(
                                            Circle()
                                                .fill(isSelected ? Color.black : Color.clear)
                                        )
                                }
                                .frame(width: screenWidth / 7)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if isClickable {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedDate = date
                                            displayedMonth = date
                                        }
                                        Task { await loadHourlyData() }
                                    }
                                }
                            }
                        }
                        .id("week-\(currentWeekOffset + weekOffset)")
                    }
                }
                .onAppear {
                    proxy.scrollTo("week-0", anchor: .center)
                }
            }
            .scrollTargetBehavior(.paging)
            .gesture(
                DragGesture()
                    .onEnded { value in
                        let screenWidth = UIScreen.main.bounds.width
                        let threshold: CGFloat = screenWidth / 4
                        
                        if value.translation.width > threshold {
                            // Swipe right - go to previous week
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentWeekOffset -= 1
                                displayedMonth = calendar.date(byAdding: .weekOfYear, value: currentWeekOffset, to: Date()) ?? Date()
                            }
                        } else if value.translation.width < -threshold {
                            // Swipe left - go to next week
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentWeekOffset += 1
                                displayedMonth = calendar.date(byAdding: .weekOfYear, value: currentWeekOffset, to: Date()) ?? Date()
                            }
                        }
                    }
            )
            .onChange(of: currentWeekOffset) { _, _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo("week-0", anchor: .center)
                }
            }
        }
    }
    
    // Helper function to get single letter day abbreviation
    private func singleLetterDayName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEE" // Single letter weekday
        return formatter.string(from: date)
    }
    
    var hourlyStepsJournal: some View {
        VStack(spacing: 12) { // Increased from 2 to 12 for more breathing room
            // Date selector header with statistics
            dateSelector
            
            // Fixed height horizontal scrolling journal with bars aligned at bottom
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(hourlySteps.enumerated()), id: \.element.id) { index, hourData in
                        HourlyStepColumnView(
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
                .padding(.top, 16) // Increased from 4 to 16 for more breathing room
                .padding(.bottom, 8)
            }
            .frame(height: 320)
            
            Spacer()
        }
    }
    
    var availableShoes: [Shoe] {
        shoes.filter { !$0.archived }
    }
    
    var maxStepsInDay: Int {
        hourlySteps.map(\.steps).max() ?? 1
    }
    
    var totalDailySteps: Int {
        hourlySteps.reduce(0) { $0 + $1.steps }
    }
    
    var totalDailyDistance: Double {
        // Use real distance data from HealthKit
        hourlySteps.reduce(0) { $0 + $1.distance }
    }
}

// MARK: - Actions

private extension JournalView {
    
    func loadHourlyData() async {
        // Get raw HealthKit data
        let rawHealthKitData = await healthKitViewModel.fetchHourlySteps(for: selectedDate)
        print("🔍 DEBUG: Loaded \(rawHealthKitData.count) raw HealthKit data points")
        
        // Use AttributionService to add shoe attributions
        if let service = attributionService {
            hourlySteps = await service.applyAttributions(to: rawHealthKitData, for: selectedDate)
            print("🔍 After attribution enrichment: \(hourlySteps.count) data points")
            
            // Debug: Print attribution status for each hour
            for hourData in hourlySteps.prefix(3) {
                if let shoe = hourData.assignedShoe {
                    print("🔍 Hour \(hourData.timeString) attributed to \(shoe.brand) \(shoe.model)")
                } else {
                    print("🔍 Hour \(hourData.timeString) not attributed")
                }
            }
        } else {
            hourlySteps = rawHealthKitData
            print("🔍 No AttributionService available, using raw data")
        }
        
        selectedHours.removeAll()
    }
    
    func attributeStepsToShoe(at index: Int, shoe: Shoe) {
        let hourData = hourlySteps[index]
        
        Task {
            guard let service = attributionService else { return }
            
            do {
                // Create attribution for this specific hour
                try await service.attributeHour(hourData.date, to: shoe)
                
                // Reload the data to reflect the attribution
                await loadHourlyData()
                
                print("✅ Attributed \(hourData.steps) steps at \(hourData.timeString) to \(shoe.brand) \(shoe.model)")
            } catch {
                print("❌ Failed to attribute hour: \(error)")
            }
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
        guard let service = attributionService else { return }
        
        let selectedHourData = hourlySteps.filter { selectedHours.contains($0.id) }
        let hourDates = selectedHourData.map(\.date)
        
        do {
            // Create attributions for all selected hours
            try await service.attributeHours(hourDates, to: shoe)
            
            // Reload the data to reflect the attribution
            await loadHourlyData()
            
            exitSelectionMode()
            
            print("✅ Batch attributed \(selectedHourData.count) hours to \(shoe.brand) \(shoe.model)")
        } catch {
            print("❌ Failed to batch attribute hours: \(error)")
        }
    }
    
    func removeSelectedHoursAttribution() async {
        guard let service = attributionService else { return }
        
        let selectedHourData = hourlySteps.filter { selectedHours.contains($0.id) }
        let hourDates = selectedHourData.map(\.date)
        
        do {
            // Remove attributions for all selected hours
            try await service.removeAttributions(for: hourDates)
            
            // Reload the data to reflect the attribution removal
            await loadHourlyData()
            
            exitSelectionMode()
            
            print("🗑️ Removed attribution for \(selectedHourData.count) hours")
        } catch {
            print("❌ Failed to remove attributions: \(error)")
        }
    }
}

// MARK: - Supporting Views

/// Visual column representation of hourly step data
struct HourlyStepColumnView: View {
    let hourData: HourlyStepData
    let maxSteps: Int
    let isSelected: Bool
    let isSelectionMode: Bool
    let onTap: () -> Void
    let onAttributionTap: () -> Void
    
    private var barHeight: CGFloat {
        let ratio = CGFloat(hourData.steps) / CGFloat(max(maxSteps, 1))
        let maxHeight: CGFloat = 180 // Reduced max height
        let minHeight: CGFloat = 8 // Minimum visible height
        return max(minHeight, maxHeight * ratio)
    }
    
    private var barWidth: CGFloat {
        40 // Consistent width
    }
    
    private var barColor: Color {
        if let shoe = hourData.assignedShoe {
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
    
    private var formattedDistance: String {
        return hourData.distanceFormatted
    }
    
    // Minimum height required to show the emoji
    private var shouldShowEmoji: Bool {
        barHeight >= 30
    }
    
    var body: some View {
        VStack(spacing: 6) {
            // Fixed container for bars - ensures bottom alignment
            VStack(spacing: 0) {
                // Distance display (moved closer to bars, above them)
                VStack(spacing: 2) {
                    Text(formattedDistance)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary)
                    Text("km")
                        .font(.system(size: 9, weight: .regular))
                        .foregroundColor(.secondary)
                }
                .frame(height: 28) // Fixed height for distance info
                .opacity(hourData.steps > 0 ? 1.0 : 0.3) // Dim when no data
                
                // Bar container with bottom alignment
                VStack {
                    Spacer() // This pushes the bar to the bottom
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(barColor)
                        .stroke(strokeColor, lineWidth: isSelected ? 2.5 : (hourData.assignedShoe == nil ? 1.0 : 0))
                        .frame(width: barWidth, height: barHeight)
                        .overlay(
                            // Shoe emoji at the bottom of the bar
                            VStack {
                                Spacer()
                                if shouldShowEmoji, let shoe = hourData.assignedShoe {
                                    Text(shoe.icon)
                                        .font(.system(size: 14))
                                        .padding(.bottom, 4)
                                }
                            }
                        )
                        .animation(.easeInOut(duration: 0.2), value: barHeight)
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
                }
                .frame(height: 180) // Fixed height for bar area - ensures alignment
            }
            
            // Hour label (below bars)
            Text(hourData.timeString)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(height: 16) // Fixed height for hour label
            
            // Selection checkbox (moved to bottom when in selection mode)
            if isSelectionMode {
                Button {
                    onTap()
                } label: {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18))
                        .foregroundColor(isSelected ? .blue : .gray)
                }
                .buttonStyle(PlainButtonStyle())
                .frame(height: 24) // Fixed height for checkbox area
            } else {
                // Fixed space when not in selection mode to maintain consistent spacing
                Spacer()
                    .frame(height: 24)
            }
        }
        .frame(width: 50) // Fixed total width for each column
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
        // Use real distance data from HealthKit
        selectedHourData.reduce(0) { $0 + $1.distance }
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
            Spacer()
            
            Image(systemName: "heart.text.square")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("HealthKit Access Required")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("ShoePrint needs access to your step count and walking distance data to track shoe usage. This data stays on your device.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            
            if let error = healthKitViewModel.error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
            
            Button {
                Task {
                    await healthKitViewModel.requestPermissions()
                }
            } label: {
                HStack {
                    if healthKitViewModel.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Text(healthKitViewModel.isLoading ? "Requesting Access..." : "Allow Access")
                }
                .frame(minWidth: 150)
            }
            .buttonStyle(.borderedProminent)
            .disabled(healthKitViewModel.isLoading)
            
            // ✅ Debug override button for testing
            if healthKitViewModel.error != nil {
                Button("Override (Debug)") {
                    healthKitViewModel.overridePermissionStatus()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.orange)
                .font(.caption)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

/// Empty state view when no data is available
struct EmptyDataView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
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
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

// Preview temporarily disabled during architecture refactor
// TODO: Update preview with new dependency injection setup
/*
#Preview {
    JournalView(healthKitViewModel: viewModel)
        .modelContainer(PreviewContainer.previewModelContainer)
}
*/ 
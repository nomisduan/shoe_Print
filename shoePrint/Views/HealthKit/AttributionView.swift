//
//  AttributionView.swift
//  shoePrint
//
//  Created by Simon Naud on 11/04/2025.
//

import SwiftUI
import SwiftData

/// View for attributing walking sessions to specific shoes
/// Allows users to review unattributed sessions and assign them manually
struct AttributionView: View {
    @ObservedObject var healthKitViewModel: HealthKitViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(filter: #Predicate<Shoe> { shoe in !shoe.archived }, sort: \Shoe.brand) 
    private var availableShoes: [Shoe]
    
    @State private var selectedSessions: Set<UUID> = []
    @State private var showingShoeSelector = false
    @State private var sessionToAttribute: WalkingSession?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if healthKitViewModel.recentSessions.isEmpty {
                    emptyState
                } else {
                    sessionsList
                }
            }
            .navigationTitle("Walking Sessions")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !selectedSessions.isEmpty {
                        Button("Attribute") {
                            showingShoeSelector = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showingShoeSelector) {
                ShoeSelectorView(
                    availableShoes: availableShoes,
                    selectedSessions: healthKitViewModel.recentSessions.filter { selectedSessions.contains($0.id) },
                    sessions: healthKitViewModel.recentSessions
                ) { shoe in
                    attributeSelectedSessions(to: shoe)
                    selectedSessions.removeAll()
                    showingShoeSelector = false
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "figure.walk.circle")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            
            VStack(spacing: 12) {
                Text("No Walking Sessions")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Start walking with Apple Health enabled to see your sessions here.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var sessionsList: some View {
        List {
            Section {
                Text("Tap sessions to select them, then choose which shoes you were wearing.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } header: {
                Text("Instructions")
            }
            
            Section {
                ForEach(healthKitViewModel.recentSessions, id: \.id) { session in
                    SessionAttributionRow(
                        session: session,
                        isSelected: selectedSessions.contains(session.id),
                        onToggle: {
                            toggleSessionSelection(session)
                        },
                        onQuickAttribute: { shoe in
                            attributeSession(session, to: shoe)
                        },
                        availableShoes: availableShoes
                    )
                }
            } header: {
                Text("Recent Sessions (\(healthKitViewModel.recentSessions.count))")
            }
        }
    }
    
    private func toggleSessionSelection(_ session: WalkingSession) {
        if selectedSessions.contains(session.id) {
            selectedSessions.remove(session.id)
        } else {
            selectedSessions.insert(session.id)
        }
    }
    
    private func attributeSelectedSessions(to shoe: Shoe) {
        let sessionsToAttribute = healthKitViewModel.recentSessions.filter { 
            selectedSessions.contains($0.id) 
        }
        
        for session in sessionsToAttribute {
            attributeSession(session, to: shoe)
        }
    }
    
    private func attributeSession(_ session: WalkingSession, to shoe: Shoe) {
        // Create a new StepEntry for this session
        let entry = StepEntry(
            startDate: session.startDate,
            endDate: session.endDate,
            steps: session.totalSteps,
            distance: session.totalDistance / 1000.0, // Convert to km
            repair: false
        )
        
        // Add to the shoe
        shoe.entries.append(entry)
        
        // Save to SwiftData
        modelContext.insert(entry)
        
        do {
            try modelContext.save()
        } catch {
            print("Error saving attributed session: \(error)")
        }
    }
}

struct SessionAttributionRow: View {
    let session: WalkingSession
    let isSelected: Bool
    let onToggle: () -> Void
    let onQuickAttribute: (Shoe) -> Void
    let availableShoes: [Shoe]
    
    @State private var showingQuickOptions = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Main session info
            HStack {
                Button(action: onToggle) {
                    HStack(spacing: 12) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundColor(isSelected ? .blue : .gray)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.startDate.displayFormat)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("\(session.totalSteps) steps • \(session.distanceFormatted)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(Int(session.duration / 60))m")
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            Text(session.source)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            
            // Quick attribution buttons
            if !availableShoes.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(availableShoes.prefix(3), id: \.timestamp) { shoe in
                            Button {
                                onQuickAttribute(shoe)
                            } label: {
                                HStack(spacing: 6) {
                                    Text(shoe.icon)
                                        .font(.caption)
                                    
                                    Text(shoe.brand)
                                        .font(.caption)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .clipShape(Capsule())
                            }
                        }
                        
                        if availableShoes.count > 3 {
                            Button("More...") {
                                showingQuickOptions = true
                            }
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.gray.opacity(0.1))
                            .foregroundColor(.secondary)
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showingQuickOptions) {
            ShoeSelectorView(
                availableShoes: availableShoes,
                selectedSessions: [session],
                sessions: [session]
            ) { shoe in
                onQuickAttribute(shoe)
                showingQuickOptions = false
            }
        }
    }
}

struct ShoeSelectorView: View {
    let availableShoes: [Shoe]
    let selectedSessions: [WalkingSession]
    let sessions: [WalkingSession]
    let onSelection: (Shoe) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Text("Select the shoes you were wearing for \(selectedSessions.count) session\(selectedSessions.count == 1 ? "" : "s").")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Choose Shoes")
                }
                
                Section {
                    ForEach(availableShoes, id: \.timestamp) { shoe in
                        Button {
                            onSelection(shoe)
                        } label: {
                            HStack {
                                Text(shoe.icon)
                                    .font(.title2)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(shoe.brand) \(shoe.model)")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    
                                    if shoe.isActive {
                                        Text("Currently wearing")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    } else {
                                        Text("\(shoe.totalDistance.formatted(.number.precision(.fractionLength(1)))) km")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                if shoe.isActive {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Available Shoes")
                }
            }
            .navigationTitle("Select Shoes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    let mockViewModel = HealthKitViewModel(
        modelContext: PreviewContainer.previewModelContext,
        healthKitManager: HealthKitManager()
    )
    
    return AttributionView(healthKitViewModel: mockViewModel)
        .modelContainer(PreviewContainer.previewModelContainer)
} 
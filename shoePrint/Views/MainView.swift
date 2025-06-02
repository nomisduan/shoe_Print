//
//  MainView.swift
//  shoePrint
//
//  Created by Simon Naud on 12/04/2025.
//
import SwiftUI

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var diContainer: DIContainer
    @EnvironmentObject private var healthKitManager: HealthKitManager
    
    @State private var showingAddSheet = false
    @State private var shoeToDelete: Shoe?
    @State private var showDeleteAlert = false
    @State private var shoeToArchive: Shoe?
    @State private var showArchiveAlert = false
    @State private var shoeToEdit: Shoe?
    @State private var showEditSheet = false
    
    // Clean architecture - access via DI
    @State private var healthKitViewModel: HealthKitViewModel?
    
    var body: some View {
        TabView {
            Group {
                NavigationStack {
                    
                    ShoeGridView(shoeToDelete: $shoeToDelete,
                                 showDeleteAlert: $showDeleteAlert,
                                 shoeToArchive: $shoeToArchive,
                                 showArchiveAlert: $showArchiveAlert,
                                 shoeToEdit: $shoeToEdit,
                                 showEditSheet: $showEditSheet,
                                 healthKitViewModel: healthKitViewModel
                    )
                    .background(Color(UIColor.systemGroupedBackground))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        // Custom title
                        ToolbarItem(placement: .principal) {
                            HStack {
                                Text("COLLECTION")
                                    .font(.largeTitle)
                                    .fontWeight(.black)
                                    .italic()
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                        }
                        
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                showingAddSheet.toggle()
                            } label: {
                                Text("Add")
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
                }
                .tabItem { Label("Collection", systemImage: "shoe.2") }
                
                // Health Dashboard Tab
                if let viewModel = healthKitViewModel {
                    NavigationStack {
                        JournalView(healthKitViewModel: viewModel)
                            .background(Color(UIColor.systemGroupedBackground))
                    }
                    .tabItem { Label("Journal", systemImage: "checklist") }
                } else {
                    // Loading placeholder
                    NavigationStack {
                        Text("Loading Health Integration...")
                            .background(Color(UIColor.systemGroupedBackground))
                    }
                    .tabItem { Label("Journal", systemImage: "checklist") }
                }
                
                NavigationStack {
                    ShoeListView()
                        .background(Color(UIColor.systemGroupedBackground))
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            // Custom title
                            ToolbarItem(placement: .principal) {
                                HStack {
                                    Text("ARCHIVE")
                                        .font(.largeTitle)
                                        .fontWeight(.black)
                                        .italic()
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                            }
                        }
                }
                .tabItem {
                    Label("Archive", systemImage: "archivebox")
                }
            }
            .toolbarBackground(.ultraThinMaterial, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
        }
        .onAppear {
            // Initialize the HealthKit ViewModel from DI container
            if healthKitViewModel == nil {
                healthKitViewModel = diContainer.resolve(HealthKitViewModel.self)
            }
        }
        .alert("Archive this shoe?", isPresented: $showArchiveAlert, presenting: shoeToArchive) { shoe in
            Button("Archive", role: .destructive) {
                shoe.archive()
                try? modelContext.save()
                print("Archived: \(shoe.model)")
            }
            Button("Cancel", role: .cancel) { }
        } message: { shoe in
            Text("Are you sure you want to archive \"\(shoe.brand) \(shoe.model)\"?")
        }
        .alert("Delete Shoe", isPresented: $showDeleteAlert, presenting: shoeToDelete) { shoe in
            Button("Delete", role: .destructive) {
                delete(shoe)
            }
            Button("Cancel", role: .cancel) {}
        } message: { shoe in
            Text("Are you sure you want to delete \(shoe.brand) \(shoe.model)?")
        }
        
        .sheet(isPresented: $showingAddSheet) {
            AddAPairView()
                .presentationDetents([.large])
        }
        
        .sheet(isPresented: $showEditSheet) {
            if let shoeToEdit = shoeToEdit {
                EditPairView(shoeToEdit: shoeToEdit) // Passage direct de la valeur
                    .presentationDetents([.large])
            }
        }
    }
    
    private func delete(_ shoe: Shoe) {
        modelContext.delete(shoe)
        try? modelContext.save()
    }
}

#Preview {
    MainView()
        .modelContainer(PreviewContainer.previewModelContainer)
}


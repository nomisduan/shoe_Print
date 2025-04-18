//
//  MainView.swift
//  shoePrint
//
//  Created by Simon Naud on 12/04/2025.
//
import SwiftUI

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    
    @State private var showingAddSheet = false
    @State private var shoeToDelete: Shoe?
    @State private var showDeleteAlert = false
    @State private var shoeToArchive: Shoe?
    @State private var showArchiveAlert = false
    @State private var shoeToEdit: Shoe?
    @State private var showEditSheet = false
    
    var body: some View {
        TabView {
            NavigationStack {
                
                ShoeGridView(shoeToDelete: $shoeToDelete,
                             showDeleteAlert: $showDeleteAlert,
                             shoeToArchive: $shoeToArchive,
                             showArchiveAlert: $showArchiveAlert,
                             shoeToEdit: $shoeToEdit,
                             showEditSheet: $showEditSheet
                )
                .navigationTitle("Collection")
                .toolbar {
                    Button("Add") {
                        showingAddSheet.toggle()
                    }
                }
            }
            .tabItem { Label("Collection", systemImage: "shoe.2") }
            NavigationStack {
                ShoeListView()
                    .navigationTitle("Archive")
            }
                .tabItem {
                    Label("Archive", systemImage: "archivebox")
                }
        }
        .alert("Archive this shoe?", isPresented: $showArchiveAlert, presenting: shoeToArchive) { shoe in
            Button("Archive", role: .destructive) {
                shoe.archived = true
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
                .presentationDetents([.height(400)])
                .presentationDragIndicator(.hidden)
        }
        
        .sheet(isPresented: $showEditSheet) {
            if let shoeToEdit = shoeToEdit {
                EditPairView(shoeToEdit: shoeToEdit) // Passage direct de la valeur
                    .presentationDetents([.height(400)])
                    .presentationDragIndicator(.hidden)
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
}


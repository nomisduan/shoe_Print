//
//  ShoeRowView.swift
//  shoePrint
//
//  Created by Simon Naud on 12/04/2025.
//

import SwiftUI
import SwiftData

struct ShoeRowView: View {
    
    let shoe : Shoe
    var onUnarchive: () -> Void = {}
    var onDelete: () -> Void = {}
    
    @State private var showDeleteAlert = false
    
    var body: some View {
        ZStack {
                    RoundedRectangle(cornerRadius: 25)
                        .foregroundStyle(Color(shoe.color))
                        .frame(height: 120)

            HStack() {
                      
                        Text(shoe.icon)
                            .font(.system(size: 70))
                            .frame(width: 115)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(shoe.brand.uppercased())
                                .font(.title3)
                                .fontWeight(.black)
                                .italic()
                            Text(shoe.model)
                                
                            HStack(spacing: 2) {
                                Text(String(format: "%.0f", shoe.totalDistance))
                                    .fontDesign(.monospaced)
                                    .font(.title)
                                Text("km")
                            }
                            
                            if shoe.isActive {
                                HStack {
                                    Image(systemName: "circle.fill")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                    Text("Active")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                            }
                        }
                        
                Spacer()
                
                // Menu pour les chaussures archivées
                VStack {
                    Menu {
                        Button(action: {
                            onUnarchive()
                        }) {
                            Label("Unarchive", systemImage: "tray.and.arrow.up")
                        }
                        
                        Divider()
                        
                        Button(action: {
                            showDeleteAlert = true
                        }) {
                            Label("Delete", systemImage: "trash")
                                .foregroundColor(.red)
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title2)
                            .foregroundColor(.primary)
                    }
                    Spacer()
                }
                .padding(.trailing, 8)
                    }
                    .padding() // ajoute de l'espace intérieur
                    //.frame(maxWidth: .infinity, alignment: .leading) // aligne à gauche dans le ZStack
                }
                .frame(height: 120) // pour que le ZStack soit bien taillé
                .alert("Delete Shoe", isPresented: $showDeleteAlert) {
                    Button("Delete", role: .destructive) {
                        onDelete()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Are you sure you want to permanently delete \(shoe.brand) \(shoe.model)? This action cannot be undone.")
                }
            }
        }

#Preview {
    ShoeRowView(shoe: Shoe())
}

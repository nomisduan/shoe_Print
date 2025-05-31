//
//  AddAPairView.swift
//  shoePrint
//
//  Created by Simon Naud on 11/04/2025.
//

import SwiftUI
import SwiftData

struct AddAPairView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @State private var shoeBrand = ""
    @State private var shoeModel = ""
    @State private var shoeNotes = ""
    @State private var shoeIcon = "🩴"
    @State private var shoeColor = "CustomPink"
    @State private var purchaseDate = Date()
    @State private var purchasePrice = ""
    @State private var includePurchaseInfo = false
    @State private var estimatedLifespan = "800"
    
    let icons = ["🥾","👞","🩴","👟","🥿","👢","👡","🛼","⛸️","🩰","👠","🦶"]
    let colors = ["CustomPink", "CustomYellow", "CustomBlue", "CustomGreen", "CustomPurple", "CustomGray"]
    
    var body: some View {
        NavigationView {
            Form(){
                Section("Informations") {
                    TextField("BRAND", text: $shoeBrand)
                        .fontWeight(.black)
                        .autocapitalization(.allCharacters)
                        .italic()
                    TextField("Model", text: $shoeModel)
                    TextField("Notes (optional)", text: $shoeNotes, axis: .vertical)
                        .lineLimit(2...4)
                }
                
                Section("Purchase Information") {
                    Toggle("Include purchase details", isOn: $includePurchaseInfo)
                    
                    if includePurchaseInfo {
                        DatePicker("Purchase Date", selection: $purchaseDate, displayedComponents: .date)
                        
                        HStack {
                            TextField("Price", text: $purchasePrice)
                                .keyboardType(.decimalPad)
                            Text("€")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("Lifespan") {
                    HStack {
                        Text("Estimated lifespan")
                        Spacer()
                        TextField("800", text: $estimatedLifespan)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("km")
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Set the expected lifespan of your shoes in kilometers. This helps track wear progress.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Customization") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(icons, id: \.self) { icon in
                            Text(icon)
                                .font(icon == shoeIcon ? .system(size: 50) : .title)
                                .shadow(radius: icon == shoeIcon ? 5 : 0)
                                .padding(10)
                                .animation(.spring(), value: shoeIcon)
                                .onTapGesture {
                                    shoeIcon = icon
                                    // Auto-set lifespan based on shoe type
                                    switch icon {
                                    case "👟": estimatedLifespan = "800" // Running shoes
                                    case "🥾": estimatedLifespan = "1200" // Hiking boots
                                    case "👞": estimatedLifespan = "1000" // Dress shoes
                                    case "🩴": estimatedLifespan = "300" // Sandals
                                    case "👢": estimatedLifespan = "1000" // Boots
                                    default: estimatedLifespan = "600" // Default
                                    }
                                }
                            
                        }
                        }
                    }
                .frame(height: 40)
               
                   
                    HStack {
                            ForEach(colors, id: \.self) { customColor in
                                
                                ZStack {
                                        Circle()
                                        .foregroundStyle(customColor == shoeColor ?   .black : .white)
                                            .frame(height: 40)
                                    Circle()
                                        .foregroundStyle(Color(customColor))
                                        .frame(height: 35)
                                        .onTapGesture {
                                            shoeColor = customColor
                                        }
                                }
                                Spacer()
                        }
                    }
                }
            }
            .navigationTitle("New Pair")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { 
                        dismiss() 
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        // Création de la nouvelle paire de chaussures
                        let newShoe = Shoe(
                            brand: shoeBrand, 
                            model: shoeModel, 
                            notes: shoeNotes, 
                            icon: shoeIcon, 
                            color: shoeColor,
                            purchaseDate: includePurchaseInfo ? purchaseDate : nil,
                            purchasePrice: includePurchaseInfo && !purchasePrice.isEmpty ? Double(purchasePrice) : nil,
                            estimatedLifespan: Double(estimatedLifespan) ?? 800.0
                        )

                        // Insertion du modèle dans le contexte de données
                        context.insert(newShoe)
                        
                        // Enregistrement du contexte pour persister les changements
                        do {
                            try context.save() // Sauvegarder les changements
                            dismiss() // Fermer la vue une fois l'enregistrement réussi
                        } catch {
                            // En cas d'erreur lors de la sauvegarde
                            print("Error saving new shoe: \(error.localizedDescription)")
                        }
                    }
                    .disabled(shoeBrand.isEmpty || shoeModel.isEmpty || shoeIcon.isEmpty)
                }
            }
        }
    }
}

#Preview {
    AddAPairView()
}

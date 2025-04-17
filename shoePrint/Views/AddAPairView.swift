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
    
    let icons = ["🥾","👞","🩴","👟","🥿","👢","👡","🛼","⛸️","🩰","👠","🦶"]
    let colors = ["CustomPink", "CustomYellow", "CustomBlue", "CustomGreen", "CustomPurple", "CustomGray"]
    
    var body: some View {
        
        VStack(spacing: 0){
            HStack {
                            Button("Cancel") { dismiss() }
                            Spacer()
                            Text("New pair")
                                .font(.headline)
                            Spacer()
                            Button("Add") {
                                // Création de la nouvelle paire de chaussures
                                let newShoe = Shoe(brand: shoeBrand, model: shoeModel, icon: shoeIcon, color: shoeColor, entries: [])

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
            .padding()
                        .background(Color("FormGray"))
            Form(){
                Section("Informations") {
                    TextField("BRAND", text: $shoeBrand)
                        .fontWeight(.black)
                        .autocapitalization(.allCharacters)
                        .italic()
                    TextField("Model", text: $shoeModel)
                }
                
                
                //  TextField("Notes", text: $shoeNotes)
                //    .frame(height: 80, alignment: .top)
                
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
        }
    }
}

#Preview {
    AddAPairView()
}

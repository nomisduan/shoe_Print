//
//  EditPairView.swift
//  shoePrint
//
//  Created by Simon Naud on 14/04/2025.
//

import SwiftUI

struct EditPairView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @State private var shoeBrand: String
    @State private var shoeModel: String
    @State private var shoeNotes = ""
    @State private var shoeIcon: String
    @State private var shoeColor: String
    
    let icons = ["🥾","👞","🩴","👟","🥿","👢","👡","🛼","⛸️","🩰","👠","🦶"]
    let colors = ["CustomPink", "CustomYellow", "CustomBlue", "CustomGreen", "CustomPurple", "CustomGray"]
    
    var shoeToEdit: Shoe
    
    // Initialisation des valeurs de la chaussure à modifier
    init(shoeToEdit: Shoe) {
        self.shoeToEdit = shoeToEdit
        _shoeBrand = State(initialValue: shoeToEdit.brand)
        _shoeModel = State(initialValue: shoeToEdit.model)
        _shoeIcon = State(initialValue: shoeToEdit.icon)
        _shoeColor = State(initialValue: shoeToEdit.color)
    }
    
    var body: some View {
        
        VStack(spacing: 0){
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Text("Edit Pair")
                    .font(.headline)
                Spacer()
                Button("Save") {
                    // Modification de la chaussure existante
                    shoeToEdit.brand = shoeBrand
                    shoeToEdit.model = shoeModel
                    shoeToEdit.icon = shoeIcon
                    shoeToEdit.color = shoeColor
                    
                    // Enregistrement du contexte pour persister les changements
                    do {
                        try context.save() // Sauvegarder les changements
                        dismiss() // Fermer la vue une fois l'enregistrement réussi
                    } catch {
                        // En cas d'erreur lors de la sauvegarde
                        print("Error saving shoe: \(error.localizedDescription)")
                    }
                }
                .disabled(shoeBrand.isEmpty || shoeModel.isEmpty || shoeIcon.isEmpty)
            }
            .padding()
            .background(Color("FormGray"))
            
            Form {
                Section("Informations") {
                    TextField("BRAND", text: $shoeBrand)
                        .fontWeight(.black)
                        .autocapitalization(.allCharacters)
                        .italic()
                    TextField("Model", text: $shoeModel)
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
                                    }
                            }
                        }
                    }
                    .frame(height: 40)
                    
                    HStack {
                        ForEach(colors, id: \.self) { customColor in
                            ZStack {
                                Circle()
                                    .foregroundStyle(customColor == shoeColor ? .black : .white)
                                    .frame(height: 40)
                                Circle()
                                    .foregroundStyle(Color(customColor))
                                    .frame(height: 35)
                                    .onTapGesture {
                                        shoeColor = customColor
                                    }
                            }
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    EditPairView(shoeToEdit: Shoe(brand: "Nike", model: "Air Max", icon: "👟", color: "CustomBlue", entries: [])) // Exemple pour tester
}

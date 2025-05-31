//
//  ShoeListView.swift
//  shoePrint
//
//  Created by Simon Naud on 12/04/2025.
//

import SwiftUI
import SwiftData

struct ShoeListView: View {
    @Query private var shoes : [Shoe]
    
    var body: some View {
        ScrollView {
            VStack {
                
                
                VStack(){
                    ForEach(shoes.filter({ shoe in
                        shoe.archived == true
                    })) { shoe in
                        ShoeRowView(shoe: shoe)
                    }
                    
                }
               
            }
            .padding(.horizontal)
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)

    let container = try! ModelContainer(for: Shoe.self, configurations: config)

    let context = container.mainContext
    let _ = [
        Shoe(brand: "Nike", model: "Air Zoom", icon: "👟", color: "CustomPink", entries: []),
        Shoe(brand: "Palomon", model: "X Ultra", icon: "🥾", color: "CustomBlue", entries: []),
        Shoe(brand: "Birkenstock", model: "Classic", icon: "🥿", color: "CustomGreen", entries: []),
        Shoe(brand: "Nike", model: "Air Zoom", icon: "👟", color: "CustomPink", entries: []),
        Shoe(brand: "Salomon", model: "X Ultra", icon: "🥾", color: "CustomBlue", entries: []),
        Shoe(brand: "Birkenstock", model: "Classic", icon: "🥿", color: "CustomGreen", entries: [])
    ].forEach { context.insert($0) }

    return ShoeListView()
        .modelContainer(container)
}

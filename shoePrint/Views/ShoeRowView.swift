//
//  ShoeRowView.swift
//  shoePrint
//
//  Created by Simon Naud on 12/04/2025.
//

import SwiftUI

struct ShoeRowView: View {
    
    let shoe : Shoe
    
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
                                Text("0")
                                    .fontDesign(.monospaced)
                                    .font(.title)
                                Text("km")
                            }
                            
                           
                        }
                Spacer()
                    }
                    .padding() // ajoute de l’espace intérieur
                    //.frame(maxWidth: .infinity, alignment: .leading) // aligne à gauche dans le ZStack
                }
                .frame(height: 120) // pour que le ZStack soit bien taillé
            }
        }

#Preview {
    ShoeRowView(shoe: Shoe(entries: []))
}

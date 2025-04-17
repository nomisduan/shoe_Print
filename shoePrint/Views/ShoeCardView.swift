//
//  ShoeCardView.swift
//  shoePrint
//
//  Created by Simon Naud on 11/04/2025.
//

import SwiftUI
import SwiftData

struct ShoeCardView: View {
    let shoe : Shoe
    var onDelete: () -> Void = {}
    var onArchive: () -> Void = {}
    var onEdit: () -> Void = {}
    
    var body: some View {
        ZStack {
                    RoundedRectangle(cornerRadius: 25)
                        .foregroundStyle(Color(shoe.color))
                        .frame(width: 180, height: 250)

            
                    VStack(alignment: .leading) {
                        HStack{
                            Spacer()
                            Menu {
                                Group {
                                    Button(action: {
                                        onEdit()
                                    }) {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    Button(action: {
                                        onArchive()
                                    }) {
                                        Label("Archive", systemImage: "archivebox")
                                    }
                                    Divider()
                                    Button(action: {
                                        onDelete()
                                    }) {
                                        Label("Delete", systemImage: "trash")
                                            .foregroundColor(.red)
                                    }
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.title2)
                            }

                        }
                        
                        Spacer()
                        Text(shoe.icon)
                            .font(.system(size: 70))
                            .frame(maxWidth: .infinity, alignment: .center)
                        Spacer()
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
                    }
                    .padding() // ajoute de l’espace intérieur
                    .frame(maxWidth: .infinity, alignment: .leading) // aligne à gauche dans le ZStack
                }
                .frame(width: 190, height: 250) // pour que le ZStack soit bien taillé
            }
    
        }


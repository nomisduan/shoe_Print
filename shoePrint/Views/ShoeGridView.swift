//
//  ShoeGridView.swift
//  shoePrint
//
//  Created by Simon Naud on 11/04/2025.
//

import SwiftUI
import SwiftData

struct ShoeGridView: View {
    @Query private var shoes : [Shoe]
    @Binding var shoeToDelete: Shoe?
    @Binding var showDeleteAlert: Bool
    
    @Binding var shoeToArchive: Shoe?
    @Binding var showArchiveAlert: Bool
    
    @Binding var shoeToEdit: Shoe?
    @Binding var showEditSheet: Bool
   
    
    let columns = [
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20)
       ]

    
    var body: some View {
        ScrollView {
            VStack {
                HStack{
                    VStack(alignment: .leading){
                        HStack{
                            Image(systemName: "shoe.2.fill")
                                .foregroundStyle(.yellow)
                            Text("0")
                                .fontWeight(.semibold)
                        }
                        Text("Footwears")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Divider()
                    VStack(alignment: .leading){
                        HStack{
                            Image(systemName: "shoeprints.fill")
                                .foregroundStyle(.green)
                            Text("0")
                                .fontWeight(.semibold)
                        }
                        Text("Kilometers this year")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Divider()
                    VStack(alignment: .leading){
                        HStack{
                            Image(systemName: "wand.and.sparkles")
                                .foregroundStyle(.purple)
                            Text("0")
                                .fontWeight(.semibold)
                        }
                        Text("Repairs")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .frame(height: 50)
              
            
        
      
            LazyVGrid(columns: columns, spacing: 15) {
                ForEach(shoes.filter({ shoe in
                    shoe.archived == false
                })) { shoe in
                        ShoeCardView(shoe: shoe) {
                            shoeToDelete = shoe
                            showDeleteAlert = true
                        } onArchive: {
                            shoeToArchive = shoe
                            showArchiveAlert = true
                        } onEdit: {
                            shoeToEdit = shoe
                            showEditSheet = true
                        }
                }
            }
            }
            .padding(.horizontal)
        }
        //.padding(.horizontal)
        
    }
    
}



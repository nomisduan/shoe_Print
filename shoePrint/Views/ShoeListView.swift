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
    @Environment(\.modelContext) private var context
    
    var body: some View {
        ScrollView {
            VStack {
                
                
                VStack(){
                    ForEach(shoes.filter({ shoe in
                        shoe.archived == true
                    })) { shoe in
                        ShoeRowView(
                            shoe: shoe,
                            onUnarchive: {
                                shoe.unarchive()
                                try? context.save()
                            },
                            onDelete: {
                                context.delete(shoe)
                                try? context.save()
                            }
                        )
                    }
                    
                }
               
            }
            .padding(.horizontal)
        }
    }
}

#Preview {
    return ShoeListView()
        .modelContainer(PreviewContainer.previewModelContainer)
}

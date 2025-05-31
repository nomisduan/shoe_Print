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
    
    private var archivedShoes: [Shoe] {
        shoes.filter { $0.archived }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack {
                    if archivedShoes.isEmpty {
                        // Empty state
                        VStack(spacing: 20) {
                            Image(systemName: "archivebox")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            
                            Text("No Archived Shoes")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("Shoes you archive will appear here")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: geometry.size.height * 0.6)
                    } else {
                        // Archived shoes list
                        VStack(spacing: 12) {
                            ForEach(archivedShoes) { shoe in
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
                }
                .padding(.horizontal)
                .frame(minHeight: geometry.size.height)
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
}

#Preview {
    return ShoeListView()
        .modelContainer(PreviewContainer.previewModelContainer)
}

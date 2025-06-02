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
        if archivedShoes.isEmpty {
            // Empty state - centered in screen
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(UIColor.systemGroupedBackground))
        } else {
            // Archived shoes list
            ScrollView {
                LazyVStack(spacing: 12) {
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
                .padding(.top, 10) // Consistent top spacing
            }
            .padding(.horizontal) // Same horizontal padding as other screens
            .background(Color(UIColor.systemGroupedBackground))
        }
    }
}

#Preview {
    return ShoeListView()
        .modelContainer(PreviewContainer.previewModelContainer)
}

//
//  MiniShoeCardView.swift
//  shoePrint
//
//  Created by Simon Naud on 11/04/2025.
//

import SwiftUI
import SwiftData

/// Compact square shoe card for selection in attribution sheets
struct MiniShoeCardView: View {
    let shoe: Shoe
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .foregroundStyle(Color(shoe.color))
                    .aspectRatio(1.0, contentMode: .fit) // Square aspect ratio
                
                VStack(alignment: .leading) {
                    HStack {
                        // Active indicator in top leading
                        if shoe.isActive {
                            WearingIndicatorMini()
                        } else {
                            // Empty space to maintain alignment
                            HStack {
                                Text("")
                                    .font(.caption2)
                            }
                        }
                        
                        Spacer()
                    }
                    
                    Spacer()
                    
                    // Centered emoji
                    Text(shoe.icon)
                        .font(.system(size: 70))
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    Spacer()
                    
                    // Text aligned leading (bottom) - same fonts as ShoeCardView
                    VStack(alignment: .leading, spacing: 2) {
                        Text(shoe.brand.uppercased())
                            .font(.title3)
                            .fontWeight(.black)
                            .italic()
                        Text(shoe.model)
                            .font(.body)
                    }
                }
                .padding(12) // Interior spacing
                .frame(maxWidth: .infinity, alignment: .leading) // Left aligned in ZStack
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Mini animated wearing indicator with pulse effect
struct WearingIndicatorMini: View {
    @State private var isPulsing = false
    
    var body: some View {
        HStack {
            Image(systemName: "circle.fill")
                .foregroundColor(.green)
                .font(.caption2)
                .scaleEffect(isPulsing ? 1.2 : 1.0)
                .opacity(isPulsing ? 0.6 : 1.0)
                .animation(
                    Animation.easeInOut(duration: 1.0)
                        .repeatForever(autoreverses: true),
                    value: isPulsing
                )
            Text("Wearing")
                .font(.caption2)
                .fontWeight(.medium)
        }
        .onAppear {
            isPulsing = true
        }
    }
} 

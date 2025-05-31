//
//  HealthKitSetupView.swift
//  shoePrint
//
//  Created by Simon Naud on 11/04/2025.
//

import SwiftUI

/// Main setup view for HealthKit integration
/// Guides users through permission setup and explains the benefits
struct HealthKitSetupView: View {
    @ObservedObject var healthKitViewModel: HealthKitViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                headerSection
                
                // Benefits section
                benefitsSection
                
                Spacer()
                
                // Action buttons
                actionSection
            }
            .padding(.horizontal, 24)
            .navigationTitle("HealthKit Integration")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.red)
            
            Text("Track Your Steps")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Connect with Apple Health to automatically track your walking sessions and sync them with your shoes.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            benefitRow(
                icon: "figure.walk",
                title: "Automatic Tracking",
                description: "No manual entry needed"
            )
            
            benefitRow(
                icon: "chart.line.uptrend.xyaxis",
                title: "Detailed Analytics",
                description: "See your progress over time"
            )
            
            benefitRow(
                icon: "shoe.2.fill",
                title: "Per-Shoe Insights",
                description: "Track which shoes you use most"
            )
            
            benefitRow(
                icon: "shield.checkered",
                title: "Privacy Protected",
                description: "Your data stays on your device"
            )
        }
        .padding(.vertical)
    }
    
    private func benefitRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    private var actionSection: some View {
        VStack(spacing: 12) {
            Button(action: {
                Task {
                    await healthKitViewModel.requestPermissions()
                }
            }) {
                HStack {
                    if healthKitViewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "heart.fill")
                    }
                    
                    Text(healthKitViewModel.isLoading ? "Requesting Access..." : "Connect to Health")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.blue)
                )
            }
            .disabled(healthKitViewModel.isLoading)
            
            if let errorMessage = healthKitViewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

#Preview {
    let mockViewModel = HealthKitViewModel(
        modelContext: PreviewContainer.previewModelContext,
        healthKitManager: HealthKitManager()
    )
    
    HealthKitSetupView(healthKitViewModel: mockViewModel)
        .modelContainer(PreviewContainer.previewModelContainer)
} 
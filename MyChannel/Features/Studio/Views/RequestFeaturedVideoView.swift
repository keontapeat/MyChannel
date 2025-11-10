//
//  RequestFeaturedVideoView.swift
//  MyChannel
//
//  User-facing view for requesting featured video placement with payment
//

import SwiftUI
import StoreKit

struct RequestFeaturedVideoView: View {
    let video: Video
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var paymentService = FeaturedVideoPaymentService.shared
    @State private var selectedDuration: FeaturedVideoRequest.FeaturedDuration = .oneWeek
    @State private var customDays: Int = 7
    @State private var isProcessing: Bool = false
    @State private var showingSuccess: Bool = false
    @State private var lastError: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Video Info
                    videoInfoSection
                    
                    // Duration Selection
                    durationSelectionSection
                    
                    // Price Display
                    priceSection
                    
                    // Purchase Button
                    purchaseButton
                    
                    // Error Display
                    if let error = lastError {
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                }
                .padding()
            }
            .navigationTitle("Feature Your Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                Task {
                    await paymentService.loadProducts()
                }
            }
            .alert("Success!", isPresented: $showingSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your featured video request has been submitted! We'll review it and feature your video if approved.")
            }
        }
    }
    
    // MARK: - Video Info Section
    private var videoInfoSection: some View {
        HStack(spacing: 16) {
            AppAsyncImage(url: URL(string: video.thumbnailURL)) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                Color.gray.opacity(0.3)
            }
            .frame(width: 160, height: 90)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 8) {
                Text(video.title)
                    .font(.headline)
                    .lineLimit(3)
                
                Text("by \(video.creator.displayName)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Duration Selection Section
    private var durationSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Feature Duration")
                .font(.headline)
            
            VStack(spacing: 12) {
                ForEach(FeaturedVideoRequest.FeaturedDuration.allCases.filter { $0 != .custom }, id: \.self) { duration in
                    Button {
                        selectedDuration = duration
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(duration.displayName)
                                    .font(.body)
                                    .fontWeight(.semibold)
                                Text("\(duration.days) day\(duration.days == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text("$\(String(format: "%.2f", paymentService.getPrice(for: duration)))")
                                .font(.headline)
                                .foregroundColor(selectedDuration == duration ? .white : .primary)
                            
                            if selectedDuration == duration {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.white)
                            }
                        }
                        .padding()
                        .background(
                            selectedDuration == duration
                                ? LinearGradient(
                                    colors: [AppTheme.Colors.primary, AppTheme.Colors.secondary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                : LinearGradient(
                                    colors: [Color(.systemGray6)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - Price Section
    private var priceSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Total")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("$\(String(format: "%.2f", paymentService.getPrice(for: selectedDuration)))")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.Colors.primary)
            }
            
            Text("Your video will be reviewed before being featured")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Purchase Button
    private var purchaseButton: some View {
        Button {
            Task {
                await purchaseFeatured()
            }
        } label: {
            HStack {
                if isProcessing {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Text("Purchase & Request Feature")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: [AppTheme.Colors.primary, AppTheme.Colors.secondary],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isProcessing || paymentService.isLoading)
        .padding(.vertical)
    }
    
    // MARK: - Purchase Action
    private func purchaseFeatured() async {
        isProcessing = true
        lastError = nil
        
        do {
            let request = try await paymentService.purchaseFeaturedVideo(
                video: video,
                duration: selectedDuration,
                customDays: nil
            )
            
            await MainActor.run {
                isProcessing = false
                showingSuccess = true
            }
        } catch {
            await MainActor.run {
                isProcessing = false
                lastError = error.localizedDescription
            }
        }
    }
}





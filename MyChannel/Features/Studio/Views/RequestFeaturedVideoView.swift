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
    @State private var isProcessing: Bool = false
    @State private var showingSuccess: Bool = false
    @State private var lastError: String?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    videoInfoSection
                    durationSelectionSection
                    Divider()
                    priceSection
                    purchaseButton
                    approvalNotice

                    if let error = lastError {
                        Text(error)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Spacer(minLength: 32)
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Feature Your Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.primary)
                }
            }
            .onAppear {
                Task { await paymentService.loadProducts() }
            }
            .alert("Request Submitted", isPresented: $showingSuccess) {
                Button("Got It") { dismiss() }
            } message: {
                Text("Your payment was processed. We'll review your video and feature it within 24 hours if approved.")
            }
        }
    }

    // MARK: - Video Info Section
    private var videoInfoSection: some View {
        HStack(spacing: 14) {
            // Thumbnail — always visible, handles asset:// and remote URLs
            Group {
                if video.thumbnailURL.hasPrefix("asset://"),
                   let assetName = video.thumbnailURL.split(separator: "/").last.map(String.init),
                   !assetName.isEmpty {
                    Image(assetName)
                        .resizable()
                        .scaledToFill()
                } else if !video.thumbnailURL.isEmpty, let url = URL(string: video.thumbnailURL) {
                    AppAsyncImage(url: url) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        Color(.systemGray5)
                            .overlay(
                                Image(systemName: "play.rectangle.fill")
                                    .foregroundColor(Color(.systemGray3))
                            )
                    }
                } else {
                    Color(.systemGray5)
                        .overlay(
                            Image(systemName: "play.rectangle.fill")
                                .foregroundColor(Color(.systemGray3))
                        )
                }
            }
            .frame(width: 140, height: 79)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(video.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(3)

                Text("by \(video.creator.displayName)")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(14)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Duration Selection
    private var durationSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Feature Duration")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)

            VStack(spacing: 8) {
                ForEach(FeaturedVideoRequest.FeaturedDuration.allCases.filter { $0 != .custom }, id: \.self) { duration in
                    durationRow(duration)
                }
            }
        }
    }

    private func durationRow(_ duration: FeaturedVideoRequest.FeaturedDuration) -> some View {
        let isSelected = selectedDuration == duration
        return Button {
            selectedDuration = duration
            HapticManager.shared.impact(style: .light)
        } label: {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(duration.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(isSelected ? .white : .primary)
                    Text("\(duration.days) day\(duration.days == 1 ? "" : "s")")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(isSelected ? .white.opacity(0.75) : .secondary)
                }

                Spacer()

                Text("$\(String(format: "%.2f", paymentService.getPrice(for: duration)))")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .primary)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.leading, 10)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color(.label) : Color(.systemGray6))
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    // MARK: - Price Section
    private var priceSection: some View {
        HStack {
            Text("Total")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.primary)

            Spacer()

            Text("$\(String(format: "%.2f", paymentService.getPrice(for: selectedDuration)))")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Purchase Button
    private var purchaseButton: some View {
        Button {
            Task { await purchaseFeatured() }
        } label: {
            HStack(spacing: 10) {
                if isProcessing {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(0.9)
                } else {
                    Image(systemName: "star.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Purchase & Request Feature")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.label))
            )
        }
        .disabled(isProcessing || paymentService.isLoading)
    }

    // MARK: - Approval Notice
    private var approvalNotice: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            Text("Your video will be reviewed before being featured. Approval typically within 24 hours.")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Purchase Action
    private func purchaseFeatured() async {
        isProcessing = true
        lastError = nil

        do {
            _ = try await paymentService.purchaseFeaturedVideo(
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














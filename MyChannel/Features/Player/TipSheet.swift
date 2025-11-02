//
//  TipSheet.swift
//  MyChannel
//
//  Real tip payment interface with Stripe integration
//

import SwiftUI
import StoreKit

struct TipSheet: View {
    let video: Video
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthenticationManager
    
    @StateObject private var tipService = TipPaymentService.shared
    @State private var selectedAmount: Double = 5.0
    @State private var customAmount: String = ""
    @State private var message: String = ""
    @State private var isProcessing: Bool = false
    @State private var showingSuccess: Bool = false
    @State private var lastError: String?
    @State private var showingPaymentSheet: Bool = false
    
    private let predefinedAmounts: [Double] = [1, 5, 10, 25, 50, 100]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Creator Info
                    creatorInfoSection
                    
                    // Amount Selection
                    amountSelectionSection
                    
                    // Message Input
                    messageInputSection
                    
                    // Payment Button
                    paymentButton
                    
                    // Error Display
                    if let error = lastError {
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                    
                    // Terms
                    termsSection
                }
                .padding()
            }
            .navigationTitle("Tip Creator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Tip Sent!", isPresented: $showingSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your tip of $\(String(format: "%.2f", selectedAmount)) has been sent to \(video.creator.displayName). Thank you for supporting creators!")
            }
        }
        .disabled(isProcessing)
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.pink, Color.red],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            Text("Support This Creator")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Show your appreciation with a tip. 100% goes to the creator!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    // MARK: - Creator Info Section
    private var creatorInfoSection: some View {
        HStack(spacing: 12) {
            AppAsyncImage(url: URL(string: video.creator.profileImageURL ?? "")) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                Color.gray.opacity(0.3)
            }
            .frame(width: 60, height: 60)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(video.creator.displayName)
                    .font(.headline)
                
                Text("@\(video.creator.username)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Amount Selection Section
    private var amountSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tip Amount")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Predefined Amounts
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                ForEach(predefinedAmounts, id: \.self) { amount in
                    Button {
                        selectedAmount = amount
                        customAmount = ""
                    } label: {
                        VStack(spacing: 4) {
                            Text("$\(Int(amount))")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(selectedAmount == amount ? .white : .primary)
                            
                            if amount == predefinedAmounts.first {
                                Text("Min")
                                    .font(.caption2)
                                    .foregroundColor(selectedAmount == amount ? .white.opacity(0.8) : .secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            selectedAmount == amount
                                ? LinearGradient(
                                    colors: [Color.pink, Color.red],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                : LinearGradient(
                                    colors: [Color(.systemGray6)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                        )
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedAmount == amount ? Color.clear : Color(.systemGray4), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Custom Amount
            VStack(alignment: .leading, spacing: 8) {
                Text("Custom Amount")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    Text("$")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    
                    TextField("Enter amount", text: $customAmount)
                        .keyboardType(.decimalPad)
                        .font(.title3)
                        .onChange(of: customAmount) { newValue in
                            if let amount = Double(newValue), amount >= 1 {
                                selectedAmount = amount
                            }
                        }
                    
                    if !customAmount.isEmpty {
                        Button {
                            customAmount = ""
                            selectedAmount = predefinedAmounts.first ?? 1.0
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Message Input Section
    private var messageInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add a Message (Optional)")
                .font(.headline)
                .fontWeight(.semibold)
            
            TextField("Say something nice!", text: $message, axis: .vertical)
                .textFieldStyle(.plain)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .lineLimit(3...6)
            
            Text("\(message.count)/200 characters")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Payment Button
    private var paymentButton: some View {
        Button {
            Task {
                await sendTip()
            }
        } label: {
            HStack {
                if isProcessing {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Image(systemName: "heart.fill")
                    Text("Send $\(String(format: "%.2f", selectedAmount)) Tip")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.pink, Color.red],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(12)
            .shadow(color: .pink.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .disabled(isProcessing || selectedAmount < 1 || tipService.isLoading)
    }
    
    // MARK: - Terms Section
    private var termsSection: some View {
        VStack(spacing: 8) {
            Text("By sending a tip, you agree to our Terms of Service")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text("100% of your tip goes to the creator. Payment processing fees are covered by MyChannel.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    // MARK: - Send Tip
    private func sendTip() async {
        guard selectedAmount >= 1.0 else {
            lastError = "Minimum tip amount is $1.00"
            return
        }
        
        guard let currentUserId = authManager.currentUser?.id else {
            lastError = "Please sign in to send a tip"
            return
        }
        
        isProcessing = true
        lastError = nil
        
        do {
            // Process real payment via Stripe
            let tip = try await tipService.processTip(
                to: video.creatorId,
                amount: selectedAmount,
                currency: "usd",
                message: message.isEmpty ? nil : message
            )
            
            // Send notification to creator
            await sendTipNotification(tip: tip)
            
            await MainActor.run {
                isProcessing = false
                showingSuccess = true
            }
            
            // Haptic feedback
            HapticManager.shared.notification(type: .success)
            
        } catch {
            await MainActor.run {
                isProcessing = false
                lastError = error.localizedDescription
            }
            
            HapticManager.shared.notification(type: .error)
        }
    }
    
    // MARK: - Send Notification
    private func sendTipNotification(tip: TipTransaction) async {
        // Send push notification to creator
        let notificationData: [String: String] = [
            "type": "tip",
            "title": "💰 New Tip Received!",
            "message": "You received a $\(String(format: "%.2f", tip.amount)) tip from \(authManager.currentUser?.displayName ?? "Someone")",
            "tipId": tip.id,
            "videoId": video.id
        ]
        
        await PushNotificationService.shared.sendNotification(
            to: tip.toCreatorId,
            notification: notificationData
        )
    }
}


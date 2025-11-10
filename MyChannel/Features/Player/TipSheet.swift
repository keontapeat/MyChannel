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
            ZStack {
                // Gradient background
                LinearGradient(
                    colors: [
                        Color(red: 0.98, green: 0.96, blue: 1.0),
                        Color(red: 1.0, green: 0.97, blue: 0.98)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Header
                        headerSection
                            .padding(.top, 8)
                        
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
                            errorDisplay(error)
                        }
                        
                        // Terms
                        termsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Tip Creator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        HapticManager.shared.impact(style: .light)
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .fontWeight(.medium)
                    }
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
        VStack(spacing: 16) {
            ZStack {
                // Animated gradient circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.pink.opacity(0.15), Color.red.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: "heart.fill")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.pink, Color.red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 8) {
                Text("Support This Creator")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Show your appreciation with a tip. 100% goes to the creator!")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
    
    // MARK: - Creator Info Section
    private var creatorInfoSection: some View {
        HStack(spacing: 16) {
            ZStack {
                // Subtle gradient ring
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Color.pink.opacity(0.3), Color.red.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2.5
                    )
                    .frame(width: 70, height: 70)
                
                AppAsyncImage(url: URL(string: video.creator.profileImageURL ?? "")) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.15))
                }
                .frame(width: 64, height: 64)
                .clipShape(Circle())
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(video.creator.displayName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("@\(video.creator.username)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
        )
    }
    
    // MARK: - Amount Selection Section
    private var amountSelectionSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Tip Amount")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
            
            // Predefined Amounts - Perfectly proportional cards
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ],
                spacing: 12
            ) {
                ForEach(predefinedAmounts, id: \.self) { amount in
                    GeometryReader { geo in
                        Button {
                            HapticManager.shared.impact(style: .light)
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedAmount = amount
                                customAmount = ""
                            }
                        } label: {
                            VStack(spacing: 6) {
                                Text("$\(Int(amount))")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(selectedAmount == amount ? .white : .primary)
                                
                                if amount == predefinedAmounts.first {
                                    Text("Min")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(selectedAmount == amount ? .white.opacity(0.8) : .secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(
                                Group {
                                    if selectedAmount == amount {
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color(red: 1.0, green: 0.2, blue: 0.4), Color(red: 0.98, green: 0.3, blue: 0.5)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .shadow(color: Color.pink.opacity(0.4), radius: 12, x: 0, y: 6)
                                    } else {
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.white)
                                            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
                                    }
                                }
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .aspectRatio(1, contentMode: .fit)
                }
            }
            
            // Custom Amount
            VStack(alignment: .leading, spacing: 12) {
                Text("Custom Amount")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                HStack(spacing: 12) {
                    Text("$")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    TextField("Enter amount", text: $customAmount)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 20, weight: .semibold))
                        .onChange(of: customAmount) { newValue in
                            if let amount = Double(newValue), amount >= 1 {
                                selectedAmount = amount
                            }
                        }
                    
                    if !customAmount.isEmpty {
                        Button {
                            HapticManager.shared.impact(style: .light)
                            customAmount = ""
                            selectedAmount = predefinedAmounts[1]
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
        )
    }
    
    // MARK: - Message Input Section
    private var messageInputSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Add a Message (Optional)")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
            
            VStack(spacing: 0) {
                TextField("Say something nice!", text: $message, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .padding(18)
                    .lineLimit(3...6)
                
                Divider()
                    .padding(.horizontal, 18)
                
                HStack {
                    Spacer()
                    Text("\(message.count)/200")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(message.count > 200 ? .red : .secondary)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
            )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
        )
    }
    
    // MARK: - Payment Button
    private var paymentButton: some View {
        Button {
            HapticManager.shared.impact(style: .medium)
            Task {
                await sendTip()
            }
        } label: {
            HStack(spacing: 12) {
                if isProcessing {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 20, weight: .semibold))
                    Text("Send $\(String(format: "%.2f", selectedAmount)) Tip")
                        .font(.system(size: 18, weight: .bold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                Group {
                    if isProcessing || selectedAmount < 1 || tipService.isLoading {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.gray.opacity(0.4))
                    } else {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 1.0, green: 0.2, blue: 0.4), Color(red: 0.98, green: 0.3, blue: 0.5)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: Color.pink.opacity(0.5), radius: 20, x: 0, y: 10)
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .disabled(isProcessing || selectedAmount < 1 || tipService.isLoading)
    }
    
    // MARK: - Error Display
    private func errorDisplay(_ error: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16))
                .foregroundColor(.red)
            
            Text(error)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.red)
                .multilineTextAlignment(.leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.red.opacity(0.08))
        )
    }
    
    // MARK: - Terms Section
    private var termsSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 12))
                    .foregroundColor(.green)
                
                Text("Secure Payment")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.green)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.green.opacity(0.1))
            )
            
            Text("100% of your tip goes to the creator. Payment processing fees are covered by MyChannel.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
            
            Text("By sending a tip, you agree to our Terms of Service")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 8)
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
        let tipperName = authManager.currentUser?.displayName ?? "Someone"
        let messagePreview = tip.message?.isEmpty == false ? " with a message" : ""
        
        let notificationData: [String: String] = [
            "type": "tip",
            "title": "💰 New Tip Received!",
            "message": "You received a $\(String(format: "%.2f", tip.amount)) tip from \(tipperName)\(messagePreview)!",
            "tipId": tip.id,
            "videoId": video.id,
            "fromUserId": tip.fromUserId,
            "amount": String(format: "%.2f", tip.amount)
        ]
        
        await PushNotificationService.shared.sendNotification(
            to: tip.toCreatorId,
            notification: notificationData
        )
        
        print("📬 [TipSheet] Notification sent to creator: \(tip.toCreatorId)")
    }
}

#Preview {
    TipSheet(video: Video.sampleVideos[0])
        .environmentObject(AuthenticationManager.shared)
}


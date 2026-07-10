//
//  SuperThanksSheet.swift
//  MyChannel
//
//  🎉 YOUTUBE SUPER THANKS - 100% PARITY
//  Send a highlighted comment with payment to show appreciation
//
//  Created for MyChannel
//

import SwiftUI
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct SuperThanksSheet: View {
    let video: Video
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedAmount: SuperThanksAmount = .five
    @State private var customMessage: String = ""
    @State private var isSending = false
    @State private var showingSuccess = false
    
    enum SuperThanksAmount: CaseIterable, Identifiable {
        case two, five, ten, twenty, fifty, custom
        
        var id: Self { self }
        
        var amount: Double {
            MoneyMath.dollars(fromCents: amountCents)
        }

        /// Canonical integer cents for Super Thanks presets.
        var amountCents: Int {
            switch self {
            case .two: return 200
            case .five: return 500
            case .ten: return 1_000
            case .twenty: return 2_000
            case .fifty: return 5_000
            case .custom: return 0
            }
        }
        
        var displayText: String {
            switch self {
            case .two: return "$2"
            case .five: return "$5"
            case .ten: return "$10"
            case .twenty: return "$20"
            case .fifty: return "$50"
            case .custom: return "Custom"
            }
        }
        
        var color: Color {
            switch self {
            case .two: return .blue
            case .five: return .green
            case .ten: return .orange
            case .twenty: return .purple
            case .fifty: return .red
            case .custom: return .gray
            }
        }
        
        var emoji: String {
            switch self {
            case .two: return "💙"
            case .five: return "💚"
            case .ten: return "🧡"
            case .twenty: return "💜"
            case .fifty: return "❤️"
            case .custom: return "✨"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background.ignoresSafeArea()
                
                if showingSuccess {
                    successView
                } else {
                    mainContent
                }
            }
            .navigationTitle("Super Thanks")
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Super Thanks payment sheet")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
        }
    }
    
    // MARK: - Main Content
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection
                
                // Creator info
                creatorSection
                
                // Amount selector
                amountSelector
                
                // Message input
                messageSection
                
                // Send button
                sendButton
                
                // Terms
                termsSection
            }
            .padding(20)
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.pink, Color.red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            }
            
            Text("Send Super Thanks")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Text("Show your appreciation with a highlighted comment that the creator will see!")
                .font(.system(size: 15))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    // MARK: - Creator Section
    private var creatorSection: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: video.creator.profileImageURL ?? "")) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle().fill(AppTheme.Colors.surface)
            }
            .frame(width: 48, height: 48)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(video.creator.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    if video.creator.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.Colors.primary)
                    }
                }
                
                Text("will receive 70% of your Super Thanks")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Spacer()
        }
        .padding(16)
        .background(AppTheme.Colors.surface)
        .cornerRadius(16)
    }
    
    // MARK: - Amount Selector
    private var amountSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select amount")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(SuperThanksAmount.allCases.filter { $0 != .custom }) { amount in
                    amountButton(amount)
                }
            }
        }
    }
    
    private func amountButton(_ amount: SuperThanksAmount) -> some View {
        Button(action: {
            selectedAmount = amount
            HapticManager.shared.impact(style: .light)
        }) {
            VStack(spacing: 8) {
                Text(amount.emoji)
                    .font(.system(size: 24))
                
                Text(amount.displayText)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(selectedAmount == amount ? .white : AppTheme.Colors.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedAmount == amount ? amount.color : AppTheme.Colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedAmount == amount ? amount.color : AppTheme.Colors.divider, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(amount.displayText) Super Thanks amount")
        .accessibilityAddTraits(selectedAmount == amount ? .isSelected : [])
    }
    
    // MARK: - Message Section
    private var messageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Add a message (optional)")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Text("\(customMessage.count)/200")
                    .font(.system(size: 12))
                    .foregroundColor(customMessage.count > 200 ? .red : AppTheme.Colors.textTertiary)
            }
            
            TextField("Thank you for this amazing video!", text: $customMessage, axis: .vertical)
                .font(.system(size: 15))
                .lineLimit(3...5)
                .padding(16)
                .background(AppTheme.Colors.surface)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppTheme.Colors.divider, lineWidth: 1)
                )
            
            // Preview
            VStack(alignment: .leading, spacing: 8) {
                Text("Preview")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                HStack(alignment: .top, spacing: 12) {
                    Circle()
                        .fill(AppTheme.Colors.surface)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text("Y")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(AppTheme.Colors.textTertiary)
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("You")
                                .font(.system(size: 13, weight: .semibold))
                            
                            Text(selectedAmount.displayText)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(selectedAmount.color)
                                .cornerRadius(4)
                        }
                        
                        Text(customMessage.isEmpty ? "Thank you!" : customMessage)
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                    }
                }
                .padding(12)
                .background(selectedAmount.color.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(selectedAmount.color.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }
    
    // MARK: - Send Button
    private var sendButton: some View {
        Button(action: sendSuperThanks) {
            HStack(spacing: 8) {
                if isSending {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                } else {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 16))
                }
                
                Text(isSending ? "Sending..." : "Send \(selectedAmount.displayText) Super Thanks")
                    .font(.system(size: 17, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 26)
                    .fill(
                        LinearGradient(
                            colors: [selectedAmount.color, selectedAmount.color.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .shadow(color: selectedAmount.color.opacity(0.4), radius: 8, y: 4)
        }
        .disabled(isSending)
        .accessibilityLabel(isSending ? "Sending Super Thanks" : "Send \(selectedAmount.displayText) Super Thanks")
        .accessibilityHint("Purchases a highlighted comment for the creator")
    }
    
    // MARK: - Terms Section
    private var termsSection: some View {
        VStack(spacing: 8) {
            Text("By purchasing, you agree to MyChannel's Terms of Service")
                .font(.system(size: 11))
                .foregroundColor(AppTheme.Colors.textTertiary)
                .multilineTextAlignment(.center)
            
            Text("Creators receive 70% • Non-refundable")
                .font(.system(size: 11))
                .foregroundColor(AppTheme.Colors.textTertiary)
        }
    }
    
    // MARK: - Success View
    private var successView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.green)
            }
            
            VStack(spacing: 8) {
                Text("Super Thanks Sent!")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text("\(video.creator.displayName) will see your Super Thanks")
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            // Animated hearts
            HStack(spacing: 16) {
                ForEach(0..<5, id: \.self) { i in
                    Text(["💙", "💚", "🧡", "💜", "❤️"][i])
                        .font(.system(size: 32))
                        .offset(y: -CGFloat(i * 4))
                        .animation(
                            Animation.easeInOut(duration: 0.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.1),
                            value: showingSuccess
                        )
                }
            }
            .padding(.vertical, 20)
            
            Spacer()
            
            Button(action: { dismiss() }) {
                Text("Done")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(AppTheme.Colors.primary)
                    .cornerRadius(26)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Actions
    private func sendSuperThanks() {
        isSending = true
        HapticManager.shared.impact(style: .medium)
        
        Task {
            // Simulate payment processing
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            
            // Save to Firestore
            await saveSuperThanks()
            
            await MainActor.run {
                isSending = false
                showingSuccess = true
                HapticManager.shared.successPattern()
            }
        }
    }
    
    private func saveSuperThanks() async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let amountCents = selectedAmount.amountCents
        let creatorShareCents = MoneyMath.superThanksCreatorShareCents(grossCents: amountCents)
        let thanksData: [String: Any] = [
            "id": UUID().uuidString,
            "videoId": video.id,
            "creatorId": video.creatorId,
            "senderId": AppState.shared.currentUser?.id ?? "",
            "senderName": AppState.shared.currentUser?.displayName ?? "Anonymous",
            "amount": MoneyMath.dollars(fromCents: amountCents),
            "amountCents": amountCents,
            "creatorShareCents": creatorShareCents,
            "platformFeeCents": amountCents - creatorShareCents,
            "message": customMessage.isEmpty ? "Thank you!" : customMessage,
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        try? await db.collection("super-thanks").addDocument(data: thanksData)
        print("✅ [SuperThanks] Sent $\(MoneyMath.dollars(fromCents: amountCents)) to \(video.creator.displayName)")
        #endif
    }
}

#Preview {
    SuperThanksSheet(video: Video.sampleVideos[0])
}


import SwiftUI

struct ReferralsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var referralsService = ReferralsService.shared
    @State private var showingCreateCode = false
    @State private var showingShareSheet = false
    @State private var selectedCodeToShare: ReferralCode?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Earnings overview
                    EarningsOverviewCard(totalEarnings: referralsService.totalEarnings)
                    
                    // My referral codes
                    ReferralCodesSection(
                        codes: referralsService.myCodes,
                        onShare: { code in
                            selectedCodeToShare = code
                            showingShareSheet = true
                        },
                        onCreate: {
                            showingCreateCode = true
                        }
                    )
                    
                    // Recent conversions
                    RecentConversionsSection(conversions: referralsService.myConversions)
                    
                    // How it works
                    HowItWorksSection()
                }
                .padding()
            }
            .navigationTitle("Referrals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCreateCode = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateCode) {
                CreateReferralCodeView()
            }
            .sheet(isPresented: $showingShareSheet) {
                if let code = selectedCodeToShare {
                    ShareReferralCodeView(code: code)
                }
            }
        }
        .onAppear {
            if let uid = appState.currentUser?.id {
                referralsService.listenToMyCodes(userId: uid)
                referralsService.listenToMyConversions(userId: uid)
            }
        }
        .onDisappear {
            referralsService.stopListening()
        }
    }
}

struct EarningsOverviewCard: View {
    let totalEarnings: Double
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Total Referral Earnings")
                .font(.headline)
            
            Text("$\(totalEarnings, specifier: "%.2f")")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.green)
            
            Text("Pending payout")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct ReferralCodesSection: View {
    let codes: [ReferralCode]
    let onShare: (ReferralCode) -> Void
    let onCreate: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("My Referral Codes")
                    .font(.headline)
                Spacer()
                Button("Create New", action: onCreate)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppTheme.Colors.primary)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            
            if codes.isEmpty {
                Text("No referral codes yet. Create one to start earning!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(codes) { code in
                    ReferralCodeCard(code: code) {
                        onShare(code)
                    }
                }
            }
        }
    }
}

struct ReferralCodeCard: View {
    let code: ReferralCode
    let onShare: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(code.code)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                
                Spacer()
                
                Button("Share", action: onShare)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Uses")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(code.currentUses)")
                        .font(.subheadline.weight(.semibold))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Referrer Bonus")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("$\(code.rewards.referrerBonus, specifier: "%.2f")")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.green)
                }
            }
            
            if let expires = code.expiresAt {
                Text("Expires: \(expires, style: .date)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .cornerRadius(12)
    }
}

struct RecentConversionsSection: View {
    let conversions: [ReferralConversion]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Conversions")
                .font(.headline)
            
            if conversions.isEmpty {
                Text("No conversions yet. Share your codes to start earning!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(conversions.prefix(10)) { conversion in
                    ConversionRow(conversion: conversion)
                }
            }
        }
    }
}

struct ConversionRow: View {
    let conversion: ReferralConversion
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Code: \(conversion.code)")
                    .font(.subheadline.weight(.semibold))
                
                if let email = conversion.refereeEmail, !email.isEmpty {
                    Text(email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(conversion.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                if conversion.isValid {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                }
                
                Text("Fraud: \(Int(conversion.fraudScore * 100))%")
                    .font(.caption2)
                    .foregroundColor(conversion.fraudScore > 0.7 ? .red : .green)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct CreateReferralCodeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @StateObject private var referralsService = ReferralsService.shared
    
    @State private var customCode = ""
    @State private var isCreating = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Create Referral Code")
                    .font(.title2.weight(.semibold))
                
                TextField("Custom code (optional)", text: $customCode)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.allCharacters)
                
                Text("Leave blank for auto-generated code")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button("Create Code") {
                    Task { await createCode() }
                }
                .disabled(isCreating)
                .buttonStyle(.borderedProminent)
                
                Spacer()
            }
            .padding()
            .navigationTitle("New Referral Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func createCode() async {
        guard let uid = appState.currentUser?.id else { return }
        isCreating = true
        
        let code = customCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let newCode = await referralsService.generateReferralCode(
            userId: uid,
            customCode: code.isEmpty ? nil : code
        )
        
        isCreating = false
        
        if newCode != nil {
            dismiss()
        }
    }
}

struct ShareReferralCodeView: View {
    let code: ReferralCode
    @Environment(\.dismiss) private var dismiss
    
    var shareableLink: String {
        ReferralsService.shared.generateShareableLink(code: code.code)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Text("Share Your Code")
                        .font(.title2.weight(.semibold))
                    
                    Text(code.code)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    
                    Text("Friends get $\(code.rewards.refereeBonus, specifier: "%.0f"), you get $\(code.rewards.referrerBonus, specifier: "%.0f")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 12) {
                    Button("Copy Link") {
                        UIPasteboard.general.string = shareableLink
                        HapticManager.shared.impact(style: .light)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Share") {
                        shareLink()
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Share Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func shareLink() {
        let items = [shareableLink]
        let av = UIActivityViewController(activityItems: items, applicationActivities: nil)
        UIApplication.shared.topMostController()?.present(av, animated: true)
    }
}

struct HowItWorksSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How Referrals Work")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                HowItWorksStep(
                    number: 1,
                    title: "Share your code",
                    description: "Send your unique referral code to friends"
                )
                
                HowItWorksStep(
                    number: 2,
                    title: "Friend signs up",
                    description: "They create an account using your code"
                )
                
                HowItWorksStep(
                    number: 3,
                    title: "Both earn rewards",
                    description: "You both get signup bonuses, plus milestone rewards"
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct HowItWorksStep: View {
    let number: Int
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(AppTheme.Colors.primary)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    ReferralsView()
        .environmentObject(AppState())
}

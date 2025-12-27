//
//  GamingOnboardingView.swift
//  MyChannel
//
//  Quick 3-Step Onboarding: "Bet on Yourself" 
//  Users ready to compete in 3 minutes!
//

import SwiftUI

struct GamingOnboardingView: View {
    @StateObject private var viewModel = GamingOnboardingViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep: OnboardingStep = .welcome
    
    var body: some View {
        ZStack {
            AppTheme.Colors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress bar
                progressBar
                
                // Content
                TabView(selection: $currentStep) {
                    welcomeStep
                        .tag(OnboardingStep.welcome)
                    
                    depositStep
                        .tag(OnboardingStep.deposit)
                    
                    verifyStep
                        .tag(OnboardingStep.verify)
                    
                    readyStep
                        .tag(OnboardingStep.ready)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .navigationBarHidden(true)
    }
    
    // MARK: - Progress Bar
    
    private var progressBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ForEach(OnboardingStep.allCases.dropLast(), id: \.self) { step in
                    Rectangle()
                        .fill(currentStep.rawValue >= step.rawValue ? AppTheme.Colors.primary : AppTheme.Colors.divider.opacity(0.3))
                        .frame(height: 4)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
            .padding(.bottom, 20)
        }
        .background(AppTheme.Colors.surface)
    }
    
    // MARK: - Welcome Step
    
    private var welcomeStep: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Hero
            VStack(spacing: 20) {
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hexString: "#FFD700") ?? .yellow, Color(hexString: "#FFA500") ?? .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundColor(.white)
                }
                
                // Title
                Text("Bet on Yourself")
                    .font(.system(size: 36, weight: .black))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                
                // Subtitle
                Text("Why bet on FanDuel when you can bet on your own skills?")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            // Features
            VStack(spacing: 16) {
                featureRow(
                    icon: "gamecontroller.fill",
                    title: "Compete in Your Game",
                    subtitle: "Fortnite, Call of Duty, Mortal Kombat, FIFA & more"
                )
                
                featureRow(
                    icon: "dollarsign.circle.fill",
                    title: "Real Money Prizes",
                    subtitle: "$1 to $100K+ tournaments & VS matches"
                )
                
                featureRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Rise to the Top",
                    subtitle: "Climb leaderboards, win medals, earn respect"
                )
            }
            .padding(.horizontal, 32)
            
            Spacer()
            
            // CTA
            Button(action: {
                withAnimation {
                    currentStep = .deposit
                }
            }) {
                Text("Get Started")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        LinearGradient(
                            colors: [AppTheme.Colors.primary, AppTheme.Colors.primary.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }
    
    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.primary.opacity(0.1))
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.primary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(subtitle)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Deposit Step
    
    private var depositStep: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 20) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 80, weight: .bold))
                    .foregroundColor(Color(hexString: "#FFD700"))
                
                Text("Fund Your Wallet")
                    .font(.system(size: 32, weight: .black))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text("Start with any amount from $5 to $10,000")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            // Quick amount buttons
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    quickAmountButton(amount: 25, isSelected: viewModel.selectedAmount == 25)
                    quickAmountButton(amount: 50, isSelected: viewModel.selectedAmount == 50)
                    quickAmountButton(amount: 100, isSelected: viewModel.selectedAmount == 100)
                }
                
                HStack(spacing: 12) {
                    quickAmountButton(amount: 250, isSelected: viewModel.selectedAmount == 250)
                    quickAmountButton(amount: 500, isSelected: viewModel.selectedAmount == 500)
                    quickAmountButton(amount: 1000, isSelected: viewModel.selectedAmount == 1000)
                }
            }
            .padding(.horizontal, 20)
            
            // Custom amount
            VStack(spacing: 8) {
                Text("Or enter custom amount")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                TextField("Enter amount", value: $viewModel.customAmount, format: .currency(code: "USD"))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppTheme.Colors.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(AppTheme.Colors.divider.opacity(0.2), lineWidth: 1)
                            )
                    )
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            // Continue button
            Button(action: {
                Task {
                    await viewModel.processDeposit()
                    withAnimation {
                        currentStep = .verify
                    }
                }
            }) {
                Text("Continue")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(AppTheme.Colors.primary)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }
    
    private func quickAmountButton(amount: Int, isSelected: Bool) -> some View {
        Button(action: {
            viewModel.selectedAmount = amount
        }) {
            Text("$\(amount)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(isSelected ? .white : AppTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isSelected ? Color.clear : AppTheme.Colors.divider.opacity(0.2), lineWidth: 1)
                        )
                )
        }
    }
    
    // MARK: - Verify Step
    
    private var verifyStep: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 20) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 80, weight: .bold))
                    .foregroundColor(Color.green)
                
                Text("Quick Verification")
                    .font(.system(size: 32, weight: .black))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text("Just need to confirm you're 18+ and in a supported region")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            // Verification checklist
            VStack(spacing: 16) {
                verificationRow(
                    title: "Age Verification",
                    subtitle: "Confirm you're 18 or older",
                    isComplete: viewModel.ageVerified
                )
                
                verificationRow(
                    title: "Region Check",
                    subtitle: "Ensure you're in a supported area",
                    isComplete: viewModel.regionVerified
                )
                
                verificationRow(
                    title: "Terms of Service",
                    subtitle: "Accept our gaming terms",
                    isComplete: viewModel.termsAccepted
                )
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            // Verify button
            Button(action: {
                Task {
                    await viewModel.completeVerification()
                    withAnimation {
                        currentStep = .ready
                    }
                }
            }) {
                if viewModel.isVerifying {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(AppTheme.Colors.primary)
                        .cornerRadius(12)
                } else {
                    Text("Verify Now")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(AppTheme.Colors.primary)
                        .cornerRadius(12)
                }
            }
            .disabled(viewModel.isVerifying)
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }
    
    private func verificationRow(title: String, subtitle: String, isComplete: Bool) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(isComplete ? Color.green.opacity(0.1) : AppTheme.Colors.surface)
                    .frame(width: 48, height: 48)
                
                Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(isComplete ? Color.green : AppTheme.Colors.textTertiary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(subtitle)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppTheme.Colors.divider.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Ready Step
    
    private var readyStep: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 20) {
                // Success icon with animation
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.green, Color.green.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 60, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Text("You're All Set!")
                    .font(.system(size: 36, weight: .black))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text("Your wallet is funded and you're verified. Time to compete!")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            // Quick stats
            HStack(spacing: 20) {
                statCard(
                    title: "Balance",
                    value: "$\(viewModel.selectedAmount)",
                    icon: "dollarsign.circle.fill",
                    color: Color(hexString: "#FFD700") ?? .yellow
                )
                
                statCard(
                    title: "Status",
                    value: "Verified",
                    icon: "checkmark.shield.fill",
                    color: Color.green
                )
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            // Enter Arena button
            Button(action: {
                dismiss()
            }) {
                HStack(spacing: 12) {
                    Text("Enter the Arena")
                        .font(.system(size: 17, weight: .bold))
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    LinearGradient(
                        colors: [Color(hexString: "#DC143C") ?? .red, Color(hexString: "#8B0000") ?? Color(red: 0.55, green: 0, blue: 0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }
    
    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(color)
            
            VStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppTheme.Colors.divider.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - Onboarding Steps

enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case deposit = 1
    case verify = 2
    case ready = 3
}

// MARK: - ViewModel

@MainActor
final class GamingOnboardingViewModel: ObservableObject {
    @Published var selectedAmount: Int = 50
    @Published var customAmount: Double = 0
    
    @Published var ageVerified = false
    @Published var regionVerified = false
    @Published var termsAccepted = false
    @Published var isVerifying = false
    
    func processDeposit() async {
        // Process Stripe payment
        try? await Task.sleep(nanoseconds: 1_000_000_000)
    }
    
    func completeVerification() async {
        isVerifying = true
        
        // Simulate verification
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        
        ageVerified = true
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        regionVerified = true
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        termsAccepted = true
        
        isVerifying = false
    }
}

#Preview {
    GamingOnboardingView()
}


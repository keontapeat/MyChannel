//
//  VSWalletSheet.swift
//  MyChannel
//
//  💰 VS Match wallet — deposit & withdraw funds used for tournament entry
//  fees and head-to-head wagers. Backed by VSMatchWalletService (Stripe).
//

import SwiftUI

struct VSWalletSheet: View {
    enum Mode: String, CaseIterable, Identifiable {
        case deposit = "Deposit"
        case withdraw = "Withdraw"
        var id: String { rawValue }
    }

    @Environment(\.dismiss) private var dismiss
    @Injected private var walletService: VSMatchWalletService

    let availableBalance: Double
    var initialMode: Mode = .deposit
    /// Called after a successful deposit/withdrawal so the caller can refresh.
    var onComplete: () -> Void = {}

    @State private var mode: Mode
    @State private var amount: String = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    init(availableBalance: Double, initialMode: Mode = .deposit, onComplete: @escaping () -> Void = {}) {
        self.availableBalance = availableBalance
        self.initialMode = initialMode
        self.onComplete = onComplete
        _mode = State(initialValue: initialMode)
    }

    private var currentUserId: String? {
        AuthenticationManager.shared.currentUser?.id ?? AppState.shared.currentUser?.id
    }

    private var requestedAmount: Double {
        Double(amount.trimmingCharacters(in: .whitespaces)) ?? 0
    }

    private var quickAmounts: [Int] {
        mode == .deposit ? [10, 25, 50, 100, 250] : [10, 25, 50, 100]
    }

    private var minAmount: Double { mode == .deposit ? 5 : 10 }
    private var maxAmount: Double { mode == .deposit ? 10_000 : availableBalance }

    private var canSubmit: Bool {
        guard !isProcessing, requestedAmount >= minAmount else { return false }
        switch mode {
        case .deposit: return requestedAmount <= 10_000
        case .withdraw: return requestedAmount <= availableBalance
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    modePicker
                    balanceCard
                    amountEntry
                    quickAmountRow
                    if mode == .withdraw {
                        withdrawNote
                    } else {
                        depositNote
                    }
                    if let errorMessage {
                        feedback(errorMessage, color: .red, icon: "exclamationmark.triangle.fill")
                    }
                    if let successMessage {
                        feedback(successMessage, color: .green, icon: "checkmark.circle.fill")
                    }
                    submitButton
                }
                .padding(20)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Wallet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Sections

    private var modePicker: some View {
        Picker("Mode", selection: $mode) {
            ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .onChange(of: mode) { _ in
            amount = ""
            errorMessage = nil
            successMessage = nil
        }
    }

    private var balanceCard: some View {
        VStack(spacing: 6) {
            Text("Available Balance")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
            Text("$\(Int(availableBalance).formatted())")
                .font(.system(size: 34, weight: .black))
                .foregroundColor(Color(hexString: "#FFD700") ?? .yellow)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.Colors.surface)
        )
    }

    private var amountEntry: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(mode == .deposit ? "Amount to Deposit" : "Amount to Withdraw")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            HStack {
                Text("$")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                TextField("0.00", text: $amount)
                    .font(.system(size: 24, weight: .bold))
                    .keyboardType(.decimalPad)
            }
            .padding(16)
            .background(AppTheme.Colors.surface)
            .cornerRadius(12)

            Text(mode == .deposit
                 ? "Min: $5 • Max: $10,000"
                 : "Min: $10 • A 2.5% fee applies (max $25)")
                .font(.system(size: 12))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
    }

    private var quickAmountRow: some View {
        HStack(spacing: 10) {
            ForEach(quickAmounts, id: \.self) { value in
                Button {
                    amount = "\(value)"
                    HapticManager.shared.impact(style: .light)
                } label: {
                    Text("$\(value)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(amount == "\(value)" ? .white : AppTheme.Colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().fill(amount == "\(value)" ? AppTheme.Colors.primary : AppTheme.Colors.surface)
                        )
                }
                .disabled(mode == .withdraw && Double(value) > availableBalance)
                .opacity(mode == .withdraw && Double(value) > availableBalance ? 0.4 : 1)
            }
        }
    }

    private var depositNote: some View {
        Label("Funds are processed securely through Stripe and added to your wallet for tournament entries and wagers.",
              systemImage: "lock.shield.fill")
            .font(.system(size: 12))
            .foregroundColor(AppTheme.Colors.textSecondary)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(AppTheme.Colors.surface))
    }

    private var withdrawNote: some View {
        Label("Withdrawals are sent to your connected payout account. Processing typically completes within 1–3 business days.",
              systemImage: "building.columns.fill")
            .font(.system(size: 12))
            .foregroundColor(AppTheme.Colors.textSecondary)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(AppTheme.Colors.surface))
    }

    private func feedback(_ text: String, color: Color, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundColor(color)
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(color)
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.1)))
    }

    private var submitButton: some View {
        Button {
            Task { await submit() }
        } label: {
            HStack {
                if isProcessing {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text(mode == .deposit ? "Add Funds" : "Withdraw")
                        .font(.system(size: 16, weight: .bold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(canSubmit ? AppTheme.Colors.primary : Color.gray)
            .cornerRadius(12)
        }
        .disabled(!canSubmit)
    }

    // MARK: - Actions

    private func submit() async {
        guard let userId = currentUserId else {
            errorMessage = "Sign in to manage your wallet."
            return
        }
        isProcessing = true
        errorMessage = nil
        successMessage = nil
        HapticManager.shared.impact(style: .medium)

        do {
            switch mode {
            case .deposit:
                let result = try await walletService.depositFunds(
                    userId: userId,
                    amount: requestedAmount,
                    paymentMethodId: "wallet_topup"
                )
                successMessage = "Deposited $\(Int(result.amount).formatted()). New balance updated."
            case .withdraw:
                let destination = WithdrawalDestination(
                    type: .stripeAccount,
                    id: userId,
                    last4: nil
                )
                let withdrawal = try await walletService.requestWithdrawal(
                    userId: userId,
                    amount: requestedAmount,
                    destination: destination
                )
                successMessage = "Withdrawal of $\(Int(withdrawal.netAmount).formatted()) requested."
            }
            HapticManager.shared.notification(type: .success)
            onComplete()
            amount = ""
        } catch {
            errorMessage = error.localizedDescription
            HapticManager.shared.notification(type: .error)
        }
        isProcessing = false
    }
}

#Preview {
    VSWalletSheet(availableBalance: 8230)
}

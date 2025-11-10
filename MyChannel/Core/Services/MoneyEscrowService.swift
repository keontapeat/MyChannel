//
//  MoneyEscrowService.swift
//  MyChannel
//
//  Created by AI Assistant on 11/6/25.
//  💰 ESCROW SERVICE - Safe money handling for VS Matches
//  Stripe Connect + Instant payouts 🔥
//

import Foundation

@MainActor
class MoneyEscrowService: ObservableObject {
    static let shared = MoneyEscrowService()
    
    @Published var heldFunds: [String: EscrowedFunds] = [:] // matchId -> funds
    
    private init() {}
    
    // MARK: - 🔒 HOLD FUNDS
    
    func holdFunds(userId: String, amount: Double, matchId: String) async throws {
        print("🔒 Holding $\(amount) from user \(userId) for match \(matchId)")
        
        // TODO: Integrate with Stripe Connect
        // For now, simulate escrow
        
        // Verify user has sufficient balance
        guard await verifyUserBalance(userId: userId, amount: amount) else {
            throw EscrowError.insufficientFunds
        }
        
        // Create escrow record
        let escrow = EscrowedFunds(
            matchId: matchId,
            userId: userId,
            amount: amount,
            status: .held,
            heldAt: Date()
        )
        
        heldFunds["\(matchId)_\(userId)"] = escrow
        
        print("✅ Funds held in escrow")
    }
    
    // MARK: - 💸 RELEASE FUNDS
    
    func releaseFunds(matchId: String, winnerId: String, loserId: String, amount: Double) async throws {
        print("💸 Releasing $\(amount) to winner \(winnerId)")
        
        // TODO: Integrate with Stripe instant payout
        // For now, simulate release
        
        // Update escrow records
        if var escrow = heldFunds["\(matchId)_\(winnerId)"] {
            escrow.status = .released
            escrow.releasedAt = Date()
            heldFunds["\(matchId)_\(winnerId)"] = escrow
        }
        
        if var escrow = heldFunds["\(matchId)_\(loserId)"] {
            escrow.status = .released
            escrow.releasedAt = Date()
            heldFunds["\(matchId)_\(loserId)"] = escrow
        }
        
        // Transfer to winner
        try await transferToUser(userId: winnerId, amount: amount)
        
        print("✅ Funds released to winner")
    }
    
    // MARK: - 🔄 REFUND
    
    func refundFunds(matchId: String, userId: String) async throws {
        print("🔄 Refunding funds for match \(matchId)")
        
        guard var escrow = heldFunds["\(matchId)_\(userId)"] else {
            throw EscrowError.noFundsHeld
        }
        
        // Return money to user
        try await transferToUser(userId: userId, amount: escrow.amount)
        
        escrow.status = .refunded
        escrow.releasedAt = Date()
        heldFunds["\(matchId)_\(userId)"] = escrow
        
        print("✅ Funds refunded")
    }
    
    // MARK: - Helper Functions
    
    private func verifyUserBalance(userId: String, amount: Double) async -> Bool {
        // TODO: Check actual user balance from payment provider
        // For now, return true
        return true
    }
    
    private func transferToUser(userId: String, amount: Double) async throws {
        // TODO: Use Stripe instant payout
        print("💰 Transferred $\(amount) to user \(userId)")
    }
}

// MARK: - Models

struct EscrowedFunds {
    let matchId: String
    let userId: String
    let amount: Double
    var status: EscrowStatus
    let heldAt: Date
    var releasedAt: Date?
    
    enum EscrowStatus {
        case held
        case released
        case refunded
    }
}

enum EscrowError: LocalizedError {
    case insufficientFunds
    case noFundsHeld
    case transferFailed
    
    var errorDescription: String? {
        switch self {
        case .insufficientFunds:
            return "Insufficient funds in account"
        case .noFundsHeld:
            return "No funds found in escrow"
        case .transferFailed:
            return "Transfer failed. Please try again"
        }
    }
}


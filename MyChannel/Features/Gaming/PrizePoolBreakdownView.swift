//
//  PrizePoolBreakdownView.swift
//  MyChannel
//
//  Prize Pool Distribution Breakdown
//

import SwiftUI

struct PrizePoolBreakdownView: View {
    let tournament: Tournament
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.Colors.background
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Total prize pool
                        totalPrizeCard
                        
                        // Breakdown
                        prizeBreakdownList
                        
                        // Platform fee info
                        platformFeeInfo
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("Prize Breakdown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var totalPrizeCard: some View {
        VStack(spacing: 16) {
            Text("Total Prize Pool")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            Text(tournament.formattedPrizePool)
                .font(.system(size: 48, weight: .black))
                .foregroundColor(Color(hex: "#FFD700"))
            
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("\(tournament.currentPlayers)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("Players")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Divider()
                    .frame(height: 40)
                    .background(AppTheme.Colors.divider.opacity(0.2))
                
                VStack(spacing: 4) {
                    Text(tournament.formattedEntryFee)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("Entry Fee")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            AppTheme.Colors.surface,
                            AppTheme.Colors.surface.opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "#FFD700").opacity(0.3), Color(hex: "#DC143C").opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
    }
    
    private var prizeBreakdownList: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Prize Distribution")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(spacing: 0) {
                prizeRow(place: "1st Place", percentage: "50%", amount: tournament.prizePool * 0.5, showMedal: "🥇")
                Divider().background(AppTheme.Colors.divider.opacity(0.1))
                
                prizeRow(place: "2nd Place", percentage: "30%", amount: tournament.prizePool * 0.3, showMedal: "🥈")
                Divider().background(AppTheme.Colors.divider.opacity(0.1))
                
                prizeRow(place: "3rd Place", percentage: "15%", amount: tournament.prizePool * 0.15, showMedal: "🥉")
                Divider().background(AppTheme.Colors.divider.opacity(0.1))
                
                prizeRow(place: "4th Place", percentage: "5%", amount: tournament.prizePool * 0.05, showMedal: nil)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.Colors.surface)
            )
        }
    }
    
    private func prizeRow(place: String, percentage: String, amount: Double, showMedal: String?) -> some View {
        HStack(spacing: 16) {
            // Place with medal
            HStack(spacing: 8) {
                if let medal = showMedal {
                    Text(medal)
                        .font(.system(size: 24))
                }
                
                Text(place)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }
            .frame(width: 120, alignment: .leading)
            
            Spacer()
            
            // Percentage
            Text(percentage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .frame(width: 50, alignment: .trailing)
            
            // Amount
            Text("$\(Int(amount).formatted())")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(hex: "#FFD700"))
                .frame(width: 100, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
    
    private var platformFeeInfo: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                Text("Platform Fee")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                Spacer()
            }
            
            Text("MyChannel takes a 10% platform fee from all prize pools to maintain the platform and ensure fair gameplay.")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.leading)
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
}

#Preview {
    PrizePoolBreakdownView(
        tournament: Tournament(
            id: "spring-championship",
            name: "Spring Championship",
            gameName: "Fortnite",
            prizePool: 50_000,
            entryFee: 50,
            format: "Single Elimination",
            currentPlayers: 248,
            maxPlayers: 256,
            startDate: Date().addingTimeInterval(60 * 60 * 38),
            isLive: false
        )
    )
}


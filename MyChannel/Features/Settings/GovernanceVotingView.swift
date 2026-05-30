//
//  GovernanceVotingView.swift
//  MyChannel
//
//  Created by Keonta.
//

import SwiftUI

struct GovernanceVotingView: View {
    @StateObject private var governanceService = PlatformGovernanceService()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Platform Governance")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                
                Text("Shape the future of MyChannel. Vote on platform policies and revenue updates.")
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .padding(.horizontal)
                
                ForEach(governanceService.proposals) { proposal in
                    ProposalCardView(proposal: proposal, service: governanceService)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Governance")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ProposalCardView: View {
    let proposal: GovernanceProposal
    @ObservedObject var service: PlatformGovernanceService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(proposal.title)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(proposal.description)
                .font(.subheadline)
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            Text("Proposed by \(proposal.proposerUid)")
                .font(.caption)
                .foregroundColor(AppTheme.Colors.primary)
            
            let totalVotes = proposal.votesFor + proposal.votesAgainst
            let yesPercentage = totalVotes > 0 ? Double(proposal.votesFor) / Double(totalVotes) : 0
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Current Results")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.red.opacity(0.8))
                            .frame(height: 12)
                            .cornerRadius(6)
                        
                        Rectangle()
                            .fill(Color.green.opacity(0.8))
                            .frame(width: geo.size.width * CGFloat(yesPercentage), height: 12)
                            .cornerRadius(6)
                    }
                }
                .frame(height: 12)
                
                HStack {
                    Text("\(Int(yesPercentage * 100))% Yes")
                        .font(.caption2)
                        .foregroundColor(.green)
                    Spacer()
                    Text("\(100 - Int(yesPercentage * 100))% No")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            }
            .padding(.top, 8)
            
            if proposal.status == .voting {
                HStack(spacing: 16) {
                    Button(action: {
                        let uid = AuthenticationManager.shared.currentUser?.id ?? ""
                        Task { try? await service.castVote(proposalId: proposal.id, voterUid: uid, isFor: true, reason: nil) }
                        HapticManager.shared.impact(style: .medium)
                    }) {
                        Text("Vote Yes")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        let uid = AuthenticationManager.shared.currentUser?.id ?? ""
                        Task { try? await service.castVote(proposalId: proposal.id, voterUid: uid, isFor: false, reason: nil) }
                        HapticManager.shared.impact(style: .medium)
                    }) {
                        Text("Vote No")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.red.opacity(0.2))
                            .foregroundColor(.red)
                            .cornerRadius(8)
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

#Preview {
    NavigationView {
        GovernanceVotingView()
    }
}

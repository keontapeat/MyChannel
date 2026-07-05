//
//  RevenueCommandCenterView.swift
//  MyChannel
//
//  Phase 265 & 277: Revenue & Creator Economy Tab
//

import SwiftUI

struct RevenueCommandCenterView: View {
    @StateObject private var attribution = RevenueAttributionService.shared
    @StateObject private var creatorEconomy = CreatorEconomyFinancialService.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // Revenue Summary
                VStack(spacing: 10) {
                    Text("REVENUE ATTRIBUTION")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(CCTheme.textSecondary)
                    Text(String(format: "$%.2f", attribution.totalRevenue))
                        .font(.system(size: 36, weight: .black, design: .monospaced)).foregroundColor(CCTheme.good)
                }
                .padding(16)
                .background(CCTheme.panel)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(CCTheme.panelBorder, lineWidth: 1))
                
                // Revenue Streams
                ForEach(attribution.revenueStreams) { stream in
                    RevenueStreamCard(stream: stream)
                }
                
                // Creator Economy Summary
                VStack(spacing: 10) {
                    Text("CREATOR ECONOMY")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(CCTheme.textSecondary)
                    HStack(spacing: 20) {
                        VStack {
                            Text(String(format: "$%.2f", creatorEconomy.totalCreatorPayouts))
                                .font(.system(size: 24, weight: .black, design: .monospaced)).foregroundColor(CCTheme.textPrimary)
                            Text("Payouts").font(.system(size: 10, design: .monospaced)).foregroundColor(CCTheme.textSecondary)
                        }
                        VStack {
                            Text("\(creatorEconomy.pendingPayouts)")
                                .font(.system(size: 24, weight: .black, design: .monospaced)).foregroundColor(creatorEconomy.pendingPayouts > 0 ? CCTheme.warning : CCTheme.good)
                            Text("Pending").font(.system(size: 10, design: .monospaced)).foregroundColor(CCTheme.textSecondary)
                        }
                    }
                }
                .padding(16)
                .background(CCTheme.panel)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(CCTheme.panelBorder, lineWidth: 1))
            }
            .padding(16)
        }
        .navigationTitle("Revenue")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct RevenueStreamCard: View {
    let stream: RevenueAttributionService.RevenueStream
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(stream.source)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(CCTheme.textPrimary)
                Text("\(stream.period)")
                    .font(.system(size: 11)).foregroundColor(CCTheme.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(stream.amount, specifier: "%.2f")")
                    .font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundColor(CCTheme.textPrimary)
                Text("\(stream.growth > 0 ? "+" : "")\(String(format: "%.1f%%", stream.growth))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(stream.growth >= 0 ? CCTheme.good : CCTheme.critical)
            }
        }
        .padding(12)
        .background(CCTheme.panel)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(CCTheme.panelBorder, lineWidth: 1))
    }
}

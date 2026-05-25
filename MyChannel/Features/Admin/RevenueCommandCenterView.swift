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
                        .foregroundColor(.secondary)
                    Text(String(format: "$%.2f", attribution.totalRevenue))
                        .font(.system(size: 36, weight: .black)).foregroundColor(.green)
                }
                .padding(16)
                .background(Color.green.opacity(0.08))
                .cornerRadius(12)
                
                // Revenue Streams
                ForEach(attribution.revenueStreams) { stream in
                    RevenueStreamCard(stream: stream)
                }
                
                // Creator Economy Summary
                VStack(spacing: 10) {
                    Text("CREATOR ECONOMY")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                    HStack(spacing: 20) {
                        VStack {
                            Text(String(format: "$%.2f", creatorEconomy.totalCreatorPayouts))
                                .font(.system(size: 24, weight: .black)).foregroundColor(.yellow)
                            Text("Payouts").font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
                        }
                        VStack {
                            Text("\(creatorEconomy.pendingPayouts)")
                                .font(.system(size: 24, weight: .black)).foregroundColor(creatorEconomy.pendingPayouts > 0 ? .orange : .green)
                            Text("Pending").font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
                        }
                    }
                }
                .padding(16)
                .background(Color.yellow.opacity(0.08))
                .cornerRadius(12)
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
                Text("\(stream.period)")
                    .font(.system(size: 11)).foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(stream.amount, specifier: "%.2f")")
                    .font(.system(size: 14, weight: .bold)).foregroundColor(.green)
                Text("\(stream.growth > 0 ? "+" : "")\(String(format: "%.1f%%", stream.growth))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(stream.growth >= 0 ? .green : .red)
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(10)
    }
}

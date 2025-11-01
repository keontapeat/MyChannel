//
//  PayoutsHistoryView.swift
//  MyChannel
//
//  Created by AI Assistant on 10/15/25.
//

import SwiftUI

struct PayoutsHistoryView: View {
    @StateObject private var service = CreatorEconomyService.shared
    @EnvironmentObject private var appState: AppState
    @State private var payouts: [Payment] = []
    
    var body: some View {
        List {
            ForEach(payouts, id: \.id) { p in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(p.type == .withdrawal ? "Withdrawal" : "Payment")
                            .font(.subheadline).fontWeight(.semibold)
                        Text(p.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("$\(p.amount, specifier: "%.2f")")
                        .font(.headline)
                        .foregroundStyle(p.status == .completed ? .green : .secondary)
                }
                .contentShape(Rectangle())
            }
        }
        .navigationTitle("Payouts History")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let id = appState.currentUser?.id ?? User.sampleUsers.first?.id ?? ""
            _ = try? await service.fetchPaymentHistory(creatorId: id)
            payouts = service.paymentHistory
        }
    }
}

#Preview {
    NavigationStack { PayoutsHistoryView() }
}



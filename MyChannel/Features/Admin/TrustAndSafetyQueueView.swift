//
//  TrustAndSafetyQueueView.swift
//  MyChannel
//
//  Created by Keonta.
//

import SwiftUI

struct ReportedItem: Identifiable {
    let id: String
    let targetId: String
    let type: String
    let reason: String
    let status: String
}

struct TrustAndSafetyQueueView: View {
    @State private var items: [ReportedItem] = [
        ReportedItem(id: "1", targetId: "vid_101", type: "Video", reason: "Spam", status: "Pending Review"),
        ReportedItem(id: "2", targetId: "comment_502", type: "Comment", reason: "Harassment", status: "Under Investigation")
    ]
    
    var body: some View {
        List(items) { item in
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(item.type)
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(4)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)
                    
                    Spacer()
                    
                    Text(item.status)
                        .font(.caption)
                        .foregroundColor(item.status == "Pending Review" ? .orange : .gray)
                }
                
                Text("Reason: \(item.reason)")
                    .font(.headline)
                
                Text("Target ID: \(item.targetId)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Button("Take Down") {
                        // Action
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    
                    Button("Dismiss") {
                        // Action
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top, 4)
            }
            .padding(.vertical, 4)
        }
        .navigationTitle("Trust & Safety")
    }
}

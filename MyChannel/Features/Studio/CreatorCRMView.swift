//
//  CreatorCRMView.swift
//  MyChannel
//
//  Created by Keonta.
//

import SwiftUI

struct TopFan: Identifiable {
    let id = UUID()
    let name: String
    let avatarURL: String
    let badgeType: FanBadgeType
    let monthsSubscribed: Int
    let totalTips: Double
}

struct CreatorCRMView: View {
    @State private var searchText = ""
    
    // Sample Data
    let topFans = [
        TopFan(name: "Alice Johnson", avatarURL: "", badgeType: .vip, monthsSubscribed: 24, totalTips: 500.0),
        TopFan(name: "Bob Smith", avatarURL: "", badgeType: .moderator, monthsSubscribed: 18, totalTips: 120.0),
        TopFan(name: "Charlie Brown", avatarURL: "", badgeType: .topFan, monthsSubscribed: 12, totalTips: 50.0),
        TopFan(name: "Diana Prince", avatarURL: "", badgeType: .vip, monthsSubscribed: 36, totalTips: 1500.0)
    ]
    
    var filteredFans: [TopFan] {
        if searchText.isEmpty {
            return topFans
        } else {
            return topFans.filter { $0.name.lowercased().contains(searchText.lowercased()) }
        }
    }
    
    var body: some View {
        NavigationStack {
            List(filteredFans) { fan in
                HStack(spacing: 16) {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Text(String(fan.name.prefix(1)))
                                .font(.headline)
                                .foregroundColor(.white)
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(fan.name)
                                .font(.headline)
                            FanBadgeView(type: fan.badgeType)
                        }
                        
                        Text("\(fan.monthsSubscribed) months • $\(String(format: "%.0f", fan.totalTips)) tipped")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        // Open direct message flow
                    }) {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(AppTheme.Colors.primary)
                            .padding(10)
                            .background(AppTheme.Colors.primary.opacity(0.2))
                            .clipShape(Circle())
                    }
                }
                .padding(.vertical, 4)
            }
            .listStyle(PlainListStyle())
            .searchable(text: $searchText, prompt: "Search fans...")
            .navigationTitle("Creator CRM")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // Filter actions
                    }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
        }
    }
}

#Preview {
    CreatorCRMView()
}

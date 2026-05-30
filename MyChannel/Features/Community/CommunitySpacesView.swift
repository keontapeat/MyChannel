//
//  CommunitySpacesView.swift
//  MyChannel
//
//  Created by Keonta.
//

import SwiftUI

struct DummyCommunitySpace: Identifiable {
    let id: String
    let name: String
    let description: String
    let memberCount: Int
    let imageUrl: String?
}

struct CommunitySpacesView: View {
    @State private var spaces: [DummyCommunitySpace] = [
        DummyCommunitySpace(id: "1", name: "SwiftUI Devs", description: "Talk about Apple UI frameworks.", memberCount: 1540, imageUrl: nil),
        DummyCommunitySpace(id: "2", name: "Gaming Hub", description: "Esports and let's plays.", memberCount: 8900, imageUrl: nil)
    ]
    
    var body: some View {
        NavigationStack {
            List(spaces) { space in
                HStack(spacing: 12) {
                    Circle()
                        .fill(AppTheme.Colors.surface)
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "person.3.fill")
                                .foregroundColor(AppTheme.Colors.primary)
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(space.name)
                            .font(.headline)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Text(space.description)
                            .font(.subheadline)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .lineLimit(2)
                        
                        Text("\(space.memberCount) members")
                            .font(.caption)
                            .foregroundColor(AppTheme.Colors.textTertiary)
                    }
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Community Spaces")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {}) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(AppTheme.Colors.primary)
                    }
                }
            }
        }
    }
}

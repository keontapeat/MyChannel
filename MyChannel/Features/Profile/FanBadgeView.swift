//
//  FanBadgeView.swift
//  MyChannel
//
//  Created by Keonta.
//

import SwiftUI

enum FanBadgeType: String {
    case topFan = "Top Fan"
    case moderator = "Moderator"
    case vip = "VIP"
    
    var color: Color {
        switch self {
        case .topFan: return .orange
        case .moderator: return .blue
        case .vip: return .purple
        }
    }
    
    var icon: String {
        switch self {
        case .topFan: return "star.fill"
        case .moderator: return "shield.fill"
        case .vip: return "crown.fill"
        }
    }
}

struct FanBadgeView: View {
    let type: FanBadgeType
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: type.icon)
                .font(.system(size: 10))
            Text(type.rawValue)
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(type.color)
        .cornerRadius(6)
        .shadow(color: type.color.opacity(0.3), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    VStack {
        FanBadgeView(type: .topFan)
        FanBadgeView(type: .moderator)
        FanBadgeView(type: .vip)
    }
    .padding()
    .background(Color.black)
}

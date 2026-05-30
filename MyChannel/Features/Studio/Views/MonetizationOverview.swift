import SwiftUI
import AVKit
import Combine

// MARK: - Monetization Overview
struct MonetizationOverviewView: View {
    @StateObject private var analyticsService = AdvancedAnalyticsService.shared
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Revenue Summary Cards
                HStack(spacing: 16) {
                    RevenueCard(
                        title: "Total Revenue",
                        amount: analyticsService.estimatedRevenue,
                        change: analyticsService.revenueGrowth,
                        icon: "dollarsign.circle.fill",
                        color: .green
                    )
                    
                    RevenueCard(
                        title: "This Month",
                        amount: analyticsService.estimatedRevenue * 0.3,
                        change: 12.5,
                        icon: "calendar.circle.fill",
                        color: .blue
                    )
                }
                
                // Revenue Breakdown
                VStack(alignment: .leading, spacing: 12) {
                    Text("Revenue Sources")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    let revenueBreakdown = analyticsService.getRevenueBreakdown(for: "current_user")
                    
                    ForEach(Array(revenueBreakdown.keys.sorted()), id: \.self) { source in
                        HStack {
                            Image(systemName: iconForRevenueSource(source))
                                .foregroundColor(colorForRevenueSource(source))
                            Text(source.capitalized)
                            Spacer()
                            Text("$\(String(format: "%.2f", revenueBreakdown[source] ?? 0))")
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Quick Actions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Actions")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        StudioQuickActionButton(
                            title: "Enable Ads",
                            subtitle: "Start earning from video ads",
                            icon: "play.rectangle.fill",
                            color: Color.red
                        ) {
                            // Enable ads action
                        }
                        
                        StudioQuickActionButton(
                            title: "Set Up Memberships",
                            subtitle: "Create membership tiers",
                            icon: "person.badge.plus.fill",
                            color: Color.purple
                        ) {
                            // Set up memberships action
                        }
                        
                        StudioQuickActionButton(
                            title: "Add Merchandise",
                            subtitle: "Sell your products",
                            icon: "bag.fill",
                            color: Color.orange
                        ) {
                            // Add merchandise action
                        }
                        
                        StudioQuickActionButton(
                            title: "Super Chat",
                            subtitle: "Enable donations",
                            icon: "heart.fill",
                            color: Color.pink
                        ) {
                            // Enable super chat action
                        }
                    }
                }
                .padding()
            }
            .padding()
        }
    }
    
    private func iconForRevenueSource(_ source: String) -> String {
        switch source.lowercased() {
        case "ads": return "play.rectangle.fill"
        case "memberships": return "person.badge.plus.fill"
        case "donations": return "heart.fill"
        default: return "dollarsign.circle.fill"
        }
    }
    
    private func colorForRevenueSource(_ source: String) -> Color {
        switch source.lowercased() {
        case "ads": return .red
        case "memberships": return .purple
        case "donations": return .pink
        default: return .blue
        }
    }
}


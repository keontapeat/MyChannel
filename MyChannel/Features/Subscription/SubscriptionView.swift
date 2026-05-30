import SwiftUI

struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedPlan: Plan = .monthly
    
    enum Plan: String, CaseIterable {
        case monthly = "Monthly"
        case yearly = "Yearly"
        
        var price: String {
            switch self {
            case .monthly: return "$4.99/mo"
            case .yearly: return "$49.99/yr"
            }
        }
        
        var savings: String? {
            switch self {
            case .monthly: return nil
            case .yearly: return "Save 16%"
            }
        }
    }
    
    let benefits = [
        ("No Ads", "Enjoy uninterrupted watching.", "speaker.slash"),
        ("Background Play", "Keep listening while using other apps.", "play.rectangle.on.rectangle"),
        ("Offline Downloads", "Save videos for when you're off the grid.", "arrow.down.circle"),
        ("Custom App Icons", "Unlock exclusive app icons.", "app.badge"),
        ("Premium Badge", "Stand out in the comments.", "checkmark.seal.fill")
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(
                                LinearGradient(colors: [AppTheme.Colors.primary, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                        
                        Text("MyChannel+")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                        
                        Text("Unlock the ultimate experience.")
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    .padding(.top, 24)
                    
                    // Benefits
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(benefits, id: \.0) { benefit in
                            HStack(spacing: 16) {
                                Image(systemName: benefit.2)
                                    .font(.system(size: 24))
                                    .foregroundColor(AppTheme.Colors.primary)
                                    .frame(width: 32)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(benefit.0)
                                        .font(.system(size: 16, weight: .bold))
                                    Text(benefit.1)
                                        .font(.system(size: 14))
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: horizontalSizeClass == .regular ? 600 : .infinity, alignment: .leading)
                    .padding(24)
                    .background(AppTheme.Colors.surface)
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
                    
                    // Plans
                    HStack(spacing: 16) {
                        ForEach(Plan.allCases, id: \.self) { plan in
                            Button(action: {
                                HapticManager.shared.impact(style: .light)
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedPlan = plan
                                }
                            }) {
                                VStack(spacing: 8) {
                                    Text(plan.rawValue)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(selectedPlan == plan ? AppTheme.Colors.primary : AppTheme.Colors.textPrimary)
                                    
                                    Text(plan.price)
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(selectedPlan == plan ? AppTheme.Colors.primary : AppTheme.Colors.textPrimary)
                                    
                                    if let savings = plan.savings {
                                        Text(savings)
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.green)
                                            .clipShape(Capsule())
                                    } else {
                                        Text("Billed monthly")
                                            .font(.system(size: 12))
                                            .foregroundColor(AppTheme.Colors.textSecondary)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                                .background(selectedPlan == plan ? AppTheme.Colors.primary.opacity(0.1) : AppTheme.Colors.surface)
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(selectedPlan == plan ? AppTheme.Colors.primary : AppTheme.Colors.divider, lineWidth: selectedPlan == plan ? 2 : 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: horizontalSizeClass == .regular ? 600 : .infinity)
                    
                    // Subscribe Button
                    Button(action: {
                        HapticManager.shared.impact(style: .heavy)
                        // Trigger subscription purchase logic
                    }) {
                        Text("Subscribe Now")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(colors: [AppTheme.Colors.primary, .purple], startPoint: .leading, endPoint: .trailing)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: AppTheme.Colors.primary.opacity(0.3), radius: 8, y: 4)
                    }
                    .frame(maxWidth: horizontalSizeClass == .regular ? 400 : .infinity)
                    .padding(.bottom, 40)
                }
                .padding(.horizontal, horizontalSizeClass == .regular ? 40 : 20)
                .frame(maxWidth: horizontalSizeClass == .regular ? 800 : .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

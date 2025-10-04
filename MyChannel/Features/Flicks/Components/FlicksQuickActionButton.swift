import SwiftUI

struct FlicksQuickActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textTertiary)
            }
            .padding(16)
            .background(AppTheme.Colors.surface.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 12) {
        FlicksQuickActionButton(
            title: "Clear Watch History",
            subtitle: "Reset your viewing recommendations",
            icon: "trash.fill",
            color: .red
        ) { }
        
        FlicksQuickActionButton(
            title: "Refresh Feed",
            subtitle: "Get fresh content recommendations",
            icon: "arrow.clockwise",
            color: .green
        ) { }
    }
    .padding()
    .background(AppTheme.Colors.background.ignoresSafeArea())
    .preferredColorScheme(.dark)
}
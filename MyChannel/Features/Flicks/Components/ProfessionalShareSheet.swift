import SwiftUI

struct ProfessionalShareSheet: View {
    let video: Video
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(.white.opacity(0.3))
                    .frame(width: 50, height: 5)
                    .padding(.top, 12)
                
                HStack {
                    Text("Share")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial, in: Circle())
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()), GridItem(.flexible()),
                        GridItem(.flexible()), GridItem(.flexible())
                    ], spacing: 24) {
                        PremiumShareOption(icon: "message.fill", title: "Messages", color: .green)
                        PremiumShareOption(icon: "envelope.fill", title: "Mail", color: .blue)
                        PremiumShareOption(icon: "square.and.arrow.up", title: "More", color: .gray)
                        PremiumShareOption(icon: "link", title: "Copy Link", color: AppTheme.Colors.primary)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                }
            }
        }
        .navigationBarHidden(true)
    }
}

struct PremiumShareOption: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(color, in: Circle())
                .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
            
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
    }
}

#Preview {
    ProfessionalShareSheet(video: Video.sampleVideos[0])
        .preferredColorScheme(.dark)
}
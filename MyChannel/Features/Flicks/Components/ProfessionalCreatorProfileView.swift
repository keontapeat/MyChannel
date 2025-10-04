import SwiftUI

struct ProfessionalCreatorProfileView: View {
    let creator: User
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    VStack(spacing: 20) {
                        AsyncImage(url: URL(string: creator.profileImageURL ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(AppTheme.Colors.primary)
                                .overlay(
                                    Text(String(creator.displayName.prefix(1)))
                                        .font(.system(size: 52, weight: .bold))
                                        .foregroundStyle(.white)
                                )
                        }
                        .frame(width: 140, height: 140)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.3), lineWidth: 4)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)
                        
                        VStack(spacing: 12) {
                            HStack(spacing: 10) {
                                Text(creator.displayName)
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundStyle(AppTheme.Colors.textPrimary)
                                
                                if creator.isVerified {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.system(size: 24))
                                        .foregroundStyle(AppTheme.Colors.primary)
                                }
                            }
                            
                            Text("@\(creator.username)")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                            
                            Text("\(creator.subscriberCount.formatted()) subscribers")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(AppTheme.Colors.textTertiary)
                        }
                    }
                    
                    if let bio = creator.bio {
                        Text(bio)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    
                    HStack(spacing: 20) {
                        Button(action: {}) {
                            Text("Subscribe")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(AppTheme.Colors.primary, in: Capsule())
                                .shadow(color: AppTheme.Colors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {}) {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                                .frame(width: 52, height: 52)
                                .background(.ultraThinMaterial, in: Circle())
                                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.vertical, 24)
            }
            .background(AppTheme.Colors.background)
            .navigationBarHidden(true)
            .overlay(alignment: .topTrailing) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .padding(.top, 60)
                .padding(.trailing, 24)
            }
        }
    }
}

#Preview {
    ProfessionalCreatorProfileView(creator: User.sampleUsers[0])
        .preferredColorScheme(.dark)
}
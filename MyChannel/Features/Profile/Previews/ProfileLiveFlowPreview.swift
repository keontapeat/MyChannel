import SwiftUI

struct ProfileLiveFlowPreview: View {
    @State private var user: User = User.sampleUsers.first ?? .defaultUser
    @State private var showEdit = false
    @State private var isFollowing = false
    @State private var showSettings = false
    
    // Use shared auth for consistency; create a local AppState for preview isolation.
    @StateObject private var appState = AppState()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ProfileHeaderView(
                    user: user,
                    scrollOffset: 0,
                    isFollowing: $isFollowing,
                    showingEditProfile: $showEdit,
                    showingSettings: $showSettings
                )
                .frame(height: 365)
                
                VStack(spacing: 12) {
                    Text("Live Edit Flow")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    
                    Text("Tap Edit Profile above, change your Display Name or banner, then Save — the header updates instantly.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 12)
                
                Spacer()
            }
            .background(AppTheme.Colors.background)
            .sheet(isPresented: $showEdit) {
                EditProfileView(user: $user)
                    .environmentObject(appState)
                    .environmentObject(AuthenticationManager.shared)
            }
        }
        .environmentObject(appState)
        .environmentObject(AuthenticationManager.shared)
        .onAppear {
            // Ensure both managers hold this same user in preview
            appState.updateUser(user)
            AuthenticationManager.shared.updateUser(user)
        }
        .onReceive(NotificationCenter.default.publisher(for: .userProfileUpdated)) { note in
            if let updated = note.object as? User {
                user = updated
            }
        }
    }
}

#Preview("Profile Live Edit Flow") {
    ProfileLiveFlowPreview()
        .preferredColorScheme(.light)
}
import SwiftUI

struct SubscriptionsView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @StateObject private var feed = SubscriptionsFeedService.shared

    var body: some View {
        Group {
            if !authManager.isAuthenticated {
                UnauthenticatedPromptView(promptType: .subscriptions) {
                    NotificationCenter.default.post(name: .presentSignInSheet, object: nil)
                }
            } else {
                subscriptionsContent
            }
        }
    }

    private var subscriptionsContent: some View {
        NavigationStack {
            Group {
                if feed.items.isEmpty {
                    if #available(iOS 17.0, *) {
                        ContentUnavailableView(
                            "No Subscriptions Yet", 
                            systemImage: "play.square.stack",
                            description: Text("Subscribe to your favorite creators to see their latest videos here.")
                        )
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "play.square.stack")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text("No Subscriptions Yet")
                                .font(.headline)
                            Text("Subscribe to your favorite creators to see their latest videos here.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    }
                } else {
                    List {
                        ForEach(feed.items) { item in
                            FeedItemRow(item: item)
                                .onTapGesture {
                                    NotificationCenter.default.post(
                                        name: NSNotification.Name("NavigateToVideo"),
                                        object: item.videoId
                                    )
                                }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("")
            .task {
                if let userId = authManager.currentUser?.id {
                    feed.listen(uid: userId)
                }
            }
            .onDisappear {
                feed.stop()
            }
        }
    }
}

struct FeedItemRow: View {
    let item: SubscriptionsFeedService.FeedItem
    
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
                .frame(width: 120, height: 68)
                .overlay(
                    Image(systemName: "play.fill")
                        .foregroundColor(.secondary)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text("New video from creator")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                
                Text(item.ownerUid)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(item.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if !item.read {
                Circle()
                    .fill(.blue)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SubscriptionsView()
        .environmentObject(AuthenticationManager.shared)
        .environmentObject(AppState())
}

//
//  SubscriptionsView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI

struct SubscriptionsView: View {
    @StateObject private var subscriptionService = MockSubscriptionService()
    @State private var selectedCreators: [User] = []
    @State private var isLoading = false
    @State private var showingCreatePlaylist = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    headerSection
                    
                    // Subscribed Creators
                    subscribedCreatorsSection
                    
                    // Suggested Creators
                    suggestedCreatorsSection
                }
                .padding()
            }
            .navigationTitle("Subscriptions")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Manage") {
                        // Manage subscriptions
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                }
            }
            .refreshable {
                await loadSubscriptions()
            }
        }
        .task {
            await loadSubscriptions()
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Your Subscriptions")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Stay updated with your favorite creators")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    showingCreatePlaylist = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            
            // Stats
            HStack(spacing: 24) {
                VStack(alignment: .leading) {
                    Text("\(subscriptionService.subscriptions.count)")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("Following")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading) {
                    Text("12")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    Text("New Videos")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading) {
                    Text("3.2K")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    Text("Watch Time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var subscribedCreatorsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Subscribed Creators")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("View All") {
                    // View all subscriptions
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            if subscriptionService.subscriptions.isEmpty {
                emptySubscriptionsView
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                    ForEach(User.sampleUsers.prefix(4)) { creator in
                        SubscriptionCreatorCard(
                            creator: creator,
                            isSubscribed: subscriptionService.subscriptions.contains { $0.creatorId == creator.id },
                            onSubscriptionToggle: {
                                Task {
                                    await toggleSubscription(for: creator)
                                }
                            }
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var suggestedCreatorsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Suggested for You")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Refresh") {
                    // Refresh suggestions
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(User.sampleUsers) { creator in
                        SuggestedCreatorCard(
                            creator: creator,
                            onSubscribe: {
                                Task {
                                    await subscribeToCreator(creator)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
            .padding(.horizontal, -16)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var emptySubscriptionsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.circle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Subscriptions Yet")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Subscribe to creators to see their latest content here")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Discover Creators") {
                // Navigate to discovery
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - Actions
    private func loadSubscriptions() async {
        // Load user's subscriptions
        print("Loading subscriptions...")
    }
    
    private func toggleSubscription(for creator: User) async {
        do {
            let isCurrentlySubscribed = subscriptionService.subscriptions.contains { $0.creatorId == creator.id }
            
            if isCurrentlySubscribed {
                try await subscriptionService.unsubscribe(from: creator.id)
            } else {
                _ = try await subscriptionService.subscribe(to: creator.id)
            }
        } catch {
            print("Error toggling subscription: \(error)")
        }
    }
    
    private func subscribeToCreator(_ creator: User) async {
        do {
            _ = try await subscriptionService.subscribe(to: creator.id)
        } catch {
            print("Error subscribing to creator: \(error)")
        }
    }
}

// MARK: - Subscription Creator Card
struct SubscriptionCreatorCard: View {
    let creator: User
    let isSubscribed: Bool
    let onSubscriptionToggle: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            AsyncImage(url: URL(string: creator.profileImageURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color(.systemGray5))
                    .overlay(
                        Image(systemName: "person.crop.circle")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    )
            }
            .frame(width: 60, height: 60)
            .clipShape(Circle())
            
            VStack(spacing: 4) {
                Text(creator.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                Text("\(creator.subscriberCount.formatted()) subscribers")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Button(action: onSubscriptionToggle) {
                HStack(spacing: 4) {
                    Image(systemName: isSubscribed ? "checkmark" : "plus")
                        .font(.caption)
                    Text(isSubscribed ? "Subscribed" : "Subscribe")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSubscribed ? Color(.systemGray5) : Color.blue)
                .foregroundColor(isSubscribed ? .primary : .white)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Suggested Creator Card
struct SuggestedCreatorCard: View {
    let creator: User
    let onSubscribe: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            AsyncImage(url: URL(string: creator.profileImageURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .overlay(
                        Image(systemName: "person.crop.circle")
                            .font(.title)
                            .foregroundColor(.secondary)
                    )
            }
            .frame(width: 120, height: 80)
            .cornerRadius(8)
            
            VStack(spacing: 6) {
                Text(creator.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                
                Text("\(creator.subscriberCount.formatted()) subscribers")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let bio = creator.bio {
                    Text(bio)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
            }
            
            Button(action: onSubscribe) {
                Text("Subscribe")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(16)
            }
            .buttonStyle(.plain)
        }
        .frame(width: 140)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    SubscriptionsView()
}
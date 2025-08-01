//
//  ShortsView.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI

struct ShortsView: View {
    @State private var currentIndex: Int = 0
    @State private var shorts: [Video] = Video.sampleVideos.filter { $0.isShort }
    @State private var likedShorts: Set<String> = []
    @State private var isPlaying: Bool = true
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black
                    .ignoresSafeArea()
                
                // Shorts feed
                TabView(selection: $currentIndex) {
                    ForEach(Array(shorts.enumerated()), id: \.element.id) { index, short in
                        ShortsPlayer(
                            video: short,
                            isLiked: likedShorts.contains(short.id),
                            isPlaying: $isPlaying,
                            onLike: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    if likedShorts.contains(short.id) {
                                        likedShorts.remove(short.id)
                                    } else {
                                        likedShorts.insert(short.id)
                                    }
                                }
                                
                                // Haptic feedback
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                            }
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .ignoresSafeArea()
                .onChange(of: currentIndex) { oldValue, newValue in
                    // Handle video change
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                }
            }
        }
        .navigationBarHidden(true)
    }
}

struct ShortsPlayer: View {
    let video: Video
    let isLiked: Bool
    @Binding var isPlaying: Bool
    let onLike: () -> Void
    
    @State private var showingComments: Bool = false
    @State private var showingShare: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Video placeholder
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                AppTheme.Colors.primary.opacity(0.6),
                                AppTheme.Colors.secondary.opacity(0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        VStack {
                            Spacer()
                            
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.white.opacity(0.8))
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isPlaying.toggle()
                                    }
                                }
                            
                            Spacer()
                        }
                    )
                
                // Overlay content
                VStack {
                    Spacer()
                    
                    HStack(alignment: .bottom) {
                        // Video info
                        VStack(alignment: .leading, spacing: 12) {
                            // Creator info
                            HStack(spacing: 12) {
                                AsyncImage(url: URL(string: video.creator.profileImageURL ?? "")) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Circle()
                                        .fill(AppTheme.Colors.surface)
                                }
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 2)
                                )
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(video.creator.displayName)
                                            .font(AppTheme.Typography.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                        
                                        if video.creator.isVerified {
                                            Image(systemName: "checkmark.seal.fill")
                                                .font(.system(size: 14))
                                                .foregroundColor(AppTheme.Colors.primary)
                                        }
                                    }
                                    
                                    Button("Follow") {
                                        // Handle follow
                                    }
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(AppTheme.Colors.primary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.white)
                                    .cornerRadius(16)
                                }
                                
                                Spacer()
                            }
                            
                            // Video title and description
                            VStack(alignment: .leading, spacing: 8) {
                                Text(video.title)
                                    .font(AppTheme.Typography.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .lineLimit(2)
                                
                                Text(video.description)
                                    .font(AppTheme.Typography.body)
                                    .foregroundColor(.white.opacity(0.9))
                                    .lineLimit(3)
                            }
                            .padding(.trailing, 80)
                            
                            // Tags
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(video.tags, id: \.self) { tag in
                                        Text("#\(tag)")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.white.opacity(0.2))
                                            .cornerRadius(12)
                                    }
                                }
                                .padding(.horizontal, 1)
                            }
                            
                            // Music info
                            HStack(spacing: 8) {
                                Image(systemName: "music.note")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                                
                                Text("Original sound - \(video.creator.displayName)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.3))
                            .cornerRadius(16)
                        }
                        .padding(.leading, AppTheme.Spacing.md)
                        .padding(.bottom, AppTheme.Spacing.lg)
                        
                        Spacer()
                        
                        // Action buttons
                        VStack(spacing: 24) {
                            // Like button
                            VStack(spacing: 4) {
                                Button(action: onLike) {
                                    Image(systemName: isLiked ? "heart.fill" : "heart")
                                        .font(.system(size: 28))
                                        .foregroundColor(isLiked ? AppTheme.Colors.primary : .white)
                                        .scaleEffect(isLiked ? 1.2 : 1.0)
                                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isLiked)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Text("\(video.likeCount + (isLiked ? 1 : 0))")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            
                            // Comment button
                            VStack(spacing: 4) {
                                Button(action: { showingComments = true }) {
                                    Image(systemName: "bubble.right")
                                        .font(.system(size: 28))
                                        .foregroundColor(.white)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Text("\(video.commentCount)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            
                            // Share button
                            VStack(spacing: 4) {
                                Button(action: { showingShare = true }) {
                                    Image(systemName: "arrowshape.turn.up.right")
                                        .font(.system(size: 28))
                                        .foregroundColor(.white)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Text("Share")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            
                            // More button
                            Button(action: {}) {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                                    .rotationEffect(.degrees(90))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.trailing, AppTheme.Spacing.md)
                        .padding(.bottom, AppTheme.Spacing.lg)
                    }
                }
                .ignoresSafeArea(.keyboard)
            }
        }
        .sheet(isPresented: $showingComments) {
            CommentsSheet(video: video)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingShare) {
            ShareSheet(video: video)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }
}

struct CommentsSheet: View {
    let video: Video
    @State private var commentText: String = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Comments")
                        .font(AppTheme.Typography.headline)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button("Done") {
                        // Dismiss
                    }
                    .font(AppTheme.Typography.subheadline)
                    .foregroundColor(AppTheme.Colors.primary)
                }
                .padding()
                
                Divider()
                
                // Comments list
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(0..<10) { index in
                            CommentRow()
                        }
                    }
                    .padding()
                }
                
                // Comment input
                VStack(spacing: 0) {
                    Divider()
                    
                    HStack(spacing: 12) {
                        AsyncImage(url: URL(string: "https://picsum.photos/40/40?random=10")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(AppTheme.Colors.surface)
                        }
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                        
                        TextField("Add a comment...", text: $commentText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(AppTheme.Colors.surface)
                            .cornerRadius(20)
                        
                        Button("Post") {
                            // Post comment
                            commentText = ""
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(commentText.isEmpty ? AppTheme.Colors.textTertiary : AppTheme.Colors.primary)
                        .disabled(commentText.isEmpty)
                    }
                    .padding()
                    .background(AppTheme.Colors.background)
                }
            }
        }
    }
}

struct CommentRow: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncImage(url: URL(string: "https://picsum.photos/40/40?random=\(Int.random(in: 1...100))")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(AppTheme.Colors.surface)
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("User\(Int.random(in: 1...999))")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("2m ago")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                    
                    Spacer()
                }
                
                Text("This is an amazing video! Thanks for sharing. Can't wait to see more content like this.")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                HStack(spacing: 16) {
                    Button(action: {}) {
                        HStack(spacing: 4) {
                            Image(systemName: "heart")
                                .font(.system(size: 12))
                            Text("\(Int.random(in: 0...50))")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(AppTheme.Colors.textTertiary)
                    }
                    
                    Button("Reply") {
                        // Reply to comment
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textTertiary)
                }
                .padding(.top, 4)
            }
            
            Spacer()
        }
    }
}

struct ShareSheet: View {
    let video: Video
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Share")
                    .font(AppTheme.Typography.headline)
                    .fontWeight(.bold)
                    .padding()
                
                // Share options
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 24) {
                    ShareOption(icon: "message", title: "Message", color: AppTheme.Colors.primary)
                    ShareOption(icon: "square.and.arrow.up", title: "Copy Link", color: AppTheme.Colors.secondary)
                    ShareOption(icon: "envelope", title: "Email", color: .blue)
                    ShareOption(icon: "camera", title: "Instagram", color: .purple)
                    ShareOption(icon: "message.circle", title: "WhatsApp", color: .green)
                    ShareOption(icon: "link", title: "Facebook", color: .blue)
                    ShareOption(icon: "message.badge", title: "Twitter", color: .blue)
                    ShareOption(icon: "ellipsis", title: "More", color: AppTheme.Colors.textSecondary)
                }
                .padding(.horizontal)
                
                Spacer()
            }
        }
        .presentationDetents([.medium])
    }
}

struct ShareOption: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Button(action: {}) {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 24))
                            .foregroundColor(color)
                    )
            }
            .buttonStyle(PlainButtonStyle())
            
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
    }
}

#Preview {
    ShortsView()
}
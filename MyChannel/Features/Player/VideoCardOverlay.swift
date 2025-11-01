import SwiftUI

struct VideoCardOverlay: View {
    let card: VideoCard
    let onDismiss: () -> Void
    let onTap: () -> Void
    
    @State private var isVisible = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Card content based on type
            switch card.type {
            case .video:
                VideoCardContent(card: card, onTap: onTap)
            case .playlist:
                PlaylistCardContent(card: card, onTap: onTap)
            case .channel:
                ChannelCardContent(card: card, onTap: onTap)
            case .link:
                LinkCardContent(card: card, onTap: onTap)
            case .poll:
                PollCardContent(card: card, onTap: onTap)
            }
        }
        .frame(width: 300)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        )
        .overlay(alignment: .topTrailing) {
            // Close button
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary, .ultraThinMaterial)
            }
            .offset(x: 8, y: -8)
        }
        .scaleEffect(isVisible ? 1.0 : 0.8)
        .opacity(isVisible ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isVisible = true
            }
        }
    }
}

struct VideoCardContent: View {
    let card: VideoCard
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Thumbnail
                AsyncImage(url: URL(string: card.thumbnailURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .aspectRatio(16/9, contentMode: .fill)
                        .overlay(
                            Image(systemName: "play.rectangle")
                                .font(.title)
                                .foregroundColor(.white)
                        )
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // Content
                VStack(alignment: .leading, spacing: 8) {
                    Text(card.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    if let subtitle = card.subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    HStack {
                        Image(systemName: "play.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Text("Watch now")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                        
                        Spacer()
                        
                        if let duration = card.metadata?["duration"] as? String {
                            Text(duration)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.6))
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PlaylistCardContent: View {
    let card: VideoCard
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Playlist thumbnail with count overlay
                ZStack(alignment: .bottomTrailing) {
                    AsyncImage(url: URL(string: card.thumbnailURL ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(16/9, contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .aspectRatio(16/9, contentMode: .fill)
                            .overlay(
                                Image(systemName: "list.bullet.rectangle")
                                    .font(.title)
                                    .foregroundColor(.white)
                            )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    if let videoCount = card.metadata?["videoCount"] as? Int {
                        Text("\(videoCount) videos")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.8))
                            .clipShape(Capsule())
                            .padding(8)
                    }
                }
                
                // Content
                VStack(alignment: .leading, spacing: 8) {
                    Text(card.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    if let subtitle = card.subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    HStack {
                        Image(systemName: "list.bullet")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Text("View playlist")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                        
                        Spacer()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ChannelCardContent: View {
    let card: VideoCard
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 16) {
                // Channel avatar
                AsyncImage(url: URL(string: card.thumbnailURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.title)
                                .foregroundColor(.white)
                        )
                }
                .frame(width: 80, height: 80)
                .clipShape(Circle())
                
                // Channel info
                VStack(spacing: 8) {
                    Text(card.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    
                    if let subscriberCount = card.metadata?["subscriberCount"] as? String {
                        Text("\(subscriberCount) subscribers")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Button("Subscribe") {
                        onTap()
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.red)
                    .clipShape(Capsule())
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct LinkCardContent: View {
    let card: VideoCard
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Link preview
                if let thumbnailURL = card.thumbnailURL {
                    AsyncImage(url: URL(string: thumbnailURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(16/9, contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .aspectRatio(16/9, contentMode: .fill)
                            .overlay(
                                Image(systemName: "link")
                                    .font(.title)
                                    .foregroundColor(.white)
                            )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                // Content
                VStack(alignment: .leading, spacing: 8) {
                    Text(card.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    if let subtitle = card.subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    HStack {
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Text("Visit link")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                        
                        Spacer()
                        
                        if let domain = card.metadata?["domain"] as? String {
                            Text(domain)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PollCardContent: View {
    let card: VideoCard
    let onTap: () -> Void
    @State private var selectedOption: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Poll question
            VStack(alignment: .leading, spacing: 8) {
                Text(card.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                
                if let subtitle = card.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            // Poll options
            if let options = card.metadata?["options"] as? [String] {
                VStack(spacing: 8) {
                    ForEach(options, id: \.self) { option in
                        Button(action: {
                            selectedOption = option
                            onTap()
                        }) {
                            HStack {
                                Text(option)
                                    .font(.subheadline)
                                    .multilineTextAlignment(.leading)
                                
                                Spacer()
                                
                                if selectedOption == option {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                } else {
                                    Circle()
                                        .stroke(Color.secondary, lineWidth: 1)
                                        .frame(width: 20, height: 20)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedOption == option ? Color.blue.opacity(0.1) : Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }
}

#Preview {
    VStack {
        VideoCardOverlay(
            card: VideoCard(
                id: "1",
                type: .video,
                title: "How to Build Amazing iOS Apps",
                subtitle: "Learn SwiftUI from scratch",
                thumbnailURL: "https://example.com/thumb.jpg",
                timestamp: 30.0,
                metadata: ["duration": "10:30"]
            ),
            onDismiss: {},
            onTap: {}
        )
        
        Spacer()
    }
    .padding()
    .background(Color.black.opacity(0.3))
}


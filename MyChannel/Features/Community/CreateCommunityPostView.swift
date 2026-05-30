import SwiftUI

struct CreateCommunityPostView: View {
    let creator: User
    @Environment(\.dismiss) private var dismiss
    
    // Core state
    @State private var selectedPostType: PostType = .text
    @State private var postTitle = ""
    @State private var postContent = ""
    @State private var selectedImages: [String] = []
    @State private var videoURL = ""
    
    // Poll state
    @State private var pollQuestion = ""
    @State private var pollOptions: [String] = ["", ""]
    @State private var pollEndDate = Date().addingTimeInterval(24 * 60 * 60)
    @State private var allowMultipleChoices = false
    
    // Tags
    @State private var tags = ""
    
    // New Settings state
    @State private var audience = "Public"
    @State private var isScheduled = false
    @State private var allowComments = true
    @State private var enableMonetization = false
    
    @State private var isSubmitting = false
    
    var isFormValid: Bool {
        switch selectedPostType {
        case .text, .announcement, .milestone, .live:
            return !postContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .image:
            return !postContent.isEmpty && !selectedImages.isEmpty
        case .video:
            return !postContent.isEmpty && !videoURL.isEmpty
        case .poll:
            return !pollQuestion.isEmpty && pollOptions.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color(.systemBackground).ignoresSafeArea() // Light mode optimized
            
            VStack(spacing: 0) {
                // Top Custom Navigation Bar
                topNavigationBar
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Creator Header
                        creatorHeader
                        
                        // What do you want to create?
                        postTypeSelector
                        
                        // Input Card
                        contentInputCard
                        
                        // Settings Toggles
                        settingsList
                        
                        // Extra spacing for bottom bar
                        Spacer().frame(height: 100)
                    }
                    .padding(.vertical, 20)
                }
            }
            
            // Sticky Bottom Bar
            bottomActionBar
        }
        .navigationBarHidden(true)
    }
    
    // MARK: - Top Navigation Bar
    private var topNavigationBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                HStack(spacing: 6) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                    Text("Drafts")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .clipShape(Capsule())
            }
            
            Spacer()
            
            VStack(spacing: 2) {
                Text("Create Post")
                    .font(.system(size: 16, weight: .bold))
                Text("Post to Community")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    Image(systemName: "cloud")
                        .font(.system(size: 10))
                    Text("Draft saved just now")
                        .font(.system(size: 10))
                }
                .foregroundColor(AppTheme.Colors.primary)
                .padding(.top, 2)
            }
            
            Spacer()
            
            Button(action: createPost) {
                Text("Publish")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(AppTheme.Colors.primary)
                    .clipShape(Capsule())
            }
            .disabled(!isFormValid || isSubmitting)
            .opacity(!isFormValid ? 0.5 : 1.0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Creator Header
    private var creatorHeader: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: creator.profileImageURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color(.systemGray5))
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(creator.displayName)
                        .font(.system(size: 16, weight: .bold))
                    
                    if creator.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 12))
                    }
                }
                
                Text("Posting to MyChannel Community")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.down")
                .foregroundColor(.secondary)
                .font(.system(size: 14, weight: .semibold))
                .padding(8)
                .background(Color(.systemGray6))
                .clipShape(Circle())
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Post Type Selector
    private var postTypeSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What do you want to create?")
                .font(.system(size: 16, weight: .bold))
                .padding(.horizontal, 16)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    // We map the first 5 PostTypes to match the mockup
                    let typesToShow: [PostType] = [.text, .image, .video, .poll, .announcement]
                    
                    ForEach(typesToShow, id: \.self) { type in
                        let isActive = selectedPostType == type
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedPostType = type
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: type.iconName)
                                    .font(.system(size: 14, weight: isActive ? .bold : .medium))
                                Text(type.displayName)
                                    .font(.system(size: 14, weight: isActive ? .bold : .semibold))
                            }
                            .foregroundColor(isActive ? AppTheme.Colors.primary : .primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(isActive ? AppTheme.Colors.primary.opacity(0.1) : Color(.systemGray6))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(isActive ? AppTheme.Colors.primary : Color.clear, lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    // MARK: - Content Input Card
    private var contentInputCard: some View {
        VStack(spacing: 0) {
            // Title Input
            HStack {
                TextField("Add a title (optional)", text: $postTitle)
                    .font(.system(size: 15))
                Spacer()
                Text("\(postTitle.count)/100")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(16)
            
            Divider()
            
            // Body Input
            ZStack(alignment: .topLeading) {
                if postContent.isEmpty {
                    Text("What's on your mind?")
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                }
                TextEditor(text: $postContent)
                    .frame(minHeight: 120)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
            }
            
            HStack {
                Spacer()
                Text("\(postContent.count)/5000")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            
            // Add Media Button
            Button(action: addImages) {
                HStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Add media")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                        Text("Images or videos up to 10GB")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(8)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                }
                .padding(16)
                .background(Color(.systemGray6).opacity(0.5))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), style: StrokeStyle(lineWidth: 1, dash: [4]))
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            
            Divider()
            
            // Bottom Toolbar
            HStack(spacing: 20) {
                toolbarButton(icon: "face.smiling", title: "Emoji")
                toolbarButton(icon: "gift", title: "GIF")
                toolbarButton(icon: "chart.bar", title: "Poll")
                toolbarButton(icon: "calendar", title: "Schedule")
                toolbarButton(icon: "mappin.and.ellipse", title: "Location")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
    
    private func toolbarButton(icon: String, title: String) -> some View {
        Button(action: {}) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Settings Toggles
    private var settingsList: some View {
        VStack(spacing: 0) {
            settingsRow(icon: "globe", title: "Audience", subtitle: "Anyone can view this post") {
                HStack(spacing: 4) {
                    Text("Public")
                        .font(.system(size: 14, weight: .medium))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppTheme.Colors.primary, lineWidth: 1)
                )
                .foregroundColor(AppTheme.Colors.primary)
            }
            
            settingsRow(icon: "calendar", title: "Schedule", subtitle: "Post now") {
                Toggle("", isOn: $isScheduled)
                    .labelsHidden()
                    .tint(AppTheme.Colors.primary)
            }
            
            settingsRow(icon: "bubble.left", title: "Allow comments", subtitle: "Let others comment on this post") {
                Toggle("", isOn: $allowComments)
                    .labelsHidden()
                    .tint(AppTheme.Colors.primary)
            }
            
            settingsRow(icon: "dollarsign.shield", title: "Monetization", subtitle: "Earn from this post") {
                Toggle("", isOn: $enableMonetization)
                    .labelsHidden()
                    .tint(AppTheme.Colors.primary)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
    
    private func settingsRow<Content: View>(icon: String, title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                content()
            }
            .padding(16)
            
            Divider()
                .padding(.leading, 56)
        }
    }
    
    // MARK: - Sticky Bottom Bar
    private var bottomActionBar: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "cloud")
                        .font(.system(size: 20))
                        .foregroundColor(AppTheme.Colors.primary)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Draft saved")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Your post will be saved automatically")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: createPost) {
                    Text("Publish")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(AppTheme.Colors.primary)
                        .clipShape(Capsule())
                }
                .disabled(!isFormValid || isSubmitting)
                .opacity(!isFormValid ? 0.5 : 1.0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24) // accommodate home indicator
        }
        .background(Color(.systemBackground).opacity(0.98))
    }
    
    // MARK: - Logic Methods
    private func addImages() {
        // Placeholder
    }
    
    private func createPost() {
        isSubmitting = true
        
        let tagArray = tags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        
        let poll: Poll? = nil // Ignoring for now as per updated UI
        
        // Use postTitle + postContent for the final content string or update the model
        let finalContent = postTitle.isEmpty ? postContent : "**\(postTitle)**\n\n\(postContent)"
        
        Task {
            let imageURL = selectedPostType == .image ? selectedImages.first : nil
            let _ = await CommunityPostService.shared.createPost(
                creatorId: creator.id,
                type: selectedPostType,
                content: finalContent,
                imageURL: imageURL,
                poll: poll
            )
            await MainActor.run {
                isSubmitting = false
                dismiss()
            }
        }
    }
}

#Preview {
    CreateCommunityPostView(
        creator: User.sampleUsers[0]
    )
}
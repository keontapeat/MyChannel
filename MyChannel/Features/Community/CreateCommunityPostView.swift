//
//  CreateCommunityPostView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI

struct CreateCommunityPostView: View {
    let creator: User
    @ObservedObject var communityService: MockCommunityService
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedPostType: PostType = .text
    @State private var postContent = ""
    @State private var selectedImages: [String] = []
    @State private var videoURL = ""
    @State private var pollQuestion = ""
    @State private var pollOptions: [String] = ["", ""]
    @State private var pollEndDate = Date().addingTimeInterval(24 * 60 * 60) // 1 day
    @State private var allowMultipleChoices = false
    @State private var tags = ""
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
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Creator Header
                    creatorHeader
                    
                    // Post Type Selector
                    postTypeSelector
                    
                    // Content Input
                    contentInputSection
                    
                    // Media Section
                    if selectedPostType == .image {
                        imageSection
                    } else if selectedPostType == .video {
                        videoSection
                    } else if selectedPostType == .poll {
                        pollSection
                    }
                    
                    // Tags Section
                    tagsSection
                }
                .padding()
            }
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Post") {
                        createPost()
                    }
                    .disabled(!isFormValid || isSubmitting)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private var creatorHeader: some View {
        HStack {
            AsyncImage(url: URL(string: creator.profileImageURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color(.systemGray5))
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            
            VStack(alignment: .leading) {
                HStack {
                    Text(creator.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if creator.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                    }
                }
                
                Text("Posting to Community")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    private var postTypeSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Post Type")
                .font(.headline)
                .fontWeight(.semibold)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(PostType.allCases, id: \.self) { type in
                        Button(action: { selectedPostType = type }) {
                            VStack(spacing: 8) {
                                Image(systemName: type.iconName)
                                    .font(.title2)
                                    .foregroundColor(selectedPostType == type ? .white : type.color)
                                
                                Text(type.displayName)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(selectedPostType == type ? .white : .primary)
                            }
                            .frame(width: 80, height: 80)
                            .background(selectedPostType == type ? type.color : Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.horizontal, -16)
        }
    }
    
    private var contentInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(selectedPostType == .poll ? "Poll Description" : "What's on your mind?")
                .font(.headline)
                .fontWeight(.semibold)
            
            TextField("Share something with your community...", text: $postContent, axis: .vertical)
                .textFieldStyle(.plain)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .lineLimit(5...10)
        }
    }
    
    private var imageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Images")
                .font(.headline)
                .fontWeight(.semibold)
            
            if selectedImages.isEmpty {
                Button(action: addImages) {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                        
                        Text("Add Images")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("You can add up to 10 images")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, dash: [8]))
                    )
                }
                .buttonStyle(.plain)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(selectedImages, id: \.self) { imageURL in
                            ZStack(alignment: .topTrailing) {
                                AsyncImage(url: URL(string: imageURL)) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Rectangle()
                                        .fill(Color(.systemGray5))
                                }
                                .frame(width: 100, height: 100)
                                .cornerRadius(8)
                                .clipped()
                                
                                Button(action: { removeImage(imageURL) }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                        .background(Color.white)
                                        .clipShape(Circle())
                                }
                                .offset(x: 8, y: -8)
                            }
                        }
                        
                        if selectedImages.count < 10 {
                            Button(action: addImages) {
                                VStack {
                                    Image(systemName: "plus")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                }
                                .frame(width: 100, height: 100)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, dash: [4]))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.horizontal, -16)
            }
        }
    }
    
    private var videoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Video")
                .font(.headline)
                .fontWeight(.semibold)
            
            TextField("Video URL", text: $videoURL)
                .textFieldStyle(.roundedBorder)
            
            if !videoURL.isEmpty {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: 200)
                    .cornerRadius(12)
                    .overlay(
                        VStack {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.blue)
                            Text("Video Preview")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    )
            }
        }
    }
    
    private var pollSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Poll Settings")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Question")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                TextField("Ask your community a question...", text: $pollQuestion)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Options")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                ForEach(pollOptions.indices, id: \.self) { index in
                    HStack {
                        TextField("Option \(index + 1)", text: $pollOptions[index])
                            .textFieldStyle(.roundedBorder)
                        
                        if pollOptions.count > 2 {
                            Button(action: { removePollOption(at: index) }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                
                if pollOptions.count < 6 {
                    Button(action: addPollOption) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                            Text("Add Option")
                                .fontWeight(.medium)
                        }
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Allow multiple choices", isOn: $allowMultipleChoices)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Poll Duration")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    DatePicker("End Date", selection: $pollEndDate, in: Date()...)
                        .datePickerStyle(.compact)
                }
            }
        }
    }
    
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tags (Optional)")
                .font(.headline)
                .fontWeight(.semibold)
            
            TextField("Add tags separated by commas", text: $tags)
                .textFieldStyle(.roundedBorder)
            
            Text("Help people discover your post with relevant tags")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Actions
    private func addImages() {
        // TODO: Implement image picker
        // For now, add sample images
        let sampleImages = [
            "https://picsum.photos/400/400?random=\(Int.random(in: 1...100))",
            "https://picsum.photos/400/400?random=\(Int.random(in: 101...200))"
        ]
        selectedImages.append(contentsOf: sampleImages.prefix(10 - selectedImages.count))
    }
    
    private func removeImage(_ imageURL: String) {
        selectedImages.removeAll { $0 == imageURL }
    }
    
    private func addPollOption() {
        if pollOptions.count < 6 {
            pollOptions.append("")
        }
    }
    
    private func removePollOption(at index: Int) {
        if pollOptions.count > 2 {
            pollOptions.remove(at: index)
        }
    }
    
    private func createPost() {
        isSubmitting = true
        
        let tagArray = tags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        
        let poll: Poll? = {
            guard selectedPostType == .poll else { return nil }
            let options = pollOptions.compactMap { option in
                let trimmed = option.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : PollOption(text: trimmed)
            }
            return Poll(
                question: pollQuestion,
                options: options,
                endsAt: pollEndDate,
                allowMultipleChoices: allowMultipleChoices
            )
        }()
        
        let newPost = CommunityPost(
            creatorId: creator.id,
            content: postContent,
            imageURLs: selectedPostType == .image ? selectedImages : [],
            videoURL: selectedPostType == .video ? videoURL : nil,
            postType: selectedPostType,
            poll: poll,
            tags: tagArray
        )
        
        Task {
            do {
                _ = try await communityService.createPost(newPost)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Error creating post: \(error)")
                isSubmitting = false
            }
        }
    }
}

#Preview {
    CreateCommunityPostView(
        creator: User.sampleUsers[0],
        communityService: MockCommunityService()
    )
}
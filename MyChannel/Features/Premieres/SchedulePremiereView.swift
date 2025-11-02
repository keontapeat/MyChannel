//
//  SchedulePremiereView.swift
//  MyChannel
//
//  Created by AI Assistant on 11/2/25.
//

import SwiftUI

struct SchedulePremiereView: View {
    let creatorId: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var premieresService = ScheduledPremieresService.shared
    
    // Form State
    @State private var selectedVideo: Video?
    @State private var showingVideoPicker = false
    @State private var title = ""
    @State private var scheduledDate = Date().addingTimeInterval(86400) // Default to tomorrow
    @State private var chatEnabled = true
    @State private var isScheduling = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Select Video") {
                    if let video = selectedVideo {
                        HStack(spacing: 12) {
                            // Video Thumbnail
                            AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                            }
                            .frame(width: 80, height: 45)
                            .cornerRadius(8)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(video.title)
                                    .font(.system(size: 15, weight: .medium))
                                    .lineLimit(2)
                                Text(formatDuration(video.duration))
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button("Change") {
                                showingVideoPicker = true
                            }
                            .font(.system(size: 14))
                        }
                    } else {
                        Button(action: { showingVideoPicker = true }) {
                            HStack {
                                Image(systemName: "play.rectangle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.blue)
                                Text("Choose Video")
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 14))
                            }
                        }
                    }
                }
                
                if selectedVideo != nil {
                    Section("Premiere Details") {
                        TextField("Title (optional)", text: $title)
                            .font(.system(size: 15))
                        
                        DatePicker(
                            "Premiere Date & Time",
                            selection: $scheduledDate,
                            in: Date()...,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .font(.system(size: 15))
                    }
                    
                    Section("Settings") {
                        Toggle(isOn: $chatEnabled) {
                            HStack {
                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                    .foregroundColor(.blue)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Enable Chat")
                                        .font(.system(size: 15, weight: .medium))
                                    Text("Let viewers chat during the premiere")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("💡 Premiere Tips")
                                .font(.system(size: 15, weight: .semibold))
                            
                            VStack(alignment: .leading, spacing: 8) {
                                TipItem(text: "Premieres work best when scheduled at least 24 hours in advance")
                                TipItem(text: "Your subscribers will receive a notification before it starts")
                                TipItem(text: "You can chat with viewers while the video plays")
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Schedule Premiere")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Schedule") {
                        schedulePremiereAction()
                    }
                    .fontWeight(.semibold)
                    .disabled(selectedVideo == nil || isScheduling)
                }
            }
            .sheet(isPresented: $showingVideoPicker) {
                VideoPickerView(creatorId: creatorId, selectedVideo: $selectedVideo)
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .overlay {
                if isScheduling {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Scheduling Premiere...")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                    }
                }
            }
        }
    }
    
    private func schedulePremiereAction() {
        guard let video = selectedVideo else { return }
        
        isScheduling = true
        
        Task {
            let premiereTitle = title.isEmpty ? video.title : title
            
            let premiereId = await premieresService.schedulePremiereForVideo(
                videoId: video.id,
                title: premiereTitle,
                thumbnailURL: video.thumbnailURL,
                scheduledAt: scheduledDate,
                creatorId: creatorId,
                chatEnabled: chatEnabled
            )
            
            await MainActor.run {
                isScheduling = false
                
                if premiereId != nil {
                    // Success
                    HapticManager.shared.notification(type: .success)
                    dismiss()
                } else {
                    // Error
                    errorMessage = "Failed to schedule premiere. Please try again."
                    showError = true
                }
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct TipItem: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 12))
                .foregroundColor(.yellow)
                .padding(.top, 2)
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct VideoPickerView: View {
    let creatorId: String
    @Binding var selectedVideo: Video?
    @Environment(\.dismiss) private var dismiss
    @State private var videos: [Video] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack {
                        ProgressView()
                        Text("Loading your videos...")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                } else if videos.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "play.rectangle")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("No Videos Yet")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text("Upload a video first to schedule a premiere")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List(videos) { video in
                        Button(action: {
                            selectedVideo = video
                            dismiss()
                        }) {
                            HStack(spacing: 12) {
                                // Thumbnail
                                AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                }
                                .frame(width: 100, height: 56)
                                .cornerRadius(8)
                                
                                // Info
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(video.title)
                                        .font(.system(size: 15, weight: .medium))
                                        .lineLimit(2)
                                        .foregroundColor(.primary)
                                    
                                    HStack(spacing: 8) {
                                        Text(formatDuration(video.duration))
                                            .font(.system(size: 13))
                                        Text("•")
                                        Text("\(video.viewCount) views")
                                            .font(.system(size: 13))
                                    }
                                    .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if selectedVideo?.id == video.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Choose Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadVideos()
        }
    }
    
    private func loadVideos() {
        Task {
            // Load creator's videos from VideoFirestoreService
            let service = VideoFirestoreService.shared
            let loadedVideos = await service.fetchVideosByCreator(creatorId: creatorId)
            
            await MainActor.run {
                videos = loadedVideos
                isLoading = false
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}


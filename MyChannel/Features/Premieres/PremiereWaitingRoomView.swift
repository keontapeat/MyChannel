//
//  PremiereWaitingRoomView.swift
//  MyChannel
//
//  Created by AI Assistant on 10/19/25.
//

import SwiftUI

struct PremiereWaitingRoomView: View {
    let premiere: VideoPremiere
    @StateObject private var premiereService = VideoPremiereService.shared
    @StateObject private var chatService = RealTimeChatService.shared
    @State private var waitingRoom: PremiereWaitingRoom?
    @State private var timeUntilStart: TimeInterval = 0
    @State private var isLoading = true
    @State private var showingShareSheet = false
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Video Thumbnail with Countdown
                premiereHeader
                    .frame(height: geometry.size.height * 0.4)
                
                // Premiere Info
                premiereInfo
                    .padding()
                
                // Chat Section (if enabled)
                if premiere.enableChat {
                    Divider()
                    
                    VStack {
                        HStack {
                            Text("Chat")
                                .font(.headline)
                            Spacer()
                            Text("\(waitingRoom?.waitingViewers ?? 0) waiting")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        
                        LiveChatView(streamId: premiere.id, isStreamer: false)
                            .frame(maxHeight: 300)
                    }
                }
                
                Spacer()
            }
        }
        .navigationTitle("Premiere")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Share") {
                    showingShareSheet = true
                }
            }
        }
        .task {
            await loadWaitingRoom()
            startCountdownTimer()
        }
        .sheet(isPresented: $showingShareSheet) {
            NativeShareSheet(items: [generateShareURL()])
        }
    }
    
    private var premiereHeader: some View {
        ZStack {
            // Thumbnail Background
            AsyncImage(url: URL(string: premiere.thumbnailURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
            }
            .clipped()
            
            // Dark Overlay
            Rectangle()
                .fill(Color.black.opacity(0.6))
            
            // Countdown and Play Button
            VStack(spacing: 20) {
                if premiere.enableCountdown && timeUntilStart > 0 {
                    VStack(spacing: 8) {
                        Text("PREMIERES IN")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text(formatCountdown(timeUntilStart))
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .monospacedDigit()
                    }
                } else if premiere.status == .live {
                    VStack(spacing: 8) {
                        Text("🔴 LIVE NOW")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                        
                        Button("Watch Now") {
                            // Navigate to video player
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                }
                
                // Large Play Button
                Button(action: {
                    if premiere.status == .live {
                        // Start watching
                    } else {
                        // Show waiting room
                    }
                }) {
                    Image(systemName: premiere.status == .live ? "play.fill" : "clock.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                        .frame(width: 80, height: 80)
                        .background(Color.black.opacity(0.7))
                        .clipShape(Circle())
                }
            }
        }
    }
    
    private var premiereInfo: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(premiere.title)
                .font(.title2)
                .fontWeight(.semibold)
                .lineLimit(2)
            
            if !premiere.description.isEmpty {
                Text(premiere.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
            
            HStack {
                Label("Scheduled for", systemImage: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(premiere.scheduledDate, style: .date)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(premiere.scheduledDate, style: .time)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            if let waitingRoom = waitingRoom {
                HStack {
                    Label("\(waitingRoom.waitingViewers)", systemImage: "person.2.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("waiting")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func loadWaitingRoom() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            waitingRoom = try await premiereService.getPremiereWaitingRoom(premiere.id)
            timeUntilStart = waitingRoom?.timeUntilStart ?? 0
        } catch {
            print("Failed to load waiting room: \(error)")
        }
    }
    
    private func startCountdownTimer() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if timeUntilStart > 0 {
                timeUntilStart -= 1
            } else {
                timer.invalidate()
                // Refresh waiting room status
                Task {
                    await loadWaitingRoom()
                }
            }
        }
    }
    
    private func formatCountdown(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60
        let seconds = Int(timeInterval) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    private func generateShareURL() -> URL {
        // Generate shareable URL for the premiere
        return URL(string: "https://mychannel.com/premiere/\(premiere.id)")!
    }
}

#Preview {
    NavigationStack {
        PremiereWaitingRoomView(
            premiere: VideoPremiere(
                id: "preview-premiere",
                videoId: "preview-video",
                title: "Epic Gaming Session - World Premiere!",
                description: "Join me for the most anticipated gaming session of the year. We'll be exploring the new expansion pack and taking on the final boss!",
                thumbnailURL: "https://example.com/thumbnail.jpg",
                scheduledDate: Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date(),
                status: .scheduled,
                enableChat: true,
                enableCountdown: true,
                createdAt: Date()
            )
        )
    }
}


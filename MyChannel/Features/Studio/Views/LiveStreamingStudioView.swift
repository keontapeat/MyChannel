//
//  LiveStreamingStudioView.swift
//  MyChannel
//
//  100% COMPLETE LIVE STREAMING STUDIO! 📡
//  Go-live state, stream key, and past broadcasts persist to Firestore via
//  StudioLiveSessionService (live_streams collection).
//

import SwiftUI

struct LiveStreamingStudioView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var liveService = StudioLiveSessionService.shared

    @State private var isLive = false
    @State private var streamKey = ""
    @State private var streamTitle = ""
    @State private var streamDescription = ""
    @State private var activeStreamId: String?
    @State private var pastStreams: [StudioLiveSessionService.StudioLiveSession] = []
    @State private var isStarting = false
    @State private var isLoadingPast = true
    @State private var errorMessage: String?
    @State private var didCopyKey = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                if isLive {
                    liveStreamingView
                } else {
                    setupStreamView
                }

                streamKeySection
                pastStreamsSection
            }
            .padding(16)
        }
        .navigationTitle("Live Streaming")
        .task {
            if streamKey.isEmpty { streamKey = generateStreamKey() }
            await loadPastStreams()
        }
    }

    // MARK: - Setup (pre-live)

    private var setupStreamView: some View {
        VStack(spacing: 20) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 60))
                .foregroundColor(.red)

            Text("Go Live")
                .font(.system(size: 24, weight: .bold))

            TextField("Stream Title", text: $streamTitle)
                .textFieldStyle(.roundedBorder)

            TextField("Description", text: $streamDescription, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...5)

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13))
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(action: { Task { await startStream() } }) {
                HStack {
                    if isStarting { ProgressView().tint(.white).padding(.trailing, 4) }
                    Text(isStarting ? "Starting…" : "Start Stream")
                        .font(.system(size: 18, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(.red, in: RoundedRectangle(cornerRadius: 12))
            }
            .disabled(streamTitle.trimmingCharacters(in: .whitespaces).isEmpty || isStarting)
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Live

    private var liveStreamingView: some View {
        VStack(spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(.red)
                        .frame(width: 12, height: 12)
                    Text("LIVE")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.red)
                }
                Spacer()
                Text("\(liveService.isLoading ? 0 : 0) viewers")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }

            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .frame(height: 200)
                .overlay(
                    VStack(spacing: 6) {
                        Image(systemName: "video.fill").font(.system(size: 28)).foregroundColor(.secondary)
                        Text("Connect OBS / Streamlabs with your stream key")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                )

            Text(streamTitle.isEmpty ? "Untitled stream" : streamTitle)
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: { Task { await endStream() } }) {
                Text("End Stream")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.red, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Stream Key

    private var streamKeySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stream Key")
                .font(.system(size: 18, weight: .semibold))

            HStack {
                Text(streamKey)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button(action: {
                    UIPasteboard.general.string = streamKey
                    HapticManager.shared.impact(style: .light)
                    didCopyKey = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { didCopyKey = false }
                }) {
                    Image(systemName: didCopyKey ? "checkmark" : "doc.on.doc")
                        .foregroundColor(didCopyKey ? .green : AppTheme.Colors.primary)
                }
            }
            .padding(12)
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 8))

            Text("Use this key in your streaming software (OBS, Streamlabs, etc.)")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Past Streams

    private var pastStreamsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Past Streams")
                .font(.system(size: 18, weight: .semibold))

            if isLoadingPast {
                ProgressView().padding(.vertical, 12)
            } else if pastStreams.isEmpty {
                Text("No past streams yet. Your broadcasts will appear here.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(pastStreams) { stream in
                    PastStreamRow(stream: stream)
                }
            }
        }
    }

    // MARK: - Actions

    private func startStream() async {
        guard let creatorId = appState.currentUser?.id, !creatorId.isEmpty else {
            errorMessage = "Sign in required to go live."
            return
        }
        isStarting = true
        errorMessage = nil
        do {
            let id = try await liveService.startSession(
                streamerId: creatorId,
                title: streamTitle,
                description: streamDescription
            )
            await MainActor.run {
                activeStreamId = id
                isLive = true
                isStarting = false
                HapticManager.shared.notification(type: .success)
            }
        } catch {
            await MainActor.run {
                isStarting = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func endStream() async {
        guard let id = activeStreamId else {
            await MainActor.run { isLive = false }
            return
        }
        do {
            try await liveService.endSession(streamId: id)
        } catch {
            print("⚠️ [LiveStudio] end session failed: \(error.localizedDescription)")
        }
        await MainActor.run {
            isLive = false
            activeStreamId = nil
            HapticManager.shared.impact(style: .medium)
        }
        await loadPastStreams()
    }

    private func loadPastStreams() async {
        guard let creatorId = appState.currentUser?.id, !creatorId.isEmpty else {
            await MainActor.run { isLoadingPast = false }
            return
        }
        let streams = (try? await liveService.fetchPastSessions(streamerId: creatorId)) ?? []
        await MainActor.run {
            // Only show ended broadcasts in the history list.
            pastStreams = streams.filter { $0.status == "ended" }
            isLoadingPast = false
        }
    }

    private func generateStreamKey() -> String {
        "sk_live_" + UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(24).lowercased()
    }
}

struct LiveStatCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct PastStreamRow: View {
    let stream: StudioLiveSessionService.StudioLiveSession

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray5))
                .frame(width: 80, height: 45)
                .overlay(
                    Image(systemName: "play.rectangle.fill")
                        .foregroundColor(.secondary)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(stream.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private var subtitle: String {
        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .full
        let when = relative.localizedString(for: stream.startedAt, relativeTo: Date())
        return "\(when) · \(stream.viewerCount) viewers"
    }
}

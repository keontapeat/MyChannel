//
//  WatchPartySetupView.swift
//  MyChannel
//
//  Created by Keonta.
//

import SwiftUI

struct WatchPartySetupView: View {
    @Environment(\.dismiss) private var dismiss
    let video: Video

    @StateObject private var partyService = WatchPartyService.shared
    @State private var isCreating = false
    @State private var createdParty: WatchParty?
    @State private var showingInviteSheet = false
    @State private var errorMessage: String?
    @State private var showError = false

    init(video: Video) {
        self.video = video
    }

    var partyLink: String {
        guard let party = createdParty else { return "" }
        return "https://mychannel.app/w/\(party.id)"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "tv.badge.wifi")
                    .font(.system(size: 64))
                    .foregroundColor(.blue)
                    .padding(.top, 40)

                Text("Start a Watch Party")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Invite friends to watch \"\(video.title)\" together in real-time. Playback and chat will be synchronized.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 32)

                if let party = createdParty {
                    // Party created — show invite options
                    VStack(spacing: 12) {
                        Text("Party Created!")
                            .font(.headline)
                            .foregroundColor(.green)

                        HStack(spacing: 8) {
                            Text(partyLink)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)

                            Button {
                                UIPasteboard.general.string = partyLink
                                HapticManager.shared.notification(type: .success)
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal, 24)

                        Button {
                            showingInviteSheet = true
                        } label: {
                            Label("Share Invite", systemImage: "square.and.arrow.up")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 32)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else {
                    Button {
                        createParty()
                    } label: {
                        Group {
                            if isCreating {
                                HStack(spacing: 8) {
                                    ProgressView().progressViewStyle(.circular).tint(.white)
                                    Text("Starting…")
                                }
                            } else {
                                Text("Start Watch Party")
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(isCreating)
                    .padding(.horizontal, 32)
                    .padding(.top, 20)
                }

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showingInviteSheet) {
                ShareSheet(items: [partyLink])
            }
            .alert("Watch Party Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "Failed to create watch party.")
            }
        }
    }

    private func createParty() {
        guard let uid = AppState.shared.currentUser?.id else { return }
        isCreating = true
        Task { @MainActor in
            do {
                let party = try await partyService.createParty(hostUid: uid, videoId: video.id)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    createdParty = party
                }
                HapticManager.shared.notification(type: .success)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isCreating = false
        }
    }
}

// MARK: - System Share Sheet wrapper
private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}

#Preview {
    WatchPartySetupView(video: Video.sampleVideos[0])
}

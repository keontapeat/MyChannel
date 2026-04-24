//
//  VideoSummarySheet.swift
//  MyChannel
//
//  Phase 32 UI: TL;DW summary sheet for any video.
//

import SwiftUI

struct VideoSummarySheet: View {
    let videoId: String
    let title: String
    let description: String
    let duration: Double
    let onSeek: ((Double) -> Void)?

    @StateObject private var service = AIVideoSummaryService.shared
    @State private var summary: AIVideoSummary?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if service.isGenerating {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Generating summary...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else if let s = summary {
                        // Short summary
                        VStack(alignment: .leading, spacing: 6) {
                            Label("TL;DW", systemImage: "text.quote")
                                .font(.headline)
                            Text(s.shortSummary)
                                .font(.body)
                        }

                        // Bullet points
                        if !s.bulletPoints.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Key Takeaways", systemImage: "list.bullet")
                                    .font(.headline)
                                ForEach(s.bulletPoints, id: \.self) { pt in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("•").foregroundStyle(Color.accentColor)
                                        Text(pt).font(.subheadline)
                                    }
                                }
                            }
                        }

                        // Key moments
                        if !s.keyMoments.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Key Moments", systemImage: "clock.badge.checkmark")
                                    .font(.headline)
                                ForEach(s.keyMoments) { moment in
                                    Button {
                                        onSeek?(moment.timestamp)
                                        dismiss()
                                    } label: {
                                        HStack {
                                            Text(formatTime(moment.timestamp))
                                                .font(.caption.monospacedDigit())
                                                .foregroundStyle(Color.accentColor)
                                                .frame(width: 50, alignment: .trailing)
                                            Text(moment.title)
                                                .font(.subheadline)
                                                .foregroundStyle(.primary)
                                        }
                                    }
                                }
                            }
                        }
                    } else if let err = service.lastError {
                        Text(err).foregroundStyle(.red).font(.subheadline)
                    }
                }
                .padding()
            }
            .navigationTitle("Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                }
            }
            .task {
                summary = try? await service.summarize(
                    videoId: videoId, title: title,
                    description: description, durationSeconds: duration
                )
            }
        }
    }

    private func formatTime(_ s: Double) -> String {
        let m = Int(s) / 60; let sec = Int(s) % 60
        return String(format: "%d:%02d", m, sec)
    }
}

#Preview {
    VideoSummarySheet(videoId: "test", title: "Test", description: "Desc", duration: 600, onSeek: nil)
}

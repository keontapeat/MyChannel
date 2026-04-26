//
//  LiveStreamsCommandCenterView.swift
//  MyChannel
//
//  Phase 261: Live Stream Monitoring Tab
//

import SwiftUI

struct LiveStreamsCommandCenterView: View {
    @StateObject private var service = LiveStreamMonitorService.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // Summary Card
                VStack(spacing: 10) {
                    Text("LIVE STREAM MONITORING")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                    HStack(spacing: 20) {
                        VStack {
                            Text("\(service.activeStreams.count)")
                                .font(.system(size: 28, weight: .black)).foregroundColor(.cyan)
                            Text("Active").font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
                        }
                        VStack {
                            Text("\(service.totalViewers)")
                                .font(.system(size: 28, weight: .black)).foregroundColor(.green)
                            Text("Viewers").font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
                        }
                        VStack {
                            Text("\(service.unhealthyStreams)")
                                .font(.system(size: 28, weight: .black)).foregroundColor(service.unhealthyStreams > 0 ? .red : .green)
                            Text("Issues").font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
                        }
                    }
                }
                .padding(16)
                .background(Color.cyan.opacity(0.08))
                .cornerRadius(12)
                
                // Stream List
                ForEach(service.activeStreams) { stream in
                    LiveStreamCard(stream: stream)
                }
            }
            .padding(16)
        }
        .navigationTitle("Live Streams")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LiveStreamCard: View {
    let stream: LiveStreamMonitorService.LiveStreamMetrics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle().fill(stream.isHealthy ? Color.green : Color.orange).frame(width: 8, height: 8)
                Text(stream.creatorName)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(stream.statusColor.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(stream.isHealthy ? .green : .orange)
            }
            HStack(spacing: 16) {
                Label("\(stream.viewerCount)", systemImage: "eye.fill")
                    .font(.system(size: 11, design: .monospaced))
                Label("\(Int(stream.bitrate)) kbps", systemImage: "speedometer")
                    .font(.system(size: 11, design: .monospaced))
                Label("\(Int(stream.latency))ms", systemImage: "clock")
                    .font(.system(size: 11, design: .monospaced))
            }
            .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 1)
    }
}

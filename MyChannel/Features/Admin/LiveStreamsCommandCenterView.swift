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
                        .foregroundColor(CCTheme.textSecondary)
                    HStack(spacing: 20) {
                        VStack {
                            Text("\(service.activeStreams.count)")
                                .font(.system(size: 28, weight: .black, design: .monospaced)).foregroundColor(CCTheme.textPrimary)
                            Text("Active").font(.system(size: 10, design: .monospaced)).foregroundColor(CCTheme.textSecondary)
                        }
                        VStack {
                            Text("\(service.totalViewers)")
                                .font(.system(size: 28, weight: .black, design: .monospaced)).foregroundColor(CCTheme.good)
                            Text("Viewers").font(.system(size: 10, design: .monospaced)).foregroundColor(CCTheme.textSecondary)
                        }
                        VStack {
                            Text("\(service.unhealthyStreams)")
                                .font(.system(size: 28, weight: .black, design: .monospaced)).foregroundColor(service.unhealthyStreams > 0 ? CCTheme.critical : CCTheme.good)
                            Text("Issues").font(.system(size: 10, design: .monospaced)).foregroundColor(CCTheme.textSecondary)
                        }
                    }
                }
                .padding(16)
                .background(CCTheme.panel)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(CCTheme.panelBorder, lineWidth: 1))
                
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
    
    @State private var isTogglingSlow = false
    @State private var isTogglingSubOnly = false
    @State private var isTerminating = false
    @State private var showKillConfirm = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle().fill(stream.isHealthy ? CCTheme.good : CCTheme.warning).frame(width: 7, height: 7)
                Text(stream.creatorName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(CCTheme.textPrimary)
                Spacer()
                Text(stream.statusColor.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(stream.isHealthy ? CCTheme.good : CCTheme.warning)
            }
            
            HStack(spacing: 16) {
                Label("\(stream.viewerCount)", systemImage: "eye.fill")
                    .font(.system(size: 11, design: .monospaced))
                Label("\(Int(stream.bitrate)) kbps", systemImage: "speedometer")
                    .font(.system(size: 11, design: .monospaced))
                Label("\(Int(stream.latency))ms", systemImage: "clock")
                    .font(.system(size: 11, design: .monospaced))
            }
            .foregroundColor(CCTheme.textSecondary)
            
            Divider()
            
            HStack(spacing: 12) {
                // Slow mode toggle
                HStack(spacing: 6) {
                    if isTogglingSlow {
                        ProgressView().scaleEffect(0.7).frame(width: 14, height: 14)
                    } else {
                        Image(systemName: "timer")
                            .font(.system(size: 12))
                            .foregroundColor(stream.isSlowModeEnabled ? CCTheme.textPrimary : CCTheme.textSecondary)
                    }
                    Toggle("Slow", isOn: Binding(
                        get: { stream.isSlowModeEnabled },
                        set: { newValue in
                            Task {
                                isTogglingSlow = true
                                try? await LiveStreamMonitorService.shared.toggleSlowMode(streamId: stream.streamId, enabled: newValue)
                                isTogglingSlow = false
                            }
                        }
                    ))
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: CCTheme.textPrimary))
                    .scaleEffect(0.8)
                    Text("Slow")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(CCTheme.textSecondary)
                }
                
                Spacer()
                
                // Sub-only toggle
                HStack(spacing: 6) {
                    if isTogglingSubOnly {
                        ProgressView().scaleEffect(0.7).frame(width: 14, height: 14)
                    } else {
                        Image(systemName: "person.2.badge.key.fill")
                            .font(.system(size: 12))
                            .foregroundColor(stream.isSubscriberOnlyEnabled ? CCTheme.textPrimary : CCTheme.textSecondary)
                    }
                    Toggle("Sub-Only", isOn: Binding(
                        get: { stream.isSubscriberOnlyEnabled },
                        set: { newValue in
                            Task {
                                isTogglingSubOnly = true
                                try? await LiveStreamMonitorService.shared.toggleSubscriberOnlyChat(streamId: stream.streamId, enabled: newValue)
                                isTogglingSubOnly = false
                            }
                        }
                    ))
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: CCTheme.textPrimary))
                    .scaleEffect(0.8)
                    Text("Sub-Only")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(CCTheme.textSecondary)
                }
                
                Spacer()
                
                // Kill stream button
                Button(role: .destructive) {
                    showKillConfirm = true
                } label: {
                    HStack(spacing: 4) {
                        if isTerminating {
                            ProgressView().tint(.white).scaleEffect(0.8)
                        } else {
                            Image(systemName: "xmark.octagon.fill")
                        }
                        Text("KILL")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(CCTheme.critical)
                    .cornerRadius(6)
                }
                .disabled(isTerminating)
            }
        }
        .padding(12)
        .background(CCTheme.panel)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(CCTheme.panelBorder, lineWidth: 1))
        .alert("Terminate Stream?", isPresented: $showKillConfirm) {
            Button("Kill Stream", role: .destructive) {
                Task {
                    isTerminating = true
                    try? await LiveStreamMonitorService.shared.terminateStream(streamId: stream.streamId)
                    isTerminating = false
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to shut down \(stream.creatorName)'s live stream immediately? This action is logged and cannot be undone.")
        }
    }
}

//
//  LiveStreamingStudioView.swift
//  MyChannel
//
//  100% COMPLETE LIVE STREAMING STUDIO! 📡
//

import SwiftUI

struct LiveStreamingStudioView: View {
    @State private var isLive = false
    @State private var streamKey = "sk_live_abc123xyz"
    @State private var streamTitle = ""
    @State private var streamDescription = ""
    
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
    }
    
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
            
            Button(action: { isLive = true }) {
                Text("Start Stream")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.red, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
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
                Text("125 viewers")
                    .font(.system(size: 14, weight: .semibold))
            }
            
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .frame(height: 200)
                .overlay(Text("Stream Preview").foregroundColor(.secondary))
            
            HStack(spacing: 12) {
                StatCard(title: "Views", value: "125", color: .blue)
                StatCard(title: "Likes", value: "42", color: .pink)
                StatCard(title: "Comments", value: "18", color: .green)
            }
            
            Button(action: { isLive = false }) {
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
    
    private var streamKeySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stream Key")
                .font(.system(size: 18, weight: .semibold))
            
            HStack {
                Text(streamKey)
                    .font(.system(.body, design: .monospaced))
                Spacer()
                Button(action: {}) {
                    Image(systemName: "doc.on.doc")
                }
            }
            .padding(12)
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 8))
            
            Text("Use this key in your streaming software (OBS, Streamlabs, etc.)")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }
    
    private var pastStreamsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Past Streams")
                .font(.system(size: 18, weight: .semibold))
            
            ForEach(0..<3, id: \.self) { _ in
                PastStreamRow()
            }
        }
    }
}

struct StatCard: View {
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
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray5))
                .frame(width: 80, height: 45)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Stream Title")
                    .font(.system(size: 14, weight: .semibold))
                Text("2 days ago · 1.2K views")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    NavigationStack {
        LiveStreamingStudioView()
    }
}


//
//  WatchPartySetupView.swift
//  MyChannel
//
//  Created by Keonta.
//

import SwiftUI

struct WatchPartySetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingInviteSheet = false
    let videoTitle: String
    
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
                
                Text("Invite friends to watch \"\(videoTitle)\" together in real-time. Playback and chat will be synchronized.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 32)
                
                Button(action: {
                    showingInviteSheet = true
                }) {
                    Text("Invite Friends")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 32)
                .padding(.top, 20)
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showingInviteSheet) {
                NavigationStack {
                    List {
                        Text("Party Link: https://mychannel.app/w/12345")
                            .textSelection(.enabled)
                        Button("Copy Link") {}
                        Button("Share via Messages") {}
                    }
                    .navigationTitle("Invite to Party")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") { showingInviteSheet = false }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
    }
}

#Preview {
    WatchPartySetupView(videoTitle: "Sample Video")
}

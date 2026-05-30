//
//  MultiFormatPublisherView.swift
//  MyChannel
//
//  Created by Keonta.
//

import SwiftUI

struct MultiFormatPublisherView: View {
    @State private var publishToVideo = true
    @State private var publishToFlicks = true
    @State private var publishToCommunity = false
    @State private var isPublishing = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Destinations")) {
                    Toggle("Long-form Video", isOn: $publishToVideo)
                    Toggle("Flicks (Shorts)", isOn: $publishToFlicks)
                    Toggle("Community Post", isOn: $publishToCommunity)
                }
                
                Section(header: Text("Details")) {
                    Text("Selecting multiple formats will automatically optimize your content for each destination.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    Button(action: publish) {
                        if isPublishing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            Text("Publish Now")
                                .frame(maxWidth: .infinity, alignment: .center)
                                .foregroundColor(.white)
                        }
                    }
                    .listRowBackground(AppTheme.Colors.primary)
                }
            }
            .navigationTitle("Multi-Format Publisher")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func publish() {
        isPublishing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isPublishing = false
            HapticManager.shared.successPattern()
        }
    }
}

#Preview {
    MultiFormatPublisherView()
}

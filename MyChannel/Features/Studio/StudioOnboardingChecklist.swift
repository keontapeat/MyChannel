//
//  StudioOnboardingChecklist.swift
//  MyChannel
//
//  Created by AI Assistant on 10/15/25.
//

import SwiftUI

struct StudioOnboardingChecklist: View {
    @AppStorage("studioOnboardingDone") private var done = false
    var onDismiss: () -> Void = {}
    
    private let items: [(String, String)] = [
        ("Upload your first video", "square.and.arrow.up"),
        ("Set payout settings", "creditcard"),
        ("Create a membership tier", "person.badge.plus"),
        ("Share your channel", "square.and.arrow.up.on.square")
    ]
    
    var body: some View {
        if done { EmptyView() } else {
            VStack(spacing: 16) {
                HStack {
                    Text("Welcome to Creator Studio")
                        .font(.headline)
                    Spacer()
                    Button(action: complete) { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                }
                ForEach(items, id: \.0) { title, icon in
                    HStack(spacing: 10) {
                        Image(systemName: icon)
                        Text(title)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
                Button("Got it") { complete() }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .padding()
        }
    }
    private func complete() { done = true; onDismiss() }
}

#Preview {
    StudioOnboardingChecklist()
}



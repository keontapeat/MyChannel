//
//  UnauthenticatedPromptView.swift
//  MyChannel
//
//  Created by AI Assistant on 9/27/25.
//

import SwiftUI

// MARK: - Unauthenticated Prompt View
struct UnauthenticatedPromptView: View {
    let promptType: PromptType
    let onSignIn: () -> Void
    
    enum PromptType {
        case subscriptions
        case history
        case watchLater
        case profile
        
        var title: String {
            switch self {
            case .subscriptions:
                return "Don't miss new videos"
            case .history:
                return "Keep track of what you watch"
            case .watchLater:
                return "Enjoy your favorite videos"
            case .profile:
                return "Enjoy your favorite videos"
            }
        }
        
        var subtitle: String {
            switch self {
            case .subscriptions:
                return "Sign in to see updates from your favorite YouTube channels"
            case .history:
                return "Sign in to access videos that you've liked or saved"
            case .watchLater:
                return "Sign in to access videos that you've liked or saved"
            case .profile:
                return "Sign in to access videos that you've liked or saved"
            }
        }
        
        var iconName: String {
            switch self {
            case .subscriptions:
                return "play.rectangle.stack"
            case .history:
                return "clock.arrow.circlepath"
            case .watchLater:
                return "folder"
            case .profile:
                return "folder"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 24) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color(.systemGray6))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: promptType.iconName)
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(.secondary)
                }
                
                // Text content
                VStack(spacing: 12) {
                    Text(promptType.title)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    Text(promptType.subtitle)
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                // Sign in button
                Button(action: {
                    HapticManager.shared.impact(style: .light)
                    onSignIn()
                }) {
                    Text("Sign in")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(height: 40)
                        .frame(maxWidth: 120)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.blue)
                        )
                }
                .buttonStyle(PressableScaleButtonStyle(scale: 0.96))
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Preview
#Preview("Subscriptions Prompt") {
    UnauthenticatedPromptView(promptType: .subscriptions) {
        print("Sign in tapped")
    }
}

#Preview("History Prompt") {
    UnauthenticatedPromptView(promptType: .history) {
        print("Sign in tapped")
    }
}

#Preview("Profile Prompt") {
    UnauthenticatedPromptView(promptType: .profile) {
        print("Sign in tapped")
    }
}

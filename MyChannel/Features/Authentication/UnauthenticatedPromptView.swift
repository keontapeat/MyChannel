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
                return "Sign in to see updates from your favorite creators"
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
            
            VStack(spacing: 20) {
                // Clean icon circle - minimal and professional
                ZStack {
                    Circle()
                        .fill(Color(.systemGray5).opacity(0.3))
                        .frame(width: 140, height: 140)
                    
                    Image(systemName: promptType.iconName)
                        .font(.system(size: 50, weight: .regular))
                        .foregroundColor(Color(.systemGray))
                }
                
                // Text content - clean and minimal
                VStack(spacing: 8) {
                    Text(promptType.title)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    Text(promptType.subtitle)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(.top, 4)
                
                // Clean sign in button - matches iOS design language
                Button(action: {
                    HapticManager.shared.impact(style: .light)
                    onSignIn()
                }) {
                    Text("Sign in")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(height: 44)
                        .frame(width: 180)
                        .background(
                            RoundedRectangle(cornerRadius: 22)
                                .fill(Color(red: 0.2, green: 0.5, blue: 1.0))
                        )
                }
                .buttonStyle(PressableScaleButtonStyle(scale: 0.97))
                .padding(.top, 8)
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

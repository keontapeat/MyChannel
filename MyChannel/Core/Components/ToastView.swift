//
//  ToastView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI

struct ToastView: View {
    let text: String
    let type: ToastType
    let duration: TimeInterval
    
    init(text: String, type: ToastType = .info, duration: TimeInterval = 2.0) {
        self.text = text
        self.type = type
        self.duration = duration
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.iconName)
                .foregroundColor(type.iconColor)
                .font(.system(size: 16, weight: .medium))
            
            Text(text)
                .font(AppTheme.Typography.bodyMedium)
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg)
                .fill(type.backgroundColor)
                .shadow(
                    color: .black.opacity(0.3),
                    radius: 8,
                    x: 0,
                    y: 4
                )
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
}

enum ToastType: Equatable {
    case success
    case error
    case warning
    case info
    
    var backgroundColor: Color {
        switch self {
        case .success:
            return AppTheme.Colors.success
        case .error:
            return AppTheme.Colors.error
        case .warning:
            return AppTheme.Colors.warning
        case .info:
            return Color.black.opacity(0.8)
        }
    }
    
    var iconName: String {
        switch self {
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "xmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .info:
            return "info.circle.fill"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .success, .error, .warning:
            return .white
        case .info:
            return .white
        }
    }
}

// MARK: - Toast Manager
@MainActor
class ToastManager: ObservableObject {
    @Published var toast: ToastData?
    
    func show(_ text: String, type: ToastType = .info, duration: TimeInterval = 2.0) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            toast = ToastData(text: text, type: type, duration: duration)
        }
        
        // Auto-hide after duration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                self.toast = nil
            }
        }
    }
    
    func hide() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            toast = nil
        }
    }
}

struct ToastData: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let type: ToastType
    let duration: TimeInterval
    
    // MARK: - Equatable
    static func == (lhs: ToastData, rhs: ToastData) -> Bool {
        lhs.id == rhs.id &&
        lhs.text == rhs.text &&
        lhs.type == rhs.type &&
        lhs.duration == rhs.duration
    }
}

// MARK: - View Extension for Easy Toast Usage
extension View {
    func toast(toast: Binding<ToastData?>) -> some View {
        self.overlay(
            ZStack {
                if let toastData = toast.wrappedValue {
                    ToastView(
                        text: toastData.text,
                        type: toastData.type,
                        duration: toastData.duration
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1000)
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: toast.wrappedValue)
            , alignment: .bottom
        )
    }
    
    func toast<T: ObservableObject>(manager: T) -> some View where T: ToastManager {
        self.overlay(
            ZStack {
                if let toastData = manager.toast {
                    ToastView(
                        text: toastData.text,
                        type: toastData.type,
                        duration: toastData.duration
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1000)
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: manager.toast)
            , alignment: .bottom
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        ToastView(text: "Success! Your action completed.", type: .success)
        ToastView(text: "Error! Something went wrong.", type: .error)
        ToastView(text: "Warning! Please check your input.", type: .warning)
        ToastView(text: "Link copied to clipboard!", type: .info)
    }
    .padding()
    .background(AppTheme.Colors.background)
}

#Preview("Toast Demo") {
    ToastDemoView()
}

struct ToastDemoView: View {
    @StateObject private var toastManager = ToastManager()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Toast Demo")
                .font(AppTheme.Typography.largeTitle)
                .padding()
            
            VStack(spacing: 16) {
                Button("Show Success Toast") {
                    toastManager.show("Success! Action completed.", type: .success)
                }
                .primaryButtonStyle()
                
                Button("Show Error Toast") {
                    toastManager.show("Error! Something went wrong.", type: .error)
                }
                .primaryButtonStyle()
                
                Button("Show Warning Toast") {
                    toastManager.show("Warning! Please check this.", type: .warning)
                }
                .primaryButtonStyle()
                
                Button("Show Info Toast") {
                    toastManager.show("Link copied to clipboard!", type: .info)
                }
                .primaryButtonStyle()
            }
            
            Spacer()
        }
        .toast(manager: toastManager)
        .background(AppTheme.Colors.background)
    }
}
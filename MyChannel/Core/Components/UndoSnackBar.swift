//
//  UndoSnackBar.swift
//  MyChannel
//
//  Reusable undo snackbar component
//

import SwiftUI

// MARK: - Undo Snack Bar

struct UndoSnackBar: View {
    let message: String
    let actionTitle: String
    let onAction: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(message)
                    .font(.system(size: 15, weight: .semibold))
                Text("Tap undo to restore.")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Spacer()
            
            Button(actionTitle) {
                onAction()
            }
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppTheme.Colors.primary)
            .clipShape(Capsule())
            
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.Colors.surface)
                .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        )
        .padding(.bottom, 16)
    }
}

// MARK: - Generic Snackbar (More Flexible)

struct GenericSnackBar: View {
    let message: String
    let subtitle: String?
    let actionTitle: String?
    let actionColor: Color
    let onAction: (() -> Void)?
    let onDismiss: () -> Void
    
    init(
        message: String,
        subtitle: String? = nil,
        actionTitle: String? = nil,
        actionColor: Color = AppTheme.Colors.primary,
        onAction: (() -> Void)? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.message = message
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.actionColor = actionColor
        self.onAction = onAction
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(message)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
            
            Spacer()
            
            if let actionTitle, let onAction {
                Button(actionTitle) {
                    onAction()
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(actionColor)
                .clipShape(Capsule())
            }
            
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.Colors.surface)
                .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        )
    }
}

// MARK: - Previews

#Preview("Undo Snack Bar") {
    VStack {
        Spacer()
        UndoSnackBar(
            message: "Deleted 3 videos",
            actionTitle: "Undo",
            onAction: { print("Undo tapped") },
            onDismiss: { print("Dismissed") }
        )
        .padding(.horizontal, 16)
    }
    .background(AppTheme.Colors.background)
}

#Preview("Generic Snack Bar") {
    VStack {
        Spacer()
        GenericSnackBar(
            message: "Video uploaded successfully",
            subtitle: "It may take a few minutes to process",
            actionTitle: "View",
            onAction: { print("View tapped") },
            onDismiss: { print("Dismissed") }
        )
        .padding(.horizontal, 16)
    }
    .background(AppTheme.Colors.background)
}

#Preview("Generic Snack Bar - No Action") {
    VStack {
        Spacer()
        GenericSnackBar(
            message: "Changes saved",
            onDismiss: { print("Dismissed") }
        )
        .padding(.horizontal, 16)
    }
    .background(AppTheme.Colors.background)
}

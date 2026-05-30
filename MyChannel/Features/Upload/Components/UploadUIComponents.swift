import SwiftUI
import PhotosUI

struct EditingToolCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(isPressed ? color.opacity(0.15) : AppTheme.Colors.cardBackground)
                        .frame(width: 56, height: 56)
                        .overlay(
                            Circle()
                                .stroke(isPressed ? color.opacity(0.4) : AppTheme.Colors.divider.opacity(0.2), lineWidth: 1.5)
                        )
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(isPressed ? color : AppTheme.Colors.textSecondary)
                        .scaleEffect(isPressed ? 1.05 : 1.0)
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isPressed)
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 160, alignment: .top)
            .padding(.vertical, 18)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isPressed ? AppTheme.Colors.cardBackground.opacity(0.8) : AppTheme.Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AppTheme.Colors.divider.opacity(isPressed ? 0.4 : 0.2), lineWidth: 1)
                    )
            )
            .shadow(
                color: .black.opacity(isPressed ? 0.1 : 0.04),
                radius: isPressed ? 10 : 6,
                x: 0,
                y: isPressed ? 6 : 3
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                        HapticManager.shared.impact(style: .light)
                    }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
}

struct UploadCreationModeBar: View {
    @Binding var selected: UploadView.CreationMode
    let onTap: (UploadView.CreationMode) -> Void
    
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.sizeCategory) private var sizeCategory
    @Namespace private var ns
    
    private var isPad: Bool { hSizeClass == .regular }
    private var isCompactWidth: Bool {
        ((UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.bounds.width ?? 390) < 360
    }
    private var showLabels: Bool {
        return isPad || (!isCompactWidth && sizeCategory <= .large)
    }
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(UploadView.CreationMode.allCases) { mode in
                NuclearModeButton(
                    ns: ns,
                    mode: mode,
                    isSelected: selected == mode,
                    showLabels: showLabels,
                    isExpanded: false,
                    onTap: {
                        HapticManager.shared.impact(style: .medium)
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            selected = mode
                        }
                        onTap(mode)
                    }
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 28)
                    .fill(.ultraThinMaterial)
                
                RoundedRectangle(cornerRadius: 28)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: selected)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Creation mode")
    }
}

struct NuclearModeButton: View {
    let ns: Namespace.ID
    let mode: UploadView.CreationMode
    let isSelected: Bool
    let showLabels: Bool
    let isExpanded: Bool
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                if isSelected {
                    Capsule()
                        .fill(AppTheme.Colors.textPrimary)
                        .matchedGeometryEffect(id: "selector", in: ns)
                        .frame(height: 44)
                        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                }
                
                VStack(spacing: 4) {
                    Image(systemName: mode.icon)
                        .font(.system(size: 16, weight: .bold))
                        .symbolRenderingMode(.hierarchical)
                    
                    if showLabels {
                        Text(mode.title)
                            .font(.system(size: 11, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .padding(.horizontal, showLabels ? 14 : 12)
                .frame(height: 44)
                .frame(minWidth: showLabels ? 0 : 44)
                .foregroundColor(isSelected ? .white : .white.opacity(0.8))
                .scaleEffect(isPressed ? 0.92 : 1.0)
            }
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .accessibilityLabel(mode.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

struct UploadQualitySettingsView: View {
    @Binding var selected: UploadView.VideoQuality
    var body: some View {
        NavigationStack {
            List {
                ForEach(UploadView.VideoQuality.allCases) { quality in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(quality.title).font(.headline)
                            Text(quality.description).font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        if selected == quality {
                            Image(systemName: "checkmark").foregroundColor(AppTheme.Colors.primary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { selected = quality }
                }
            }
            .navigationTitle("Upload Quality")
        }
    }
}


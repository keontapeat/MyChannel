import SwiftUI

struct VideoFilterBar: View {
    @Binding var searchText: String
    @Binding var visibilityFilter: VideoVisibilityFilter
    @Binding var typeFilter: VideoTypeFilter
    @Binding var showingFilterTray: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                UIKitSearchBar(
                    text: $searchText,
                    placeholder: "Search"
                )
                .frame(height: 42)

                Button {
                    HapticManager.shared.impact(style: .light)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                        showingFilterTray.toggle()
                    }
                } label: {
                    Image(systemName: showingFilterTray ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(showingFilterTray ? AppTheme.Colors.primary : AppTheme.Colors.textPrimary)
                        .frame(width: 42, height: 42)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            if showingFilterTray {
                UIKitProfileFilterRow(
                    visibilityFilter: $visibilityFilter,
                    typeFilter: $typeFilter
                )
                .frame(height: 36)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}

struct ProfileFilterChip: View {
    let title: String
    let isSelected: Bool
    var icon: String? = nil
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
            .padding(.vertical, 8)
            .foregroundColor(isSelected ? .white : AppTheme.Colors.textPrimary)
            .background(
                Capsule()
                    .fill(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.surface)
            )
            .overlay(
                Capsule()
                    .stroke(AppTheme.Colors.divider.opacity(isSelected ? 0 : 0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

enum VideoVisibilityFilter: CaseIterable {
    case all, publicOnly, unlisted, privateOnly, scheduled
    
    var title: String {
        switch self {
        case .all: return "All"
        case .publicOnly: return "Public"
        case .unlisted: return "Unlisted"
        case .privateOnly: return "Private"
        case .scheduled: return "Scheduled"
        }
    }
    
    var icon: String? {
        switch self {
        case .all: return "line.3.horizontal.decrease.circle"
        case .publicOnly: return "globe"
        case .unlisted: return "link"
        case .privateOnly: return "lock.fill"
        case .scheduled: return "calendar"
        }
    }
}

enum VideoTypeFilter: CaseIterable {
    case all, flicks, longForm, live
    
    var title: String {
        switch self {
        case .all: return "Type"
        case .flicks: return "Flicks"
        case .longForm: return "Long"
        case .live: return "Live"
        }
    }
    
    var icon: String? {
        switch self {
        case .all: return "star.fill"
        case .flicks: return "play.rectangle.on.rectangle"
        case .longForm: return "rectangle.stack"
        case .live: return "dot.radiowaves.left.and.right"
        }
    }
}

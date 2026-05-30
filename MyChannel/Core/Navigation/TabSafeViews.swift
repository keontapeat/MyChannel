// ⚡ PERFORMANCE: Extracted from MainTabView.swift — independent compilation unit.
// Safe view wrappers, ErrorBoundary, ErrorView, ButtonStyles, and AppNotification model.
// 276 lines that now compile independently in parallel.
import SwiftUI

// MARK: - Safe Content View
struct SafeContentView: View {
    let selectedTab: TabItem
    
    var body: some View {
        Group {
            switch selectedTab {
            case .home:
                SafeHomeView()
            case .subscriptions:
                NavigationStack { SubscriptionsView() }
            case .flicks:
                // Embed Flicks inside the tab with embedded flag on
                ErrorBoundary {
                    FlicksView()
                } fallback: {
                    if #available(iOS 17.0, *) {
                        return AnyView(
                            ContentUnavailableView(
                                "Flicks Unavailable",
                                systemImage: "play.slash",
                                description: Text("Please try again later")
                            )
                        )
                    } else {
                        return AnyView(
                            VStack(spacing: 12) {
                                Image(systemName: "play.slash").font(.largeTitle)
                                Text("Flicks Unavailable").font(.headline)
                                Text("Please try again later").font(.subheadline).foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(AppTheme.Colors.background)
                        )
                    }
                }
            case .search:
                SafeSearchView()
            case .profile:
                NavigationStack {
                    ProfileView()
                        .navigationBarHidden(true)
                }
            case .upload:
                EmptyView()
            }
        }
        .transition(.identity)
    }
}

// MARK: - Safe View Wrappers
struct SafeHomeView: View {
    var body: some View {
        ErrorBoundary {
            HomeView()
        } fallback: {
            if #available(iOS 17.0, *) {
                return AnyView(
                    ContentUnavailableView(
                        "Home Unavailable",
                        systemImage: "house.slash",
                        description: Text("Please try again later")
                    )
                )
            } else {
                return AnyView(
                    VStack(spacing: 12) {
                        Image(systemName: "house.slash").font(.largeTitle)
                        Text("Home Unavailable").font(.headline)
                        Text("Please try again later").font(.subheadline).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.Colors.background)
                )
            }
        }
    }
}

struct SafeFlicksView: View {
    var body: some View {
        ErrorBoundary {
            FlicksView()
        } fallback: {
            if #available(iOS 17.0, *) {
                return AnyView(
                    ContentUnavailableView(
                        "Flicks Unavailable",
                        systemImage: "play.slash",
                        description: Text("Please try again later")
                    )
                )
            } else {
                return AnyView(
                    VStack(spacing: 12) {
                        Image(systemName: "play.slash").font(.largeTitle)
                        Text("Flicks Unavailable").font(.headline)
                        Text("Please try again later").font(.subheadline).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.Colors.background)
                )
            }
        }
    }
}

struct SafeSearchView: View {
    var body: some View {
        ErrorBoundary {
            SearchView()
        } fallback: {
            if #available(iOS 17.0, *) {
                return AnyView(
                    ContentUnavailableView(
                        "Search Unavailable",
                        systemImage: "magnifyingglass.circle.slash",
                        description: Text("Please try again later")
                    )
                )
            } else {
                return AnyView(
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass.circle.slash").font(.largeTitle)
                        Text("Search Unavailable").font(.headline)
                        Text("Please try again later").font(.subheadline).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.Colors.background)
                )
            }
        }
    }
}

struct SafeProfileView: View {
    var body: some View {
        ErrorBoundary {
            ProfileView()
        } fallback: {
            if #available(iOS 17.0, *) {
                return AnyView(
                    ContentUnavailableView(
                        "Profile Unavailable",
                        systemImage: "person.slash",
                        description: Text("Please try again later")
                    )
                )
            } else {
                return AnyView(
                    VStack(spacing: 12) {
                        Image(systemName: "person.slash").font(.largeTitle)
                        Text("Profile Unavailable").font(.headline)
                        Text("Please try again later").font(.subheadline).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.Colors.background)
                )
            }
        }
    }
}

struct SafeUploadView: View {
    var body: some View {
        ErrorBoundary {
            YouTubeStyleUploadFlow()
        } fallback: {
            if #available(iOS 17.0, *) {
                return AnyView(
                    ContentUnavailableView(
                        "Upload Unavailable",
                        systemImage: "plus.circle.slash",
                        description: Text("Please try again later")
                    )
                )
            } else {
                return AnyView(
                    VStack(spacing: 12) {
                        Image(systemName: "plus.circle.slash").font(.largeTitle)
                        Text("Upload Unavailable").font(.headline)
                        Text("Please try again later").font(.subheadline).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.Colors.background)
                )
            }
        }
    }
}

// MARK: - Error Boundary
struct ErrorBoundary<Content: View, Fallback: View>: View {
    let content: () -> Content
    let fallback: () -> Fallback
    
    @State private var hasError = false
    
    var body: some View {
        Group {
            if hasError {
                fallback()
            } else {
                content()
                    .onAppear {
                        hasError = false
                    }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ViewError"))) { _ in
            hasError = true
        }
    }
}

// MARK: - Error View
struct ErrorView: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.Colors.primary)
            
            VStack(spacing: 8) {
                Text("Something went wrong")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(message)
                    .font(.body)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button("Try Again") {
                onRetry()
            }
            .buttonStyle(TabErrorButtonStyle())
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.Colors.background)
    }
}

// MARK: - Tab Error Button Style
struct TabErrorButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.Colors.primary)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct PressableScaleButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.95
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}


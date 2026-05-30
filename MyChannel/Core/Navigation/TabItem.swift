// ⚡ TabItem.swift
// Extracted navigation enum. Shared by CustomTabBar, MainTabView, and TabSafeViews.
import Foundation

enum TabItem: String, CaseIterable, Hashable {
    case home
    case flicks
    case upload
    case subscriptions
    case search
    case profile

    var title: String {
        switch self {
        case .home: return "Home"
        case .flicks: return "Flicks"
        case .upload: return "Upload"
        case .subscriptions: return "Subscriptions"
        case .search: return "Search"
        case .profile: return "Profile"
        }
    }

    func iconName(isSelected: Bool) -> String {
        switch self {
        case .home:          return isSelected ? "house.fill" : "house"
        case .flicks:        return isSelected ? "play.rectangle.fill" : "play.rectangle"
        case .upload:        return "plus.circle.fill"
        case .subscriptions: return isSelected ? "bell.fill" : "bell"
        case .search:        return isSelected ? "magnifyingglass.circle.fill" : "magnifyingglass"
        case .profile:       return isSelected ? "person.fill" : "person"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .home:          return "Home"
        case .flicks:        return "Flicks"
        case .upload:        return "Create"
        case .subscriptions: return "Subscriptions"
        case .search:        return "Search"
        case .profile:       return "Profile"
        }
    }
}

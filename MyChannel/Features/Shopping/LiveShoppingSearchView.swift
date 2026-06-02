//
//  LiveShoppingSearchView.swift
//  MyChannel
//
//  Search + notifications surfaces for the Live Shopping experience.
//  Search queries the real Firestore catalog via LiveShoppingService.
//

import SwiftUI

// MARK: - Search

struct LiveShoppingSearchView: View {
    @ObservedObject var viewModel: LiveShoppingViewModel
    let onSelect: (ShoppingProduct) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [ShoppingProduct] = []
    @State private var isSearching = false
    @State private var hasSearched = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar

                if isSearching {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if hasSearched && results.isEmpty {
                    emptyState
                } else if results.isEmpty {
                    suggestionsState
                } else {
                    resultsList
                }
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Search merch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { searchFocused = true }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppTheme.Colors.textTertiary)
            TextField("Search products, brands, creators", text: $query)
                .focused($searchFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .onSubmit { runSearch() }
            if !query.isEmpty {
                Button {
                    query = ""
                    results = []
                    hasSearched = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }
            }
        }
        .padding(12)
        .background(AppTheme.Colors.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(results) { product in
                    Button { onSelect(product) } label: {
                        LiveShoppingSearchRow(product: product)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "bag.badge.questionmark")
                .font(.system(size: 44, weight: .light))
                .foregroundColor(AppTheme.Colors.textTertiary)
            Text("No products found")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            Text("Try a different search term.")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.Colors.textSecondary)
            Spacer()
        }
    }

    private var suggestionsState: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Popular categories")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
                .padding(.horizontal, 16)
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 14) {
                    ForEach(ShoppingCategory.allCases) { category in
                        ShoppingCategoryButton(category: category) {
                            query = category.rawValue
                            runSearch()
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.top, 8)
    }

    private func runSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSearching = true
        Task {
            let found = await viewModel.search(trimmed)
            await MainActor.run {
                results = found
                hasSearched = true
                isSearching = false
            }
        }
    }
}

private struct LiveShoppingSearchRow: View {
    let product: ShoppingProduct

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: product.imageURL)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppTheme.Colors.backgroundSecondary)
                    .overlay(
                        Image(systemName: product.category.icon)
                            .foregroundColor(AppTheme.Colors.textTertiary)
                    )
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(product.brand.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textTertiary)
                Text(product.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
                Text("$\(String(format: "%.2f", product.price))")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textTertiary)
        }
        .padding(12)
        .background(AppTheme.Colors.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.Colors.divider.opacity(0.3), lineWidth: 0.8)
        )
    }
}

// MARK: - Notifications

struct LiveShoppingNotificationsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 44, weight: .light))
                    .foregroundColor(AppTheme.Colors.primary)
                Text("You're all caught up")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                Text("Drop alerts, restocks, and price drops from creators you follow will show up here.")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

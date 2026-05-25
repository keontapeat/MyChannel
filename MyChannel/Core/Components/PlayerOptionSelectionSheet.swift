import SwiftUI

struct PlayerOptionSelectionItem: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String?
}

struct PlayerOptionSelectionSheet: View {
    let title: String
    let subtitle: String
    let items: [PlayerOptionSelectionItem]
    let selectedID: String
    var searchable: Bool = false
    var searchPlaceholder: String = "Search"
    let onSelect: (PlayerOptionSelectionItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var searchFocused = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)

                if searchable {
                    UIKitSearchBar(
                        text: $searchText,
                        placeholder: searchPlaceholder,
                        isFirstResponder: searchFocused,
                        onFocusChanged: { focused in
                            searchFocused = focused
                        }
                    )
                    .frame(height: 44)
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                }

                List {
                    ForEach(filteredItems) { item in
                        Button {
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            onSelect(item)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                dismiss()
                            }
                        } label: {
                            HStack(spacing: 16) {
                                Circle()
                                    .fill(item.id == selectedID ? Color.accentColor : Color(.systemGray5))
                                    .frame(width: 12, height: 12)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.accentColor, lineWidth: item.id == selectedID ? 0 : 1.5)
                                    )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(.body)
                                        .fontWeight(item.id == selectedID ? .semibold : .medium)
                                        .foregroundColor(.primary)

                                    if let subtitle = item.subtitle {
                                        Text(subtitle)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Spacer()

                                if item.id == selectedID {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.accentColor)
                                        .font(.title3)
                                }
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(item.id == selectedID ? Color.accentColor.opacity(0.1) : Color.clear)
                        )
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.accentColor)
                    .fontWeight(.medium)
                }
            }
        }
        .background(
            UIKitSheetConfigurator(
                configuration: UIKitSheetConfiguration(
                    detents: [.medium()],
                    largestUndimmedDetentIdentifier: .medium,
                    prefersGrabberVisible: true,
                    prefersScrollingExpandsWhenScrolledToEdge: false,
                    preferredCornerRadius: 28
                )
            )
        )
    }

    private var filteredItems: [PlayerOptionSelectionItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard searchable, !query.isEmpty else { return items }
        return items.filter {
            $0.title.lowercased().contains(query) || ($0.subtitle?.lowercased().contains(query) ?? false)
        }
    }
}

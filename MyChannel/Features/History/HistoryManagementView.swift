import SwiftUI

struct HistoryManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @StateObject private var historyService = HistoryService.shared
    @State private var selectedFilter: WatchHistoryItem.ContentType?
    @State private var isWorking = false
    @State private var showingClearAllConfirmation = false
    @State private var showingClearFilteredConfirmation = false
    
    private var filterTitle: String {
        selectedFilter?.displayName ?? "All activity"
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(historyService.isWatchHistoryPaused ? "Watch history is paused" : "Watch history is on")
                                .font(.headline)
                            Text(historyService.isWatchHistoryPaused ? "Videos and posts you view won't be saved." : "MyChannel saves watched content to improve recommendations.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { historyService.isWatchHistoryPaused },
                            set: { paused in setPaused(paused) }
                        ))
                        .labelsHidden()
                    }
                }
                
                Section("Filter activity") {
                    filterRow(title: "All activity", icon: "clock.arrow.circlepath", type: nil)
                    ForEach(WatchHistoryItem.ContentType.allCases, id: \.rawValue) { type in
                        filterRow(title: type.displayName, icon: type.iconName, type: type)
                    }
                }
                
                Section("Bulk actions") {
                    Button(role: .destructive) {
                        showingClearFilteredConfirmation = true
                    } label: {
                        Label("Delete \(filterTitle)", systemImage: "line.3.horizontal.decrease.circle")
                    }
                    .disabled(isWorking)
                    
                    Button(role: .destructive) {
                        showingClearAllConfirmation = true
                    } label: {
                        Label("Delete all watch history", systemImage: "trash")
                    }
                    .disabled(isWorking)
                }
                
                Section("Privacy") {
                    Label("Not interested choices are saved to your account and can be used to tune recommendations.", systemImage: "hand.thumbsdown")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Manage All History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .overlay {
                if isWorking {
                    ProgressView()
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .confirmationDialog("Delete all watch history?", isPresented: $showingClearAllConfirmation, titleVisibility: .visible) {
                Button("Delete all watch history", role: .destructive) { clearAll() }
                Button("Cancel", role: .cancel) { }
            }
            .confirmationDialog("Delete \(filterTitle)?", isPresented: $showingClearFilteredConfirmation, titleVisibility: .visible) {
                Button("Delete \(filterTitle)", role: .destructive) { clearFiltered() }
                Button("Cancel", role: .cancel) { }
            }
        }
    }
    
    private func filterRow(title: String, icon: String, type: WatchHistoryItem.ContentType?) -> some View {
        Button {
            selectedFilter = type
        } label: {
            HStack {
                Label(title, systemImage: icon)
                Spacer()
                if selectedFilter == type {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
        }
        .foregroundColor(.primary)
    }
    
    private func setPaused(_ paused: Bool) {
        guard let userId = appState.currentUser?.id else { return }
        Task { await historyService.setPaused(paused, userId: userId) }
    }
    
    private func clearAll() {
        guard let userId = appState.currentUser?.id else { return }
        isWorking = true
        Task {
            await historyService.clearAll(userId: userId)
            await MainActor.run { isWorking = false }
        }
    }
    
    private func clearFiltered() {
        guard let userId = appState.currentUser?.id else { return }
        isWorking = true
        Task {
            if let selectedFilter {
                await historyService.clearItems(userId: userId) { $0.contentType == selectedFilter }
            } else {
                await historyService.clearAll(userId: userId)
            }
            await MainActor.run { isWorking = false }
        }
    }
}

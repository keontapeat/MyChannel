import SwiftUI

struct NotificationsInboxView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @StateObject private var inbox = NotificationsInboxService.shared

    var body: some View {
        NavigationStack {
            List {
                ForEach(inbox.items) { item in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: icon(for: item.type))
                            .foregroundColor(.blue)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title).font(.subheadline.weight(.semibold))
                            Text(item.body).font(.caption).foregroundColor(.secondary)
                            Text(item.createdAt, style: .relative)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if !item.read {
                            Circle().fill(Color.blue).frame(width: 8, height: 8)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let uid = appState.currentUser?.id { Task { await inbox.markRead(userId: uid, id: item.id, read: true) } }
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .bold))
                            .foregroundColor(.primary)
                            .frame(width: 30, height: 30)
                            .background(AppTheme.Colors.surface, in: Circle())
                    }
                }
            }
        }
        .onAppear { if let uid = appState.currentUser?.id { inbox.listen(userId: uid) } }
        .onDisappear { inbox.stop() }
    }

    private func icon(for type: String) -> String {
        switch type {
        case "like": return "heart.fill"
        case "comment": return "bubble.right.fill"
        case "upload": return "arrow.up.circle.fill"
        default: return "bell.fill"
        }
    }
}





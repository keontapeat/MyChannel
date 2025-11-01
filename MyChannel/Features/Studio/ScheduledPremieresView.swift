import SwiftUI

struct ScheduledPremieresView: View {
    let creatorId: String
    @StateObject private var premieresService = ScheduledPremieresService.shared
    @State private var showingScheduleView = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(premieresService.premieres) { premiere in
                    PremiereRow(premiere: premiere) { premiereId in
                        // Handle premiere tap (e.g., open chat/waiting room)
                        print("Tapped premiere: \(premiereId)")
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Scheduled Premieres")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingScheduleView = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingScheduleView) {
                SchedulePremiereView(creatorId: creatorId)
            }
        }
        .onAppear {
            premieresService.listenToPremieres(creatorId: creatorId)
        }
        .onDisappear {
            premieresService.stopListening()
        }
    }
}

struct PremiereRow: View {
    let premiere: ScheduledPremiere
    let onTap: (String) -> Void
    
    private var statusColor: Color {
        switch premiere.status {
        case .scheduled: return .blue
        case .live: return .red
        case .completed: return .green
        }
    }
    
    var body: some View {
        Button {
            onTap(premiere.id)
        } label: {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: premiere.thumbnailURL)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(Color(.systemGray6))
                }
                .frame(width: 120, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(alignment: .topLeading) {
                    Text(premiere.status.displayName)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(statusColor)
                        .cornerRadius(4)
                        .padding(6)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(premiere.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                    
                    if premiere.status == .scheduled {
                        Text("Premieres \(premiere.scheduledAt, style: .relative)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if premiere.status == .live, let viewers = premiere.viewerCount {
                        HStack {
                            Circle().fill(.red).frame(width: 6, height: 6)
                            Text("\(viewers) watching")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if premiere.chatEnabled {
                        Label("Chat enabled", systemImage: "bubble.left.and.bubble.right")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}

struct SchedulePremiereView: View {
    let creatorId: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var premieresService = ScheduledPremieresService.shared
    
    @State private var title = ""
    @State private var scheduledDate = Date().addingTimeInterval(3600) // 1 hour from now
    @State private var chatEnabled = true
    @State private var isScheduling = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Premiere Details") {
                    TextField("Title", text: $title)
                    
                    DatePicker("Scheduled Time", selection: $scheduledDate, in: Date()...)
                    
                    Toggle("Enable Chat", isOn: $chatEnabled)
                }
                
                Section {
                    Button("Schedule Premiere") {
                        Task { await schedulePremiereAction() }
                    }
                    .disabled(title.isEmpty || isScheduling)
                }
            }
            .navigationTitle("Schedule Premiere")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func schedulePremiereAction() async {
        isScheduling = true
        let _ = await premieresService.schedulePremiereForVideo(
            videoId: "temp_video_id", // Would be actual video ID
            title: title,
            thumbnailURL: "https://picsum.photos/400/225?random=\(Int.random(in: 1...1000))",
            scheduledAt: scheduledDate,
            creatorId: creatorId,
            chatEnabled: chatEnabled
        )
        isScheduling = false
        dismiss()
    }
}



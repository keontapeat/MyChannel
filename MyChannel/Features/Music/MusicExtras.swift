//
//  MusicExtras.swift
//  MyChannel
//
//  Extra Music Features - Widgets, Watch, Alarm, Behind the Music
//

import SwiftUI
import WidgetKit

// MARK: - =====================================================
// MARK: - HOME SCREEN WIDGETS CONFIGURATION
// MARK: - =====================================================

struct MusicWidgetData: Codable {
    let trackTitle: String
    let artistName: String
    let artworkURL: String?
    let lastPlayed: Date
}

struct WidgetSettingsView: View {
    @AppStorage("widget_show_artwork") private var showArtwork: Bool = true
    @AppStorage("widget_show_controls") private var showControls: Bool = true
    @AppStorage("widget_theme") private var widgetTheme: WidgetTheme = .auto
    
    enum WidgetTheme: String, CaseIterable, Codable {
        case auto = "Auto"
        case light = "Light"
        case dark = "Dark"
        case vibrant = "Vibrant"
    }
    
    var body: some View {
        Form {
            Section {
                Toggle("Show Album Artwork", isOn: $showArtwork)
                Toggle("Show Playback Controls", isOn: $showControls)
                
                Picker("Theme", selection: $widgetTheme) {
                    ForEach(WidgetTheme.allCases, id: \.self) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }
            } header: {
                Text("Widget Appearance")
            }
            
            Section {
                WidgetPreviewCard(showArtwork: showArtwork, showControls: showControls, theme: widgetTheme)
            } header: {
                Text("Preview")
            }
            
            Section {
                Button {
                    // This would reload widgets in production
                    HapticManager.shared.notification(type: .success)
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh Widgets")
                    }
                }
            } footer: {
                Text("Add the MyChannel Music widget from your home screen.")
            }
        }
        .navigationTitle("Widgets")
    }
}

struct WidgetPreviewCard: View {
    let showArtwork: Bool
    let showControls: Bool
    let theme: WidgetSettingsView.WidgetTheme
    
    var backgroundColor: Color {
        switch theme {
        case .auto, .dark: return Color.black
        case .light: return Color.white
        case .vibrant: return Color.purple
        }
    }
    
    var foregroundColor: Color {
        switch theme {
        case .light: return .black
        default: return .white
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            if showArtwork {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(foregroundColor.opacity(0.5))
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Now Playing")
                    .font(.system(size: 11))
                    .foregroundColor(foregroundColor.opacity(0.6))
                Text("Coochie")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(foregroundColor)
                Text("YN Jay")
                    .font(.system(size: 13))
                    .foregroundColor(foregroundColor.opacity(0.7))
            }
            
            Spacer()
            
            if showControls {
                HStack(spacing: 12) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 14))
                    Image(systemName: "pause.fill")
                        .font(.system(size: 18))
                    Image(systemName: "forward.fill")
                        .font(.system(size: 14))
                }
                .foregroundColor(foregroundColor)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(backgroundColor)
        )
    }
}

// MARK: - =====================================================
// MARK: - ALARM (Wake Up to Music)
// MARK: - =====================================================

struct MusicAlarm: Identifiable, Codable {
    let id: String
    var time: Date
    var isEnabled: Bool
    var label: String
    var trackId: String?
    var trackTitle: String?
    var artistName: String?
    var repeatDays: [Int] // 0 = Sunday, 6 = Saturday
    var fadeInDuration: Int // seconds
    var snoozeEnabled: Bool
    var vibrationEnabled: Bool
}

@MainActor
final class AlarmService: ObservableObject {
    static let shared = AlarmService()
    
    @Published var alarms: [MusicAlarm] = []
    
    private init() {
        loadAlarms()
    }
    
    func addAlarm(_ alarm: MusicAlarm) {
        alarms.append(alarm)
        saveAlarms()
    }
    
    func updateAlarm(_ alarm: MusicAlarm) {
        if let index = alarms.firstIndex(where: { $0.id == alarm.id }) {
            alarms[index] = alarm
            saveAlarms()
        }
    }
    
    func deleteAlarm(_ id: String) {
        alarms.removeAll { $0.id == id }
        saveAlarms()
    }
    
    func toggleAlarm(_ id: String) {
        if let index = alarms.firstIndex(where: { $0.id == id }) {
            alarms[index].isEnabled.toggle()
            saveAlarms()
        }
    }
    
    private func saveAlarms() {
        if let encoded = try? JSONEncoder().encode(alarms) {
            UserDefaults.standard.set(encoded, forKey: "music_alarms")
        }
    }
    
    private func loadAlarms() {
        if let data = UserDefaults.standard.data(forKey: "music_alarms"),
           let decoded = try? JSONDecoder().decode([MusicAlarm].self, from: data) {
            alarms = decoded
        }
    }
}

struct MusicAlarmsView: View {
    @StateObject private var alarmService = AlarmService.shared
    @State private var showAddAlarm: Bool = false
    
    var body: some View {
        List {
            if alarmService.alarms.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "alarm")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text("No alarms yet")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Wake up to your favorite music")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
                .listRowBackground(Color.clear)
            } else {
                ForEach(alarmService.alarms) { alarm in
                    AlarmRow(alarm: alarm)
                }
                .onDelete { indexSet in
                    indexSet.forEach { index in
                        alarmService.deleteAlarm(alarmService.alarms[index].id)
                    }
                }
            }
        }
        .navigationTitle("Music Alarm")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showAddAlarm = true
                    HapticManager.shared.impact(style: .light)
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddAlarm) {
            AddAlarmSheet()
        }
    }
}

struct AlarmRow: View {
    let alarm: MusicAlarm
    @StateObject private var alarmService = AlarmService.shared
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(formatTime(alarm.time))
                    .font(.system(size: 40, weight: .light))
                
                HStack(spacing: 8) {
                    Text(alarm.label)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    if let track = alarm.trackTitle {
                        Text("• \(track)")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.Colors.primary)
                    }
                }
                
                if !alarm.repeatDays.isEmpty {
                    Text(formatRepeatDays(alarm.repeatDays))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { alarm.isEnabled },
                set: { _ in alarmService.toggleAlarm(alarm.id) }
            ))
        }
        .padding(.vertical, 8)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm"
        return formatter.string(from: date)
    }
    
    private func formatRepeatDays(_ days: [Int]) -> String {
        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        if days.count == 7 { return "Every day" }
        if days == [1, 2, 3, 4, 5] { return "Weekdays" }
        if days == [0, 6] { return "Weekends" }
        return days.sorted().map { dayNames[$0] }.joined(separator: ", ")
    }
}

struct AddAlarmSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var alarmService = AlarmService.shared
    @State private var time: Date = Date()
    @State private var label: String = "Wake Up"
    @State private var selectedTrack: PlaylistTrack? = nil
    @State private var repeatDays: Set<Int> = []
    @State private var fadeIn: Int = 30
    @State private var snooze: Bool = true
    @State private var vibration: Bool = true
    @State private var showTrackPicker: Bool = false
    
    let fadeOptions = [0, 15, 30, 45, 60]
    
    var body: some View {
        NavigationStack {
            Form {
                // Time picker
                DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                
                // Label
                Section {
                    TextField("Label", text: $label)
                }
                
                // Music selection
                Section {
                    Button {
                        showTrackPicker = true
                    } label: {
                        HStack {
                            Text("Sound")
                            Spacer()
                            if let track = selectedTrack {
                                Text(track.title)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Choose a song")
                                    .foregroundColor(.secondary)
                            }
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                    
                    Picker("Fade In", selection: $fadeIn) {
                        ForEach(fadeOptions, id: \.self) { seconds in
                            Text(seconds == 0 ? "Off" : "\(seconds)s").tag(seconds)
                        }
                    }
                }
                
                // Repeat days
                Section {
                    ForEach(0..<7) { day in
                        let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
                        Button {
                            if repeatDays.contains(day) {
                                repeatDays.remove(day)
                            } else {
                                repeatDays.insert(day)
                            }
                            HapticManager.shared.impact(style: .light)
                        } label: {
                            HStack {
                                Text(dayNames[day])
                                    .foregroundColor(.primary)
                                Spacer()
                                if repeatDays.contains(day) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(AppTheme.Colors.primary)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Repeat")
                }
                
                // Options
                Section {
                    Toggle("Snooze", isOn: $snooze)
                    Toggle("Vibration", isOn: $vibration)
                }
            }
            .navigationTitle("Add Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveAlarm()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func saveAlarm() {
        let alarm = MusicAlarm(
            id: UUID().uuidString,
            time: time,
            isEnabled: true,
            label: label,
            trackId: selectedTrack?.id,
            trackTitle: selectedTrack?.title,
            artistName: selectedTrack?.artist,
            repeatDays: Array(repeatDays),
            fadeInDuration: fadeIn,
            snoozeEnabled: snooze,
            vibrationEnabled: vibration
        )
        alarmService.addAlarm(alarm)
        HapticManager.shared.notification(type: .success)
    }
}

// MARK: - =====================================================
// MARK: - BEHIND THE MUSIC (Artist Stories)
// MARK: - =====================================================

struct BehindTheMusicStory: Identifiable {
    let id: String
    let artistName: String
    let artistImageURL: String?
    let title: String
    let subtitle: String
    let videoURL: String?
    let duration: TimeInterval
    let publishedAt: Date
    let viewCount: Int
}

struct BehindTheMusicView: View {
    @State private var stories: [BehindTheMusicStory] = [
        BehindTheMusicStory(
            id: "1",
            artistName: "YN Jay",
            artistImageURL: "https://i.ytimg.com/vi/pnQ0BXTfBjk/hqdefault.jpg",
            title: "The Making of Coochie",
            subtitle: "How a viral hit was born in the 810",
            videoURL: nil,
            duration: 180,
            publishedAt: Date().addingTimeInterval(-86400),
            viewCount: 125000
        ),
        BehindTheMusicStory(
            id: "2",
            artistName: "Rio Da Yung OG",
            artistImageURL: "https://i.ytimg.com/vi/6DZSh9vqlWc/hqdefault.jpg",
            title: "From the Block to the Stage",
            subtitle: "Rio's journey through the 810",
            videoURL: nil,
            duration: 240,
            publishedAt: Date().addingTimeInterval(-172800),
            viewCount: 89000
        ),
        BehindTheMusicStory(
            id: "3",
            artistName: "RMC Mike",
            artistImageURL: "https://i.ytimg.com/vi/x_E1bq1sYdY/hqdefault.jpg",
            title: "The 810 Sound",
            subtitle: "How Michigan changed hip-hop",
            videoURL: nil,
            duration: 300,
            publishedAt: Date().addingTimeInterval(-259200),
            viewCount: 67000
        )
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Featured story
                if let featured = stories.first {
                    FeaturedStoryCard(story: featured)
                }
                
                // More stories
                VStack(alignment: .leading, spacing: 16) {
                    Text("More Stories")
                        .font(.system(size: 22, weight: .bold))
                        .padding(.horizontal, 20)
                    
                    ForEach(stories.dropFirst()) { story in
                        StoryRow(story: story)
                    }
                }
            }
            .padding(.top, 20)
        }
        .navigationTitle("Behind the Music")
    }
}

struct FeaturedStoryCard: View {
    let story: BehindTheMusicStory
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background
            if let url = story.artistImageURL {
                AsyncImage(url: URL(string: url)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.gray
                }
            }
            
            // Gradient overlay
            LinearGradient(
                colors: [.clear, .black.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("FEATURED")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.white.opacity(0.2)))
                    Spacer()
                }
                
                Text(story.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text(story.subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
                
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                        Text("\(formatDuration(story.duration))")
                    }
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
                    
                    Text("•")
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text(formatViews(story.viewCount))
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(20)
        }
        .frame(height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 20)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        return "\(minutes) min"
    }
    
    private func formatViews(_ count: Int) -> String {
        if count >= 1000 {
            return "\(count / 1000)K views"
        }
        return "\(count) views"
    }
}

struct StoryRow: View {
    let story: BehindTheMusicStory
    
    var body: some View {
        HStack(spacing: 14) {
            // Thumbnail
            ZStack {
                if let url = story.artistImageURL {
                    AsyncImage(url: URL(string: url)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.gray
                    }
                }
                
                // Play button
                Circle()
                    .fill(.black.opacity(0.5))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "play.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                    )
            }
            .frame(width: 100, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(story.title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(2)
                
                Text(story.artistName)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - =====================================================
// MARK: - MUSIC PROFILE / STATS CARD
// MARK: - =====================================================

struct MusicProfileView: View {
    @State private var selectedTimeRange: TimeRange = .month
    
    enum TimeRange: String, CaseIterable {
        case week = "This Week"
        case month = "This Month"
        case year = "This Year"
        case allTime = "All Time"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Profile header
                profileHeader
                
                // Time range picker
                Picker("Time Range", selection: $selectedTimeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                
                // Stats cards
                statsGrid
                
                // Top artists
                topArtistsSection
                
                // Top tracks
                topTracksSection
                
                // Genres
                genresSection
            }
            .padding(.top, 20)
        }
        .navigationTitle("Your Music")
    }
    
    private var profileHeader: some View {
        VStack(spacing: 16) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 100, height: 100)
                .overlay(
                    Text("K")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                )
            
            Text("Your Profile")
                .font(.system(size: 22, weight: .bold))
            
            Text("Listening since 2024")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
    }
    
    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            MusicStatCard(title: "Minutes", value: "4,832", icon: "clock.fill", color: .blue)
            MusicStatCard(title: "Tracks", value: "342", icon: "music.note", color: .purple)
            MusicStatCard(title: "Artists", value: "87", icon: "person.2.fill", color: .green)
            MusicStatCard(title: "Genres", value: "12", icon: "guitars.fill", color: .orange)
        }
        .padding(.horizontal, 20)
    }
    
    private var topArtistsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Artists")
                .font(.system(size: 20, weight: .bold))
                .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(0..<5) { i in
                        TopArtistCard(rank: i + 1)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    private var topTracksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Tracks")
                .font(.system(size: 20, weight: .bold))
                .padding(.horizontal, 20)
            
            VStack(spacing: 0) {
                ForEach(0..<5) { i in
                    TopTrackRow(rank: i + 1)
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    private var genresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Genres")
                .font(.system(size: 20, weight: .bold))
                .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    GenreChip(name: "Hip-Hop", percentage: 45, color: .red)
                    GenreChip(name: "R&B", percentage: 25, color: .purple)
                    GenreChip(name: "Pop", percentage: 15, color: .blue)
                    GenreChip(name: "Electronic", percentage: 10, color: .green)
                    GenreChip(name: "Soul", percentage: 5, color: .orange)
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 30)
    }
}

struct MusicStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 28, weight: .bold))
            
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct TopArtistCard: View {
    let rank: Int
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topLeading) {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "music.mic")
                            .font(.system(size: 28))
                            .foregroundColor(.gray)
                    )
                
                Text("#\(rank)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(AppTheme.Colors.primary))
            }
            
            Text("Artist \(rank)")
                .font(.system(size: 13, weight: .semibold))
            
            Text("42 plays")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }
}

struct TopTrackRow: View {
    let rank: Int
    
    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(rank <= 3 ? AppTheme.Colors.primary : .secondary)
                .frame(width: 24)
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.systemGray5))
                .frame(width: 44, height: 44)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Track \(rank)")
                    .font(.system(size: 15, weight: .medium))
                Text("Artist Name")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("32 plays")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

struct GenreChip: View {
    let name: String
    let percentage: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.3), lineWidth: 4)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: CGFloat(percentage) / 100)
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                
                Text("\(percentage)%")
                    .font(.system(size: 14, weight: .bold))
            }
            
            Text(name)
                .font(.system(size: 12, weight: .medium))
        }
    }
}

// MARK: - =====================================================
// MARK: - MUSIC SEARCH HISTORY
// MARK: - =====================================================

struct SearchHistoryView: View {
    @AppStorage("search_history") private var searchHistoryData: Data = Data()
    @State private var searchHistory: [String] = []
    
    var body: some View {
        List {
            if searchHistory.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No recent searches")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .listRowBackground(Color.clear)
            } else {
                ForEach(searchHistory, id: \.self) { query in
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(.secondary)
                        Text(query)
                        Spacer()
                        Image(systemName: "arrow.up.left")
                            .foregroundColor(.secondary)
                    }
                }
                .onDelete(perform: deleteItems)
            }
        }
        .navigationTitle("Search History")
        .toolbar {
            if !searchHistory.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear All") {
                        searchHistory.removeAll()
                        saveHistory()
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .onAppear {
            loadHistory()
        }
    }
    
    private func loadHistory() {
        if let decoded = try? JSONDecoder().decode([String].self, from: searchHistoryData) {
            searchHistory = decoded
        }
    }
    
    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(searchHistory) {
            searchHistoryData = encoded
        }
    }
    
    private func deleteItems(at offsets: IndexSet) {
        searchHistory.remove(atOffsets: offsets)
        saveHistory()
    }
}

// MARK: - =====================================================
// MARK: - MUSIC SETTINGS HUB
// MARK: - =====================================================

struct MusicSettingsView: View {
    var body: some View {
        List {
            Section {
                NavigationLink {
                    AudioSettingsView()
                } label: {
                    SettingsRow(icon: "speaker.wave.3.fill", title: "Audio Quality", color: .blue)
                }
                
                NavigationLink {
                    // Equalizer
                } label: {
                    SettingsRow(icon: "slider.horizontal.3", title: "Equalizer", color: .purple)
                }
                
                NavigationLink {
                    MusicDownloadsView()
                } label: {
                    SettingsRow(icon: "arrow.down.circle.fill", title: "Downloads", color: .green)
                }
            } header: {
                Text("Playback")
            }
            
            Section {
                NavigationLink {
                    WidgetSettingsView()
                } label: {
                    SettingsRow(icon: "square.grid.2x2.fill", title: "Widgets", color: .orange)
                }
                
                NavigationLink {
                    MusicAlarmsView()
                } label: {
                    SettingsRow(icon: "alarm.fill", title: "Alarm", color: .red)
                }
            } header: {
                Text("Features")
            }
            
            Section {
                NavigationLink {
                    FollowingView()
                } label: {
                    SettingsRow(icon: "person.2.fill", title: "Following", color: .pink)
                }
                
                NavigationLink {
                    FriendActivityView()
                } label: {
                    SettingsRow(icon: "bubble.left.and.bubble.right.fill", title: "Friend Activity", color: .teal)
                }
            } header: {
                Text("Social")
            }
            
            Section {
                NavigationLink {
                    SearchHistoryView()
                } label: {
                    SettingsRow(icon: "clock.arrow.circlepath", title: "Search History", color: .gray)
                }
                
                NavigationLink {
                    // Privacy settings
                } label: {
                    SettingsRow(icon: "hand.raised.fill", title: "Privacy", color: .indigo)
                }
            } header: {
                Text("Data")
            }
        }
        .navigationTitle("Music Settings")
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color)
                )
            
            Text(title)
        }
    }
}


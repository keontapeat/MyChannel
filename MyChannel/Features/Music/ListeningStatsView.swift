//
//  ListeningStatsView.swift
//  MyChannel
//
//  Listening Stats / Wrapped - Spotify Wrapped Style
//

import SwiftUI

// MARK: - Listening Stats Model

struct ListeningStats: Codable {
    var totalMinutes: Int
    var totalTracks: Int
    var topArtists: [TopArtist]
    var topTracks: [TopTrack]
    var topGenres: [TopGenre]
    var listeningByHour: [Int: Int] // Hour -> minutes
    var streakDays: Int
    var flintMinutes: Int // Time spent listening to Flint artists
    
    struct TopArtist: Codable, Identifiable {
        let id: String
        let name: String
        let imageURL: String?
        let minutesListened: Int
        let tracksPlayed: Int
    }
    
    struct TopTrack: Codable, Identifiable {
        let id: String
        let title: String
        let artist: String
        let artworkURL: String?
        let playCount: Int
    }
    
    struct TopGenre: Codable, Identifiable {
        var id: String { name }
        let name: String
        let percentage: Double
        let color: String
    }
    
    static let sample = ListeningStats(
        totalMinutes: 12450,
        totalTracks: 3240,
        topArtists: [
            TopArtist(id: "1", name: "YN Jay", imageURL: "https://i.ytimg.com/vi/pnQ0BXTfBjk/hqdefault.jpg", minutesListened: 2400, tracksPlayed: 580),
            TopArtist(id: "2", name: "Rio Da Yung OG", imageURL: "https://i.ytimg.com/vi/6DZSh9vqlWc/hqdefault.jpg", minutesListened: 1800, tracksPlayed: 420),
            TopArtist(id: "3", name: "RMC Mike", imageURL: "https://i.ytimg.com/vi/x_E1bq1sYdY/hqdefault.jpg", minutesListened: 1500, tracksPlayed: 350),
            TopArtist(id: "4", name: "Louie Ray", imageURL: "https://i.ytimg.com/vi/oVP_aK7JzDw/hqdefault.jpg", minutesListened: 1200, tracksPlayed: 280),
            TopArtist(id: "5", name: "MC Breed", imageURL: "https://i.ytimg.com/vi/3LfgZdZbv0I/hqdefault.jpg", minutesListened: 900, tracksPlayed: 210)
        ],
        topTracks: [
            TopTrack(id: "t1", title: "Coochie", artist: "YN Jay", artworkURL: "https://i.ytimg.com/vi/pnQ0BXTfBjk/hqdefault.jpg", playCount: 156),
            TopTrack(id: "t2", title: "Ain't No Future", artist: "MC Breed", artworkURL: "https://i.ytimg.com/vi/3LfgZdZbv0I/hqdefault.jpg", playCount: 124),
            TopTrack(id: "t3", title: "Flint Flow", artist: "Rio Da Yung OG", artworkURL: "https://i.ytimg.com/vi/6DZSh9vqlWc/hqdefault.jpg", playCount: 98),
            TopTrack(id: "t4", title: "Enbarassing", artist: "RMC Mike", artworkURL: "https://i.ytimg.com/vi/x_E1bq1sYdY/hqdefault.jpg", playCount: 87),
            TopTrack(id: "t5", title: "Wavy", artist: "Louie Ray", artworkURL: "https://i.ytimg.com/vi/oVP_aK7JzDw/hqdefault.jpg", playCount: 76)
        ],
        topGenres: [
            TopGenre(name: "Hip-Hop", percentage: 0.65, color: "orange"),
            TopGenre(name: "Michigan Rap", percentage: 0.20, color: "red"),
            TopGenre(name: "R&B", percentage: 0.10, color: "purple"),
            TopGenre(name: "Other", percentage: 0.05, color: "gray")
        ],
        listeningByHour: [9: 45, 10: 60, 11: 75, 12: 90, 13: 60, 14: 45, 15: 30, 16: 45, 17: 60, 18: 90, 19: 120, 20: 150, 21: 180, 22: 120, 23: 60],
        streakDays: 47,
        flintMinutes: 8500
    )
}

// MARK: - Listening Stats View

struct ListeningStatsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var stats: ListeningStats = .sample
    @State private var currentCard: Int = 0
    @State private var animateStats: Bool = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: backgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.5), value: currentCard)
            
            VStack {
                // Top bar
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Button {
                        // Share
                        HapticManager.shared.impact(style: .light)
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                // Card content
                TabView(selection: $currentCard) {
                    // Card 1: Total Time
                    TotalTimeCard(stats: stats, animate: $animateStats)
                        .tag(0)
                    
                    // Card 2: Top Artist
                    if let topArtist = stats.topArtists.first {
                        StatsTopArtistCard(artist: topArtist, animate: $animateStats)
                            .tag(1)
                    }
                    
                    // Card 3: Top 5 Artists
                    TopArtistsListCard(artists: stats.topArtists, animate: $animateStats)
                        .tag(2)
                    
                    // Card 4: Top Track
                    if let topTrack = stats.topTracks.first {
                        TopTrackCard(track: topTrack, animate: $animateStats)
                            .tag(3)
                    }
                    
                    // Card 5: Genre Breakdown
                    GenreBreakdownCard(genres: stats.topGenres, animate: $animateStats)
                        .tag(4)
                    
                    // Card 6: Flint Pride
                    FlintPrideCard(flintMinutes: stats.flintMinutes, totalMinutes: stats.totalMinutes, animate: $animateStats)
                        .tag(5)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                
                // Progress dots
                HStack(spacing: 8) {
                    ForEach(0..<6, id: \.self) { index in
                        Circle()
                            .fill(currentCard == index ? Color.white : Color.white.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                animateStats = true
            }
        }
        .onChange(of: currentCard) { _ in
            animateStats = false
            withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                animateStats = true
            }
            HapticManager.shared.impact(style: .light)
        }
    }
    
    private var backgroundColors: [Color] {
        switch currentCard {
        case 0: return [Color(red: 0.1, green: 0.1, blue: 0.3), Color(red: 0.2, green: 0.1, blue: 0.4)]
        case 1: return [Color(red: 0.9, green: 0.3, blue: 0.2), Color(red: 0.7, green: 0.1, blue: 0.3)]
        case 2: return [Color(red: 0.2, green: 0.5, blue: 0.3), Color(red: 0.1, green: 0.3, blue: 0.2)]
        case 3: return [Color(red: 0.8, green: 0.5, blue: 0.1), Color(red: 0.6, green: 0.2, blue: 0.1)]
        case 4: return [Color(red: 0.5, green: 0.2, blue: 0.6), Color(red: 0.3, green: 0.1, blue: 0.4)]
        case 5: return [Color(red: 0.9, green: 0.4, blue: 0.1), Color(red: 0.8, green: 0.2, blue: 0.1)]
        default: return [Color.black, Color.gray]
        }
    }
}

// MARK: - Total Time Card

struct TotalTimeCard: View {
    let stats: ListeningStats
    @Binding var animate: Bool
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Text("You listened to")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .opacity(animate ? 1 : 0)
                .offset(y: animate ? 0 : 20)
            
            VStack(spacing: 8) {
                Text("\(stats.totalMinutes.formatted())")
                    .font(.system(size: 72, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                
                Text("minutes of music")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
            }
            .scaleEffect(animate ? 1 : 0.8)
            .opacity(animate ? 1 : 0)
            
            Text("That's \(stats.totalMinutes / 60) hours!")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .opacity(animate ? 1 : 0)
                .offset(y: animate ? 0 : 20)
            
            Spacer()
            
            // Streak badge
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                Text("\(stats.streakDays) day streak")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Capsule().fill(.white.opacity(0.15)))
            .opacity(animate ? 1 : 0)
            
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Top Artist Card

struct StatsTopArtistCard: View {
    let artist: ListeningStats.TopArtist
    @Binding var animate: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Text("Your #1 artist was")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .opacity(animate ? 1 : 0)
            
            // Artist image
            if let url = artist.imageURL {
                AsyncImage(url: URL(string: url)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                }
                .frame(width: 180, height: 180)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                .scaleEffect(animate ? 1 : 0.5)
                .opacity(animate ? 1 : 0)
            }
            
            Text(artist.name)
                .font(.system(size: 36, weight: .black))
                .foregroundColor(.white)
                .scaleEffect(animate ? 1 : 0.8)
                .opacity(animate ? 1 : 0)
            
            VStack(spacing: 8) {
                Text("\(artist.minutesListened) minutes listened")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                
                Text("\(artist.tracksPlayed) tracks played")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
            }
            .opacity(animate ? 1 : 0)
            
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Top Artists List Card

struct TopArtistsListCard: View {
    let artists: [ListeningStats.TopArtist]
    @Binding var animate: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Your Top Artists")
                .font(.system(size: 28, weight: .black))
                .foregroundColor(.white)
                .padding(.top, 40)
                .opacity(animate ? 1 : 0)
            
            VStack(spacing: 16) {
                ForEach(Array(artists.enumerated()), id: \.element.id) { index, artist in
                    HStack(spacing: 16) {
                        Text("\(index + 1)")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                            .frame(width: 30)
                        
                        if let url = artist.imageURL {
                            AsyncImage(url: URL(string: url)) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Circle().fill(Color.white.opacity(0.2))
                            }
                            .frame(width: 56, height: 56)
                            .clipShape(Circle())
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(artist.name)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("\(artist.minutesListened) min")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        Spacer()
                    }
                    .opacity(animate ? 1 : 0)
                    .offset(x: animate ? 0 : -50)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.1), value: animate)
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
    }
}

// MARK: - Top Track Card

struct TopTrackCard: View {
    let track: ListeningStats.TopTrack
    @Binding var animate: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Text("Your #1 song was")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .opacity(animate ? 1 : 0)
            
            // Track artwork
            if let url = track.artworkURL {
                AsyncImage(url: URL(string: url)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.2))
                }
                .frame(width: 200, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                .scaleEffect(animate ? 1 : 0.5)
                .opacity(animate ? 1 : 0)
            }
            
            VStack(spacing: 8) {
                Text(track.title)
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text(track.artist)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
            .scaleEffect(animate ? 1 : 0.8)
            .opacity(animate ? 1 : 0)
            
            Text("Played \(track.playCount) times")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Capsule().fill(.white.opacity(0.15)))
                .opacity(animate ? 1 : 0)
            
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Genre Breakdown Card

struct GenreBreakdownCard: View {
    let genres: [ListeningStats.TopGenre]
    @Binding var animate: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Your Taste")
                .font(.system(size: 28, weight: .black))
                .foregroundColor(.white)
                .padding(.top, 40)
                .opacity(animate ? 1 : 0)
            
            // Pie chart representation
            ZStack {
                ForEach(Array(genres.enumerated()), id: \.element.id) { index, genre in
                    Circle()
                        .trim(from: trimStart(for: index), to: trimStart(for: index) + CGFloat(genre.percentage))
                        .stroke(genreColor(genre.color), lineWidth: 40)
                        .rotationEffect(.degrees(-90))
                        .frame(width: 160, height: 160)
                        .scaleEffect(animate ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(Double(index) * 0.15), value: animate)
                }
            }
            .frame(width: 200, height: 200)
            
            // Legend
            VStack(spacing: 12) {
                ForEach(genres) { genre in
                    HStack {
                        Circle()
                            .fill(genreColor(genre.color))
                            .frame(width: 16, height: 16)
                        
                        Text(genre.name)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text("\(Int(genre.percentage * 100))%")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .opacity(animate ? 1 : 0)
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    private func trimStart(for index: Int) -> CGFloat {
        var start: CGFloat = 0
        for i in 0..<index {
            start += CGFloat(genres[i].percentage)
        }
        return start
    }
    
    private func genreColor(_ name: String) -> Color {
        switch name {
        case "orange": return .orange
        case "red": return .red
        case "purple": return .purple
        case "blue": return .blue
        case "green": return .green
        default: return .gray
        }
    }
}

// MARK: - Flint Pride Card

struct FlintPrideCard: View {
    let flintMinutes: Int
    let totalMinutes: Int
    @Binding var animate: Bool
    
    var percentage: Int {
        Int((Double(flintMinutes) / Double(totalMinutes)) * 100)
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // 810 Badge
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 140, height: 140)
                    .shadow(color: .orange.opacity(0.5), radius: 20)
                
                Text("810")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            }
            .scaleEffect(animate ? 1 : 0.3)
            .opacity(animate ? 1 : 0)
            
            Text("You're a true 810 supporter!")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .opacity(animate ? 1 : 0)
            
            VStack(spacing: 8) {
                Text("\(percentage)%")
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                
                Text("of your listening was\nFlint artists")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .scaleEffect(animate ? 1 : 0.8)
            .opacity(animate ? 1 : 0)
            
            Text("\(flintMinutes.formatted()) minutes")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Capsule().fill(.white.opacity(0.2)))
                .opacity(animate ? 1 : 0)
            
            Spacer()
            
            // Share button
            Button {
                HapticManager.shared.impact(style: .medium)
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share Your Stats")
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.black)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(Capsule().fill(.white))
            }
            .opacity(animate ? 1 : 0)
            .padding(.bottom, 20)
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Preview

#if DEBUG
struct ListeningStatsView_Previews: PreviewProvider {
    static var previews: some View {
        ListeningStatsView()
    }
}
#endif


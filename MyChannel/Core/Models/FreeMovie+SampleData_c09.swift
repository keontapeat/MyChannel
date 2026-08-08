import Foundation

extension FreeMovie {
    // MARK: Chunk 9 — Horror additions (user-requested)
    // Copyrighted studio titles: stream/trailer point to the official YouTube
    // trailer. Posters use the real TMDB poster art (image.tmdb.org, an approved
    // CDN) so cards show the actual movie poster; backdrops use the trailer frame.
    static let _smc09: [FreeMovie] = [
        FreeMovie(
            id: "yt-obsession-2025",
            title: "Obsession",
            posterURL: "https://image.tmdb.org/t/p/w500/bRwnj8WEKBCvmfeUNOukJPwB43K.jpg",
            backdropURL: "https://image.tmdb.org/t/p/w1280/r013C8Me2bZ0pUi0OWJRh0h7MzT.jpg",
            overview: "A hopeless romantic uses a supernatural trinket to force his longtime crush to love him — and unleashes a wave of horrifying, unhinged consequences. Curry Barker's chilling supernatural horror.",
            releaseDate: "2026-05-15",
            runtime: 98,
            genre: [.horror, .thriller, .mystery],
            rating: "R",
            imdbRating: 7.1,
            streamingSource: .youtube,
            streamURL: "https://www.youtube.com/watch?v=gMC8kkwbIQQ",
            trailerURL: "https://www.youtube.com/watch?v=gMC8kkwbIQQ",
            cast: [],
            director: "Curry Barker",
            year: 2026,
            language: "English",
            country: "US",
            isAvailable: true
        ),

        FreeMovie(
            id: "yt-jeepers-creepers-2-2003",
            title: "Jeepers Creepers 2",
            posterURL: "https://image.tmdb.org/t/p/w500/u2ghDfjcs3y5c8ata3COc4pWiAN.jpg",
            backdropURL: "https://image.tmdb.org/t/p/w1280/pPZUYQx5PuH4xkXkFizirTd0ey1.jpg",
            overview: "On the last day of its 23-day feeding frenzy, the flesh-eating Creeper stalks a busload of high-school athletes stranded on a remote highway. They must fight back before nightfall.",
            releaseDate: "2003-08-29",
            runtime: 104,
            genre: [.horror, .thriller],
            rating: "R",
            imdbRating: 5.6,
            streamingSource: .youtube,
            // Rotten Tomatoes Classic Trailers upload — embed-enabled. The prior
            // ScreamFactoryTV upload (Quy0zQ1PXVw) disabled embedding, which is
            // what produced YouTube's "unavailable / Error code 152-4" screen.
            streamURL: "https://www.youtube.com/watch?v=H1IA0LvpEpg",
            trailerURL: "https://www.youtube.com/watch?v=H1IA0LvpEpg",
            cast: ["Ray Wise", "Jonathan Breck", "Nicki Aycox"],
            director: "Victor Salva",
            year: 2003,
            language: "English",
            country: "US",
            isAvailable: true
        ),

        FreeMovie(
            id: "yt-dead-silence-2007",
            title: "Dead Silence",
            posterURL: "https://image.tmdb.org/t/p/w500/rvcUVdATIHKZt7BSSttUkKbeBXN.jpg",
            backdropURL: "https://image.tmdb.org/t/p/w1280/xMjAkXpCb55FTAV7By31p3TQMxb.jpg",
            overview: "After his wife meets a grisly end, Jamie Ashen returns to his haunted hometown of Ravens Fair to find answers — leading him to the ghost of a murdered ventriloquist named Mary Shaw.",
            releaseDate: "2007-03-16",
            runtime: 89,
            genre: [.horror, .mystery, .thriller],
            rating: "R",
            imdbRating: 6.2,
            streamingSource: .youtube,
            // Rotten Tomatoes Classic Trailers upload — embed-enabled. Moved off
            // the ScreamFactoryTV upload (NvVPn1gD1Xw, same channel as the
            // embed-blocked Jeepers Creepers 2 trailer) to avoid the 152-4 error.
            streamURL: "https://www.youtube.com/watch?v=8b_HVtHmK30",
            trailerURL: "https://www.youtube.com/watch?v=8b_HVtHmK30",
            cast: ["Ryan Kwanten", "Amber Valletta", "Donnie Wahlberg"],
            director: "James Wan",
            year: 2007,
            language: "English",
            country: "US",
            isAvailable: true
        )
    ]
}

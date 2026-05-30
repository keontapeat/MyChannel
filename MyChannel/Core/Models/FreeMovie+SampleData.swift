import Foundation

// MARK: - Sample Free Movies (THE BEST FREE FULL MOVIES! 🔥)
// PERFORMANCE: Split into 8 small files so Swift type-checker stays FAST.
// Each file has ≤21 movies — type-check is O(n) not O(n²).
extension FreeMovie {
    /// 🎬 EPIC COLLECTION: 160+ FREE FULL MOVIES Users Can Actually Watch!
    static var sampleMovies: [FreeMovie] {
        sampleMovies_c01 +
        sampleMovies_c02 +
        sampleMovies_c03 +
        sampleMovies_c04 +
        sampleMovies_c05 +
        sampleMovies_c06 +
        sampleMovies_c07 +
        sampleMovies_c08
    }
    private static var sampleMovies_c01: [FreeMovie] { _smc01 }
    private static var sampleMovies_c02: [FreeMovie] { _smc02 }
    private static var sampleMovies_c03: [FreeMovie] { _smc03 }
    private static var sampleMovies_c04: [FreeMovie] { _smc04 }
    private static var sampleMovies_c05: [FreeMovie] { _smc05 }
    private static var sampleMovies_c06: [FreeMovie] { _smc06 }
    private static var sampleMovies_c07: [FreeMovie] { _smc07 }
    private static var sampleMovies_c08: [FreeMovie] { _smc08 }
}

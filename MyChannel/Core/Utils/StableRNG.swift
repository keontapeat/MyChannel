import Foundation

/// Deterministic random number generator seeded by a UInt64.
/// Produces the same sequence every time for a given seed,
/// preventing ranking shuffles on refresh cycles.
struct StableRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 1 : seed
    }

    /// Create from a string using a stable FNV-1a hash
    /// (Swift's .hashValue changes between launches, so we need our own)
    init(string: String) {
        var hash: UInt64 = 14695981039346656037 // FNV offset basis
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211 // FNV prime
        }
        self.init(seed: hash)
    }

    mutating func next() -> UInt64 {
        // xorshift64 — fast, deterministic, good distribution
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

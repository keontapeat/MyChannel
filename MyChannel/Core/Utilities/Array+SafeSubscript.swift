import Foundation

// Safe array access — returns nil instead of trapping on out-of-bounds indices.
// Relocated here from the (removed) FreeMoviesView so shared callers
// (FlicksView, etc.) keep working independently of the Movies feature.
extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

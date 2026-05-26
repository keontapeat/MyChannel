import Foundation

extension URLSession {
    /// App-wide configured URLSession replacing `URLSession.shared`.
    /// Adds request/resource timeouts, connectivity waiting, and connection pooling
    /// that `URLSession.shared` lacks by default.
    static let configured: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        config.waitsForConnectivity = true
        config.httpMaximumConnectionsPerHost = 6
        return URLSession(configuration: config)
    }()
}

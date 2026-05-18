import Alamofire
import Foundation

/// Robust admin HTTP layer using Alamofire — retry, auth headers, request interception.
/// Used by Command Center, 3-Strike Review, and AGI Agent Manager for all admin API calls.
@MainActor
final class AlamofireAdminNetworkService: ObservableObject {
    static let shared = AlamofireAdminNetworkService()

    // MARK: - Alamofire session with retry + auth

    private lazy var session: Session = {
        let retryPolicy = RetryPolicy(
            retryLimit: 3,
            exponentialBackoffBase: 2,
            exponentialBackoffScale: 0.5,
            retryableHTTPStatusCodes: [408, 429, 500, 502, 503, 504]
        )
        let interceptor = Interceptor(
            adapters: [AdminAuthAdapter()],
            retriers: [retryPolicy]
        )
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        return Session(configuration: config, interceptor: interceptor)
    }()

    private let baseURL = AppConfig.API.baseURL

    private init() {}

    // MARK: - Generic GET

    func get<T: Decodable>(_ path: String, parameters: [String: Any]? = nil) async throws -> T {
        return try await withCheckedThrowingContinuation { cont in
            session.request("\(baseURL)\(path)", parameters: parameters)
                .validate()
                .responseDecodable(of: T.self) { response in
                    switch response.result {
                    case .success(let value): cont.resume(returning: value)
                    case .failure(let error): cont.resume(throwing: error)
                    }
                }
        }
    }

    // MARK: - Generic POST

    func post<T: Decodable>(_ path: String, body: Encodable) async throws -> T {
        return try await withCheckedThrowingContinuation { cont in
            session.request("\(baseURL)\(path)",
                            method: .post,
                            parameters: body,
                            encoder: JSONParameterEncoder.default)
                .validate()
                .responseDecodable(of: T.self) { response in
                    switch response.result {
                    case .success(let value): cont.resume(returning: value)
                    case .failure(let error): cont.resume(throwing: error)
                    }
                }
        }
    }

    // MARK: - Admin actions (fire-and-forget with logging)

    func postAdminAction(_ path: String, payload: [String: Any]) async {
        session.request("\(baseURL)\(path)",
                        method: .post,
                        parameters: payload,
                        encoding: JSONEncoding.default)
            .validate()
            .response { response in
                if let error = response.error {
                    AgentLogService.shared.agentFailed("AdminAction", agentId: path, error: error.localizedDescription)
                }
            }
    }

    // MARK: - Multipart upload (for report exports)

    func uploadFile(path: String, fileURL: URL, mimeType: String) async throws -> Bool {
        return try await withCheckedThrowingContinuation { cont in
            session.upload(multipartFormData: { form in
                form.append(fileURL, withName: "file", mimeType: mimeType)
            }, to: "\(baseURL)\(path)")
            .validate()
            .response { response in
                cont.resume(returning: response.error == nil)
            }
        }
    }

    // MARK: - Download (for report pulls)

    func downloadFile(from url: String, to destination: URL) async throws {
        let dest: DownloadRequest.Destination = { _, _ in (destination, [.removePreviousFile]) }
        return try await withCheckedThrowingContinuation { cont in
            session.download(url, to: dest)
                .validate()
                .response { response in
                    if let error = response.error { cont.resume(throwing: error) }
                    else { cont.resume() }
                }
        }
    }
}

// MARK: - Auth Adapter (injects admin JWT)

private struct AdminAuthAdapter: RequestAdapter {
    func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        var request = urlRequest
        if let token = UserDefaults.standard.string(forKey: "admin_auth_token") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("MyChannel-Admin-iOS/1.0", forHTTPHeaderField: "X-Client-ID")
        completion(.success(request))
    }
}

import Foundation

enum MusicAPIError: LocalizedError {
    case unavailable
    case invalidResponse
    case server(statusCode: Int, message: String)
    case unsupportedAudioType
    case invalidFile
    case invalidArtwork
    case invalidIdentifier
    case invalidCollaborators
    case invalidPayoutType
    case processingPending(trackId: String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Music services are temporarily unavailable."
        case .invalidResponse:
            return "The music service returned an invalid response."
        case let .server(_, message):
            return message
        case .unsupportedAudioType:
            return "Choose an MP3, WAV, M4A, AAC, FLAC, or OGG audio file."
        case .invalidFile:
            return "The selected audio file is empty or exceeds the 500 MB limit."
        case .invalidArtwork:
            return "Artwork must be a JPEG, PNG, or WebP image no larger than 10 MB."
        case .invalidIdentifier:
            return "The music service identifier is invalid."
        case .invalidCollaborators:
            return "Collaborators must use linked user IDs and exact integer basis points totaling 10,000."
        case .invalidPayoutType:
            return "Payout type must be standard or instant."
        case .processingPending:
            return "Upload completed, but transcoding could not be started. The track remains private pending processing and review."
        }
    }
}

struct MusicUploadMetadata: Encodable {
    let title: String
    let artistName: String
    let albumName: String?
    let genre: String
    let isExplicit: Bool
    let duration: Double?
}

struct MusicUploadResult {
    let trackId: String
    let status: String
    let transcodingStatus: String
    let message: String

    var isAwaitingHandoff: Bool { transcodingStatus == "awaiting_handoff" }
}
struct MusicCollaboratorInput: Encodable {
    let artistId: String
    let name: String
    let role: String
    let basisPoints: Int
}

struct MusicCollaboratorSplit: Decodable, Identifiable {
    let artistId: String
    let name: String
    let role: String
    let basisPoints: Int

    var id: String { artistId }
}

struct MusicCollaboratorsResponse: Decodable {
    let trackId: String
    let totalBasisPoints: Int
    let collaborators: [MusicCollaboratorSplit]
    let revision: Int
}

struct MusicAvailableBalance {
    let amountCents: Int
    let ownerAmountCents: Int
    let totalGrossCents: Int
    let minimumPayoutCents: Int
    let isReadyForPayout: Bool
    let stripeConnected: Bool
    let payoutAccountReady: Bool
    let ownerStreams: Int
    let standardDelivery: String
}

enum MusicPayoutStatus: String, Decodable {
    case paid
    case partiallyPaid = "partially_paid"
    case owed
}

struct MusicPayoutSplit: Decodable, Identifiable {
    let payeeId: String
    let name: String
    let role: String
    let amountCents: Int
    let streams: Int
    let status: MusicPayoutStatus

    var id: String { payeeId }
}

struct MusicPayoutResult: Decodable {
    let success: Bool
    let status: MusicPayoutStatus?
    let transferGroup: String?
    let splits: [MusicPayoutSplit]?
    let message: String?
}

struct MusicOnboardingLink: Decodable {
    let url: URL
    let stripeAccountId: String
}

actor MusicAPIClient {
    static let shared = MusicAPIClient()

    private static let chunkSize = 5 * 1024 * 1024
    private static let maximumFileSize = 500 * 1024 * 1024
    private static let maximumArtworkSize = 10 * 1024 * 1024

    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init(session: URLSession = .shared) {
        self.session = session
    }

    func upload(
        fileURL: URL,
        metadata: MusicUploadMetadata,
        artworkData: Data? = nil,
        artworkMimeType: String? = nil,
        progress: (@Sendable (Double) async -> Void)? = nil
    ) async throws -> MusicUploadResult {
        let hasSecurityScope = fileURL.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityScope { fileURL.stopAccessingSecurityScopedResource() }
        }

        try Task.checkCancellation()
        let values = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard values.isRegularFile == true,
              let fileSize = values.fileSize,
              fileSize > 0,
              fileSize <= Self.maximumFileSize else {
            throw MusicAPIError.invalidFile
        }

        let mimeType = try Self.audioMimeType(for: fileURL)
        let initiation: UploadInitiationResponse = try await request(
            baseURL: try musicBaseURL(),
            path: ["v1", "music", "tracks", "upload"],
            method: "POST",
            body: metadata
        )
        let trackId = initiation.trackId

        do {
            if let artworkData {
                guard artworkData.count > 0,
                      artworkData.count <= Self.maximumArtworkSize,
                      let artworkMimeType,
                      ["image/jpeg", "image/png", "image/webp"].contains(artworkMimeType) else {
                    throw MusicAPIError.invalidArtwork
                }
                let artwork = ArtworkRequest(
                    artworkData: artworkData.base64EncodedString(),
                    mimeType: artworkMimeType
                )
                let _: MusicMessageResponse = try await request(
                    baseURL: try musicBaseURL(),
                    path: ["v1", "music", "tracks", trackId, "artwork"],
                    method: "POST",
                    body: artwork
                )
            }

            let totalChunks = Int(ceil(Double(fileSize) / Double(Self.chunkSize)))
            let handle = try FileHandle(forReadingFrom: fileURL)
            defer { try? handle.close() }

            for chunkIndex in 0..<totalChunks {
                try Task.checkCancellation()
                guard let chunk = try handle.read(upToCount: Self.chunkSize), !chunk.isEmpty else {
                    throw MusicAPIError.invalidFile
                }
                let body = ChunkRequest(
                    chunkIndex: chunkIndex,
                    totalChunks: totalChunks,
                    chunkData: chunk.base64EncodedString(),
                    mimeType: mimeType
                )
                let _: MusicMessageResponse = try await request(
                    baseURL: try musicBaseURL(),
                    path: ["v1", "music", "tracks", trackId, "chunk"],
                    method: "POST",
                    body: body
                )
                await progress?(Double(chunkIndex + 1) / Double(totalChunks))
            }

            try Task.checkCancellation()
            let completion = CompleteRequest(
                fileName: Self.safeFileName(for: fileURL, mimeType: mimeType),
                mimeType: mimeType
            )
            let completed: UploadCompletionResponse = try await request(
                baseURL: try musicBaseURL(),
                path: ["v1", "music", "tracks", trackId, "complete"],
                method: "POST",
                body: completion
            )
            guard completed.trackId == trackId else { throw MusicAPIError.invalidResponse }
            return MusicUploadResult(
                trackId: trackId,
                status: completed.status,
                transcodingStatus: completed.transcodingStatus,
                message: completed.message
            )
        } catch {
            if Task.isCancelled || error is CancellationError {
                let cleanup = Task.detached {
                    try? await MusicAPIClient.shared.deleteTrack(trackId: trackId)
                }
                _ = await cleanup.value
                throw CancellationError()
            }
            throw error
        }
    }

    func deleteTrack(trackId: String) async throws {
        let _: MusicMessageResponse = try await request(
            baseURL: try musicBaseURL(),
            path: ["v1", "music", "tracks", trackId],
            method: "DELETE"
        )
    }

    func submitQualifiedPlay(
        trackId: String,
        sessionId: UUID,
        qualifiedSeconds: Int
    ) async throws {
        guard qualifiedSeconds >= 30 else { return }
        let body = QualifiedPlayRequest(
            sessionId: sessionId.uuidString.lowercased(),
            qualifiedSeconds: qualifiedSeconds
        )
        let _: PlayResponse = try await request(
            baseURL: try musicBaseURL(),
            path: ["v1", "music", "tracks", trackId, "plays"],
            method: "POST",
            body: body
        )
    }

    func like(trackId: String) async throws -> Int {
        let response: LikeResponse = try await request(
            baseURL: try musicBaseURL(),
            path: ["v1", "music", "tracks", trackId, "likes"],
            method: "POST",
            body: EmptyBody()
        )
        return response.likeCount
    }

    func getCollaborators(trackId: String) async throws -> MusicCollaboratorsResponse {
        guard Self.isSafeIdentifier(trackId) else { throw MusicAPIError.invalidIdentifier }
        let response: MusicCollaboratorsResponse = try await request(
            baseURL: try musicBaseURL(),
            path: ["v1", "music", "tracks", trackId, "collaborators"],
            method: "GET"
        )
        guard response.trackId == trackId,
              response.revision >= 0,
              Self.hasValidCollaborators(response.collaborators, total: response.totalBasisPoints) else {
            throw MusicAPIError.invalidResponse
        }
        return response
    }

    @discardableResult
    func replaceCollaborators(
        trackId: String,
        collaborators: [MusicCollaboratorInput]
    ) async throws -> MusicCollaboratorsResponse {
        guard Self.isSafeIdentifier(trackId),
              Self.hasValidCollaboratorInputs(collaborators) else {
            throw MusicAPIError.invalidCollaborators
        }
        let body = CollaboratorsRequest(collaborators: collaborators)
        let response: MusicCollaboratorsResponse = try await request(
            baseURL: try musicBaseURL(),
            path: ["v1", "music", "tracks", trackId, "collaborators"],
            method: "PUT",
            body: body
        )
        guard response.trackId == trackId,
              response.revision > 0,
              Self.hasValidCollaborators(response.collaborators, total: response.totalBasisPoints) else {
            throw MusicAPIError.invalidResponse
        }
        return response
    }

    func getAvailableBalance(artistId: String) async throws -> MusicAvailableBalance {
        guard Self.isSafeIdentifier(artistId) else { throw MusicAPIError.invalidIdentifier }
        let response: MusicBalanceResponse = try await request(
            baseURL: try payoutsBaseURL(),
            path: ["getAvailableBalance"],
            method: "GET",
            queryItems: [URLQueryItem(name: "artistId", value: artistId)]
        )
        return MusicAvailableBalance(
            amountCents: response.amountCents,
            ownerAmountCents: response.ownerAmountCents,
            totalGrossCents: response.totalGrossCents,
            minimumPayoutCents: response.minimumPayoutCents,
            isReadyForPayout: response.isReadyForPayout,
            stripeConnected: response.stripeConnected,
            payoutAccountReady: response.payoutAccountReady,
            ownerStreams: response.ownerStreams,
            standardDelivery: response.estimatedStandardDelivery
        )
    }

    func payoutArtist(artistId: String) async throws -> MusicPayoutResult {
        guard Self.isSafeIdentifier(artistId) else { throw MusicAPIError.invalidIdentifier }
        return try await request(
            baseURL: try payoutsBaseURL(),
            path: ["payoutArtist"],
            method: "POST",
            body: ArtistRequest(artistId: artistId)
        )
    }

    func requestPayout(artistId: String, payoutType: String) async throws -> MusicPayoutResult {
        guard Self.isSafeIdentifier(artistId) else { throw MusicAPIError.invalidIdentifier }
        guard payoutType == "standard" || payoutType == "instant" else {
            throw MusicAPIError.invalidPayoutType
        }
        return try await request(
            baseURL: try payoutsBaseURL(),
            path: ["requestPayout"],
            method: "POST",
            body: MusicPayoutRequest(artistId: artistId, payoutType: payoutType)
        )
    }

    func createConnectOnboardingLink(
        artistId: String,
        email: String?,
        refreshURL: URL,
        returnURL: URL
    ) async throws -> MusicOnboardingLink {
        guard Self.isSafeIdentifier(artistId) else { throw MusicAPIError.invalidIdentifier }
        let body = OnboardingRequest(
            artistId: artistId,
            email: email,
            refreshUrl: refreshURL.absoluteString,
            returnUrl: returnURL.absoluteString
        )
        return try await request(
            baseURL: try payoutsBaseURL(),
            path: ["createConnectOnboardingLink"],
            method: "POST",
            body: body
        )
    }

    nonisolated static func publicPlaybackURL(from candidates: [String?]) -> URL? {
        for candidate in candidates {
            guard let candidate,
                  let url = URL(string: candidate),
                  url.scheme?.lowercased() == "https",
                  url.host?.isEmpty == false else { continue }
            return url
        }
        return nil
    }

    private func musicBaseURL() throws -> URL {
        guard let url = AppConfig.API.musicAPIBaseURL,
              url.scheme?.lowercased() == "https",
              url.host?.isEmpty == false else {
            throw MusicAPIError.unavailable
        }
        return url
    }

    private func payoutsBaseURL() throws -> URL {
        guard let url = URL(string: AppConfig.API.musicPayoutsBaseURL),
              url.scheme?.lowercased() == "https",
              url.host?.isEmpty == false else {
            throw MusicAPIError.unavailable
        }
        return url
    }

    private func request<Response: Decodable>(
        baseURL: URL,
        path: [String],
        method: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> Response {
        try await request(
            baseURL: baseURL,
            path: path,
            method: method,
            queryItems: queryItems,
            encodedBody: nil
        )
    }

    private func request<Body: Encodable, Response: Decodable>(
        baseURL: URL,
        path: [String],
        method: String,
        queryItems: [URLQueryItem] = [],
        body: Body
    ) async throws -> Response {
        try await request(
            baseURL: baseURL,
            path: path,
            method: method,
            queryItems: queryItems,
            encodedBody: try encoder.encode(body)
        )
    }

    private func request<Response: Decodable>(
        baseURL: URL,
        path: [String],
        method: String,
        queryItems: [URLQueryItem],
        encodedBody: Data?
    ) async throws -> Response {
        try Task.checkCancellation()
        var url = baseURL
        for component in path { url.appendPathComponent(component) }
        if !queryItems.isEmpty {
            guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                throw MusicAPIError.unavailable
            }
            components.queryItems = queryItems
            guard let queryURL = components.url else { throw MusicAPIError.unavailable }
            url = queryURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = AppConfig.API.timeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let encodedBody {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = encodedBody
        }
        try await AuthTokenProvider.authorize(&request)
        try Task.checkCancellation()

        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MusicAPIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = (try? decoder.decode(APIErrorResponse.self, from: data).error)
                ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            throw MusicAPIError.server(statusCode: httpResponse.statusCode, message: message)
        }
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw MusicAPIError.invalidResponse
        }
    }

    private nonisolated static func isSafeIdentifier(_ value: String) -> Bool {
        value.range(
            of: #"^[A-Za-z0-9_-]{1,128}$"#,
            options: .regularExpression
        ) != nil
    }

    private nonisolated static func hasValidCollaboratorInputs(
        _ collaborators: [MusicCollaboratorInput]
    ) -> Bool {
        guard (1...20).contains(collaborators.count) else { return false }
        let supportedRoles: Set<String> = [
            "primary_artist", "featured_artist", "producer", "songwriter",
            "composer", "performer", "label", "publisher"
        ]
        var artistIds = Set<String>()
        var totalBasisPoints = 0
        for collaborator in collaborators {
            let name = collaborator.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard isSafeIdentifier(collaborator.artistId),
                  artistIds.insert(collaborator.artistId).inserted,
                  (1...120).contains(name.count),
                  supportedRoles.contains(collaborator.role),
                  (1...10_000).contains(collaborator.basisPoints) else { return false }
            totalBasisPoints += collaborator.basisPoints
        }
        return totalBasisPoints == 10_000
    }

    private nonisolated static func hasValidCollaborators(
        _ collaborators: [MusicCollaboratorSplit],
        total: Int
    ) -> Bool {
        if collaborators.isEmpty { return total == 0 }
        let inputs = collaborators.map {
            MusicCollaboratorInput(
                artistId: $0.artistId,
                name: $0.name,
                role: $0.role,
                basisPoints: $0.basisPoints
            )
        }
        return total == 10_000 && hasValidCollaboratorInputs(inputs)
    }

    private nonisolated static func audioMimeType(for url: URL) throws -> String {
        switch url.pathExtension.lowercased() {
        case "mp3": return "audio/mpeg"
        case "m4a", "mp4": return "audio/mp4"
        case "wav": return "audio/wav"
        case "aac": return "audio/aac"
        case "flac": return "audio/flac"
        case "ogg": return "audio/ogg"
        default: throw MusicAPIError.unsupportedAudioType
        }
    }

    private nonisolated static func safeFileName(for url: URL, mimeType: String) -> String {
        let extensions = [
            "audio/mpeg": "mp3", "audio/mp4": "m4a", "audio/wav": "wav",
            "audio/aac": "aac", "audio/flac": "flac", "audio/ogg": "ogg"
        ]
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._ -"))
        let base = url.deletingPathExtension().lastPathComponent.unicodeScalars
            .map { allowed.contains($0) ? Character(String($0)) : "_" }
        let normalized = String(base).prefix(200)
        return "\(normalized.isEmpty ? "track" : String(normalized)).\(extensions[mimeType] ?? "mp3")"
    }

    private nonisolated static func cents(fromUSD amount: Decimal) throws -> Int {
        var dollars = amount
        var cents = Decimal()
        NSDecimalMultiplyByPowerOf10(&cents, &dollars, 2, .bankers)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &cents, 0, .bankers)
        let number = NSDecimalNumber(decimal: rounded)
        guard number != .notANumber,
              number.compare(NSDecimalNumber(value: 0)) != .orderedAscending,
              number.compare(NSDecimalNumber(value: Int.max)) != .orderedDescending else {
            throw MusicAPIError.invalidResponse
        }
        return number.intValue
    }
}

private struct EmptyBody: Encodable {}
private struct APIErrorResponse: Decodable { let error: String }
private struct UploadInitiationResponse: Decodable { let trackId: String }
private struct UploadCompletionResponse: Decodable {
    let trackId: String
    let status: String
    let transcodingStatus: String
    let message: String
}
private struct MusicMessageResponse: Decodable { let message: String }
private struct PlayResponse: Decodable { let trackId: String }
private struct TranscodeResponse: Decodable { let status: String }
private struct LikeResponse: Decodable { let likeCount: Int }
private struct MusicBalanceResponse: Decodable {
    let amountCents: Int
    let ownerAmountCents: Int
    let totalGrossCents: Int
    let minimumPayoutCents: Int
    let isReadyForPayout: Bool
    let stripeConnected: Bool
    let payoutAccountReady: Bool
    let ownerStreams: Int
    let estimatedStandardDelivery: String

    private enum CodingKeys: String, CodingKey {
        case amountCents
        case ownerAmountCents
        case totalGrossCents
        case minimumPayoutCents
        case isReadyForPayout
        case stripeConnected
        case payoutAccountReady
        case ownerStreams
        case estimatedStandardDelivery
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        amountCents = try values.decode(Int.self, forKey: .amountCents)
        ownerAmountCents = try values.decode(Int.self, forKey: .ownerAmountCents)
        totalGrossCents = try values.decode(Int.self, forKey: .totalGrossCents)
        minimumPayoutCents = try values.decode(Int.self, forKey: .minimumPayoutCents)
        isReadyForPayout = try values.decode(Bool.self, forKey: .isReadyForPayout)
        stripeConnected = try values.decode(Bool.self, forKey: .stripeConnected)
        payoutAccountReady = try values.decode(Bool.self, forKey: .payoutAccountReady)
        ownerStreams = try values.decode(Int.self, forKey: .ownerStreams)
        estimatedStandardDelivery = try values.decode(
            String.self,
            forKey: .estimatedStandardDelivery
        )

        guard amountCents >= 0,
              ownerAmountCents == amountCents,
              totalGrossCents >= ownerAmountCents,
              minimumPayoutCents > 0,
              ownerStreams >= 0,
              stripeConnected == payoutAccountReady,
              !isReadyForPayout || (
                payoutAccountReady && ownerAmountCents >= minimumPayoutCents
              ) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Balance response contains inconsistent authoritative fields."
                )
            )
        }
    }
}
private struct ChunkRequest: Encodable {
    let chunkIndex: Int
    let totalChunks: Int
    let chunkData: String
    let mimeType: String
}
private struct CompleteRequest: Encodable { let fileName: String; let mimeType: String }
private struct ArtworkRequest: Encodable { let artworkData: String; let mimeType: String }
private struct QualifiedPlayRequest: Encodable { let sessionId: String; let qualifiedSeconds: Int }
private struct CollaboratorsRequest: Encodable { let collaborators: [MusicCollaboratorInput] }
private struct ArtistRequest: Encodable { let artistId: String }
private struct MusicPayoutRequest: Encodable { let artistId: String; let payoutType: String }
private struct OnboardingRequest: Encodable {
    let artistId: String
    let email: String?
    let refreshUrl: String
    let returnUrl: String
}

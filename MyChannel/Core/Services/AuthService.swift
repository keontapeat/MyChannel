//
//  AuthService.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import Foundation
import Combine
import AuthenticationServices
import CryptoKit
import SwiftUI

// MARK: - Authentication Service
@MainActor
class AuthService: ObservableObject {
    static let shared = AuthService()
    
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: User?
    @Published var authState: AuthState = .unauthenticated
    @Published var isLoading: Bool = false
    
    private let networkService = NetworkService.shared
    private let keychain = KeychainHelper.shared
    private var cancellables = Set<AnyCancellable>()
    private var tokenRefreshTimer: Timer?
    
    enum AuthState: Equatable {
        case unauthenticated
        case authenticating
        case authenticated
        case error(String)
        
        static func == (lhs: AuthState, rhs: AuthState) -> Bool {
            switch (lhs, rhs) {
            case (.unauthenticated, .unauthenticated),
                 (.authenticating, .authenticating),
                 (.authenticated, .authenticated):
                return true
            case (.error(let lhsMessage), .error(let rhsMessage)):
                return lhsMessage == rhsMessage
            default:
                return false
            }
        }
    }
    
    private init() {
        checkAuthenticationStatus()
        setupTokenRefresh()
    }
    
    // MARK: - Authentication Status Check
    private func checkAuthenticationStatus() {
        guard let accessToken = keychain.getString(for: "accessToken"),
              let refreshToken = keychain.getString(for: "refreshToken") else {
            authState = .unauthenticated
            return
        }
        
        // Validate tokens
        Task {
            do {
                try await validateAndRefreshTokens(accessToken: accessToken, refreshToken: refreshToken)
            } catch {
                await signOut()
            }
        }
    }
    
    // MARK: - Sign In
    func signIn(email: String, password: String) async throws {
        authState = .authenticating
        isLoading = true
        
        defer {
            isLoading = false
        }
        
        do {
            let deviceId = await getDeviceId()
            let request = SignInRequest(email: email, password: password, deviceId: deviceId)
            
            let response: APIResponse<SignInResponse> = try await networkService.post(
                endpoint: .signIn,
                body: request,
                responseType: APIResponse<SignInResponse>.self
            )
            
            // Store tokens securely
            _ = keychain.save(response.data.accessToken, for: "accessToken")
            _ = keychain.save(response.data.refreshToken, for: "refreshToken")
            _ = keychain.save(response.data.user.id, for: "userId")
            
            // Update state
            currentUser = response.data.user
            isAuthenticated = true
            authState = .authenticated
            
            // Setup token refresh
            scheduleTokenRefresh(expiresIn: response.data.expiresIn)
            
            // Track analytics
            await AnalyticsService.shared.trackEvent("user_sign_in", parameters: [
                "method": "email",
                "user_id": response.data.user.id
            ])
            
            NotificationManager.shared.showSuccess("Welcome back, \(response.data.user.displayName)!")
            
        } catch {
            authState = .error(error.localizedDescription)
            NotificationManager.shared.showError("Sign in failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Sign Up
    func signUp(
        firstName: String,
        lastName: String,
        username: String,
        email: String,
        password: String
    ) async throws {
        authState = .authenticating
        isLoading = true
        
        defer {
            isLoading = false
        }
        
        do {
            // Validate input
            try validateSignUpInput(
                firstName: firstName,
                lastName: lastName,
                username: username,
                email: email,
                password: password
            )
            
            let deviceId = await getDeviceId()
            let request = SignUpRequest(
                email: email,
                password: password,
                username: username.lowercased(),
                displayName: "\(firstName) \(lastName)",
                deviceId: deviceId
            )
            
            let response: APIResponse<SignInResponse> = try await networkService.post(
                endpoint: .signUp,
                body: request,
                responseType: APIResponse<SignInResponse>.self
            )
            
            // Store tokens securely
            _ = keychain.save(response.data.accessToken, for: "accessToken")
            _ = keychain.save(response.data.refreshToken, for: "refreshToken")
            _ = keychain.save(response.data.user.id, for: "userId")
            
            // Update state
            currentUser = response.data.user
            isAuthenticated = true
            authState = .authenticated
            
            // Setup token refresh
            scheduleTokenRefresh(expiresIn: response.data.expiresIn)
            
            // Track analytics
            await AnalyticsService.shared.trackEvent("user_sign_up", parameters: [
                "method": "email",
                "user_id": response.data.user.id
            ])
            
            NotificationManager.shared.showSuccess("Welcome to MyChannel, \(firstName)! 🎉")
            
        } catch {
            authState = .error(error.localizedDescription)
            NotificationManager.shared.showError("Sign up failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Social Authentication
    func signInWithApple() async throws {
        guard AppConfig.Social.enableAppleLogin else {
            throw AuthError.socialLoginDisabled
        }
        
        authState = .authenticating
        isLoading = true
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            
            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            let delegate = AppleSignInDelegate { [weak self] result in
                Task { @MainActor in
                    do {
                        switch result {
                        case .success(let appleSignInResult):
                            try await self?.processAppleSignIn(appleSignInResult)
                            continuation.resume()
                        case .failure(let error):
                            self?.authState = .error(error.localizedDescription)
                            self?.isLoading = false
                            continuation.resume(throwing: error)
                        }
                    } catch {
                        self?.authState = .error(error.localizedDescription)
                        self?.isLoading = false
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            authorizationController.delegate = delegate
            authorizationController.performRequests()
        }
    }
    
    func signInWithGoogle() async throws {
        guard AppConfig.Social.enableGoogleLogin else {
            throw AuthError.socialLoginDisabled
        }
        
        // For now, simulate Google Sign In
        // In production, you'd integrate Google Sign-In SDK
        
        authState = .authenticating
        isLoading = true
        
        defer {
            isLoading = false
        }
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 2_000_000_000)
        
        do {
            // Mock Google user data
            let mockUser = User(
                username: "google_user_\(UUID().uuidString.prefix(8))",
                displayName: "Google User",
                email: "user@gmail.com",
                profileImageURL: "https://picsum.photos/200/200?random=300",
                bio: "Signed in with Google 🔍",
                subscriberCount: 0,
                videoCount: 0,
                isVerified: false,
                isCreator: true
            )
            
            // Mock tokens
            let accessToken = "google_access_token_\(UUID().uuidString)"
            let refreshToken = "google_refresh_token_\(UUID().uuidString)"
            
            // Store tokens
            _ = keychain.save(accessToken, for: "accessToken")
            _ = keychain.save(refreshToken, for: "refreshToken")
            _ = keychain.save(mockUser.id, for: "userId")
            
            // Update state
            currentUser = mockUser
            isAuthenticated = true
            authState = .authenticated
            
            // Track analytics
            await AnalyticsService.shared.trackEvent("user_sign_in", parameters: [
                "method": "google",
                "user_id": mockUser.id
            ])
            
            NotificationManager.shared.showSuccess("Welcome, \(mockUser.displayName)!")
            
        } catch {
            authState = .error(error.localizedDescription)
            throw error
        }
    }
    
    // MARK: - Sign Out
    func signOut() async {
        // Cancel token refresh
        tokenRefreshTimer?.invalidate()
        tokenRefreshTimer = nil
        
        // Clear stored credentials
        _ = keychain.delete(for: "accessToken")
        _ = keychain.delete(for: "refreshToken")
        _ = keychain.delete(for: "userId")
        
        // Send sign out request to server
        do {
            let _: APIResponse<EmptyResponse> = try await networkService.post(
                endpoint: .signOut,
                body: EmptyRequest(),
                responseType: APIResponse<EmptyResponse>.self
            )
        } catch {
            print("Failed to notify server of sign out: \(error)")
        }
        
        // Update state
        withAnimation(.easeInOut(duration: 0.5)) {
            currentUser = nil
            isAuthenticated = false
            authState = .unauthenticated
        }
        
        NotificationManager.shared.showInfo("You've been signed out")
    }
    
    // MARK: - Token Management
    private func validateAndRefreshTokens(accessToken: String, refreshToken: String) async throws {
        // First, try to use the current access token
        do {
            let userProfile = try await fetchUserProfile(with: accessToken)
            currentUser = userProfile
            isAuthenticated = true
            authState = .authenticated
            return
        } catch {
            // Access token is invalid, try to refresh
            try await refreshAccessToken(refreshToken: refreshToken)
        }
    }
    
    private func refreshAccessToken(refreshToken: String) async throws {
        let request = RefreshTokenRequest(refreshToken: refreshToken, deviceId: await getDeviceId())
        
        let response: APIResponse<SignInResponse> = try await networkService.post(
            endpoint: .refreshToken,
            body: request,
            responseType: APIResponse<SignInResponse>.self
        )
        
        // Store new tokens
        _ = keychain.save(response.data.accessToken, for: "accessToken")
        _ = keychain.save(response.data.refreshToken, for: "refreshToken")
        
        // Update state
        currentUser = response.data.user
        isAuthenticated = true
        authState = .authenticated
        
        // Schedule next refresh
        scheduleTokenRefresh(expiresIn: response.data.expiresIn)
    }
    
    private func scheduleTokenRefresh(expiresIn: TimeInterval) {
        // Refresh token 5 minutes before expiration
        let refreshTime = max(300, expiresIn - 300) // 5 minutes = 300 seconds
        
        tokenRefreshTimer = Timer.scheduledTimer(withTimeInterval: refreshTime, repeats: false) { [weak self] _ in
            Task { @MainActor in
                do {
                    if let refreshToken = self?.keychain.getString(for: "refreshToken") {
                        try await self?.refreshAccessToken(refreshToken: refreshToken)
                    }
                } catch {
                    await self?.signOut()
                }
            }
        }
    }
    
    private func setupTokenRefresh() {
        // Check token expiration on app becoming active
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    if self?.isAuthenticated == true {
                        do {
                            if let accessToken = self?.keychain.getString(for: "accessToken"),
                               let refreshToken = self?.keychain.getString(for: "refreshToken") {
                                try await self?.validateAndRefreshTokens(accessToken: accessToken, refreshToken: refreshToken)
                            }
                        } catch {
                            await self?.signOut()
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - User Profile
    private func fetchUserProfile(with accessToken: String) async throws -> User {
        guard let userId = keychain.getString(for: "userId") else {
            throw AuthError.noUserId
        }
        
        let response: APIResponse<User> = try await networkService.get(
            endpoint: .userProfile(userId),
            responseType: APIResponse<User>.self,
            headers: ["Authorization": "Bearer \(accessToken)"]
        )
        
        return response.data
    }
    
    func updateProfile(_ user: User) async throws {
        let response: APIResponse<User> = try await networkService.put(
            endpoint: .updateProfile,
            body: user,
            responseType: APIResponse<User>.self
        )
        
        currentUser = response.data
        NotificationManager.shared.showSuccess("Profile updated successfully!")
    }
    
    // MARK: - Password Reset
    func requestPasswordReset(email: String) async throws {
        let request = PasswordResetRequest(email: email)
        
        let _: APIResponse<EmptyResponse> = try await networkService.post(
            endpoint: .passwordReset,
            body: request,
            responseType: APIResponse<EmptyResponse>.self
        )
        
        NotificationManager.shared.showSuccess("Password reset email sent!")
    }
    
    // MARK: - Input Validation
    private func validateSignUpInput(
        firstName: String,
        lastName: String,
        username: String,
        email: String,
        password: String
    ) throws {
        // Name validation
        guard !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AuthError.invalidFirstName
        }
        
        guard !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AuthError.invalidLastName
        }
        
        // Username validation
        guard username.count >= 3 else {
            throw AuthError.usernameTooShort
        }
        
        guard username.count <= 30 else {
            throw AuthError.usernameTooLong
        }
        
        let usernameRegex = "^[a-zA-Z0-9_.-]+$"
        guard NSPredicate(format: "SELF MATCHES %@", usernameRegex).evaluate(with: username) else {
            throw AuthError.invalidUsername
        }
        
        // Email validation
        let emailRegex = #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"#
        guard NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: email) else {
            throw AuthError.invalidEmail
        }
        
        // Password validation
        guard password.count >= 8 else {
            throw AuthError.passwordTooShort
        }
        
        guard password.contains(where: { $0.isUppercase }) else {
            throw AuthError.passwordNeedsUppercase
        }
        
        guard password.contains(where: { $0.isLowercase }) else {
            throw AuthError.passwordNeedsLowercase
        }
        
        guard password.contains(where: { $0.isNumber }) else {
            throw AuthError.passwordNeedsNumber
        }
    }
    
    // MARK: - Utilities
    private func getDeviceId() async -> String {
        if let existingId = keychain.getString(for: "deviceId") {
            return existingId
        }
        
        let deviceId = UUID().uuidString
        _ = keychain.save(deviceId, for: "deviceId")
        return deviceId
    }
    
    // MARK: - Apple Sign In Processing
    private func processAppleSignIn(_ result: AppleSignInResult) async throws {
        let request = AppleSignInRequest(
            identityToken: result.identityToken,
            authorizationCode: result.authorizationCode,
            fullName: result.fullName,
            email: result.email,
            deviceId: await getDeviceId()
        )
        
        let response: APIResponse<SignInResponse> = try await networkService.post(
            endpoint: .appleSignIn,
            body: request,
            responseType: APIResponse<SignInResponse>.self
        )
        
        // Store tokens
        _ = keychain.save(response.data.accessToken, for: "accessToken")
        _ = keychain.save(response.data.refreshToken, for: "refreshToken")
        _ = keychain.save(response.data.user.id, for: "userId")
        
        // Update state
        currentUser = response.data.user
        isAuthenticated = true
        authState = .authenticated
        isLoading = false
        
        // Setup token refresh
        scheduleTokenRefresh(expiresIn: response.data.expiresIn)
        
        // Track analytics
        await AnalyticsService.shared.trackEvent("user_sign_in", parameters: [
            "method": "apple",
            "user_id": response.data.user.id
        ])
        
        NotificationManager.shared.showSuccess("Welcome, \(response.data.user.displayName)!")
    }
}

// MARK: - Authentication Errors
enum AuthError: LocalizedError {
    case invalidCredentials
    case invalidEmail
    case invalidFirstName
    case invalidLastName
    case invalidUsername
    case usernameTooShort
    case usernameTooLong
    case passwordTooShort
    case passwordNeedsUppercase
    case passwordNeedsLowercase
    case passwordNeedsNumber
    case usernameExists
    case emailExists
    case networkError
    case tokenExpired
    case refreshTokenInvalid
    case noUserId
    case socialLoginDisabled
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password. Please try again."
        case .invalidEmail:
            return "Please enter a valid email address."
        case .invalidFirstName:
            return "Please enter your first name."
        case .invalidLastName:
            return "Please enter your last name."
        case .invalidUsername:
            return "Username can only contain letters, numbers, and ._- characters."
        case .usernameTooShort:
            return "Username must be at least 3 characters long."
        case .usernameTooLong:
            return "Username cannot be longer than 30 characters."
        case .passwordTooShort:
            return "Password must be at least 8 characters long."
        case .passwordNeedsUppercase:
            return "Password must contain at least one uppercase letter."
        case .passwordNeedsLowercase:
            return "Password must contain at least one lowercase letter."
        case .passwordNeedsNumber:
            return "Password must contain at least one number."
        case .usernameExists:
            return "This username is already taken. Please choose another one."
        case .emailExists:
            return "An account with this email already exists."
        case .networkError:
            return "Network connection failed. Please check your internet connection."
        case .tokenExpired:
            return "Your session has expired. Please sign in again."
        case .refreshTokenInvalid:
            return "Your session is invalid. Please sign in again."
        case .noUserId:
            return "User ID not found. Please sign in again."
        case .socialLoginDisabled:
            return "Social login is not available at this time."
        case .unknown:
            return "An unexpected error occurred. Please try again."
        }
    }
}

// MARK: - Request Models
struct RefreshTokenRequest: Codable {
    let refreshToken: String
    let deviceId: String
}

struct PasswordResetRequest: Codable {
    let email: String
}

struct AppleSignInRequest: Codable {
    let identityToken: String
    let authorizationCode: String
    let fullName: PersonNameComponents?
    let email: String?
    let deviceId: String
}

// MARK: - Apple Sign In Support
struct AppleSignInResult {
    let identityToken: String
    let authorizationCode: String
    let fullName: PersonNameComponents?
    let email: String?
}

class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate {
    private let completion: (Result<AppleSignInResult, Error>) -> Void
    
    init(completion: @escaping (Result<AppleSignInResult, Error>) -> Void) {
        self.completion = completion
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            guard let identityTokenData = appleIDCredential.identityToken,
                  let identityToken = String(data: identityTokenData, encoding: .utf8),
                  let authorizationCodeData = appleIDCredential.authorizationCode,
                  let authorizationCode = String(data: authorizationCodeData, encoding: .utf8) else {
                completion(.failure(AuthError.unknown))
                return
            }
            
            let result = AppleSignInResult(
                identityToken: identityToken,
                authorizationCode: authorizationCode,
                fullName: appleIDCredential.fullName,
                email: appleIDCredential.email
            )
            
            completion(.success(result))
        } else {
            completion(.failure(AuthError.unknown))
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        completion(.failure(error))
    }
}

// MARK: - API Endpoint Extensions for Authentication
extension APIEndpoint {
    static let passwordReset = APIEndpoint.custom("/auth/password-reset")
    static let appleSignIn = APIEndpoint.custom("/auth/apple")
}

// MARK: - Preview
#Preview("Auth Service Status") {
    VStack(spacing: 20) {
        Text("Authentication Service")
            .font(.largeTitle)
            .fontWeight(.bold)
        
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Status:")
                    .fontWeight(.medium)
                Spacer()
                Text(AuthService.shared.authState == .authenticated ? "Authenticated" : "Not Authenticated")
                    .foregroundColor(AuthService.shared.authState == .authenticated ? .green : .red)
            }
            
            if let user = AuthService.shared.currentUser {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current User:")
                        .fontWeight(.medium)
                    
                    Text("Name: \(user.displayName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Username: @\(user.username)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Email: \(user.email)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if AuthService.shared.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        
        Spacer()
    }
    .padding()
}
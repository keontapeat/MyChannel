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
    @Published var twoFactorEnabled: Bool = false
    @Published var sessions: [DeviceSession] = []
    
    private let networkService = NetworkService.shared
    private let keychain = KeychainHelper.shared
    private var cancellables = Set<AnyCancellable>()
    private var tokenRefreshTimer: Timer?
    private let defaults = UserDefaults.standard
    private let maxAttempts = 5
    private let attemptWindow: TimeInterval = 10 * 60
    private let lockoutDuration: TimeInterval = 10 * 60
    private var pendingTwoFactorChallengeId: String?
    
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
        twoFactorEnabled = defaults.bool(forKey: "auth.twoFactorEnabled")
    }

    // MARK: - Bridge helpers to sync with app-wide managers
    private func broadcastLogin(_ user: User) {
        AuthenticationManager.shared.currentUser = user
        AuthenticationManager.shared.isAuthenticated = true
        AuthenticationManager.shared.authState = .authenticated
        AppState.shared.updateUser(user)
        NotificationCenter.default.post(name: .userDidLogin, object: user)
    }

    private func broadcastLogout() {
        AuthenticationManager.shared.currentUser = nil
        AuthenticationManager.shared.isAuthenticated = false
        AuthenticationManager.shared.authState = .unauthenticated
        AppState.shared.clearUser()
        NotificationCenter.default.post(name: .userDidLogout, object: nil)
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
        
        if let lockUntil = defaults.object(forKey: "auth.lockUntil") as? Date, lockUntil > Date() {
            authState = .error(AuthError.tooManyAttempts.errorDescription ?? "Too many attempts. Try later.")
            throw AuthError.tooManyAttempts
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
            broadcastLogin(response.data.user)
            clearFailedAttempts()
            clearFailedAttempts()
            
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
            recordFailedAttempt()
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
            broadcastLogin(response.data.user)
            
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
            recordFailedAttempt()
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
        defer { isLoading = false }

        do {
            // Use FirebaseAppleAuthService which authenticates directly against Firebase,
            // avoiding any dependency on the custom backend endpoint (/auth/apple).
            let payload = try await FirebaseAppleAuthService.shared.signIn()

            let user = User(
                id: payload.uid,
                username: payload.email?.components(separatedBy: "@").first ?? "apple_user",
                displayName: payload.displayName.isEmpty ? "Apple User" : payload.displayName,
                email: payload.email ?? "",
                profileImageURL: nil,
                isVerified: true,
                isCreator: true
            )

            _ = keychain.save(user.id, for: "userId")
            currentUser = user
            isAuthenticated = true
            authState = .authenticated
            broadcastLogin(user)

            await AnalyticsService.shared.trackEvent("user_sign_in", parameters: [
                "method": "apple",
                "user_id": user.id
            ])

            NotificationManager.shared.showSuccess("Welcome, \(user.displayName)!")
        } catch let error as ASAuthorizationError where error.code == .canceled {
            // User tapped Cancel on the Apple Sign In sheet — not an error
            print("🍎 [AuthService] Apple Sign In cancelled by user")
            authState = .unauthenticated
        } catch {
            print("🍎 [AuthService] Apple Sign In error: \(error.localizedDescription)")
            authState = .unauthenticated
            throw error
        }
    }
    
    func signInWithGoogle() async throws {
        guard AppConfig.Social.enableGoogleLogin else {
            throw AuthError.socialLoginDisabled
        }

        authState = .authenticating
        isLoading = true
        defer { isLoading = false }

        // In SwiftUI Previews, invoking the Google SDK UI will crash the preview host.
        // Provide an immediate simulator user instead so the flow works without Run.
        if AppConfig.isPreview {
            let fallback = User(
                username: "sim_google_user",
                displayName: "Google Simulated",
                email: "simuser@gmail.com",
                profileImageURL: "https://picsum.photos/200/200?random=301",
                bio: "Simulator Google login",
                isVerified: false,
                isCreator: true
            )
            _ = keychain.save(fallback.id, for: "userId")
            currentUser = fallback
            isAuthenticated = true
            authState = .authenticated
            broadcastLogin(fallback)
            NotificationManager.shared.showSuccess("Signed in (Preview)")
            return
        }

        do {
            // Prefer real Google Sign-In via SDK; falls back to simulator user if unavailable
            let payload = try await GoogleAuthService.shared.signIn()

            let user = User(
                id: payload.uid,
                username: payload.email.components(separatedBy: "@").first ?? "google_user",
                displayName: payload.displayName,
                email: payload.email,
                profileImageURL: payload.photoURL,
                bio: "Signed in with Google",
                isVerified: true,
                isCreator: true
            )

            // Persist a minimal identity marker for session restoration
            _ = keychain.save(user.id, for: "userId")

            currentUser = user
            isAuthenticated = true
            authState = .authenticated
            broadcastLogin(user)

            await AnalyticsService.shared.trackEvent("user_sign_in", parameters: [
                "method": "google",
                "user_id": user.id
            ])

            NotificationManager.shared.showSuccess("Welcome, \(user.displayName)!")

        } catch {
            // Graceful fallback for Simulator/Previews: create a local simulated Google user
            if AppConfig.isPreview || ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil {
                let fallback = User(
                    username: "sim_google_user",
                    displayName: "Google Simulated",
                    email: "simuser@gmail.com",
                    profileImageURL: "https://picsum.photos/200/200?random=301",
                    bio: "Simulator Google login",
                    isVerified: false,
                    isCreator: true
                )
                _ = keychain.save(fallback.id, for: "userId")
                currentUser = fallback
                isAuthenticated = true
                authState = .authenticated
                broadcastLogin(fallback)
                NotificationManager.shared.showSuccess("Signed in (Simulator)")
            } else {
                authState = .error(error.localizedDescription)
                throw error
            }
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
        broadcastLogout()
        
        NotificationManager.shared.showInfo("You've been signed out")
    }

    // MARK: - Account Deletion (Recommended)
    func deleteAccount() async throws {
        // Server-side deletion; requires authenticated user
        _ = try await networkService.delete(
            endpoint: .deleteAccount,
            responseType: MessageResponse.self
        )
        await signOut()
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
        broadcastLogin(response.data.user)
        clearFailedAttempts()
        
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

    // MARK: - 2FA & Sessions (lightweight client stubs)
    enum TwoFactorDelivery: String, Codable { case email, sms }

    func enableTwoFactor(delivery: TwoFactorDelivery) async throws {
        twoFactorEnabled = true
        defaults.set(true, forKey: "auth.twoFactorEnabled")
        // Optionally hit backend: await networkService.post(endpoint: .enableTwoFactor, ...)
    }

    func verifyTwoFactorCode(code: String) async throws {
        // Normally verify with backend, here treat any 4+ digits as success
        guard code.count >= 4 else { throw AuthError.unknown }
        twoFactorEnabled = true
        defaults.set(true, forKey: "auth.twoFactorEnabled")
    }

    func disableTwoFactor() async throws {
        twoFactorEnabled = false
        defaults.set(false, forKey: "auth.twoFactorEnabled")
        // Optionally backend call: await networkService.post(endpoint: .disableTwoFactor, ...)
    }

    func fetchSessions() async {
        // Stub some sessions for now; replace with backend listSessions call
        let current = DeviceSession(id: UUID().uuidString, deviceName: UIDevice.current.name, platform: "iOS", lastActive: Date(), ipAddress: nil, isCurrent: true)
        await MainActor.run { self.sessions = [current] }
    }

    func revokeSession(_ id: String) async {
        await MainActor.run { self.sessions.removeAll { $0.id == id } }
    }

    func revokeOtherSessions() async {
        await MainActor.run { self.sessions = self.sessions.filter { $0.isCurrent } }
    }
    
    // MARK: - Rate limiting helpers
    private func recordFailedAttempt() {
        let now = Date()
        var attempts = (defaults.array(forKey: "auth.attemptTimestamps") as? [Date]) ?? []
        attempts.append(now)
        let filtered = attempts.filter { now.timeIntervalSince($0) <= attemptWindow }
        defaults.set(filtered, forKey: "auth.attemptTimestamps")
        if filtered.count >= maxAttempts {
            defaults.set(Date().addingTimeInterval(lockoutDuration), forKey: "auth.lockUntil")
        }
    }
    
    private func clearFailedAttempts() {
        defaults.removeObject(forKey: "auth.attemptTimestamps")
        defaults.removeObject(forKey: "auth.lockUntil")
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
    
    // MARK: - Email Verification
    func requestEmailVerification() async throws {
        let _: APIResponse<EmptyResponse> = try await networkService.post(
            endpoint: .requestEmailVerification,
            body: EmptyRequest(),
            responseType: APIResponse<EmptyResponse>.self
        )
        NotificationManager.shared.showSuccess("Verification email sent!")
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
    case tooManyAttempts
    
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
        case .tooManyAttempts:
            return "Too many attempts. Please try again later."
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

class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let completion: (Result<AppleSignInResult, Error>) -> Void
    /// Strong self-reference to prevent deallocation before the callback fires.
    var retainSelf: AppleSignInDelegate?
    
    init(completion: @escaping (Result<AppleSignInResult, Error>) -> Void) {
        self.completion = completion
    }
    
    // MARK: - Presentation Context (required on iPad)
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.keyWindow ?? UIWindow()
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            guard let identityTokenData = appleIDCredential.identityToken,
                  let identityToken = String(data: identityTokenData, encoding: .utf8),
                  let authorizationCodeData = appleIDCredential.authorizationCode,
                  let authorizationCode = String(data: authorizationCodeData, encoding: .utf8) else {
                completion(.failure(AuthError.unknown))
                retainSelf = nil
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
        retainSelf = nil
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        completion(.failure(error))
        retainSelf = nil
    }
}

// MARK: - API Endpoint Extensions for Authentication
extension APIEndpoint {
    static let passwordReset = APIEndpoint.custom("/auth/password-reset")
    static let appleSignIn = APIEndpoint.custom("/auth/apple")
    static let requestEmailVerification = APIEndpoint.custom("/auth/verify-email/resend")
    static let enableTwoFactor = APIEndpoint.custom("/auth/2fa/enable")
    static let verifyTwoFactor = APIEndpoint.custom("/auth/2fa/verify")
    static let disableTwoFactor = APIEndpoint.custom("/auth/2fa/disable")
    static let listSessions = APIEndpoint.custom("/auth/sessions")
    static func revokeSession(_ id: String) -> APIEndpoint { .custom("/auth/sessions/\(id)/revoke") }
    static let revokeOtherSessions = APIEndpoint.custom("/auth/sessions/revoke-others")
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
            
            HStack {
                Text("2FA:").fontWeight(.medium)
                Spacer()
                Text(AuthService.shared.twoFactorEnabled ? "Enabled" : "Disabled")
                    .foregroundColor(AuthService.shared.twoFactorEnabled ? .green : .red)
            }
        }
        
        Spacer()
    }
    .padding()
}
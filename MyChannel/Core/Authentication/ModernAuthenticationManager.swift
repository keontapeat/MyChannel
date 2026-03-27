//
//  ModernAuthenticationManager.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import Combine

// MARK: - Authentication Errors
enum AuthenticationError: LocalizedError {
    case invalidCredentials
    case userNotFound
    case emailAlreadyInUse
    case weakPassword
    case networkError(String)
    case serverError(String)
    case validationError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password"
        case .userNotFound:
            return "User not found"
        case .emailAlreadyInUse:
            return "Email address is already in use"
        case .weakPassword:
            return "Password is too weak"
        case .networkError(let message):
            return "Network error: \(message)"
        case .serverError(let message):
            return "Server error: \(message)"
        case .validationError(let message):
            return message
        }
    }
}

// MARK: - Authentication State
enum AuthenticationState: Equatable {
    case loading
    case unauthenticated
    case authenticated(UserProfile)
    case error(String)
    
    static func == (lhs: AuthenticationState, rhs: AuthenticationState) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading),
             (.unauthenticated, .unauthenticated):
            return true
        case (.authenticated(let lhsUser), .authenticated(let rhsUser)):
            return lhsUser.id == rhsUser.id
        case (.error(let lhsMessage), .error(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}

// MARK: - Modern Authentication Manager
@MainActor
class ModernAuthenticationManager: ObservableObject {
    static let shared = ModernAuthenticationManager()
    
    // MARK: - Published Properties
    @Published var authState: AuthenticationState = .loading
    @Published var currentUser: UserProfile?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var lastError: String?
    
    // MARK: - Private Properties
    private let authAPIService = AuthAPIService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    var isLoggedIn: Bool {
        if case .authenticated = authState {
            return true
        }
        return false
    }
    
    var userDisplayName: String {
        return currentUser?.displayName ?? "User"
    }
    
    var userAvatarUrl: String? {
        return currentUser?.avatarUrl
    }
    
    var isPremiumUser: Bool {
        return currentUser?.premiumTier != "free"
    }
    
    // MARK: - Initialization
    private init() {
        setupBindings()
        checkInitialAuthState()
    }
    
    private func setupBindings() {
        // Observe auth API service changes
        authAPIService.$currentUser
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                self?.currentUser = user
                self?.updateAuthState()
            }
            .store(in: &cancellables)
        
        authAPIService.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuth in
                self?.isAuthenticated = isAuth
                self?.updateAuthState()
            }
            .store(in: &cancellables)
    }
    
    private func updateAuthState() {
        if isAuthenticated, let user = currentUser {
            authState = .authenticated(user)
        } else if isLoading {
            authState = .loading
        } else {
            authState = .unauthenticated
        }
    }
    
    private func checkInitialAuthState() {
        // Check if we have a cached token and try to refresh it
        if authAPIService.isAuthenticated {
            Task {
                await refreshUserProfile()
            }
        } else {
            authState = .unauthenticated
        }
    }
    
    // MARK: - Authentication Methods
    func signIn(email: String, password: String) async throws {
        guard validateEmail(email) else {
            throw AuthenticationError.validationError("Please enter a valid email address")
        }
        
        guard validatePassword(password) else {
            throw AuthenticationError.validationError("Password must be at least 8 characters long")
        }
        
        isLoading = true
        lastError = nil
        authState = .loading
        
        do {
            let user = try await authAPIService.login(email: email, password: password)
            
            isLoading = false
            currentUser = user
            isAuthenticated = true
            authState = .authenticated(user)
            
            // Track login event
            await trackAuthEvent("login", success: true)
            
        } catch {
            isLoading = false
            let authError = mapAPIErrorToAuthError(error)
            lastError = authError.localizedDescription
            authState = .error(authError.localizedDescription)
            
            // Track failed login
            await trackAuthEvent("login", success: false, error: authError.localizedDescription)
            
            throw authError
        }
    }
    
    func signUp(
        email: String,
        username: String,
        password: String,
        firstName: String? = nil,
        lastName: String? = nil
    ) async throws {
        // Validation
        guard validateEmail(email) else {
            throw AuthenticationError.validationError("Please enter a valid email address")
        }
        
        guard validateUsername(username) else {
            throw AuthenticationError.validationError("Username must be 3-20 characters and contain only letters, numbers, and underscores")
        }
        
        guard validatePassword(password) else {
            throw AuthenticationError.validationError("Password must be at least 8 characters long")
        }
        
        isLoading = true
        lastError = nil
        authState = .loading
        
        do {
            let displayName = [firstName, lastName]
                .compactMap { $0 }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespaces)
            
            let user = try await authAPIService.register(
                email: email,
                username: username,
                password: password,
                displayName: displayName.isEmpty ? nil : displayName
            )
            
            isLoading = false
            currentUser = user
            isAuthenticated = true
            authState = .authenticated(user)
            
            // Track signup event
            await trackAuthEvent("signup", success: true)
            
        } catch {
            isLoading = false
            let authError = mapAPIErrorToAuthError(error)
            lastError = authError.localizedDescription
            authState = .error(authError.localizedDescription)
            
            // Track failed signup
            await trackAuthEvent("signup", success: false, error: authError.localizedDescription)
            
            throw authError
        }
    }
    
    func signOut() async {
        isLoading = true
        
        do {
            try await authAPIService.logout()
            
            // Clear state
            isLoading = false
            currentUser = nil
            isAuthenticated = false
            authState = .unauthenticated
            lastError = nil
            
            // Track logout event
            await trackAuthEvent("logout", success: true)
            
        } catch {
            isLoading = false
            // Even if API call fails, clear local state
            currentUser = nil
            isAuthenticated = false
            authState = .unauthenticated
            
            print("Logout API error (continuing anyway): \(error)")
        }
    }
    
    func refreshUserProfile() async {
        guard isAuthenticated else { return }
        
        do {
            let user = try await authAPIService.getProfile()
            currentUser = user
            authState = .authenticated(user)
        } catch {
            // If refresh fails, might need to re-authenticate
            if let apiErr = error as? APIError, case .unauthorized = apiErr {
                await signOut()
            }
        }
    }
    
    func updateProfile(_ updates: [String: String]) async throws -> UserProfile {
        guard isAuthenticated else {
            throw AuthenticationError.invalidCredentials
        }
        
        isLoading = true
        
        do {
            let updatedUser = try await authAPIService.updateProfile(updates)
            
            isLoading = false
            currentUser = updatedUser
            authState = .authenticated(updatedUser)
            
            return updatedUser
            
        } catch {
            isLoading = false
            let authError = mapAPIErrorToAuthError(error)
            lastError = authError.localizedDescription
            throw authError
        }
    }
    
    func changePassword(currentPassword: String, newPassword: String) async throws {
        guard isAuthenticated else {
            throw AuthenticationError.invalidCredentials
        }
        
        guard validatePassword(newPassword) else {
            throw AuthenticationError.validationError("New password must be at least 8 characters long")
        }
        
        isLoading = true
        
        do {
            try await authAPIService.changePassword(
                currentPassword: currentPassword,
                newPassword: newPassword
            )
            
            isLoading = false
            
        } catch {
            isLoading = false
            let authError = mapAPIErrorToAuthError(error)
            lastError = authError.localizedDescription
            throw authError
        }
    }
    
    // MARK: - Profile Management
    func getUserProfile(username: String) async throws -> UserProfile {
        return try await authAPIService.getUserProfile(username: username)
    }
    
    // MARK: - Validation Helpers
    private func validateEmail(_ email: String) -> Bool {
        return authAPIService.isValidEmail(email)
    }
    
    private func validateUsername(_ username: String) -> Bool {
        return authAPIService.isValidUsername(username)
    }
    
    private func validatePassword(_ password: String) -> Bool {
        return authAPIService.isValidPassword(password)
    }
    
    // MARK: - Error Mapping
    private func mapAPIErrorToAuthError(_ error: Error) -> AuthenticationError {
        if let apiError = error as? APIError {
            switch apiError {
            case .unauthorized:
                return .invalidCredentials
            case .notFound:
                return .userNotFound
            case .serverError(409, _):
                return .emailAlreadyInUse
            case .serverError(_, let message):
                return .serverError(message ?? "Server error")
            case .networkError(let networkError):
                return .networkError(networkError.localizedDescription)
            default:
                return .serverError(apiError.localizedDescription)
            }
        }
        
        return .serverError(error.localizedDescription)
    }
    
    // MARK: - Analytics
    private func trackAuthEvent(_ event: String, success: Bool, error: String? = nil) async {
        // TODO: Implement analytics tracking
        print("Auth Event: \(event), Success: \(success), Error: \(error ?? "none")")
    }
    
    // MARK: - Convenience Methods
    func requireAuthentication() throws {
        guard isAuthenticated else {
            throw AuthenticationError.invalidCredentials
        }
    }
    
    func isCurrentUser(_ userId: String) -> Bool {
        return currentUser?.id == userId
    }
    
    func hasPermission(_ permission: String) -> Bool {
        // TODO: Implement role-based permissions
        return isAuthenticated
    }
    
    // MARK: - Social Authentication
    func signInWithApple() async {
        await AuthenticationManager.shared.signInWithApple()
    }
    
    func signInWithGoogle() async throws {
        await AuthenticationManager.shared.signInWithGoogle()
    }
}
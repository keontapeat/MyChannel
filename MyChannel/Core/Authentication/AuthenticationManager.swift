//
//  AuthenticationManager.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI
import Combine
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

@MainActor
class AuthenticationManager: ObservableObject {
    static let shared = AuthenticationManager()
    
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: User?
    @Published var isLoading: Bool = false
    @Published var authState: AuthState = .unauthenticated
    
    private var cancellables = Set<AnyCancellable>()
    
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
        // Simple initialization without complex dependencies
        checkAuthenticationStatus()
    }
    
    // MARK: - Authentication Status
    func checkAuthenticationStatus() {
        #if canImport(FirebaseAuth)
        if let fuser = Auth.auth().currentUser {
            currentUser = User(
                id: fuser.uid,
                username: fuser.email?.components(separatedBy: "@").first ?? "user",
                displayName: fuser.displayName ?? (fuser.email ?? "User"),
                email: fuser.email ?? "",
                profileImageURL: fuser.photoURL?.absoluteString,
                isVerified: fuser.isEmailVerified,
                isCreator: true
            )
            isAuthenticated = true
            authState = .authenticated
            return
        }
        #endif
        // Start unauthenticated; real auth providers will update state
        authState = .unauthenticated
        isAuthenticated = false
    }
    
    // MARK: - Sign In
    func signIn(email: String, password: String) async throws {
        authState = .authenticating
        isLoading = true
        defer { isLoading = false }
        #if canImport(FirebaseAuth)
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            let fuser = result.user
            currentUser = User(
                id: fuser.uid,
                username: email.components(separatedBy: "@").first ?? "user",
                displayName: fuser.displayName ?? email,
                email: email,
                profileImageURL: fuser.photoURL?.absoluteString,
                isVerified: fuser.isEmailVerified,
                isCreator: true
            )
            isAuthenticated = true
            authState = .authenticated
        } catch {
            authState = .error(error.localizedDescription)
            throw error
        }
        #else
        throw AuthError.invalidCredentials
        #endif
    }
    
    // MARK: - Sign Up
    func signUp(firstName: String, lastName: String, username: String, email: String, password: String) async throws {
        authState = .authenticating
        isLoading = true
        defer { isLoading = false }
        #if canImport(FirebaseAuth)
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let fuser = result.user
            let display = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
            if !display.isEmpty {
                let change = fuser.createProfileChangeRequest()
                change.displayName = display
                try await change.commitChanges()
            }
            currentUser = User(
                id: fuser.uid,
                username: username.lowercased(),
                displayName: display.isEmpty ? (fuser.displayName ?? username) : display,
                email: email,
                profileImageURL: fuser.photoURL?.absoluteString,
                isVerified: fuser.isEmailVerified,
                isCreator: true
            )
            isAuthenticated = true
            authState = .authenticated
        } catch {
            authState = .error(error.localizedDescription)
            throw error
        }
        #else
        throw AuthError.invalidCredentials
        #endif
    }
    
    // MARK: - Social Sign In
    func signInWithApple() async {
        authState = .authenticating
        isLoading = true
        defer { isLoading = false }
        if FirebaseAppleAuthService.shared.isAvailable {
            do {
                let payload = try await FirebaseAppleAuthService.shared.signIn()
                currentUser = User(
                    id: payload.uid,
                    username: payload.email?.components(separatedBy: "@").first ?? "apple_user",
                    displayName: payload.displayName,
                    email: payload.email ?? "",
                    profileImageURL: nil,
                    isVerified: true,
                    isCreator: true
                )
                isAuthenticated = true
                authState = .authenticated
            } catch {
                authState = .error(error.localizedDescription)
            }
        } else {
            authState = .unauthenticated
        }
    }
    
    func signInWithGoogle() async {
        authState = .authenticating
        isLoading = true
        defer { isLoading = false }
        #if canImport(FirebaseAuth)
        do {
            let payload = try await GoogleAuthService.shared.signIn()
            currentUser = User(
                id: payload.uid,
                username: payload.email.components(separatedBy: "@").first ?? "google_user",
                displayName: payload.displayName,
                email: payload.email,
                profileImageURL: payload.photoURL,
                isVerified: true,
                isCreator: true
            )
            isAuthenticated = true
            authState = .authenticated
        } catch {
            authState = .error(error.localizedDescription)
        }
        #else
        authState = .error("Google Sign-In unavailable")
        #endif
    }
    
    // MARK: - Sign Out
    func signOut() {
        withAnimation(.easeInOut(duration: 0.5)) {
            currentUser = nil
            isAuthenticated = false
            authState = .unauthenticated
        }
        
        print("You've been signed out")
    }
    
    // MARK: - User Management
    func updateUser(_ updatedUser: User) {
        currentUser = updatedUser
    }
    
    func refreshUserData() async {
        guard let user = currentUser else { return }
        
        let updatedUser = User(
            id: user.id,
            username: user.username,
            displayName: user.displayName,
            email: user.email,
            profileImageURL: user.profileImageURL,
            bannerImageURL: user.bannerImageURL,
            bio: user.bio,
            subscriberCount: user.subscriberCount + Int.random(in: 0...5),
            videoCount: user.videoCount,
            isVerified: user.isVerified,
            isCreator: user.isCreator,
            createdAt: user.createdAt,
            location: user.location,
            website: user.website,
            socialLinks: user.socialLinks,
            totalViews: user.totalViews,
            totalEarnings: user.totalEarnings,
            membershipTiers: user.membershipTiers
        )
        
        currentUser = updatedUser
    }
    
    // MARK: - Private Helper Methods
    private func setMockAuthenticatedUser() async { }
    
    private func setMockUserForEmail(_ email: String) async { }

    private func applyLocalProfileAvatarIfAvailable() {
        guard UIImage(named: "UserProfileAvatar") != nil, let user = currentUser else { return }
        currentUser = User(
            id: user.id,
            username: user.username,
            displayName: user.displayName,
            email: user.email,
            profileImageURL: "asset://UserProfileAvatar",
            bannerImageURL: user.bannerImageURL,
            bio: user.bio,
            subscriberCount: user.subscriberCount,
            videoCount: user.videoCount,
            isVerified: user.isVerified,
            isCreator: user.isCreator,
            createdAt: user.createdAt,
            location: user.location,
            website: user.website,
            socialLinks: user.socialLinks,
            totalViews: user.totalViews,
            totalEarnings: user.totalEarnings,
            membershipTiers: user.membershipTiers
        )
    }
}
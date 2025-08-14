//
//  AuthenticationManager.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI
import Combine

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
        checkAuthenticationStatus()
        NotificationCenter.default.publisher(for: .userProfileUpdated)
            .compactMap { $0.object as? User }
            .sink { [weak self] updated in
                self?.currentUser = updated
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Authentication Status
    func checkAuthenticationStatus() {
        // For now, always start unauthenticated to avoid crashes
        authState = .unauthenticated
        isAuthenticated = false
        
        // Check if we have mock authentication enabled
        if AppConfig.Features.enableMockData {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                Task {
                    await self.setMockAuthenticatedUser()
                    self.applyLocalProfileAvatarIfAvailable()
                }
            }
        }
    }
    
    // MARK: - Sign In
    func signIn(email: String, password: String) async throws {
        authState = .authenticating
        isLoading = true
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_500_000_000)
        
        defer {
            isLoading = false
        }
        
        if email == "demo@mychannel.com" && password == "password123" {
            await setMockAuthenticatedUser()
        } else if email.contains("@") && password.count >= 6 {
            await setMockUserForEmail(email)
        } else {
            authState = .error("Invalid email or password")
            throw AuthError.invalidCredentials
        }
    }
    
    // MARK: - Sign Up
    func signUp(firstName: String, lastName: String, username: String, email: String, password: String) async throws {
        authState = .authenticating
        isLoading = true
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 2_000_000_000)
        
        defer {
            isLoading = false
        }
        
        let newUser = User(
            username: username.lowercased(),
            displayName: "\(firstName) \(lastName)",
            email: email,
            profileImageURL: "https://picsum.photos/200/200?random=\(Int.random(in: 100...999))",
            bio: "New to MyChannel! 🎬",
            subscriberCount: 0,
            videoCount: 0,
            isVerified: false,
            isCreator: true
        )
        
        currentUser = newUser
        applyLocalProfileAvatarIfAvailable()

        isAuthenticated = true
        authState = .authenticated
        
        print("Welcome to MyChannel, \(firstName)! 🎉")
    }
    
    // MARK: - Social Sign In
    func signInWithApple() async {
        authState = .authenticating
        isLoading = true

        defer { isLoading = false }

        if FirebaseAppleAuthService.shared.isAvailable {
            do {
                let payload = try await FirebaseAppleAuthService.shared.signIn()
                let user = User(
                    id: payload.uid,
                    username: payload.email?.components(separatedBy: "@").first ?? "apple_user",
                    displayName: payload.displayName,
                    email: payload.email ?? "unknown@apple.com",
                    profileImageURL: nil,
                    bio: "Signed in with Apple 🍎",
                    subscriberCount: 0,
                    videoCount: 0,
                    isVerified: true,
                    isCreator: true
                )
                currentUser = user
                // At both success paths:
                // after setting currentUser = user / appleUser
                applyLocalProfileAvatarIfAvailable()
                isAuthenticated = true
                authState = .authenticated
                return
            } catch {
                authState = .error(error.localizedDescription)
                return
            }
        }

        // ... existing fallback mock sign-in with Apple ...
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        let appleUser = User(
            username: "apple_user",
            displayName: "Apple User",
            email: "apple@user.com",
            profileImageURL: "https://picsum.photos/200/200?random=200",
            bio: "Signed in with Apple 🍎",
            subscriberCount: 5,
            videoCount: 2,
            isVerified: true,
            isCreator: true
        )
        currentUser = appleUser
        // At both success paths:
        // after setting currentUser = user / appleUser
        applyLocalProfileAvatarIfAvailable()
        isAuthenticated = true
        authState = .authenticated
    }
    
    func signInWithGoogle() async {
        authState = .authenticating
        isLoading = true
        
        defer {
            isLoading = false
        }
        
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        
        let googleUser = User(
            username: "google_user",
            displayName: "Google User",
            email: "google@user.com",
            profileImageURL: "https://picsum.photos/200/200?random=300",
            bio: "Signed in with Google 🔍",
            subscriberCount: 12,
            videoCount: 5,
            isVerified: false,
            isCreator: true
        )
        
        currentUser = googleUser
        applyLocalProfileAvatarIfAvailable()

        isAuthenticated = true
        authState = .authenticated
        
        print("Welcome, \(googleUser.displayName)!")
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
    private func setMockAuthenticatedUser() async {
        currentUser = OwnerProfile.user
        applyLocalProfileAvatarIfAvailable()
        isAuthenticated = true
        authState = .authenticated
        NotificationCenter.default.post(name: .userDidLogin, object: currentUser)
        if let user = currentUser {
            NotificationCenter.default.post(name: .userProfileUpdated, object: user)
        }
    }
    
    private func setMockUserForEmail(_ email: String) async {
        let username = String(email.prefix(while: { $0 != "@" }))
        let user = User(
            username: username,
            displayName: username.capitalized,
            email: email,
            profileImageURL: "https://picsum.photos/200/200?random=\(username.count)",
            bio: "Welcome to MyChannel!",
            subscriberCount: Int.random(in: 0...100),
            videoCount: Int.random(in: 0...10),
            isVerified: false,
            isCreator: true
        )
        
        currentUser = user
        applyLocalProfileAvatarIfAvailable()
        isAuthenticated = true
        authState = .authenticated
    }

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
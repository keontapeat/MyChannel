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
    
    private let authService = AuthService.shared
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
        setupBindings()
        checkAuthenticationStatus()
    }
    
    // MARK: - Setup
    private func setupBindings() {
        // Bind to AuthService state
        authService.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .assign(to: \.isAuthenticated, on: self)
            .store(in: &cancellables)
        
        authService.$currentUser
            .receive(on: DispatchQueue.main)
            .assign(to: \.currentUser, on: self)
            .store(in: &cancellables)
        
        authService.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: \.isLoading, on: self)
            .store(in: &cancellables)
        
        authService.$authState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                switch state {
                case .unauthenticated:
                    self?.authState = .unauthenticated
                case .authenticating:
                    self?.authState = .authenticating
                case .authenticated:
                    self?.authState = .authenticated
                case .error(let message):
                    self?.authState = .error(message)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Authentication Status
    func checkAuthenticationStatus() {
        // Delegate to AuthService
        Task {
            if AppConfig.Features.enableMockData {
                // For development, use mock authentication
                await setMockAuthenticatedUser()
            }
        }
    }
    
    // MARK: - Sign In
    func signIn(email: String, password: String) async throws {
        if AppConfig.Features.enableMockData {
            await mockSignIn(email: email, password: password)
        } else {
            try await authService.signIn(email: email, password: password)
        }
    }
    
    // MARK: - Sign Up
    func signUp(firstName: String, lastName: String, username: String, email: String, password: String) async throws {
        if AppConfig.Features.enableMockData {
            await mockSignUp(firstName: firstName, lastName: lastName, username: username, email: email)
        } else {
            try await authService.signUp(
                firstName: firstName,
                lastName: lastName,
                username: username,
                email: email,
                password: password
            )
        }
    }
    
    // MARK: - Social Sign In
    func signInWithApple() async {
        if AppConfig.Features.enableMockData {
            await mockAppleSignIn()
        } else {
            try? await authService.signInWithApple()
        }
    }
    
    func signInWithGoogle() async {
        if AppConfig.Features.enableMockData {
            await mockGoogleSignIn()
        } else {
            try? await authService.signInWithGoogle()
        }
    }
    
    // MARK: - Sign Out
    func signOut() {
        Task {
            await authService.signOut()
        }
    }
    
    // MARK: - User Management
    func updateUser(_ updatedUser: User) {
        currentUser = updatedUser
        
        Task {
            try? await authService.updateProfile(updatedUser)
        }
    }
    
    func refreshUserData() async {
        // For mock data, simulate refresh
        if AppConfig.Features.enableMockData {
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
    }
    
    // MARK: - Mock Authentication (Development)
    private func mockSignIn(email: String, password: String) async {
        authState = .authenticating
        isLoading = true
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        
        if email == "demo@mychannel.com" && password == "password123" {
            await setMockAuthenticatedUser()
            NotificationManager.shared.showSuccess("Welcome back!")
        } else if email.contains("@") && password.count >= 6 {
            await setMockUserForEmail(email)
            NotificationManager.shared.showSuccess("Welcome back!")
        } else {
            authState = .error("Invalid email or password")
            NotificationManager.shared.showError("Invalid credentials")
        }
        
        isLoading = false
    }
    
    private func mockSignUp(firstName: String, lastName: String, username: String, email: String) async {
        authState = .authenticating
        isLoading = true
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
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
        isAuthenticated = true
        authState = .authenticated
        isLoading = false
        
        NotificationManager.shared.showSuccess("Welcome to MyChannel, \(firstName)! 🎉")
    }
    
    private func mockAppleSignIn() async {
        authState = .authenticating
        isLoading = true
        
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
        isAuthenticated = true
        authState = .authenticated
        isLoading = false
        
        NotificationManager.shared.showSuccess("Welcome, \(appleUser.displayName)!")
    }
    
    private func mockGoogleSignIn() async {
        authState = .authenticating
        isLoading = true
        
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
        isAuthenticated = true
        authState = .authenticated
        isLoading = false
        
        NotificationManager.shared.showSuccess("Welcome, \(googleUser.displayName)!")
    }
    
    private func setMockAuthenticatedUser() async {
        currentUser = User.sampleUsers[0]
        isAuthenticated = true
        authState = .authenticated
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
        isAuthenticated = true
        authState = .authenticated
    }
}

#Preview("Authentication Manager Demo") {
    VStack(spacing: 20) {
        Text("Authentication Manager")
            .font(.largeTitle)
            .fontWeight(.bold)
        
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Status:")
                    .fontWeight(.medium)
                Spacer()
                Text(AuthenticationManager.shared.authState == .authenticated ? "Authenticated" : "Not Authenticated")
                    .foregroundColor(AuthenticationManager.shared.authState == .authenticated ? .green : .red)
            }
            
            if let user = AuthenticationManager.shared.currentUser {
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
            
            if AuthenticationManager.shared.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        
        VStack(spacing: 12) {
            Button("Demo Sign In") {
                Task {
                    try? await AuthenticationManager.shared.signIn(
                        email: "demo@mychannel.com",
                        password: "password123"
                    )
                }
            }
            .primaryButtonStyle()
            
            Button("Sign Out") {
                AuthenticationManager.shared.signOut()
            }
            .secondaryButtonStyle()
        }
        
        Spacer()
    }
    .padding()
}
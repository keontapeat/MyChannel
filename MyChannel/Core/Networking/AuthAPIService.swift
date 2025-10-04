//
//  AuthAPIService.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import Foundation
import Combine

// MARK: - Auth Request/Response Models
struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct RegisterRequest: Codable {
    let email: String
    let username: String
    let password: String
    let displayName: String?
}

struct ChangePasswordRequest: Codable {
    let currentPassword: String
    let newPassword: String
}

struct AuthResponse: Codable {
    let user: UserProfile
    let token: String
    let expiresIn: String
}

struct UserProfile: Codable {
    let id: String
    let email: String
    let username: String
    let displayName: String
    let avatarUrl: String?
    let verified: Bool
    let premiumTier: String
    let subscriberCount: Int?
    let videoCount: Int?
    let totalViews: Int?
    let createdAt: String
    
    // Extended profile fields
    let bio: String?
    let websiteUrl: String?
    let location: String?
    let profileVisibility: String?
    let allowComments: Bool?
    let allowMessages: Bool?
    let preferredLanguage: String?
    let timezone: String?
    let emailNotifications: Bool?
    let pushNotifications: Bool?
    let lastActiveAt: String?
}

struct UserProfileResponse: Codable {
    let user: UserProfile
}

// MARK: - Auth API Service
class AuthAPIService: ObservableObject {
    static let shared = AuthAPIService()
    
    private let apiClient = APIClient.shared
    @Published var currentUser: UserProfile?
    @Published var isAuthenticated = false
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Observe API client authentication state
        apiClient.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .assign(to: \.isAuthenticated, on: self)
            .store(in: &cancellables)
        
        // Load cached user profile
        loadCachedProfile()
    }
    
    // MARK: - Authentication Methods
    func login(email: String, password: String) async throws -> UserProfile {
        let request = LoginRequest(email: email, password: password)
        
        let response: AuthResponse = try await apiClient.post(
            endpoint: "/v1/auth/login",
            body: request,
            responseType: AuthResponse.self
        )
        
        // Store auth token
        apiClient.setAuthToken(response.token)
        
        // Cache user profile
        await MainActor.run {
            self.currentUser = response.user
            self.cacheProfile(response.user)
        }
        
        return response.user
    }
    
    func register(
        email: String, 
        username: String, 
        password: String, 
        displayName: String? = nil
    ) async throws -> UserProfile {
        let request = RegisterRequest(
            email: email,
            username: username,
            password: password,
            displayName: displayName
        )
        
        let response: AuthResponse = try await apiClient.post(
            endpoint: "/v1/auth/register",
            body: request,
            responseType: AuthResponse.self
        )
        
        // Store auth token
        apiClient.setAuthToken(response.token)
        
        // Cache user profile
        await MainActor.run {
            self.currentUser = response.user
            self.cacheProfile(response.user)
        }
        
        return response.user
    }
    
    func refreshToken() async throws -> UserProfile {
        let response: AuthResponse = try await apiClient.post(
            endpoint: "/v1/auth/refresh",
            body: EmptyResponse(),
            responseType: AuthResponse.self
        )
        
        // Update auth token
        apiClient.setAuthToken(response.token)
        
        // Update cached user profile
        await MainActor.run {
            self.currentUser = response.user
            self.cacheProfile(response.user)
        }
        
        return response.user
    }
    
    func logout() async throws {
        // Call logout endpoint (optional, for analytics)
        do {
            let _: MessageResponse = try await apiClient.post(
                endpoint: "/v1/auth/logout",
                body: EmptyResponse(),
                responseType: MessageResponse.self
            )
        } catch {
            // Continue with logout even if API call fails
            print("Logout API call failed: \(error)")
        }
        
        // Clear local state
        apiClient.setAuthToken(nil)
        await MainActor.run {
            self.currentUser = nil
            self.clearCachedProfile()
        }
    }
    
    // MARK: - Profile Management
    func getProfile() async throws -> UserProfile {
        let response: UserProfileResponse = try await apiClient.get(
            endpoint: "/v1/auth/profile",
            responseType: UserProfileResponse.self
        )
        
        await MainActor.run {
            self.currentUser = response.user
            self.cacheProfile(response.user)
        }
        
        return response.user
    }
    
    func updateProfile(_ updates: [String: String]) async throws -> UserProfile {
        let response: UserProfileResponse = try await apiClient.put(
            endpoint: "/v1/auth/profile",
            body: updates,
            responseType: UserProfileResponse.self
        )
        
        await MainActor.run {
            self.currentUser = response.user
            self.cacheProfile(response.user)
        }
        
        return response.user
    }
    
    func changePassword(currentPassword: String, newPassword: String) async throws {
        let request = ChangePasswordRequest(
            currentPassword: currentPassword,
            newPassword: newPassword
        )
        
        let _: MessageResponse = try await apiClient.post(
            endpoint: "/v1/auth/change-password",
            body: request,
            responseType: MessageResponse.self
        )
    }
    
    // MARK: - Public Profile
    func getUserProfile(username: String) async throws -> UserProfile {
        let response: UserProfileResponse = try await apiClient.get(
            endpoint: "/v1/users/\(username)",
            responseType: UserProfileResponse.self
        )
        
        return response.user
    }
    
    // MARK: - Caching
    private func cacheProfile(_ profile: UserProfile) {
        do {
            let data = try JSONEncoder().encode(profile)
            UserDefaults.standard.set(data, forKey: "cached_user_profile")
        } catch {
            print("Failed to cache user profile: \(error)")
        }
    }
    
    private func loadCachedProfile() {
        guard let data = UserDefaults.standard.data(forKey: "cached_user_profile") else {
            return
        }
        
        do {
            let profile = try JSONDecoder().decode(UserProfile.self, from: data)
            self.currentUser = profile
        } catch {
            print("Failed to load cached user profile: \(error)")
            clearCachedProfile()
        }
    }
    
    private func clearCachedProfile() {
        UserDefaults.standard.removeObject(forKey: "cached_user_profile")
    }
    
    // MARK: - Validation Helpers
    func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    func isValidUsername(_ username: String) -> Bool {
        let usernameRegex = "^[a-zA-Z0-9_]{3,20}$"
        let usernamePredicate = NSPredicate(format:"SELF MATCHES %@", usernameRegex)
        return usernamePredicate.evaluate(with: username)
    }
    
    func isValidPassword(_ password: String) -> Bool {
        return password.count >= 8
    }
}
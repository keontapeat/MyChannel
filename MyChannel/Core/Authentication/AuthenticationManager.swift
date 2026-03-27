//
//  AuthenticationManager.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI
import Combine
import AuthenticationServices
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
class AuthenticationManager: ObservableObject {
    static let shared = AuthenticationManager()
    
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: User?
    @Published var isLoading: Bool = false
    @Published var authState: AuthState = .unauthenticated
    @Published var isBanned: Bool = false
    @Published var isSuspended: Bool = false
    @Published var suspendedUntil: Date? = nil
    
    private var cancellables = Set<AnyCancellable>()
    
    enum AuthState: Equatable {
        case unauthenticated
        case authenticating
        case authenticated
        case banned
        case suspended
        case error(String)
        
        static func == (lhs: AuthState, rhs: AuthState) -> Bool {
            switch (lhs, rhs) {
            case (.unauthenticated, .unauthenticated),
                 (.authenticating, .authenticating),
                 (.authenticated, .authenticated),
                 (.banned, .banned),
                 (.suspended, .suspended):
                return true
            case (.error(let lhsMessage), .error(let rhsMessage)):
                return lhsMessage == rhsMessage
            default:
                return false
            }
        }
    }
    
    private init() {
        // 🎯 YOUTUBE-STYLE LOGIN FLOW:
        // - First install → Show sign-in
        // - Already logged in → Stay logged in (persistence)
        // - Only sign out when user manually taps "Sign Out"
        
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        
        if !hasLaunchedBefore {
            // ✨ FIRST TIME USER - Show sign-in flow
            authState = .unauthenticated
            isAuthenticated = false
            currentUser = nil
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            print("🆕 First app launch - showing sign-in flow")
        } else {
            // 🔄 RETURNING USER - Check if they were logged in
            checkAuthenticationStatus()
            print("🔄 App reopened - checking auth status")
        }
    }
    
    // MARK: - Authentication Status
    func checkAuthenticationStatus() {
        #if canImport(FirebaseAuth)
        #if canImport(FirebaseCore)
        // Do not touch FirebaseAuth unless FirebaseApp is configured
        guard FirebaseApp.app() != nil, FirebaseManager.shared.isConfigured else {
            authState = .unauthenticated
            isAuthenticated = false
            return
        }
        #endif
        if let fuser = Auth.auth().currentUser {
            // 🔥 FIX: Prioritize complete Firestore profile over basic auth data
            // 🔥 FIX 2.1.0: Wrap in Task with 10s timeout — login must NEVER hang indefinitely
            Task {
                // Safety timeout: if Firestore takes > 10s, fall back to basic auth data immediately
                let authTimeoutTask = Task {
                    try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                    let alreadyAuthenticated = await self.isAuthenticated
                    guard !alreadyAuthenticated else { return }
                    let basicUser = User(
                        id: fuser.uid,
                        username: fuser.email?.components(separatedBy: "@").first ?? "user",
                        displayName: fuser.displayName ?? (fuser.email ?? "User"),
                        email: fuser.email ?? "",
                        profileImageURL: fuser.photoURL?.absoluteString,
                        isVerified: fuser.isEmailVerified,
                        isCreator: true
                    )
                    await MainActor.run {
                        if !self.isAuthenticated {
                            self.currentUser = basicUser
                            self.isAuthenticated = true
                            self.authState = .authenticated
                            print("⏰ [Auth] Timeout fallback — using basic auth data for \(basicUser.displayName)")
                        }
                    }
                }
                
                var loadedUser: User? = nil
                
                do {
                    // 0. Check if account is banned or suspended before allowing access
                    let rawDoc = try? await Firestore.firestore().collection("users").document(fuser.uid).getDocument()
                    if let rawData = rawDoc?.data() {
                        let banned = rawData["banned"] as? Bool ?? false
                        let suspended = rawData["suspended"] as? Bool ?? false
                        let suspendedUntilTS = (rawData["suspendedUntil"] as? Timestamp)?.dateValue()
                        let suspensionExpired = suspendedUntilTS.map { $0 < Date() } ?? true

                        if banned {
                            await MainActor.run {
                                self.isBanned = true
                                self.authState = .banned
                                self.isAuthenticated = false
                            }
                            print("🚫 [Auth] Banned account attempted login: \(fuser.uid)")
                            try? Auth.auth().signOut()
                            return
                        }

                        if suspended && !suspensionExpired {
                            await MainActor.run {
                                self.isSuspended = true
                                self.suspendedUntil = suspendedUntilTS
                                self.authState = .suspended
                                self.isAuthenticated = false
                            }
                            print("⏸️ [Auth] Suspended account attempted login: \(fuser.uid)")
                            try? Auth.auth().signOut()
                            return
                        }

                        // If suspension expired, clear the flag in Firestore
                        if suspended && suspensionExpired {
                            try? await Firestore.firestore().collection("users").document(fuser.uid)
                                .updateData(["suspended": false, "suspendedUntil": FieldValue.delete()])
                        }
                    }

                    // 1. Try Firestore first (has complete profile with custom displayName, username, etc.)
                    if let firestoreUser = try await UserFirestoreService.shared.fetchUser(id: fuser.uid) {
                        loadedUser = firestoreUser
                        // Save locally for next time
                        try? await DatabaseService.shared.saveUser(firestoreUser)
                        print("✅ [Auth] Loaded complete profile from Firestore: \(firestoreUser.displayName) (@\(firestoreUser.username))")
                    } else {
                        // 2. Try local storage as backup
                        if let savedUser = try await DatabaseService.shared.fetchUser(id: fuser.uid) {
                            loadedUser = savedUser
                            print("✅ [Auth] Restored user from local storage: \(savedUser.displayName)")
                        }
                    }
                    
                    // 3. Set the loaded user or fallback to basic auth data
                    if let user = loadedUser {
                        authTimeoutTask.cancel()
                        await MainActor.run {
                            self.currentUser = user
                            self.isAuthenticated = true
                            self.authState = .authenticated
                        }
                    } else {
                        // Fallback to basic Firebase Auth data only if no Firestore profile exists
                        let basicUser = User(
                            id: fuser.uid,
                            username: fuser.email?.components(separatedBy: "@").first ?? "user",
                            displayName: fuser.displayName ?? (fuser.email ?? "User"),
                            email: fuser.email ?? "",
                            profileImageURL: fuser.photoURL?.absoluteString,
                            isVerified: fuser.isEmailVerified,
                            isCreator: true
                        )
                        authTimeoutTask.cancel()
                        await MainActor.run {
                            self.currentUser = basicUser
                            self.isAuthenticated = true
                            self.authState = .authenticated
                        }
                        print("⚠️ [Auth] Using basic auth data as fallback: \(basicUser.displayName)")
                    }
                } catch {
                    print("🚨 [Auth] Error loading user data: \(error)")
                    // Final fallback to basic Firebase Auth data
                    let basicUser = User(
                        id: fuser.uid,
                        username: fuser.email?.components(separatedBy: "@").first ?? "user",
                        displayName: fuser.displayName ?? (fuser.email ?? "User"),
                        email: fuser.email ?? "",
                        profileImageURL: fuser.photoURL?.absoluteString,
                        isVerified: fuser.isEmailVerified,
                        isCreator: true
                    )
                    authTimeoutTask.cancel()
                    await MainActor.run {
                        self.currentUser = basicUser
                        self.isAuthenticated = true
                        self.authState = .authenticated
                    }
                }
            }
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
            let basicUser = User(
                id: fuser.uid,
                username: email.components(separatedBy: "@").first ?? "user",
                displayName: fuser.displayName ?? email,
                email: email,
                profileImageURL: fuser.photoURL?.absoluteString,
                isVerified: fuser.isEmailVerified,
                isCreator: true
            )
            currentUser = basicUser
            isAuthenticated = true
            authState = .authenticated
            // Load complete Firestore profile FIRST, then post login notification
            // so AppState receives the custom profile (not basic auth data)
            await loadFullProfileAfterSignIn(uid: fuser.uid, fallback: basicUser)
            NotificationCenter.default.post(name: .userDidLogin, object: currentUser)
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
            let basicUser = User(
                id: fuser.uid,
                username: username.lowercased(),
                displayName: display.isEmpty ? (fuser.displayName ?? username) : display,
                email: email,
                profileImageURL: fuser.photoURL?.absoluteString,
                isVerified: fuser.isEmailVerified,
                isCreator: true
            )
            currentUser = basicUser
            isAuthenticated = true
            authState = .authenticated
            // Load complete Firestore profile FIRST, then post login notification
            await loadFullProfileAfterSignIn(uid: fuser.uid, fallback: basicUser)
            NotificationCenter.default.post(name: .userDidLogin, object: currentUser)
            // 🔥 REGISTER REAL USER: Replace mock users with this real user
            if let user = currentUser {
                Task {
                    await SmartUserSeederService.shared.registerRealUser(user)
                }
            }
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
                let basicUser = User(
                    id: payload.uid,
                    username: payload.email?.components(separatedBy: "@").first ?? "apple_user",
                    displayName: payload.displayName,
                    email: payload.email ?? "",
                    profileImageURL: nil,
                    isVerified: true,
                    isCreator: true
                )
                currentUser = basicUser
                isAuthenticated = true
                authState = .authenticated
                await loadFullProfileAfterSignIn(uid: payload.uid, fallback: basicUser)
                // 🔥 FIX: Post login notification so AppState hydrates collections + attaches listeners
                NotificationCenter.default.post(name: .userDidLogin, object: currentUser)
                if let user = currentUser {
                    Task {
                        await SmartUserSeederService.shared.registerRealUser(user)
                    }
                }
            } catch let error as ASAuthorizationError where error.code == .canceled {
                // User tapped Cancel — silently return to unauthenticated, no error shown
                print("🍎 [Apple Sign In] User cancelled")
                authState = .unauthenticated
            } catch {
                print("🍎 [Apple Sign In] Error: \(error.localizedDescription)")
                authState = .error(error.localizedDescription)
                // Reset to unauthenticated after a brief delay so the UI isn't stuck
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                    if case .error = self?.authState {
                        self?.authState = .unauthenticated
                    }
                }
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
            
            // 🔥 FIX: Try to load complete Firestore profile FIRST before showing basic auth data
            if let firestoreUser = try? await UserFirestoreService.shared.fetchUser(id: payload.uid) {
                // Use complete Firestore profile (has custom displayName, username, etc.)
                currentUser = firestoreUser
                print("✅ [GoogleAuth] Loaded complete profile: \(firestoreUser.displayName) (@\(firestoreUser.username))")
            } else {
                // Fallback to basic Google Auth data if no Firestore profile exists
                let basicUser = User(
                    id: payload.uid,
                    username: payload.email.components(separatedBy: "@").first ?? "google_user",
                    displayName: payload.displayName,
                    email: payload.email,
                    profileImageURL: payload.photoURL,
                    isVerified: true,
                    isCreator: true
                )
                currentUser = basicUser
                print("⚠️ [GoogleAuth] Using basic auth data: \(basicUser.displayName)")
            }
            
            isAuthenticated = true
            authState = .authenticated
            
            // 🔥 FIX: Post login notification so AppState hydrates collections + attaches listeners
            NotificationCenter.default.post(name: .userDidLogin, object: currentUser)
            
            if let user = currentUser {
                Task {
                    await SmartUserSeederService.shared.registerRealUser(user)
                }
            }
        } catch {
            authState = .error(error.localizedDescription)
        }
        #else
        authState = .error("Google Sign-In unavailable")
        #endif
    }
    
    // MARK: - Sign Out
    func signOut() throws {
        #if canImport(FirebaseAuth)
        try Auth.auth().signOut()
        #endif
        
        withAnimation(.easeInOut(duration: 0.5)) {
            currentUser = nil
            isAuthenticated = false
            authState = .unauthenticated
        }
        
        print("You've been signed out")
        NotificationCenter.default.post(name: .userDidLogout, object: nil)
    }
    
    // MARK: - Delete Account
    func deleteAccount() async throws {
        #if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "AuthenticationManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }
        
        // Delete Firebase Auth account
        try await user.delete()
        
        // Clear local state
        await MainActor.run {
            currentUser = nil
            isAuthenticated = false
            authState = .unauthenticated
        }
        
        print("✅ Firebase Auth account deleted")
        NotificationCenter.default.post(name: .userDidLogout, object: nil)
        #else
        throw NSError(domain: "AuthenticationManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Firebase Auth not available"])
        #endif
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
            subscriberCount: user.subscriberCount,
            videoCount: user.videoCount,
            isVerified: user.isVerified,
            isCreator: user.isCreator,
            createdAt: user.createdAt,
            location: user.location,
            website: user.website,
            showWebsiteOnProfile: user.showWebsiteOnProfile,
            showOnlineStatus: user.showOnlineStatus,
            socialLinks: user.socialLinks,
            totalViews: user.totalViews,
            totalEarnings: user.totalEarnings,
            membershipTiers: user.membershipTiers
        )
        
        currentUser = updatedUser
    }
    
    // MARK: - Private Helper Methods
    
    /// After sign-in, load full profile from Firestore so Edit Profile choices (Show Website, privacy, etc.) stick across reload and sign-out/sign-in.
    private func loadFullProfileAfterSignIn(uid: String, fallback: User) async {
        #if canImport(FirebaseFirestore)
        do {
            if let firestoreUser = try await UserFirestoreService.shared.fetchUser(id: uid) {
                currentUser = firestoreUser
                AppState.shared.updateUser(firestoreUser)
                try? await DatabaseService.shared.saveUser(firestoreUser)
                print("✅ Loaded saved profile from Firestore (showWebsiteOnProfile: \(firestoreUser.showWebsiteOnProfile ?? false))")
            }
            // else keep currentUser as fallback; first Edit Profile save will create Firestore doc
        } catch {
            print("⚠️ Could not load profile from Firestore: \(error.localizedDescription)")
        }
        #endif
    }
    
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
            showWebsiteOnProfile: user.showWebsiteOnProfile,
            showOnlineStatus: user.showOnlineStatus,
            socialLinks: user.socialLinks,
            totalViews: user.totalViews,
            totalEarnings: user.totalEarnings,
            membershipTiers: user.membershipTiers
        )
    }
}

// MARK: - Firebase ID token helper
extension AuthenticationManager {
    static func sharedToken() async throws -> String? {
        #if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser else { return nil }
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String?, Error>) in
            user.getIDTokenForcingRefresh(false) { token, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: token)
                }
            }
        }
        #else
        return nil
        #endif
    }
}
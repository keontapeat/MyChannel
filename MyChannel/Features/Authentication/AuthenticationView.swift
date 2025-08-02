//
//  AuthenticationView.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI

struct AuthenticationView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var currentPage: AuthPage = .welcome
    @State private var animateBackground: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Animated gradient background
                AnimatedAuthBackground()
                
                // Content
                VStack(spacing: 0) {
                    switch currentPage {
                    case .welcome:
                        WelcomeView(onContinue: {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                currentPage = .signIn
                            }
                        })
                        
                    case .signIn:
                        SignInView(
                            onSignUp: {
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                    currentPage = .signUp
                                }
                            },
                            onForgotPassword: {
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                    currentPage = .forgotPassword
                                }
                            }
                        )
                        
                    case .signUp:
                        SignUpView(
                            onSignIn: {
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                    currentPage = .signIn
                                }
                            }
                        )
                        
                    case .forgotPassword:
                        ForgotPasswordView(
                            onBack: {
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                    currentPage = .signIn
                                }
                            }
                        )
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Authentication Pages
enum AuthPage {
    case welcome, signIn, signUp, forgotPassword
}

// MARK: - Welcome View
struct WelcomeView: View {
    let onContinue: () -> Void
    
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0.0
    @State private var textOffset: CGFloat = 50
    @State private var buttonsOffset: CGFloat = 100
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Logo and branding
            VStack(spacing: 32) {
                // App logo with animation
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    AppTheme.Colors.primary.opacity(0.3),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)
                        .scaleEffect(logoScale * 1.2)
                        .opacity(logoOpacity * 0.6)
                    
                    // Main logo
                    RoundedRectangle(cornerRadius: 35)
                        .fill(AppTheme.Colors.gradient)
                        .frame(width: 120, height: 120)
                        .overlay(
                            VStack(spacing: 4) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundColor(.white)
                                
                                // Channel waves
                                HStack(spacing: 3) {
                                    ForEach(0..<3) { index in
                                        RoundedRectangle(cornerRadius: 1.5)
                                            .fill(.white)
                                            .frame(width: 4, height: CGFloat(6 + index * 3))
                                            .scaleEffect(y: logoScale + Double(index) * 0.2)
                                            .animation(
                                                .easeInOut(duration: 0.8)
                                                .repeatForever(autoreverses: true)
                                                .delay(Double(index) * 0.2),
                                                value: logoScale
                                            )
                                    }
                                }
                            }
                        )
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)
                        .shadow(
                            color: AppTheme.Colors.primary.opacity(0.4),
                            radius: 25,
                            x: 0,
                            y: 15
                        )
                }
                
                // Welcome text
                VStack(spacing: 16) {
                    Text("Welcome to MyChannel")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppTheme.Colors.primary, AppTheme.Colors.secondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .multilineTextAlignment(.center)
                        .offset(y: textOffset)
                        .opacity(logoOpacity)
                    
                    Text("Your Creative Universe Awaits")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .offset(y: textOffset)
                        .opacity(logoOpacity * 0.9)
                    
                    Text("Create amazing videos, discover trending content, and connect with creators worldwide")
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .offset(y: textOffset)
                        .opacity(logoOpacity * 0.8)
                }
            }
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 16) {
                Button("Get Started") {
                    onContinue()
                    
                    // Haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                }
                .primaryButtonStyle()
                .scaleEffect(1.05)
                .shadow(
                    color: AppTheme.Colors.primary.opacity(0.3),
                    radius: 15,
                    x: 0,
                    y: 8
                )
                
                Text("Join millions of creators sharing their stories")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .offset(y: buttonsOffset)
            .opacity(logoOpacity)
            .padding(.horizontal, 32)
            .padding(.bottom, 50)
        }
        .onAppear {
            startWelcomeAnimation()
        }
    }
    
    private func startWelcomeAnimation() {
        // Logo animation
        withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }
        
        // Text slide in
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.3)) {
            textOffset = 0
        }
        
        // Buttons slide in
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.6)) {
            buttonsOffset = 0
        }
    }
}

// MARK: - Sign In View
struct SignInView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showPassword: Bool = false
    @State private var rememberMe: Bool = false
    @State private var isLoading: Bool = false
    @State private var showingError: Bool = false
    @State private var errorMessage: String = ""
    
    let onSignUp: () -> Void
    let onForgotPassword: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(AppTheme.Colors.primary)
                    
                    VStack(spacing: 8) {
                        Text("Welcome Back!")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Text("Sign in to continue your creative journey")
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 60)
                
                // Sign in form
                VStack(spacing: 24) {
                    // Email field
                    AuthTextField(
                        title: "Email",
                        text: $email,
                        placeholder: "Enter your email",
                        keyboardType: .emailAddress,
                        icon: "envelope"
                    )
                    
                    // Password field
                    AuthPasswordField(
                        title: "Password",
                        text: $password,
                        placeholder: "Enter your password",
                        showPassword: $showPassword
                    )
                    
                    // Remember me & Forgot password
                    HStack {
                        Button(action: { rememberMe.toggle() }) {
                            HStack(spacing: 8) {
                                Image(systemName: rememberMe ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 18))
                                    .foregroundColor(rememberMe ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary)
                                
                                Text("Remember me")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Spacer()
                        
                        Button("Forgot Password?") {
                            onForgotPassword()
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.primary)
                    }
                }
                .padding(.horizontal, 32)
                
                // Sign in button
                VStack(spacing: 16) {
                    Button(action: signIn) {
                        HStack(spacing: 12) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            
                            Text(isLoading ? "Signing In..." : "Sign In")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            Group {
                                if canSignIn && !isLoading {
                                    AppTheme.Colors.gradient
                                } else {
                                    AppTheme.Colors.textTertiary
                                }
                            }
                        )
                        .cornerRadius(AppTheme.CornerRadius.lg)
                        .disabled(!canSignIn || isLoading)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, 32)
                    
                    // Divider
                    HStack {
                        Rectangle()
                            .fill(AppTheme.Colors.divider)
                            .frame(height: 1)
                        
                        Text("OR")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                            .padding(.horizontal, 16)
                        
                        Rectangle()
                            .fill(AppTheme.Colors.divider)
                            .frame(height: 1)
                    }
                    .padding(.horizontal, 32)
                    
                    // Social sign in
                    VStack(spacing: 12) {
                        SocialSignInButton(
                            title: "Continue with Apple",
                            icon: "applelogo",
                            backgroundColor: .black,
                            textColor: .white
                        ) {
                            signInWithApple()
                        }
                        
                        SocialSignInButton(
                            title: "Continue with Google",
                            icon: "globe",
                            backgroundColor: AppTheme.Colors.surface,
                            textColor: AppTheme.Colors.textPrimary
                        ) {
                            signInWithGoogle()
                        }
                    }
                    .padding(.horizontal, 32)
                }
                
                // Sign up link
                HStack(spacing: 4) {
                    Text("Don't have an account?")
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    Button("Sign Up") {
                        onSignUp()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.primary)
                }
                .padding(.bottom, 40)
            }
        }
        .alert("Sign In Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var canSignIn: Bool {
        !email.isEmpty && !password.isEmpty && email.contains("@") && password.count >= 6
    }
    
    private func signIn() {
        isLoading = true
        
        Task {
            do {
                try await authManager.signIn(email: email, password: password)
                
                // Haptic feedback
                let notificationFeedback = UINotificationFeedbackGenerator()
                notificationFeedback.notificationOccurred(.success)
                
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isLoading = false
                    
                    // Error haptic feedback
                    let notificationFeedback = UINotificationFeedbackGenerator()
                    notificationFeedback.notificationOccurred(.error)
                }
            }
        }
    }
    
    private func signInWithApple() {
        // Implement Apple Sign In
        Task {
            await authManager.signInWithApple()
        }
    }
    
    private func signInWithGoogle() {
        // Implement Google Sign In
        Task {
            await authManager.signInWithGoogle()
        }
    }
}

// MARK: - Sign Up View
struct SignUpView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var username: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var showPassword: Bool = false
    @State private var showConfirmPassword: Bool = false
    @State private var agreeToTerms: Bool = false
    @State private var isLoading: Bool = false
    @State private var showingError: Bool = false
    @State private var errorMessage: String = ""
    
    let onSignIn: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 60))
                        .foregroundColor(AppTheme.Colors.primary)
                    
                    VStack(spacing: 8) {
                        Text("Create Account")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Text("Join the community of amazing creators")
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 40)
                
                // Sign up form
                VStack(spacing: 20) {
                    // Name fields
                    HStack(spacing: 12) {
                        AuthTextField(
                            title: "First Name",
                            text: $firstName,
                            placeholder: "First name",
                            icon: "person"
                        )
                        
                        AuthTextField(
                            title: "Last Name",
                            text: $lastName,
                            placeholder: "Last name",
                            icon: "person"
                        )
                    }
                    
                    // Username field
                    AuthTextField(
                        title: "Username",
                        text: $username,
                        placeholder: "Choose a username",
                        icon: "at",
                        validation: usernameValidation
                    )
                    
                    // Email field
                    AuthTextField(
                        title: "Email",
                        text: $email,
                        placeholder: "Enter your email",
                        keyboardType: .emailAddress,
                        icon: "envelope",
                        validation: emailValidation
                    )
                    
                    // Password fields
                    AuthPasswordField(
                        title: "Password",
                        text: $password,
                        placeholder: "Create a password",
                        showPassword: $showPassword,
                        validation: passwordValidation
                    )
                    
                    AuthPasswordField(
                        title: "Confirm Password",
                        text: $confirmPassword,
                        placeholder: "Confirm your password",
                        showPassword: $showConfirmPassword,
                        validation: confirmPasswordValidation
                    )
                    
                    // Terms agreement
                    Button(action: { agreeToTerms.toggle() }) {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: agreeToTerms ? "checkmark.square.fill" : "square")
                                .font(.system(size: 20))
                                .foregroundColor(agreeToTerms ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("I agree to the Terms of Service and Privacy Policy")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                                    .multilineTextAlignment(.leading)
                                
                                HStack {
                                    Button("Terms of Service") { }
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(AppTheme.Colors.primary)
                                    
                                    Text("•")
                                        .font(.system(size: 12))
                                        .foregroundColor(AppTheme.Colors.textTertiary)
                                    
                                    Button("Privacy Policy") { }
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(AppTheme.Colors.primary)
                                }
                            }
                            
                            Spacer()
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 32)
                
                // Sign up button
                VStack(spacing: 16) {
                    Button(action: signUp) {
                        HStack(spacing: 12) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            
                            Text(isLoading ? "Creating Account..." : "Create Account")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            Group {
                                if canSignUp && !isLoading {
                                    AppTheme.Colors.gradient
                                } else {
                                    AppTheme.Colors.textTertiary
                                }
                            }
                        )
                        .cornerRadius(AppTheme.CornerRadius.lg)
                        .disabled(!canSignUp || isLoading)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, 32)
                }
                
                // Sign in link
                HStack(spacing: 4) {
                    Text("Already have an account?")
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    Button("Sign In") {
                        onSignIn()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.primary)
                }
                .padding(.bottom, 40)
            }
        }
        .alert("Sign Up Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var canSignUp: Bool {
        !firstName.isEmpty &&
        !lastName.isEmpty &&
        !username.isEmpty &&
        !email.isEmpty &&
        !password.isEmpty &&
        !confirmPassword.isEmpty &&
        email.contains("@") &&
        password.count >= 8 &&
        password == confirmPassword &&
        agreeToTerms
    }
    
    private var usernameValidation: FieldValidation? {
        guard !username.isEmpty else { return nil }
        
        if username.count < 3 {
            return FieldValidation(isValid: false, message: "Username must be at least 3 characters")
        }
        
        let validCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_.-"))
        if username.rangeOfCharacter(from: validCharacters.inverted) != nil {
            return FieldValidation(isValid: false, message: "Username can only contain letters, numbers, and _.-")
        }
        
        return FieldValidation(isValid: true, message: "Username is available")
    }
    
    private var emailValidation: FieldValidation? {
        guard !email.isEmpty else { return nil }
        
        let emailRegex = #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"#
        let isValid = NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: email)
        
        return FieldValidation(
            isValid: isValid,
            message: isValid ? "Valid email address" : "Please enter a valid email address"
        )
    }
    
    private var passwordValidation: FieldValidation? {
        guard !password.isEmpty else { return nil }
        
        var issues: [String] = []
        
        if password.count < 8 {
            issues.append("At least 8 characters")
        }
        
        if !password.contains(where: { $0.isUppercase }) {
            issues.append("One uppercase letter")
        }
        
        if !password.contains(where: { $0.isNumber }) {
            issues.append("One number")
        }
        
        if issues.isEmpty {
            return FieldValidation(isValid: true, message: "Strong password")
        } else {
            return FieldValidation(isValid: false, message: "Password needs: \(issues.joined(separator: ", "))")
        }
    }
    
    private var confirmPasswordValidation: FieldValidation? {
        guard !confirmPassword.isEmpty else { return nil }
        
        let matches = password == confirmPassword
        return FieldValidation(
            isValid: matches,
            message: matches ? "Passwords match" : "Passwords don't match"
        )
    }
    
    private func signUp() {
        isLoading = true
        
        Task {
            do {
                try await authManager.signUp(
                    firstName: firstName,
                    lastName: lastName,
                    username: username,
                    email: email,
                    password: password
                )
                
                // Success haptic feedback
                let notificationFeedback = UINotificationFeedbackGenerator()
                notificationFeedback.notificationOccurred(.success)
                
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isLoading = false
                    
                    // Error haptic feedback
                    let notificationFeedback = UINotificationFeedbackGenerator()
                    notificationFeedback.notificationOccurred(.error)
                }
            }
        }
    }
}

// MARK: - Forgot Password View
struct ForgotPasswordView: View {
    @State private var email: String = ""
    @State private var isLoading: Bool = false
    @State private var emailSent: Bool = false
    @State private var showingError: Bool = false
    @State private var errorMessage: String = ""
    
    let onBack: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Back button
                HStack {
                    Button(action: onBack) {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .medium))
                            Text("Back")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(AppTheme.Colors.primary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                }
                .padding(.horizontal, 32)
                .padding(.top, 20)
                
                // Header
                VStack(spacing: 16) {
                    Image(systemName: emailSent ? "checkmark.circle.fill" : "lock.rotation")
                        .font(.system(size: 60))
                        .foregroundColor(emailSent ? AppTheme.Colors.success : AppTheme.Colors.primary)
                    
                    VStack(spacing: 8) {
                        Text(emailSent ? "Check Your Email" : "Forgot Password?")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Text(emailSent ? 
                             "We've sent a password reset link to your email address. Please check your inbox and follow the instructions." :
                             "Don't worry! Enter your email address and we'll send you a link to reset your password."
                        )
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.top, 40)
                
                if !emailSent {
                    // Email form
                    VStack(spacing: 24) {
                        AuthTextField(
                            title: "Email",
                            text: $email,
                            placeholder: "Enter your email address",
                            keyboardType: .emailAddress,
                            icon: "envelope"
                        )
                        .padding(.horizontal, 32)
                        
                        Button(action: sendResetEmail) {
                            HStack(spacing: 12) {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                }
                                
                                Text(isLoading ? "Sending..." : "Send Reset Link")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                Group {
                                    if canSendReset && !isLoading {
                                        AppTheme.Colors.gradient
                                    } else {
                                        AppTheme.Colors.textTertiary
                                    }
                                }
                            )
                            .cornerRadius(AppTheme.CornerRadius.lg)
                            .disabled(!canSendReset || isLoading)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal, 32)
                    }
                } else {
                    // Email sent confirmation
                    VStack(spacing: 20) {
                        Button("Resend Email") {
                            sendResetEmail()
                        }
                        .secondaryButtonStyle()
                        .padding(.horizontal, 32)
                        
                        Button("Return to Sign In") {
                            onBack()
                        }
                        .primaryButtonStyle()
                        .padding(.horizontal, 32)
                    }
                }
                
                Spacer()
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var canSendReset: Bool {
        !email.isEmpty && email.contains("@")
    }
    
    private func sendResetEmail() {
        isLoading = true
        
        // Simulate sending reset email
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isLoading = false
            
            if email.contains("@") {
                emailSent = true
                
                // Success haptic feedback
                let notificationFeedback = UINotificationFeedbackGenerator()
                notificationFeedback.notificationOccurred(.success)
            } else {
                errorMessage = "Please enter a valid email address"
                showingError = true
                
                // Error haptic feedback
                let notificationFeedback = UINotificationFeedbackGenerator()
                notificationFeedback.notificationOccurred(.error)
            }
        }
    }
}

// MARK: - Supporting Views

struct AuthTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    var keyboardType: UIKeyboardType = .default
    let icon: String
    var validation: FieldValidation? = nil
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(isFocused ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary)
                    .frame(width: 20)
                
                TextField(placeholder, text: $text)
                    .textFieldStyle(PlainTextFieldStyle())
                    .keyboardType(keyboardType)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .focused($isFocused)
                    .font(.system(size: 16))
            }
            .padding()
            .background(AppTheme.Colors.surface)
            .cornerRadius(AppTheme.CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                    .stroke(
                        isFocused ? AppTheme.Colors.primary : 
                        (validation?.isValid == false ? AppTheme.Colors.error : AppTheme.Colors.divider),
                        lineWidth: isFocused ? 2 : 1
                    )
            )
            
            if let validation = validation {
                HStack(spacing: 6) {
                    Image(systemName: validation.isValid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(validation.isValid ? AppTheme.Colors.success : AppTheme.Colors.error)
                    
                    Text(validation.message)
                        .font(.system(size: 12))
                        .foregroundColor(validation.isValid ? AppTheme.Colors.success : AppTheme.Colors.error)
                }
            }
        }
    }
}

struct AuthPasswordField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    @Binding var showPassword: Bool
    var validation: FieldValidation? = nil
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            HStack(spacing: 12) {
                Image(systemName: "lock")
                    .font(.system(size: 16))
                    .foregroundColor(isFocused ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary)
                    .frame(width: 20)
                
                Group {
                    if showPassword {
                        TextField(placeholder, text: $text)
                    } else {
                        SecureField(placeholder, text: $text)
                    }
                }
                .textFieldStyle(PlainTextFieldStyle())
                .focused($isFocused)
                .font(.system(size: 16))
                
                Button(action: { showPassword.toggle() }) {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            .background(AppTheme.Colors.surface)
            .cornerRadius(AppTheme.CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                    .stroke(
                        isFocused ? AppTheme.Colors.primary : 
                        (validation?.isValid == false ? AppTheme.Colors.error : AppTheme.Colors.divider),
                        lineWidth: isFocused ? 2 : 1
                    )
            )
            
            if let validation = validation {
                HStack(spacing: 6) {
                    Image(systemName: validation.isValid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(validation.isValid ? AppTheme.Colors.success : AppTheme.Colors.error)
                    
                    Text(validation.message)
                        .font(.system(size: 12))
                        .foregroundColor(validation.isValid ? AppTheme.Colors.success : AppTheme.Colors.error)
                        .multilineTextAlignment(.leading)
                }
            }
        }
    }
}

struct SocialSignInButton: View {
    let title: String
    let icon: String
    let backgroundColor: Color
    let textColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(textColor)
                
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(textColor)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(backgroundColor)
            .cornerRadius(AppTheme.CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                    .stroke(AppTheme.Colors.divider, lineWidth: backgroundColor == AppTheme.Colors.surface ? 1 : 0)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct AnimatedAuthBackground: View {
    @State private var animateGradient: Bool = false
    
    var body: some View {
        LinearGradient(
            colors: [
                AppTheme.Colors.background,
                AppTheme.Colors.primary.opacity(0.03),
                AppTheme.Colors.secondary.opacity(0.02),
                AppTheme.Colors.background
            ],
            startPoint: animateGradient ? .topLeading : .bottomTrailing,
            endPoint: animateGradient ? .bottomTrailing : .topLeading
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
        }
    }
}

// MARK: - Supporting Types
struct FieldValidation {
    let isValid: Bool
    let message: String
}

#Preview("Authentication") {
    AuthenticationView()
}

#Preview("Welcome") {
    WelcomeView(onContinue: {})
}

#Preview("Sign In") {
    SignInView(onSignUp: {}, onForgotPassword: {})
}

#Preview("Sign Up") {
    SignUpView(onSignIn: {})
}
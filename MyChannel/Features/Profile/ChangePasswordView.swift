//
//  ChangePasswordView.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthenticationManager
    
    @State private var currentPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var showCurrentPassword: Bool = false
    @State private var showNewPassword: Bool = false
    @State private var showConfirmPassword: Bool = false
    
    @State private var isChangingPassword: Bool = false
    @State private var showingSuccessAlert: Bool = false
    @State private var showingErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    
    @FocusState private var focusedField: PasswordField?
    
    var isFormValid: Bool {
        !currentPassword.isEmpty &&
        !newPassword.isEmpty &&
        !confirmPassword.isEmpty &&
        newPassword == confirmPassword &&
        newPassword.count >= 8 &&
        currentPassword != newPassword
    }
    
    var passwordStrength: PasswordStrength {
        return PasswordValidator.checkStrength(newPassword)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Header Section
                    headerSection
                    
                    // Current Password Section
                    currentPasswordSection
                    
                    // New Password Section
                    newPasswordSection
                    
                    // Password Requirements
                    passwordRequirementsSection
                    
                    // Change Password Button
                    changePasswordButton
                    
                    Spacer(minLength: 50)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
            .alert("Password Changed", isPresented: $showingSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your password has been changed successfully.")
            }
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Security icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                AppTheme.Colors.primary.opacity(0.8),
                                AppTheme.Colors.primary.opacity(0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: AppTheme.Colors.primary.opacity(0.3), radius: 12, x: 0, y: 6)
                
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 8) {
                Text("Secure Your Account")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text("Create a strong password to keep your account safe")
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
    }
    
    // MARK: - Current Password Section
    private var currentPasswordSection: some View {
        VStack(spacing: 20) {
            SectionHeader(title: "Current Password")
            
            PasswordTextField(
                title: "Current Password",
                text: $currentPassword,
                placeholder: "Enter your current password",
                showPassword: $showCurrentPassword,
                focusState: $focusedField,
                field: .current
            )
        }
    }
    
    // MARK: - New Password Section
    private var newPasswordSection: some View {
        VStack(spacing: 20) {
            SectionHeader(title: "New Password")
            
            VStack(spacing: 16) {
                PasswordTextField(
                    title: "New Password",
                    text: $newPassword,
                    placeholder: "Enter your new password",
                    showPassword: $showNewPassword,
                    focusState: $focusedField,
                    field: .new
                )
                
                // Password Strength Indicator
                if !newPassword.isEmpty {
                    PasswordStrengthIndicator(strength: passwordStrength)
                }
                
                PasswordTextField(
                    title: "Confirm New Password",
                    text: $confirmPassword,
                    placeholder: "Confirm your new password",
                    showPassword: $showConfirmPassword,
                    focusState: $focusedField,
                    field: .confirm
                )
                
                // Password Match Indicator
                if !confirmPassword.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: newPassword == confirmPassword ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(newPassword == confirmPassword ? .green : AppTheme.Colors.error)
                        
                        Text(newPassword == confirmPassword ? "Passwords match" : "Passwords don't match")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(newPassword == confirmPassword ? .green : AppTheme.Colors.error)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
    }
    
    // MARK: - Password Requirements Section
    private var passwordRequirementsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Password Requirements")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                PasswordRequirementRow(
                    text: "At least 8 characters",
                    isValid: newPassword.count >= 8
                )
                
                PasswordRequirementRow(
                    text: "Contains uppercase letter",
                    isValid: newPassword.range(of: "[A-Z]", options: .regularExpression) != nil
                )
                
                PasswordRequirementRow(
                    text: "Contains lowercase letter",
                    isValid: newPassword.range(of: "[a-z]", options: .regularExpression) != nil
                )
                
                PasswordRequirementRow(
                    text: "Contains number",
                    isValid: newPassword.range(of: "[0-9]", options: .regularExpression) != nil
                )
                
                PasswordRequirementRow(
                    text: "Contains special character",
                    isValid: newPassword.range(of: "[!@#$%^&*(),.?\":{}|<>]", options: .regularExpression) != nil
                )
                
                PasswordRequirementRow(
                    text: "Different from current password",
                    isValid: !newPassword.isEmpty && currentPassword != newPassword
                )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(AppTheme.Colors.cardBackground)
            .cornerRadius(16)
        }
    }
    
    // MARK: - Change Password Button
    private var changePasswordButton: some View {
        Button {
            changePassword()
        } label: {
            HStack(spacing: 12) {
                if isChangingPassword {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                } else {
                    Image(systemName: "lock.rotation")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }
                
                Text(isChangingPassword ? "Changing Password..." : "Change Password")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                isFormValid && !isChangingPassword ? 
                AppTheme.Colors.primary : 
                AppTheme.Colors.textTertiary
            )
            .cornerRadius(16)
            .shadow(
                color: isFormValid ? AppTheme.Colors.primary.opacity(0.3) : Color.clear,
                radius: 8,
                x: 0,
                y: 4
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isFormValid || isChangingPassword)
        .animation(.easeInOut(duration: 0.2), value: isFormValid)
        .animation(.easeInOut(duration: 0.2), value: isChangingPassword)
    }
    
    // MARK: - Helper Methods
    private func changePassword() {
        guard isFormValid else { return }
        
        isChangingPassword = true
        HapticManager.shared.impact(style: .medium)
        
        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isChangingPassword = false
            
            // Simulate random success/failure for demo
            if Bool.random() {
                showingSuccessAlert = true
            } else {
                errorMessage = "Current password is incorrect. Please try again."
                showingErrorAlert = true
            }
        }
    }
}

// MARK: - Password Text Field
struct PasswordTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    @Binding var showPassword: Bool
    var focusState: FocusState<PasswordField?>.Binding?
    let field: PasswordField?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            HStack(spacing: 0) {
                Group {
                    if showPassword {
                        TextField(placeholder, text: $text)
                    } else {
                        SecureField(placeholder, text: $text)
                    }
                }
                .font(.system(size: 16))
                .foregroundColor(AppTheme.Colors.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .focused(focusState ?? FocusState<PasswordField?>().projectedValue, equals: field)
                
                Button {
                    showPassword.toggle()
                    HapticManager.shared.impact(style: .light)
                } label: {
                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.trailing, 16)
            }
            .background(AppTheme.Colors.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        focusState?.wrappedValue == field ? 
                        AppTheme.Colors.primary : Color.clear,
                        lineWidth: 2
                    )
            )
        }
    }
}

// MARK: - Password Strength Indicator
struct PasswordStrengthIndicator: View {
    let strength: PasswordStrength
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { index in
                    Rectangle()
                        .fill(
                            index < strength.level ? 
                            strength.color : 
                            AppTheme.Colors.textTertiary.opacity(0.3)
                        )
                        .frame(height: 4)
                        .cornerRadius(2)
                }
            }
            .frame(maxWidth: .infinity)
            
            HStack {
                Text("Password Strength: \(strength.text)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(strength.color)
                
                Spacer()
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Password Requirement Row
struct PasswordRequirementRow: View {
    let text: String
    let isValid: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isValid ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 16))
                .foregroundColor(isValid ? .green : AppTheme.Colors.textTertiary)
            
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(isValid ? AppTheme.Colors.textPrimary : AppTheme.Colors.textSecondary)
                .strikethrough(isValid)
            
            Spacer()
        }
        .animation(.easeInOut(duration: 0.2), value: isValid)
    }
}

// MARK: - Password Field Enum
enum PasswordField: CaseIterable {
    case current
    case new
    case confirm
}

// MARK: - Password Strength Enum
enum PasswordStrength {
    case weak
    case fair
    case good
    case strong
    
    var level: Int {
        switch self {
        case .weak: return 1
        case .fair: return 2
        case .good: return 3
        case .strong: return 4
        }
    }
    
    var text: String {
        switch self {
        case .weak: return "Weak"
        case .fair: return "Fair"
        case .good: return "Good"
        case .strong: return "Strong"
        }
    }
    
    var color: Color {
        switch self {
        case .weak: return .red
        case .fair: return .orange
        case .good: return .yellow
        case .strong: return .green
        }
    }
}

// MARK: - Password Validator
struct PasswordValidator {
    static func checkStrength(_ password: String) -> PasswordStrength {
        var score = 0
        
        // Length check
        if password.count >= 8 { score += 1 }
        if password.count >= 12 { score += 1 }
        
        // Character type checks
        if password.range(of: "[A-Z]", options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[a-z]", options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[0-9]", options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[!@#$%^&*(),.?\":{}|<>]", options: .regularExpression) != nil { score += 1 }
        
        switch score {
        case 0...2: return .weak
        case 3...4: return .fair
        case 5: return .good
        default: return .strong
        }
    }
}

#Preview {
    ChangePasswordView()
        .environmentObject(AuthenticationManager.shared)
}
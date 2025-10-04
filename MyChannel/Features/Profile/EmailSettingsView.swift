//
//  EmailSettingsView.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI

struct EmailSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthenticationManager
    
    @State private var primaryEmail: String = "john.doe@example.com"
    @State private var backupEmail: String = ""
    @State private var newEmail: String = ""
    @State private var verificationCode: String = ""
    
    @State private var emailNotifications: Bool = true
    @State private var marketingEmails: Bool = false
    @State private var securityAlerts: Bool = true
    @State private var weeklyDigest: Bool = true
    @State private var channelUpdates: Bool = true
    @State private var commentNotifications: Bool = true
    @State private var likeNotifications: Bool = false
    @State private var followNotifications: Bool = true
    
    @State private var showingChangeEmailSheet: Bool = false
    @State private var showingAddBackupSheet: Bool = false
    @State private var showingVerificationSheet: Bool = false
    @State private var isVerifyingEmail: Bool = false
    @State private var showingSuccessAlert: Bool = false
    @State private var successMessage: String = ""
    
    @FocusState private var focusedField: EmailField?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Email Accounts Section
                    emailAccountsSection
                    
                    // Email Preferences Section
                    emailPreferencesSection
                    
                    // Notification Categories Section
                    notificationCategoriesSection
                    
                    Spacer(minLength: 50)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Email Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Colors.primary)
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingChangeEmailSheet) {
                ChangeEmailSheet(
                    newEmail: $newEmail,
                    isPresented: $showingChangeEmailSheet,
                    onEmailChanged: { email in
                        primaryEmail = email
                        successMessage = "Primary email updated successfully"
                        showingSuccessAlert = true
                    }
                )
            }
            .sheet(isPresented: $showingAddBackupSheet) {
                AddBackupEmailSheet(
                    backupEmail: $backupEmail,
                    isPresented: $showingAddBackupSheet,
                    onEmailAdded: { email in
                        backupEmail = email
                        successMessage = "Backup email added successfully"
                        showingSuccessAlert = true
                    }
                )
            }
            .alert("Success", isPresented: $showingSuccessAlert) {
                Button("OK") { }
            } message: {
                Text(successMessage)
            }
        }
    }
    
    // MARK: - Email Accounts Section
    private var emailAccountsSection: some View {
        VStack(spacing: 20) {
            SectionHeader(title: "Email Accounts")
            
            VStack(spacing: 16) {
                // Primary Email
                EmailAccountRow(
                    icon: "envelope.fill",
                    title: "Primary Email",
                    email: primaryEmail,
                    isVerified: true,
                    isPrimary: true,
                    onTap: {
                        showingChangeEmailSheet = true
                        HapticManager.shared.impact(style: .light)
                    }
                )
                
                // Backup Email
                if backupEmail.isEmpty {
                    Button {
                        showingAddBackupSheet = true
                        HapticManager.shared.impact(style: .light)
                    } label: {
                        HStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(AppTheme.Colors.primary.opacity(0.1))
                                    .frame(width: 40, height: 40)
                                
                                Image(systemName: "plus")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(AppTheme.Colors.primary)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Add Backup Email")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                
                                Text("For account recovery and security")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppTheme.Colors.textTertiary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(AppTheme.Colors.cardBackground)
                        .cornerRadius(12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    EmailAccountRow(
                        icon: "envelope.badge.fill",
                        title: "Backup Email",
                        email: backupEmail,
                        isVerified: false,
                        isPrimary: false,
                        onTap: {
                            // Handle backup email actions
                            HapticManager.shared.impact(style: .light)
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Email Preferences Section
    private var emailPreferencesSection: some View {
        VStack(spacing: 20) {
            SectionHeader(title: "General Preferences")
            
            VStack(spacing: 0) {
                EmailToggleRow(
                    icon: "envelope",
                    title: "Email Notifications",
                    subtitle: "Receive email notifications for account activity",
                    isOn: $emailNotifications
                )
                
                Divider().padding(.leading, 64)
                
                EmailToggleRow(
                    icon: "megaphone",
                    title: "Marketing Emails",
                    subtitle: "Receive promotional emails and product updates",
                    isOn: $marketingEmails
                )
                
                Divider().padding(.leading, 64)
                
                EmailToggleRow(
                    icon: "shield.checkered",
                    title: "Security Alerts",
                    subtitle: "Get notified about important security events",
                    isOn: $securityAlerts
                )
                .disabled(true) // Always on for security
                
                Divider().padding(.leading, 64)
                
                EmailToggleRow(
                    icon: "calendar",
                    title: "Weekly Digest",
                    subtitle: "Summary of your weekly activity",
                    isOn: $weeklyDigest
                )
            }
            .background(AppTheme.Colors.cardBackground)
            .cornerRadius(16)
        }
    }
    
    // MARK: - Notification Categories Section
    private var notificationCategoriesSection: some View {
        VStack(spacing: 20) {
            SectionHeader(title: "Notification Categories")
            
            VStack(spacing: 0) {
                EmailToggleRow(
                    icon: "tv",
                    title: "Channel Updates",
                    subtitle: "New videos from channels you follow",
                    isOn: $channelUpdates
                )
                
                Divider().padding(.leading, 64)
                
                EmailToggleRow(
                    icon: "bubble.left",
                    title: "Comments",
                    subtitle: "Someone comments on your videos",
                    isOn: $commentNotifications
                )
                
                Divider().padding(.leading, 64)
                
                EmailToggleRow(
                    icon: "heart",
                    title: "Likes",
                    subtitle: "Someone likes your content",
                    isOn: $likeNotifications
                )
                
                Divider().padding(.leading, 64)
                
                EmailToggleRow(
                    icon: "person.badge.plus",
                    title: "New Followers",
                    subtitle: "Someone starts following you",
                    isOn: $followNotifications
                )
            }
            .background(AppTheme.Colors.cardBackground)
            .cornerRadius(16)
        }
    }
}

// MARK: - Email Account Row
struct EmailAccountRow: View {
    let icon: String
    let title: String
    let email: String
    let isVerified: Bool
    let isPrimary: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppTheme.Colors.primary.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppTheme.Colors.primary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        if isPrimary {
                            Text("PRIMARY")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppTheme.Colors.primary)
                                .cornerRadius(4)
                        }
                    }
                    
                    HStack(spacing: 8) {
                        Text(email)
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .lineLimit(1)
                        
                        if isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.green)
                        } else {
                            Text("UNVERIFIED")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .cornerRadius(4)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(AppTheme.Colors.cardBackground)
            .cornerRadius(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Email Toggle Row
struct EmailToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    let isDisabled: Bool
    
    init(
        icon: String,
        title: String,
        subtitle: String,
        isOn: Binding<Bool>,
        isDisabled: Bool = false
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
        self.isDisabled = isDisabled
    }
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppTheme.Colors.primary.opacity(isDisabled ? 0.05 : 0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isDisabled ? AppTheme.Colors.textTertiary : AppTheme.Colors.primary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isDisabled ? AppTheme.Colors.textTertiary : AppTheme.Colors.textPrimary)
                    
                    if isDisabled {
                        Text("REQUIRED")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.Colors.textTertiary)
                            .cornerRadius(4)
                    }
                }
                
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .scaleEffect(0.9)
                .disabled(isDisabled)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .opacity(isDisabled ? 0.6 : 1.0)
    }
}

// MARK: - Change Email Sheet
struct ChangeEmailSheet: View {
    @Binding var newEmail: String
    @Binding var isPresented: Bool
    let onEmailChanged: (String) -> Void
    
    @State private var currentPassword: String = ""
    @State private var showPassword: Bool = false
    @State private var isLoading: Bool = false
    
    @FocusState private var focusedField: EmailField?
    
    var isFormValid: Bool {
        !newEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !currentPassword.isEmpty &&
        isValidEmail(newEmail)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "envelope.arrow.triangle.branch")
                            .font(.system(size: 32))
                            .foregroundColor(AppTheme.Colors.primary)
                        
                        Text("Change Primary Email")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Text("Your new email will need to be verified")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Form
                    VStack(spacing: 20) {
                        // New Email Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("New Email Address")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            
                            TextField("Enter your new email", text: $newEmail)
                                .font(.system(size: 16))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(AppTheme.Colors.cardBackground)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            focusedField == .newEmail ? 
                                            AppTheme.Colors.primary : Color.clear,
                                            lineWidth: 2
                                        )
                                )
                                .focused($focusedField, equals: .newEmail)
                        }
                        
                        // Current Password Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Current Password")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            
                            HStack(spacing: 0) {
                                Group {
                                    if showPassword {
                                        TextField("Enter your password", text: $currentPassword)
                                    } else {
                                        SecureField("Enter your password", text: $currentPassword)
                                    }
                                }
                                .font(.system(size: 16))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .focused($focusedField, equals: .currentPassword)
                                
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
                                        focusedField == .currentPassword ? 
                                        AppTheme.Colors.primary : Color.clear,
                                        lineWidth: 2
                                    )
                            )
                        }
                    }
                    
                    // Info Box
                    InfoBox(
                        icon: "info.circle.fill",
                        title: "Email Verification Required",
                        message: "After changing your email, you'll receive a verification link at your new address. Your account will remain accessible during this process."
                    )
                    
                    // Update Button
                    Button {
                        updateEmail()
                    } label: {
                        HStack(spacing: 12) {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            } else {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            
                            Text(isLoading ? "Updating..." : "Update Email")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            isFormValid && !isLoading ? 
                            AppTheme.Colors.primary : 
                            AppTheme.Colors.textTertiary
                        )
                        .cornerRadius(16)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(!isFormValid || isLoading)
                    
                    Spacer(minLength: 50)
                }
                .padding(.horizontal, 20)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    private func updateEmail() {
        guard isFormValid else { return }
        
        isLoading = true
        HapticManager.shared.impact(style: .medium)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isLoading = false
            onEmailChanged(newEmail)
            isPresented = false
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
}

// MARK: - Add Backup Email Sheet
struct AddBackupEmailSheet: View {
    @Binding var backupEmail: String
    @Binding var isPresented: Bool
    let onEmailAdded: (String) -> Void
    
    @State private var isLoading: Bool = false
    @FocusState private var isEmailFieldFocused: Bool
    
    var isFormValid: Bool {
        !backupEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        isValidEmail(backupEmail)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "envelope.badge.shield.half.filled")
                            .font(.system(size: 32))
                            .foregroundColor(AppTheme.Colors.primary)
                        
                        Text("Add Backup Email")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Text("A backup email helps secure your account and aids in recovery")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Email Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Backup Email Address")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        TextField("Enter backup email", text: $backupEmail)
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(AppTheme.Colors.cardBackground)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        isEmailFieldFocused ? 
                                        AppTheme.Colors.primary : Color.clear,
                                        lineWidth: 2
                                    )
                            )
                            .focused($isEmailFieldFocused)
                    }
                    
                    // Benefits List
                    InfoBox(
                        icon: "shield.checkered",
                        title: "Why Add a Backup Email?",
                        message: "• Account recovery if you forget your password\n• Security notifications for account activity\n• Alternative contact method for important updates"
                    )
                    
                    // Add Button
                    Button {
                        addBackupEmail()
                    } label: {
                        HStack(spacing: 12) {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            } else {
                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            
                            Text(isLoading ? "Adding..." : "Add Backup Email")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            isFormValid && !isLoading ? 
                            AppTheme.Colors.primary : 
                            AppTheme.Colors.textTertiary
                        )
                        .cornerRadius(16)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(!isFormValid || isLoading)
                    
                    Spacer(minLength: 50)
                }
                .padding(.horizontal, 20)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    private func addBackupEmail() {
        guard isFormValid else { return }
        
        isLoading = true
        HapticManager.shared.impact(style: .medium)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isLoading = false
            onEmailAdded(backupEmail)
            isPresented = false
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
}

// MARK: - Info Box
struct InfoBox: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(AppTheme.Colors.primary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(message)
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppTheme.Colors.primary.opacity(0.08))
        .cornerRadius(12)
    }
}

// MARK: - Email Field Enum
enum EmailField: CaseIterable {
    case newEmail
    case currentPassword
}

// MARK: - Section Header
struct SectionHeader: View {
    let title: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Spacer()
        }
    }
}

#Preview {
    EmailSettingsView()
        .environmentObject(AuthenticationManager.shared)
}
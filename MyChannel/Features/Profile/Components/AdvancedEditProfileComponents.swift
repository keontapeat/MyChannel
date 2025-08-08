//
//  AdvancedEditProfileComponents.swift
//  MyChannel
//
//  Created by AI Assistant
//

import SwiftUI
import PhotosUI

// MARK: - Advanced Text Field with Validation
struct AdvancedTextField: View {
    let title: String
    @Binding var text: String
    let icon: String
    let prefix: String?
    let placeholder: String
    let keyboardType: UIKeyboardType
    let validation: TextValidation?
    
    @FocusState private var isFocused: Bool
    @State private var validationState: ValidationState = .idle
    @State private var showValidation = false
    
    enum ValidationState: Equatable {
        case idle, validating, valid, invalid(String)
        
        static func == (lhs: ValidationState, rhs: ValidationState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.validating, .validating), (.valid, .valid):
                return true
            case (.invalid(let lhsMessage), .invalid(let rhsMessage)):
                return lhsMessage == rhsMessage
            default:
                return false
            }
        }
    }
    
    struct TextValidation {
        let validator: (String) -> ValidationResult
        let debounceTime: Double
    }
    
    enum ValidationResult {
        case valid
        case invalid(String)
        case validating
    }
    
    init(title: String, text: Binding<String>, icon: String, prefix: String? = nil, placeholder: String = "", keyboardType: UIKeyboardType = .default, validation: TextValidation? = nil) {
        self.title = title
        self._text = text
        self.icon = icon
        self.prefix = prefix
        self.placeholder = placeholder
        self.keyboardType = keyboardType
        self.validation = validation
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title with validation indicator
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                if showValidation {
                    validationIndicator
                }
                
                Spacer()
            }
            
            // Input field
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(fieldBorderColor)
                    .frame(width: 20)
                    .animation(.easeInOut(duration: 0.2), value: isFocused)
                
                if let prefix = prefix {
                    Text(prefix)
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                TextField(placeholder, text: $text)
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(keyboardType == .URL ? .never : .words)
                    .focused($isFocused)
                    .onChange(of: text) { _, newValue in
                        if let validation = validation {
                            validateText(newValue, validation: validation)
                        }
                    }
                    .onSubmit {
                        if let validation = validation {
                            validateText(text, validation: validation)
                        }
                    }
            }
            .padding(16)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(fieldBorderColor, lineWidth: fieldBorderWidth)
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: validationState)
            
            // Validation message
            if showValidation, case .invalid(let message) = validationState {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                    
                    Text(message)
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                }
                .transition(.slide.combined(with: .opacity))
            }
        }
    }
    
    private var fieldBorderColor: Color {
        switch validationState {
        case .invalid:
            return .red
        case .valid:
            return .green
        case .validating:
            return AppTheme.Colors.primary
        case .idle:
            return isFocused ? AppTheme.Colors.primary : AppTheme.Colors.divider.opacity(0.3)
        }
    }
    
    private var fieldBorderWidth: CGFloat {
        switch validationState {
        case .idle:
            return isFocused ? 2 : 1
        case .validating, .valid, .invalid:
            return 2
        }
    }
    
    @ViewBuilder
    private var validationIndicator: some View {
        switch validationState {
        case .validating:
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.primary))
                .scaleEffect(0.6)
        case .valid:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(.green)
        case .invalid:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(.red)
        case .idle:
            EmptyView()
        }
    }
    
    private func validateText(_ text: String, validation: TextValidation) {
        guard !text.isEmpty else {
            validationState = .idle
            showValidation = false
            return
        }
        
        validationState = .validating
        showValidation = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + validation.debounceTime) {
            let result = validation.validator(text)
            withAnimation(.easeInOut(duration: 0.2)) {
                switch result {
                case .valid:
                    validationState = .valid
                case .invalid(let message):
                    validationState = .invalid(message)
                case .validating:
                    validationState = .validating
                }
            }
        }
    }
}

// MARK: - Advanced Character Counter Text Editor
struct AdvancedTextEditor: View {
    let title: String
    @Binding var text: String
    let icon: String
    let placeholder: String
    let maxCharacters: Int
    
    @FocusState private var isFocused: Bool
    @State private var characterCount = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with live character counter
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text("\(characterCount)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(characterCountColor)
                    
                    Text("/\(maxCharacters)")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(characterCountBackgroundColor)
                .clipShape(Capsule())
                .animation(.easeInOut(duration: 0.2), value: characterCount)
            }
            
            // Editor container
            VStack(alignment: .leading, spacing: 0) {
                // Header bar
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(isFocused ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary)
                        .frame(width: 20)
                    
                    Text("About You")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    Spacer()
                    
                    // Character progress indicator
                    AdvancedCircularProgressView(
                        progress: Double(characterCount) / Double(maxCharacters),
                        color: characterCountColor
                    )
                    .frame(width: 16, height: 16)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                // Text editor
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $text)
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .focused($isFocused)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .onChange(of: text) { _, newValue in
                            withAnimation(.easeInOut(duration: 0.1)) {
                                characterCount = newValue.count
                            }
                            if newValue.count > maxCharacters {
                                text = String(newValue.prefix(maxCharacters))
                                HapticManager.shared.impact(style: .rigid)
                            }
                        }
                    
                    if text.isEmpty {
                        Text(placeholder)
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                }
                .frame(height: 100)
            }
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: isFocused ? 2 : 1)
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
        }
        .onAppear {
            characterCount = text.count
        }
    }
    
    private var characterCountColor: Color {
        let ratio = Double(characterCount) / Double(maxCharacters)
        if ratio >= 1.0 {
            return .red
        } else if ratio >= 0.8 {
            return .orange
        } else {
            return AppTheme.Colors.primary
        }
    }
    
    private var characterCountBackgroundColor: Color {
        let ratio = Double(characterCount) / Double(maxCharacters)
        if ratio >= 1.0 {
            return .red.opacity(0.1)
        } else if ratio >= 0.8 {
            return .orange.opacity(0.1)
        } else {
            return AppTheme.Colors.primary.opacity(0.1)
        }
    }
    
    private var borderColor: Color {
        if characterCount > maxCharacters {
            return .red
        } else {
            return isFocused ? AppTheme.Colors.primary : AppTheme.Colors.divider.opacity(0.3)
        }
    }
}

// MARK: - Advanced Circular Progress View
struct AdvancedCircularProgressView: View {
    let progress: Double
    let color: Color
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 2)
            
            Circle()
                .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)
        }
    }
}

// MARK: - Enhanced Privacy Toggle with Animation
struct AdvancedPrivacyToggleRow: View {
    let title: String
    let description: String
    let icon: String
    @Binding var isOn: Bool
    let requiresPremium: Bool
    
    @State private var showPremiumPrompt = false
    
    init(title: String, description: String, icon: String, isOn: Binding<Bool>, requiresPremium: Bool = false) {
        self.title = title
        self.description = description
        self.icon = icon
        self._isOn = isOn
        self.requiresPremium = requiresPremium
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Animated icon
            ZStack {
                Circle()
                    .fill(iconBackgroundColor)
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(iconColor)
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isOn)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    if requiresPremium {
                        Text("PRO")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                    }
                }
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            // Enhanced toggle
            Toggle("", isOn: $isOn)
                .toggleStyle(AdvancedToggleStyle(isEnabled: !requiresPremium || isOn))
                .disabled(requiresPremium && !isOn)
                .onTapGesture {
                    if requiresPremium && !isOn {
                        showPremiumPrompt = true
                        HapticManager.shared.impact(style: .medium)
                    } else {
                        HapticManager.shared.impact(style: .light)
                    }
                }
        }
        .padding(20)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(borderColor, lineWidth: 1)
        )
        .scaleEffect(isOn ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isOn)
        .sheet(isPresented: $showPremiumPrompt) {
            PremiumPromptSheet()
        }
    }
    
    private var iconBackgroundColor: Color {
        isOn ? AppTheme.Colors.primary.opacity(0.2) : AppTheme.Colors.surface
    }
    
    private var iconColor: Color {
        isOn ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary
    }
    
    private var borderColor: Color {
        isOn ? AppTheme.Colors.primary.opacity(0.3) : AppTheme.Colors.divider.opacity(0.2)
    }
}

// MARK: - Advanced Toggle Style
struct AdvancedToggleStyle: ToggleStyle {
    let isEnabled: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            
            RoundedRectangle(cornerRadius: 16)
                .fill(configuration.isOn ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary.opacity(0.3))
                .frame(width: 50, height: 30)
                .overlay(
                    Circle()
                        .fill(.white)
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                        .padding(2)
                        .offset(x: configuration.isOn ? 10 : -10)
                )
                .onTapGesture {
                    if isEnabled {
                        withAnimation(.spring()) {
                            configuration.isOn.toggle()
                        }
                    }
                }
                .opacity(isEnabled ? 1.0 : 0.5)
        }
    }
}

// MARK: - Premium Prompt Sheet
struct PremiumPromptSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "crown.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                    }
                    
                    Text("Premium Feature")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("This feature is available with MyChannel Pro. Upgrade to unlock advanced privacy controls and more.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .padding(.horizontal, 20)
                }
                
                VStack(spacing: 12) {
                    Button(action: {
                        // Handle upgrade action
                        dismiss()
                    }) {
                        Text("Upgrade to Pro")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .background(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    Button("Maybe Later") {
                        dismiss()
                    }
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .padding(.vertical, 40)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    VStack(spacing: 20) {
        AdvancedTextField(
            title: "Username",
            text: .constant("johndoe"),
            icon: "at",
            prefix: "@",
            placeholder: "username",
            validation: AdvancedTextField.TextValidation(
                validator: { username in
                    if username.count < 3 {
                        return .invalid("Username must be at least 3 characters")
                    }
                    return .valid
                },
                debounceTime: 0.5
            )
        )
        
        AdvancedTextEditor(
            title: "Bio",
            text: .constant(""),
            icon: "text.quote",
            placeholder: "Tell people about yourself...",
            maxCharacters: 150
        )
        
        AdvancedPrivacyToggleRow(
            title: "Advanced Analytics",
            description: "Get detailed insights about your profile views",
            icon: "chart.bar.fill",
            isOn: .constant(false),
            requiresPremium: true
        )
    }
    .padding(20)
    .background(AppTheme.Colors.background)
}
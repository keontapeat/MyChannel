import SwiftUI
import PhotosUI

struct ProfessionalInputField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let icon: String
    let isRequired: Bool
    let maxLength: Int
    
    @FocusState private var isFocused: Bool
    
    init(title: String, text: Binding<String>, placeholder: String, icon: String, isRequired: Bool = false, maxLength: Int = 1000) {
        self.title = title
        self._text = text
        self.placeholder = placeholder
        self.icon = icon
        self.isRequired = isRequired
        self.maxLength = maxLength
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.system(size: 16, weight: .semibold)).foregroundColor(AppTheme.Colors.textPrimary)
                if isRequired { Text("*").font(.system(size: 16, weight: .semibold)).foregroundColor(.red) }
                Spacer()
                Text("\(text.count)/\(maxLength)").font(.system(size: 12)).foregroundColor(text.count > maxLength ? .red : AppTheme.Colors.textTertiary)
            }
            
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 16)).foregroundColor(isFocused ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary).frame(width: 20)
                TextField(placeholder, text: $text)
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .focused($isFocused)
                    .onChange(of: text) { newValue in
                        if newValue.count > maxLength { text = String(newValue.prefix(maxLength)) }
                    }
            }
            .padding(16)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isFocused ? AppTheme.Colors.primary : AppTheme.Colors.divider.opacity(0.3), lineWidth: isFocused ? 2 : 1))
            .animation(.easeInOut(duration: 0.2), value: isFocused)
        }
    }
}

struct ProfessionalTextEditor: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let icon: String
    let maxLength: Int
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.system(size: 16, weight: .semibold)).foregroundColor(AppTheme.Colors.textPrimary)
                Spacer()
                Text("\(text.count)/\(maxLength)").font(.system(size: 12)).foregroundColor(text.count > maxLength ? .red : AppTheme.Colors.textTertiary)
            }
            
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: icon).font(.system(size: 16)).foregroundColor(isFocused ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary).frame(width: 20)
                    Text("Description").font(.system(size: 16, weight: .medium)).foregroundColor(AppTheme.Colors.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                ZStack(alignment: .topLeading) {
                    UIKitMultilineTextView(
                        text: $text,
                        placeholder: placeholder,
                        font: .systemFont(ofSize: 16),
                        textColor: UIColor(AppTheme.Colors.textPrimary),
                        placeholderColor: UIColor(AppTheme.Colors.textTertiary),
                        isFirstResponder: isFocused,
                        maxLength: maxLength,
                        onFocusChanged: { focused in
                            isFocused = focused
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                }
                .frame(height: 100)
            }
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isFocused ? AppTheme.Colors.primary : AppTheme.Colors.divider.opacity(0.2), lineWidth: isFocused ? 2 : 1))
            .animation(.easeInOut(duration: 0.2), value: isFocused)
        }
    }
}

struct ProfessionalPicker<T: CaseIterable & Hashable & RawRepresentable>: View where T.RawValue == String, T: CustomStringConvertible {
    let title: String
    @Binding var selection: T
    let icon: String
    let options: [T]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Menu {
                ForEach(options, id: \.self) { option in
                    Button {
                        selection = option
                        HapticManager.shared.impact(style: .light)
                    } label: {
                        HStack {
                            Text(option.description)
                            Spacer()
                            if option == selection {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    Text(selection.description)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppTheme.Colors.background)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppTheme.Colors.divider.opacity(0.4), lineWidth: 1)
                )
            }
            .contentShape(Rectangle())
        }
    }
}

struct ProfessionalTagInput: View {
    let title: String
    @Binding var selectedTags: Set<String>
    let icon: String
    
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool
    private let suggestedTags = ["Tutorial", "Educational", "Fun", "Music", "Gaming", "Tech", "Lifestyle", "Comedy"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Text("\(selectedTags.count)/10")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(selectedTags.count >= 10 ? .red : AppTheme.Colors.textTertiary)
            }
            
            // Input field
            HStack(spacing: 10) {
                TextField("Add tags", text: $inputText)
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .focused($isInputFocused)
                    .onSubmit { addTag() }
                    .submitLabel(.done)
                
                if !inputText.isEmpty {
                    Button(action: { inputText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                    }
                }
                
                Button(action: addTag) {
                    Text("Add")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(canAddTag ? AppTheme.Colors.textPrimary : AppTheme.Colors.textTertiary)
                }
                .disabled(!canAddTag)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppTheme.Colors.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isInputFocused ? AppTheme.Colors.textPrimary.opacity(0.4) : AppTheme.Colors.divider.opacity(0.4), lineWidth: 1)
                    )
            )
            .animation(.easeInOut(duration: 0.15), value: isInputFocused)
            
            // Selected tags
            if !selectedTags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(Array(selectedTags).sorted(), id: \.self) { tag in
                        YouTubeStyleTagChip(tag: tag, isSelected: true) {
                            _ = withAnimation(.easeInOut(duration: 0.2)) {
                                selectedTags.remove(tag)
                            }
                            HapticManager.shared.impact(style: .light)
                        }
                    }
                }
            }
            
            // Suggested tags
            if !availableSuggestedTags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Suggested")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                    
                    FlowLayout(spacing: 6) {
                        ForEach(availableSuggestedTags.prefix(8), id: \.self) { tag in
                            YouTubeStyleTagChip(tag: tag, isSelected: false) {
                                if selectedTags.count < 10 {
                                    _ = withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedTags.insert(tag)
                                    }
                                    HapticManager.shared.impact(style: .light)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var canAddTag: Bool {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && !selectedTags.contains(trimmed) && selectedTags.count < 10
    }
    
    private var availableSuggestedTags: [String] {
        suggestedTags.filter { !selectedTags.contains($0) }
    }
    
    private func addTag() {
        let tag = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tag.isEmpty && !selectedTags.contains(tag) && selectedTags.count < 10 {
            _ = withAnimation(.easeInOut(duration: 0.2)) {
                selectedTags.insert(tag)
            }
            inputText = ""
            HapticManager.shared.impact(style: .light)
        }
    }
}

struct YouTubeStyleTagChip: View {
    let tag: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(tag)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                
                Image(systemName: isSelected ? "xmark" : "plus")
                    .font(.system(size: 10, weight: .bold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? AppTheme.Colors.textPrimary : AppTheme.Colors.background)
            )
            .foregroundColor(isSelected ? .white : AppTheme.Colors.textPrimary)
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : AppTheme.Colors.divider.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ProfessionalToggleRow: View {
    let title: String
    let subtitle: String
    let icon: String
    @Binding var isOn: Bool
    let isPremium: Bool
    
    init(title: String, subtitle: String, icon: String, isOn: Binding<Bool>, isPremium: Bool = false) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self._isOn = isOn
        self.isPremium = isPremium
    }
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(isOn ? AppTheme.Colors.primary.opacity(0.1) : AppTheme.Colors.surface).frame(width: 40, height: 40)
                Image(systemName: icon).font(.system(size: 18, weight: .medium)).foregroundColor(isOn ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title).font(.system(size: 16, weight: .semibold)).foregroundColor(AppTheme.Colors.textPrimary)
                    if isPremium {
                        Text("PRO")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(AppTheme.Colors.primary)
                            .clipShape(Capsule())
                    }
                }
                Text(subtitle).font(.system(size: 14)).foregroundColor(AppTheme.Colors.textSecondary)
            }
            Spacer()
            Toggle("", isOn: $isOn).toggleStyle(SwitchToggleStyle(tint: AppTheme.Colors.primary))
        }
        .padding(16)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.Colors.divider.opacity(0.2), lineWidth: 1))
    }
}

struct ProfessionalButtonStyle: ButtonStyle {
    enum Style { case primary, secondary }
    let style: Style
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/*
struct ProfessionalVisibilityPicker: View {
    let title: String
    // @Binding var selection: VideoUploadManager.VideoVisibility
    let icon: String
    var body: some View { EmptyView() }
}
*/

struct ProfessionalDatePicker: View {
    let title: String
    @Binding var date: Date
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(AppTheme.Colors.primary)
                    .font(.system(size: 16, weight: .medium))
                
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }
            
            DatePicker("", selection: $date, in: Date()...)
                .datePickerStyle(.compact)
                .labelsHidden()
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppTheme.Colors.cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.Colors.divider, lineWidth: 1)
                )
        }
    }
}


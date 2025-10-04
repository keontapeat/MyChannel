import SwiftUI

struct LanguageSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("app.language") private var languageCode: String = Locale.current.language.languageCode?.identifier ?? "en"

    private let supported: [(code: String, name: String)] = [
        ("en", "English"),
        ("es", "Spanish"),
        ("fr", "French"),
        ("de", "German"),
        ("ar", "Arabic")
    ]

    var body: some View {
        NavigationView {
            List {
                ForEach(supported, id: \.code) { item in
                    HStack {
                        Text(item.name)
                        Spacer()
                        if languageCode == item.code {
                            Image(systemName: "checkmark").foregroundStyle(AppTheme.Colors.primary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { languageCode = item.code }
                }
            }
            .navigationTitle("Language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}

#Preview { LanguageSettingsView() }

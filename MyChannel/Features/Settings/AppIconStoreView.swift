import SwiftUI

struct AppIconStoreView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var iconEngine = AppIconEngine.shared
    
    // Using simple names assuming these exist in Assets/Info.plist as alternate icons
    let availableIcons = [
        ("Default", nil),
        ("Dark", "AppIconDark"),
        ("Neon", "AppIconNeon"),
        ("Retro", "AppIconRetro"),
        ("Gold", "AppIconGold"),
        ("Minimal", "AppIconMinimal")
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                let columns = horizontalSizeClass == .regular 
                    ? [GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 20)]
                    : [GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 16)]
                
                LazyVGrid(columns: columns, spacing: 24) {
                    ForEach(availableIcons, id: \.0) { icon in
                        VStack(spacing: 12) {
                            // Mocking the icon presentation with a rounded rectangle if image not available
                            ZStack {
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .fill(AppTheme.Colors.surface)
                                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                                
                                if icon.1 == nil {
                                    Image(systemName: "play.square.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(AppTheme.Colors.primary)
                                } else {
                                    // Normally you'd load the actual image from asset catalog
                                    Image(systemName: "app.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(iconColor(for: icon.0))
                                }
                                
                                if iconEngine.currentIconName == icon.1 || (iconEngine.currentIconName == nil && icon.1 == nil) {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 24, height: 24)
                                        .overlay(Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundColor(.white))
                                        .offset(x: 35, y: -35)
                                }
                            }
                            .frame(width: 100, height: 100)
                            
                            Text(icon.0)
                                .font(.system(size: 14, weight: .medium))
                            
                            Button(action: {
                                HapticManager.shared.impact(style: .medium)
                                iconEngine.changeAppIcon(to: icon.1)
                            }) {
                                Text((iconEngine.currentIconName == icon.1 || (iconEngine.currentIconName == nil && icon.1 == nil)) ? "Active" : "Apply")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor((iconEngine.currentIconName == icon.1 || (iconEngine.currentIconName == nil && icon.1 == nil)) ? .white : AppTheme.Colors.primary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background((iconEngine.currentIconName == icon.1 || (iconEngine.currentIconName == nil && icon.1 == nil)) ? Color.green : AppTheme.Colors.primary.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                .padding(24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("App Icon Store")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func iconColor(for name: String) -> Color {
        switch name {
        case "Dark": return .black
        case "Neon": return .cyan
        case "Retro": return .orange
        case "Gold": return .yellow
        case "Minimal": return .gray
        default: return AppTheme.Colors.primary
        }
    }
}

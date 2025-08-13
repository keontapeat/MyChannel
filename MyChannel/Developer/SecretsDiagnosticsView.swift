import SwiftUI

struct SecretsDiagnosticsView: View {
    private var hasTMDB: Bool { !AppSecrets.tmdbAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(hasTMDB ? Color.green : Color.red)
                        .frame(width: 14, height: 14)
                        .shadow(color: (hasTMDB ? Color.green : Color.red).opacity(0.4), radius: 6, x: 0, y: 2)
                    Text("TMDB_API_KEY")
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                    Text(hasTMDB ? "Available" : "Missing")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(hasTMDB ? .green : .red)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill((hasTMDB ? Color.green : Color.red).opacity(0.12)))
                }

                Text("This screen checks whether your app can access TMDB_API_KEY at runtime. The actual key is never shown or logged.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Divider().padding(.vertical, 8)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Provide the key securely via:")
                        .font(.system(size: 14, weight: .semibold))
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Scheme Environment Variable (Run/Previews/Test)", systemImage: "1.circle")
                        Label("Secrets.local.xcconfig (ignored by Git)", systemImage: "2.circle")
                        Label("CI Secret (GitHub Actions)", systemImage: "3.circle")
                    }
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)
            }
            .padding(20)
            .navigationTitle("Secrets Diagnostics")
        }
    }
}

#Preview("Secrets Diagnostics") {
    SecretsDiagnosticsView()
        .preferredColorScheme(.light)
        .environmentObject(AppState())
}
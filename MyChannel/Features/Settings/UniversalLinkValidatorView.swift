import SwiftUI

struct UniversalLinkValidatorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var result: String = ""

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Checks that the apple-app-site-association is reachable and valid.")
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                Button("Run Check", action: runCheck)
                    .buttonStyle(.borderedProminent)

                ScrollView {
                    Text(result.isEmpty ? "Tap Run Check" : result)
                        .font(.system(size: 13, weight: .regular, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.Colors.backgroundSecondary.opacity(0.4))
                        .cornerRadius(8)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Universal Links")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } } }
        }
    }

    private func runCheck() {
        let urls = [
            URL(string: "https://mychannel.live/apple-app-site-association"),
            URL(string: "https://www.mychannel.live/apple-app-site-association")
        ].compactMap { $0 }

        Task {
            var lines: [String] = []
            for url in urls {
                do {
                    let (data, resp) = try await URLSession.shared.data(from: url)
                    if let http = resp as? HTTPURLResponse {
                        lines.append("\nURL: \(url.absoluteString)\nStatus: \(http.statusCode)")
                        lines.append("Content-Type: \(http.value(forHTTPHeaderField: "Content-Type") ?? "")")
                    }
                    if let text = String(data: data, encoding: .utf8) {
                        lines.append("Body (first 400 chars):\n\(text.prefix(400))")
                    }
                } catch {
                    lines.append("\nURL: \(url.absoluteString)\nError: \(error.localizedDescription)")
                }
            }
            await MainActor.run { self.result = lines.joined(separator: "\n") }
        }
    }
}

#Preview { UniversalLinkValidatorView() }

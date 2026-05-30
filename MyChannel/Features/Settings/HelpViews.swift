// ⚡ PERFORMANCE: Extracted from SettingsView.swift to its own compilation unit.
// Separate file = independent incremental compilation. Changes here don't
// trigger recompilation of the other 24 structs in SettingsView.swift.
import SwiftUI

// MARK: - Help View
struct HelpView: View {
    var body: some View {
        List {
            Section {
                Button {
                    if let url = URL(string: "https://mychannel.live/help") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack {
                        Text("Help Center")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Button {
                    if let url = URL(string: "https://mychannel.live/guidelines") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack {
                        Text("Community Guidelines")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Button {
                    if let url = URL(string: "https://mychannel.live/copyright") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack {
                        Text("Copyright Policy")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Button {
                    let email = "support@mychannel.live"
                    let subject = "Support Request"
                    let subjectEncoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                    if let url = URL(string: "mailto:\(email)?subject=\(subjectEncoded)") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack {
                        Text("Contact Support")
                            .foregroundColor(AppTheme.Colors.primary)
                        Spacer()
                        Image(systemName: "envelope")
                            .font(.caption)
                            .foregroundColor(AppTheme.Colors.primary)
                    }
                }
            }
            
            Section("Quick Help") {
                NavigationLink("How to upload videos") {
                    HelpArticleView(title: "How to Upload Videos", content: """
                    1. Tap the + button at the bottom of the screen
                    2. Select a video from your library or record a new one
                    3. Add a title, description, and thumbnail
                    4. Choose your privacy settings
                    5. Tap Upload to publish your video
                    
                    Your video will be processed and available within minutes!
                    """)
                }
                NavigationLink("Monetization requirements") {
                    HelpArticleView(title: "Monetization Requirements", content: """
                    To monetize your content on MyChannel:
                    
                    • 1,000+ subscribers
                    • 4,000+ watch hours in the last 12 months
                    • Follow Community Guidelines
                    • Have an approved AdSense account
                    
                    Once eligible, enable monetization in Creator Studio.
                    """)
                }
                NavigationLink("Account & Privacy") {
                    HelpArticleView(title: "Account & Privacy", content: """
                    Your privacy matters to us:
                    
                    • You control who sees your content
                    • You can download your data anytime
                    • You can delete your account and all data
                    • We never sell your personal information
                    
                    Manage settings in Settings > Privacy.
                    """)
                }
            }
        }
        .navigationTitle("Help")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Help Article View
struct HelpArticleView: View {
    let title: String
    let content: String
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(content)
                    .font(.body)
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }
            .padding()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Feedback View
struct FeedbackView: View {
    @State private var feedbackText = ""
    @State private var showingSuccess = false
    
    var body: some View {
        Form {
            Section {
                TextEditor(text: $feedbackText)
                    .frame(minHeight: 150)
            } header: {
                Text("Your feedback")
            } footer: {
                Text("Tell us what you think about MyChannel")
            }
            
            Section {
                Button("Send feedback") {
                    showingSuccess = true
                }
                .disabled(feedbackText.isEmpty)
            }
        }
        .navigationTitle("Send feedback")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Thanks for your feedback!", isPresented: $showingSuccess) {
            Button("OK") {
                feedbackText = ""
            }
        }
    }
}

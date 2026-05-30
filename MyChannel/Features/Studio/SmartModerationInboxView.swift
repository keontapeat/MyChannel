import SwiftUI

/// A Creator Studio view that acts as a Smart Inbox for comments.
/// It utilizes Vertex AI (Gemini) to automatically filter out toxicity and spam.
struct SmartModerationInboxView: View {
    @State private var comments: [SmartInboxComment] = [
        SmartInboxComment(author: "User123", text: "You are the worst creator ever, delete your channel! 😡", isAnalyzed: false),
        SmartInboxComment(author: "Fanboy99", text: "Wow, this video was incredibly helpful. Thank you so much!", isAnalyzed: false),
        SmartInboxComment(author: "CryptoBot", text: "Click here to win free Bitcoin! http://spam.link", isAnalyzed: false)
    ]
    
    @State private var isScanning: Bool = false
    
    var body: some View {
        VStack {
            HStack {
                Text("Smart Inbox")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                Spacer()
                
                if isScanning {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                } else {
                    Button(action: scanComments) {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("AI Scan")
                        }
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.purple)
                        .cornerRadius(20)
                    }
                }
            }
            .padding()
            
            List {
                ForEach(comments) { comment in
                    SmartInboxCommentRow(comment: comment)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(PlainListStyle())
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("AI Moderation")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func scanComments() {
        isScanning = true
        
        Task {
            var updatedComments = comments
            
            for i in 0..<updatedComments.count {
                do {
                    let result = try await CommentModerationAIService.shared.analyzeComment(text: updatedComments[i].text)
                    var analysis = SmartInboxCommentAnalysis(status: .safe, reason: nil)
                    switch result {
                    case .safe:
                        analysis.status = .safe
                    case .toxic(let reason):
                        analysis.status = .toxic
                        analysis.reason = reason
                    case .reviewRequired:
                        analysis.status = .reviewRequired
                    }
                    updatedComments[i].analysis = analysis
                    updatedComments[i].isAnalyzed = true
                } catch {
                    updatedComments[i].analysis = SmartInboxCommentAnalysis(status: .reviewRequired, reason: "Error analyzing comment")
                    updatedComments[i].isAnalyzed = true
                }
            }
            
            DispatchQueue.main.async {
                self.comments = updatedComments
                self.isScanning = false
            }
        }
    }
}

struct SmartInboxCommentAnalysis {
    enum Status { case safe, toxic, reviewRequired }
    var status: Status
    var reason: String?
}

struct SmartInboxComment: Identifiable {
    let id = UUID()
    let author: String
    let text: String
    var isAnalyzed: Bool
    var analysis: SmartInboxCommentAnalysis?
}

struct SmartInboxCommentRow: View {
    let comment: SmartInboxComment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("@\(comment.author)")
                    .font(.subheadline.bold())
                    .foregroundColor(.gray)
                
                Spacer()
                
                if comment.isAnalyzed, let analysis = comment.analysis {
                    switch analysis.status {
                    case .safe:
                        Label("Approved", systemImage: "checkmark.shield.fill")
                            .font(.caption.bold())
                            .foregroundColor(.green)
                    case .toxic:
                        Label("Hidden (Toxic)", systemImage: "xmark.shield.fill")
                            .font(.caption.bold())
                            .foregroundColor(.red)
                    case .reviewRequired:
                        Label("Review Needed", systemImage: "exclamationmark.shield.fill")
                            .font(.caption.bold())
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Text(comment.text)
                .font(.body)
                .foregroundColor(comment.analysis?.status == .toxic ? .gray.opacity(0.5) : .white)
                .strikethrough(comment.analysis?.status == .toxic)
            
            if comment.isAnalyzed, let reason = comment.analysis?.reason, comment.analysis?.status != .safe {
                Text("AI Note: \(reason)")
                    .font(.caption)
                    .foregroundColor(.red.opacity(0.8))
                    .padding(6)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(6)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

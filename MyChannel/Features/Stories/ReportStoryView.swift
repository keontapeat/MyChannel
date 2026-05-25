//
//  ReportStoryView.swift
//  MyChannel
//
//  Created by AI Assistant on 11/21/25.
//  🚨 REPORT STORY FEATURE - CONTENT MODERATION
//

import SwiftUI
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

struct ReportStoryView: View {
    let story: Story
    let onReported: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedReason: StoryReportReason?
    @State private var additionalDetails: String = ""
    @State private var isSubmitting: Bool = false
    @State private var showSuccess: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.shield.fill")
                                .font(.system(size: 24))
                                .foregroundColor(AppTheme.Colors.primary)
                            
                            Text("Report Story")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                        }
                        
                        Text("Help us keep MyChannel safe. Your report is anonymous.")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    .padding(.horizontal)
                    
                    // Report reasons
                    VStack(spacing: 12) {
                        ForEach(StoryReportReason.allCases) { reason in
                            reportReasonButton(reason)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Additional details
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Additional Details (Optional)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        TextEditor(text: $additionalDetails)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .frame(height: 100)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(AppTheme.Colors.surface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(AppTheme.Colors.divider.opacity(0.2), lineWidth: 1)
                                    )
                            )
                    }
                    .padding(.horizontal)
                    
                    // Submit button
                    Button(action: submitReport) {
                        HStack(spacing: 8) {
                            if isSubmitting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "flag.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                
                                Text("Submit Report")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedReason != nil ? AppTheme.Colors.primary : AppTheme.Colors.primary.opacity(0.5))
                        )
                    }
                    .disabled(selectedReason == nil || isSubmitting)
                    .padding(.horizontal)
                }
                .padding(.vertical, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Report Submitted", isPresented: $showSuccess) {
                Button("OK") {
                    onReported()
                    dismiss()
                }
            } message: {
                Text("Thank you for helping keep MyChannel safe. We'll review this report and take appropriate action.")
            }
        }
    }
    
    private func reportReasonButton(_ reason: StoryReportReason) -> some View {
        Button {
            selectedReason = reason
            
            // Haptic feedback
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
        } label: {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(selectedReason == reason ? AppTheme.Colors.primary.opacity(0.2) : AppTheme.Colors.surface)
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: reason.iconName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(selectedReason == reason ? AppTheme.Colors.primary : AppTheme.Colors.textPrimary)
                }
                
                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(reason.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text(reason.description)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
                
                // Selection indicator
                if selectedReason == reason {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                selectedReason == reason ? AppTheme.Colors.primary : AppTheme.Colors.divider.opacity(0.2),
                                lineWidth: selectedReason == reason ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func submitReport() {
        guard let reason = selectedReason else { return }
        
        isSubmitting = true
        
        Task {
            await sendReport(reason: reason)
            
            await MainActor.run {
                isSubmitting = false
                showSuccess = true
            }
        }
    }
    
    private func sendReport(reason: StoryReportReason) async {
        #if canImport(FirebaseFirestore)
        guard let userId = Auth.auth().currentUser?.uid else {
            print("🚨 No authenticated user")
            return
        }
        
        let db = Firestore.firestore()
        
        let reportData: [String: Any] = [
            "reporterId": userId,
            "storyId": story.id,
            "creatorId": story.creatorId,
            "reason": reason.rawValue,
            "reasonTitle": reason.title,
            "additionalDetails": additionalDetails,
            "createdAt": FieldValue.serverTimestamp(),
            "status": "pending",
            "reviewed": false
        ]
        
        do {
            try await db.collection("story_reports").addDocument(data: reportData)
            print("✅ Story report submitted: \(story.id)")
        } catch {
            print("🚨 Failed to submit report: \(error)")
        }
        #else
        print("⚠️ Firebase not available - report not submitted")
        #endif
    }
}

// MARK: - Story Report Reason Enum
enum StoryReportReason: String, CaseIterable, Identifiable {
    case spam = "spam"
    case nudity = "nudity"
    case violence = "violence"
    case harassment = "harassment"
    case hate = "hate"
    case misinformation = "misinformation"
    case copyright = "copyright"
    case other = "other"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .spam: return "Spam or Misleading"
        case .nudity: return "Nudity or Sexual Content"
        case .violence: return "Violence or Dangerous Content"
        case .harassment: return "Harassment or Bullying"
        case .hate: return "Hate Speech"
        case .misinformation: return "False Information"
        case .copyright: return "Copyright Violation"
        case .other: return "Something Else"
        }
    }
    
    var description: String {
        switch self {
        case .spam: return "Scams, fake content, or spam"
        case .nudity: return "Inappropriate sexual content"
        case .violence: return "Graphic or threatening content"
        case .harassment: return "Bullying or harassment"
        case .hate: return "Hateful or discriminatory content"
        case .misinformation: return "False or misleading information"
        case .copyright: return "Unauthorized use of copyrighted material"
        case .other: return "Other policy violations"
        }
    }
    
    var iconName: String {
        switch self {
        case .spam: return "envelope.badge.fill"
        case .nudity: return "eye.slash.fill"
        case .violence: return "exclamationmark.triangle.fill"
        case .harassment: return "person.2.slash.fill"
        case .hate: return "hand.raised.fill"
        case .misinformation: return "exclamationmark.bubble.fill"
        case .copyright: return "c.circle.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

#Preview {
    ReportStoryView(
        story: Story(
            creatorId: "test",
            mediaURL: "test",
            mediaType: .image
        ),
        onReported: {}
    )
}


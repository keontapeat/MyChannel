//
//  UniversityCertificateDetailView.swift
//  MyChannel
//
//  Created by AI Assistant
//

import SwiftUI

/// 🎓 CERTIFICATE DETAIL VIEW - Shareable Professional Certificates
/// Shows earned certificate with share to LinkedIn, PDF download, verification QR code
struct UniversityCertificateDetailView: View {
    
    // MARK: - Properties
    let careerPath: CareerPath
    let progress: CareerPathProgress
    let userName: String
    
    @Environment(\.dismiss) private var dismiss
    @State private var isSharing = false
    @State private var certificateImage: UIImage?
    @State private var showShareSheet = false
    
    // MARK: - Body
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Certificate Card
                certificateCard
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                
                // Certificate Info
                certificateInfo
                
                // Action Buttons
                actionButtons
                
                // Verification Section
                verificationSection
                
                Spacer(minLength: 40)
            }
        }
        .navigationTitle("Your Certificate")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = certificateImage {
                NativeShareSheet(items: [image])
            }
        }
    }
    
    // MARK: - Certificate Card
    private var certificateCard: some View {
        ZStack {
            // Background with gradient
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            careerPath.color.opacity(0.15),
                            careerPath.color.opacity(0.05),
                            Color.white
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(careerPath.color.opacity(0.3), lineWidth: 2)
                )
            
            // Certificate Content
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [careerPath.color, careerPath.color.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("Certificate of Completion")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("MyChannel University")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                // Recipient Name
                VStack(spacing: 4) {
                    Text("This certifies that")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    Text(userName)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                
                // Career Path
                VStack(spacing: 4) {
                    Text("has successfully completed")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    Text(careerPath.name)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [careerPath.color, careerPath.color.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                
                // Stats
                HStack(spacing: 20) {
                    statBadge(
                        icon: "clock.fill",
                        value: "\(Int(progress.totalHours))",
                        label: "Hours"
                    )
                    
                    statBadge(
                        icon: "play.rectangle.fill",
                        value: "\(progress.videosWatched)",
                        label: "Videos"
                    )
                    
                    statBadge(
                        icon: "star.fill",
                        value: "\(progress.averageAIScore)",
                        label: "AI Score"
                    )
                }
                
                // Date & Signature
                VStack(spacing: 16) {
                    Divider()
                        .background(careerPath.color.opacity(0.3))
                    
                    HStack(spacing: 40) {
                        // Date
                        VStack(spacing: 4) {
                            Text(progress.certificateEarnedDate?.formatted(date: .abbreviated, time: .omitted) ?? "")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            
                            Text("Date Earned")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                        
                        // Signature
                        VStack(spacing: 4) {
                            Text("MyChannel University")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            
                            Text("Certified Authority")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                    }
                }
            }
            .padding(32)
        }
        .frame(height: 600)
        .onAppear {
            generateCertificateImage()
        }
    }
    
    // MARK: - Stat Badge
    private func statBadge(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(value)
                    .font(.system(size: 18, weight: .bold))
            }
            .foregroundColor(careerPath.color)
            
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(careerPath.color.opacity(0.08))
        )
    }
    
    // MARK: - Certificate Info
    private var certificateInfo: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Certificate Details")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            VStack(spacing: 12) {
                infoRow(icon: "person.fill", label: "Recipient", value: userName)
                infoRow(icon: "briefcase.fill", label: "Career Path", value: careerPath.name)
                infoRow(icon: "calendar.circle.fill", label: "Earned On", value: progress.certificateEarnedDate?.formatted(date: .long, time: .omitted) ?? "")
                infoRow(icon: "checkmark.seal.fill", label: "Certificate ID", value: progress.id)
                infoRow(icon: "chart.line.uptrend.xyaxis", label: "AI Verification", value: "\(progress.averageAIScore)% Score")
            }
        }
        .padding(.horizontal, 20)
    }
    
    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(careerPath.color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                Text(value)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Share to LinkedIn
            Button(action: shareToLinkedIn) {
                HStack(spacing: 12) {
                    Image(systemName: "link.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                    
                    Text("Share to LinkedIn")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Spacer()
                    
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color.blue, Color.blue.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            
            // Download PDF
            Button(action: downloadPDF) {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                    
                    Text("Download PDF")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Spacer()
                }
                .foregroundColor(careerPath.color)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(careerPath.color.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(careerPath.color.opacity(0.3), lineWidth: 1.5)
                        )
                )
            }
            
            // Share Image
            Button(action: { showShareSheet = true }) {
                HStack(spacing: 12) {
                    Image(systemName: "square.and.arrow.up.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                    
                    Text("Share Image")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Spacer()
                }
                .foregroundColor(AppTheme.Colors.textPrimary)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(AppTheme.Colors.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(AppTheme.Colors.divider, lineWidth: 1)
                        )
                )
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Verification Section
    private var verificationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Certificate Verification")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            VStack(spacing: 16) {
                // QR Code (placeholder)
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .overlay(
                        VStack(spacing: 12) {
                            Image(systemName: "qrcode")
                                .font(.system(size: 80, weight: .regular))
                                .foregroundColor(careerPath.color)
                            
                            Text("Scan to Verify")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                    )
                    .frame(height: 200)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                
                // Verification URL
                VStack(spacing: 8) {
                    Text("Verification URL")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    Text("mychannel.live/verify/\(progress.id)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(careerPath.color)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(careerPath.color.opacity(0.08))
                        )
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Actions
    private func shareToLinkedIn() {
        // LinkedIn share URL with pre-filled text
        let text = "I've earned a certificate in \(careerPath.name) from MyChannel University! 🎓 \(Int(progress.totalHours)) hours of learning. #MyChannelUniversity #ContinuousLearning"
        let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let linkedInURL = "https://www.linkedin.com/sharing/share-offsite/?url=mychannel.live&text=\(encodedText)"
        
        if let url = URL(string: linkedInURL) {
            UIApplication.shared.open(url)
        }
    }
    
    private func downloadPDF() {
        print("📄 [Certificate] Download PDF: \(careerPath.name)")
        // TODO: Generate PDF using PDFKit
        // Convert certificate card to PDF and save to Files app
    }
    
    private func generateCertificateImage() {
        // TODO: Render certificate card as UIImage for sharing
        // Use UIGraphicsImageRenderer to capture SwiftUI view
    }
}

// MARK: - Preview
#Preview("iOS Development Certificate") {
    NavigationStack {
        UniversityCertificateDetailView(
            careerPath: CareerPath.allCareerPaths.first { $0.id == "ios-development" }!,
            progress: CareerPathProgress(
                id: "1",
                userId: "user1",
                careerPathId: "ios-development",
                totalHours: 120,
                videosWatched: 45,
                videoIds: ["vid1", "vid2", "vid3"],
                lastWatchedAt: Date(),
                certificateProgress: 0.92,
                certificateEarned: true,
                certificateEarnedDate: Date(),
                averageAIScore: 92,
                skillsCovered: ["swift basics", "swiftui", "app architecture"]
            ),
            userName: "Keonta Peat"
        )
    }
}

#Preview("Accounting Certificate") {
    NavigationStack {
        UniversityCertificateDetailView(
            careerPath: CareerPath.allCareerPaths.first { $0.id == "accounting" }!,
            progress: CareerPathProgress(
                id: "2",
                userId: "user1",
                careerPathId: "accounting",
                totalHours: 250,
                videosWatched: 300,
                videoIds: Array(repeating: "vid", count: 300),
                lastWatchedAt: Date().addingTimeInterval(-86400 * 7),
                certificateProgress: 1.0,
                certificateEarned: true,
                certificateEarnedDate: Date().addingTimeInterval(-86400 * 7),
                averageAIScore: 88,
                skillsCovered: ["accounting basics", "financial statements", "tax preparation"]
            ),
            userName: "Keonta Peat"
        )
    }
}


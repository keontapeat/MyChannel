//
//  CreativeUploadView.swift
//  MyChannel
//
//  CREATIVE UPLOAD SYSTEM
//  Video/image upload with AI analysis & auto-approval
//

import SwiftUI
import PhotosUI

struct CreativeUploadView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = CreativeUploadViewModel()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Upload area
                    uploadArea
                    
                    // Uploaded creatives
                    if !viewModel.uploadedCreatives.isEmpty {
                        uploadedCreativesSection
                    }
                    
                    // Specifications
                    specificationsSection
                }
                .padding(20)
            }
            .navigationTitle("Upload Creative")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .disabled(viewModel.uploadedCreatives.isEmpty)
                }
            }
            .photosPicker(
                isPresented: $viewModel.showPhotoPicker,
                selection: $viewModel.selectedItems,
                maxSelectionCount: 5,
                matching: .any(of: [.images, .videos])
            )
            .onChange(of: viewModel.selectedItems) { _ in
                Task {
                    await viewModel.loadSelectedMedia()
                }
            }
        }
    }
    
    // MARK: - Upload Area
    
    private var uploadArea: some View {
        Button(action: {
            viewModel.showPhotoPicker = true
        }) {
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                }
                
                VStack(spacing: 8) {
                    Text("Upload Creative")
                        .font(.system(size: 18, weight: .semibold))
                    
                    Text("Select video or image files")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    Text("Supports MP4, MOV, JPG, PNG")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 48)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, dash: [8]))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Uploaded Creatives
    
    private var uploadedCreativesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Uploaded Creatives")
                    .font(.system(size: 18, weight: .semibold))
                
                Spacer()
                
                Text("\(viewModel.uploadedCreatives.count)")
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.blue.opacity(0.15)))
                    .foregroundColor(.blue)
            }
            
            ForEach(viewModel.uploadedCreatives) { creative in
                creativeCard(creative)
            }
        }
    }
    
    private func creativeCard(_ creative: UploadedCreative) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Thumbnail
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 200)
                    .overlay(
                        Image(systemName: creative.type == .video ? "play.circle.fill" : "photo.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.white)
                    )
                
                if creative.isAnalyzing {
                    ProgressView()
                        .padding(12)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)
                        .padding(12)
                } else if let score = creative.aiScore {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                        Text("Score: \(Int(score))/100")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(scoreColor(score)))
                    .foregroundColor(.white)
                    .padding(12)
                }
            }
            
            // Info
            VStack(alignment: .leading, spacing: 8) {
                Text(creative.name)
                    .font(.system(size: 16, weight: .semibold))
                
                HStack {
                    Label(creative.type == .video ? "Video" : "Image", systemImage: creative.type == .video ? "video.fill" : "photo.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    
                    if let dimensions = creative.dimensions {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(dimensions)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    if let duration = creative.duration {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text("\(Int(duration))s")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                
                // AI Insights
                if let insights = creative.aiInsights {
                    aiInsightsView(insights)
                }
            }
            
            // Actions
            HStack(spacing: 12) {
                Button(action: {
                    viewModel.editCreative(creative)
                }) {
                    Label("Edit", systemImage: "pencil")
                        .font(.system(size: 14, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(8)
                }
                
                Button(action: {
                    viewModel.removeCreative(creative)
                }) {
                    Label("Remove", systemImage: "trash")
                        .font(.system(size: 14, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(8)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private func aiInsightsView(_ insights: AICreativeInsights) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.purple)
                Text("AI Analysis")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.purple)
            }
            
            ForEach(insights.suggestions, id: \.self) { suggestion in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                    
                    Text(suggestion)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            
            if !insights.warnings.isEmpty {
                ForEach(insights.warnings, id: \.self) { warning in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                        
                        Text(warning)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.purple.opacity(0.05))
        )
    }
    
    private func scoreColor(_ score: Double) -> Color {
        if score >= 80 { return .green }
        if score >= 60 { return .orange }
        return .red
    }
    
    // MARK: - Specifications
    
    private var specificationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Creative Specifications")
                .font(.system(size: 18, weight: .semibold))
            
            VStack(spacing: 12) {
                specRow("Video Formats", value: "MP4, MOV, AVI")
                specRow("Image Formats", value: "JPG, PNG, GIF")
                specRow("Max File Size", value: "100 MB")
                specRow("Video Length", value: "6-60 seconds")
                specRow("Recommended Resolution", value: "1920x1080 (16:9)")
                specRow("Aspect Ratios", value: "16:9, 9:16, 1:1")
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
        }
    }
    
    private func specRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 13, weight: .semibold))
        }
    }
}

// MARK: - View Model

@MainActor
class CreativeUploadViewModel: ObservableObject {
    @Published var uploadedCreatives: [UploadedCreative] = []
    @Published var showPhotoPicker = false
    @Published var selectedItems: [PhotosPickerItem] = []
    
    func loadSelectedMedia() async {
        for item in selectedItems {
            if let data = try? await item.loadTransferable(type: Data.self) {
                await uploadCreative(data: data)
            }
        }
        selectedItems = []
    }
    
    private func uploadCreative(data: Data) async {
        let creative = UploadedCreative(
            id: UUID().uuidString,
            name: "Creative_\(uploadedCreatives.count + 1)",
            type: .video, // Detect from data
            dimensions: "1920x1080",
            duration: 30,
            fileSize: Double(data.count),
            isAnalyzing: true
        )
        
        uploadedCreatives.append(creative)
        
        // Analyze with AI
        await analyzeCreative(creative)
    }
    
    private func analyzeCreative(_ creative: UploadedCreative) async {
        // Simulate AI analysis
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        if let index = uploadedCreatives.firstIndex(where: { $0.id == creative.id }) {
            uploadedCreatives[index].isAnalyzing = false
            uploadedCreatives[index].aiScore = Double.random(in: 70...95)
            uploadedCreatives[index].aiInsights = AICreativeInsights(
                suggestions: [
                    "Great visual appeal - bright colors grab attention",
                    "Clear call-to-action detected",
                    "Professional production quality"
                ],
                warnings: []
            )
            uploadedCreatives[index].isApproved = true
        }
    }
    
    func editCreative(_ creative: UploadedCreative) {
        print("Edit creative: \(creative.name)")
    }
    
    func removeCreative(_ creative: UploadedCreative) {
        uploadedCreatives.removeAll { $0.id == creative.id }
    }
}

// MARK: - Models

struct UploadedCreative: Identifiable {
    let id: String
    var name: String
    let type: CreativeType
    var dimensions: String?
    var duration: TimeInterval?
    let fileSize: Double
    var isAnalyzing: Bool = false
    var aiScore: Double?
    var aiInsights: AICreativeInsights?
    var isApproved: Bool = false
}

// ✅ CreativeType is defined in AdModels.swift

struct AICreativeInsights {
    let suggestions: [String]
    let warnings: [String]
}

#Preview {
    CreativeUploadView()
}


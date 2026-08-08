//
//  ViralPredictorSheet.swift
//  MyChannel
//
//  AI-powered viral score prediction for video concepts.
//  Calls VertexAIAgentService.predictViralScore under the hood.
//

import SwiftUI
import Charts

@MainActor
struct ViralPredictorSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var titleInput = ""
    @State private var categoryInput = ""
    @State private var isAnalyzing = false
    @State private var prediction: VertexAIViralPrediction?
    @State private var errorMessage: String?

    private let categories = ["Entertainment", "Tech", "Education", "Gaming", "Lifestyle",
                               "Music", "Comedy", "Fitness", "Food", "Travel"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // Input form
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Enter your video concept")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Video Title / Concept")
                                .font(.caption.bold())
                                .foregroundColor(AppTheme.Colors.textSecondary)
                            TextField("e.g. 10 Life Hacks That Changed My Life", text: $titleInput)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Category")
                                .font(.caption.bold())
                                .foregroundColor(AppTheme.Colors.textSecondary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(categories, id: \.self) { cat in
                                        Button {
                                            withAnimation { categoryInput = cat }
                                            HapticManager.shared.impact(style: .light)
                                        } label: {
                                            Text(cat)
                                                .font(.caption.bold())
                                                .foregroundColor(categoryInput == cat ? .white : AppTheme.Colors.textPrimary)
                                                .padding(.horizontal, 12).padding(.vertical, 7)
                                                .background(Capsule().fill(categoryInput == cat ? AppTheme.Colors.primary : AppTheme.Colors.surface))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        Button {
                            runPrediction()
                        } label: {
                            HStack {
                                if isAnalyzing {
                                    ProgressView().tint(.white)
                                    Text("Analyzing…")
                                } else {
                                    Image(systemName: "sparkles")
                                    Text("Predict Viral Score")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(titleInput.trimmingCharacters(in: .whitespaces).isEmpty
                                        ? AppTheme.Colors.textTertiary
                                        : AppTheme.Colors.primary)
                            .foregroundColor(.white)
                            .font(.headline)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(titleInput.trimmingCharacters(in: .whitespaces).isEmpty || isAnalyzing)

                        if let err = errorMessage {
                            Text(err).font(.caption).foregroundColor(.red)
                        }
                    }
                    .padding(.horizontal, 24)

                    // Results
                    if let pred = prediction {
                        resultCard(pred)
                    }

                    Spacer(minLength: 32)
                }
                .padding(.vertical, 24)
            }
            .navigationTitle("Viral Predictor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Result card

    @ViewBuilder
    private func resultCard(_ pred: VertexAIViralPrediction) -> some View {
        VStack(spacing: 20) {
            // Score gauge
            VStack(spacing: 8) {
                Text("Viral Score")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.Colors.textSecondary)

                ZStack {
                    Circle()
                        .stroke(AppTheme.Colors.surface, lineWidth: 12)
                        .frame(width: 120, height: 120)
                    Circle()
                        .trim(from: 0, to: Double(pred.viralScore) / 100.0)
                        .stroke(scoreColor(pred.viralScore), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 120, height: 120)
                        .animation(.spring(response: 0.8, dampingFraction: 0.7), value: pred.viralScore)

                    VStack(spacing: 0) {
                        Text("\(pred.viralScore)")
                            .font(.system(size: 34, weight: .bold))
                            .contentTransition(.numericText())
                        Text("/ 100")
                            .font(.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }

                Text(scoreLabel(pred.viralScore))
                    .font(.headline)
                    .foregroundColor(scoreColor(pred.viralScore))

                Text("Confidence: \(Int(pred.confidence * 100))%")
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }

            Divider()

            // Factors
            if !pred.factors.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Positive Factors")
                        .font(.headline)
                        .padding(.horizontal, 24)
                    ForEach(pred.factors, id: \.self) { factor in
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(factor)
                                .font(.subheadline)
                        }
                        .padding(.horizontal, 24)
                    }
                }
            }

            // Tips
            if !pred.optimizationTips.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Optimization Tips")
                        .font(.headline)
                        .padding(.horizontal, 24)
                    ForEach(pred.optimizationTips, id: \.self) { tip in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)
                            Text(tip)
                                .font(.subheadline)
                        }
                        .padding(.horizontal, 24)
                    }
                }
            }
        }
        .padding(.vertical, 20)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 24)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    // MARK: - Helpers

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...100: return .green
        case 60..<80:  return .yellow
        case 40..<60:  return .orange
        default:       return .red
        }
    }

    private func scoreLabel(_ score: Int) -> String {
        switch score {
        case 80...100: return "Highly Viral"
        case 60..<80:  return "Good Potential"
        case 40..<60:  return "Average"
        default:       return "Low Potential"
        }
    }

    private func runPrediction() {
        isAnalyzing = true
        errorMessage = nil
        let title = titleInput.trimmingCharacters(in: .whitespaces)
        let category = categoryInput.isEmpty ? "Entertainment" : categoryInput
        Task {
            do {
                let result = try await VertexAIAgentService.shared.predictViralScore(
                    videoTitle: title,
                    category: category
                )
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    prediction = result
                    isAnalyzing = false
                }
                HapticManager.shared.notification(type: .success)
            } catch {
                errorMessage = error.localizedDescription
                isAnalyzing = false
                HapticManager.shared.notification(type: .error)
            }
        }
    }
}

#Preview {
    ViralPredictorSheet()
}

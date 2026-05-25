//
//  CampaignCreatorView.swift
//  MyChannel
//
//  SELF-SERVE CAMPAIGN CREATOR
//  Create campaigns in 60 seconds - 5-step wizard
//

import SwiftUI

struct CampaignCreatorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = CampaignCreatorViewModel()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress indicator
                progressBar
                
                // Current step
                ScrollView {
                    VStack(spacing: 24) {
                        switch viewModel.currentStep {
                        case .objective:
                            objectiveStep
                        case .audience:
                            targetingStep
                        case .targeting:
                            targetingStep
                        case .budget:
                            budgetStep
                        case .creative:
                            creativeStep
                        case .review:
                            reviewStep
                        }
                    }
                    .padding(20)
                }
                
                // Navigation buttons
                navigationButtons
            }
            .navigationTitle("Create Campaign")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Progress Bar
    
    private var progressBar: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                ForEach(CampaignStep.allCases, id: \.self) { step in
                    Circle()
                        .fill(stepColor(step))
                        .frame(width: 10, height: 10)
                    
                    if step != CampaignStep.allCases.last {
                        Rectangle()
                            .fill(viewModel.currentStep >= step ? Color.blue : Color.gray.opacity(0.3))
                            .frame(height: 2)
                    }
                }
            }
            
            Text("Step \(viewModel.currentStep.number) of 5: \(viewModel.currentStep.title)")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(20)
        .background(Color(.systemBackground))
    }
    
    private func stepColor(_ step: CampaignStep) -> Color {
        if viewModel.currentStep == step {
            return .blue
        } else if viewModel.currentStep > step {
            return .green
        } else {
            return .gray.opacity(0.3)
        }
    }
    
    // MARK: - Step 1: Objective
    
    private var objectiveStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("What's your campaign goal?")
                .font(.system(size: 24, weight: .bold))
            
            Text("Choose the main objective for this campaign")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                objectiveCard(.awareness, icon: "eye.fill", title: "Brand Awareness", description: "Reach as many people as possible")
                objectiveCard(.traffic, icon: "arrow.right.circle.fill", title: "Website Traffic", description: "Drive visitors to your website")
                objectiveCard(.conversions, icon: "cart.fill", title: "Conversions", description: "Get people to take action")
                objectiveCard(.videoViews, icon: "play.circle.fill", title: "Video Views", description: "Get more video views")
                objectiveCard(.appInstalls, icon: "square.and.arrow.down.fill", title: "App Installs", description: "Get more app downloads")
            }
        }
    }
    
    private func objectiveCard(_ objective: CampaignObjective, icon: String, title: String, description: String) -> some View {
        Button(action: {
            viewModel.campaign.objective = objective
        }) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(viewModel.campaign.objective == objective ? Color.blue.opacity(0.15) : Color.gray.opacity(0.1))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(viewModel.campaign.objective == objective ? .blue : .gray)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if viewModel.campaign.objective == objective {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(viewModel.campaign.objective == objective ? Color.blue : Color.gray.opacity(0.3), lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Step 2: Targeting
    
    private var targetingStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Who do you want to reach?")
                .font(.system(size: 24, weight: .bold))
            
            // AI Suggestions
            aiSuggestionCard
            
            // Location
            VStack(alignment: .leading, spacing: 12) {
                Label("Location", systemImage: "location.fill")
                    .font(.system(size: 16, weight: .semibold))
                
                Menu {
                    Button("United States") { viewModel.campaign.targeting.locations = ["US"] }
                    Button("United Kingdom") { viewModel.campaign.targeting.locations = ["UK"] }
                    Button("Canada") { viewModel.campaign.targeting.locations = ["CA"] }
                    Button("Worldwide") { viewModel.campaign.targeting.locations = ["Worldwide"] }
                } label: {
                    HStack {
                        Text(viewModel.campaign.targeting.locations.isEmpty ? "Select location" : viewModel.campaign.targeting.locations.joined(separator: ", "))
                            .foregroundColor(viewModel.campaign.targeting.locations.isEmpty ? .secondary : .primary)
                        Spacer()
                        Image(systemName: "chevron.down")
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray6))
                    )
                }
            }
            
            // Age Range
            VStack(alignment: .leading, spacing: 12) {
                Label("Age Range", systemImage: "person.fill")
                    .font(.system(size: 16, weight: .semibold))
                
                HStack {
                    Picker("Min Age", selection: $viewModel.minAge) {
                        ForEach(18...65, id: \.self) { age in
                            Text("\(age)").tag(age)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Text("to")
                        .foregroundColor(.secondary)
                    
                    Picker("Max Age", selection: $viewModel.maxAge) {
                        ForEach(18...65, id: \.self) { age in
                            Text("\(age)").tag(age)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray6))
                )
            }
            
            // Interests
            VStack(alignment: .leading, spacing: 12) {
                Label("Interests", systemImage: "star.fill")
                    .font(.system(size: 16, weight: .semibold))
                
                TextField("Add interests (e.g., gaming, fitness, travel)", text: $viewModel.interestInput)
                    .textFieldStyle(.roundedBorder)
                
                if !viewModel.campaign.targeting.interests.isEmpty {
                    LegacyFlowLayout(spacing: 8) {
                        ForEach(viewModel.campaign.targeting.interests, id: \.self) { interest in
                            HStack(spacing: 6) {
                                Text(interest)
                                    .font(.system(size: 14))
                                Button(action: {
                                    viewModel.removeInterest(interest)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 14))
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.blue.opacity(0.15)))
                            .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
    }
    
    private var aiSuggestionCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "star.fill")
                .font(.system(size: 20))
                .foregroundColor(.purple)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("AI Suggestion")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.purple)
                
                Text("Target US users aged 18-34 interested in gaming for 30% better ROI")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Apply") {
                viewModel.applyAISuggestion()
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.purple))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.purple.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Step 3: Creative
    
    private var creativeStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Upload your ad creative")
                .font(.system(size: 24, weight: .bold))
            
            Text("Add video or image ads that will be shown to your audience")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
            
            // Upload button
            Button(action: {
                viewModel.showCreativeUpload = true
            }) {
                VStack(spacing: 16) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    
                    Text("Upload Creative")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text("Supports video (MP4, MOV) and images (JPG, PNG)")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, dash: [8]))
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Preview uploaded creatives
            if !viewModel.campaign.creatives.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Uploaded Creatives (\(viewModel.campaign.creatives.count))")
                        .font(.system(size: 16, weight: .semibold))
                    
                    ForEach(viewModel.campaign.creatives) { creative in
                        creativePreviewCard(creative)
                    }
                }
            }
        }
    }
    
    private func creativePreviewCard(_ creative: AdCreative) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 80, height: 60)
                
                Image(systemName: creative.type == .video ? "play.circle.fill" : "photo.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(creative.name)
                    .font(.system(size: 14, weight: .semibold))
                
                Text(creative.type == .video ? "Video • \(creative.duration ?? 0)s" : "Image • \(creative.dimensions)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                viewModel.removeCreative(creative)
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
    }
    
    // MARK: - Step 4: Budget
    
    private var budgetStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Set your budget")
                .font(.system(size: 24, weight: .bold))
            
            // Daily budget
            VStack(alignment: .leading, spacing: 12) {
                Label("Daily Budget", systemImage: "dollarsign.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                
                TextField("Enter amount", text: $viewModel.dailyBudgetText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: viewModel.dailyBudgetText) { newValue in
                        if let value = Double(newValue) {
                            viewModel.campaign.dailyBudget = value
                        }
                    }
                
                Text("Minimum: $20/day")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            // Total budget
            VStack(alignment: .leading, spacing: 12) {
                Label("Total Budget", systemImage: "creditcard.fill")
                    .font(.system(size: 16, weight: .semibold))
                
                TextField("Enter amount", text: $viewModel.totalBudgetText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: viewModel.totalBudgetText) { newValue in
                        if let value = Double(newValue) {
                            viewModel.campaign.totalBudget = value
                        }
                    }
                
                Text("Campaign will stop when this budget is reached")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            // Bid strategy
            VStack(alignment: .leading, spacing: 12) {
                Label("Bid Strategy", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 16, weight: .semibold))
                
                Picker("Bid Strategy", selection: $viewModel.campaign.bidStrategy) {
                    Text("Automatic").tag(BidStrategy.automatic)
                    Text("Target CPA").tag(BidStrategy.targetCPA)
                    Text("Target ROAS").tag(BidStrategy.targetROAS)
                    Text("Manual").tag(BidStrategy.manual)
                }
                .pickerStyle(.segmented)
                
                Text("Lowest cost gets you the most results at the lowest price")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            // ROI Projection
            roiProjectionCard
        }
    }
    
    private var roiProjectionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.green)
                Text("Projected Performance")
                    .font(.system(size: 16, weight: .semibold))
            }
            
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Est. Impressions")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Text(viewModel.projectedImpressions)
                        .font(.system(size: 20, weight: .bold))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Est. Clicks")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Text(viewModel.projectedClicks)
                        .font(.system(size: 20, weight: .bold))
                }
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Est. CPM")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Text("$\(viewModel.projectedCPM)")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Est. ROI")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Text(viewModel.projectedROI)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.green)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Step 5: Review
    
    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Review & Launch")
                .font(.system(size: 24, weight: .bold))
            
            Text("Review your campaign details before launching")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
            
            // Campaign name
            VStack(alignment: .leading, spacing: 8) {
                Text("Campaign Name")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                
                TextField("Enter campaign name", text: $viewModel.campaign.name)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Summary sections
            summarySection("Objective", value: viewModel.campaign.objective.displayName)
            summarySection("Location", value: viewModel.campaign.targeting.locations.joined(separator: ", "))
            summarySection("Age Range", value: "\(viewModel.minAge)-\(viewModel.maxAge)")
            summarySection("Interests", value: "\(viewModel.campaign.targeting.interests.count) selected")
            summarySection("Creatives", value: "\(viewModel.campaign.creatives.count) uploaded")
            summarySection("Daily Budget", value: "$\(Int(viewModel.campaign.dailyBudget))")
            summarySection("Total Budget", value: "$\(Int(viewModel.campaign.totalBudget))")
            
            Divider()
            
            // Terms
            HStack(spacing: 12) {
                Image(systemName: viewModel.acceptedTerms ? "checkmark.square.fill" : "square")
                    .foregroundColor(viewModel.acceptedTerms ? .blue : .gray)
                    .onTapGesture {
                        viewModel.acceptedTerms.toggle()
                    }
                
                Text("I agree to MyChannel's advertising policies and terms of service")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func summarySection(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14, weight: .semibold))
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Navigation Buttons
    
    private var navigationButtons: some View {
        HStack(spacing: 12) {
            if viewModel.currentStep != .objective {
                Button("Back") {
                    viewModel.previousStep()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(.systemGray5))
                .foregroundColor(.primary)
                .cornerRadius(12)
            }
            
            Button(viewModel.currentStep == .review ? "Launch Campaign" : "Continue") {
                if viewModel.currentStep == .review {
                    Task {
                        await viewModel.launchCampaign()
                        dismiss()
                    }
                } else {
                    viewModel.nextStep()
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(viewModel.canProceed ? Color.blue : Color.gray.opacity(0.3))
            .foregroundColor(.white)
            .cornerRadius(12)
            .disabled(!viewModel.canProceed)
        }
        .padding(20)
        .background(Color(.systemBackground))
    }
}

// MARK: - View Model

@MainActor
class CampaignCreatorViewModel: ObservableObject {
    @Published var campaign = CreateCampaignData()
    @Published var currentStep: CampaignStep = .objective
    @Published var showCreativeUpload = false
    @Published var acceptedTerms = false
    
    @Published var minAge = 18
    @Published var maxAge = 65
    @Published var interestInput = ""
    @Published var dailyBudgetText = ""
    @Published var totalBudgetText = ""
    
    var canProceed: Bool {
        switch currentStep {
        case .objective:
            return campaign.objective != .awareness || !campaign.name.isEmpty
        case .audience:
            return true
        case .targeting:
            return !campaign.targeting.locations.isEmpty
        case .budget:
            return campaign.dailyBudget >= 20 && campaign.totalBudget >= 20
        case .creative:
            return !campaign.creatives.isEmpty
        case .review:
            return !campaign.name.isEmpty && acceptedTerms
        }
    }
    
    var projectedImpressions: String {
        let impressions = Int(campaign.totalBudget / 5.0 * 1000)
        return formatNumber(impressions)
    }
    
    var projectedClicks: String {
        let clicks = Int(campaign.totalBudget / 5.0 * 1000 * 0.02)
        return formatNumber(clicks)
    }
    
    var projectedCPM: String {
        return "5.00"
    }
    
    var projectedROI: String {
        return "300%"
    }
    
    func nextStep() {
        let allSteps = CampaignStep.allCases
        guard let currentIndex = allSteps.firstIndex(of: currentStep),
              currentIndex < allSteps.count - 1 else { return }
        currentStep = allSteps[currentIndex + 1]
    }
    
    func previousStep() {
        let allSteps = CampaignStep.allCases
        guard let currentIndex = allSteps.firstIndex(of: currentStep),
              currentIndex > 0 else { return }
        currentStep = allSteps[currentIndex - 1]
    }
    
    func applyAISuggestion() {
        campaign.targeting.locations = ["US"]
        minAge = 18
        maxAge = 34
        campaign.targeting.interests = ["gaming", "technology", "entertainment"]
    }
    
    func removeInterest(_ interest: String) {
        campaign.targeting.interests.removeAll { $0 == interest }
    }
    
    func removeCreative(_ creative: AdCreative) {
        campaign.creatives.removeAll { $0.id == creative.id }
    }
    
    func launchCampaign() async {
        print("🚀 [Campaign] Launching campaign: \(campaign.name)")
        // Save to Firestore
        // Start serving ads immediately
    }
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

// MARK: - Models

struct CreateCampaignData {
    var name = ""
    var objective: CampaignObjective = .awareness
    var targeting = TargetingData()
    var creatives: [AdCreative] = []
    var dailyBudget: Double = 0
    var totalBudget: Double = 0
    var bidStrategy: BidStrategy = .automatic
}

struct TargetingData {
    var locations: [String] = []
    var interests: [String] = []
    var ageMin = 18
    var ageMax = 65
}

// Legacy FlowLayout helper (deprecated - use Core/Components/FlowLayout.swift instead)
struct LegacyFlowLayout<Content: View>: View {
    let spacing: CGFloat
    let content: () -> Content
    
    init(spacing: CGFloat = 8, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }
    
    var body: some View {
        GeometryReader { geometry in
            self.generateContent(in: geometry)
        }
    }
    
    private func generateContent(in geometry: GeometryProxy) -> some View {
        var width: CGFloat = 0
        var height: CGFloat = 0
        
        return ZStack(alignment: .topLeading) {
            content()
        }
    }
}

#Preview {
    CampaignCreatorView()
}


//
//  CreateCampaignView.swift
//  MyChannel
//
//  Campaign Builder - 5-Minute Setup!
//

import SwiftUI

struct CreateCampaignView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: AdvertiserViewModel
    @StateObject private var campaignBuilder = CampaignBuilderViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Progress Indicator
                        progressIndicator
                        
                        // Step Content
                        switch campaignBuilder.currentStep {
                        case .objective:
                            objectiveStep
                        case .audience:
                            audienceStep
                        case .budget:
                            budgetStep
                        case .creative:
                            creativeStep
                        case .review:
                            reviewStep
                        }
                        
                        // Navigation Buttons
                        navigationButtons
                    }
                    .padding()
                }
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
    
    // MARK: - Progress Indicator
    private var progressIndicator: some View {
        VStack(spacing: 12) {
            HStack {
                ForEach(CampaignStep.allCases.indices, id: \.self) { index in
                    Circle()
                        .fill(index <= campaignBuilder.currentStep.rawValue ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 12, height: 12)
                    
                    if index < CampaignStep.allCases.count - 1 {
                        Rectangle()
                            .fill(index < campaignBuilder.currentStep.rawValue ? Color.blue : Color.gray.opacity(0.3))
                            .frame(height: 2)
                    }
                }
            }
            
            Text("Step \(campaignBuilder.currentStep.rawValue + 1) of \(CampaignStep.allCases.count): \(campaignBuilder.currentStep.title)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Step 1: Objective
    private var objectiveStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("What's your campaign objective?")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Choose what you want to achieve")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                ObjectiveOption(
                    icon: "eye.fill",
                    title: "Brand Awareness",
                    description: "Reach the most people",
                    isSelected: campaignBuilder.objective == .awareness
                ) {
                    campaignBuilder.objective = .awareness
                }
                
                ObjectiveOption(
                    icon: "hand.tap.fill",
                    title: "Traffic",
                    description: "Get more clicks to your website",
                    isSelected: campaignBuilder.objective == .traffic
                ) {
                    campaignBuilder.objective = .traffic
                }
                
                ObjectiveOption(
                    icon: "cart.fill",
                    title: "Conversions",
                    description: "Drive sales and sign-ups",
                    isSelected: campaignBuilder.objective == .conversions
                ) {
                    campaignBuilder.objective = .conversions
                }
                
                ObjectiveOption(
                    icon: "play.rectangle.fill",
                    title: "Video Views",
                    description: "Get more people to watch your video",
                    isSelected: campaignBuilder.objective == .videoViews
                ) {
                    campaignBuilder.objective = .videoViews
                }
            }
            
            // Campaign Name
            VStack(alignment: .leading, spacing: 8) {
                Text("Campaign Name")
                    .font(.headline)
                TextField("Enter campaign name", text: $campaignBuilder.campaignName)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.top)
        }
    }
    
    // MARK: - Step 2: Audience
    private var audienceStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Who do you want to reach?")
                .font(.title2)
                .fontWeight(.bold)
            
            // Quick Audience Templates
            VStack(alignment: .leading, spacing: 12) {
                Text("Quick Templates")
                    .font(.headline)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        AudienceTemplateCard(
                            title: "Tech Enthusiasts",
                            size: "2.5M users",
                            icon: "laptopcomputer"
                        ) {
                            campaignBuilder.selectedAudienceTemplate = "tech"
                        }
                        
                        AudienceTemplateCard(
                            title: "Gamers",
                            size: "3.2M users",
                            icon: "gamecontroller.fill"
                        ) {
                            campaignBuilder.selectedAudienceTemplate = "gaming"
                        }
                        
                        AudienceTemplateCard(
                            title: "Fashion Lovers",
                            size: "1.8M users",
                            icon: "sparkles"
                        ) {
                            campaignBuilder.selectedAudienceTemplate = "fashion"
                        }
                        
                        AudienceTemplateCard(
                            title: "Fitness",
                            size: "1.2M users",
                            icon: "figure.run"
                        ) {
                            campaignBuilder.selectedAudienceTemplate = "fitness"
                        }
                    }
                }
            }
            
            // Custom Targeting
            VStack(alignment: .leading, spacing: 16) {
                Text("Custom Targeting")
                    .font(.headline)
                
                // Age
                VStack(alignment: .leading, spacing: 8) {
                    Text("Age Range")
                        .font(.subheadline)
                    HStack {
                        Picker("Min", selection: $campaignBuilder.minAge) {
                            ForEach(13...65, id: \.self) { age in
                                Text("\(age)").tag(age)
                            }
                        }
                        .pickerStyle(.menu)
                        
                        Text("to")
                        
                        Picker("Max", selection: $campaignBuilder.maxAge) {
                            ForEach(13...65, id: \.self) { age in
                                Text("\(age)").tag(age)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                
                // Gender
                VStack(alignment: .leading, spacing: 8) {
                    Text("Gender")
                        .font(.subheadline)
                    Picker("Gender", selection: $campaignBuilder.gender) {
                        Text("All").tag("all")
                        Text("Male").tag("male")
                        Text("Female").tag("female")
                        Text("Other").tag("other")
                    }
                    .pickerStyle(.segmented)
                }
                
                // Locations
                VStack(alignment: .leading, spacing: 8) {
                    Text("Locations")
                        .font(.subheadline)
                    HStack {
                        TextField("Add countries, cities...", text: $campaignBuilder.locationInput)
                            .textFieldStyle(.roundedBorder)
                        Button("Add") {
                            if !campaignBuilder.locationInput.isEmpty {
                                campaignBuilder.locations.append(campaignBuilder.locationInput)
                                campaignBuilder.locationInput = ""
                            }
                        }
                    }
                    
                    CampaignFlowLayout(items: campaignBuilder.locations) { location in
                        HStack(spacing: 4) {
                            Text(location)
                                .font(.caption)
                            Button {
                                campaignBuilder.locations.removeAll { $0 == location }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                    }
                }
                
                // Interests
                VStack(alignment: .leading, spacing: 8) {
                    Text("Interests")
                        .font(.subheadline)
                    HStack {
                        TextField("Add interests...", text: $campaignBuilder.interestInput)
                            .textFieldStyle(.roundedBorder)
                        Button("Add") {
                            if !campaignBuilder.interestInput.isEmpty {
                                campaignBuilder.interests.append(campaignBuilder.interestInput)
                                campaignBuilder.interestInput = ""
                            }
                        }
                    }
                    
                    CampaignFlowLayout(items: campaignBuilder.interests) { interest in
                        HStack(spacing: 4) {
                            Text(interest)
                                .font(.caption)
                            Button {
                                campaignBuilder.interests.removeAll { $0 == interest }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.1))
                        .foregroundColor(.green)
                        .cornerRadius(4)
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            
            // Estimated Reach
            VStack(spacing: 8) {
                HStack {
                    Text("Estimated Daily Reach")
                        .font(.headline)
                    Spacer()
                    Text("\(campaignBuilder.estimatedReach) users")
                        .font(.headline)
                        .foregroundColor(.blue)
                }
                
                Text("Based on your targeting criteria")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Step 3: Budget
    private var budgetStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Set your budget")
                .font(.title2)
                .fontWeight(.bold)
            
            // Budget Type
            Picker("Budget Type", selection: $campaignBuilder.budgetType) {
                Text("Daily").tag(BudgetType.daily)
                Text("Lifetime").tag(BudgetType.lifetime)
            }
            .pickerStyle(.segmented)
            
            // Budget Amount
            VStack(alignment: .leading, spacing: 8) {
                Text(campaignBuilder.budgetType == .daily ? "Daily Budget" : "Total Budget")
                    .font(.headline)
                HStack {
                    Text("$")
                        .font(.title)
                    TextField("0.00", value: $campaignBuilder.budget, format: .number)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 36, weight: .bold))
                        .frame(maxWidth: .infinity)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
            
            // Quick Budget Options
            VStack(alignment: .leading, spacing: 12) {
                Text("Quick Select")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach([50, 100, 250, 500, 1000, 2500], id: \.self) { amount in
                        Button {
                            campaignBuilder.budget = Double(amount)
                        } label: {
                            Text("$\(amount)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(campaignBuilder.budget == Double(amount) ? .white : .primary)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(campaignBuilder.budget == Double(amount) ? Color.blue : Color(.tertiarySystemBackground))
                                .cornerRadius(8)
                        }
                    }
                }
            }
            
            // Schedule
            VStack(alignment: .leading, spacing: 12) {
                Text("Schedule")
                    .font(.headline)
                
                DatePicker("Start Date", selection: $campaignBuilder.startDate, displayedComponents: .date)
                
                Toggle("Set End Date", isOn: $campaignBuilder.hasEndDate)
                
                if campaignBuilder.hasEndDate {
                    DatePicker("End Date", selection: $campaignBuilder.endDate, displayedComponents: .date)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            
            // Bid Strategy
            VStack(alignment: .leading, spacing: 12) {
                Text("Bid Strategy")
                    .font(.headline)
                
                Picker("Strategy", selection: $campaignBuilder.bidStrategy) {
                    Text("Automatic (AI Optimized)").tag(BidStrategy.automatic)
                    Text("Manual Bidding").tag(BidStrategy.manual)
                }
                .pickerStyle(.menu)
                
                if campaignBuilder.bidStrategy == .manual {
                    HStack {
                        Text("Max CPM:")
                        TextField("0.00", value: $campaignBuilder.maxCPM, format: .number)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                
                Text(campaignBuilder.bidStrategy == .automatic ? "AI will automatically adjust bids to get you the best results within your budget" : "You control the maximum amount you'll pay per 1000 impressions")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            
            // Estimated Results
            VStack(spacing: 12) {
                Text("Estimated Results (Per Day)")
                    .font(.headline)
                
                HStack {
                    ResultEstimate(icon: "eye.fill", label: "Impressions", value: campaignBuilder.estimatedImpressions, color: .blue)
                    ResultEstimate(icon: "hand.tap.fill", label: "Clicks", value: campaignBuilder.estimatedClicks, color: .green)
                    ResultEstimate(icon: "cart.fill", label: "Conversions", value: campaignBuilder.estimatedConversions, color: .purple)
                }
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Step 4: Creative
    private var creativeStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Add your creative")
                .font(.title2)
                .fontWeight(.bold)
            
            // Upload Creative
            Button {
                // TODO: Show file picker
            } label: {
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text("Upload Video or Image")
                        .font(.headline)
                    
                    Text("MP4, MOV (max 60s) or JPG, PNG")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(style: StrokeStyle(lineWidth: 2, dash: [10]))
                        .foregroundColor(.blue)
                )
            }
            
            // Creative Details
            VStack(alignment: .leading, spacing: 12) {
                Text("Creative Details")
                    .font(.headline)
                
                TextField("Headline", text: $campaignBuilder.creativeHeadline)
                    .textFieldStyle(.roundedBorder)
                
                TextField("Description", text: $campaignBuilder.creativeDescription)
                    .textFieldStyle(.roundedBorder)
                
                TextField("Call to Action (e.g., 'Shop Now')", text: $campaignBuilder.creativeCTA)
                    .textFieldStyle(.roundedBorder)
                
                TextField("Destination URL", text: $campaignBuilder.creativeURL)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            
            // Preview
            VStack(alignment: .leading, spacing: 12) {
                Text("Preview")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .aspectRatio(16/9, contentMode: .fit)
                        .cornerRadius(8)
                        .overlay(
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.white)
                        )
                    
                    Text(campaignBuilder.creativeHeadline.isEmpty ? "Your headline here" : campaignBuilder.creativeHeadline)
                        .font(.headline)
                    
                    Text(campaignBuilder.creativeDescription.isEmpty ? "Your description here" : campaignBuilder.creativeDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button(campaignBuilder.creativeCTA.isEmpty ? "Learn More" : campaignBuilder.creativeCTA) {
                        // Preview action
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(8)
                }
                .padding()
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(8)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Step 5: Review
    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Review & Launch")
                .font(.title2)
                .fontWeight(.bold)
            
            // Campaign Summary
            VStack(alignment: .leading, spacing: 16) {
                SummaryRow(label: "Campaign Name", value: campaignBuilder.campaignName)
                SummaryRow(label: "Objective", value: campaignBuilder.objective.title)
                SummaryRow(label: "Budget", value: "$\(campaignBuilder.budget, specifier: "%.2f") \(campaignBuilder.budgetType == .daily ? "per day" : "total")")
                SummaryRow(label: "Audience Size", value: "\(campaignBuilder.estimatedReach) users")
                SummaryRow(label: "Start Date", value: campaignBuilder.startDate.formatted(date: .abbreviated, time: .omitted))
                
                if campaignBuilder.hasEndDate {
                    SummaryRow(label: "End Date", value: campaignBuilder.endDate.formatted(date: .abbreviated, time: .omitted))
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            
            // Terms
            HStack(alignment: .top, spacing: 12) {
                Toggle("", isOn: $campaignBuilder.acceptedTerms)
                    .labelsHidden()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("I agree to the Terms of Service and understand that:")
                        .font(.caption)
                    Text("• Campaigns are subject to approval")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("• Minimum spend is $50")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("• Refunds available for unused budget")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            
            // AI Approval
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("AI Pre-Approval Complete")
                        .font(.headline)
                        .foregroundColor(.green)
                }
                
                Text("Your campaign meets all requirements and will go live instantly!")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Navigation Buttons
    private var navigationButtons: some View {
        HStack(spacing: 12) {
            if campaignBuilder.currentStep != .objective {
                Button {
                    withAnimation {
                        campaignBuilder.previousStep()
                    }
                } label: {
                    Text("Back")
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                }
            }
            
            Button {
                if campaignBuilder.currentStep == .review {
                    // Launch campaign
                    campaignBuilder.launchCampaign()
                    dismiss()
                } else {
                    withAnimation {
                        campaignBuilder.nextStep()
                    }
                }
            } label: {
                Text(campaignBuilder.currentStep == .review ? "Launch Campaign 🚀" : "Continue")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(campaignBuilder.canProceed ? Color.blue : Color.gray)
                    .cornerRadius(10)
            }
            .disabled(!campaignBuilder.canProceed)
        }
        .padding(.top)
    }
}

// MARK: - Supporting Views

struct ObjectiveOption: View {
    let icon: String
    let title: String
    let description: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 50)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.secondarySystemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
    }
}

struct AudienceTemplateCard: View {
    let title: String
    let size: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(size)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 120)
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
}

struct CampaignFlowLayout: View {
    let items: [String]
    let itemView: (String) -> AnyView
    
    init(items: [String], @ViewBuilder itemView: @escaping (String) -> some View) {
        self.items = items
        self.itemView = { item in AnyView(itemView(item)) }
    }
    
    var body: some View {
        GeometryReader { geometry in
            self.generateContent(in: geometry)
        }
    }
    
    private func generateContent(in geometry: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero
        
        return ZStack(alignment: .topLeading) {
            ForEach(items, id: \.self) { item in
                itemView(item)
                    .padding([.horizontal, .vertical], 4)
                    .alignmentGuide(.leading, computeValue: { d in
                        if (abs(width - d.width) > geometry.size.width) {
                            width = 0
                            height -= d.height
                        }
                        let result = width
                        if item == items.last {
                            width = 0
                        } else {
                            width -= d.width
                        }
                        return result
                    })
                    .alignmentGuide(.top, computeValue: { d in
                        let result = height
                        if item == items.last {
                            height = 0
                        }
                        return result
                    })
            }
        }
    }
}

struct ResultEstimate: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct SummaryRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}

// MARK: - Campaign Builder ViewModel

@MainActor
class CampaignBuilderViewModel: ObservableObject {
    @Published var currentStep: CampaignStep = .objective
    
    // Step 1: Objective
    @Published var objective: CampaignObjective? = nil
    @Published var campaignName: String = ""
    
    // Step 2: Audience
    @Published var selectedAudienceTemplate: String = ""
    @Published var minAge: Int = 18
    @Published var maxAge: Int = 65
    @Published var gender: String = "all"
    @Published var locations: [String] = []
    @Published var locationInput: String = ""
    @Published var interests: [String] = []
    @Published var interestInput: String = ""
    @Published var estimatedReach: Int = 2500000
    
    // Step 3: Budget
    @Published var budgetType: BudgetType = .daily
    @Published var budget: Double = 100
    @Published var startDate: Date = Date()
    @Published var hasEndDate: Bool = false
    @Published var endDate: Date = Date().addingTimeInterval(30*24*60*60)
    @Published var bidStrategy: BidStrategy = .automatic
    @Published var maxCPM: Double = 10
    
    // Step 4: Creative
    @Published var creativeHeadline: String = ""
    @Published var creativeDescription: String = ""
    @Published var creativeCTA: String = ""
    @Published var creativeURL: String = ""
    
    // Step 5: Review
    @Published var acceptedTerms: Bool = false
    
    var canProceed: Bool {
        switch currentStep {
        case .objective:
            return objective != nil && !campaignName.isEmpty
        case .audience:
            return true
        case .budget:
            return budget >= 50
        case .creative:
            return !creativeHeadline.isEmpty && !creativeURL.isEmpty
        case .review:
            return acceptedTerms
        }
    }
    
    var estimatedImpressions: String {
        let daily = Int(budget * 100)
        return "\(daily/1000)K"
    }
    
    var estimatedClicks: String {
        let daily = Int(budget * 100 * 0.08)
        return "\(daily)"
    }
    
    var estimatedConversions: String {
        let daily = Int(budget * 100 * 0.08 * 0.12)
        return "\(daily)"
    }
    
    func nextStep() {
        if let nextStep = CampaignStep(rawValue: currentStep.rawValue + 1) {
            currentStep = nextStep
        }
    }
    
    func previousStep() {
        if let prevStep = CampaignStep(rawValue: currentStep.rawValue - 1) {
            currentStep = prevStep
        }
    }
    
    func launchCampaign() {
        // TODO: Save to Firestore and start campaign
        print("🚀 Launching campaign: \(campaignName)")
    }
}

enum CampaignStep: Int, CaseIterable {
    case objective = 0
    case audience = 1
    case budget = 2
    case creative = 3
    case review = 4
    
    var title: String {
        switch self {
        case .objective: return "Objective"
        case .audience: return "Audience"
        case .budget: return "Budget"
        case .creative: return "Creative"
        case .review: return "Review"
        }
    }
}

enum CampaignObjective {
    case awareness
    case traffic
    case conversions
    case videoViews
    
    var title: String {
        switch self {
        case .awareness: return "Brand Awareness"
        case .traffic: return "Traffic"
        case .conversions: return "Conversions"
        case .videoViews: return "Video Views"
        }
    }
}

enum BudgetType {
    case daily
    case lifetime
}

enum BidStrategy {
    case automatic
    case manual
}


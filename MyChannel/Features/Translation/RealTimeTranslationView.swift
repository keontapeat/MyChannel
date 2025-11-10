//
//  RealTimeTranslationView.swift
//  MyChannel
//
//  REAL-TIME TRANSLATION - Watch videos in ANY language with live captions
//  100+ languages supported
//  Created for MyChannel by AI Assistant
//

import SwiftUI

struct RealTimeTranslationView: View {
    @StateObject private var viewModel = RealTimeTranslationViewModel()
    @State private var selectedLanguage: TranslationLanguage?
    @State private var showLanguagePicker = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 28) {
                        // Hero Section
                        translationHero
                        
                        // Current Language
                        currentLanguageSection
                        
                        // Quick Languages
                        quickLanguagesSection
                        
                        // Translation Stats
                        statsSection
                        
                        // Features
                        featuresSection
                        
                        // Recently Used Languages
                        recentLanguagesSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("Translation")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showLanguagePicker) {
            LanguagePickerSheet(
                viewModel: viewModel,
                selectedLanguage: $selectedLanguage
            )
        }
        .onAppear {
            Task {
                await viewModel.loadTranslationData()
            }
        }
    }
    
    // MARK: - Hero Section
    private var translationHero: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.2, green: 0.6, blue: 0.9),
                            Color(red: 0.4, green: 0.3, blue: 0.9)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 220)
            
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    Image(systemName: "globe")
                        .font(.system(size: 32, weight: .bold))
                    Text("Translation")
                        .font(.system(size: 28, weight: .bold))
                }
                .foregroundColor(.white)
                
                Text("Watch any video in your language")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white.opacity(0.95))
                
                HStack(spacing: 14) {
                    featureBadge(icon: "brain.head.profile", text: "AI Powered")
                    featureBadge(icon: "bolt.fill", text: "Real-Time")
                    featureBadge(icon: "globe", text: "100+ Languages")
                }
                
                Text("🌍 Breaking language barriers worldwide")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Capsule())
            }
            .padding(24)
        }
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
    
    private func featureBadge(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
            Text(text)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.2))
        .clipShape(Capsule())
    }
    
    // MARK: - Current Language
    private var currentLanguageSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Current Translation Language")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
            
            Button {
                showLanguagePicker = true
            } label: {
                HStack(spacing: 16) {
                    Text(viewModel.currentLanguage.flag)
                        .font(.system(size: 48))
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(viewModel.currentLanguage.name)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Text(viewModel.currentLanguage.nativeName)
                            .font(.system(size: 15))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }
                .padding(20)
                .background(AppTheme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(AppTheme.Colors.primary.opacity(0.3), lineWidth: 2)
                )
            }
        }
    }
    
    // MARK: - Quick Languages
    private var quickLanguagesSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Quick Select")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(viewModel.popularLanguages) { language in
                    QuickLanguageButton(language: language) {
                        viewModel.setCurrentLanguage(language)
                    }
                }
            }
        }
    }
    
    // MARK: - Stats Section
    private var statsSection: some View {
        HStack(spacing: 12) {
            TranslationStatCard(
                icon: "text.bubble.fill",
                value: "\(viewModel.totalTranslations)",
                label: "Translations",
                color: .blue
            )
            
            TranslationStatCard(
                icon: "clock.fill",
                value: "\(viewModel.hoursTranslated)h",
                label: "Hours",
                color: .green
            )
            
            TranslationStatCard(
                icon: "globe",
                value: "\(viewModel.languagesUsed)",
                label: "Languages",
                color: .purple
            )
        }
    }
    
    // MARK: - Features
    private var featuresSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Features")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                TranslationFeatureRow(
                    icon: "waveform",
                    title: "Speech-to-Text",
                    description: "Automatic caption generation in real-time"
                )
                
                TranslationFeatureRow(
                    icon: "text.quote",
                    title: "Live Captions",
                    description: "See translations as the video plays"
                )
                
                TranslationFeatureRow(
                    icon: "speaker.wave.3.fill",
                    title: "Text-to-Speech",
                    description: "Listen to translations in your language"
                )
                
                TranslationFeatureRow(
                    icon: "rectangle.and.pencil.and.ellipsis",
                    title: "Download Transcripts",
                    description: "Save full transcriptions for later"
                )
            }
        }
        .padding(20)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    // MARK: - Recent Languages
    private var recentLanguagesSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Recently Used")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Button {
                    showLanguagePicker = true
                } label: {
                    Text("See All")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
            
            ForEach(viewModel.recentLanguages) { language in
                LanguageRow(language: language) {
                    viewModel.setCurrentLanguage(language)
                }
            }
        }
        .padding(20)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Supporting Views

struct QuickLanguageButton: View {
    let language: TranslationLanguage
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(language.flag)
                    .font(.system(size: 32))
                
                Text(language.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppTheme.Colors.divider.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

struct TranslationStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct TranslationFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.primary.opacity(0.15))
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(AppTheme.Colors.primary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct LanguageRow: View {
    let language: TranslationLanguage
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(language.flag)
                    .font(.system(size: 36))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(language.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text(language.nativeName)
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
                
                Text("\(language.speakers) speakers")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
            .padding(12)
            .background(AppTheme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Language Picker Sheet
struct LanguagePickerSheet: View {
    @ObservedObject var viewModel: RealTimeTranslationViewModel
    @Binding var selectedLanguage: TranslationLanguage?
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    var filteredLanguages: [TranslationLanguage] {
        if searchText.isEmpty {
            return viewModel.allLanguages
        }
        return viewModel.allLanguages.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.nativeName.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    TextField("Search languages", text: $searchText)
                        .font(.system(size: 16))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(AppTheme.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                // Languages List
                List {
                    ForEach(filteredLanguages) { language in
                        Button {
                            viewModel.setCurrentLanguage(language)
                            selectedLanguage = language
                            dismiss()
                        } label: {
                            HStack(spacing: 14) {
                                Text(language.flag)
                                    .font(.system(size: 32))
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(language.name)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(AppTheme.Colors.textPrimary)
                                    
                                    Text(language.nativeName)
                                        .font(.system(size: 14))
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                }
                                
                                Spacer()
                                
                                if language.id == viewModel.currentLanguage.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(AppTheme.Colors.primary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .listRowBackground(AppTheme.Colors.surface)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Select Language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.primary)
                }
            }
        }
    }
}

#Preview {
    RealTimeTranslationView()
}


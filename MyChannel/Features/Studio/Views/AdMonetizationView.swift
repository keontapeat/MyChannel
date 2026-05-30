import SwiftUI
import AVKit
import Combine

// MARK: - Ad Monetization View
struct AdMonetizationView: View {
    @Binding var settings: AdSettings
    @State private var showingAdPreview = false
    
    var body: some View {
        Form {
            Section("Ad Settings") {
                Toggle("Enable Ads on Videos", isOn: $settings.adsEnabled)
                
                if settings.adsEnabled {
                    Toggle("Pre-roll Ads", isOn: $settings.prerollEnabled)
                    Toggle("Mid-roll Ads", isOn: $settings.midrollEnabled)
                    Toggle("Post-roll Ads", isOn: $settings.postrollEnabled)
                    
                    Picker("Ad Frequency", selection: $settings.adFrequency) {
                        Text("Low").tag(AdFrequency.low)
                        Text("Medium").tag(AdFrequency.medium)
                        Text("High").tag(AdFrequency.high)
                    }
                    
                    Toggle("Skippable Ads", isOn: $settings.skippableAds)
                    Toggle("Personalized Ads", isOn: $settings.personalizedAds)
                }
            }
            
            Section("Revenue Share") {
                HStack {
                    Text("Creator Share")
                    Spacer()
                    Text("55%")
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                
                HStack {
                    Text("Platform Share")
                    Spacer()
                    Text("45%")
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
            }
            
            Section("Ad Performance") {
                HStack {
                    Text("Average CPM")
                    Spacer()
                    Text("$2.50")
                        .fontWeight(.semibold)
                }
                
                HStack {
                    Text("Fill Rate")
                    Spacer()
                    Text("85%")
                        .fontWeight(.semibold)
                }
                
                HStack {
                    Text("Viewability Rate")
                    Spacer()
                    Text("92%")
                        .fontWeight(.semibold)
                }
            }
            
            if settings.adsEnabled {
                Section {
                    Button("Preview Ad Experience") {
                        showingAdPreview = true
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .sheet(isPresented: $showingAdPreview) {
            AdPreviewView()
        }
        .onChange(of: settings) { newSettings in
            newSettings.save()
        }
    }
}


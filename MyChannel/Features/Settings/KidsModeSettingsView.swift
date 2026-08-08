//
//  KidsModeSettingsView.swift
//  MyChannel
//
//  Full Kids Mode settings: PIN setup, kid profiles, enter/exit gate.
//

import SwiftUI

@MainActor
struct KidsModeSettingsView: View {
    @StateObject private var service = KidsModeService.shared

    @State private var profiles: [KidProfile] = []
    @State private var isLoadingProfiles = true

    @State private var showingSetPIN = false
    @State private var showingExitPIN = false
    @State private var showingAddProfile = false
    @State private var pinInput = ""
    @State private var confirmPIN = ""
    @State private var pinError: String? = nil
    @State private var profileName = ""
    @State private var selectedAgeBand: KidsAgeBand = .earlyElementary
    @State private var isSavingProfile = false

    private var hasPIN: Bool {
        UserDefaults.standard.string(forKey: "kidsMode.parentPinHash") != nil
    }

    var body: some View {
        List {
            // Status banner
            Section {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(service.isKidsModeActive ? Color.blue.opacity(0.15) : AppTheme.Colors.surface)
                            .frame(width: 52, height: 52)
                        Image(systemName: service.isKidsModeActive ? "figure.child.circle.fill" : "figure.child.circle")
                            .font(.system(size: 28))
                            .foregroundColor(service.isKidsModeActive ? .blue : AppTheme.Colors.textSecondary)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(service.isKidsModeActive ? "Kids Mode is ON" : "Kids Mode is OFF")
                            .font(.system(size: 17, weight: .semibold))
                        if let profile = service.activeProfile {
                            Text("Watching as \(profile.displayName) · \(profile.ageBand.rawValue)")
                                .font(.caption)
                                .foregroundColor(.blue)
                        } else {
                            Text("Filtered content, no personalized ads")
                                .font(.caption)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                    }
                    Spacer()
                    if service.isKidsModeActive {
                        Button("Exit") { showingExitPIN = true }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                            .controlSize(.small)
                    }
                }
                .padding(.vertical, 6)
            }

            // Kid Profiles
            Section("Kid Profiles") {
                if isLoadingProfiles {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    ForEach(profiles) { profile in
                        HStack {
                            Circle()
                                .fill(Color.blue.opacity(0.2))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Text(String(profile.displayName.prefix(1)))
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.blue)
                                )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(profile.displayName)
                                    .font(.system(size: 15, weight: .medium))
                                Text("\(profile.ageBand.rawValue) · Max \(profile.dailyWatchMinutes) min/day")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                            Spacer()
                            if service.activeProfile?.id == profile.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            } else if !service.isKidsModeActive {
                                Button("Enter") {
                                    service.enter(profile)
                                    HapticManager.shared.notification(type: .success)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                }

                Button {
                    showingAddProfile = true
                } label: {
                    Label("Add Kid Profile", systemImage: "plus.circle.fill")
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }

            // Parental PIN
            Section("Parental Controls") {
                Button {
                    showingSetPIN = true
                } label: {
                    HStack {
                        Label(hasPIN ? "Change Parental PIN" : "Set Parental PIN",
                              systemImage: "lock.fill")
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        Spacer()
                        if hasPIN {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 14))
                        }
                    }
                }
            }
        }
        .navigationTitle("Kids Mode")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadProfiles()
        }
        // Set / change PIN sheet
        .sheet(isPresented: $showingSetPIN) {
            setPINSheet
        }
        // Exit Kids Mode PIN gate
        .alert("Enter Parental PIN", isPresented: $showingExitPIN) {
            SecureField("PIN", text: $pinInput)
                .keyboardType(.numberPad)
            Button("Confirm") {
                do {
                    try service.exit(withPIN: pinInput)
                    pinInput = ""
                    HapticManager.shared.notification(type: .success)
                } catch {
                    pinError = "Incorrect PIN."
                    HapticManager.shared.notification(type: .error)
                }
            }
            Button("Cancel", role: .cancel) { pinInput = "" }
        } message: {
            Text("Enter your parental PIN to exit Kids Mode.")
        }
        .alert("Incorrect PIN", isPresented: Binding(get: { pinError != nil }, set: { if !$0 { pinError = nil } })) {
            Button("OK", role: .cancel) {}
        }
        // Add profile sheet
        .sheet(isPresented: $showingAddProfile) {
            addProfileSheet
        }
    }

    // MARK: - Load profiles
    private func loadProfiles() async {
        guard let uid = AppState.shared.currentUser?.id else {
            isLoadingProfiles = false
            return
        }
        isLoadingProfiles = true
        profiles = (try? await service.listProfiles(parentUid: uid)) ?? []
        isLoadingProfiles = false
    }

    // MARK: - Set PIN sheet
    private var setPINSheet: some View {
        NavigationStack {
            Form {
                Section("New PIN") {
                    SecureField("4-digit PIN", text: $pinInput)
                        .keyboardType(.numberPad)
                    SecureField("Confirm PIN", text: $confirmPIN)
                        .keyboardType(.numberPad)
                }
                if let err = pinError {
                    Section {
                        Text(err)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(hasPIN ? "Change PIN" : "Set PIN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        pinInput = ""; confirmPIN = ""; pinError = nil
                        showingSetPIN = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        guard pinInput.count >= 4 else { pinError = "PIN must be at least 4 digits."; return }
                        guard pinInput == confirmPIN else { pinError = "PINs don't match."; return }
                        do {
                            try service.setParentPIN(pinInput)
                            pinInput = ""; confirmPIN = ""; pinError = nil
                            showingSetPIN = false
                            HapticManager.shared.notification(type: .success)
                        } catch {
                            pinError = error.localizedDescription
                        }
                    }
                    .bold()
                    .disabled(pinInput.count < 4 || confirmPIN.count < 4)
                }
            }
        }
    }

    // MARK: - Add Profile sheet
    private var addProfileSheet: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("Name (e.g. Emma)", text: $profileName)
                    Picker("Age Group", selection: $selectedAgeBand) {
                        ForEach(KidsAgeBand.allCases, id: \.self) { band in
                            Text(band.rawValue.capitalized).tag(band)
                        }
                    }
                }
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Max content rating: \(selectedAgeBand.maxContentRating)")
                            .font(.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        Text("Default watch limit: \(selectedAgeBand.dailyWatchMinutesDefault) min/day")
                            .font(.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
            }
            .navigationTitle("New Kid Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { showingAddProfile = false }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        guard let uid = AppState.shared.currentUser?.id,
                              !profileName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        isSavingProfile = true
                        let profile = KidProfile(
                            id: UUID().uuidString,
                            parentUid: uid,
                            displayName: profileName,
                            ageBand: selectedAgeBand,
                            dailyWatchMinutes: selectedAgeBand.dailyWatchMinutesDefault,
                            allowedChannelIds: [],
                            blockedChannelIds: [],
                            createdAt: Date()
                        )
                        Task {
                            try? await service.createProfile(profile)
                            profiles.append(profile)
                            profileName = ""
                            isSavingProfile = false
                            showingAddProfile = false
                            HapticManager.shared.notification(type: .success)
                        }
                    }
                    .bold()
                    .disabled(profileName.trimmingCharacters(in: .whitespaces).isEmpty || isSavingProfile)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        KidsModeSettingsView()
    }
}

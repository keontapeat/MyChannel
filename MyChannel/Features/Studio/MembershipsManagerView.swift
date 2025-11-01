//
//  MembershipsManagerView.swift
//  MyChannel
//
//  Created by AI Assistant on 10/15/25.
//

import SwiftUI

struct MembershipsManagerView: View {
    @EnvironmentObject private var appState: AppState
    @State private var tiers: [MembershipTier] = []
    @State private var showingCreate = false
    @State private var tipsEnabled = true
    @State private var membershipsEnabled = false
    
    var body: some View {
        List {
            Section("Monetization") {
                Toggle("Enable Tips", isOn: Binding(get: { tipsEnabled }, set: { val in Task { try? await toggleTips(val) } }))
                Toggle("Enable Memberships", isOn: Binding(get: { membershipsEnabled }, set: { val in Task { try? await toggleMemberships(val) } }))
            }
            Section("Tiers") {
                ForEach(tiers) { tier in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(tier.name).font(.headline)
                            Spacer()
                            Text(String(format: "$%.2f", tier.price)).font(.subheadline).foregroundStyle(.secondary)
                        }
                        Text(tier.description).font(.caption).foregroundStyle(.secondary)
                        Text(tier.benefits.joined(separator: ", ")).font(.caption2).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { indexSet in tiers.remove(atOffsets: indexSet) }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingCreate = true }) { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showingCreate) { CreateTierSheet { createTier($0) } }
        .navigationTitle("Memberships")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadSettings(); await loadTiers() }
    }
    private func loadSettings() async {
        do {
            let uid = appState.currentUser?.id ?? User.sampleUsers.first?.id ?? ""
            let s = try await PayAPIService.shared.getMonetizationSettings(userId: uid)
            tipsEnabled = s.tipsEnabled
            membershipsEnabled = s.membershipsEnabled
        } catch {
            tipsEnabled = true; membershipsEnabled = false
        }
    }
    private func toggleTips(_ value: Bool) async {
        let uid = appState.currentUser?.id ?? User.sampleUsers.first?.id ?? ""
        do { try await PayAPIService.shared.setTipsEnabled(userId: uid, enabled: value); tipsEnabled = value } catch {}
    }
    private func toggleMemberships(_ value: Bool) async {
        let uid = appState.currentUser?.id ?? User.sampleUsers.first?.id ?? ""
        do { try await PayAPIService.shared.setMembershipsEnabled(userId: uid, enabled: value); membershipsEnabled = value } catch {}
    }

    private func loadTiers() async {
        struct Response: Codable { let tiers: [MembershipTier] }
        do {
            let uid = appState.currentUser?.id ?? User.sampleUsers.first?.id ?? ""
            let resp: Response = try await NetworkService.shared.get(endpoint: .custom("/memberships/\(uid)"), responseType: Response.self)
            tiers = resp.tiers
        } catch {
            tiers = []
        }
    }
    private func createTier(_ tier: MembershipTier) {
        Task {
            struct Req: Codable { let tier: MembershipTier }
            let uid = appState.currentUser?.id ?? User.sampleUsers.first?.id ?? ""
            let _: MessageResponse = try await NetworkService.shared.post(endpoint: .custom("/memberships/\(uid)"), body: Req(tier: tier), responseType: MessageResponse.self)
            await loadTiers()
        }
    }
}

private struct CreateTierSheet: View {
    var onCreate: (MembershipTier) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var price: String = "4.99"
    @State private var desc: String = ""
    @State private var benefits: String = "Badge, Posts"
    @State private var color: String = "blue"
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name", text: $name)
                    TextField("Price", text: $price).keyboardType(.decimalPad)
                    TextField("Description", text: $desc)
                }
                Section("Benefits") {
                    TextField("Comma separated", text: $benefits)
                    TextField("Badge color", text: $color)
                }
            }
            .navigationTitle("New Tier")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") { create() }.disabled(name.isEmpty || Double(price) == nil)
                }
            }
        }
    }
    private func create() {
        let tier = MembershipTier(name: name, description: desc, price: Double(price) ?? 0, benefits: benefits.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }, badgeColor: color)
        onCreate(tier)
        dismiss()
    }
}

#Preview {
    NavigationStack { MembershipsManagerView().environmentObject(AppState()) }
}



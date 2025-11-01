//
//  PayoutSettingsView.swift
//  MyChannel
//
//  Created by AI Assistant on 10/15/25.
//

import SwiftUI

struct PayoutSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var fullName: String = ""
    @State private var bankRouting: String = ""
    @State private var bankAccount: String = ""
    @State private var taxCountry: String = "US"
    @State private var tosAccepted: Bool = false
    @State private var isOpeningConnect: Bool = false
    
    var body: some View {
        Form {
            Section("Legal") {
                TextField("Full legal name", text: $fullName)
                Picker("Tax country", selection: $taxCountry) {
                    Text("United States").tag("US")
                    Text("Canada").tag("CA")
                    Text("United Kingdom").tag("GB")
                }
            }
            Section("Bank account (test)") {
                TextField("Routing number", text: $bankRouting)
                    .keyboardType(.numberPad)
                TextField("Account number", text: $bankAccount)
                    .keyboardType(.numberPad)
            }
            Section {
                Toggle("I accept payout terms", isOn: $tosAccepted)
            }
            Section {
                Button {
                    Task {
                        guard let uid = appState.currentUser?.id ?? User.sampleUsers.first?.id else { return }
                        isOpeningConnect = true
                        do {
                            let url = try await PayAPIService.shared.createConnectLink(userId: uid)
                            await MainActor.run {
                                UIApplication.shared.open(url)
                            }
                        } catch {
                            // Swallow for now; production should show an alert
                        }
                        isOpeningConnect = false
                    }
                } label: {
                    HStack {
                        Image(systemName: "creditcard")
                        Text(isOpeningConnect ? "Opening Stripe…" : "Connect payouts")
                    }
                }
                .disabled(isOpeningConnect)
                Button("Save") {
                    Task {
                        let uid = appState.currentUser?.id ?? User.sampleUsers.first?.id ?? ""
                        struct Req: Codable { let fullName: String; let routing: String; let account: String; let country: String }
                        let _: MessageResponse = try await NetworkService.shared.post(
                            endpoint: .custom("/pay/settings"),
                            body: Req(fullName: fullName, routing: bankRouting, account: bankAccount, country: taxCountry),
                            responseType: MessageResponse.self
                        )
                    }
                }
                    .disabled(!tosAccepted || fullName.isEmpty || bankRouting.isEmpty || bankAccount.isEmpty)
            }
        }
        .navigationTitle("Payout Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { PayoutSettingsView() }
}



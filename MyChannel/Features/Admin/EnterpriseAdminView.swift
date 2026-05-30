//
//  EnterpriseAdminView.swift
//  MyChannel
//
//  Created by Keonta.
//

import SwiftUI

struct EnterpriseAdminView: View {
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Overview")) {
                    HStack {
                        Text("Active Users")
                        Spacer()
                        Text("1,245K")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Total Revenue")
                        Spacer()
                        Text("$1.2M")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Governance")) {
                    NavigationLink(destination: TrustAndSafetyQueueView()) {
                        Label("Trust & Safety Queue", systemImage: "shield.lefthalf.filled")
                    }
                    NavigationLink(destination: Text("Policy Management")) {
                        Label("Policy Configurations", systemImage: "doc.text.fill")
                    }
                    NavigationLink(destination: Text("Access Control")) {
                        Label("Roles & Permissions", systemImage: "person.3.fill")
                    }
                }
            }
            .navigationTitle("Enterprise Admin")
        }
    }
}

//
//  GuildDashboardView.swift
//  MyChannel
//
//  Created by Keonta.
//

import SwiftUI

struct GuildDashboardView: View {
    @StateObject private var guildService = CreatorGuildsService()
    @State private var showingCreateGuild = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Creator Guilds")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("Collaborate & grow together")
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    Spacer()
                    Button(action: { showingCreateGuild = true }) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(AppTheme.Colors.primary)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal)
                
                ForEach(guildService.guilds) { guild in
                    GuildCardView(guild: guild)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .sheet(isPresented: $showingCreateGuild) {
            CreateGuildView(guildService: guildService)
        }
    }
}

struct GuildCardView: View {
    let guild: CreatorGuild
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(guild.name)
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
                Text("\(guild.memberUids.count) Members")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.Colors.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.Colors.primary.opacity(0.1))
                    .cornerRadius(8)
            }
            
            Text(guild.description)
                .font(.subheadline)
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            Divider()
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Revenue Pool")
                        .font(.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    Text(guild.revenuePoolEnabled ? "Enabled" : "Disabled")
                        .font(.headline)
                        .foregroundColor(guild.revenuePoolEnabled ? .green : AppTheme.Colors.textSecondary)
                }
                Spacer()
                Button(action: {}) {
                    Text("View Dashboard")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray5))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct CreateGuildView: View {
    @ObservedObject var guildService: CreatorGuildsService
    @Environment(\.presentationMode) var presentationMode
    
    @State private var name = ""
    @State private var description = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Guild Details")) {
                    TextField("Guild Name", text: $name)
                    TextField("Description", text: $description)
                }
                
                Button(action: {
                    let uid = AuthenticationManager.shared.currentUser?.id ?? ""
                    Task {
                        _ = try? await guildService.createGuild(
                            name: name,
                            description: description,
                            founderUid: uid,
                            revenueModel: .equal
                        )
                    }
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Create Guild")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .foregroundColor(AppTheme.Colors.primary)
                }
                .disabled(name.isEmpty || description.isEmpty)
            }
            .navigationTitle("New Guild")
            .navigationBarItems(leading: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

#Preview {
    GuildDashboardView()
}

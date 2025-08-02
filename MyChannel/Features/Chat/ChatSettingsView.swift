//
//  ChatSettingsView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI

struct ChatSettingsView: View {
    @ObservedObject var chatService: MockLiveChatService
    let streamId: String
    @Environment(\.dismiss) private var dismiss
    @State private var tempSettings: ChatSettings
    
    init(chatService: MockLiveChatService, streamId: String) {
        self.chatService = chatService
        self.streamId = streamId
        self._tempSettings = State(initialValue: chatService.settings)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Chat Moderation")) {
                    Toggle("Slow Mode", isOn: $tempSettings.isSlowMode)
                    
                    if tempSettings.isSlowMode {
                        HStack {
                            Text("Delay")
                            Spacer()
                            Stepper("\(tempSettings.slowModeDelay)s", 
                                   value: $tempSettings.slowModeDelay, 
                                   in: 5...300, 
                                   step: 5)
                        }
                    }
                    
                    Toggle("Subscriber Only", isOn: $tempSettings.isSubscriberOnly)
                    Toggle("Emote Only", isOn: $tempSettings.isEmoteOnly)
                    Toggle("Auto-moderate", isOn: $tempSettings.autoModerate)
                }
                
                Section(header: Text("Content Filtering")) {
                    Toggle("Filter Profanity", isOn: $tempSettings.filterProfanity)
                    Toggle("Filter Spam", isOn: $tempSettings.filterSpam)
                    Toggle("Filter Links", isOn: $tempSettings.filterLinks)
                    Toggle("Require Verification", isOn: $tempSettings.requireVerification)
                }
                
                Section(header: Text("Super Chat")) {
                    Toggle("Enable Super Chat", isOn: $tempSettings.superChatEnabled)
                    
                    if tempSettings.superChatEnabled {
                        HStack {
                            Text("Minimum Amount")
                            Spacer()
                            Text("$\(tempSettings.superChatMinAmount, specifier: "%.0f")")
                        }
                        
                        Slider(value: $tempSettings.superChatMinAmount, 
                               in: 1...100, 
                               step: 1) {
                            Text("Min Amount")
                        }
                    }
                }
                
                Section(header: Text("Statistics")) {
                    HStack {
                        Text("Active Users")
                        Spacer()
                        Text("\(chatService.statistics.activeUsers)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Total Messages")
                        Spacer()
                        Text("\(chatService.statistics.totalMessages)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Messages/Min")
                        Spacer()
                        Text("\(chatService.statistics.messagesPerMinute)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Super Chat Revenue")
                        Spacer()
                        Text("$\(chatService.statistics.superChatRevenue, specifier: "%.2f")")
                            .foregroundColor(.green)
                    }
                }
                
                Section {
                    Button("Reset to Defaults") {
                        tempSettings = ChatSettings.defaultSettings
                    }
                    .foregroundColor(.orange)
                    
                    Button("Clear Chat History") {
                        // Clear chat
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Chat Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        chatService.updateSettings(tempSettings)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    ChatSettingsView(chatService: MockLiveChatService(), streamId: "stream-1")
}
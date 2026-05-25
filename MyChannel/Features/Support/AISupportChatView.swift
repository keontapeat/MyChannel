//
//  AISupportChatView.swift
//  MyChannel
//
//  🤖 AI Support Chat - 24/7 AI-powered support
//  Powered by Support Agent (Vertex AI)
//

import SwiftUI

struct AISupportChatView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var aiService = VertexAIAgentService.shared
    
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isSending = false
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages List
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Welcome message
                        if messages.isEmpty {
                            welcomeMessage
                        }
                        
                        // Chat messages
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                        
                        // Typing indicator
                        if isSending {
                            typingIndicator
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .onChange(of: messages.count) { _ in
                    withAnimation {
                        if let lastMessage = messages.last {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Input Bar
            inputBar
        }
        .navigationTitle("AI Support")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Auto-focus input
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isInputFocused = true
            }
        }
    }
    
    // MARK: - Welcome Message
    
    private var welcomeMessage: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.badge.shield.checkmark")
                .font(.system(size: 60))
                .foregroundColor(AppTheme.Colors.primary)
            
            Text("AI Support Assistant")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Text("I'm here to help 24/7! Ask me anything about MyChannel.")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            
            // Suggested Questions
            VStack(spacing: 12) {
                Text("Try asking:")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                ForEach(suggestedQuestions, id: \.self) { question in
                    Button(action: {
                        inputText = question
                        sendMessage()
                    }) {
                        HStack {
                            Text(question)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppTheme.Colors.primary)
                            Spacer()
                            Image(systemName: "arrow.right.circle")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(AppTheme.Colors.primary)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(AppTheme.Colors.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(AppTheme.Colors.primary.opacity(0.2), lineWidth: 1)
                                )
                        )
                    }
                }
            }
            .padding(.top, 8)
        }
        .padding(.top, 40)
    }
    
    private var suggestedQuestions: [String] {
        [
            "How do I upload a video?",
            "How does monetization work?",
            "What are VS Matches?",
            "How do I get verified?"
        ]
    }
    
    // MARK: - Typing Indicator
    
    private var typingIndicator: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(AppTheme.Colors.textSecondary)
                        .frame(width: 8, height: 8)
                        .opacity(0.6)
                        .animation(
                            .easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                            value: isSending
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(AppTheme.Colors.surface)
            )
            
            Spacer()
        }
    }
    
    // MARK: - Input Bar
    
    private var inputBar: some View {
        HStack(spacing: 12) {
            // Text Input
            TextField("Ask a question...", text: $inputText)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(AppTheme.Colors.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(AppTheme.Colors.surface)
                )
                .focused($isInputFocused)
                .submitLabel(.send)
                .onSubmit {
                    sendMessage()
                }
            
            // Send Button
            Button(action: sendMessage) {
                Image(systemName: isSending ? "hourglass" : "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(inputText.isEmpty ? AppTheme.Colors.textSecondary : AppTheme.Colors.primary)
            }
            .disabled(inputText.isEmpty || isSending)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppTheme.Colors.background)
    }
    
    // MARK: - Actions
    
    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !isSending else { return }
        
        let userMessage = ChatMessage(
            id: UUID().uuidString,
            text: inputText,
            isUser: true,
            timestamp: Date()
        )
        
        messages.append(userMessage)
        let question = inputText
        inputText = ""
        isSending = true
        
        Task {
            do {
                let response = try await aiService.askSupportAgent(
                    userId: appState.currentUser?.id ?? "unknown",
                    question: question
                )
                
                await MainActor.run {
                    let aiMessage = ChatMessage(
                        id: UUID().uuidString,
                        text: response.answer,
                        isUser: false,
                        timestamp: Date(),
                        relatedDocs: response.relatedDocs,
                        nextSteps: response.nextSteps,
                        confidence: response.confidence
                    )
                    messages.append(aiMessage)
                    isSending = false
                }
            } catch {
                print("⚠️ [AI Support] Error: \(error)")
                await MainActor.run {
                    let errorMessage = ChatMessage(
                        id: UUID().uuidString,
                        text: "I'm sorry, I'm having trouble connecting right now. Please try again in a moment.",
                        isUser: false,
                        timestamp: Date()
                    )
                    messages.append(errorMessage)
                    isSending = false
                }
            }
        }
    }
}

// MARK: - Chat Message Model

struct ChatMessage: Identifiable {
    let id: String
    let text: String
    let isUser: Bool
    let timestamp: Date
    var relatedDocs: [String]?
    var nextSteps: [String]?
    var confidence: Double?
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
                // Message Text
                Text(message.text)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(message.isUser ? .white : AppTheme.Colors.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(message.isUser ? AppTheme.Colors.primary : AppTheme.Colors.surface)
                    )
                
                // Next Steps (if available)
                if let nextSteps = message.nextSteps, !nextSteps.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Next Steps:")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        
                        ForEach(nextSteps, id: \.self) { step in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(AppTheme.Colors.primary)
                                
                                Text(step)
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                            }
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                }
                
                // Timestamp
                Text(formatTime(message.timestamp))
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
            
            if !message.isUser {
                Spacer(minLength: 60)
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        AISupportChatView()
            .environmentObject(AppState.shared)
    }
}








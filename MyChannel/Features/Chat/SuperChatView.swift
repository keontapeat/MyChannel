//
//  SuperChatView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI

struct SuperChatView: View {
    let streamId: String
    @ObservedObject var chatService: MockLiveChatService
    @Environment(\.dismiss) private var dismiss
    @State private var message = ""
    @State private var selectedAmount: Double = 5.0
    @State private var isProcessingPayment = false
    @State private var showingPaymentSuccess = false
    
    private let predefinedAmounts: [Double] = [2, 5, 10, 20, 50, 100]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        
                        Text("Super Chat")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Stand out in the chat with a highlighted message that stays pinned for a duration based on your contribution.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    
                    // Amount Selection
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Choose Amount")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                            ForEach(predefinedAmounts, id: \.self) { amount in
                                Button(action: { selectedAmount = amount }) {
                                    VStack(spacing: 4) {
                                        Text("$\(Int(amount))")
                                            .font(.title3)
                                            .fontWeight(.bold)
                                        
                                        Text(highlightDuration(for: amount))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(selectedAmount == amount ? Color.green.opacity(0.2) : Color(.systemGray6))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(selectedAmount == amount ? Color.green : Color.clear, lineWidth: 2)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        // Custom Amount Slider
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Custom Amount: $\(selectedAmount, specifier: "%.0f")")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Slider(value: $selectedAmount, in: 2...200, step: 1)
                                .tint(.green)
                        }
                        .padding(.top)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                    
                    // Message Input
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your Message")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        TextField("Enter your message (optional)", text: $message, axis: .vertical)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .lineLimit(3...6)
                        
                        Text("\(message.count)/200 characters")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                    
                    // Preview
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Preview")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        SuperChatPreview(amount: selectedAmount, message: message.isEmpty ? "Your message will appear here" : message)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                    
                    // Send Button
                    Button(action: sendSuperChat) {
                        HStack {
                            if isProcessingPayment {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            
                            Text(isProcessingPayment ? "Processing..." : "Send Super Chat ($\(selectedAmount, specifier: "%.0f"))")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.green, .green.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: .green.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    .disabled(isProcessingPayment)
                    .padding(.horizontal)
                }
                .padding()
            }
            .navigationTitle("Super Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Super Chat Sent!", isPresented: $showingPaymentSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Thank you for your support! Your message will be highlighted in the chat.")
        }
    }
    
    private func highlightDuration(for amount: Double) -> String {
        switch amount {
        case 2..<5: return "30s highlight"
        case 5..<10: return "1m highlight"
        case 10..<20: return "2m highlight"
        case 20..<50: return "5m highlight"
        case 50..<100: return "10m highlight"
        default: return "15m highlight"
        }
    }
    
    private func sendSuperChat() {
        isProcessingPayment = true
        
        // Simulate payment processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let superChatMessage = ChatMessage(
                streamId: streamId,
                userId: "current-user-id",
                username: "CurrentUser",
                content: message.isEmpty ? "Thanks for the stream!" : message,
                messageType: .superChat,
                superChatAmount: selectedAmount
            )
            
            Task {
                try? await chatService.sendMessage(superChatMessage)
                await MainActor.run {
                    isProcessingPayment = false
                    showingPaymentSuccess = true
                }
            }
        }
    }
}

struct SuperChatPreview: View {
    let amount: Double
    let message: String
    
    private var backgroundColor: Color {
        switch amount {
        case 2..<5: return .blue.opacity(0.1)
        case 5..<10: return .cyan.opacity(0.1)
        case 10..<20: return .green.opacity(0.1)
        case 20..<50: return .yellow.opacity(0.1)
        case 50..<100: return .orange.opacity(0.1)
        default: return .red.opacity(0.1)
        }
    }
    
    private var borderColor: Color {
        switch amount {
        case 2..<5: return .blue
        case 5..<10: return .cyan
        case 10..<20: return .green
        case 20..<50: return .yellow
        case 50..<100: return .orange
        default: return .red
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "dollarsign.circle.fill")
                        .foregroundColor(borderColor)
                    Text("Super Chat")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(borderColor)
                }
                
                Spacer()
                
                Text("$\(amount, specifier: "%.0f")")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(borderColor)
            }
            
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text("U")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("CurrentUser")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(backgroundColor)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: 2)
        )
    }
}

#Preview {
    SuperChatView(streamId: "stream-1", chatService: MockLiveChatService())
}
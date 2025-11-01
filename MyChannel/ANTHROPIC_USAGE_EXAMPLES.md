# Anthropic API Usage Examples for MyChannel

Your Anthropic API key has been securely configured! Here's how to use Claude AI in your app:

## ✅ Configuration Complete

- ✅ API Key stored securely in `Secrets.local.xcconfig`
- ✅ Key accessible via `AppSecrets.anthropicAPIKey`
- ✅ Service ready at `AnthropicService.shared`
- ✅ Protected from Git commits (in `.gitignore`)

## 🚀 Usage Examples

### 1. Basic Message (Simple Text Generation)

```swift
import SwiftUI

struct AIAssistantView: View {
    @StateObject private var aiService = AnthropicService.shared
    @State private var userInput = ""
    @State private var response = ""
    
    var body: some View {
        VStack {
            TextField("Ask Claude...", text: $userInput)
                .textFieldStyle(.roundedBorder)
            
            Button("Send") {
                Task {
                    do {
                        response = try await aiService.sendMessage(userInput)
                    } catch {
                        response = "Error: \(error.localizedDescription)"
                    }
                }
            }
            .disabled(aiService.isLoading)
            
            if aiService.isLoading {
                ProgressView()
            }
            
            Text(response)
                .padding()
        }
        .padding()
    }
}
```

### 2. Generate Video Content Ideas

```swift
struct ContentIdeasView: View {
    @StateObject private var aiService = AnthropicService.shared
    @State private var topic = ""
    @State private var ideas = ""
    
    var body: some View {
        VStack {
            TextField("Video topic...", text: $topic)
                .textFieldStyle(.roundedBorder)
            
            Button("Generate Ideas") {
                Task {
                    do {
                        ideas = try await aiService.generateContentIdeas(
                            for: topic,
                            style: "viral and engaging"
                        )
                    } catch {
                        ideas = "Error: \(error.localizedDescription)"
                    }
                }
            }
            .disabled(aiService.isLoading)
            
            ScrollView {
                Text(ideas)
                    .padding()
            }
        }
        .padding()
    }
}
```

### 3. Improve Video Descriptions

```swift
// In your video upload flow
Task {
    let improvedDescription = try await AnthropicService.shared.improveVideoDescription(
        originalDescription
    )
    descriptionText = improvedDescription
}
```

### 4. Generate Video Titles

```swift
// Generate multiple title options
Task {
    let titleSuggestions = try await AnthropicService.shared.generateVideoTitles(
        for: videoDescription,
        count: 5
    )
    // Parse and show title options to user
}
```

### 5. Advanced: Custom Conversation

```swift
struct CreatorAssistantView: View {
    @State private var conversation: [AnthropicService.Message] = []
    @State private var userInput = ""
    @State private var response = ""
    
    var body: some View {
        VStack {
            ScrollView {
                ForEach(conversation.indices, id: \.self) { index in
                    MessageBubble(message: conversation[index])
                }
            }
            
            HStack {
                TextField("Ask your creator assistant...", text: $userInput)
                
                Button("Send") {
                    Task {
                        // Add user message
                        conversation.append(.init(role: "user", content: userInput))
                        
                        do {
                            let reply = try await AnthropicService.shared.sendConversation(
                                conversation,
                                system: "You are a helpful assistant for content creators on MyChannel."
                            )
                            
                            // Add assistant response
                            conversation.append(.init(role: "assistant", content: reply))
                            response = reply
                            userInput = ""
                        } catch {
                            response = "Error: \(error.localizedDescription)"
                        }
                    }
                }
            }
        }
    }
}
```

## 🎯 Integration Ideas for MyChannel

### 1. **Creator Studio - AI Content Helper**
```swift
// Add to ComprehensiveCreatorStudioView.swift
Button("AI Content Ideas") {
    showAIHelper = true
}
.sheet(isPresented: $showAIHelper) {
    ContentIdeasGeneratorView()
}
```

### 2. **Video Upload - Smart Descriptions**
```swift
// In VideoUploadView.swift
Button("Improve with AI") {
    Task {
        description = try await AnthropicService.shared.improveVideoDescription(description)
    }
}
```

### 3. **Video Upload - Title Generator**
```swift
// Generate clickable titles
Button("Generate Titles") {
    Task {
        titleOptions = try await AnthropicService.shared.generateVideoTitles(
            for: videoDescription
        )
        showTitleOptions = true
    }
}
```

### 4. **Profile Bio Generator**
```swift
// Help creators write better bios
Button("Generate Bio") {
    Task {
        let prompt = "Write a compelling creator bio for: \(creatorStyle)"
        bio = try await AnthropicService.shared.sendMessage(prompt)
    }
}
```

### 5. **Comment Reply Helper**
```swift
// Suggest replies to comments
func generateReply(to comment: String) async throws -> String {
    let prompt = """
    Generate a friendly, engaging reply to this comment on my video:
    "\(comment)"
    Keep it authentic and conversational.
    """
    return try await AnthropicService.shared.sendMessage(prompt)
}
```

## 🔒 Security Notes

- ✅ Your API key is stored in `Secrets.local.xcconfig` (not committed to Git)
- ✅ Never hardcode API keys in source files
- ✅ The key is accessed securely via `AppSecrets.anthropicAPIKey`
- ✅ For production, consider server-side proxy to protect API keys

## 💰 API Usage Tips

1. **Monitor Usage**: Claude API has usage limits and costs
2. **Cache Results**: Store generated content to avoid redundant calls
3. **User Control**: Let users opt-in to AI features
4. **Rate Limiting**: Implement cooldowns between requests

## 📊 Available Models

The service uses `claude-3-5-sonnet-20241022` by default (best balance of speed/quality).

You can change models per request:
```swift
let response = try await AnthropicService.shared.sendMessage(
    "Your prompt",
    model: "claude-3-5-sonnet-20241022", // Current default
    maxTokens: 2048 // Adjust for longer responses
)
```

## 🎉 Ready to Use!

Your Anthropic API integration is complete and ready for Y Combinator demos! This gives MyChannel a competitive edge with AI-powered creator tools.

**Pro tip for YC application**: Highlight this AI integration as a differentiator:
> "MyChannel includes AI-powered creator tools using Claude API to help creators generate content ideas, optimize descriptions, and engage with their audience more effectively."


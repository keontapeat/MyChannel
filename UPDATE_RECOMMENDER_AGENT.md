# 🔄 Update Recommender Agent ID (New Billing Account)

## ⚠️ Situation
Your Recommender Agent was on the old billing account. You need to recreate it on the new billing account and update the ID.

---

## 🚀 Quick Fix (2 Steps)

### Step 1: Recreate Recommender Agent in Vertex AI

1. **Click "Develop agent"** in Vertex AI Agent Engine
2. **Name**: `Recommender Agent`
3. **Paste this prompt**:
```
You are the MyChannel Recommender Agent. Analyze user behavior and recommend the most relevant videos.

User Profile: {{userProfile}}
Watch History: {{watchHistory}}
Current Context: {{currentContext}}

Return top 20 recommended videos with confidence scores.
```
4. **Create/Deploy** the agent
5. **Copy the NEW Agent ID** (UUID format)

### Step 2: Update the Code

**Option A: Using Code (Easiest!)**
```swift
// Just run this with your new Agent ID:
AGIAgentManager.shared.addVertexAIAgentId(
    "agent-001-recommender",
    vertexAIAgentId: "YOUR-NEW-AGENT-ID-HERE"
)
```

**Option B: Manual Update**
Edit `MyChannel/Core/AI/AGIAgentConfig.swift` line 95:
```swift
// OLD:
vertexAIAgentId: "37600385-e2b1-4139-8f0e-a92cd929436f",

// NEW:
vertexAIAgentId: "YOUR-NEW-AGENT-ID-HERE",
```

Also update `MyChannel/Core/Services/VertexAIAgentService.swift` line 38:
```swift
// OLD:
private let recommenderAgentID = "37600385-e2b1-4139-8f0e-a92cd929436f"

// NEW:
private let recommenderAgentID = "YOUR-NEW-AGENT-ID-HERE"
```

---

## ✅ That's It!

Once you update the ID, your Recommender Agent will work with the new billing account!

---

## 📋 After This, Create the Other 5 Agents

Once Recommender is working, create these 5 agents (they're ready to go):
1. Creator Coach Agent
2. CPS Guardian Agent  
3. Support Agent
4. Super AGI Code Debugger
5. Universe Company Agent

Use `QuickAgentSetupView` or `AGIAgentBulkUpdater` to add them all at once!






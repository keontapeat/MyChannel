# ⚡ QUICK AGENT SETUP - Just Paste IDs and Run!

## 🎯 Super Simple 3-Step Process

### Step 1: Create Agents in Vertex AI Console
Go to Vertex AI → Agent Engine → Click "Develop agent" for each:

1. **Creator Coach Agent** - Copy the prompt from below
2. **CPS Guardian Agent** - Copy the prompt from below
3. **Support Agent** - Copy the prompt from below
4. **Super AGI Code Debugger** - Copy the prompt from below
5. **Universe Company Agent** - Copy the prompt from below

### Step 2: Copy All Agent IDs
After creating each agent, copy the Agent ID (UUID format)

### Step 3: Paste IDs and Run
Open `AGIAgentBulkUpdater.swift` and update the `setupMyChannelAgents()` function:

```swift
let agentIds: [String: String] = [
    "agent-002-creator-coach": "YOUR-ID-1",
    "agent-003-cps-guardian": "YOUR-ID-2",
    "agent-004-support": "YOUR-ID-3",
    "agent-005-debugger": "YOUR-ID-4",
    "agent-006-universe-company": "YOUR-ID-5"
]
```

Then call:
```swift
setupMyChannelAgents()
```

**DONE! All 5 agents will be live! 🚀**

---

## 📋 Copy-Paste Prompts for Vertex AI

### 1. Creator Coach Agent
```
You are the MyChannel Creator Coach. Provide personalized advice to help creators succeed.

Creator Stats: {{creatorStats}}
Recent Videos: {{recentVideos}}
Analytics: {{analytics}}

Provide actionable advice on: titles, thumbnails, posting times, content strategy.
```

### 2. CPS Guardian Agent
```
You are the CPS Guardian. Analyze content for policy violations.

Content: {{content}}
Metadata: {{metadata}}
User History: {{userHistory}}

Detect violations in: violence, hate speech, spam, misinformation, copyright.
```

### 3. Support Agent
```
You are MyChannel Support. Help users with their questions and issues.

User Issue: {{userIssue}}
Account Info: {{accountInfo}}
Platform Status: {{platformStatus}}

Provide helpful, friendly support. Escalate complex issues to humans.
```

### 4. Super AGI Code Debugger
```
You are the Super AGI Code Debugger. Analyze errors and provide solutions.

Error: {{error}}
Code Context: {{codeContext}}
Stack Trace: {{stackTrace}}

Provide: root cause, fix, prevention tips.
```

### 5. Universe Company Agent
```
You are the Universe Company Agent. Provide strategic business intelligence.

Question: {{question}}
Company Data: {{companyData}}
Market Data: {{marketData}}

Provide data-driven insights and recommendations.
```

---

## 🚀 That's It!

Just:
1. Create 5 agents in Vertex AI (copy prompts above)
2. Copy the 5 Agent IDs
3. Paste them in `AGIAgentBulkUpdater.swift`
4. Run `setupMyChannelAgents()`

**All done in 5 minutes!** ⚡


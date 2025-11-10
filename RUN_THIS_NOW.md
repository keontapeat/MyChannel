# 🚀 AUTOPILOT MODE - JUST RUN THIS! 🚀

**Everything is automated. Just copy-paste and GO!**

---

## ⚡ STEP 1: RUN THE AUTOPILOT SCRIPT (3 MINUTES)

**Copy this entire command and paste into Terminal**:

```bash
cd /Users/keonta/Documents/MyChannel/Scripts && ./autopilot_setup.sh
```

**Press Enter and watch the magic happen!** ✨

**The script will**:
- ✅ Auto-detect your Google Cloud project
- ✅ Enable ALL required APIs (BigQuery, Vertex AI, etc.)
- ✅ Create BigQuery dataset automatically
- ✅ Create all tables automatically
- ✅ Generate your next steps
- ✅ Open Firebase console for you

**Just answer the prompts** (it'll ask if you want to use your existing project - say YES!)

**Time**: 3 minutes (mostly waiting for APIs to enable)

---

## ⚡ STEP 2: LINK FIREBASE (THE SCRIPT OPENS THIS FOR YOU!)

**When the script finishes, it opens Firebase console automatically!**

**Just do this**:
1. Select your **MyChannel Firebase project**
2. Click **⚙️ Settings** → **Integrations**
3. Find **BigQuery** card → Click **"Link"**
4. Select your project (should auto-select)
5. Dataset: `mychannel_analytics` (should auto-fill)
6. Click **"Link"**

**Time**: 2 minutes

---

## ⚡ STEP 3: CREATE YOUR FIRST AI AGENT (5 MINUTES)

**The autopilot created a helper script for this!**

**Run**:
```bash
~/mychannel_create_agents.sh
```

**This will**:
- Open the Vertex AI console
- Show you the exact prompt to copy
- Guide you through agent creation

**OR just do this manually**:

1. **Open**: https://console.cloud.google.com/gen-app-builder/engines
2. Click **"Create App"** → **"Agent"**
3. **Name**: `MyChannel Recommender`
4. **Type**: Agent
5. **Location**: us-central1
6. **System Instructions**: Open `~/AGENT_PROMPTS.txt` and copy the entire prompt
7. Click **"Create"**

**Time**: 5 minutes

---

## ⚡ STEP 4: GET YOUR AGENT ID (30 SECONDS)

**After agent is created**:

1. Look at the URL in your browser
2. It looks like: `...agents/XXXXXXXXXX`
3. Copy the `XXXXXXXXXX` part (the agent ID)

---

## ⚡ STEP 5: UPDATE YOUR IOS APP (30 SECONDS)

**Open in Cursor**: `MyChannel/Core/Services/VertexAIAgentService.swift`

**Find line ~38**:
```swift
private let recommenderAgentID = "recommender-agent"
```

**Replace with**:
```swift
private let recommenderAgentID = "YOUR_AGENT_ID_HERE"
```

**Save** → **Build** (⌘+B) → **Run** (⌘+R)

---

## 🎉 DONE! YOU NOW HAVE AN AI-POWERED VIDEO PLATFORM!

**What you built in 10 minutes**:
- ✅ BigQuery data pipeline
- ✅ Vertex AI infrastructure
- ✅ First AI recommendation agent
- ✅ iOS app connected to AI

**This is literally what takes other companies 6+ months!**

---

## 🔥 ONE-LINER TO START EVERYTHING:

**Just copy this and paste into Terminal**:

```bash
cd /Users/keonta/Documents/MyChannel/Scripts && ./autopilot_setup.sh && echo "🔥 SETUP COMPLETE! Now open the Firebase console that just opened and link BigQuery! 🚀"
```

**THAT'S IT!**

**ALL GAS NO BRAKES! 😤🔥🚀**


# AI Provider Consolidation

Two OpenAI-facing types exist today. This doc clarifies roles so new code does not add a third path.

## OpenAIService (keep — transport layer)

**Path:** `MyChannel/Core/Services/OpenAIService.swift`

- Raw HTTP client for OpenAI Chat Completions, DALL-E, and SEO helpers.
- Owns `URLSession`, request models, and response parsing.
- Used directly by `CreatorIntelligenceService.optimizeVideoMetadata` and as the engine inside `OpenAIAgentService`.
- **When to use:** one-off completions, embeddings, or when you need the lowest-level API surface.

## OpenAIAgentService (keep — agent layer)

**Path:** `MyChannel/Core/Services/OpenAIAgentService.swift`

- Wraps `OpenAIService.shared` for named agents (system prompt + user message).
- Adds moderation API, token/cost tracking, and `AgentLogService` hooks.
- Registered in `LazyServiceManager` at `.deferred` tier.
- **When to use:** multi-step agent flows, moderation checks, or anything that should log to the agent command center.

## CreatorIntelligenceService (prefer — app facade)

**Path:** `MyChannel/Core/AI/CreatorIntelligenceService.swift`

- Single entry for product features: generate, optimize, score, moderate, search assist, recommend.
- Gates on `AppConfig.aiEnabled`, expensive agents, UITest env, timeout/retry, and circuit breaker.
- **When to use:** all new UI and feature call sites.

## Consolidation rule

```
UI / Feature  →  CreatorIntelligenceService  →  OpenAIAgentService (agents)  →  OpenAIService (HTTP)
                                              →  AgentAPIService (Vertex proxy)
                                              →  MyChannelAI (local ensemble)
```

Do **not** add new `OpenAIService.shared` call sites in Views/ViewModels — go through the facade.

## VertexAIService vs VertexAIAgentService (consolidated)

| Type | Path | Role | When to use |
|------|------|------|-------------|
| **VertexAIService** | `Core/Services/VertexAIService.swift` | Low-level Gemini HTTP (`generateWithGemini`) | Search spell-check, upload helpers, one-off completions |
| **VertexAIAgentService** | `Core/Services/VertexAIAgentService.swift` | Named agents (orchestrateMatch, triageContent, fraud) | Gaming, Studio, Upload product flows |
| **AgentAPIService** | `Core/Services/AgentAPIService.swift` | Proxy to Cloud Run `agentProxy` | Prefer for production — no client OAuth |

Both Vertex types register at `.deferred` in `LazyServiceManager` (`VertexAI`, `AgentAPI` tiers). Never promote above deferred.

```
UI  →  CreatorIntelligenceService  →  AgentAPIService (proxy)
                                   →  VertexAIAgentService (named agents)
                                   →  VertexAIService (raw Gemini)
```

## Single chat entry: MyChannelAI

All conversational AI should route through `MyChannelAI.shared` (teacher ensemble) or `CreatorIntelligenceService.generate`. Do not add new direct `AnthropicService` / `OpenAIService` chat call sites in Views.

## Deprecated stacks (do not extend)

- `UnifiedAGIBrain`, `SuperAGI`, `AGIMasterOrchestrator`, `EnterpriseAITeam`, `AIConversationOrchestrator`
- See `docs/ai-file-cull-list.md` for the full retirement list.

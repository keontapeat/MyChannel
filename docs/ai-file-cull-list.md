# AI File Cull List (documentation only — no deletes)

Legacy orchestrators and duplicate AGI stacks slated for retirement once call sites migrate to `CreatorIntelligenceService`. **Do not delete** until migration is complete and tests pass.

## Deprecated orchestrators (use `CreatorIntelligenceService`)

| File | Type | Status |
|------|------|--------|
| `MyChannel/Core/Services/AGIMasterOrchestrator.swift` | Master coordinator | `@available(*, deprecated)` |
| `MyChannel/Core/Services/EnterpriseAITeam.swift` | Virtual employee team | `@available(*, deprecated)` |
| `MyChannel/Core/Services/AIConversationOrchestrator.swift` | Multi-model debates | `@available(*, deprecated)` |
| `MyChannel/Core/AI/UnifiedAGIBrain.swift` | Unified AGI brain | `@available(*, deprecated)` |
| `MyChannel/Core/AI/SuperAGI.swift` | Superhuman stack | `@available(*, deprecated)` |

## Secondary candidates (audit before removal)

| File | Notes |
|------|-------|
| `MyChannel/Core/Services/ChannelMindAGI.swift` | Only referenced by deprecated orchestrators |
| `MyChannel/Core/Services/AISwarmIntelligence.swift` | Swarm layer; no new call sites |
| `MyChannel/Core/Services/AICrystalBall.swift` | Trend predictor stub |
| `MyChannel/Core/Services/AIEvolutionEngine.swift` | Self-improve loop stub |
| `MyChannel/Core/Services/MetaLearningEngine.swift` | Meta-learner stub |
| `MyChannel/Core/Services/SuperAITeamService.swift` | Overlaps EnterpriseAITeam |
| `MyChannel/Features/Gaming/GamingAIOrchestrator.swift` | Gaming-specific; keep until esports AI migrates |
| `MyChannel/Core/AI/VertexAI/VertexAIManager.swift` | Deferred init only; gated by `enableVertexAI` |

## Safe to keep (active path)

| File | Role |
|------|------|
| `MyChannel/Core/AI/CreatorIntelligenceService.swift` | **Canonical facade** for new AI work |
| `MyChannel/Core/Services/MyChannelAI.swift` | Teacher ensemble / local model (deferred, `aiEnabled` gated) |
| `MyChannel/Core/Services/OpenAIService.swift` | Low-level OpenAI HTTP client |
| `MyChannel/Core/Services/OpenAIAgentService.swift` | Agent prompts + moderation (wraps OpenAIService) |
| `MyChannel/Core/Services/AgentAPIService.swift` | Vertex agent proxy (deferred tier) |

## Migration checklist

1. Grep for imports/usages of deprecated types before any file removal.
2. Route new features through `CreatorIntelligenceService` only.
3. Keep `LazyServiceManager` AI registrations at `.deferred`.
4. Update `docs/ai-agi-callsite-map.md` when a call site moves.

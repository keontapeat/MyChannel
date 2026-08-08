// AGI Agent Manager - Centralized management for all 30 agents

import type { AGIAgent } from '@/types';

// Money Maker Agents
import { dynamicPricingAgent } from './money-maker/DynamicPricingAgent';
import { adBiddingAgent } from './money-maker/AdBiddingAgent';
import { revenueMaximizerAgent } from './money-maker/RevenueMaximizerAgent';
import { creatorPayoutAgent } from './money-maker/CreatorPayoutAgent';
import { subscriptionOptimizerAgent } from './money-maker/SubscriptionOptimizer';
// Growth Agents
import { viralPredictionAgent } from './growth/ViralPredictionAgent';
import { retentionPredictorAgent } from './growth/RetentionPredictorAgent';
import { onboardingOptimizerAgent } from './growth/OnboardingOptimizer';
import { subscriberGrowthAgent } from './growth/SubscriberGrowthAgent';
// Gaming Agents
import { matchOrchestratorAgent } from './gaming/MatchOrchestratorAgent';
import { antiCheatAgent } from './gaming/AntiCheatAgent';
import { fairnessAgent } from './gaming/FairnessAgent';
import { tournamentAgent } from './gaming/TournamentAgent';
// Safety Agents
import { contentModerationAgent } from './safety/ContentModerationAgent';
import { fraudDetectionAgent } from './safety/FraudDetectionAgent';
import { copyrightDetectionAgent } from './safety/CopyrightDetectionAgent';
import { toxicityFilterAgent } from './safety/ToxicityFilterAgent';
import { ageVerificationAgent } from './safety/AgeVerificationAgent';
// Analytics Agents
import { creatorAnalyticsAgent } from './analytics/CreatorAnalyticsAgent';
import { watchTimeAnalyticsAgent } from './analytics/WatchTimeAnalyticsAgent';
import { thumbnailOptimizerAgent } from './analytics/ThumbnailOptimizerAgent';
import { audienceInsightsAgent } from './analytics/AudienceInsightsAgent';
// Scale Agents
import { cdnOptimizerAgent } from './scale/CDNOptimizerAgent';
import { costOptimizerAgent } from './scale/CostOptimizerAgent';
import { smartNotificationAgent } from './scale/SmartNotificationAgent';
import { autoScalerAgent } from './scale/AutoScalerAgent';

export class AGIAgentManager {
  private static instance: AGIAgentManager;
  private agents: Map<string, any> = new Map();

  private constructor() {
    this.registerAgents();
  }

  static getInstance(): AGIAgentManager {
    if (!AGIAgentManager.instance) {
      AGIAgentManager.instance = new AGIAgentManager();
    }
    return AGIAgentManager.instance;
  }

  // Register all agents
  private registerAgents(): void {
    // ── Money Maker Agents ──────────────────────────────────────────────────
    this.registerAgent(dynamicPricingAgent);
    this.registerAgent(adBiddingAgent);
    this.registerAgent(revenueMaximizerAgent);
    this.registerAgent(creatorPayoutAgent);
    this.registerAgent(subscriptionOptimizerAgent);

    // ── Growth Agents ───────────────────────────────────────────────────────
    this.registerAgent(viralPredictionAgent);
    this.registerAgent(retentionPredictorAgent);
    this.registerAgent(onboardingOptimizerAgent);
    this.registerAgent(subscriberGrowthAgent);

    // ── Gaming Agents ───────────────────────────────────────────────────────
    this.registerAgent(matchOrchestratorAgent);
    this.registerAgent(antiCheatAgent);
    this.registerAgent(fairnessAgent);
    this.registerAgent(tournamentAgent);

    // ── Safety Agents ───────────────────────────────────────────────────────
    this.registerAgent(contentModerationAgent);
    this.registerAgent(fraudDetectionAgent);
    this.registerAgent(copyrightDetectionAgent);
    this.registerAgent(toxicityFilterAgent);
    this.registerAgent(ageVerificationAgent);

    // ── Analytics Agents ────────────────────────────────────────────────────
    this.registerAgent(creatorAnalyticsAgent);
    this.registerAgent(watchTimeAnalyticsAgent);
    this.registerAgent(thumbnailOptimizerAgent);
    this.registerAgent(audienceInsightsAgent);

    // ── Scale Agents ─────────────────────────────────────────────────────────
    this.registerAgent(cdnOptimizerAgent);
    this.registerAgent(costOptimizerAgent);
    this.registerAgent(smartNotificationAgent);
    this.registerAgent(autoScalerAgent);

    console.log(`🤖 [AGIAgentManager] Registered ${this.agents.size} agents`);
  }

  // Register an agent
  private registerAgent(agent: any): void {
    const info = agent.getInfo();
    this.agents.set(info.id, agent);
  }

  // Get all agents
  getAllAgents(): AGIAgent[] {
    return Array.from(this.agents.values()).map((agent) => agent.getInfo());
  }

  // Get agents by category
  getAgentsByCategory(category: AGIAgent['category']): AGIAgent[] {
    return this.getAllAgents().filter((agent) => agent.category === category);
  }

  // Get agent by ID
  getAgent(agentId: string): any | null {
    return this.agents.get(agentId) || null;
  }

  // Get agent info by ID
  getAgentInfo(agentId: string): AGIAgent | null {
    const agent = this.agents.get(agentId);
    return agent ? agent.getInfo() : null;
  }

  // Start agent
  async startAgent(agentId: string): Promise<void> {
    const agent = this.agents.get(agentId);
    if (agent) {
      await agent.start();
      console.log(`✅ [AGIAgentManager] Started agent: ${agentId}`);
    } else {
      console.error(`🚨 [AGIAgentManager] Agent not found: ${agentId}`);
    }
  }

  // Stop agent
  stopAgent(agentId: string): void {
    const agent = this.agents.get(agentId);
    if (agent) {
      agent.stop();
      console.log(`🛑 [AGIAgentManager] Stopped agent: ${agentId}`);
    } else {
      console.error(`🚨 [AGIAgentManager] Agent not found: ${agentId}`);
    }
  }

  // Pause agent
  pauseAgent(agentId: string): void {
    const agent = this.agents.get(agentId);
    if (agent) {
      agent.pause();
      console.log(`⏸️ [AGIAgentManager] Paused agent: ${agentId}`);
    } else {
      console.error(`🚨 [AGIAgentManager] Agent not found: ${agentId}`);
    }
  }

  // Resume agent
  async resumeAgent(agentId: string): Promise<void> {
    const agent = this.agents.get(agentId);
    if (agent) {
      await agent.resume();
      console.log(`▶️ [AGIAgentManager] Resumed agent: ${agentId}`);
    } else {
      console.error(`🚨 [AGIAgentManager] Agent not found: ${agentId}`);
    }
  }

  // Start all agents
  async startAllAgents(): Promise<void> {
    console.log('🚀 [AGIAgentManager] Starting all agents...');
    for (const agent of this.agents.values()) {
      await agent.start();
    }
    console.log('✅ [AGIAgentManager] All agents started');
  }

  // Stop all agents
  stopAllAgents(): void {
    console.log('🛑 [AGIAgentManager] Stopping all agents...');
    for (const agent of this.agents.values()) {
      agent.stop();
    }
    console.log('✅ [AGIAgentManager] All agents stopped');
  }

  // Get total metrics across all agents
  getTotalMetrics(): {
    totalRuns: number;
    successCount: number;
    errorCount: number;
    totalRevenue: number;
    totalImpressions: number;
    avgResponseTime: number;
  } {
    let totalRuns = 0;
    let successCount = 0;
    let errorCount = 0;
    let totalRevenue = 0;
    let totalImpressions = 0;
    let avgResponseTime = 0;

    for (const agent of this.agents.values()) {
      const metrics = agent.getMetrics();
      totalRuns += metrics.totalRuns;
      successCount += metrics.successCount;
      errorCount += metrics.errorCount;
      totalRevenue += metrics.revenue;
      totalImpressions += metrics.impressions;
      avgResponseTime += metrics.avgResponseTime;
    }

    return {
      totalRuns,
      successCount,
      errorCount,
      totalRevenue,
      totalImpressions,
      avgResponseTime: avgResponseTime / this.agents.size,
    };
  }

  // Get system health status
  getSystemHealth(): {
    status: 'healthy' | 'degraded' | 'critical';
    activeAgents: number;
    pausedAgents: number;
    stoppedAgents: number;
    errorAgents: number;
  } {
    const agents = this.getAllAgents();

    const activeAgents = agents.filter((a) => a.status === 'running').length;
    const pausedAgents = agents.filter((a) => a.status === 'paused').length;
    const stoppedAgents = agents.filter((a) => a.status === 'stopped').length;
    const errorAgents = agents.filter((a) => a.status === 'error').length;

    let status: 'healthy' | 'degraded' | 'critical' = 'healthy';

    if (errorAgents > 0) {
      status = 'degraded';
    }

    if (errorAgents > agents.length * 0.3) {
      // More than 30% in error
      status = 'critical';
    }

    return {
      status,
      activeAgents,
      pausedAgents,
      stoppedAgents,
      errorAgents,
    };
  }

  // Agent categories and their expected counts
  static readonly AGENT_CATEGORIES = {
    money_maker: 5,
    growth: 4,
    gaming: 5,
    safety: 5,
    analytics: 5,
    scale: 6,
  };

  // Get category summary
  getCategorySummary(): Record<AGIAgent['category'], { total: number; active: number }> {
    const summary: any = {};

    for (const category in AGIAgentManager.AGENT_CATEGORIES) {
      const agents = this.getAgentsByCategory(category as AGIAgent['category']);
      summary[category] = {
        total: agents.length,
        active: agents.filter((a) => a.isActive).length,
      };
    }

    return summary;
  }
}

// Export singleton instance
export const agiAgentManager = AGIAgentManager.getInstance();


// Base AGI Agent Class for MyChannel Web Platform

import { getVertexAI, defaultGenerationConfig, safetySettings } from './config';
import type { AGIAgent, AGIAgentMetrics, AGIAgentConfig, AGIAgentStatus } from '@/types';

export abstract class BaseAgent {
  protected model: any;
  protected metrics: AGIAgentMetrics;
  protected config: AGIAgentConfig;
  protected isActive: boolean = false;
  protected status: AGIAgentStatus = 'stopped';
  protected runInterval: NodeJS.Timeout | null = null;

  constructor(
    protected id: string,
    protected name: string,
    protected description: string,
    protected modelName: string,
    config?: Partial<AGIAgentConfig>
  ) {
    this.config = {
      id: this.id,
      runInterval: config?.runInterval || 300, // 5 minutes default
      requiresNetwork: config?.requiresNetwork ?? true,
      requiresAuth: config?.requiresAuth ?? true,
      modelName: this.modelName,
      endpoint: config?.endpoint,
    };

    this.metrics = {
      totalRuns: 0,
      successCount: 0,
      errorCount: 0,
      revenue: 0,
      impressions: 0,
      avgResponseTime: 0,
    };

    // Initialize Vertex AI model (client-side safe)
    if (typeof window !== 'undefined') {
      try {
        const vertexAI = getVertexAI();
        this.model = vertexAI.preview.getGenerativeModel({
          model: this.modelName,
          generationConfig: defaultGenerationConfig,
          safetySettings: safetySettings as any,
        });
      } catch (error) {
        console.error(`🚨 [${this.name}] Failed to initialize model:`, error);
      }
    }
  }

  // Start the agent
  async start(): Promise<void> {
    if (this.isActive) {
      console.log(`⚠️ [${this.name}] Already running`);
      return;
    }

    this.isActive = true;
    this.status = 'running';
    this.metrics.startTime = new Date();

    console.log(`✅ [${this.name}] Agent started`);

    // Start agent loop
    this.runAgentLoop();
  }

  // Stop the agent
  stop(): void {
    if (!this.isActive) {
      console.log(`⚠️ [${this.name}] Already stopped`);
      return;
    }

    this.isActive = false;
    this.status = 'stopped';

    if (this.runInterval) {
      clearInterval(this.runInterval);
      this.runInterval = null;
    }

    console.log(`🛑 [${this.name}] Agent stopped`);
  }

  // Pause the agent
  pause(): void {
    this.isActive = false;
    this.status = 'paused';

    if (this.runInterval) {
      clearInterval(this.runInterval);
      this.runInterval = null;
    }

    console.log(`⏸️ [${this.name}] Agent paused`);
  }

  // Resume the agent
  async resume(): Promise<void> {
    if (this.status !== 'paused') {
      console.log(`⚠️ [${this.name}] Not paused, cannot resume`);
      return;
    }

    await this.start();
  }

  // Agent loop
  private runAgentLoop(): void {
    // Run immediately
    this.runTask();

    // Then run on interval
    this.runInterval = setInterval(() => {
      if (this.isActive) {
        this.runTask();
      }
    }, this.config.runInterval * 1000);
  }

  // Run agent task
  private async runTask(): Promise<void> {
    if (!this.isActive) return;

    const startTime = Date.now();

    try {
      this.metrics.totalRuns++;

      // Execute agent-specific logic
      await this.execute();

      this.metrics.successCount++;
      this.metrics.lastSuccessTime = new Date();

      // Calculate average response time
      const responseTime = Date.now() - startTime;
      this.metrics.avgResponseTime =
        (this.metrics.avgResponseTime * (this.metrics.totalRuns - 1) + responseTime) /
        this.metrics.totalRuns;

      console.log(`✅ [${this.name}] Task completed in ${responseTime}ms`);
    } catch (error) {
      this.metrics.errorCount++;
      this.metrics.lastErrorTime = new Date();
      this.metrics.lastError = error instanceof Error ? error.message : String(error);

      console.error(`🚨 [${this.name}] Task failed:`, error);

      // Auto-disable if too many errors
      if (this.metrics.errorCount >= 10) {
        this.status = 'error';
        this.stop();
        console.error(`🚨 [${this.name}] Auto-disabled after 10 errors`);
      }
    }
  }

  // Abstract method - must be implemented by subclasses
  protected abstract execute(): Promise<void>;

  // Generate prompt for Vertex AI
  protected async generateContent(prompt: string): Promise<string> {
    if (!this.model) {
      throw new Error('Model not initialized');
    }

    try {
      const result = await this.model.generateContent(prompt);
      const response = await result.response;
      return response.text();
    } catch (error) {
      console.error(`🚨 [${this.name}] Generate content error:`, error);
      throw error;
    }
  }

  // Get agent info
  getInfo(): AGIAgent {
    return {
      id: this.id,
      name: this.name,
      description: this.description,
      category: this.getCategory(),
      priority: this.getPriority(),
      status: this.status,
      isActive: this.isActive,
      metrics: this.metrics,
      config: this.config,
    };
  }

  // Get metrics
  getMetrics(): AGIAgentMetrics {
    return { ...this.metrics };
  }

  // Abstract methods for subclasses
  protected abstract getCategory(): AGIAgent['category'];
  protected abstract getPriority(): AGIAgent['priority'];

  // Update metrics (for manual tracking)
  protected updateMetrics(updates: Partial<AGIAgentMetrics>): void {
    this.metrics = { ...this.metrics, ...updates };
  }
}


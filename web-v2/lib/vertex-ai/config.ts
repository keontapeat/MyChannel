// Vertex AI Configuration for MyChannel Web Platform

import { VertexAI } from '@google-cloud/vertexai';

// Vertex AI configuration
const projectId = process.env.GOOGLE_CLOUD_PROJECT_ID || '';
const location = process.env.GOOGLE_CLOUD_LOCATION || 'us-central1';

// Initialize Vertex AI client
let vertexAI: VertexAI | null = null;

export const getVertexAI = (): VertexAI => {
  if (!vertexAI) {
    vertexAI = new VertexAI({
      project: projectId,
      location: location,
    });
  }
  return vertexAI;
};

// Vertex AI Model Names (from environment)
export const VertexAIModels = {
  // Money Maker Agents
  DYNAMIC_PRICING: process.env.VERTEX_AI_DYNAMIC_PRICING_MODEL || 'gemini-pro',
  AD_PLACEMENT: process.env.VERTEX_AI_AD_PLACEMENT_MODEL || 'gemini-pro',
  FRAUD_DETECTION: process.env.VERTEX_AI_FRAUD_DETECTION_MODEL || 'gemini-pro',
  UPSELL: process.env.VERTEX_AI_UPSELL_MODEL || 'gemini-pro',
  MATCH_FAIRNESS: process.env.VERTEX_AI_MATCH_FAIRNESS_MODEL || 'gemini-pro',

  // Growth Agents
  VIRAL_PREDICTION: process.env.VERTEX_AI_VIRAL_PREDICTION_MODEL || 'gemini-pro',
  RETENTION_OPTIMIZER: process.env.VERTEX_AI_RETENTION_MODEL || 'gemini-pro',
  SEO_DISCOVERY: process.env.VERTEX_AI_SEO_MODEL || 'gemini-pro',
  THUMBNAIL_AB: process.env.VERTEX_AI_THUMBNAIL_MODEL || 'gemini-pro',

  // Gaming Agents
  MATCH_ORCHESTRATOR: process.env.VERTEX_AI_MATCH_ORCHESTRATOR_MODEL || 'gemini-pro',
  PRIZE_POOL: process.env.VERTEX_AI_PRIZE_POOL_MODEL || 'gemini-pro',
  ANTI_CHEAT: process.env.VERTEX_AI_ANTI_CHEAT_MODEL || 'gemini-pro',
  TOURNAMENT_SCHEDULER: process.env.VERTEX_AI_TOURNAMENT_MODEL || 'gemini-pro',
  LEADERBOARD: process.env.VERTEX_AI_LEADERBOARD_MODEL || 'gemini-pro',

  // Safety Agents
  CONTENT_MODERATION: process.env.VERTEX_AI_CONTENT_MODERATION_MODEL || 'gemini-pro',
  COPYRIGHT: process.env.VERTEX_AI_COPYRIGHT_MODEL || 'gemini-pro',
  SPAM_DESTROYER: process.env.VERTEX_AI_SPAM_MODEL || 'gemini-pro',
  TOXICITY_FILTER: process.env.VERTEX_AI_TOXICITY_MODEL || 'gemini-pro',
  REPORT_HANDLER: process.env.VERTEX_AI_REPORT_MODEL || 'gemini-pro',

  // Analytics Agents
  CREATOR_ANALYTICS: process.env.VERTEX_AI_CREATOR_ANALYTICS_MODEL || 'gemini-pro',
  AUDIENCE_INSIGHTS: process.env.VERTEX_AI_AUDIENCE_MODEL || 'gemini-pro',
  REVENUE_ATTRIBUTION: process.env.VERTEX_AI_REVENUE_MODEL || 'gemini-pro',
  TREND_FORECASTER: process.env.VERTEX_AI_TREND_MODEL || 'gemini-pro',
  COMPETITOR_INTELLIGENCE: process.env.VERTEX_AI_COMPETITOR_MODEL || 'gemini-pro',

  // Scale Agents
  CDN_OPTIMIZER: process.env.VERTEX_AI_CDN_MODEL || 'gemini-pro',
  DB_PERFORMANCE: process.env.VERTEX_AI_DB_MODEL || 'gemini-pro',
  AUTO_SCALER: process.env.VERTEX_AI_SCALER_MODEL || 'gemini-pro',
  BANDWIDTH_MANAGER: process.env.VERTEX_AI_BANDWIDTH_MODEL || 'gemini-pro',
  CACHE_OPTIMIZER: process.env.VERTEX_AI_CACHE_MODEL || 'gemini-pro',
  LOAD_BALANCER: process.env.VERTEX_AI_LOAD_BALANCER_MODEL || 'gemini-pro',
};

// Agent Endpoint Configuration
export const AgentEndpoints = {
  BASE_URL: process.env.VERTEX_AI_API_URL || 'https://us-central1-aiplatform.googleapis.com',
  API_VERSION: 'v1',
};

// Generation Config
export const defaultGenerationConfig = {
  temperature: 0.7,
  topP: 0.95,
  topK: 40,
  maxOutputTokens: 1024,
};

// Safety Settings
export const safetySettings = [
  {
    category: 'HARM_CATEGORY_HATE_SPEECH',
    threshold: 'BLOCK_MEDIUM_AND_ABOVE',
  },
  {
    category: 'HARM_CATEGORY_DANGEROUS_CONTENT',
    threshold: 'BLOCK_MEDIUM_AND_ABOVE',
  },
  {
    category: 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
    threshold: 'BLOCK_MEDIUM_AND_ABOVE',
  },
  {
    category: 'HARM_CATEGORY_HARASSMENT',
    threshold: 'BLOCK_MEDIUM_AND_ABOVE',
  },
];

// Check if Vertex AI is properly configured
export const isVertexAIConfigured = (): boolean => {
  return !!projectId && !!location;
};

// Log Vertex AI status (dev only)
if (process.env.NODE_ENV === 'development') {
  console.log('🤖 Vertex AI configured:', {
    projectId,
    location,
    isConfigured: isVertexAIConfigured(),
  });
}


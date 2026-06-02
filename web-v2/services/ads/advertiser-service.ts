/**
 * 🎯 Advertiser Service
 * Connects web UI to ads backend (services/ads)
 */

import type {
  Campaign,
  Creative,
  CampaignMetrics,
  SavedAudience,
  AnalyticsReport,
  BiddingConfig,
  TargetingRules,
} from '@/types/ads';

const ADS_API_URL = process.env.NEXT_PUBLIC_ADS_API_URL || 'http://127.0.0.1:9093';

// ============================================================================
// CAMPAIGN MANAGEMENT
// ============================================================================

export async function createCampaign(data: {
  name: string;
  objective: string;
  budget: { total: number; daily?: number };
  schedule: { startDate: string; endDate?: string; timezone: string };
  targeting: TargetingRules;
  bidding: BiddingConfig;
}): Promise<Campaign> {
  const response = await fetch(`${ADS_API_URL}/api/advertiser/campaigns`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${await getAuthToken()}`,
    },
    body: JSON.stringify(data),
  });

  if (!response.ok) {
    throw new Error(`Failed to create campaign: ${response.statusText}`);
  }

  return response.json();
}

export async function getCampaigns(advertiserId: string): Promise<Campaign[]> {
  const response = await fetch(
    `${ADS_API_URL}/api/advertiser/campaigns?advertiserId=${advertiserId}`,
    {
      headers: {
        'Authorization': `Bearer ${await getAuthToken()}`,
      },
    }
  );

  if (!response.ok) {
    throw new Error(`Failed to fetch campaigns: ${response.statusText}`);
  }

  return response.json();
}

export async function getCampaign(campaignId: string): Promise<Campaign> {
  const response = await fetch(`${ADS_API_URL}/api/advertiser/campaigns/${campaignId}`, {
    headers: {
      'Authorization': `Bearer ${await getAuthToken()}`,
    },
  });

  if (!response.ok) {
    throw new Error(`Failed to fetch campaign: ${response.statusText}`);
  }

  return response.json();
}

export async function updateCampaign(
  campaignId: string,
  updates: Partial<Campaign>
): Promise<Campaign> {
  const response = await fetch(`${ADS_API_URL}/api/advertiser/campaigns/${campaignId}`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${await getAuthToken()}`,
    },
    body: JSON.stringify(updates),
  });

  if (!response.ok) {
    throw new Error(`Failed to update campaign: ${response.statusText}`);
  }

  return response.json();
}

export async function pauseCampaign(campaignId: string): Promise<void> {
  await updateCampaign(campaignId, { status: 'paused' });
}

export async function resumeCampaign(campaignId: string): Promise<void> {
  await updateCampaign(campaignId, { status: 'active' });
}

export async function deleteCampaign(campaignId: string): Promise<void> {
  const response = await fetch(`${ADS_API_URL}/api/advertiser/campaigns/${campaignId}`, {
    method: 'DELETE',
    headers: {
      'Authorization': `Bearer ${await getAuthToken()}`,
    },
  });

  if (!response.ok) {
    throw new Error(`Failed to delete campaign: ${response.statusText}`);
  }
}

// ============================================================================
// CREATIVE MANAGEMENT
// ============================================================================

export async function uploadCreative(data: {
  campaignId: string;
  name: string;
  format: string;
  videoFile: File;
  callToAction?: { text: string; url: string };
}): Promise<Creative> {
  const formData = new FormData();
  formData.append('campaignId', data.campaignId);
  formData.append('name', data.name);
  formData.append('format', data.format);
  formData.append('video', data.videoFile);
  
  if (data.callToAction) {
    formData.append('callToAction', JSON.stringify(data.callToAction));
  }

  const response = await fetch(`${ADS_API_URL}/api/advertiser/creatives`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${await getAuthToken()}`,
    },
    body: formData,
  });

  if (!response.ok) {
    throw new Error(`Failed to upload creative: ${response.statusText}`);
  }

  return response.json();
}

export async function getCreatives(campaignId: string): Promise<Creative[]> {
  const response = await fetch(
    `${ADS_API_URL}/api/advertiser/creatives?campaignId=${campaignId}`,
    {
      headers: {
        'Authorization': `Bearer ${await getAuthToken()}`,
      },
    }
  );

  if (!response.ok) {
    throw new Error(`Failed to fetch creatives: ${response.statusText}`);
  }

  return response.json();
}

export async function deleteCreative(creativeId: string): Promise<void> {
  const response = await fetch(`${ADS_API_URL}/api/advertiser/creatives/${creativeId}`, {
    method: 'DELETE',
    headers: {
      'Authorization': `Bearer ${await getAuthToken()}`,
    },
  });

  if (!response.ok) {
    throw new Error(`Failed to delete creative: ${response.statusText}`);
  }
}

// ============================================================================
// ANALYTICS
// ============================================================================

export async function getCampaignMetrics(
  campaignId: string,
  dateRange?: { start: string; end: string }
): Promise<CampaignMetrics> {
  const params = new URLSearchParams();
  if (dateRange) {
    params.append('start', dateRange.start);
    params.append('end', dateRange.end);
  }

  const response = await fetch(
    `${ADS_API_URL}/api/advertiser/campaigns/${campaignId}/metrics?${params}`,
    {
      headers: {
        'Authorization': `Bearer ${await getAuthToken()}`,
      },
    }
  );

  if (!response.ok) {
    throw new Error(`Failed to fetch metrics: ${response.statusText}`);
  }

  return response.json();
}

export async function getAnalyticsReport(
  campaignId: string,
  options: {
    dateRange: { start: string; end: string };
    dimensions?: string[];
    metrics?: string[];
  }
): Promise<AnalyticsReport> {
  const response = await fetch(`${ADS_API_URL}/api/advertiser/analytics`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${await getAuthToken()}`,
    },
    body: JSON.stringify({
      campaignId,
      ...options,
    }),
  });

  if (!response.ok) {
    throw new Error(`Failed to fetch analytics: ${response.statusText}`);
  }

  return response.json();
}

// ============================================================================
// AUDIENCE MANAGEMENT
// ============================================================================

export async function saveAudience(data: {
  name: string;
  description?: string;
  targeting: TargetingRules;
}): Promise<SavedAudience> {
  const response = await fetch(`${ADS_API_URL}/api/advertiser/audiences`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${await getAuthToken()}`,
    },
    body: JSON.stringify(data),
  });

  if (!response.ok) {
    throw new Error(`Failed to save audience: ${response.statusText}`);
  }

  return response.json();
}

export async function getSavedAudiences(advertiserId: string): Promise<SavedAudience[]> {
  const response = await fetch(
    `${ADS_API_URL}/api/advertiser/audiences?advertiserId=${advertiserId}`,
    {
      headers: {
        'Authorization': `Bearer ${await getAuthToken()}`,
      },
    }
  );

  if (!response.ok) {
    throw new Error(`Failed to fetch audiences: ${response.statusText}`);
  }

  return response.json();
}

export async function estimateAudienceReach(targeting: TargetingRules): Promise<number> {
  const response = await fetch(`${ADS_API_URL}/api/advertiser/audiences/estimate`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${await getAuthToken()}`,
    },
    body: JSON.stringify({ targeting }),
  });

  if (!response.ok) {
    throw new Error(`Failed to estimate reach: ${response.statusText}`);
  }

  const data = await response.json();
  return data.estimatedReach;
}

// ============================================================================
// PAYMENT
// ============================================================================

export async function addFunds(amount: number): Promise<{ clientSecret: string }> {
  const response = await fetch(`${ADS_API_URL}/api/advertiser/payment/add-funds`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${await getAuthToken()}`,
    },
    body: JSON.stringify({ amount }),
  });

  if (!response.ok) {
    throw new Error(`Failed to add funds: ${response.statusText}`);
  }

  return response.json();
}

export async function getBalance(advertiserId: string): Promise<number> {
  const response = await fetch(
    `${ADS_API_URL}/api/advertiser/payment/balance?advertiserId=${advertiserId}`,
    {
      headers: {
        'Authorization': `Bearer ${await getAuthToken()}`,
      },
    }
  );

  if (!response.ok) {
    throw new Error(`Failed to fetch balance: ${response.statusText}`);
  }

  const data = await response.json();
  return data.balance;
}

// ============================================================================
// HELPERS
// ============================================================================

async function getAuthToken(): Promise<string> {
  // In a real app, get Firebase ID token
  if (typeof window === 'undefined') {
    return '';
  }

  try {
    const { getAuth } = await import('firebase/auth');
    const auth = getAuth();
    const user = auth.currentUser;
    
    if (!user) {
      throw new Error('User not authenticated');
    }

    return await user.getIdToken();
  } catch (error) {
    console.error('Failed to get auth token:', error);
    return '';
  }
}

// Format currency (cents to dollars)
export function formatCurrency(cents: number): string {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
  }).format(cents / 100);
}

// Format number with commas
export function formatNumber(num: number): string {
  return new Intl.NumberFormat('en-US').format(num);
}

// Format percentage
export function formatPercentage(value: number, decimals: number = 2): string {
  return `${value.toFixed(decimals)}%`;
}

// Calculate CTR
export function calculateCTR(clicks: number, impressions: number): number {
  if (impressions === 0) return 0;
  return (clicks / impressions) * 100;
}

// Calculate VTR
export function calculateVTR(views: number, impressions: number): number {
  if (impressions === 0) return 0;
  return (views / impressions) * 100;
}

// Calculate CPM
export function calculateCPM(spend: number, impressions: number): number {
  if (impressions === 0) return 0;
  return (spend / impressions) * 1000;
}

// Calculate CPV
export function calculateCPV(spend: number, views: number): number {
  if (views === 0) return 0;
  return spend / views;
}

// Calculate CPC
export function calculateCPC(spend: number, clicks: number): number {
  if (clicks === 0) return 0;
  return spend / clicks;
}

// Calculate ROAS
export function calculateROAS(revenue: number, spend: number): number {
  if (spend === 0) return 0;
  return revenue / spend;
}

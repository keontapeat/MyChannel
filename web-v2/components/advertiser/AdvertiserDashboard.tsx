'use client';

/**
 * 🎯 Advertiser Dashboard Component
 * YouTube Ads Manager Level UI
 */

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { 
  TrendingUp, 
  DollarSign, 
  Eye, 
  MousePointer, 
  Play,
  Plus,
  BarChart3,
  Settings,
  Users,
  Video
} from 'lucide-react';
import type { Campaign, CampaignMetrics } from '@/types/ads';
import { getCampaigns } from '@/services/ads/advertiser-service';
import { formatCurrency, formatNumber, formatPercentage } from '@/services/ads/advertiser-service';

export default function AdvertiserDashboard() {
  const [campaigns, setCampaigns] = useState<Campaign[]>([]);
  const [loading, setLoading] = useState(true);
  const [totalMetrics, setTotalMetrics] = useState<CampaignMetrics | null>(null);

  useEffect(() => {
    loadCampaigns();
  }, []);

  async function loadCampaigns() {
    try {
      setLoading(true);
      // TODO: Get actual advertiser ID from auth
      const advertiserId = 'demo-advertiser';
      const data = await getCampaigns(advertiserId);
      setCampaigns(data);

      // Calculate total metrics
      const totals = data.reduce(
        (acc, campaign) => ({
          impressions: acc.impressions + campaign.metrics.impressions,
          views: acc.views + campaign.metrics.views,
          clicks: acc.clicks + campaign.metrics.clicks,
          conversions: acc.conversions + campaign.metrics.conversions,
          spend: acc.spend + campaign.metrics.spend,
          ctr: 0,
          vtr: 0,
          cpm: 0,
          cpv: 0,
          cpc: 0,
          cpa: 0,
          roas: 0,
          quartiles: {
            firstQuartile: 0,
            midpoint: 0,
            thirdQuartile: 0,
            complete: 0,
          },
          likes: 0,
          shares: 0,
          comments: 0,
        }),
        {
          impressions: 0,
          views: 0,
          clicks: 0,
          conversions: 0,
          spend: 0,
          ctr: 0,
          vtr: 0,
          cpm: 0,
          cpv: 0,
          cpc: 0,
          cpa: 0,
          roas: 0,
          quartiles: {
            firstQuartile: 0,
            midpoint: 0,
            thirdQuartile: 0,
            complete: 0,
          },
          likes: 0,
          shares: 0,
          comments: 0,
        }
      );

      // Calculate derived metrics
      totals.ctr = totals.impressions > 0 ? (totals.clicks / totals.impressions) * 100 : 0;
      totals.vtr = totals.impressions > 0 ? (totals.views / totals.impressions) * 100 : 0;
      totals.cpm = totals.impressions > 0 ? (totals.spend / totals.impressions) * 1000 : 0;
      totals.cpv = totals.views > 0 ? totals.spend / totals.views : 0;
      totals.cpc = totals.clicks > 0 ? totals.spend / totals.clicks : 0;

      setTotalMetrics(totals);
    } catch (error) {
      console.error('Failed to load campaigns:', error);
    } finally {
      setLoading(false);
    }
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-white">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          <div className="animate-pulse">
            <div className="h-8 bg-gray-200 rounded w-1/4 mb-8"></div>
            <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
              {[1, 2, 3, 4].map((i) => (
                <div key={i} className="h-32 bg-gray-200 rounded-lg"></div>
              ))}
            </div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-white">
      {/* Header */}
      <div className="border-b border-gray-200">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-2xl font-semibold text-gray-900">Advertiser Dashboard</h1>
              <p className="mt-1 text-sm text-gray-500">
                Manage your campaigns and track performance
              </p>
            </div>
            <Link
              href="/advertiser/campaigns/create"
              className="inline-flex items-center gap-2 px-4 py-2 bg-red-600 text-white rounded-full hover:bg-red-700 transition-colors"
            >
              <Plus className="w-4 h-4" />
              Create Campaign
            </Link>
          </div>
        </div>
      </div>

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Quick Stats */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
          <StatCard
            icon={<Eye className="w-5 h-5" />}
            label="Impressions"
            value={formatNumber(totalMetrics?.impressions || 0)}
            change="+12.5%"
            positive
          />
          <StatCard
            icon={<Play className="w-5 h-5" />}
            label="Views"
            value={formatNumber(totalMetrics?.views || 0)}
            change="+8.3%"
            positive
          />
          <StatCard
            icon={<MousePointer className="w-5 h-5" />}
            label="Clicks"
            value={formatNumber(totalMetrics?.clicks || 0)}
            change="+15.2%"
            positive
          />
          <StatCard
            icon={<DollarSign className="w-5 h-5" />}
            label="Spend"
            value={formatCurrency(totalMetrics?.spend || 0)}
            change="+5.7%"
            positive={false}
          />
        </div>

        {/* Performance Metrics */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
          <MetricCard
            label="CTR"
            value={formatPercentage(totalMetrics?.ctr || 0)}
            description="Click-through rate"
          />
          <MetricCard
            label="VTR"
            value={formatPercentage(totalMetrics?.vtr || 0)}
            description="View-through rate"
          />
          <MetricCard
            label="CPM"
            value={formatCurrency(totalMetrics?.cpm || 0)}
            description="Cost per 1000 impressions"
          />
        </div>

        {/* Quick Actions */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
          <ActionCard
            icon={<Plus className="w-6 h-6" />}
            title="Create Campaign"
            description="Launch a new ad campaign"
            href="/advertiser/campaigns/create"
          />
          <ActionCard
            icon={<Video className="w-6 h-6" />}
            title="Upload Creative"
            description="Add video ads"
            href="/advertiser/creatives/upload"
          />
          <ActionCard
            icon={<Users className="w-6 h-6" />}
            title="Build Audience"
            description="Create targeting rules"
            href="/advertiser/audiences/builder"
          />
          <ActionCard
            icon={<BarChart3 className="w-6 h-6" />}
            title="View Analytics"
            description="Detailed performance reports"
            href="/advertiser/analytics"
          />
        </div>

        {/* Campaigns List */}
        <div className="bg-white rounded-lg border border-gray-200">
          <div className="px-6 py-4 border-b border-gray-200">
            <h2 className="text-lg font-semibold text-gray-900">Your Campaigns</h2>
          </div>
          
          {campaigns.length === 0 ? (
            <div className="px-6 py-12 text-center">
              <Video className="w-12 h-12 text-gray-400 mx-auto mb-4" />
              <h3 className="text-lg font-medium text-gray-900 mb-2">No campaigns yet</h3>
              <p className="text-gray-500 mb-6">
                Create your first campaign to start advertising on MyChannel
              </p>
              <Link
                href="/advertiser/campaigns/create"
                className="inline-flex items-center gap-2 px-4 py-2 bg-red-600 text-white rounded-full hover:bg-red-700 transition-colors"
              >
                <Plus className="w-4 h-4" />
                Create Campaign
              </Link>
            </div>
          ) : (
            <div className="divide-y divide-gray-200">
              {campaigns.map((campaign) => (
                <CampaignRow key={campaign.id} campaign={campaign} />
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

// ============================================================================
// SUB-COMPONENTS
// ============================================================================

function StatCard({
  icon,
  label,
  value,
  change,
  positive,
}: {
  icon: React.ReactNode;
  label: string;
  value: string;
  change: string;
  positive: boolean;
}) {
  return (
    <div className="bg-white rounded-lg border border-gray-200 p-6">
      <div className="flex items-center justify-between mb-4">
        <div className="p-2 bg-gray-100 rounded-lg text-gray-600">{icon}</div>
        <span
          className={`text-sm font-medium ${
            positive ? 'text-green-600' : 'text-red-600'
          }`}
        >
          {change}
        </span>
      </div>
      <div className="text-2xl font-bold text-gray-900 mb-1">{value}</div>
      <div className="text-sm text-gray-500">{label}</div>
    </div>
  );
}

function MetricCard({
  label,
  value,
  description,
}: {
  label: string;
  value: string;
  description: string;
}) {
  return (
    <div className="bg-white rounded-lg border border-gray-200 p-6">
      <div className="text-sm text-gray-500 mb-1">{label}</div>
      <div className="text-3xl font-bold text-gray-900 mb-1">{value}</div>
      <div className="text-xs text-gray-400">{description}</div>
    </div>
  );
}

function ActionCard({
  icon,
  title,
  description,
  href,
}: {
  icon: React.ReactNode;
  title: string;
  description: string;
  href: string;
}) {
  return (
    <Link
      href={href}
      className="bg-white rounded-lg border border-gray-200 p-6 hover:border-red-600 hover:shadow-md transition-all group"
    >
      <div className="p-3 bg-gray-100 rounded-lg text-gray-600 group-hover:bg-red-50 group-hover:text-red-600 transition-colors w-fit mb-4">
        {icon}
      </div>
      <h3 className="text-lg font-semibold text-gray-900 mb-1">{title}</h3>
      <p className="text-sm text-gray-500">{description}</p>
    </Link>
  );
}

function CampaignRow({ campaign }: { campaign: Campaign }) {
  const statusColors = {
    draft: 'bg-gray-100 text-gray-700',
    active: 'bg-green-100 text-green-700',
    paused: 'bg-yellow-100 text-yellow-700',
    completed: 'bg-blue-100 text-blue-700',
    archived: 'bg-gray-100 text-gray-500',
  };

  return (
    <Link
      href={`/advertiser/campaigns/${campaign.id}`}
      className="block px-6 py-4 hover:bg-gray-50 transition-colors"
    >
      <div className="flex items-center justify-between">
        <div className="flex-1">
          <div className="flex items-center gap-3 mb-2">
            <h3 className="text-base font-semibold text-gray-900">{campaign.name}</h3>
            <span
              className={`px-2 py-1 text-xs font-medium rounded-full ${
                statusColors[campaign.status]
              }`}
            >
              {campaign.status}
            </span>
          </div>
          <div className="flex items-center gap-6 text-sm text-gray-500">
            <span>{formatNumber(campaign.metrics.impressions)} impressions</span>
            <span>{formatNumber(campaign.metrics.views)} views</span>
            <span>{formatPercentage(campaign.metrics.ctr)} CTR</span>
            <span>{formatCurrency(campaign.metrics.spend)} spent</span>
          </div>
        </div>
        <div className="text-right">
          <div className="text-sm font-medium text-gray-900 mb-1">
            {formatCurrency(campaign.budget.remaining)} remaining
          </div>
          <div className="text-xs text-gray-500">
            of {formatCurrency(campaign.budget.total)}
          </div>
        </div>
      </div>
    </Link>
  );
}

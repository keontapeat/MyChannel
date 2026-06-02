/**
 * 🎯 Advertiser Dashboard
 * YouTube Ads Manager Parity
 */

import { Metadata } from 'next';
import AdvertiserDashboard from '@/components/advertiser/AdvertiserDashboard';

export const metadata: Metadata = {
  title: 'Advertiser Dashboard - MyChannel Ads',
  description: 'Manage your advertising campaigns on MyChannel',
};

export default function AdvertiserDashboardPage() {
  return <AdvertiserDashboard />;
}

// Static params for static export
export async function generateStaticParams() {
  return [];
}

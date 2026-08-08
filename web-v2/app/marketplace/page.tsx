import MarketplacePageClient from './MarketplacePageClient';

export async function generateStaticParams() {
  return [];
}

export default function MarketplacePage() {
  return <MarketplacePageClient />;
}

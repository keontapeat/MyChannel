import PremiumPageClient from './PremiumPageClient';

export async function generateStaticParams() {
  return [];
}

export default function PremiumPage() {
  return <PremiumPageClient />;
}

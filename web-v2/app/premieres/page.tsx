import PremieresPageClient from './PremieresPageClient';

export async function generateStaticParams() {
  return [];
}

export default function PremieresPage() {
  return <PremieresPageClient />;
}

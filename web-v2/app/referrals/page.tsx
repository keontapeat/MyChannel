import ReferralsPageClient from './ReferralsPageClient';

export async function generateStaticParams() {
  return [];
}

export default function ReferralsPage() {
  return <ReferralsPageClient />;
}

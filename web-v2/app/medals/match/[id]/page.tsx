import MatchDetailClient from './MatchDetailClient';

interface MatchDetailPageProps {
  params: Promise<{ id: string }>;
}

export function generateStaticParams() {
  return [{ id: '_fallback' }];
}

export default async function MatchDetailPage({ params }: MatchDetailPageProps) {
  const { id } = await params;
  return <MatchDetailClient matchId={id} />;
}

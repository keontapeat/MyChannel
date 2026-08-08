import MatchSpectateClient from './MatchSpectateClient';

interface SpectatePageProps {
  params: Promise<{id: string}>;
}

export function generateStaticParams() {
  return [{id: '_fallback'}];
}

export default async function MatchSpectatePage({params}: SpectatePageProps) {
  const {id} = await params;
  return <MatchSpectateClient initialMatchId={id} />;
}

import WatchPageClient from './WatchPageClient';

export const dynamic = 'force-static';

export async function generateStaticParams() {
  return []; // Empty for client-side routing with static export
}

export default function WatchPage({ params }: { params: { id: string } }) {
  return <WatchPageClient videoId={params.id} />;
}

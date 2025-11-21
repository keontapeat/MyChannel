import WatchPageClient from './WatchPageClient';

export async function generateStaticParams() {
  // Generate one fallback page for static export
  return [{ id: '_fallback' }];
}

export default async function WatchPage(props: { params: Promise<{ id: string }> }) {
  const params = await props.params;
  return <WatchPageClient videoId={params.id} />;
}

import PlaylistDetailClient from './PlaylistDetailClient';

export async function generateStaticParams() {
  // Generate one fallback page for static export; real playlist IDs are
  // resolved client-side (owner-scoped, so server-side listing isn't useful).
  return [{ id: '_fallback' }];
}

export default async function PlaylistDetailPage(props: { params: Promise<{ id: string }> }) {
  const params = await props.params;
  return <PlaylistDetailClient playlistId={params.id} />;
}

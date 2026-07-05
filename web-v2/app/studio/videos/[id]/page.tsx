import { redirect } from 'next/navigation';

export async function generateStaticParams() {
  return [{ id: '_fallback' }];
}

// /studio/videos/[id] → redirect to the edit page
export default async function StudioVideoPage(props: { params: Promise<{ id: string }> }) {
  const params = await props.params;
  redirect(`/studio/videos/${params.id}/edit`);
}

import ChaptersEditorClient from './ChaptersEditorClient';

export async function generateStaticParams() {
  return [{ id: '_fallback' }];
}

export default async function ChaptersPage(props: { params: Promise<{ id: string }> }) {
  const params = await props.params;
  return <ChaptersEditorClient videoId={params.id} />;
}

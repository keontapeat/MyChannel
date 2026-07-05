import EndScreensEditorClient from './EndScreensEditorClient';

export async function generateStaticParams() {
  return [{ id: '_fallback' }];
}

export default async function EndScreensPage(props: { params: Promise<{ id: string }> }) {
  const params = await props.params;
  return <EndScreensEditorClient videoId={params.id} />;
}

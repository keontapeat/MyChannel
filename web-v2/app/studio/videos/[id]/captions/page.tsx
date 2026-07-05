import CaptionsEditorClient from './CaptionsEditorClient';

export async function generateStaticParams() {
  return [{ id: '_fallback' }];
}

export default async function CaptionsPage(props: { params: Promise<{ id: string }> }) {
  const params = await props.params;
  return <CaptionsEditorClient videoId={params.id} />;
}

import VideoEditClient from './VideoEditClient';

export function generateStaticParams() {
  return [{ id: '_fallback' }];
}

export default async function VideoEditPage(props: { params: Promise<{ id: string }> }) {
  const { id } = await props.params;
  return <VideoEditClient videoId={id} />;
}

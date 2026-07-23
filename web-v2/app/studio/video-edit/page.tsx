import VideoEditClient from './VideoEditClient';

export async function generateStaticParams() {
  return [];
}

export default function VideoEditPage() {
  return <VideoEditClient />;
}

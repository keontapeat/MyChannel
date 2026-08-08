import type {Metadata} from 'next';
import LiveStreamPageClient from './LiveStreamPageClient';

export async function generateStaticParams() {
  return [{id: '_fallback'}];
}

interface LiveStreamPageProps {
  params: Promise<{id: string}>;
}

export async function generateMetadata(): Promise<Metadata> {
  return {
    title: 'Live on MyChannel',
    description: 'Watch live creators, events, and communities on MyChannel.',
    openGraph: {
      title: 'Live on MyChannel',
      description: 'Watch live creators, events, and communities on MyChannel.',
      type: 'video.other',
    },
  };
}

export default async function LiveStreamPage(props: LiveStreamPageProps) {
  const {id} = await props.params;
  return <LiveStreamPageClient initialStreamId={id} />;
}


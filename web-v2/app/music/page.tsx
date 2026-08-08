import type { Metadata } from 'next';
import MusicHub from '@/components/music/MusicHub';

export const metadata: Metadata = {
  title: 'Music Hub | MyChannel',
  description: 'Discover published music from independent creators on MyChannel.',
};

export default function MusicPage() {
  return <MusicHub />;
}

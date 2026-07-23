import ChaptersClient from './ChaptersClient';

export async function generateStaticParams() {
  return [];
}

export default function ChaptersPage() {
  return <ChaptersClient />;
}

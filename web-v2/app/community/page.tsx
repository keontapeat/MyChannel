import CommunityPageClient from './CommunityPageClient';

export async function generateStaticParams() {
  return [];
}

export default function CommunityPage() {
  return <CommunityPageClient />;
}

import CollaborationsPageClient from './CollaborationsPageClient';

export async function generateStaticParams() {
  return [];
}

export default function CollaborationsPage() {
  return <CollaborationsPageClient />;
}

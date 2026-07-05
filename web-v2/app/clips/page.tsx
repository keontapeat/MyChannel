import ClipsPageClient from './ClipsPageClient';

export async function generateStaticParams() {
  return [];
}

export default function ClipsPage() {
  return <ClipsPageClient />;
}

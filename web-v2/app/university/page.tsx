import UniversityPageClient from './UniversityPageClient';

export async function generateStaticParams() {
  return [];
}

export default function UniversityPage() {
  return <UniversityPageClient />;
}

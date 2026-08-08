import TranslationsPageClient from './TranslationsPageClient';

export async function generateStaticParams() {
  return [];
}

export default function TranslationsPage() {
  return <TranslationsPageClient />;
}

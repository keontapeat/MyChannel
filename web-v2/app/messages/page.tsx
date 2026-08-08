import MessagesPageClient from './MessagesPageClient';

export async function generateStaticParams() {
  return [];
}

export default function MessagesPage() {
  return <MessagesPageClient />;
}

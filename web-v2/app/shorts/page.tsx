import ShortsRedirect from './ShortsRedirect';

export async function generateStaticParams() {
  return [];
}

export default function ShortsPage() {
  return <ShortsRedirect />;
}

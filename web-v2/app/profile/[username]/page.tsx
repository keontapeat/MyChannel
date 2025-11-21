// 🔥 YOUTUBE-LEVEL PROFESSIONAL PROFILE PAGE 🔥

import ProfilePageClient from './ProfilePageClient';

interface ProfilePageProps {
  params: Promise<{
    username: string;
  }>;
}

export async function generateStaticParams() {
  // Generate one fallback page for static export
  // All other pages will be handled client-side via 404.html fallback
  return [{ username: '_fallback' }];
}

export default async function ProfilePage(props: ProfilePageProps) {
  const params = await props.params;
  return <ProfilePageClient username={params.username} />;
}


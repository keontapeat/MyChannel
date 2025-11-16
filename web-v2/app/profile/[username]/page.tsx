// 🔥 YOUTUBE-LEVEL PROFESSIONAL PROFILE PAGE 🔥

import ProfilePageClient from './ProfilePageClient';

interface ProfilePageProps {
  params: {
    username: string;
  };
}

// Required for static export
export const dynamic = 'force-static';

export async function generateStaticParams(): Promise<{ username: string }[]> {
  return [];
}

export default function ProfilePage({ params }: ProfilePageProps) {
  return <ProfilePageClient username={params.username} />;
}


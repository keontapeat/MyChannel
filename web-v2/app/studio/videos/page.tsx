'use client';

// Creator Studio - Video Manager

import { Video, Search, Filter, Eye, ThumbsUp, MessageSquare, Edit, Trash2, MoreVertical } from 'lucide-react';
import Link from 'next/link';
import { useState } from 'react';

export default function VideoManagerPage() {
  const [searchQuery, setSearchQuery] = useState('');
  const [filterStatus, setFilterStatus] = useState<'all' | 'public' | 'unlisted' | 'private'>('all');

  // Sample videos
  const [videos] = useState([
    {
      id: '1',
      title: 'Amazing Tutorial - Part 1',
      thumbnailURL: 'https://picsum.photos/seed/vid1/320/180',
      status: 'public' as const,
      views: 125000,
      likes: 8500,
      comments: 420,
      uploadDate: new Date('2024-01-15'),
      duration: '12:34',
    },
    {
      id: '2',
      title: 'Behind the Scenes',
      thumbnailURL: 'https://picsum.photos/seed/vid2/320/180',
      status: 'public' as const,
      views: 98000,
      likes: 6200,
      comments: 310,
      uploadDate: new Date('2024-01-10'),
      duration: '8:45',
    },
    {
      id: '3',
      title: 'Q&A with Fans',
      thumbnailURL: 'https://picsum.photos/seed/vid3/320/180',
      status: 'public' as const,
      views: 75000,
      likes: 5100,
      comments: 890,
      uploadDate: new Date('2024-01-05'),
      duration: '15:20',
    },
    {
      id: '4',
      title: 'Draft Video (Coming Soon)',
      thumbnailURL: 'https://picsum.photos/seed/vid4/320/180',
      status: 'private' as const,
      views: 0,
      likes: 0,
      comments: 0,
      uploadDate: new Date('2024-01-20'),
      duration: '10:12',
    },
  ]);

  const filteredVideos = videos.filter((video) => {
    const matchesSearch = video.title.toLowerCase().includes(searchQuery.toLowerCase());
    const matchesStatus = filterStatus === 'all' || video.status === filterStatus;
    return matchesSearch && matchesStatus;
  });

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Mobile-First Container */}
      <div className="max-w-[768px] mx-auto">
        {/* Header */}
        <header className="sticky top-0 z-50 bg-white border-b border-gray-200 px-4 py-4">
          <div className="flex items-center gap-3 mb-4">
            <Link href="/studio" className="p-2 hover:bg-gray-100 rounded-full transition-colors">
              <svg width="24" height="24" viewBox="0 0 24 24" fill="black">
                <path d="M15.41 7.41L14 6l-6 6 6 6 1.41-1.41L10.83 12z" />
              </svg>
            </Link>
            <Video size={28} className="text-purple-600" />
            <div>
              <h1 className="text-xl font-bold text-black">Video Manager</h1>
              <p className="text-sm text-gray-600">{videos.length} videos</p>
            </div>
          </div>

          {/* Search Bar */}
          <div className="relative mb-3">
            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400" size={20} />
            <input
              type="text"
              placeholder="Search your videos..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full bg-gray-100 text-black pl-10 pr-4 py-3 rounded-xl focus:outline-none focus:ring-2 focus:ring-purple-500"
            />
          </div>

          {/* Filter Tabs */}
          <div className="flex gap-2 overflow-x-auto scrollbar-hide">
            {(['all', 'public', 'unlisted', 'private'] as const).map((status) => (
              <button
                key={status}
                onClick={() => setFilterStatus(status)}
                className={`px-4 py-2 rounded-full text-sm font-medium whitespace-nowrap transition-all capitalize ${
                  filterStatus === status
                    ? 'bg-purple-600 text-white'
                    : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                }`}
              >
                {status}
              </button>
            ))}
          </div>
        </header>

        {/* Main Content */}
        <main className="px-4 py-6 pb-24">
          {filteredVideos.length === 0 ? (
            <div className="text-center py-12">
              <Video size={48} className="text-gray-300 mx-auto mb-4" />
              <p className="text-gray-600 mb-4">No videos found</p>
              <Link
                href="/upload"
                className="inline-block px-6 py-3 bg-purple-600 text-white font-bold rounded-full hover:bg-purple-700 transition-colors"
              >
                Upload Video
              </Link>
            </div>
          ) : (
            <div className="space-y-3">
              {filteredVideos.map((video) => (
                <div key={video.id} className="bg-white p-3 rounded-xl border border-gray-200 shadow-sm">
                  <div className="flex items-start gap-3">
                    {/* Thumbnail */}
                    <Link href={`/watch/${video.id}`} className="flex-shrink-0">
                      <div className="relative w-32 h-18 bg-gray-200 rounded-lg overflow-hidden">
                        <img
                          src={video.thumbnailURL}
                          alt={video.title}
                          className="w-full h-full object-cover"
                        />
                        <div className="absolute bottom-1 right-1 bg-black/80 text-white text-xs px-1 py-0.5 rounded">
                          {video.duration}
                        </div>
                      </div>
                    </Link>

                    {/* Info */}
                    <div className="flex-1 min-w-0">
                      <Link href={`/watch/${video.id}`}>
                        <h3 className="font-bold text-black text-sm line-clamp-2 mb-1 hover:text-purple-600 transition-colors">
                          {video.title}
                        </h3>
                      </Link>

                      <div className="flex items-center gap-3 text-xs text-gray-600 mb-2">
                        <span className="flex items-center gap-1">
                          <Eye size={12} />
                          {video.views > 0 ? (video.views / 1000).toFixed(0) + 'K' : '0'}
                        </span>
                        <span className="flex items-center gap-1">
                          <ThumbsUp size={12} />
                          {video.likes > 0 ? (video.likes / 1000).toFixed(1) + 'K' : '0'}
                        </span>
                        <span className="flex items-center gap-1">
                          <MessageSquare size={12} />
                          {video.comments}
                        </span>
                      </div>

                      <div className="flex items-center gap-2">
                        <span
                          className={`text-xs px-2 py-1 rounded-full font-medium ${
                            video.status === 'public'
                              ? 'bg-green-100 text-green-700'
                              : video.status === 'private'
                              ? 'bg-gray-100 text-gray-700'
                              : 'bg-yellow-100 text-yellow-700'
                          }`}
                        >
                          {video.status}
                        </span>
                        <span className="text-xs text-gray-500">
                          {video.uploadDate.toLocaleDateString()}
                        </span>
                      </div>
                    </div>

                    {/* Actions */}
                    <div className="flex flex-col gap-2">
                      <Link
                        href={`/studio/videos/${video.id}/edit`}
                        className="p-2 hover:bg-gray-100 rounded-full transition-colors"
                      >
                        <Edit size={18} className="text-gray-700" />
                      </Link>
                      <button className="p-2 hover:bg-gray-100 rounded-full transition-colors">
                        <Trash2 size={18} className="text-red-600" />
                      </button>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </main>
      </div>
    </div>
  );
}


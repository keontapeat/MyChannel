'use client';

import React from 'react';
import { Plus } from 'lucide-react';
import Link from 'next/link';

interface Story {
  id: string;
  username: string;
  authorImageName: string;
  isCloseFriends?: boolean;
}

interface StoriesRowProps {
  stories?: Story[];
}

// Dummy data if none provided
const DUMMY_STORIES: Story[] = [
  { id: '1', username: 'Your Story', authorImageName: '', isCloseFriends: false },
  { id: '2', username: 'Keonta', authorImageName: 'https://i.pravatar.cc/150?img=11' },
  { id: '3', username: 'mrbeast', authorImageName: 'https://i.pravatar.cc/150?img=12' },
  { id: '4', username: 'MKBHD', authorImageName: 'https://i.pravatar.cc/150?img=13', isCloseFriends: true },
  { id: '5', username: 'iJustine', authorImageName: 'https://i.pravatar.cc/150?img=14' },
  { id: '6', username: 'Casey', authorImageName: 'https://i.pravatar.cc/150?img=15' },
];

export default function StoriesRow({ stories = DUMMY_STORIES }: StoriesRowProps) {
  return (
    <section className="py-2 px-4 bg-white dark:bg-black">
      <div className="flex gap-4 overflow-x-auto scrollbar-hide pb-2">
        {stories.map((story, index) => {
          const isYourStory = index === 0; // Assuming first item is always 'Your Story' for now
          
          return (
            <div key={story.id} className="flex flex-col items-center flex-shrink-0 cursor-pointer w-16">
              <div className={`relative rounded-full p-[2px] ${!isYourStory ? (story.isCloseFriends ? 'bg-green-500' : 'bg-red-500') : ''}`}>
                <div className="w-14 h-14 bg-white dark:bg-gray-900 rounded-full flex items-center justify-center overflow-hidden border-2 border-white dark:border-black">
                  {isYourStory ? (
                    <Plus size={28} className="text-gray-900 dark:text-white" />
                  ) : (
                    <img
                      src={story.authorImageName}
                      alt={story.username}
                      className="w-full h-full object-cover"
                    />
                  )}
                </div>
              </div>
              <span className="text-[10px] text-gray-800 dark:text-gray-200 mt-1 text-center w-full truncate">
                {story.username}
              </span>
            </div>
          );
        })}
      </div>
    </section>
  );
}

'use client';

import React from 'react';

export type FilterChip = 
  | 'All' 
  | 'Music' 
  | 'Live' 
  | 'Gaming' 
  | 'News' 
  | 'Mixes' 
  | 'Podcasts' 
  | 'Recently uploaded' 
  | 'Watched' 
  | 'New to you';

export const CHIPS: FilterChip[] = [
  'All',
  'Music',
  'Live',
  'Gaming',
  'News',
  'Mixes',
  'Podcasts',
  'Recently uploaded',
  'Watched',
  'New to you'
];

interface FilterChipsProps {
  selected: FilterChip | string;
  onChipTap: (chip: FilterChip | string) => void;
}

export default function FilterChips({ selected, onChipTap }: FilterChipsProps) {
  return (
    <div className="w-full bg-white py-2 px-4 sticky top-[3.5rem] z-40 border-b border-gray-100">
      <div className="flex overflow-x-auto scrollbar-hide gap-2 pb-1 items-center">
        {CHIPS.map((chip) => {
          const isSelected = selected === chip;
          return (
            <button
              key={chip}
              onClick={() => onChipTap(chip)}
              className={`
                whitespace-nowrap px-3.5 py-1.5 rounded-full text-sm font-medium transition-colors
                ${
                  isSelected
                    ? 'bg-gray-900 text-white'
                    : 'bg-gray-100 text-gray-800 hover:bg-gray-200'
                }
              `}
            >
              {chip}
            </button>
          );
        })}
      </div>
    </div>
  );
}

'use client';

// 🔥 YOUTUBE-STYLE CATEGORY TABS COMPONENT 🔥

import { useState, useRef, useEffect } from 'react';
import { ChevronLeft, ChevronRight } from 'lucide-react';

interface CategoryTabsProps {
  categories?: string[];
  activeCategory?: string;
  onCategoryChange?: (category: string) => void;
}

const defaultCategories = [
  'All',
  'Music',
  'Gaming',
  'Live',
  'Flicks',
  'Movies',
  'Sports',
  'News',
  'Comedy',
  'Technology',
  'Education',
  'Cooking',
  'Fashion',
  'Travel',
];

export default function CategoryTabs({
  categories = defaultCategories,
  activeCategory = 'All',
  onCategoryChange,
}: CategoryTabsProps) {
  const [active, setActive] = useState(activeCategory);
  const [showLeftArrow, setShowLeftArrow] = useState(false);
  const [showRightArrow, setShowRightArrow] = useState(true);
  const scrollContainerRef = useRef<HTMLDivElement>(null);

  const handleCategoryClick = (category: string) => {
    setActive(category);
    onCategoryChange?.(category);
  };

  const handleScroll = () => {
    const container = scrollContainerRef.current;
    if (!container) return;

    const { scrollLeft, scrollWidth, clientWidth } = container;
    setShowLeftArrow(scrollLeft > 10);
    setShowRightArrow(scrollLeft < scrollWidth - clientWidth - 10);
  };

  const scroll = (direction: 'left' | 'right') => {
    const container = scrollContainerRef.current;
    if (!container) return;

    const scrollAmount = 300;
    container.scrollBy({
      left: direction === 'left' ? -scrollAmount : scrollAmount,
      behavior: 'smooth',
    });
  };

  useEffect(() => {
    const container = scrollContainerRef.current;
    if (!container) return;

    handleScroll();
    container.addEventListener('scroll', handleScroll);
    window.addEventListener('resize', handleScroll);

    return () => {
      container.removeEventListener('scroll', handleScroll);
      window.removeEventListener('resize', handleScroll);
    };
  }, []);

  return (
    <div className="
      sticky top-14 z-30
      bg-white dark:bg-[rgb(var(--color-background))]
      border-b border-[rgb(var(--color-border))]
    ">
      <div className="relative max-w-[1800px] mx-auto">
        {/* Left Arrow (Desktop) */}
        {showLeftArrow && (
          <button
            onClick={() => scroll('left')}
            className="
              absolute left-0 top-0 bottom-0
              w-12
              hidden md:flex items-center justify-center
              bg-gradient-to-r from-white dark:from-[rgb(var(--color-background))] to-transparent
              z-10
            "
          >
            <div className="
              w-8 h-8
              rounded-full
              bg-white dark:bg-[rgb(var(--color-surface))]
              border border-[rgb(var(--color-border))]
              flex items-center justify-center
              hover:bg-[rgb(var(--color-surface-hover))]
              transition-colors
              shadow-sm
            ">
              <ChevronLeft size={18} className="text-[rgb(var(--color-text-primary))]" />
            </div>
          </button>
        )}

        {/* Scrollable Categories */}
        <div
          ref={scrollContainerRef}
          className="
            flex gap-3
            overflow-x-auto scrollbar-hide
            px-6
            py-3
          "
        >
          {categories.map((category) => {
            const isActive = category === active;
            
            return (
              <button
                key={category}
                onClick={() => handleCategoryClick(category)}
                className={`
                  flex-shrink-0
                  px-4 py-1.5
                  rounded-full
                  text-sm font-medium
                  transition-all duration-150
                  ${
                    isActive
                      ? 'bg-[rgb(var(--color-text-primary))] text-white'
                      : 'bg-[rgb(var(--color-surface))] text-[rgb(var(--color-text-primary))] hover:bg-[rgb(var(--color-surface-hover))]'
                  }
                `}
              >
                {category}
              </button>
            );
          })}
        </div>

        {/* Right Arrow (Desktop) */}
        {showRightArrow && (
          <button
            onClick={() => scroll('right')}
            className="
              absolute right-0 top-0 bottom-0
              w-12
              hidden md:flex items-center justify-center
              bg-gradient-to-l from-white dark:from-[rgb(var(--color-background))] to-transparent
              z-10
            "
          >
            <div className="
              w-8 h-8
              rounded-full
              bg-white dark:bg-[rgb(var(--color-surface))]
              border border-[rgb(var(--color-border))]
              flex items-center justify-center
              hover:bg-[rgb(var(--color-surface-hover))]
              transition-colors
              shadow-sm
            ">
              <ChevronRight size={18} className="text-[rgb(var(--color-text-primary))]" />
            </div>
          </button>
        )}
      </div>
    </div>
  );
}







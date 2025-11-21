'use client';

// 🔥 YOUTUBE-STYLE SKELETON LOADING COMPONENT 🔥

export function VideoCardSkeleton({ index = 0 }: { index?: number }) {
  return (
    <div className={`fade-in-up stagger-${(index % 4) + 1}`}>
      <div className="space-y-3">
        {/* Thumbnail Skeleton */}
        <div className="
          aspect-video
          rounded-xl
          skeleton
        " />

        {/* Info Skeleton */}
        <div className="flex gap-3 px-0.5">
          {/* Avatar Skeleton */}
          <div className="
            w-9 h-9
            rounded-full
            skeleton
            flex-shrink-0
          " />

          {/* Text Skeleton */}
          <div className="flex-1 space-y-2">
            {/* Title Lines */}
            <div className="h-4 skeleton rounded w-full" />
            <div className="h-4 skeleton rounded w-3/4" />
            
            {/* Metadata */}
            <div className="h-3 skeleton rounded w-1/2" />
          </div>
        </div>
      </div>
    </div>
  );
}

export function VideoGridSkeleton({ count = 24 }: { count?: number }) {
  return (
    <div className="
      grid
      grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 2xl:grid-cols-6
      gap-x-4 gap-y-10
    ">
      {Array.from({ length: count }).map((_, i) => (
        <VideoCardSkeleton key={i} index={i} />
      ))}
    </div>
  );
}

export function SidebarSkeleton() {
  return (
    <div className="py-2 px-2 space-y-1">
      {/* Main Nav Skeletons */}
      {Array.from({ length: 3 }).map((_, i) => (
        <div key={`main-${i}`} className="flex items-center gap-6 px-3 py-2.5">
          <div className="w-5 h-5 skeleton rounded" />
          <div className="flex-1 h-4 skeleton rounded" />
        </div>
      ))}

      <div className="my-2 border-t border-[rgb(var(--color-border))]" />

      {/* Library Skeletons */}
      {Array.from({ length: 5 }).map((_, i) => (
        <div key={`library-${i}`} className="flex items-center gap-6 px-3 py-2.5">
          <div className="w-5 h-5 skeleton rounded" />
          <div className="flex-1 h-4 skeleton rounded" />
        </div>
      ))}
    </div>
  );
}

export function PlayerSkeleton() {
  return (
    <div className="space-y-4">
      {/* Video Player Skeleton */}
      <div className="
        aspect-video
        w-full
        skeleton
        rounded-xl
      " />

      {/* Title Skeleton */}
      <div className="space-y-2">
        <div className="h-6 skeleton rounded w-3/4" />
        <div className="h-6 skeleton rounded w-1/2" />
      </div>

      {/* Channel Info Skeleton */}
      <div className="flex items-center gap-4">
        <div className="w-10 h-10 skeleton rounded-full" />
        <div className="flex-1 space-y-2">
          <div className="h-4 skeleton rounded w-32" />
          <div className="h-3 skeleton rounded w-24" />
        </div>
        <div className="h-10 w-28 skeleton rounded-full" />
      </div>

      {/* Description Skeleton */}
      <div className="space-y-2 pt-4">
        <div className="h-4 skeleton rounded w-full" />
        <div className="h-4 skeleton rounded w-full" />
        <div className="h-4 skeleton rounded w-2/3" />
      </div>
    </div>
  );
}

export function CompactVideoCardSkeleton() {
  return (
    <div className="flex gap-2">
      {/* Compact Thumbnail */}
      <div className="
        w-[168px] h-[94px]
        skeleton
        rounded-lg
        flex-shrink-0
      " />

      {/* Compact Info */}
      <div className="flex-1 space-y-2">
        <div className="h-4 skeleton rounded w-full" />
        <div className="h-4 skeleton rounded w-3/4" />
        <div className="h-3 skeleton rounded w-1/2" />
      </div>
    </div>
  );
}







// lib/utils/format.ts - Formatting utilities for MyChannel Web

/**
 * Formats a duration in seconds into a human-readable string (e.g., "1:23", "12:34", "1:23:45").
 * @param seconds The duration in seconds.
 * @returns Formatted duration string.
 */
export const formatDuration = (seconds: number): string => {
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const remainingSeconds = seconds % 60;

  const pad = (num: number) => num.toString().padStart(2, '0');

  if (hours > 0) {
    return `${hours}:${pad(minutes)}:${pad(remainingSeconds)}`;
  } else {
    return `${minutes}:${pad(remainingSeconds)}`;
  }
};

/**
 * Formats a number of views into a human-readable string (e.g., "1.2K", "123K", "1.2M").
 * @param views The number of views.
 * @returns Formatted views string.
 */
export const formatViews = (views: number): string => {
  if (views >= 1_000_000_000) {
    return (views / 1_000_000_000).toFixed(1).replace(/\.0$/, '') + 'B';
  }
  if (views >= 1_000_000) {
    return (views / 1_000_000).toFixed(1).replace(/\.0$/, '') + 'M';
  }
  if (views >= 1_000) {
    return (views / 1_000).toFixed(1).replace(/\.0$/, '') + 'K';
  }
  return views.toString();
};

// Alias for formatViews
export const formatViewCount = formatViews;

/**
 * Formats a Date object into a human-readable "time ago" string (e.g., "2 hours ago", "3 days ago").
 * @param date The Date object to format.
 * @returns Formatted time ago string.
 */
export const timeAgo = (date: Date): string => {
  const seconds = Math.floor((new Date().getTime() - date.getTime()) / 1000);

  let interval = seconds / 31536000; // years
  if (interval > 1) return Math.floor(interval) + ' years ago';
  interval = seconds / 2592000; // months
  if (interval > 1) return Math.floor(interval) + ' months ago';
  interval = seconds / 86400; // days
  if (interval > 1) return Math.floor(interval) + ' days ago';
  interval = seconds / 3600; // hours
  if (interval > 1) return Math.floor(interval) + ' hours ago';
  interval = seconds / 60; // minutes
  if (interval > 1) return Math.floor(interval) + ' minutes ago';
  return Math.floor(seconds) + ' seconds ago';
};

// Alias for timeAgo
export const formatTimeAgo = timeAgo;

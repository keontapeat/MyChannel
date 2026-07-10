/**
 * Share links for VS Match detail / spectator views.
 */

const SITE_ORIGIN =
  typeof window !== "undefined" ? window.location.origin : "https://mychannel.app";

export function matchDetailPath(matchId: string): string {
  return `/medals/match/${encodeURIComponent(matchId)}`;
}

export function matchSpectatePath(matchId: string): string {
  return `/medals/match/${encodeURIComponent(matchId)}/spectate`;
}

export function matchShareUrl(matchId: string): string {
  return `${SITE_ORIGIN}${matchDetailPath(matchId)}`;
}

export async function copyMatchShareLink(matchId: string): Promise<boolean> {
  const url = matchShareUrl(matchId);
  if (typeof navigator !== "undefined" && navigator.clipboard?.writeText) {
    await navigator.clipboard.writeText(url);
    return true;
  }
  return false;
}

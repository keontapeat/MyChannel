import test from 'node:test';
import assert from 'node:assert/strict';
import {authorizePlaybackSession} from './playback-session.js';

const baseVideo = () => ({
  ownerId: 'creator-1',
  visibility: 'public',
  isPublic: true,
  processingStatus: 'ready',
  moderationStatus: 'approved',
  ageRestricted: false,
  allowedRegions: [],
  blockedRegions: [],
  isPremium: false,
  hlsURL: 'https://storage.googleapis.com/mychannel/video/master.m3u8',
  hasCaptions: true,
  offlineDownloadEnabled: true,
  pictureInPictureEnabled: true,
  castingEnabled: true,
});

const authorize = (video: Record<string, unknown>, viewer: Record<string, unknown> = {}) =>
  authorizePlaybackSession({
    sessionId: 'session-1',
    videoId: 'video-1',
    viewerId: 'viewer-1',
    video,
    viewer,
  });

test('authorizes policy-complete HLS and derives capabilities', () => {
  const result = authorize(baseVideo());
  assert.equal(result.canPlay, true);
  assert.equal(result.denialReason, null);
  assert.equal(result.capabilities.hls, true);
  assert.equal(result.capabilities.dash, false);
  assert.equal(result.capabilities.captions, true);
  assert.equal(result.capabilities.offlineDownload, true);
  assert.equal(result.capabilities.pictureInPicture, true);
  assert.equal(result.capabilities.casting, true);
});

test('allows a private video only for its canonical owner', () => {
  const video = {...baseVideo(), visibility: 'private', isPublic: false};
  const denied = authorize(video);
  assert.equal(denied.denialReason, 'visibility_denied');
  const allowed = authorizePlaybackSession({
    sessionId: 'session-2', videoId: 'video-1', viewerId: 'creator-1', video, viewer: {},
  });
  assert.equal(allowed.canPlay, true);
});

test('fails closed when required policy fields are missing', () => {
  const cases: Array<[string, keyof ReturnType<typeof baseVideo>, string]> = [
    ['visibility', 'visibility', 'invalid_visibility_policy'],
    ['processing', 'processingStatus', 'invalid_processing_policy'],
    ['moderation', 'moderationStatus', 'invalid_moderation_policy'],
    ['age', 'ageRestricted', 'invalid_age_policy'],
    ['regions', 'allowedRegions', 'invalid_region_policy'],
    ['entitlement', 'isPremium', 'invalid_entitlement_policy'],
  ];
  for (const [name, field, denialReason] of cases) {
    const video: Record<string, unknown> = baseVideo();
    delete video[field];
    assert.equal(authorize(video).denialReason, denialReason, name);
  }
});

test('enforces age, region, and membership policy', () => {
  const restricted = {...baseVideo(), ageRestricted: true};
  assert.equal(authorize(restricted).denialReason, 'age_verification_required');
  assert.equal(authorize(restricted, {isAgeVerified: true, age: 21}).canPlay, true);

  const regional = {...baseVideo(), allowedRegions: ['US'], blockedRegions: ['US-NY']};
  assert.equal(authorize(regional, {region: 'CA'}).denialReason, 'region_denied');
  assert.equal(authorize(regional, {region: 'US-CA'}).canPlay, true);

  const premium = {...baseVideo(), isPremium: true, channelId: 'creator-1'};
  assert.equal(authorize(premium).denialReason, 'entitlement_required');
  assert.equal(authorize(premium, {entitlements: {'channel:creator-1': true}}).canPlay, true);
});

test('rejects unsafe and expired manifests', () => {
  assert.equal(
    authorize({...baseVideo(), hlsURL: 'https://evil.example/master.m3u8'}).denialReason,
    'manifest_unavailable',
  );
  assert.equal(
    authorize({...baseVideo(), playbackExpiresAt: '2020-01-01T00:00:00.000Z'}).denialReason,
    'manifest_expired',
  );
});
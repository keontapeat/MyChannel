# Video Playback QA Checklist

Use this checklist before every TestFlight or production release to ensure the MyChannel player matches YouTube-level expectations.

## 1. Autoplay & Detail View
- Open any video from the Home feed → Video starts automatically within 500ms.
- Navigate between videos rapidly via Up Next → Each video autoplays immediately.
- Newly uploaded video from UploadView → open detail screen → video autoplays without manual tap.

## 2. View Tracking & Analytics
- Play a video for >5 seconds → View count increments exactly once (verify in Firestore or admin dashboard).
- Pause/resume multiple times → View count remains unchanged.
- Seek around the video → analytics events (start/pause/seek) appear in logging console.

## 3. Mini Player & PiP Parity
- Swiping down from detail view → Floating mini player appears, keeps playing.
- Drag mini player to edges, resize via pinch, swipe left/right to change videos.
- Swipe down on mini player → dismiss animation + playback stops.
- Background the app while video is playing in mini player → Picture-in-Picture auto-starts.
- Return to app → PiP exits and mini player resumes.

## 4. Upload → Playback Pipeline
- Upload a new video (Firebase path) → wait for “Upload complete” toast → open detail view → stream plays instantly.
- Inspect logs for `VideoPlaybackReadinessService` confirming poll + prewarm completed.
- Thumbnail for newly uploaded video appears instantly in Home feed (confirm cache warming).

## 5. Additional Scenarios
- Watch video to completion → Up Next overlay appears with countdown & autoplay works.
- Enter fullscreen and back → playback continues without white flashes.
- Activate manual PiP (pip.enter button) → PiP controller appears & responds to close/restore.
- Network toggle (Wi-Fi → LTE) mid playback → Buffer adjusts (2s/5s/10s) and playback continues smoothly.

Record findings (pass/fail + device + OS) in TestRail/Testrail or QA doc, attach screen recordings for any regressions.


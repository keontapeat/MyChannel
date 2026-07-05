# Shorts (Deprecated Directory)

This directory is intentionally empty.

**On MyChannel, short-form vertical video is called "Flicks" — not Shorts.**

All short-form video code lives in:
`MyChannel/Features/Flicks/`

Deep links:
- `mychannel://flicks` → opens the Flicks tab (handled by `DeepLinkManager`)
- `mychannel://shorts` → also routes to Flicks (handled by `DeepLinkService`: `case "flicks", "shorts": type = .flicks`)

The web route `/shorts` redirects to `/flicks` for SEO parity with YouTube's URL structure.

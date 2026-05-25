# GA4 Event Map → BigQuery

- video_impression: { video_id, rank, surface, session_id }
- video_start: { video_id, autoplay, position=0 }
- quartile_25/50/75: { video_id, position }
- video_complete: { video_id, duration }
- ad_impression/click: { line_item_id, placement, quartile }
- subscribe: { channel_id }
- tip: { channel_id, amount }
- membership_start: { channel_id, tier }
- share: { surface }
- referral_activate: { code }

BigQuery tables (infra/terraform): analytics.events, plays, impressions, likes, video_features.

Partitioning: daily partition on timestamp fields; clustering by video_id/channel_id where applicable.

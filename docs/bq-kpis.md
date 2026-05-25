# BigQuery KPI queries

-- Daily active users by day
SELECT DATE(timestamp) AS day, COUNT(DISTINCT user_id) dau
FROM `mychannel-ca26d.analytics.events`
WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
GROUP BY day ORDER BY day;

-- Video RPM/eCPM by geo
SELECT geo, SAFE_DIVIDE(SUM(ad_revenue_usd), SUM(play_time_seconds)/60.0) AS rpm
FROM `mychannel-ca26d.analytics.events`
WHERE event_type IN ('ad_impression','video_complete')
GROUP BY geo ORDER BY rpm DESC;

-- Viewer retention curve by percentiles
SELECT video_id, APPROX_QUANTILES(watch_time_seconds, 20) AS pct
FROM `mychannel-ca26d.analytics.plays`
GROUP BY video_id;

-- Subscriptions gained per channel last 7 days
SELECT channel_id, COUNT(1) subs
FROM `mychannel-ca26d.analytics.events`
WHERE event_type = 'subscribe' AND timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
GROUP BY channel_id ORDER BY subs DESC;

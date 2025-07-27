-- Event Type Overview - High-level analytics across all event types
-- Shows total events, unique sessions, and unique users for each event type
-- Useful for understanding overall app usage patterns and feature adoption

SELECT
  event_type,
  COUNT(*) as total_events,
  COUNT(DISTINCT session_id) as unique_sessions,
  COUNT(DISTINCT device_id) as unique_users,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentage_of_total_events,
  ROUND(COUNT(DISTINCT session_id) * 1.0 / COUNT(DISTINCT device_id), 2) as sessions_per_user
FROM mht_api_production_data_analytics.mht_api_production_flattened_analytics_correct
WHERE DATE(from_unixtime(CAST(event_timestamp AS BIGINT)/1000)) >= CURRENT_DATE - INTERVAL '30' DAY
GROUP BY event_type
ORDER BY total_events DESC;
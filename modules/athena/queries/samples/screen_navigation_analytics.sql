SELECT 
  screen_name,
  COUNT(*) as total_views,
  COUNT(DISTINCT device_id) as unique_users,
  COUNT(DISTINCT session_id) as unique_sessions,
  COUNT(DISTINCT DATE(from_unixtime(CAST(event_timestamp AS BIGINT)/1000))) as active_days,
  MIN(event_timestamp) as first_view,
  MAX(event_timestamp) as last_view,
  ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT device_id), 2) as views_per_user,
  ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT session_id), 2) as views_per_session,
  ROUND(COUNT(DISTINCT session_id) * 1.0 / COUNT(DISTINCT device_id), 2) as sessions_per_user
FROM mht_api_production_data_analytics.mht_api_production_flattened_analytics_correct
WHERE event_type = 'screen_view'
  AND year = CAST(YEAR(CURRENT_DATE) AS VARCHAR)
  AND month = CAST(MONTH(CURRENT_DATE) AS VARCHAR)
  AND screen_name IS NOT NULL AND screen_name != ''
GROUP BY screen_name
ORDER BY total_views DESC
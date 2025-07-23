SELECT 
  device_id,
  COUNT(DISTINCT session_id) as unique_sessions,
  COUNT(DISTINCT DATE(from_unixtime(CAST(event_timestamp AS BIGINT)/1000))) as active_days,
  COUNT(*) as total_events,
  COUNT(CASE WHEN event_type = 'anxiety_session_completed' THEN 1 END) as completed_anxiety_sessions,
  COUNT(CASE WHEN event_type = 'app_background' THEN 1 END) as app_backgrounds,
  COUNT(CASE WHEN event_type = 'new_focus_selected' THEN 1 END) as new_focuses,
  COUNT(CASE WHEN event_type = 'screen_view' THEN 1 END) as screen_views,
  MIN(event_timestamp) as first_event,
  MAX(event_timestamp) as last_event,
  ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT session_id), 2) as events_per_session,
  ROUND(COUNT(DISTINCT session_id) * 1.0 / COUNT(DISTINCT DATE(from_unixtime(CAST(event_timestamp AS BIGINT)/1000))), 2) as sessions_per_day,
  CASE 
    WHEN COUNT(CASE WHEN event_type = 'anxiety_session_completed' THEN 1 END) >= 5 THEN 'High Engagement'
    WHEN COUNT(CASE WHEN event_type = 'anxiety_session_completed' THEN 1 END) >= 2 THEN 'Medium Engagement'
    ELSE 'Low Engagement'
  END as engagement_level
FROM mht_api_production_data_analytics.mht_api_production_flattened_analytics_correct
WHERE year = CAST(YEAR(CURRENT_DATE) AS VARCHAR)
  AND month = CAST(MONTH(CURRENT_DATE) AS VARCHAR)
GROUP BY device_id
HAVING COUNT(DISTINCT session_id) >= 2
ORDER BY completed_anxiety_sessions DESC, unique_sessions DESC
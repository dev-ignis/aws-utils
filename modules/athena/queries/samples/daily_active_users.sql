SELECT 
  year,
  month,
  day,
  COUNT(DISTINCT device_id) as daily_active_users,
  COUNT(DISTINCT session_id) as daily_unique_sessions,
  COUNT(*) as total_events,
  COUNT(DISTINCT CASE WHEN event_type = 'anxiety_session_completed' THEN session_id END) as sessions_with_anxiety_completion,
  COUNT(CASE WHEN event_type = 'anxiety_session_completed' THEN 1 END) as anxiety_completion_events,
  COUNT(CASE WHEN event_type = 'screen_view' THEN 1 END) as screen_views,
  COUNT(CASE WHEN event_type = 'new_focus_selected' THEN 1 END) as new_focus_selections,
  COUNT(CASE WHEN event_type = 'app_background' THEN 1 END) as app_backgrounds,
  ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT device_id), 2) as events_per_user,
  ROUND(COUNT(DISTINCT session_id) * 1.0 / COUNT(DISTINCT device_id), 2) as sessions_per_user,
  ROUND(COUNT(DISTINCT CASE WHEN event_type = 'anxiety_session_completed' THEN session_id END) * 100.0 / COUNT(DISTINCT session_id), 2) as session_completion_rate
FROM mht_api_production_data_analytics.mht_api_production_flattened_analytics_correct
WHERE year = CAST(YEAR(CURRENT_DATE) AS VARCHAR)
  AND month = CAST(MONTH(CURRENT_DATE) AS VARCHAR)
GROUP BY year, month, day
ORDER BY year, month, day
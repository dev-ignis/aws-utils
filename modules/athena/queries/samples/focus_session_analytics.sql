SELECT 
  focus,
  specific_focus,
  COUNT(DISTINCT session_id) as unique_sessions,
  COUNT(DISTINCT device_id) as unique_users,
  COUNT(*) as total_anxiety_events,
  AVG(CAST(danger_level AS DOUBLE)) as avg_danger_level,
  AVG(CAST(probability_level AS DOUBLE)) as avg_probability_level,
  COUNT(CASE WHEN response = 'Maintain' THEN 1 END) as maintain_responses,
  COUNT(CASE WHEN response = 'Reduce' THEN 1 END) as reduce_responses,
  COUNT(CASE WHEN response = 'Increase' THEN 1 END) as increase_responses,
  ROUND(COUNT(DISTINCT session_id) * 1.0 / COUNT(DISTINCT device_id), 2) as sessions_per_user,
  ROUND(COUNT(CASE WHEN response = 'Reduce' THEN 1 END) * 100.0 / COUNT(*), 2) as reduce_response_percentage
FROM mht_api_production_data_analytics.mht_api_production_flattened_analytics_correct
WHERE event_type = 'anxiety_session_completed'
  AND year = CAST(YEAR(CURRENT_DATE) AS VARCHAR)
  AND month = CAST(MONTH(CURRENT_DATE) AS VARCHAR)
  AND focus IS NOT NULL
GROUP BY focus, specific_focus
ORDER BY unique_sessions DESC
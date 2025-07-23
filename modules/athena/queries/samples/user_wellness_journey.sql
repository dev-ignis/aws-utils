WITH user_journey AS (
  SELECT 
    device_id,
    DATE(from_unixtime(CAST(event_timestamp AS BIGINT)/1000)) as activity_date,
    event_type,
    
    CASE WHEN event_type = 'anxiety_session_completed' THEN 1 ELSE 0 END as anxiety_session,
    CASE WHEN event_type = 'anxiety_session_completed' THEN CAST(danger_level AS DOUBLE) END as danger_level,
    CASE WHEN event_type = 'anxiety_session_completed' THEN CAST(probability_level AS DOUBLE) END as probability_level,
    CASE WHEN event_type = 'anxiety_session_completed' THEN response END as response_action,
    CASE WHEN event_type = 'new_focus_selected' THEN focus END as selected_focus,
    
    year,
    month
  FROM mht_api_production_data_analytics.mht_api_production_flattened_analytics_correct
  WHERE device_id IS NOT NULL
    AND year = CAST(YEAR(CURRENT_DATE) AS VARCHAR)
    AND month = CAST(MONTH(CURRENT_DATE) AS VARCHAR)
),

daily_user_metrics AS (
  SELECT 
    device_id,
    activity_date,
    
    COUNT(*) as total_events,
    COUNT(DISTINCT event_type) as unique_event_types,
    
    SUM(anxiety_session) as anxiety_sessions_completed,
    AVG(danger_level) as avg_danger_level,
    AVG(probability_level) as avg_probability_level,
    
    COUNT(CASE WHEN response_action = 'Reduce' THEN 1 END) as reduce_responses,
    COUNT(CASE WHEN response_action = 'Maintain' THEN 1 END) as maintain_responses,
    COUNT(CASE WHEN response_action = 'Increase' THEN 1 END) as increase_responses,
    
    COUNT(CASE WHEN selected_focus IS NOT NULL THEN 1 END) as new_focus_selections,
    
    CASE 
      WHEN SUM(anxiety_session) >= 3 THEN 'High Activity'
      WHEN SUM(anxiety_session) >= 1 THEN 'Moderate Activity'
      ELSE 'Low Activity'
    END as daily_activity_level
     
  FROM user_journey
  GROUP BY device_id, activity_date
)

SELECT 
  device_id,
  
  COUNT(DISTINCT activity_date) as active_days,
  MIN(activity_date) as first_activity_date,
  MAX(activity_date) as last_activity_date,
  
  SUM(anxiety_sessions_completed) as total_anxiety_sessions,
  SUM(new_focus_selections) as total_focus_changes,
  SUM(total_events) as total_interactions,
  
  AVG(avg_danger_level) as overall_avg_danger_level,
  AVG(avg_probability_level) as overall_avg_probability_level,
  
  SUM(reduce_responses) as total_reduce_responses,
  SUM(maintain_responses) as total_maintain_responses,
  SUM(increase_responses) as total_increase_responses,
  
  ROUND(SUM(reduce_responses) * 100.0 / NULLIF(SUM(reduce_responses + maintain_responses + increase_responses), 0), 2) as reduce_response_percentage,
  
  CASE 
    WHEN COUNT(DISTINCT activity_date) >= 7 AND SUM(anxiety_sessions_completed) >= 10 THEN 'Highly Engaged User'
    WHEN COUNT(DISTINCT activity_date) >= 3 AND SUM(anxiety_sessions_completed) >= 3 THEN 'Regular User'
    ELSE 'Casual User'
  END as user_engagement_category,
  
  CASE
    WHEN AVG(avg_danger_level) < 3 THEN 'Low Anxiety Trend'
    WHEN AVG(avg_danger_level) < 6 THEN 'Moderate Anxiety Trend'
    ELSE 'High Anxiety Trend'
  END as anxiety_level_category

FROM daily_user_metrics
WHERE anxiety_sessions_completed > 0
GROUP BY device_id
HAVING COUNT(DISTINCT activity_date) >= 2
ORDER BY total_anxiety_sessions DESC, active_days DESC
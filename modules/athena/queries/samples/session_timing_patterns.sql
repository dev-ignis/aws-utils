WITH session_timing AS (
  SELECT 
    device_id,
    session_id,
    event_type,
    from_unixtime(CAST(event_timestamp AS BIGINT)/1000) as session_datetime,
    EXTRACT(hour FROM from_unixtime(CAST(event_timestamp AS BIGINT)/1000)) as hour_of_day,
    EXTRACT(dow FROM from_unixtime(CAST(event_timestamp AS BIGINT)/1000)) as day_of_week,
    DATE(from_unixtime(CAST(event_timestamp AS BIGINT)/1000)) as session_date,
    
    CASE WHEN event_type = 'anxiety_session_completed' THEN CAST(danger_level AS DOUBLE) END as danger_level,
    CASE WHEN event_type = 'anxiety_session_completed' THEN CAST(probability_level AS DOUBLE) END as probability_level,
    CASE WHEN event_type = 'anxiety_session_completed' THEN response END as response,
    CASE WHEN event_type = 'anxiety_session_completed' THEN focus END as focus
    
  FROM mht_api_production_data_analytics.mht_api_production_flattened_analytics_correct
  WHERE year = CAST(YEAR(CURRENT_DATE) AS VARCHAR)
    AND month = CAST(MONTH(CURRENT_DATE) AS VARCHAR)
    AND event_type IN ('anxiety_session_completed', 'screen_view', 'new_focus_selected')
),

hourly_patterns AS (
  SELECT 
    hour_of_day,
    
    CASE 
      WHEN hour_of_day BETWEEN 6 AND 11 THEN 'Morning (6-11am)'
      WHEN hour_of_day BETWEEN 12 AND 17 THEN 'Afternoon (12-5pm)' 
      WHEN hour_of_day BETWEEN 18 AND 21 THEN 'Evening (6-9pm)'
      WHEN hour_of_day BETWEEN 22 AND 23 OR hour_of_day BETWEEN 0 AND 5 THEN 'Night (10pm-5am)'
    END as time_period,
    
    COUNT(DISTINCT CASE WHEN event_type = 'anxiety_session_completed' THEN session_id END) as unique_anxiety_sessions,
    COUNT(CASE WHEN event_type = 'anxiety_session_completed' THEN 1 END) as anxiety_completion_events,
    COUNT(*) as total_events,
    COUNT(DISTINCT device_id) as unique_users,
    COUNT(DISTINCT session_id) as unique_sessions,
    COUNT(DISTINCT session_date) as active_days,
    
    AVG(danger_level) as avg_danger_level,
    AVG(probability_level) as avg_probability_level,
    
    COUNT(CASE WHEN danger_level >= 7 THEN 1 END) as high_anxiety_sessions,
    COUNT(CASE WHEN response = 'Reduce' THEN 1 END) as reduce_responses
    
  FROM session_timing
  GROUP BY hour_of_day
),

daily_patterns AS (
  SELECT 
    day_of_week,
    
    CASE day_of_week
      WHEN 1 THEN 'Monday'
      WHEN 2 THEN 'Tuesday' 
      WHEN 3 THEN 'Wednesday'
      WHEN 4 THEN 'Thursday'
      WHEN 5 THEN 'Friday'
      WHEN 6 THEN 'Saturday'
      WHEN 0 THEN 'Sunday'
    END as day_name,
    
    CASE 
      WHEN day_of_week IN (1,2,3,4,5) THEN 'Weekday'
      ELSE 'Weekend'
    END as day_type,
    
    COUNT(DISTINCT CASE WHEN event_type = 'anxiety_session_completed' THEN session_id END) as unique_anxiety_sessions,
    COUNT(CASE WHEN event_type = 'anxiety_session_completed' THEN 1 END) as anxiety_completion_events,
    COUNT(*) as total_events,
    COUNT(DISTINCT device_id) as unique_users,
    COUNT(DISTINCT session_id) as unique_sessions,
    
    AVG(danger_level) as avg_danger_level,
    AVG(probability_level) as avg_probability_level,
    
    COUNT(CASE WHEN danger_level >= 7 THEN 1 END) as high_anxiety_sessions
    
  FROM session_timing
  GROUP BY day_of_week
)

SELECT 
  'Hourly Analysis' as analysis_type,
  CAST(hour_of_day AS VARCHAR) as time_dimension,
  time_period as time_category,
  unique_anxiety_sessions,
  anxiety_completion_events,
  total_events,
  unique_users,
  unique_sessions,
  ROUND(avg_danger_level, 2) as avg_danger_level,
  ROUND(avg_probability_level, 2) as avg_probability_level,
  high_anxiety_sessions,
  ROUND(high_anxiety_sessions * 100.0 / NULLIF(unique_anxiety_sessions, 0), 2) as high_anxiety_percentage,
  ROUND(unique_anxiety_sessions * 1.0 / NULLIF(unique_users, 0), 2) as anxiety_sessions_per_user

FROM hourly_patterns
WHERE unique_anxiety_sessions > 0

UNION ALL

SELECT 
  'Daily Analysis' as analysis_type,
  day_name as time_dimension,
  day_type as time_category,
  unique_anxiety_sessions,
  anxiety_completion_events,
  total_events,
  unique_users,
  unique_sessions,
  ROUND(avg_danger_level, 2) as avg_danger_level,
  ROUND(avg_probability_level, 2) as avg_probability_level,
  high_anxiety_sessions,
  ROUND(high_anxiety_sessions * 100.0 / NULLIF(unique_anxiety_sessions, 0), 2) as high_anxiety_percentage,
  ROUND(unique_anxiety_sessions * 1.0 / NULLIF(unique_users, 0), 2) as anxiety_sessions_per_user

FROM daily_patterns
WHERE unique_anxiety_sessions > 0

ORDER BY analysis_type, 
  CASE analysis_type 
    WHEN 'Hourly Analysis' THEN CAST(time_dimension AS INTEGER)
    ELSE day_of_week 
  END
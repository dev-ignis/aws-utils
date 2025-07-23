-- Breathing Exercise Effectiveness Analysis
-- Tracks breathing patterns, completion rates, and user engagement

WITH breathing_data AS (
  SELECT 
    user_id,
    session_id,
    event_timestamp,
    exercise_type,
    breaths_per_minute,
    total_breaths,
    breathing_duration,
    pattern_type,
    guide_used,
    completion_status,
    CASE 
      WHEN completion_status = 'completed' THEN 1 
      ELSE 0 
    END as completed_flag,
    year,
    month,
    day
  FROM ${database_name}.${view_name}
  WHERE event_type = 'breathing_exercise'
    AND breathing_duration IS NOT NULL
    AND year = CAST(YEAR(CURRENT_DATE) AS VARCHAR)
)

SELECT 
  exercise_type,
  pattern_type,
  guide_used,
  
  -- Basic metrics
  COUNT(*) as total_sessions,
  COUNT(DISTINCT user_id) as unique_users,
  AVG(breathing_duration) as avg_duration_seconds,
  AVG(breaths_per_minute) as avg_breaths_per_minute,
  AVG(total_breaths) as avg_total_breaths,
  
  -- Completion metrics
  SUM(completed_flag) as completed_sessions,
  AVG(completed_flag) * 100 as completion_rate_percent,
  
  -- Effectiveness indicators
  CASE 
    WHEN AVG(breaths_per_minute) BETWEEN 4 AND 6 THEN 'Optimal (4-6 BPM)'
    WHEN AVG(breaths_per_minute) BETWEEN 6 AND 8 THEN 'Good (6-8 BPM)'
    WHEN AVG(breaths_per_minute) > 8 THEN 'Fast (>8 BPM)'
    ELSE 'Slow (<4 BPM)'
  END as breathing_pace_category,
  
  -- User engagement
  AVG(breathing_duration) / 60.0 as avg_duration_minutes,
  COUNT(*) / COUNT(DISTINCT user_id) as avg_sessions_per_user,
  
  -- Trend analysis
  COUNT(DISTINCT DATE(from_unixtime(event_timestamp/1000))) as active_days

FROM breathing_data
GROUP BY exercise_type, pattern_type, guide_used
ORDER BY total_sessions DESC, completion_rate_percent DESC;
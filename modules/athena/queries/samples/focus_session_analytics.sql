-- Focus Session Analytics for Amygdalas App
-- Analyzes completion rates, mood improvements, and technique effectiveness

WITH focus_sessions AS (
  SELECT 
    user_id,
    session_id,
    event_timestamp,
    focus_duration,
    completion_rate,
    technique_used,
    difficulty_level,
    mood_before,
    mood_after,
    interruptions,
    CASE 
      WHEN mood_after > mood_before THEN 'Improved'
      WHEN mood_after = mood_before THEN 'Stable'
      ELSE 'Declined'
    END as mood_change,
    year,
    month,
    day
  FROM ${database_name}.${view_name}
  WHERE event_type = 'focus_session'
    AND focus_duration IS NOT NULL
    AND year = CAST(YEAR(CURRENT_DATE) AS VARCHAR)
    AND month = CAST(MONTH(CURRENT_DATE) AS VARCHAR)
)

SELECT 
  technique_used,
  difficulty_level,
  COUNT(*) as total_sessions,
  AVG(completion_rate) as avg_completion_rate,
  AVG(focus_duration) as avg_duration_seconds,
  AVG(interruptions) as avg_interruptions,
  
  -- Mood improvement metrics
  COUNT(CASE WHEN mood_change = 'Improved' THEN 1 END) as sessions_with_improvement,
  COUNT(CASE WHEN mood_change = 'Improved' THEN 1 END) * 100.0 / COUNT(*) as improvement_rate_percent,
  
  -- Session quality indicators
  COUNT(CASE WHEN completion_rate >= 0.8 THEN 1 END) as high_quality_sessions,
  COUNT(CASE WHEN completion_rate >= 0.8 THEN 1 END) * 100.0 / COUNT(*) as quality_rate_percent,
  
  -- Usage patterns
  COUNT(DISTINCT user_id) as unique_users,
  COUNT(DISTINCT DATE(from_unixtime(event_timestamp/1000))) as active_days

FROM focus_sessions
GROUP BY technique_used, difficulty_level
ORDER BY total_sessions DESC, avg_completion_rate DESC;
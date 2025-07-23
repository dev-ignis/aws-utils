WITH user_sessions AS (
  SELECT 
    user_id,
    DATE(from_unixtime(event_timestamp/1000)) as session_date,
    event_type,
    
    CASE WHEN event_type = 'focus_session' THEN focus_duration ELSE NULL END as focus_time,
    CASE WHEN event_type = 'focus_session' THEN completion_rate ELSE NULL END as focus_completion,
    CASE WHEN event_type = 'focus_session' AND mood_after IS NOT NULL AND mood_before IS NOT NULL 
         THEN CAST(mood_after AS DOUBLE) - CAST(mood_before AS DOUBLE) ELSE NULL END as mood_improvement,
    
    CASE WHEN event_type = 'breathing_exercise' THEN breathing_duration ELSE NULL END as breathing_time,
    CASE WHEN event_type = 'breathing_exercise' AND completion_status = 'completed' THEN 1 ELSE 0 END as breathing_completed,
    
    CASE WHEN event_type = 'danger_assessment' THEN user_confidence ELSE NULL END as confidence_level,
    CASE WHEN event_type = 'danger_assessment' THEN outcome_rating ELSE NULL END as assessment_outcome,
    
    year,
    month
  FROM mht_api_production_data_analytics.mht_api_production_flattened_analytics
  WHERE user_id IS NOT NULL
    AND year = CAST(YEAR(CURRENT_DATE) AS VARCHAR)
),

daily_user_metrics AS (
  SELECT 
    user_id,
    session_date,
    
    COUNT(*) as total_events,
    COUNT(DISTINCT event_type) as unique_event_types,
    
    COUNT(CASE WHEN event_type = 'focus_session' THEN 1 END) as focus_sessions,
    AVG(focus_time) as avg_focus_duration,
    AVG(focus_completion) as avg_focus_completion,
    AVG(mood_improvement) as avg_mood_improvement,
    
    COUNT(CASE WHEN event_type = 'breathing_exercise' THEN 1 END) as breathing_sessions,
    AVG(breathing_time) as avg_breathing_duration,
    SUM(breathing_completed) as breathing_completed_count,
    
    COUNT(CASE WHEN event_type = 'danger_assessment' THEN 1 END) as assessments,
    AVG(confidence_level) as avg_confidence,
    
    (COUNT(*) * 0.3 + 
     COALESCE(AVG(focus_completion), 0) * 0.4 + 
     COALESCE(AVG(CASE WHEN breathing_completed = 1 THEN 1.0 ELSE 0.0 END), 0) * 0.3) * 100 as daily_engagement_score
     
  FROM user_sessions
  GROUP BY user_id, session_date
)

SELECT 
  user_id,
  
  COUNT(DISTINCT session_date) as active_days,
  MIN(session_date) as first_session_date,
  MAX(session_date) as last_session_date,
  DATE_DIFF('day', MIN(session_date), MAX(session_date)) + 1 as days_since_first_use,
  
  SUM(focus_sessions) as total_focus_sessions,
  SUM(breathing_sessions) as total_breathing_sessions,
  SUM(assessments) as total_assessments,
  SUM(total_events) as total_interactions,
  
  AVG(avg_focus_completion) as overall_focus_completion_rate,
  AVG(avg_mood_improvement) as overall_mood_improvement,
  AVG(avg_confidence) as overall_confidence_trend,
  
  AVG(daily_engagement_score) as avg_daily_engagement,
  COUNT(DISTINCT session_date) * 100.0 / GREATEST(DATE_DIFF('day', MIN(session_date), MAX(session_date)) + 1, 1) as retention_rate_percent,
  
  STDDEV(daily_engagement_score) as engagement_consistency,
  CASE 
    WHEN COUNT(DISTINCT session_date) >= 7 THEN 'Highly Active (7+ days)'
    WHEN COUNT(DISTINCT session_date) >= 3 THEN 'Moderately Active (3-6 days)'
    ELSE 'Low Activity (<3 days)'
  END as user_engagement_category

FROM daily_user_metrics
GROUP BY user_id
HAVING COUNT(DISTINCT session_date) >= 2
ORDER BY overall_focus_completion_rate DESC, total_focus_sessions DESC
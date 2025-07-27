-- Session Engagement Metrics
-- Analyzes user engagement patterns including session duration, screen views, and activity levels
-- Provides insights into user behavior and app usage patterns

WITH session_metrics AS (
  SELECT 
    session_id,
    device_id,
    MIN(event_timestamp) as session_start,
    MAX(event_timestamp) as session_end,
    COUNT(*) as total_events,
    COUNT(CASE WHEN event_type = 'screen_view' THEN 1 END) as screen_views,
    COUNT(DISTINCT screen_name) as unique_screens_viewed,
    
    -- Calculate session duration in minutes
    (CAST(MAX(event_timestamp) AS BIGINT) - CAST(MIN(event_timestamp) AS BIGINT))/1000/60 as session_duration_minutes,
    
    -- Track specific engagement events
    MAX(CASE WHEN event_type = 'anxiety_session_completed' THEN 1 ELSE 0 END) as completed_anxiety_session,
    MAX(CASE WHEN event_type = 'new_anxiety_created' THEN 1 ELSE 0 END) as created_new_anxiety,
    
    -- App lifecycle events
    COUNT(CASE WHEN event_type = 'app_background' THEN 1 END) as background_events,
    COUNT(CASE WHEN event_type = 'app_foreground' THEN 1 END) as foreground_events
  FROM mht_api_production_data_analytics.mht_api_production_flattened_analytics_correct
  WHERE DATE(from_unixtime(CAST(event_timestamp AS BIGINT)/1000)) >= CURRENT_DATE - INTERVAL '30' DAY
    AND session_id IS NOT NULL
  GROUP BY session_id, device_id
),

engagement_summary AS (
  SELECT
    COUNT(DISTINCT session_id) as total_sessions,
    COUNT(DISTINCT device_id) as total_users,
    
    -- Duration metrics
    AVG(session_duration_minutes) as avg_session_duration_minutes,
    APPROX_PERCENTILE(session_duration_minutes, 0.5) as median_session_duration_minutes,
    APPROX_PERCENTILE(session_duration_minutes, 0.9) as p90_session_duration_minutes,
    
    -- Activity metrics
    AVG(total_events) as avg_events_per_session,
    AVG(screen_views) as avg_screen_views_per_session,
    AVG(unique_screens_viewed) as avg_unique_screens_per_session,
    
    -- Engagement rates
    SUM(completed_anxiety_session) * 100.0 / COUNT(*) as session_completion_rate_percent,
    SUM(created_new_anxiety) * 100.0 / COUNT(*) as new_anxiety_creation_rate_percent,
    
    -- App switching behavior
    AVG(background_events + foreground_events) as avg_app_switches_per_session
  FROM session_metrics
  WHERE session_duration_minutes >= 0 AND session_duration_minutes <= 120 -- Filter out unrealistic durations
),

session_length_distribution AS (
  SELECT
    CASE 
      WHEN session_duration_minutes < 1 THEN '< 1 min'
      WHEN session_duration_minutes < 5 THEN '1-5 min'
      WHEN session_duration_minutes < 15 THEN '5-15 min'
      WHEN session_duration_minutes < 30 THEN '15-30 min'
      ELSE '30+ min'
    END as duration_bucket,
    COUNT(*) as session_count,
    COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () as percentage
  FROM session_metrics
  WHERE session_duration_minutes >= 0 AND session_duration_minutes <= 120
  GROUP BY 
    CASE 
      WHEN session_duration_minutes < 1 THEN '< 1 min'
      WHEN session_duration_minutes < 5 THEN '1-5 min'
      WHEN session_duration_minutes < 15 THEN '5-15 min'
      WHEN session_duration_minutes < 30 THEN '15-30 min'
      ELSE '30+ min'
    END
)

-- Main summary metrics
SELECT 
  'Session Engagement Summary' as metric_type,
  total_sessions,
  total_users,
  ROUND(avg_session_duration_minutes, 2) as avg_session_duration_minutes,
  ROUND(median_session_duration_minutes, 2) as median_session_duration_minutes,
  ROUND(p90_session_duration_minutes, 2) as p90_session_duration_minutes,
  ROUND(avg_events_per_session, 1) as avg_events_per_session,
  ROUND(avg_screen_views_per_session, 1) as avg_screen_views_per_session,
  ROUND(avg_unique_screens_per_session, 1) as avg_unique_screens_per_session,
  ROUND(session_completion_rate_percent, 2) as session_completion_rate_percent,
  ROUND(new_anxiety_creation_rate_percent, 2) as new_anxiety_creation_rate_percent,
  ROUND(avg_app_switches_per_session, 1) as avg_app_switches_per_session
FROM engagement_summary

UNION ALL

-- Session duration distribution
SELECT 
  'Duration Distribution: ' || duration_bucket as metric_type,
  session_count as total_sessions,
  NULL as total_users,
  ROUND(percentage, 1) as avg_session_duration_minutes,
  NULL as median_session_duration_minutes,
  NULL as p90_session_duration_minutes,
  NULL as avg_events_per_session,
  NULL as avg_screen_views_per_session,
  NULL as avg_unique_screens_per_session,
  NULL as session_completion_rate_percent,
  NULL as new_anxiety_creation_rate_percent,
  NULL as avg_app_switches_per_session
FROM session_length_distribution
ORDER BY metric_type;
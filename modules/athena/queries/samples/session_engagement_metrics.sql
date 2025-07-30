-- Session Engagement Metrics
-- Analyzes user engagement patterns including session duration, screen views, and activity levels
-- Provides insights into user behavior and app usage patterns

WITH session_metrics AS (
  SELECT 
    session_id,
    device_id,
    COUNT(*) as total_events,
    COUNT(CASE WHEN event_type = 'screen_view' THEN 1 END) as screen_views,
    COUNT(DISTINCT screen_name) as unique_screens_viewed,
    
    -- Track specific engagement events
    MAX(CASE WHEN event_type = 'anxiety_session_completed' THEN 1 ELSE 0 END) as completed_anxiety_session,
    MAX(CASE WHEN event_type = 'new_anxiety_created' THEN 1 ELSE 0 END) as created_new_anxiety,
    
    -- App lifecycle events
    COUNT(CASE WHEN event_type = 'app_background' THEN 1 END) as background_events,
    COUNT(CASE WHEN event_type = 'app_foreground' THEN 1 END) as foreground_events
  FROM mht_api_production_data_analytics.mht_api_production_flattened_analytics_correct
  WHERE year = CAST(YEAR(CURRENT_DATE) AS VARCHAR) AND month = CAST(MONTH(CURRENT_DATE) AS VARCHAR)
    AND session_id IS NOT NULL
  GROUP BY session_id, device_id
),

engagement_summary AS (
  SELECT
    COUNT(DISTINCT session_id) as total_sessions,
    COUNT(DISTINCT device_id) as total_users,
    
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
)

SELECT 
  'Session Engagement Summary' as metric_type,
  total_sessions,
  total_users,
  ROUND(avg_events_per_session, 1) as avg_events_per_session,
  ROUND(avg_screen_views_per_session, 1) as avg_screen_views_per_session,
  ROUND(avg_unique_screens_per_session, 1) as avg_unique_screens_per_session,
  ROUND(session_completion_rate_percent, 2) as session_completion_rate_percent,
  ROUND(new_anxiety_creation_rate_percent, 2) as new_anxiety_creation_rate_percent,
  ROUND(avg_app_switches_per_session, 1) as avg_app_switches_per_session
FROM engagement_summary;
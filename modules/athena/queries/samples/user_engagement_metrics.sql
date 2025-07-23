-- User Engagement Metrics Analysis
-- This query analyzes user engagement patterns, session quality, and feature usage

WITH user_sessions AS (
  SELECT 
    user_id,
    session_id,
    year,
    month,
    day,
    MIN(timestamp) as session_start,
    MAX(timestamp) as session_end,
    COUNT(*) as events_per_session,
    COUNT(DISTINCT properties.screen_name) as unique_screens,
    COUNT(DISTINCT event_name) as unique_events,
    MAX(CAST(properties.duration as double)) as max_session_duration,
    user_properties.app_version,
    user_properties.subscription_status,
    user_properties.device_type
  FROM analytics_table
  WHERE year = '2025' 
    AND month = '07'
    AND timestamp >= CAST((current_timestamp - interval '7' day) AS bigint) * 1000
    AND event_type IN ('session_start', 'screen_view', 'user_action', 'feature_usage')
  GROUP BY 
    user_id, session_id, year, month, day,
    user_properties.app_version, user_properties.subscription_status, user_properties.device_type
),
engagement_metrics AS (
  SELECT 
    user_id,
    year,
    month,
    day,
    COUNT(DISTINCT session_id) as sessions_per_day,
    AVG(events_per_session) as avg_events_per_session,
    AVG(unique_screens) as avg_screens_per_session,
    AVG(unique_events) as avg_unique_events_per_session,
    AVG((session_end - session_start) / 1000.0) as avg_session_duration_seconds,
    MAX((session_end - session_start) / 1000.0) as max_session_duration_seconds,
    SUM(events_per_session) as total_events,
    app_version,
    subscription_status,
    device_type
  FROM user_sessions
  GROUP BY user_id, year, month, day, app_version, subscription_status, device_type
),
feature_usage AS (
  SELECT 
    year,
    month,
    day,
    properties.screen_name,
    event_name,
    COUNT(*) as usage_count,
    COUNT(DISTINCT user_id) as unique_users,
    COUNT(DISTINCT session_id) as unique_sessions,
    AVG(CAST(properties.duration as double)) as avg_interaction_duration
  FROM analytics_table
  WHERE year = '2025' 
    AND month = '07'
    AND timestamp >= CAST((current_timestamp - interval '7' day) AS bigint) * 1000
    AND event_type = 'feature_usage'
  GROUP BY year, month, day, properties.screen_name, event_name
),
engagement_segments AS (
  SELECT 
    year,
    month,
    day,
    subscription_status,
    device_type,
    COUNT(DISTINCT user_id) as total_users,
    AVG(sessions_per_day) as avg_sessions_per_user,
    AVG(avg_session_duration_seconds) as avg_session_duration,
    AVG(total_events) as avg_events_per_user,
    
    -- Engagement level classification
    COUNT(DISTINCT CASE WHEN sessions_per_day >= 3 AND avg_session_duration_seconds >= 300 THEN user_id END) as high_engagement_users,
    COUNT(DISTINCT CASE WHEN sessions_per_day >= 1 AND avg_session_duration_seconds >= 120 THEN user_id END) as medium_engagement_users,
    COUNT(DISTINCT CASE WHEN sessions_per_day < 1 OR avg_session_duration_seconds < 120 THEN user_id END) as low_engagement_users,
    
    -- Power user metrics
    COUNT(DISTINCT CASE WHEN total_events >= 50 THEN user_id END) as power_users,
    COUNT(DISTINCT CASE WHEN avg_unique_events_per_session >= 5 THEN user_id END) as diverse_feature_users
    
  FROM engagement_metrics
  GROUP BY year, month, day, subscription_status, device_type
)
SELECT 
  -- Time and segmentation
  es.year,
  es.month,
  es.day,
  es.subscription_status,
  es.device_type,
  
  -- User counts
  es.total_users,
  es.high_engagement_users,
  es.medium_engagement_users,
  es.low_engagement_users,
  es.power_users,
  es.diverse_feature_users,
  
  -- Engagement percentages
  ROUND(CAST(es.high_engagement_users as double) / CAST(es.total_users as double) * 100, 2) as high_engagement_percentage,
  ROUND(CAST(es.power_users as double) / CAST(es.total_users as double) * 100, 2) as power_user_percentage,
  
  -- Average metrics
  ROUND(es.avg_sessions_per_user, 2) as avg_sessions_per_user,
  ROUND(es.avg_session_duration, 2) as avg_session_duration_seconds,
  ROUND(es.avg_events_per_user, 2) as avg_events_per_user,
  
  -- Top features for this segment
  (SELECT fu.event_name 
   FROM feature_usage fu 
   WHERE fu.year = es.year AND fu.month = es.month AND fu.day = es.day
   ORDER BY fu.usage_count DESC 
   LIMIT 1) as top_feature,
   
  (SELECT fu.properties.screen_name 
   FROM feature_usage fu 
   WHERE fu.year = es.year AND fu.month = es.month AND fu.day = es.day
   ORDER BY fu.unique_users DESC 
   LIMIT 1) as most_popular_screen

FROM engagement_segments es
ORDER BY es.year, es.month, es.day, es.subscription_status, es.device_type;
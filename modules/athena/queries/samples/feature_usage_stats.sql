-- Feature Usage Statistics
-- This query analyzes feature adoption, usage patterns, and user preferences

WITH feature_events AS (
  SELECT 
    year,
    month,
    day,
    hour,
    user_id,
    session_id,
    event_name,
    properties.screen_name,
    properties.action,
    properties.category,
    properties.label,
    CAST(properties.value as double) as numeric_value,
    CAST(properties.duration as double) as interaction_duration,
    user_properties.app_version,
    user_properties.subscription_status,
    user_properties.device_type,
    context.os_name,
    timestamp
  FROM analytics_table
  WHERE year = '2025' 
    AND month = '07'
    AND timestamp >= CAST((current_timestamp - interval '7' day) AS bigint) * 1000
    AND event_type = 'feature_usage'
),
feature_adoption AS (
  SELECT 
    year,
    month,
    day,
    event_name,
    screen_name,
    category,
    
    -- Usage metrics
    COUNT(*) as total_usage,
    COUNT(DISTINCT user_id) as unique_users,
    COUNT(DISTINCT session_id) as unique_sessions,
    
    -- Time-based metrics
    AVG(interaction_duration) as avg_interaction_duration,
    MAX(interaction_duration) as max_interaction_duration,
    PERCENTILE_APPROX(interaction_duration, 0.5) as median_interaction_duration,
    PERCENTILE_APPROX(interaction_duration, 0.95) as p95_interaction_duration,
    
    -- Value metrics (for features that track numerical values)
    AVG(numeric_value) as avg_numeric_value,
    SUM(numeric_value) as total_numeric_value,
    
    -- Segmentation
    COUNT(DISTINCT CASE WHEN subscription_status = 'premium' THEN user_id END) as premium_users,
    COUNT(DISTINCT CASE WHEN subscription_status = 'free' THEN user_id END) as free_users,
    COUNT(DISTINCT CASE WHEN device_type = 'iPhone' THEN user_id END) as iphone_users,
    COUNT(DISTINCT CASE WHEN device_type = 'iPad' THEN user_id END) as ipad_users,
    COUNT(DISTINCT CASE WHEN device_type = 'Android' THEN user_id END) as android_users
    
  FROM feature_events
  GROUP BY year, month, day, event_name, screen_name, category
),
user_feature_patterns AS (
  SELECT 
    user_id,
    year,
    month,
    day,
    COUNT(DISTINCT event_name) as features_used,
    COUNT(DISTINCT screen_name) as screens_visited,
    COUNT(*) as total_feature_interactions,
    AVG(interaction_duration) as avg_user_interaction_duration,
    
    -- Feature diversity score (entropy-like measure)
    -SUM((CAST(COUNT(*) as double) / CAST(SUM(COUNT(*)) OVER (PARTITION BY user_id, year, month, day) as double)) * 
         LOG2(CAST(COUNT(*) as double) / CAST(SUM(COUNT(*)) OVER (PARTITION BY user_id, year, month, day) as double))) as feature_diversity_score,
    
    -- Most used feature
    array_agg(event_name ORDER BY COUNT(*) DESC)[1] as most_used_feature,
    
    subscription_status,
    device_type
  FROM feature_events
  GROUP BY user_id, year, month, day, subscription_status, device_type, event_name
),
feature_funnel AS (
  SELECT 
    year,
    month,
    day,
    screen_name,
    
    -- Step analysis (assuming screen flow)
    COUNT(DISTINCT CASE WHEN action = 'view' THEN user_id END) as users_viewed,
    COUNT(DISTINCT CASE WHEN action = 'interact' THEN user_id END) as users_interacted,
    COUNT(DISTINCT CASE WHEN action = 'complete' THEN user_id END) as users_completed,
    
    -- Conversion rates
    ROUND(CAST(COUNT(DISTINCT CASE WHEN action = 'interact' THEN user_id END) as double) / 
          CAST(COUNT(DISTINCT CASE WHEN action = 'view' THEN user_id END) as double) * 100, 2) as view_to_interaction_rate,
    ROUND(CAST(COUNT(DISTINCT CASE WHEN action = 'complete' THEN user_id END) as double) / 
          CAST(COUNT(DISTINCT CASE WHEN action = 'interact' THEN user_id END) as double) * 100, 2) as interaction_to_completion_rate
    
  FROM feature_events
  WHERE action IN ('view', 'interact', 'complete')
  GROUP BY year, month, day, screen_name
)
SELECT 
  -- Time dimension
  fa.year,
  fa.month,
  fa.day,
  
  -- Feature identification
  fa.event_name,
  fa.screen_name,
  fa.category,
  
  -- Usage metrics
  fa.total_usage,
  fa.unique_users,
  fa.unique_sessions,
  ROUND(CAST(fa.total_usage as double) / CAST(fa.unique_users as double), 2) as usage_per_user,
  
  -- Time metrics
  ROUND(fa.avg_interaction_duration, 2) as avg_interaction_duration_seconds,
  ROUND(fa.median_interaction_duration, 2) as median_interaction_duration_seconds,
  ROUND(fa.p95_interaction_duration, 2) as p95_interaction_duration_seconds,
  
  -- Value metrics
  ROUND(fa.avg_numeric_value, 2) as avg_numeric_value,
  ROUND(fa.total_numeric_value, 2) as total_numeric_value,
  
  -- User segmentation
  fa.premium_users,
  fa.free_users,
  ROUND(CAST(fa.premium_users as double) / CAST(fa.unique_users as double) * 100, 2) as premium_user_percentage,
  
  -- Device breakdown
  fa.iphone_users,
  fa.ipad_users,
  fa.android_users,
  
  -- Feature ranking
  ROW_NUMBER() OVER (PARTITION BY fa.year, fa.month, fa.day ORDER BY fa.total_usage DESC) as usage_rank,
  ROW_NUMBER() OVER (PARTITION BY fa.year, fa.month, fa.day ORDER BY fa.unique_users DESC) as adoption_rank,
  
  -- Funnel metrics (if available)
  ff.users_viewed,
  ff.users_interacted,
  ff.users_completed,
  ff.view_to_interaction_rate,
  ff.interaction_to_completion_rate

FROM feature_adoption fa
LEFT JOIN feature_funnel ff ON fa.year = ff.year AND fa.month = ff.month AND fa.day = ff.day AND fa.screen_name = ff.screen_name
WHERE fa.unique_users >= 5  -- Filter out features with very low adoption
ORDER BY fa.year, fa.month, fa.day, fa.total_usage DESC;
-- Create Daily Metrics View
-- This view pre-aggregates daily metrics for faster querying and dashboards

CREATE OR REPLACE VIEW `${database_name}`.`${view_name}` AS
WITH daily_aggregates AS (
  SELECT 
    year,
    month,
    day,
    
    -- User metrics
    COUNT(DISTINCT user_id) as daily_active_users,
    COUNT(DISTINCT CASE WHEN event_type = 'first_open' THEN user_id END) as new_users,
    COUNT(DISTINCT session_id) as total_sessions,
    COUNT(*) as total_events,
    
    -- Engagement metrics
    AVG(CAST(properties.duration as double)) as avg_session_duration,
    PERCENTILE_APPROX(CAST(properties.duration as double), 0.5) as median_session_duration,
    COUNT(DISTINCT properties.screen_name) as unique_screens_accessed,
    COUNT(DISTINCT event_name) as unique_events_triggered,
    
    -- User segments
    COUNT(DISTINCT CASE WHEN user_properties.subscription_status = 'premium' THEN user_id END) as premium_users,
    COUNT(DISTINCT CASE WHEN user_properties.subscription_status = 'free' THEN user_id END) as free_users,
    COUNT(DISTINCT CASE WHEN user_properties.device_type = 'iPhone' THEN user_id END) as iphone_users,
    COUNT(DISTINCT CASE WHEN user_properties.device_type = 'iPad' THEN user_id END) as ipad_users,
    COUNT(DISTINCT CASE WHEN user_properties.device_type = 'Android' THEN user_id END) as android_users,
    
    -- App versions
    COUNT(DISTINCT user_properties.app_version) as app_versions_active,
    mode() WITHIN GROUP (ORDER BY user_properties.app_version) as most_common_app_version,
    
    -- Geographic distribution
    COUNT(DISTINCT user_properties.country) as countries_active,
    mode() WITHIN GROUP (ORDER BY user_properties.country) as most_common_country,
    
    -- Event type breakdown
    COUNT(CASE WHEN event_type = 'session_start' THEN 1 END) as session_starts,
    COUNT(CASE WHEN event_type = 'screen_view' THEN 1 END) as screen_views,
    COUNT(CASE WHEN event_type = 'user_action' THEN 1 END) as user_actions,
    COUNT(CASE WHEN event_type = 'feature_usage' THEN 1 END) as feature_usages,
    COUNT(CASE WHEN event_type = 'error' THEN 1 END) as errors,
    COUNT(CASE WHEN event_type = 'crash' THEN 1 END) as crashes,
    
    -- Performance indicators
    AVG(CASE WHEN event_type = 'performance' THEN CAST(properties.duration as double) END) as avg_performance_load_time,
    PERCENTILE_APPROX(CASE WHEN event_type = 'performance' THEN CAST(properties.duration as double) END, 0.95) as p95_performance_load_time,
    
    -- Quality metrics
    ROUND(CAST(COUNT(CASE WHEN event_type = 'error' THEN 1 END) as double) / CAST(COUNT(*) as double) * 100, 4) as error_rate_percent,
    ROUND(CAST(COUNT(CASE WHEN event_type = 'crash' THEN 1 END) as double) / CAST(COUNT(DISTINCT session_id) as double) * 100, 4) as crash_rate_percent
    
  FROM `${database_name}`.`${analytics_table}`
  WHERE year >= '2025'
    AND timestamp >= CAST((current_timestamp - interval '90' day) AS bigint) * 1000
  GROUP BY year, month, day
),
retention_metrics AS (
  SELECT 
    a.year,
    a.month,
    a.day,
    COUNT(DISTINCT a.user_id) as new_users_base,
    COUNT(DISTINCT r1.user_id) as day_1_retained,
    COUNT(DISTINCT r7.user_id) as day_7_retained,
    COUNT(DISTINCT r30.user_id) as day_30_retained
  FROM `${database_name}`.`${analytics_table}` a
  LEFT JOIN `${database_name}`.`${analytics_table}` r1 
    ON a.user_id = r1.user_id 
    AND r1.timestamp >= (a.timestamp + 86400000)  -- 1 day later
    AND r1.timestamp < (a.timestamp + 172800000)  -- 2 days later
  LEFT JOIN `${database_name}`.`${analytics_table}` r7 
    ON a.user_id = r7.user_id 
    AND r7.timestamp >= (a.timestamp + 604800000)  -- 7 days later
    AND r7.timestamp < (a.timestamp + 691200000)   -- 8 days later
  LEFT JOIN `${database_name}`.`${analytics_table}` r30 
    ON a.user_id = r30.user_id 
    AND r30.timestamp >= (a.timestamp + 2592000000)  -- 30 days later
    AND r30.timestamp < (a.timestamp + 2678400000)   -- 31 days later
  WHERE a.event_type = 'first_open'
    AND a.year >= '2025'
    AND a.timestamp >= CAST((current_timestamp - interval '90' day) AS bigint) * 1000
  GROUP BY a.year, a.month, a.day
),
feature_popularity AS (
  SELECT 
    year,
    month,
    day,
    array_agg(
      STRUCT(
        event_name,
        usage_count,
        unique_users
      )
      ORDER BY usage_count DESC
      LIMIT 10
    ) as top_features
  FROM (
    SELECT 
      year,
      month,
      day,
      event_name,
      COUNT(*) as usage_count,
      COUNT(DISTINCT user_id) as unique_users
    FROM `${database_name}`.`${analytics_table}`
    WHERE event_type = 'feature_usage'
      AND year >= '2025'
      AND timestamp >= CAST((current_timestamp - interval '90' day) AS bigint) * 1000
    GROUP BY year, month, day, event_name
  ) feature_stats
  GROUP BY year, month, day
)
SELECT 
  -- Date dimension
  da.year,
  da.month,
  da.day,
  date_parse(concat(da.year, '-', da.month, '-', da.day), '%Y-%m-%d') as date_value,
  
  -- User metrics
  da.daily_active_users,
  da.new_users,
  da.total_sessions,
  da.total_events,
  
  -- Calculated metrics
  ROUND(CAST(da.total_sessions as double) / CAST(da.daily_active_users as double), 2) as avg_sessions_per_user,
  ROUND(CAST(da.total_events as double) / CAST(da.daily_active_users as double), 2) as avg_events_per_user,
  ROUND(CAST(da.total_events as double) / CAST(da.total_sessions as double), 2) as avg_events_per_session,
  
  -- Engagement
  ROUND(da.avg_session_duration, 2) as avg_session_duration_seconds,
  ROUND(da.median_session_duration, 2) as median_session_duration_seconds,
  da.unique_screens_accessed,
  da.unique_events_triggered,
  
  -- User segments
  da.premium_users,
  da.free_users,
  ROUND(CAST(da.premium_users as double) / CAST(da.daily_active_users as double) * 100, 2) as premium_user_percentage,
  
  -- Device breakdown
  da.iphone_users,
  da.ipad_users,
  da.android_users,
  
  -- App health
  da.app_versions_active,
  da.most_common_app_version,
  da.countries_active,
  da.most_common_country,
  
  -- Event breakdown
  da.session_starts,
  da.screen_views,
  da.user_actions,
  da.feature_usages,
  da.errors,
  da.crashes,
  
  -- Performance
  ROUND(da.avg_performance_load_time, 2) as avg_performance_load_time_ms,
  ROUND(da.p95_performance_load_time, 2) as p95_performance_load_time_ms,
  
  -- Quality metrics
  da.error_rate_percent,
  da.crash_rate_percent,
  
  -- Retention metrics
  rm.new_users_base,
  rm.day_1_retained,
  rm.day_7_retained,
  rm.day_30_retained,
  ROUND(CAST(rm.day_1_retained as double) / CAST(rm.new_users_base as double) * 100, 2) as day_1_retention_rate,
  ROUND(CAST(rm.day_7_retained as double) / CAST(rm.new_users_base as double) * 100, 2) as day_7_retention_rate,
  ROUND(CAST(rm.day_30_retained as double) / CAST(rm.new_users_base as double) * 100, 2) as day_30_retention_rate,
  
  -- Feature popularity
  fp.top_features

FROM daily_aggregates da
LEFT JOIN retention_metrics rm ON da.year = rm.year AND da.month = rm.month AND da.day = rm.day
LEFT JOIN feature_popularity fp ON da.year = fp.year AND da.month = fp.month AND da.day = fp.day
ORDER BY da.year, da.month, da.day;
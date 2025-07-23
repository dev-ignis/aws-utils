-- Error Rate Analysis
-- This query analyzes error patterns, crash rates, and performance issues

WITH error_events AS (
  SELECT 
    year,
    month,
    day,
    hour,
    event_type,
    properties.category as error_category,
    properties.label as error_message,
    user_properties.app_version,
    user_properties.os_version,
    user_properties.device_type,
    context.device_model,
    COUNT(*) as error_count,
    COUNT(DISTINCT user_id) as affected_users,
    COUNT(DISTINCT session_id) as affected_sessions
  FROM analytics_table
  WHERE year = '2025' 
    AND month = '07'
    AND (event_type = 'error' OR event_type = 'crash' OR event_type = 'exception')
    AND timestamp >= CAST((current_timestamp - interval '7' day) AS bigint) * 1000
  GROUP BY 
    year, month, day, hour, event_type, 
    properties.category, properties.label,
    user_properties.app_version, user_properties.os_version, 
    user_properties.device_type, context.device_model
),
total_events AS (
  SELECT 
    year,
    month,
    day,
    hour,
    COUNT(*) as total_events,
    COUNT(DISTINCT user_id) as total_users,
    COUNT(DISTINCT session_id) as total_sessions
  FROM analytics_table
  WHERE year = '2025' 
    AND month = '07'
    AND timestamp >= CAST((current_timestamp - interval '7' day) AS bigint) * 1000
  GROUP BY year, month, day, hour
),
hourly_error_rates AS (
  SELECT 
    te.year,
    te.month,
    te.day,
    te.hour,
    COALESCE(SUM(ee.error_count), 0) as total_errors,
    te.total_events,
    COALESCE(COUNT(DISTINCT ee.affected_users), 0) as total_affected_users,
    te.total_users,
    ROUND(CAST(COALESCE(SUM(ee.error_count), 0) as double) / CAST(te.total_events as double) * 100, 4) as error_rate_percent,
    ROUND(CAST(COALESCE(COUNT(DISTINCT ee.affected_users), 0) as double) / CAST(te.total_users as double) * 100, 4) as user_impact_percent
  FROM total_events te
  LEFT JOIN error_events ee ON te.year = ee.year AND te.month = ee.month AND te.day = ee.day AND te.hour = ee.hour
  GROUP BY te.year, te.month, te.day, te.hour, te.total_events, te.total_users
)
SELECT 
  -- Time dimension
  year,
  month,
  day,
  hour,
  
  -- Error metrics
  total_errors,
  total_events,
  error_rate_percent,
  
  -- User impact
  total_affected_users,
  total_users,
  user_impact_percent,
  
  -- Top error categories
  (SELECT error_category 
   FROM error_events ee2 
   WHERE ee2.year = her.year AND ee2.month = her.month AND ee2.day = her.day AND ee2.hour = her.hour
   GROUP BY error_category 
   ORDER BY SUM(error_count) DESC 
   LIMIT 1) as top_error_category,
   
  -- Most affected app version
  (SELECT app_version 
   FROM error_events ee3 
   WHERE ee3.year = her.year AND ee3.month = her.month AND ee3.day = her.day AND ee3.hour = her.hour
   GROUP BY app_version 
   ORDER BY SUM(error_count) DESC 
   LIMIT 1) as most_affected_app_version,
   
  -- Most affected device type
  (SELECT device_type 
   FROM error_events ee4 
   WHERE ee4.year = her.year AND ee4.month = her.month AND ee4.day = her.day AND ee4.hour = her.hour
   GROUP BY device_type 
   ORDER BY SUM(error_count) DESC 
   LIMIT 1) as most_affected_device_type

FROM hourly_error_rates her
WHERE total_errors > 0
ORDER BY year, month, day, hour;
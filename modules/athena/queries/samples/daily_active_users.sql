-- Daily Active Users Analysis
-- This query calculates daily active users, new users, and retention metrics

WITH daily_users AS (
  SELECT 
    year,
    month,
    day,
    COUNT(DISTINCT user_id) as total_users,
    COUNT(DISTINCT CASE WHEN event_type = 'first_open' THEN user_id END) as new_users,
    COUNT(DISTINCT CASE WHEN event_type = 'session_start' THEN user_id END) as returning_users,
    COUNT(*) as total_events,
    AVG(CAST(properties.duration as double)) as avg_session_duration
  FROM analytics_table
  WHERE year = '2025' 
    AND month = '07'
    AND day >= '01'
    AND timestamp >= CAST((current_timestamp - interval '30' day) AS bigint) * 1000
  GROUP BY year, month, day
),
user_retention AS (
  SELECT 
    year,
    month,
    day,
    COUNT(DISTINCT a1.user_id) as day_1_retention,
    COUNT(DISTINCT a7.user_id) as day_7_retention,
    COUNT(DISTINCT a30.user_id) as day_30_retention
  FROM analytics_table a
  LEFT JOIN analytics_table a1 ON a.user_id = a1.user_id 
    AND a1.timestamp >= (a.timestamp + 86400000)  -- 1 day later
    AND a1.timestamp < (a.timestamp + 172800000)  -- 2 days later
  LEFT JOIN analytics_table a7 ON a.user_id = a7.user_id 
    AND a7.timestamp >= (a.timestamp + 604800000)  -- 7 days later
    AND a7.timestamp < (a.timestamp + 691200000)   -- 8 days later
  LEFT JOIN analytics_table a30 ON a.user_id = a30.user_id 
    AND a30.timestamp >= (a.timestamp + 2592000000)  -- 30 days later
    AND a30.timestamp < (a.timestamp + 2678400000)   -- 31 days later
  WHERE a.event_type = 'first_open'
    AND a.year = '2025' 
    AND a.month = '07'
  GROUP BY year, month, day
)
SELECT 
  du.year,
  du.month,
  du.day,
  du.total_users,
  du.new_users,
  du.returning_users,
  du.total_events,
  ROUND(du.avg_session_duration, 2) as avg_session_duration_seconds,
  ROUND(CAST(du.new_users as double) / CAST(du.total_users as double) * 100, 2) as new_user_percentage,
  ROUND(CAST(ur.day_1_retention as double) / CAST(du.new_users as double) * 100, 2) as day_1_retention_rate,
  ROUND(CAST(ur.day_7_retention as double) / CAST(du.new_users as double) * 100, 2) as day_7_retention_rate,
  ROUND(CAST(ur.day_30_retention as double) / CAST(du.new_users as double) * 100, 2) as day_30_retention_rate
FROM daily_users du
LEFT JOIN user_retention ur ON du.year = ur.year AND du.month = ur.month AND du.day = ur.day
ORDER BY du.year, du.month, du.day;
-- Performance Metrics Analysis
-- This query analyzes app performance, load times, and user experience metrics

WITH performance_events AS (
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
    CAST(properties.duration as double) as load_time_ms,
    CAST(properties.value as double) as performance_score,
    user_properties.app_version,
    user_properties.device_type,
    user_properties.os_version,
    context.device_model,
    context.network_type,
    timestamp
  FROM analytics_table
  WHERE year = '2025' 
    AND month = '07'
    AND timestamp >= CAST((current_timestamp - interval '7' day) AS bigint) * 1000
    AND event_type = 'performance'
    AND properties.duration IS NOT NULL
),
screen_performance AS (
  SELECT 
    year,
    month,
    day,
    screen_name,
    app_version,
    device_type,
    network_type,
    
    -- Load time metrics
    COUNT(*) as total_loads,
    AVG(load_time_ms) as avg_load_time_ms,
    PERCENTILE_APPROX(load_time_ms, 0.5) as median_load_time_ms,
    PERCENTILE_APPROX(load_time_ms, 0.95) as p95_load_time_ms,
    PERCENTILE_APPROX(load_time_ms, 0.99) as p99_load_time_ms,
    MIN(load_time_ms) as min_load_time_ms,
    MAX(load_time_ms) as max_load_time_ms,
    STDDEV(load_time_ms) as load_time_stddev,
    
    -- Performance score metrics
    AVG(performance_score) as avg_performance_score,
    PERCENTILE_APPROX(performance_score, 0.5) as median_performance_score,
    
    -- Slow load analysis
    COUNT(CASE WHEN load_time_ms > 3000 THEN 1 END) as slow_loads_3s,
    COUNT(CASE WHEN load_time_ms > 5000 THEN 1 END) as slow_loads_5s,
    COUNT(CASE WHEN load_time_ms > 10000 THEN 1 END) as slow_loads_10s,
    
    -- User impact
    COUNT(DISTINCT user_id) as unique_users_affected,
    COUNT(DISTINCT session_id) as unique_sessions_affected
    
  FROM performance_events
  GROUP BY year, month, day, screen_name, app_version, device_type, network_type
),
device_performance AS (
  SELECT 
    year,
    month,
    day,
    device_type,
    device_model,
    os_version,
    network_type,
    
    -- Aggregated metrics
    COUNT(*) as total_performance_events,
    COUNT(DISTINCT user_id) as unique_users,
    AVG(load_time_ms) as avg_load_time_ms,
    PERCENTILE_APPROX(load_time_ms, 0.95) as p95_load_time_ms,
    AVG(performance_score) as avg_performance_score,
    
    -- Performance buckets
    COUNT(CASE WHEN load_time_ms <= 1000 THEN 1 END) as excellent_performance,
    COUNT(CASE WHEN load_time_ms > 1000 AND load_time_ms <= 3000 THEN 1 END) as good_performance,
    COUNT(CASE WHEN load_time_ms > 3000 AND load_time_ms <= 5000 THEN 1 END) as fair_performance,
    COUNT(CASE WHEN load_time_ms > 5000 THEN 1 END) as poor_performance
    
  FROM performance_events
  GROUP BY year, month, day, device_type, device_model, os_version, network_type
),
performance_trends AS (
  SELECT 
    year,
    month,
    day,
    hour,
    COUNT(*) as hourly_loads,
    AVG(load_time_ms) as avg_hourly_load_time,
    PERCENTILE_APPROX(load_time_ms, 0.95) as p95_hourly_load_time,
    COUNT(CASE WHEN load_time_ms > 3000 THEN 1 END) as hourly_slow_loads,
    
    -- Performance degradation detection
    AVG(load_time_ms) - LAG(AVG(load_time_ms)) OVER (ORDER BY year, month, day, hour) as load_time_change_ms,
    
    -- Network impact
    AVG(CASE WHEN network_type = 'WiFi' THEN load_time_ms END) as wifi_avg_load_time,
    AVG(CASE WHEN network_type = 'Cellular' THEN load_time_ms END) as cellular_avg_load_time,
    AVG(CASE WHEN network_type = '5G' THEN load_time_ms END) as five_g_avg_load_time
    
  FROM performance_events
  GROUP BY year, month, day, hour
),
performance_anomalies AS (
  SELECT 
    year,
    month,
    day,
    hour,
    screen_name,
    app_version,
    device_type,
    AVG(load_time_ms) as avg_load_time,
    
    -- Anomaly detection (loads > 2 standard deviations from mean)
    CASE 
      WHEN AVG(load_time_ms) > (
        SELECT AVG(load_time_ms) + 2 * STDDEV(load_time_ms) 
        FROM performance_events pe2 
        WHERE pe2.year = performance_events.year 
          AND pe2.month = performance_events.month 
          AND pe2.day = performance_events.day
      ) THEN 'HIGH_LOAD_TIME_ANOMALY'
      ELSE 'NORMAL'
    END as anomaly_status
    
  FROM performance_events
  GROUP BY year, month, day, hour, screen_name, app_version, device_type
  HAVING COUNT(*) >= 10  -- Only consider periods with sufficient data
)
SELECT 
  -- Time dimension
  sp.year,
  sp.month,
  sp.day,
  
  -- Screen/feature identification
  sp.screen_name,
  sp.app_version,
  sp.device_type,
  sp.network_type,
  
  -- Load time metrics
  sp.total_loads,
  ROUND(sp.avg_load_time_ms, 2) as avg_load_time_ms,
  ROUND(sp.median_load_time_ms, 2) as median_load_time_ms,
  ROUND(sp.p95_load_time_ms, 2) as p95_load_time_ms,
  ROUND(sp.p99_load_time_ms, 2) as p99_load_time_ms,
  ROUND(sp.load_time_stddev, 2) as load_time_stddev_ms,
  
  -- Performance score
  ROUND(sp.avg_performance_score, 2) as avg_performance_score,
  ROUND(sp.median_performance_score, 2) as median_performance_score,
  
  -- Slow load analysis
  sp.slow_loads_3s,
  sp.slow_loads_5s,
  sp.slow_loads_10s,
  ROUND(CAST(sp.slow_loads_3s as double) / CAST(sp.total_loads as double) * 100, 2) as slow_load_percentage_3s,
  ROUND(CAST(sp.slow_loads_5s as double) / CAST(sp.total_loads as double) * 100, 2) as slow_load_percentage_5s,
  
  -- User impact
  sp.unique_users_affected,
  sp.unique_sessions_affected,
  
  -- Performance rating
  CASE 
    WHEN sp.p95_load_time_ms <= 1000 THEN 'EXCELLENT'
    WHEN sp.p95_load_time_ms <= 3000 THEN 'GOOD'
    WHEN sp.p95_load_time_ms <= 5000 THEN 'FAIR'
    ELSE 'POOR'
  END as performance_rating,
  
  -- Ranking
  ROW_NUMBER() OVER (PARTITION BY sp.year, sp.month, sp.day ORDER BY sp.p95_load_time_ms DESC) as slowest_screen_rank,
  ROW_NUMBER() OVER (PARTITION BY sp.year, sp.month, sp.day ORDER BY sp.slow_loads_3s DESC) as most_problematic_rank

FROM screen_performance sp
WHERE sp.total_loads >= 10  -- Filter out screens with very low usage
ORDER BY sp.year, sp.month, sp.day, sp.p95_load_time_ms DESC;
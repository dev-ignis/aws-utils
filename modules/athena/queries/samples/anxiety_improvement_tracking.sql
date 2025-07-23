WITH user_anxiety_timeline AS (
  SELECT 
    device_id,
    CAST(danger_level AS DOUBLE) as danger_level,
    CAST(probability_level AS DOUBLE) as probability_level,
    DATE(from_unixtime(CAST(event_timestamp AS BIGINT)/1000)) as session_date,
    event_timestamp,
    focus,
    response,
    ROW_NUMBER() OVER (PARTITION BY device_id ORDER BY event_timestamp) as session_number,
    COUNT(*) OVER (PARTITION BY device_id) as total_sessions
  FROM mht_api_production_data_analytics.mht_api_production_flattened_analytics_correct
  WHERE event_type = 'anxiety_session_completed'
    AND danger_level IS NOT NULL
    AND probability_level IS NOT NULL
    AND year = CAST(YEAR(CURRENT_DATE) AS VARCHAR)
    AND month = CAST(MONTH(CURRENT_DATE) AS VARCHAR)
),

user_progress_metrics AS (
  SELECT 
    device_id,
    total_sessions,
    
    -- First and last session metrics
    MIN(CASE WHEN session_number = 1 THEN danger_level END) as first_danger_level,
    MAX(CASE WHEN session_number = total_sessions THEN danger_level END) as latest_danger_level,
    MIN(CASE WHEN session_number = 1 THEN probability_level END) as first_probability_level,
    MAX(CASE WHEN session_number = total_sessions THEN probability_level END) as latest_probability_level,
    
    -- Overall averages
    AVG(danger_level) as avg_danger_level,
    AVG(probability_level) as avg_probability_level,
    
    -- Trends (using linear regression approximation)
    CORR(session_number, danger_level) as danger_trend_correlation,
    CORR(session_number, probability_level) as probability_trend_correlation,
    
    -- Session patterns
    MIN(session_date) as first_session_date,
    MAX(session_date) as last_session_date,
    COUNT(DISTINCT session_date) as active_days,
    
    -- Most common response
    MODE() WITHIN GROUP (ORDER BY response) as most_common_response,
    MODE() WITHIN GROUP (ORDER BY focus) as most_common_focus
    
  FROM user_anxiety_timeline
  GROUP BY device_id, total_sessions
  HAVING total_sessions >= 3
),

improvement_categories AS (
  SELECT 
    device_id,
    total_sessions,
    active_days,
    first_session_date,
    last_session_date,
    most_common_response,
    most_common_focus,
    
    first_danger_level,
    latest_danger_level,
    (first_danger_level - latest_danger_level) as danger_improvement,
    
    first_probability_level,
    latest_probability_level,
    (first_probability_level - latest_probability_level) as probability_improvement,
    
    avg_danger_level,
    avg_probability_level,
    danger_trend_correlation,
    probability_trend_correlation,
    
    CASE 
      WHEN (first_danger_level - latest_danger_level) >= 2 THEN 'Significant Improvement'
      WHEN (first_danger_level - latest_danger_level) >= 1 THEN 'Moderate Improvement'
      WHEN (first_danger_level - latest_danger_level) > 0 THEN 'Slight Improvement'
      WHEN (first_danger_level - latest_danger_level) = 0 THEN 'No Change'
      ELSE 'Worsened'
    END as improvement_category,
    
    CASE 
      WHEN danger_trend_correlation < -0.3 THEN 'Strong Downward Trend'
      WHEN danger_trend_correlation < -0.1 THEN 'Moderate Downward Trend'
      WHEN danger_trend_correlation < 0.1 THEN 'Stable'
      ELSE 'Upward Trend'
    END as trend_analysis
    
  FROM user_progress_metrics
)

SELECT 
  improvement_category,
  trend_analysis,
  most_common_response,
  most_common_focus,
  
  COUNT(*) as user_count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentage_of_users,
  
  ROUND(AVG(total_sessions), 1) as avg_total_sessions,
  ROUND(AVG(active_days), 1) as avg_active_days,
  ROUND(AVG(danger_improvement), 2) as avg_danger_reduction,
  ROUND(AVG(probability_improvement), 2) as avg_probability_reduction,
  
  ROUND(AVG(first_danger_level), 2) as avg_initial_danger,
  ROUND(AVG(latest_danger_level), 2) as avg_final_danger,
  ROUND(AVG(avg_danger_level), 2) as avg_overall_danger,
  
  MIN(first_session_date) as earliest_user_start,
  MAX(last_session_date) as latest_user_activity

FROM improvement_categories
GROUP BY improvement_category, trend_analysis, most_common_response, most_common_focus
ORDER BY 
  CASE improvement_category 
    WHEN 'Significant Improvement' THEN 1
    WHEN 'Moderate Improvement' THEN 2  
    WHEN 'Slight Improvement' THEN 3
    WHEN 'No Change' THEN 4
    ELSE 5
  END,
  user_count DESC
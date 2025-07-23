WITH user_risk_signals AS (
  SELECT 
    device_id,
    event_timestamp,
    CAST(danger_level AS DOUBLE) as danger_level,
    CAST(probability_level AS DOUBLE) as probability_level,
    response,
    focus,
    specific_focus,
    DATE(from_unixtime(CAST(event_timestamp AS BIGINT)/1000)) as session_date,
    
    ROW_NUMBER() OVER (PARTITION BY device_id ORDER BY event_timestamp DESC) as recency_rank,
    COUNT(*) OVER (PARTITION BY device_id) as total_sessions,
    
    AVG(CAST(danger_level AS DOUBLE)) OVER (
      PARTITION BY device_id 
      ORDER BY event_timestamp 
      ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) as recent_avg_danger,
    
    MAX(CAST(danger_level AS DOUBLE)) OVER (
      PARTITION BY device_id 
      ORDER BY event_timestamp 
      ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) as recent_max_danger
    
  FROM mht_api_production_data_analytics.mht_api_production_flattened_analytics_correct
  WHERE event_type = 'anxiety_session_completed'
    AND danger_level IS NOT NULL
    AND probability_level IS NOT NULL
    AND year = CAST(YEAR(CURRENT_DATE) AS VARCHAR)
    AND month = CAST(MONTH(CURRENT_DATE) AS VARCHAR)
),

crisis_indicators AS (
  SELECT 
    device_id,
    total_sessions,
    
    -- Latest session metrics
    MAX(CASE WHEN recency_rank = 1 THEN danger_level END) as latest_danger_level,
    MAX(CASE WHEN recency_rank = 1 THEN probability_level END) as latest_probability_level,
    MAX(CASE WHEN recency_rank = 1 THEN session_date END) as last_session_date,
    MAX(CASE WHEN recency_rank = 1 THEN recent_avg_danger END) as recent_avg_danger,
    MAX(CASE WHEN recency_rank = 1 THEN recent_max_danger END) as recent_max_danger,
    
    -- Pattern analysis
    COUNT(CASE WHEN danger_level >= 8 THEN 1 END) as high_danger_sessions,
    COUNT(CASE WHEN danger_level >= 9 THEN 1 END) as extreme_danger_sessions,
    COUNT(CASE WHEN probability_level >= 8 THEN 1 END) as high_probability_sessions,
    
    -- Recent pattern (last 7 sessions)
    COUNT(CASE WHEN recency_rank <= 7 AND danger_level >= 7 THEN 1 END) as recent_concerning_sessions,
    COUNT(CASE WHEN recency_rank <= 3 AND danger_level >= 8 THEN 1 END) as very_recent_high_danger,
    
    -- Response patterns
    COUNT(CASE WHEN response = 'Increase' AND danger_level >= 7 THEN 1 END) as concerning_increase_responses,
    COUNT(CASE WHEN recency_rank <= 5 THEN 1 END) as recent_session_count,
    
    -- Focus patterns indicating distress
    COUNT(CASE WHEN focus LIKE '%crisis%' OR focus LIKE '%emergency%' OR focus LIKE '%harm%' THEN 1 END) as crisis_focus_sessions,
    
    -- Most common recent focus
    MODE() WITHIN GROUP (ORDER BY CASE WHEN recency_rank <= 5 THEN focus END) as recent_primary_focus
    
  FROM user_risk_signals
  GROUP BY device_id, total_sessions
),

risk_assessment AS (
  SELECT 
    device_id,
    total_sessions,
    latest_danger_level,
    latest_probability_level,
    last_session_date,
    recent_avg_danger,
    recent_max_danger,
    high_danger_sessions,
    extreme_danger_sessions,
    recent_concerning_sessions,
    very_recent_high_danger,
    concerning_increase_responses,
    crisis_focus_sessions,
    recent_primary_focus,
    
    -- Days since last session
    DATE_DIFF('day', last_session_date, CURRENT_DATE) as days_since_last_session,
    
    -- Risk scoring
    (CASE WHEN latest_danger_level >= 9 THEN 4
          WHEN latest_danger_level >= 8 THEN 3  
          WHEN latest_danger_level >= 7 THEN 2
          WHEN latest_danger_level >= 6 THEN 1
          ELSE 0 END) +
    (CASE WHEN recent_avg_danger >= 8 THEN 3
          WHEN recent_avg_danger >= 7 THEN 2
          WHEN recent_avg_danger >= 6 THEN 1
          ELSE 0 END) +
    (CASE WHEN very_recent_high_danger >= 2 THEN 3
          WHEN very_recent_high_danger >= 1 THEN 2
          ELSE 0 END) +
    (CASE WHEN extreme_danger_sessions >= 3 THEN 2
          WHEN extreme_danger_sessions >= 1 THEN 1
          ELSE 0 END) +
    (CASE WHEN concerning_increase_responses >= 2 THEN 2
          WHEN concerning_increase_responses >= 1 THEN 1
          ELSE 0 END) +
    (CASE WHEN crisis_focus_sessions >= 1 THEN 3 ELSE 0 END) as risk_score,
    
    -- Risk categorization
    CASE 
      WHEN latest_danger_level >= 9 OR very_recent_high_danger >= 2 OR crisis_focus_sessions > 0 THEN 'CRITICAL'
      WHEN latest_danger_level >= 8 OR recent_avg_danger >= 8 OR extreme_danger_sessions >= 2 THEN 'HIGH'
      WHEN latest_danger_level >= 7 OR recent_avg_danger >= 7 OR high_danger_sessions >= 5 THEN 'MODERATE'
      WHEN latest_danger_level >= 6 OR high_danger_sessions >= 3 THEN 'ELEVATED'
      ELSE 'LOW'
    END as risk_level
    
  FROM crisis_indicators
  WHERE total_sessions >= 2
)

SELECT 
  device_id,
  risk_level,
  risk_score,
  latest_danger_level,
  latest_probability_level,
  recent_avg_danger,
  recent_max_danger,
  last_session_date,
  days_since_last_session,
  total_sessions,
  high_danger_sessions,
  extreme_danger_sessions,
  very_recent_high_danger,
  concerning_increase_responses,
  crisis_focus_sessions,
  recent_primary_focus,
  
  -- Urgency flags
  CASE WHEN days_since_last_session = 0 THEN 'Active Today'
       WHEN days_since_last_session <= 1 THEN 'Recent Activity'
       WHEN days_since_last_session <= 3 THEN 'Moderately Recent'
       WHEN days_since_last_session <= 7 THEN 'Week Ago'
       ELSE 'Inactive >7 days' END as activity_recency,
       
  CASE WHEN risk_level = 'CRITICAL' AND days_since_last_session <= 1 THEN 'IMMEDIATE ATTENTION NEEDED'
       WHEN risk_level = 'HIGH' AND days_since_last_session <= 2 THEN 'Priority Follow-up'
       WHEN risk_level = 'MODERATE' AND days_since_last_session <= 3 THEN 'Check-in Recommended'
       ELSE 'Monitor' END as intervention_recommendation

FROM risk_assessment
WHERE risk_level IN ('CRITICAL', 'HIGH', 'MODERATE')
   OR (risk_level = 'ELEVATED' AND days_since_last_session <= 1)
ORDER BY 
  CASE risk_level 
    WHEN 'CRITICAL' THEN 1
    WHEN 'HIGH' THEN 2
    WHEN 'MODERATE' THEN 3
    ELSE 4
  END,
  days_since_last_session ASC,
  risk_score DESC
WITH user_activity_timeline AS (
  SELECT 
    device_id,
    DATE(from_unixtime(CAST(event_timestamp AS BIGINT)/1000)) as activity_date,
    MIN(DATE(from_unixtime(CAST(event_timestamp AS BIGINT)/1000))) OVER (PARTITION BY device_id) as first_activity_date,
    MAX(DATE(from_unixtime(CAST(event_timestamp AS BIGINT)/1000))) OVER (PARTITION BY device_id) as last_activity_date,
    event_type,
    COUNT(*) as daily_events,
    COUNT(CASE WHEN event_type = 'anxiety_session_completed' THEN 1 END) as daily_anxiety_sessions
  FROM mht_api_production_data_analytics.mht_api_production_flattened_analytics_correct
  WHERE year = CAST(YEAR(CURRENT_DATE) AS VARCHAR)
    AND month = CAST(MONTH(CURRENT_DATE) AS VARCHAR)
  GROUP BY device_id, DATE(from_unixtime(CAST(event_timestamp AS BIGINT)/1000)), event_type
),

user_engagement_summary AS (
  SELECT 
    device_id,
    first_activity_date,
    last_activity_date,
    COUNT(DISTINCT activity_date) as total_active_days,
    DATE_DIFF('day', first_activity_date, last_activity_date) + 1 as days_since_first_use,
    DATE_DIFF('day', last_activity_date, CURRENT_DATE) as days_since_last_activity,
    SUM(daily_events) as total_events,
    SUM(daily_anxiety_sessions) as total_anxiety_sessions,
    
    -- Calculate activity streaks and gaps
    COUNT(DISTINCT activity_date) * 100.0 / (DATE_DIFF('day', first_activity_date, last_activity_date) + 1) as activity_consistency_percentage,
    
    -- User lifecycle stage
    CASE 
      WHEN DATE_DIFF('day', first_activity_date, CURRENT_DATE) <= 7 THEN 'New User (0-7 days)'
      WHEN DATE_DIFF('day', first_activity_date, CURRENT_DATE) <= 30 THEN 'Establishing User (8-30 days)'
      WHEN DATE_DIFF('day', first_activity_date, CURRENT_DATE) <= 90 THEN 'Regular User (31-90 days)'
      ELSE 'Long-term User (90+ days)'
    END as user_lifecycle_stage
    
  FROM user_activity_timeline
  GROUP BY device_id, first_activity_date, last_activity_date
),

churn_risk_assessment AS (
  SELECT 
    device_id,
    user_lifecycle_stage,
    first_activity_date,
    last_activity_date,
    total_active_days,
    days_since_first_use,
    days_since_last_activity,
    total_events,
    total_anxiety_sessions,
    activity_consistency_percentage,
    
    -- Engagement level
    CASE 
      WHEN total_anxiety_sessions >= 10 AND total_active_days >= 7 THEN 'Highly Engaged'
      WHEN total_anxiety_sessions >= 5 AND total_active_days >= 3 THEN 'Moderately Engaged'
      WHEN total_anxiety_sessions >= 1 THEN 'Lightly Engaged'
      ELSE 'Minimal Engagement'
    END as engagement_level,
    
    -- Churn risk scoring
    CASE 
      WHEN days_since_last_activity >= 14 THEN 'High Risk'
      WHEN days_since_last_activity >= 7 THEN 'Medium Risk'
      WHEN days_since_last_activity >= 3 THEN 'Low Risk'
      ELSE 'Active'
    END as churn_risk_level,
    
    -- Retention score (0-100)
    GREATEST(0, 100 - 
      (days_since_last_activity * 5) - 
      (CASE WHEN activity_consistency_percentage < 20 THEN 20 ELSE 0 END) -
      (CASE WHEN total_anxiety_sessions = 0 THEN 30 ELSE 0 END)
    ) as retention_score
    
  FROM user_engagement_summary
),

cohort_analysis AS (
  SELECT 
    DATE_FORMAT(first_activity_date, '%Y-%m') as cohort_month,
    user_lifecycle_stage,
    engagement_level,
    churn_risk_level,
    
    COUNT(*) as user_count,
    
    AVG(days_since_first_use) as avg_days_since_first_use,
    AVG(days_since_last_activity) as avg_days_since_last_activity,
    AVG(total_active_days) as avg_active_days,
    AVG(total_anxiety_sessions) as avg_anxiety_sessions,
    AVG(activity_consistency_percentage) as avg_consistency_percentage,
    AVG(retention_score) as avg_retention_score,
    
    -- Retention rates
    COUNT(CASE WHEN days_since_last_activity <= 7 THEN 1 END) * 100.0 / COUNT(*) as seven_day_retention_rate,
    COUNT(CASE WHEN days_since_last_activity <= 14 THEN 1 END) * 100.0 / COUNT(*) as fourteen_day_retention_rate,
    COUNT(CASE WHEN days_since_last_activity <= 30 THEN 1 END) * 100.0 / COUNT(*) as thirty_day_retention_rate,
    
    -- Churn indicators
    COUNT(CASE WHEN churn_risk_level = 'High Risk' THEN 1 END) as high_churn_risk_users,
    COUNT(CASE WHEN engagement_level = 'Minimal Engagement' THEN 1 END) as minimal_engagement_users
    
  FROM churn_risk_assessment
  GROUP BY 
    DATE_FORMAT(first_activity_date, '%Y-%m'),
    user_lifecycle_stage,
    engagement_level, 
    churn_risk_level
)

SELECT 
  cohort_month,
  user_lifecycle_stage,
  engagement_level,
  churn_risk_level,
  user_count,
  ROUND(user_count * 100.0 / SUM(user_count) OVER (PARTITION BY cohort_month), 2) as percentage_of_cohort,
  
  ROUND(avg_days_since_first_use, 1) as avg_days_since_first_use,
  ROUND(avg_days_since_last_activity, 1) as avg_days_since_last_activity,
  ROUND(avg_active_days, 1) as avg_active_days,
  ROUND(avg_anxiety_sessions, 1) as avg_anxiety_sessions,
  ROUND(avg_consistency_percentage, 1) as avg_consistency_percentage,
  ROUND(avg_retention_score, 1) as avg_retention_score,
  
  ROUND(seven_day_retention_rate, 2) as seven_day_retention_rate,
  ROUND(fourteen_day_retention_rate, 2) as fourteen_day_retention_rate,
  ROUND(thirty_day_retention_rate, 2) as thirty_day_retention_rate,
  
  high_churn_risk_users,
  minimal_engagement_users,
  
  -- Actionable insights
  CASE 
    WHEN churn_risk_level = 'High Risk' AND engagement_level != 'Minimal Engagement' 
    THEN 'Re-engagement Campaign'
    WHEN engagement_level = 'Minimal Engagement' AND user_lifecycle_stage = 'New User (0-7 days)' 
    THEN 'Onboarding Optimization'
    WHEN thirty_day_retention_rate < 50 
    THEN 'Retention Strategy Needed'
    ELSE 'Monitor'
  END as recommended_action

FROM cohort_analysis
WHERE user_count >= 3
ORDER BY 
  cohort_month DESC,
  CASE user_lifecycle_stage
    WHEN 'New User (0-7 days)' THEN 1
    WHEN 'Establishing User (8-30 days)' THEN 2
    WHEN 'Regular User (31-90 days)' THEN 3
    ELSE 4
  END,
  CASE churn_risk_level
    WHEN 'High Risk' THEN 1
    WHEN 'Medium Risk' THEN 2
    WHEN 'Low Risk' THEN 3
    ELSE 4
  END
-- User Journey Funnel Analysis
-- Tracks user progression from app install through first anxiety session completion
-- Shows conversion rates at each stage of the user onboarding process

WITH user_stages AS (
  SELECT 
    device_id,
    MIN(CASE WHEN event_type = 'app_install' THEN event_timestamp END) as install_time,
    MIN(CASE WHEN event_type = 'new_anxiety_created' THEN event_timestamp END) as first_anxiety_time,
    MIN(CASE WHEN event_type = 'anxiety_session_completed' THEN event_timestamp END) as first_completion_time
  FROM mht_api_production_data_analytics.mht_api_production_flattened_analytics_correct
  WHERE DATE(from_unixtime(CAST(event_timestamp AS BIGINT)/1000)) >= CURRENT_DATE - INTERVAL '30' DAY
  GROUP BY device_id
),

funnel_metrics AS (
  SELECT
    COUNT(DISTINCT device_id) as total_installs,
    COUNT(DISTINCT CASE WHEN install_time IS NOT NULL THEN device_id END) as users_installed,
    COUNT(DISTINCT CASE WHEN first_anxiety_time IS NOT NULL THEN device_id END) as users_created_anxiety,
    COUNT(DISTINCT CASE WHEN first_completion_time IS NOT NULL THEN device_id END) as users_completed_session,
    
    -- Time to conversion metrics
    AVG(CASE WHEN first_anxiety_time IS NOT NULL AND install_time IS NOT NULL 
        THEN (CAST(first_anxiety_time AS BIGINT) - CAST(install_time AS BIGINT))/1000/60 END) as avg_minutes_to_first_anxiety,
    AVG(CASE WHEN first_completion_time IS NOT NULL AND first_anxiety_time IS NOT NULL 
        THEN (CAST(first_completion_time AS BIGINT) - CAST(first_anxiety_time AS BIGINT))/1000/60 END) as avg_minutes_to_completion
  FROM user_stages
)

SELECT
  'App Install' as stage,
  users_installed as users,
  users_installed as previous_stage_users,
  100.0 as conversion_rate,
  NULL as avg_time_to_next_stage_minutes
FROM funnel_metrics

UNION ALL

SELECT
  'First Anxiety Created' as stage,
  users_created_anxiety as users,
  users_installed as previous_stage_users,
  ROUND(users_created_anxiety * 100.0 / users_installed, 2) as conversion_rate,
  ROUND(avg_minutes_to_first_anxiety, 1) as avg_time_to_next_stage_minutes
FROM funnel_metrics

UNION ALL

SELECT
  'First Session Completed' as stage,
  users_completed_session as users,
  users_created_anxiety as previous_stage_users,
  ROUND(users_completed_session * 100.0 / users_created_anxiety, 2) as conversion_rate,
  ROUND(avg_minutes_to_completion, 1) as avg_time_to_next_stage_minutes
FROM funnel_metrics

ORDER BY 
  CASE 
    WHEN stage = 'App Install' THEN 1
    WHEN stage = 'First Anxiety Created' THEN 2
    WHEN stage = 'First Session Completed' THEN 3
  END;
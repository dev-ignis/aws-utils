-- User Journey Funnel Analysis
-- Tracks user progression from app install through first anxiety session completion
-- Shows conversion rates at each stage of the user onboarding process

WITH user_stages AS (
  SELECT 
    device_id,
    MAX(CASE WHEN event_type = 'app_install' THEN 1 ELSE 0 END) as has_install,
    MAX(CASE WHEN event_type = 'new_anxiety_created' THEN 1 ELSE 0 END) as has_anxiety,
    MAX(CASE WHEN event_type = 'anxiety_session_completed' THEN 1 ELSE 0 END) as has_completion
  FROM mht_api_production_data_analytics.mht_api_production_flattened_analytics_correct
  WHERE year = CAST(YEAR(CURRENT_DATE) AS VARCHAR) AND month = CAST(MONTH(CURRENT_DATE) AS VARCHAR)
  GROUP BY device_id
)

SELECT
  'App Install' as stage,
  SUM(has_install) as users,
  SUM(has_install) as previous_stage_users,
  100.0 as conversion_rate
FROM user_stages

UNION ALL

SELECT
  'First Anxiety Created' as stage,
  SUM(has_anxiety) as users,
  SUM(has_install) as previous_stage_users,
  ROUND(SUM(has_anxiety) * 100.0 / NULLIF(SUM(has_install), 0), 2) as conversion_rate
FROM user_stages

UNION ALL

SELECT
  'First Session Completed' as stage,
  SUM(has_completion) as users,
  SUM(has_anxiety) as previous_stage_users,
  ROUND(SUM(has_completion) * 100.0 / NULLIF(SUM(has_anxiety), 0), 2) as conversion_rate
FROM user_stages

ORDER BY 
  CASE 
    WHEN stage = 'App Install' THEN 1
    WHEN stage = 'First Anxiety Created' THEN 2
    WHEN stage = 'First Session Completed' THEN 3
  END;
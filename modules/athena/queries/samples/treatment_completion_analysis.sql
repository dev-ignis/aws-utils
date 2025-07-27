-- Treatment Completion Rate Analysis (3 B's Framework)
-- Tracks completion rates for Be Cool, Believe, and Behave treatment steps
-- Shows user progression through the complete anxiety management workflow

WITH treatment_sessions AS (
  SELECT 
    session_id,
    device_id,
    MAX(CASE WHEN event_type = 'be_cool_step_completed' THEN 1 ELSE 0 END) as be_cool_completed,
    MAX(CASE WHEN event_type = 'believe_step_completed' THEN 1 ELSE 0 END) as believe_completed,
    MAX(CASE WHEN event_type = 'behave_step_completed' THEN 1 ELSE 0 END) as behave_completed,
    MAX(CASE WHEN event_type = 'anxiety_session_completed' THEN 1 ELSE 0 END) as session_completed
  FROM mht_api_production_data_analytics.mht_api_production_flattened_analytics_correct
  WHERE year = CAST(YEAR(CURRENT_DATE) AS VARCHAR) AND month = CAST(MONTH(CURRENT_DATE) AS VARCHAR)
    AND event_type IN ('be_cool_step_completed', 'believe_step_completed', 'behave_step_completed', 'anxiety_session_completed')
  GROUP BY session_id, device_id
),

completion_metrics AS (
  SELECT
    COUNT(DISTINCT session_id) as total_sessions,
    COUNT(DISTINCT device_id) as total_users,
    
    -- Individual step completion rates
    SUM(be_cool_completed) as be_cool_completions,
    SUM(believe_completed) as believe_completions,
    SUM(behave_completed) as behave_completions,
    SUM(session_completed) as full_session_completions,
    
    -- Multi-step completion patterns
    SUM(CASE WHEN be_cool_completed = 1 AND believe_completed = 1 THEN 1 ELSE 0 END) as be_cool_and_believe,
    SUM(CASE WHEN be_cool_completed = 1 AND believe_completed = 1 AND behave_completed = 1 THEN 1 ELSE 0 END) as all_three_steps
  FROM treatment_sessions
)

SELECT 
  'Treatment Step Analysis' as metric_type,
  total_sessions,
  total_users,
  
  -- Completion rates
  ROUND(be_cool_completions * 100.0 / total_sessions, 2) as be_cool_completion_rate_percent,
  ROUND(believe_completions * 100.0 / total_sessions, 2) as believe_completion_rate_percent,
  ROUND(behave_completions * 100.0 / total_sessions, 2) as behave_completion_rate_percent,
  ROUND(full_session_completions * 100.0 / total_sessions, 2) as full_session_completion_rate_percent,
  
  -- Multi-step completion rates
  ROUND(be_cool_and_believe * 100.0 / total_sessions, 2) as first_two_steps_completion_rate_percent,
  ROUND(all_three_steps * 100.0 / total_sessions, 2) as all_three_steps_completion_rate_percent
FROM completion_metrics;
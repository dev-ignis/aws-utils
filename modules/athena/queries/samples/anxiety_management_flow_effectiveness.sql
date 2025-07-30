-- Anxiety Management Flow Effectiveness Analysis
-- Tracks the complete anxiety management workflow from focus selection through response selection
-- Measures effectiveness based on user choices and completion patterns

WITH anxiety_flow_sessions AS (
  SELECT 
    session_id,
    device_id,
    
    -- Focus selection steps
    MAX(CASE WHEN event_type = 'new_focus_selected' THEN 1 ELSE 0 END) as selected_new_focus,
    MAX(CASE WHEN event_type = 'specific_focus_selected' THEN 1 ELSE 0 END) as selected_specific_focus,
    
    -- Assessment steps
    MAX(CASE WHEN event_type = 'danger_level_selected' THEN 1 ELSE 0 END) as selected_danger_level,
    MAX(CASE WHEN event_type = 'probability_level_selected' THEN 1 ELSE 0 END) as selected_probability_level,
    
    -- Response and completion
    MAX(CASE WHEN event_type = 'response_selected' THEN 1 ELSE 0 END) as selected_response,
    MAX(CASE WHEN event_type = 'anxiety_session_completed' THEN 1 ELSE 0 END) as completed_session,
    
    -- Extract specific values for analysis
    MAX(CASE WHEN event_type = 'response_selected' THEN response END) as final_response,
    MAX(CASE WHEN event_type = 'danger_level_selected' THEN danger_level END) as danger_assessment,
    MAX(CASE WHEN event_type = 'probability_level_selected' THEN probability_level END) as probability_assessment,
    
    -- Remove timing analysis due to timestamp parsing issues
    
  FROM mht_api_production_data_analytics.mht_api_production_flattened_analytics_correct
  WHERE year = CAST(YEAR(CURRENT_DATE) AS VARCHAR) AND month = CAST(MONTH(CURRENT_DATE) AS VARCHAR)
    AND event_type IN (
      'new_focus_selected', 'specific_focus_selected', 
      'danger_level_selected', 'probability_level_selected',
      'response_selected', 'anxiety_session_completed'
    )
  GROUP BY session_id, device_id
),

flow_effectiveness AS (
  SELECT
    COUNT(DISTINCT session_id) as total_anxiety_sessions,
    COUNT(DISTINCT device_id) as total_users,
    
    -- Step completion rates
    SUM(selected_new_focus + selected_specific_focus) as focus_selections,
    SUM(selected_danger_level) as danger_assessments,
    SUM(selected_probability_level) as probability_assessments,
    SUM(selected_response) as response_selections,
    SUM(completed_session) as completed_sessions,
    
    -- Complete flow completion rate
    SUM(CASE WHEN selected_danger_level = 1 AND selected_probability_level = 1 
             AND selected_response = 1 AND completed_session = 1 THEN 1 ELSE 0 END) as complete_flow_sessions,
    
    -- Response effectiveness analysis
    SUM(CASE WHEN final_response = 'Reduce' THEN 1 ELSE 0 END) as reduce_responses,
    SUM(CASE WHEN final_response = 'Maintain' THEN 1 ELSE 0 END) as maintain_responses,
    SUM(CASE WHEN final_response = 'Increase' THEN 1 ELSE 0 END) as increase_responses,
    
    -- Assessment patterns
    SUM(CASE WHEN danger_assessment IN ('High', 'Very High') THEN 1 ELSE 0 END) as high_danger_assessments,
    SUM(CASE WHEN probability_assessment IN ('High', 'Very High') THEN 1 ELSE 0 END) as high_probability_assessments
  FROM anxiety_flow_sessions
),

response_effectiveness_by_assessment AS (
  SELECT
    danger_assessment,
    probability_assessment,
    final_response,
    COUNT(*) as response_count,
    COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY danger_assessment, probability_assessment) as response_percentage
  FROM anxiety_flow_sessions
  WHERE danger_assessment IS NOT NULL 
    AND probability_assessment IS NOT NULL 
    AND final_response IS NOT NULL
  GROUP BY danger_assessment, probability_assessment, final_response
)

-- Main effectiveness metrics
SELECT 
  'Anxiety Flow Effectiveness' as metric_type,
  total_anxiety_sessions,
  total_users,
  ROUND(focus_selections * 100.0 / total_anxiety_sessions, 2) as focus_selection_rate_percent,
  ROUND(danger_assessments * 100.0 / total_anxiety_sessions, 2) as danger_assessment_rate_percent,
  ROUND(probability_assessments * 100.0 / total_anxiety_sessions, 2) as probability_assessment_rate_percent,
  ROUND(response_selections * 100.0 / total_anxiety_sessions, 2) as response_selection_rate_percent,
  ROUND(completed_sessions * 100.0 / total_anxiety_sessions, 2) as session_completion_rate_percent,
  ROUND(complete_flow_sessions * 100.0 / total_anxiety_sessions, 2) as complete_flow_rate_percent,
  ROUND(reduce_responses * 100.0 / response_selections, 2) as reduce_response_rate_percent,
  ROUND(high_danger_assessments * 100.0 / danger_assessments, 2) as high_danger_rate_percent,
  ROUND(high_probability_assessments * 100.0 / probability_assessments, 2) as high_probability_rate_percent
FROM flow_effectiveness

UNION ALL

-- Response patterns by assessment levels
SELECT 
  'Response Pattern: ' || danger_assessment || ' danger, ' || probability_assessment || ' prob → ' || final_response as metric_type,
  response_count as total_anxiety_sessions,
  NULL as total_users,
  ROUND(response_percentage, 1) as focus_selection_rate_percent,
  NULL as danger_assessment_rate_percent,
  NULL as probability_assessment_rate_percent,
  NULL as response_selection_rate_percent,
  NULL as session_completion_rate_percent,
  NULL as complete_flow_rate_percent,
  NULL as reduce_response_rate_percent,
  NULL as high_danger_rate_percent,
  NULL as high_probability_rate_percent
FROM response_effectiveness_by_assessment
WHERE response_count >= 5  -- Only show patterns with meaningful sample size
ORDER BY metric_type;
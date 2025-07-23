WITH user_response_tracking AS (
  SELECT 
    device_id,
    response,
    CAST(danger_level AS DOUBLE) as danger_level,
    CAST(probability_level AS DOUBLE) as probability_level,
    focus,
    specific_focus,
    event_timestamp,
    ROW_NUMBER() OVER (PARTITION BY device_id ORDER BY event_timestamp) as session_order
  FROM mht_api_production_data_analytics.mht_api_production_flattened_analytics_correct
  WHERE event_type = 'anxiety_session_completed'
    AND response IS NOT NULL
    AND danger_level IS NOT NULL
    AND probability_level IS NOT NULL
    AND year = CAST(YEAR(CURRENT_DATE) AS VARCHAR)
    AND month = CAST(MONTH(CURRENT_DATE) AS VARCHAR)
),

response_outcomes AS (
  SELECT 
    curr.device_id,
    curr.response,
    curr.danger_level as current_danger,
    curr.probability_level as current_probability,
    curr.focus,
    
    next_session.danger_level as next_danger,
    next_session.probability_level as next_probability,
    
    (next_session.danger_level - curr.danger_level) as danger_change,
    (next_session.probability_level - curr.probability_level) as probability_change,
    
    CASE 
      WHEN next_session.danger_level < curr.danger_level THEN 'Improved'
      WHEN next_session.danger_level = curr.danger_level THEN 'Stable'
      ELSE 'Worsened'
    END as danger_outcome,
    
    CASE 
      WHEN next_session.probability_level < curr.probability_level THEN 'Improved'
      WHEN next_session.probability_level = curr.probability_level THEN 'Stable'
      ELSE 'Worsened'
    END as probability_outcome
    
  FROM user_response_tracking curr
  LEFT JOIN user_response_tracking next_session 
    ON curr.device_id = next_session.device_id 
    AND next_session.session_order = curr.session_order + 1
  WHERE next_session.device_id IS NOT NULL
)

SELECT 
  response,
  focus,
  
  COUNT(DISTINCT session_id) as unique_sessions_with_response,
  COUNT(DISTINCT device_id) as unique_users,
  COUNT(*) as total_response_events,
  
  ROUND(AVG(current_danger), 2) as avg_initial_danger_level,
  ROUND(AVG(next_danger), 2) as avg_subsequent_danger_level,
  ROUND(AVG(danger_change), 2) as avg_danger_change,
  
  ROUND(AVG(current_probability), 2) as avg_initial_probability_level,
  ROUND(AVG(next_probability), 2) as avg_subsequent_probability_level,
  ROUND(AVG(probability_change), 2) as avg_probability_change,
  
  COUNT(CASE WHEN danger_outcome = 'Improved' THEN 1 END) as danger_improved_count,
  COUNT(CASE WHEN danger_outcome = 'Stable' THEN 1 END) as danger_stable_count,
  COUNT(CASE WHEN danger_outcome = 'Worsened' THEN 1 END) as danger_worsened_count,
  
  ROUND(COUNT(CASE WHEN danger_outcome = 'Improved' THEN 1 END) * 100.0 / COUNT(*), 2) as danger_improvement_rate,
  ROUND(COUNT(CASE WHEN probability_outcome = 'Improved' THEN 1 END) * 100.0 / COUNT(*), 2) as probability_improvement_rate,
  
  CASE 
    WHEN AVG(danger_change) < -0.5 THEN 'Highly Effective'
    WHEN AVG(danger_change) < 0 THEN 'Effective'
    WHEN AVG(danger_change) = 0 THEN 'Neutral'
    ELSE 'Concerning'
  END as response_effectiveness_rating

FROM response_outcomes
GROUP BY response, focus
HAVING COUNT(*) >= 5
ORDER BY avg_danger_change ASC, danger_improvement_rate DESC
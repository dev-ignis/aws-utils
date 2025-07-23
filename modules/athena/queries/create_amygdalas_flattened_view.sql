-- Create Flattened View for Amygdalas Analytics Data
-- This view unnests the batch/events structure for easier querying

CREATE OR REPLACE VIEW `${database_name}`.`${view_name}` AS
SELECT 
  -- Batch level metadata
  batch_id,
  batch_timestamp,
  batch_metadata.user_id,
  batch_metadata.device_id,
  batch_metadata.session_id,
  batch_metadata.app_version,
  batch_metadata.os_version,
  batch_metadata.device_model,
  batch_metadata.platform,
  batch_metadata.timezone,
  batch_metadata.network_type,
  
  -- Individual event data (unnested)
  event.event_id,
  event.timestamp as event_timestamp,
  event.event_type,
  event.event_name,
  event.screen_name,
  event.action,
  event.category,
  event.label,
  event.value,
  event.duration,
  
  -- Focus session specific fields
  event.focus_session.session_type,
  event.focus_session.duration_seconds as focus_duration,
  event.focus_session.completion_rate,
  event.focus_session.technique_used,
  event.focus_session.difficulty_level,
  event.focus_session.mood_before,
  event.focus_session.mood_after,
  event.focus_session.interruptions,
  
  -- Breathing exercise fields
  event.breathing_exercise.exercise_type,
  event.breathing_exercise.breaths_per_minute,
  event.breathing_exercise.total_breaths,
  event.breathing_exercise.session_duration as breathing_duration,
  event.breathing_exercise.pattern_type,
  event.breathing_exercise.guide_used,
  event.breathing_exercise.completion_status,
  
  -- Danger/probability assessment
  event.danger_probability.danger_level,
  event.danger_probability.probability_level,
  event.danger_probability.context as danger_context,
  event.danger_probability.user_confidence,
  event.danger_probability.technique_applied,
  event.danger_probability.outcome_rating,
  
  -- User interaction data
  event.user_interaction.interaction_type,
  event.user_interaction.element_id,
  event.user_interaction.position.x as click_x,
  event.user_interaction.position.y as click_y,
  event.user_interaction.gesture,
  event.user_interaction.response_time_ms,
  
  -- Partition fields for performance
  year,
  month,
  day,
  hour
  
FROM `${database_name}`.`${table_name}`
CROSS JOIN UNNEST(events) AS t(event)
WHERE year >= '2025' -- Only current year data for performance
-- Create User Behavior Table for Amygdalas Mental Health Analytics
-- Focus on user engagement patterns, session effectiveness, and wellness outcomes

CREATE EXTERNAL TABLE IF NOT EXISTS ${database_name}.${table_name} (
  `behavior_id` string,
  `user_id` string,
  `session_id` string,
  `device_id` string,
  `timestamp` bigint,
  `behavior_type` string,
  `screen_name` string,
  `action` string,
  -- Mental health specific behavior tracking
  `wellness_metrics` struct<
    session_completion_rate: double,
    total_focus_time_minutes: double,
    breathing_sessions_completed: bigint,
    mood_improvement_score: double,
    stress_reduction_rating: double,
    technique_effectiveness: string,
    weekly_consistency_score: double,
    goal_achievement_rate: double
  >,
  `engagement_patterns` struct<
    daily_active_minutes: double,
    preferred_session_times: array<string>,
    favorite_techniques: array<string>,
    difficulty_progression: string,
    feature_usage_frequency: map<string, bigint>,
    retention_indicators: struct<
      days_since_first_use: bigint,
      consecutive_active_days: bigint,
      last_session_quality: string
    >
  >,
  `user_preferences` struct<
    preferred_session_duration: double,
    notification_settings: map<string, boolean>,
    accessibility_options: array<string>,
    privacy_settings: map<string, string>,
    theme_preferences: string
  >,
  `device_context` struct<
    app_version: string,
    os_name: string,
    os_version: string,
    device_model: string,
    network_type: string,
    battery_level: double,
    available_storage_gb: double,
    memory_usage_mb: double
  >
)
PARTITIONED BY (
  `year` string,
  `month` string,
  `day` string,
  `hour` string
)
STORED AS INPUTFORMAT 'org.apache.hadoop.mapred.TextInputFormat'
OUTPUTFORMAT 'org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat'
SERDE 'org.apache.hive.hcatalog.data.JsonSerDe'
LOCATION '${s3_location}'
TBLPROPERTIES (
  'projection.enabled' = 'true',
  'projection.year.type' = 'integer',
  'projection.year.range' = '2025,2030',
  'projection.year.interval' = '1',
  'projection.month.type' = 'integer',
  'projection.month.range' = '01,12',
  'projection.month.interval' = '1',
  'projection.month.digits' = '2',
  'projection.day.type' = 'integer',
  'projection.day.range' = '01,31',
  'projection.day.interval' = '1',
  'projection.day.digits' = '2',
  'projection.hour.type' = 'integer',
  'projection.hour.range' = '00,23',
  'projection.hour.interval' = '1',
  'projection.hour.digits' = '2',
  'storage.location.template' = '${s3_location}year=$${year}/month=$${month}/day=$${day}/hour=$${hour}/',
  'classification' = 'json',
  'compressionType' = 'gzip',
  'typeOfData' = 'file'
);
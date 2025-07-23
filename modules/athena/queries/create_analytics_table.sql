CREATE EXTERNAL TABLE ${database_name}.${table_name} (
  batch_id string,
  batch_timestamp bigint,
  batch_metadata struct<
    user_id: string,
    device_id: string,
    session_id: string,
    app_version: string,
    os_version: string,
    device_model: string,
    platform: string,
    timezone: string,
    network_type: string
  >,
  events array<struct<
    event_id: string,
    timestamp: bigint,
    event_type: string,
    event_name: string,
    screen_name: string,
    action: string,
    category: string,
    label: string,
    value: double,
    duration: double,
    focus_session: struct<
      session_type: string,
      duration_seconds: double,
      completion_rate: double,
      technique_used: string,
      difficulty_level: string,
      mood_before: string,
      mood_after: string,
      interruptions: bigint
    >,
    breathing_exercise: struct<
      exercise_type: string,
      breaths_per_minute: double,
      total_breaths: bigint,
      session_duration: double,
      pattern_type: string,
      guide_used: boolean,
      completion_status: string
    >,
    danger_probability: struct<
      danger_level: string,
      probability_level: string,
      context: string,
      user_confidence: double,
      technique_applied: string,
      outcome_rating: string
    >,
    user_interaction: struct<
      interaction_type: string,
      element_id: string,
      position: struct<x: double, y: double>,
      gesture: string,
      response_time_ms: bigint
    >
  >>
)
PARTITIONED BY (
  year string,
  month string,
  day string,
  hour string
)
ROW FORMAT SERDE 'org.apache.hive.hcatalog.data.JsonSerDe'
STORED AS INPUTFORMAT 'org.apache.hadoop.mapred.TextInputFormat'
OUTPUTFORMAT 'org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat'
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
  'storage.location.template' = '${s3_location}year=$${year}/month=$${month}/day=$${day}/hour=$${hour}/'
)
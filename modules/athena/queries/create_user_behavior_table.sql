-- Create User Behavior Table with Partition Projection
-- This table stores detailed user behavior and interaction patterns

CREATE EXTERNAL TABLE IF NOT EXISTS `${database_name}`.`${table_name}` (
  `behavior_id` string,
  `user_id` string,
  `session_id` string,
  `device_id` string,
  `timestamp` bigint,
  `behavior_type` string,
  `screen_name` string,
  `action` string,
  `target_element` string,
  `interaction_data` struct<
    scroll_depth: double,
    time_on_screen: double,
    click_position: struct<x: double, y: double>,
    gesture_type: string,
    input_method: string,
    form_completion_time: double,
    error_occurred: boolean,
    error_message: string
  >,
  `user_state` struct<
    mood_before: string,
    mood_after: string,
    energy_level: string,
    stress_level: string,
    engagement_score: double,
    satisfaction_rating: double
  >,
  `context` struct<
    app_version: string,
    os_name: string,
    os_version: string,
    device_model: string,
    network_type: string,
    battery_level: double,
    memory_usage: double,
    storage_available: double
  >,
  `metadata` struct<
    processing_time: double,
    data_quality_score: double,
    privacy_level: string,
    consent_status: string
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
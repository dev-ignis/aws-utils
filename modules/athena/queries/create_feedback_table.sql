CREATE EXTERNAL TABLE ${database_name}.${table_name} (
  feedback_id string,
  user_id string,
  device_id string,
  session_id string,
  timestamp bigint,
  feedback_type string,
  category string,
  severity string,
  priority string,
  title string,
  description string,
  steps_to_reproduce string,
  expected_behavior string,
  actual_behavior string,
  user_rating double,
  tags array<string>,
  attachments array<struct<
    type: string,
    filename: string,
    size: bigint,
    s3_key: string,
    url: string
  >>,
  device_info struct<
    device_model: string,
    os_name: string,
    os_version: string,
    app_version: string,
    screen_resolution: string,
    available_memory: bigint,
    available_storage: bigint,
    battery_level: double,
    network_type: string
  >,
  app_state struct<
    current_screen: string,
    previous_screen: string,
    user_actions: array<string>,
    error_logs: array<string>,
    performance_metrics: struct<
      cpu_usage: double,
      memory_usage: double,
      load_time: double,
      crash_occurred: boolean
    >
  >,
  processing_status struct<
    status: string,
    assigned_to: string,
    processed_at: bigint,
    resolved_at: bigint,
    resolution_notes: string,
    internal_tags: array<string>
  >
)
PARTITIONED BY (
  year string,
  month string,
  day string
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
  'storage.location.template' = '${s3_location}year=$${year}/month=$${month}/day=$${day}/'
)
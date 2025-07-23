-- Create Analytics Events Table with Partition Projection
-- This table stores user analytics events with automatic partitioning by date and hour

CREATE EXTERNAL TABLE IF NOT EXISTS `${database_name}`.`${table_name}` (
  `event_id` string,
  `user_id` string,
  `device_id` string,
  `session_id` string,
  `event_type` string,
  `event_name` string,
  `timestamp` bigint,
  `properties` struct<
    screen_name: string,
    action: string,
    category: string,
    label: string,
    value: double,
    duration: double,
    custom_properties: map<string, string>
  >,
  `user_properties` struct<
    user_type: string,
    subscription_status: string,
    app_version: string,
    os_version: string,
    device_type: string,
    country: string,
    language: string
  >,
  `context` struct<
    app_version: string,
    os_name: string,
    os_version: string,
    device_model: string,
    network_type: string,
    ip_address: string,
    user_agent: string
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
CREATE EXTERNAL TABLE ${database_name}.${table_name} (
  transaction_id string,
  user_id string,
  device_id string,
  session_id string,
  timestamp bigint,
  transaction_type string,
  product_id string,
  product_name string,
  product_category string,
  amount double,
  currency string,
  payment_method string,
  subscription_info struct<
    subscription_id: string,
    plan_type: string,
    billing_period: string,
    trial_period: boolean,
    renewal_date: bigint,
    cancellation_date: bigint,
    upgrade_from: string,
    downgrade_to: string
  >,
  transaction_status string,
  payment_processor string,
  payment_processor_transaction_id string,
  refund_info struct<
    refund_id: string,
    refund_amount: double,
    refund_reason: string,
    refund_date: bigint,
    refund_status: string
  >,
  promo_code struct<
    code: string,
    discount_type: string,
    discount_amount: double,
    campaign_id: string
  >,
  tax_info struct<
    tax_amount: double,
    tax_rate: double,
    tax_jurisdiction: string,
    tax_exempt: boolean
  >,
  receipt_info struct<
    receipt_id: string,
    receipt_url: string,
    receipt_email: string,
    receipt_sent: boolean
  >,
  risk_assessment struct<
    risk_score: double,
    fraud_indicators: array<string>,
    verification_status: string,
    chargeback_risk: double
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
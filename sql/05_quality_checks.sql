-- 05_quality_checks.sql  Data-quality evidence (Spark SQL dialect): before/after counts, null rates, issues, assertions

CREATE OR REPLACE TABLE dq_row_counts AS
SELECT 'orders' AS entity, (SELECT COUNT(*) FROM stg_orders) AS raw_rows,
       (SELECT COUNT(DISTINCT row_id) FROM stg_orders) AS distinct_keys,
       (SELECT COUNT(*) FROM cln_orders) AS clean_rows, 'order line (row_id)' AS grain
UNION ALL SELECT 'returns', (SELECT COUNT(*) FROM stg_returns), (SELECT COUNT(DISTINCT order_id) FROM stg_returns),
       (SELECT COUNT(*) FROM cln_returns), 'returned order'
UNION ALL SELECT 'people', (SELECT COUNT(*) FROM stg_people), (SELECT COUNT(DISTINCT region) FROM stg_people),
       (SELECT COUNT(*) FROM cln_people), 'region'
UNION ALL SELECT 'fact_sales', NULL, NULL, (SELECT COUNT(*) FROM fact_sales), 'order line'
UNION ALL SELECT 'dim_date', NULL, NULL, (SELECT COUNT(*) FROM dim_date), 'order date'
UNION ALL SELECT 'dim_customer', NULL, NULL, (SELECT COUNT(*) FROM dim_customer), 'customer_id'
UNION ALL SELECT 'dim_product', NULL, NULL, (SELECT COUNT(*) FROM dim_product), 'product_id + product_name'
UNION ALL SELECT 'dim_geography', NULL, NULL, (SELECT COUNT(*) FROM dim_geography), 'region/state/city/postal'
UNION ALL SELECT 'dim_ship_mode', NULL, NULL, (SELECT COUNT(*) FROM dim_ship_mode), 'ship mode';

CREATE OR REPLACE TABLE dq_null_rates AS
SELECT 'orders' AS entity, 'postal_code' AS column_name,
  (SELECT ROUND(100.0 * SUM(CASE WHEN postal_code IS NULL OR trim(postal_code) = '' THEN 1 ELSE 0 END) / COUNT(*), 3) FROM stg_orders) AS raw_null_pct,
  (SELECT ROUND(100.0 * SUM(CASE WHEN postal_code IS NULL THEN 1 ELSE 0 END) / COUNT(*), 3) FROM cln_orders) AS clean_null_pct,
  'kept as NULL (Burlington, VT has no code in source); geography matched on NULL-safe key' AS treatment
UNION ALL SELECT 'orders', 'order_date',
  (SELECT ROUND(100.0 * SUM(CASE WHEN TRY_CAST(order_date AS DATE) IS NULL THEN 1 ELSE 0 END) / COUNT(*), 3) FROM stg_orders),
  (SELECT ROUND(100.0 * SUM(CASE WHEN order_date IS NULL THEN 1 ELSE 0 END) / COUNT(*), 3) FROM cln_orders),
  'required; unparseable dates dropped'
UNION ALL SELECT 'orders', 'sales',
  (SELECT ROUND(100.0 * SUM(CASE WHEN TRY_CAST(sales AS DOUBLE) IS NULL THEN 1 ELSE 0 END) / COUNT(*), 3) FROM stg_orders),
  (SELECT ROUND(100.0 * SUM(CASE WHEN sales IS NULL THEN 1 ELSE 0 END) / COUNT(*), 3) FROM cln_orders),
  'required; rounded to 2 dp (float artefacts like 731.9399999999999)'
UNION ALL SELECT 'orders', 'ship_mode',
  (SELECT ROUND(100.0 * SUM(CASE WHEN ship_mode IS NULL OR trim(ship_mode) = '' THEN 1 ELSE 0 END) / COUNT(*), 3) FROM stg_orders),
  (SELECT ROUND(100.0 * SUM(CASE WHEN ship_mode IS NULL THEN 1 ELSE 0 END) / COUNT(*), 3) FROM cln_orders),
  'standardised to 4 labels';

CREATE OR REPLACE TABLE dq_issues AS
SELECT 'orders: exact duplicate lines removed (same order/product/values, different row_id)' AS check_name,
       (SELECT COUNT(*) FROM stg_orders) - (SELECT COUNT(*) FROM cln_orders) AS affected_rows
UNION ALL SELECT 'orders: missing postal_code (kept)', (SELECT SUM(dq_missing_postal_code) FROM cln_orders)
UNION ALL SELECT 'orders: postal_code with lost leading zero (repaired)',
       (SELECT COUNT(*) FROM stg_orders WHERE length(trim(postal_code)) = 4)
UNION ALL SELECT 'orders: sales with float artefacts (>2 dp, rounded)',
       (SELECT COUNT(*) FROM stg_orders WHERE length(split_part(sales, '.', 2)) > 2)
UNION ALL SELECT 'orders: ship_date < order_date', (SELECT COUNT(*) FROM stg_orders WHERE TRY_CAST(ship_date AS DATE) < TRY_CAST(order_date AS DATE))
UNION ALL SELECT 'orders: loss-making lines (profit < 0)', (SELECT SUM(is_loss_line) FROM cln_orders)
UNION ALL SELECT 'orders: sales outlier (> Q3 + 3*IQR, kept)', (SELECT SUM(is_sales_outlier_iqr3) FROM cln_orders)
UNION ALL SELECT 'orders: profit outside p1-p99 (kept)', (SELECT SUM(is_profit_extreme_p1_p99) FROM cln_orders)
UNION ALL SELECT 'products: product_id mapped to >1 product_name',
       (SELECT COUNT(*) FROM (SELECT product_id FROM dim_product GROUP BY product_id HAVING COUNT(*) > 1) x)
UNION ALL SELECT 'customers: customer_id with >1 name or segment',
       (SELECT COUNT(*) FROM (SELECT customer_id FROM cln_orders GROUP BY customer_id
                              HAVING COUNT(DISTINCT customer_name) > 1 OR COUNT(DISTINCT segment) > 1) x)
UNION ALL SELECT 'returns: duplicate rows collapsed to order grain', (SELECT COUNT(*) FROM stg_returns) - (SELECT COUNT(*) FROM cln_returns)
UNION ALL SELECT 'returns: returned orders not found in orders', (SELECT COUNT(*) FROM cln_returns WHERE order_id NOT IN (SELECT order_id FROM cln_orders))
UNION ALL SELECT 'orders: lines on returned orders', (SELECT SUM(returned_flag) FROM cln_orders)
UNION ALL SELECT 'RI: fact without customer', (SELECT COUNT(*) FROM fact_sales WHERE customer_key IS NULL)
UNION ALL SELECT 'RI: fact without product', (SELECT COUNT(*) FROM fact_sales WHERE product_key IS NULL)
UNION ALL SELECT 'RI: fact without geography', (SELECT COUNT(*) FROM fact_sales WHERE geo_key IS NULL)
UNION ALL SELECT 'RI: fact without ship mode', (SELECT COUNT(*) FROM fact_sales WHERE ship_mode_key IS NULL);

CREATE OR REPLACE TABLE dq_assertions AS
WITH c AS (
  SELECT 'fact_sales.line_id unique' AS check_name, (SELECT COUNT(*) - COUNT(DISTINCT line_id) FROM fact_sales) AS failed_rows
  UNION ALL SELECT 'fact_sales.customer_key -> dim_customer', (SELECT COUNT(*) FROM fact_sales WHERE customer_key IS NULL OR customer_key NOT IN (SELECT customer_key FROM dim_customer))
  UNION ALL SELECT 'fact_sales.product_key -> dim_product', (SELECT COUNT(*) FROM fact_sales WHERE product_key IS NULL OR product_key NOT IN (SELECT product_key FROM dim_product))
  UNION ALL SELECT 'fact_sales.geo_key -> dim_geography', (SELECT COUNT(*) FROM fact_sales WHERE geo_key IS NULL OR geo_key NOT IN (SELECT geo_key FROM dim_geography))
  UNION ALL SELECT 'fact_sales.ship_mode_key -> dim_ship_mode', (SELECT COUNT(*) FROM fact_sales WHERE ship_mode_key IS NULL OR ship_mode_key NOT IN (SELECT ship_mode_key FROM dim_ship_mode))
  UNION ALL SELECT 'fact_sales.order_date_key -> dim_date', (SELECT COUNT(*) FROM fact_sales WHERE order_date_key NOT IN (SELECT date_key FROM dim_date))
  UNION ALL SELECT 'ship_date >= order_date', (SELECT COUNT(*) FROM fact_sales WHERE ship_date < order_date)
  UNION ALL SELECT 'discount between 0 and 0.8', (SELECT COUNT(*) FROM fact_sales WHERE discount < 0 OR discount > 0.8)
  UNION ALL SELECT 'sales > 0 and quantity > 0', (SELECT COUNT(*) FROM fact_sales WHERE sales <= 0 OR quantity <= 0)
  UNION ALL SELECT 'one manager per region', (SELECT COUNT(*) FROM (SELECT region FROM cln_people GROUP BY region HAVING COUNT(*) > 1) x)
  UNION ALL SELECT 'every region has a manager', (SELECT COUNT(*) FROM dim_geography WHERE regional_manager = 'Unassigned')
  UNION ALL SELECT 'fact sales reconcile to clean orders', (SELECT CASE WHEN ABS((SELECT SUM(sales) FROM fact_sales) - (SELECT SUM(sales) FROM cln_orders)) < 0.01 THEN 0 ELSE 1 END)
)
SELECT check_name, failed_rows, CASE WHEN failed_rows = 0 THEN 'PASS' ELSE 'FAIL' END AS status FROM c;

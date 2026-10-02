-- 03_model.sql  Star schema (Spark SQL dialect)
--   fact : fact_sales (grain: one order line)
--   dims : dim_date (order date), dim_customer, dim_product, dim_geography (+ regional manager), dim_ship_mode
-- Surrogate keys are dense INT ranks; date_key = yyyymmdd.

CREATE OR REPLACE TABLE dim_date AS
SELECT
  CAST(year(d) * 10000 + month(d) * 100 + day(d) AS INT) AS date_key,
  d AS full_date,
  year(d) AS year,
  quarter(d) AS quarter,
  month(d) AS month,
  concat(CAST(year(d) AS STRING), '-', lpad(CAST(month(d) AS STRING), 2, '0')) AS year_month,
  dayofweek(d) AS day_of_week,
  CASE WHEN dayofweek(d) IN (1, 7) THEN 1 ELSE 0 END AS is_weekend
FROM (SELECT DISTINCT order_date AS d FROM cln_orders) x;

CREATE OR REPLACE TABLE dim_customer AS
SELECT
  CAST(ROW_NUMBER() OVER (ORDER BY customer_id) AS INT) AS customer_key,
  customer_id, customer_name, segment
FROM (
  SELECT customer_id, MIN(customer_name) AS customer_name, MIN(segment) AS segment
  FROM cln_orders GROUP BY customer_id
) c;

-- Product ID is NOT unique in the source (some ids carry 2 names) -> natural key = (product_id, product_name)
CREATE OR REPLACE TABLE dim_product AS
SELECT
  CAST(ROW_NUMBER() OVER (ORDER BY product_id, product_name) AS INT) AS product_key,
  product_id, product_name, category, sub_category
FROM (
  SELECT product_id, product_name, MIN(category) AS category, MIN(sub_category) AS sub_category
  FROM cln_orders GROUP BY product_id, product_name
) p;

CREATE OR REPLACE TABLE dim_geography AS
SELECT
  CAST(ROW_NUMBER() OVER (ORDER BY g.region, g.state, g.city, g.postal_code) AS INT) AS geo_key,
  g.country, g.region, g.state, g.city, g.postal_code,
  COALESCE(p.manager_name, 'Unassigned') AS regional_manager
FROM (SELECT DISTINCT country, region, state, city, postal_code FROM cln_orders) g
LEFT JOIN cln_people p ON lower(g.region) = lower(p.region);

CREATE OR REPLACE TABLE dim_ship_mode AS
SELECT
  CAST(ROW_NUMBER() OVER (ORDER BY CASE ship_mode WHEN 'Same Day' THEN 1 WHEN 'First Class' THEN 2
                                   WHEN 'Second Class' THEN 3 WHEN 'Standard Class' THEN 4 ELSE 5 END) AS INT) AS ship_mode_key,
  ship_mode,
  CASE ship_mode WHEN 'Same Day' THEN 1 WHEN 'First Class' THEN 2
                 WHEN 'Second Class' THEN 3 WHEN 'Standard Class' THEN 4 ELSE 5 END AS service_level_rank
FROM (SELECT DISTINCT ship_mode FROM cln_orders WHERE ship_mode IS NOT NULL) s;

CREATE OR REPLACE TABLE fact_sales AS
SELECT
  o.row_id AS line_id,
  o.order_id,
  CAST(year(o.order_date) * 10000 + month(o.order_date) * 100 + day(o.order_date) AS INT) AS order_date_key,
  o.order_date,
  o.ship_date,
  c.customer_key,
  p.product_key,
  g.geo_key,
  s.ship_mode_key,
  o.ship_days,
  o.sales,
  o.list_sales,
  o.quantity,
  o.discount,
  o.discount_band,
  o.profit,
  o.profit_margin,
  o.is_loss_line,
  o.returned_flag,
  o.is_sales_outlier_iqr3,
  o.is_profit_extreme_p1_p99
FROM cln_orders o
LEFT JOIN dim_customer c ON o.customer_id = c.customer_id
LEFT JOIN dim_product p ON o.product_id = p.product_id AND o.product_name = p.product_name
LEFT JOIN dim_geography g ON o.region = g.region AND o.state = g.state AND o.city = g.city
     AND COALESCE(o.postal_code, '?') = COALESCE(g.postal_code, '?') AND o.country = g.country
LEFT JOIN dim_ship_mode s ON o.ship_mode = s.ship_mode;

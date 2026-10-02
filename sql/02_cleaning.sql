-- 02_cleaning.sql  (Spark SQL dialect; runs on DuckDB via 00_duckdb_compat.sql shims)
-- Steps: trim/standardise text -> type casting -> rounding of float artefacts -> postal-code repair
--        -> exact-duplicate removal -> returns dedupe -> chronology / range / outlier flags -> integrity filters.

-- People: one regional manager per region (trim, dedupe)
CREATE OR REPLACE TABLE cln_people AS
SELECT region, manager_name
FROM (
  SELECT trim(region) AS region, trim(person) AS manager_name,
         ROW_NUMBER() OVER (PARTITION BY lower(trim(region)) ORDER BY trim(person)) AS rn
  FROM stg_people
  WHERE NULLIF(trim(region), '') IS NOT NULL
) p
WHERE rn = 1;

-- Returns: the sheet lists one row per returned LINE without line ids -> collapse to one row per order
CREATE OR REPLACE TABLE cln_returns AS
SELECT trim(order_id) AS order_id,
       COUNT(*)       AS return_rows_in_source
FROM stg_returns
WHERE lower(trim(returned)) IN ('yes', 'y', 'true', '1')
  AND NULLIF(trim(order_id), '') IS NOT NULL
GROUP BY trim(order_id);

-- Orders (line grain)
CREATE OR REPLACE TABLE cln_orders AS
WITH typed AS (
  SELECT
    TRY_CAST(row_id AS INT)                                   AS row_id,
    upper(trim(order_id))                                     AS order_id,
    TRY_CAST(trim(order_date) AS DATE)                        AS order_date,
    TRY_CAST(trim(ship_date) AS DATE)                         AS ship_date,
    CASE lower(trim(ship_mode))
      WHEN 'same day' THEN 'Same Day' WHEN 'first class' THEN 'First Class'
      WHEN 'second class' THEN 'Second Class' WHEN 'standard class' THEN 'Standard Class'
      ELSE NULLIF(trim(ship_mode), '') END                    AS ship_mode,
    upper(trim(customer_id))                                  AS customer_id,
    trim(customer_name)                                       AS customer_name,
    trim(segment)                                             AS segment,
    trim(country_region)                                      AS country,
    trim(city)                                                AS city,
    trim(state)                                               AS state,
    -- postal codes lose leading zeros in Excel (e.g. 2920 -> 02920); missing in source for Burlington, VT
    CASE WHEN TRY_CAST(trim(postal_code) AS DOUBLE) IS NULL THEN NULL
         ELSE lpad(CAST(CAST(TRY_CAST(trim(postal_code) AS DOUBLE) AS INT) AS STRING), 5, '0') END AS postal_code,
    trim(region)                                              AS region,
    upper(trim(product_id))                                   AS product_id,
    trim(category)                                            AS category,
    trim(sub_category)                                        AS sub_category,
    trim(product_name)                                        AS product_name,
    ROUND(TRY_CAST(sales AS DOUBLE), 2)                       AS sales,
    TRY_CAST(quantity AS INT)                                 AS quantity,
    ROUND(TRY_CAST(discount AS DOUBLE), 2)                    AS discount,
    ROUND(TRY_CAST(profit AS DOUBLE), 4)                      AS profit
  FROM stg_orders
), dedup AS (
  -- exact duplicate lines (same order, product, values) except the surrogate row_id -> keep lowest row_id
  SELECT *, ROW_NUMBER() OVER (
    PARTITION BY order_id, product_id, product_name, order_date, ship_date, customer_id, sales, quantity, discount, profit
    ORDER BY row_id) AS dup_rn
  FROM typed
  WHERE row_id IS NOT NULL
), bounds AS (
  SELECT percentile_approx(sales, 0.25) AS q1, percentile_approx(sales, 0.75) AS q3,
         percentile_approx(profit, 0.01) AS p01, percentile_approx(profit, 0.99) AS p99
  FROM dedup WHERE dup_rn = 1
)
SELECT
  d.row_id, d.order_id, d.order_date, d.ship_date,
  datediff(d.ship_date, d.order_date)                         AS ship_days,
  d.ship_mode, d.customer_id, d.customer_name, d.segment, d.country, d.city, d.state,
  d.postal_code, d.region, d.product_id, d.category, d.sub_category, d.product_name,
  d.sales, d.quantity, d.discount, d.profit,
  ROUND(d.sales / NULLIF(1 - d.discount, 0), 2)               AS list_sales,
  ROUND(d.profit / NULLIF(d.sales, 0), 4)                     AS profit_margin,
  CASE WHEN d.discount = 0 THEN '01: 0%'
       WHEN d.discount <= 0.1 THEN '02: 1-10%'
       WHEN d.discount <= 0.2 THEN '03: 11-20%'
       WHEN d.discount <= 0.3 THEN '04: 21-30%'
       WHEN d.discount <= 0.5 THEN '05: 31-50%'
       ELSE '06: >50%' END                                    AS discount_band,
  CASE WHEN d.profit < 0 THEN 1 ELSE 0 END                    AS is_loss_line,
  CASE WHEN r.order_id IS NOT NULL THEN 1 ELSE 0 END          AS returned_flag,
  -- DQ / outlier flags (rows kept)
  CASE WHEN d.sales > b.q3 + 3 * (b.q3 - b.q1) THEN 1 ELSE 0 END AS is_sales_outlier_iqr3,
  CASE WHEN d.profit < b.p01 OR d.profit > b.p99 THEN 1 ELSE 0 END AS is_profit_extreme_p1_p99,
  CASE WHEN d.postal_code IS NULL THEN 1 ELSE 0 END           AS dq_missing_postal_code
FROM dedup d
CROSS JOIN bounds b
LEFT JOIN cln_returns r ON d.order_id = r.order_id
WHERE d.dup_rn = 1
  AND d.order_id IS NOT NULL AND d.order_date IS NOT NULL AND d.ship_date IS NOT NULL
  AND d.ship_date >= d.order_date
  AND d.sales IS NOT NULL AND d.sales > 0
  AND d.quantity IS NOT NULL AND d.quantity > 0
  AND d.discount BETWEEN 0 AND 1
  AND d.profit IS NOT NULL;

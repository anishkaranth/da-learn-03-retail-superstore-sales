-- 04_analysis.sql  Business KPI queries (Spark SQL dialect). Each result is materialised as an a_* table
-- and exported by run_pipeline.py to results/tables/<name>.csv.
-- Margin % = 100 * SUM(profit) / SUM(sales). Return rate = share of ORDERS that appear in the Returns sheet.

-- Q1 Headline KPIs
CREATE OR REPLACE TABLE a_kpi_headline AS
SELECT
  COUNT(*)                                                         AS order_lines,
  COUNT(DISTINCT order_id)                                         AS orders,
  COUNT(DISTINCT customer_key)                                     AS customers,
  COUNT(DISTINCT product_key)                                      AS products,
  ROUND(SUM(sales), 2)                                             AS total_sales,
  ROUND(SUM(profit), 2)                                            AS total_profit,
  ROUND(100.0 * SUM(profit) / SUM(sales), 2)                       AS profit_margin_pct,
  ROUND(SUM(sales) / COUNT(DISTINCT order_id), 2)                  AS avg_order_value,
  SUM(quantity)                                                    AS units,
  ROUND(AVG(discount) * 100, 2)                                    AS avg_discount_pct,
  ROUND(100.0 * SUM(is_loss_line) / COUNT(*), 2)                   AS loss_line_pct,
  ROUND(-SUM(CASE WHEN profit < 0 THEN profit ELSE 0 END), 2)      AS profit_lost_on_loss_lines,
  ROUND(100.0 * COUNT(DISTINCT CASE WHEN returned_flag = 1 THEN order_id END) / COUNT(DISTINCT order_id), 2) AS order_return_rate_pct,
  ROUND(SUM(CASE WHEN returned_flag = 1 THEN sales ELSE 0 END), 2) AS returned_sales,
  ROUND(AVG(ship_days), 2)                                         AS avg_ship_days,
  MIN(order_date)                                                  AS first_order_date,
  MAX(order_date)                                                  AS last_order_date
FROM fact_sales;

-- Q2 Regional profit (with regional manager)
CREATE OR REPLACE TABLE a_region_performance AS
SELECT
  g.region, g.regional_manager,
  COUNT(DISTINCT f.order_id) AS orders,
  ROUND(SUM(f.sales), 2) AS sales,
  ROUND(SUM(f.profit), 2) AS profit,
  ROUND(100.0 * SUM(f.profit) / SUM(f.sales), 2) AS margin_pct,
  ROUND(100.0 * SUM(f.sales) / SUM(SUM(f.sales)) OVER (), 2) AS sales_share_pct,
  ROUND(AVG(f.discount) * 100, 2) AS avg_discount_pct,
  ROUND(100.0 * COUNT(DISTINCT CASE WHEN f.returned_flag = 1 THEN f.order_id END) / COUNT(DISTINCT f.order_id), 2) AS order_return_rate_pct
FROM fact_sales f JOIN dim_geography g ON f.geo_key = g.geo_key
GROUP BY g.region, g.regional_manager;

-- Q3 States: most and least profitable
CREATE OR REPLACE TABLE a_state_profit AS
SELECT
  g.region, g.state,
  COUNT(DISTINCT f.order_id) AS orders,
  ROUND(SUM(f.sales), 2) AS sales,
  ROUND(SUM(f.profit), 2) AS profit,
  ROUND(100.0 * SUM(f.profit) / SUM(f.sales), 2) AS margin_pct,
  ROUND(AVG(f.discount) * 100, 2) AS avg_discount_pct,
  RANK() OVER (ORDER BY SUM(f.profit) DESC) AS profit_rank
FROM fact_sales f JOIN dim_geography g ON f.geo_key = g.geo_key
GROUP BY g.region, g.state;

-- Q4 Discount impact: margin collapses as discount rises
CREATE OR REPLACE TABLE a_discount_impact AS
SELECT
  discount_band,
  COUNT(*) AS order_lines,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS line_share_pct,
  ROUND(SUM(sales), 2) AS sales,
  ROUND(SUM(profit), 2) AS profit,
  ROUND(100.0 * SUM(profit) / SUM(sales), 2) AS margin_pct,
  ROUND(100.0 * SUM(is_loss_line) / COUNT(*), 2) AS loss_line_pct
FROM fact_sales
GROUP BY discount_band;

-- Q5 Discount x category: where discounting destroys profit
CREATE OR REPLACE TABLE a_discount_by_subcategory AS
SELECT
  p.category, p.sub_category,
  COUNT(*) AS order_lines,
  ROUND(SUM(f.sales), 2) AS sales,
  ROUND(SUM(f.profit), 2) AS profit,
  ROUND(100.0 * SUM(f.profit) / SUM(f.sales), 2) AS margin_pct,
  ROUND(AVG(f.discount) * 100, 2) AS avg_discount_pct,
  ROUND(100.0 * SUM(CASE WHEN f.discount > 0 THEN 1 ELSE 0 END) / COUNT(*), 2) AS discounted_line_pct,
  ROUND(100.0 * COUNT(DISTINCT CASE WHEN f.returned_flag = 1 THEN f.order_id END) / COUNT(DISTINCT f.order_id), 2) AS order_return_rate_pct
FROM fact_sales f JOIN dim_product p ON f.product_key = p.product_key
GROUP BY p.category, p.sub_category;

-- Q6 Shipping modes: speed, mix and profitability
CREATE OR REPLACE TABLE a_ship_mode AS
SELECT
  s.ship_mode, s.service_level_rank,
  COUNT(DISTINCT f.order_id) AS orders,
  ROUND(100.0 * COUNT(DISTINCT f.order_id) / (SELECT COUNT(DISTINCT order_id) FROM fact_sales), 2) AS order_share_pct,
  ROUND(AVG(f.ship_days), 2) AS avg_ship_days,
  MAX(f.ship_days) AS max_ship_days,
  ROUND(SUM(f.sales), 2) AS sales,
  ROUND(SUM(f.profit), 2) AS profit,
  ROUND(100.0 * SUM(f.profit) / SUM(f.sales), 2) AS margin_pct,
  ROUND(100.0 * COUNT(DISTINCT CASE WHEN f.returned_flag = 1 THEN f.order_id END) / COUNT(DISTINCT f.order_id), 2) AS order_return_rate_pct
FROM fact_sales f JOIN dim_ship_mode s ON f.ship_mode_key = s.ship_mode_key
GROUP BY s.ship_mode, s.service_level_rank;

-- Q7 Ship mode x segment order mix
CREATE OR REPLACE TABLE a_ship_mode_segment AS
SELECT
  c.segment, s.ship_mode,
  COUNT(DISTINCT f.order_id) AS orders,
  ROUND(100.0 * COUNT(DISTINCT f.order_id) / SUM(COUNT(DISTINCT f.order_id)) OVER (PARTITION BY c.segment), 2) AS pct_of_segment_orders
FROM fact_sales f
JOIN dim_customer c ON f.customer_key = c.customer_key
JOIN dim_ship_mode s ON f.ship_mode_key = s.ship_mode_key
GROUP BY c.segment, s.ship_mode;

-- Q8 Segment performance
CREATE OR REPLACE TABLE a_segment_performance AS
SELECT
  c.segment,
  COUNT(DISTINCT c.customer_key) AS customers,
  COUNT(DISTINCT f.order_id) AS orders,
  ROUND(SUM(f.sales), 2) AS sales,
  ROUND(SUM(f.profit), 2) AS profit,
  ROUND(100.0 * SUM(f.profit) / SUM(f.sales), 2) AS margin_pct,
  ROUND(SUM(f.sales) / COUNT(DISTINCT f.order_id), 2) AS avg_order_value
FROM fact_sales f JOIN dim_customer c ON f.customer_key = c.customer_key
GROUP BY c.segment;

-- Q9 Yearly trend with YoY growth
CREATE OR REPLACE TABLE a_yearly_trend AS
SELECT
  year, orders, sales, profit, margin_pct,
  ROUND(100.0 * (sales - LAG(sales) OVER (ORDER BY year)) / LAG(sales) OVER (ORDER BY year), 2) AS sales_yoy_pct,
  ROUND(100.0 * (profit - LAG(profit) OVER (ORDER BY year)) / LAG(profit) OVER (ORDER BY year), 2) AS profit_yoy_pct
FROM (
  SELECT d.year, COUNT(DISTINCT f.order_id) AS orders, ROUND(SUM(f.sales), 2) AS sales,
         ROUND(SUM(f.profit), 2) AS profit, ROUND(100.0 * SUM(f.profit) / SUM(f.sales), 2) AS margin_pct
  FROM fact_sales f JOIN dim_date d ON f.order_date_key = d.date_key
  GROUP BY d.year
) y;

-- Q10 Monthly sales and profit
CREATE OR REPLACE TABLE a_monthly_sales AS
SELECT
  d.year_month,
  COUNT(DISTINCT f.order_id) AS orders,
  ROUND(SUM(f.sales), 2) AS sales,
  ROUND(SUM(f.profit), 2) AS profit
FROM fact_sales f JOIN dim_date d ON f.order_date_key = d.date_key
GROUP BY d.year_month;

-- Q11 Products that lose the most money
CREATE OR REPLACE TABLE a_top_loss_products AS
SELECT * FROM (
  SELECT
    p.product_name, p.sub_category,
    COUNT(*) AS order_lines,
    ROUND(SUM(f.sales), 2) AS sales,
    ROUND(SUM(f.profit), 2) AS profit,
    ROUND(AVG(f.discount) * 100, 2) AS avg_discount_pct,
    ROW_NUMBER() OVER (ORDER BY SUM(f.profit), p.product_name) AS loss_rank
  FROM fact_sales f JOIN dim_product p ON f.product_key = p.product_key
  GROUP BY p.product_name, p.sub_category
) x WHERE loss_rank <= 10;

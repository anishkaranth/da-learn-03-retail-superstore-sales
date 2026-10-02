-- 01_staging.sql
-- Land the 3 raw CSVs (exported from the Superstore workbook) as all-STRING staging tables.
-- {{RAW_DIR}} is substituted by run_pipeline.py.
-- DuckDB : read_csv(path, header = true, all_varchar = true)
-- Databricks equivalent (databricks/superstore_pipeline_notebook.sql):
--   SELECT * FROM read_files('/Volumes/workspace/da_learn_03/raw/orders.csv', format => 'csv',
--          header => true, multiLine => true, escape => '"', inferColumnTypes => false)
CREATE OR REPLACE TABLE stg_orders AS
SELECT * FROM read_csv('{{RAW_DIR}}/orders.csv', header = true, all_varchar = true);

CREATE OR REPLACE TABLE stg_returns AS
SELECT * FROM read_csv('{{RAW_DIR}}/returns.csv', header = true, all_varchar = true);

CREATE OR REPLACE TABLE stg_people AS
SELECT * FROM read_csv('{{RAW_DIR}}/people.csv', header = true, all_varchar = true);

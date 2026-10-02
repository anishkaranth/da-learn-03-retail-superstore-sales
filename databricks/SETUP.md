# Databricks package

The full pipeline ran on the Databricks **Serverless Starter Warehouse** (Unity Catalog) and a Lakeview (AI/BI)
dashboard was published over the resulting tables. The warehouse is left to auto-stop.

| Object | Workspace location |
|---|---|
| Raw CSVs (full) | UC volume `/Volumes/workspace/da_learn_03/raw/` (orders.csv, returns.csv, people.csv) |
| Tables (stg_*, cln_*, dim_*, fact_sales, a_*, dq_*) | `workspace.da_learn_03` |
| Notebook | `/Workspace/Shared/da-learn-03-retail-superstore-sales/superstore_pipeline_notebook` |
| Dashboard (published) | **da-learn-03 Retail Superstore sales** (2 pages: Overview, Profit leaks; 2 counters + 6 charts) |

## DuckDB vs Databricks (`run_outputs/duckdb_vs_databricks.json`)
All **12 core tables have identical row counts** (stg_orders 9,994; cln_orders / fact_sales 9,993; cln_returns 296; dim_date 1,236;
dim_customer 793; dim_product 1,894; dim_geography 632; dim_ship_mode 4). `a_kpi_headline`, `a_region_performance`, `a_discount_impact`,
`a_ship_mode` and `dq_assertions` (12/12 PASS) match cell-for-cell. `dq_issues` differs in one row: profit outside p1-p99 = 198 (Databricks,
approximate `percentile_approx`) vs 200 (DuckDB, exact).

## Files here
| File | What it is |
|---|---|
| `superstore_pipeline_notebook.sql` | Databricks SQL notebook (exported from the workspace after import), generated from `sql/` |
| `superstore_sales_dashboard.lvdash.json` | Lakeview dashboard definition exported from the workspace |
| `run_outputs/` | Tables queried back from Databricks, `databricks_run.json` (statement log), `dashboard_publish.json`, `duckdb_vs_databricks.json` |

## Re-run it yourself
1. `CREATE SCHEMA IF NOT EXISTS workspace.da_learn_03; CREATE VOLUME IF NOT EXISTS workspace.da_learn_03.raw;`
2. `python scripts/download_full_data.py`, then upload `data/raw_full/{orders,returns,people}.csv` to the volume (Catalog Explorer -> Upload).
3. Workspace -> *Import* -> `superstore_pipeline_notebook.sql`; attach a SQL warehouse -> *Run all*. Check `dq_assertions` = 12 x PASS.
4. Dashboards -> *Import dashboard from file* -> `superstore_sales_dashboard.lvdash.json` -> choose a warehouse -> *Publish*.

## Dialect notes
| Topic | DuckDB run | Databricks |
|---|---|---|
| CSV load | `read_csv(path, header = true, all_varchar = true)` | `read_files(..., inferColumnTypes => false)` |
| `percentile_approx` | exact (`quantile_cont` shim) | approximate |
| `datediff(end, start)`, `dayofweek` | macros in `00_duckdb_compat.sql` | built in |

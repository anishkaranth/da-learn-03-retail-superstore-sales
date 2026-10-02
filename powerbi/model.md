# Power BI model

## Tables (from `powerbi/data/`, sample-sized; full star in `data/clean_full/star/` after `run_pipeline.py --source full`)
| Table | Grain | Key columns |
|---|---|---|
| `fact_sales` | order line | `line_id` (unique), `order_id`, `order_date_key`, `customer_key`, `product_key`, `geo_key`, `ship_mode_key` |
| `dim_date` | order date | `date_key` (yyyymmdd), `full_date`, `year`, `quarter`, `month`, `year_month` |
| `dim_customer` | customer | `customer_key`, `customer_id`, `customer_name`, `segment` |
| `dim_product` | product id + name | `product_key`, `product_id`, `product_name`, `category`, `sub_category` |
| `dim_geography` | region/state/city/postal | `geo_key`, `region`, `state`, `city`, `postal_code`, `regional_manager` |
| `dim_ship_mode` | ship mode | `ship_mode_key`, `ship_mode`, `service_level_rank` |

## Relationships (*:1, single direction)
1. `fact_sales[order_date_key]` -> `dim_date[date_key]` (mark `dim_date` as date table on `full_date`)
2. `fact_sales[customer_key]` -> `dim_customer[customer_key]`
3. `fact_sales[product_key]` -> `dim_product[product_key]`
4. `fact_sales[geo_key]` -> `dim_geography[geo_key]`
5. `fact_sales[ship_mode_key]` -> `dim_ship_mode[ship_mode_key]`

## Data types
* Keys, quantity, ship_days, flags: Whole number. `sales`, `list_sales`, `profit`: Fixed decimal (currency). `discount`, `profit_margin`: Decimal (percentage format).
* `postal_code`: **Text** (keeps leading zeros). Dates: Date.
* Sort `discount_band` by itself (labels are prefixed `01:`..`06:`), `ship_mode` by `service_level_rank`.
Hide keys and outlier flags from report view.

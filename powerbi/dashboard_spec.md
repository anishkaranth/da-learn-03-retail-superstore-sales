# Dashboard specification (3 pages)

Validate against full-data SQL (`results/metrics.json`): Sales **$2,296,919.61**, Profit **$286,409.08**, Margin **12.47 %**,
Orders **5,009**, Return rate **5.91 %**. (The CSVs in `powerbi/data/` are the 66-line sample: expected values in `results/sample/JSON.shot`.)

## Page 1 - Executive overview
* KPI cards: Total Sales, Total Profit, Profit Margin %, Orders, Avg Discount %, Order Return Rate %
* Clustered bar: Total Profit and Profit Margin % by `dim_geography[region]` (tooltip `regional_manager`)
* Line: Total Sales and Total Profit by `dim_date[year_month]`; card Sales YoY %
* Slicers: `dim_date[year]`, `dim_customer[segment]`, `dim_product[category]`

## Page 2 - Discount impact
* Column: Profit Margin % by `fact_sales[discount_band]` (conditional colour: red when < 0)
* Bar: Total Profit by `dim_product[sub_category]` sorted ascending, tooltip Avg Discount %
* Scatter: Avg Discount % (X) vs Profit Margin % (Y) per `dim_geography[state]`, size = Total Sales
* Table: top 10 loss products (product_name, Total Sales, Total Profit, Avg Discount %)

## Page 3 - Shipping
* Column: Orders by `dim_ship_mode[ship_mode]` (sort by `service_level_rank`), line = Avg Ship Days
* 100 % stacked bar: Orders by `dim_customer[segment]` x `ship_mode`
* Matrix: region x ship_mode with Orders, Profit Margin %, Order Return Rate %

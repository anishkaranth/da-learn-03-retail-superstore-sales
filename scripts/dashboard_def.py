"""Lakeview dashboard + notebook visualization definitions for da-learn-03 (used by build_databricks.py)."""
from lakeview import ds, text, counter, chart, PCT, USD

VIZ = [
    ("Profit by region", "Bar: X = region, Y = profit (label margin_pct)",
     "SELECT region, regional_manager, sales, profit, margin_pct FROM a_region_performance ORDER BY profit DESC"),
    ("Discount impact", "Bar: X = discount_band, Y = margin_pct",
     "SELECT discount_band, order_lines, sales, profit, margin_pct, loss_line_pct FROM a_discount_impact ORDER BY discount_band"),
    ("Profit by sub-category", "Horizontal bar: Y = sub_category, X = profit",
     "SELECT category, sub_category, sales, profit, margin_pct, avg_discount_pct FROM a_discount_by_subcategory ORDER BY profit"),
    ("Shipping modes", "Bar: X = ship_mode, Y = orders (tooltip avg_ship_days, margin_pct)",
     "SELECT ship_mode, orders, order_share_pct, avg_ship_days, margin_pct FROM a_ship_mode ORDER BY service_level_rank"),
    ("Monthly sales", "Line: X = year_month, Y = sales",
     "SELECT year_month, orders, sales, profit FROM a_monthly_sales ORDER BY year_month"),
    ("State profit", "Horizontal bar: Y = state, X = profit",
     "SELECT state, region, sales, profit, margin_pct FROM a_state_profit ORDER BY profit"),
]


def dashboard(fq):
    q = lambda t: f"{fq}.{t}"
    datasets = [
        ds("kpi", "Headline KPIs", f"SELECT total_sales, total_profit, profit_margin_pct / 100 AS margin_rate, orders, order_return_rate_pct / 100 AS return_rate FROM {q('a_kpi_headline')}"),
        ds("region", "Region", f"SELECT region, regional_manager, sales, profit, margin_pct FROM {q('a_region_performance')}"),
        ds("discount", "Discount bands", f"SELECT discount_band, order_lines, margin_pct, loss_line_pct FROM {q('a_discount_impact')} ORDER BY discount_band"),
        ds("subcat", "Sub-category", f"SELECT sub_category, profit, margin_pct, avg_discount_pct FROM {q('a_discount_by_subcategory')}"),
        ds("ship", "Ship mode", f"SELECT ship_mode, service_level_rank, orders, avg_ship_days, margin_pct FROM {q('a_ship_mode')} ORDER BY service_level_rank"),
        ds("monthly", "Monthly", f"SELECT to_date(concat(year_month, '-01')) AS month_start, sales, profit FROM {q('a_monthly_sales')}"),
        ds("state", "States", f"SELECT state, profit FROM {q('a_state_profit')} WHERE profit_rank <= 5 OR profit_rank >= (SELECT MAX(profit_rank) - 4 FROM {q('a_state_profit')})"),
    ]
    p1 = [text("title", "## Sample Superstore - regional profit, discounts and shipping (full data, 2018-2021)", {"x": 0, "y": 0, "width": 6, "height": 1}),
          counter("kpi_sales", "kpi", "total_sales", "Total sales", USD, 0, w=2),
          counter("kpi_margin", "kpi", "margin_rate", "Profit margin", PCT, 2, w=2),
          text("note", "Margin = profit / sales. Return rate = orders in Returns sheet / all orders. Source: Tableau Sample Superstore (Kaggle mirror). Tables in workspace.da_learn_03.", {"x": 4, "y": 1, "width": 2, "height": 2}),
          chart("region_bar", "bar", "region", ("region", "Region"), ("profit", "Profit ($)"), "Profit by region", {"x": 0, "y": 3, "width": 3, "height": 6}),
          chart("discount_bar", "bar", "discount", ("discount_band", "Discount band"), ("margin_pct", "Margin %"), "Discount impact on margin %", {"x": 3, "y": 3, "width": 3, "height": 6}),
          chart("monthly_line", "line", "monthly", ("month_start", "Month"), ("sales", "Sales ($)"), "Monthly sales", {"x": 0, "y": 9, "width": 6, "height": 5}, xs="temporal")]
    p2 = [text("title2", "## Where profit is lost: sub-categories, states, shipping", {"x": 0, "y": 0, "width": 6, "height": 1}),
          chart("subcat_bar", "bar", "subcat", ("sub_category", "Sub-category"), ("profit", "Profit ($)"), "Profit by sub-category", {"x": 0, "y": 1, "width": 3, "height": 8}, horizontal=True),
          chart("state_bar", "bar", "state", ("state", "State"), ("profit", "Profit ($)"), "Top 5 / bottom 5 states by profit", {"x": 3, "y": 1, "width": 3, "height": 8}, horizontal=True),
          chart("ship_bar", "bar", "ship", ("ship_mode", "Ship mode"), ("orders", "Orders"), "Orders by shipping mode", {"x": 0, "y": 9, "width": 6, "height": 5})]
    return {"datasets": datasets, "pages": [
        {"name": "overview", "displayName": "Overview", "pageType": "PAGE_TYPE_CANVAS", "layout": p1},
        {"name": "profit_leaks", "displayName": "Profit leaks", "pageType": "PAGE_TYPE_CANVAS", "layout": p2}]}

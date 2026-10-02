#!/usr/bin/env python3
"""Render the dashboard preview + individual charts as pure-vector SVG (no embedded images) from results/tables/*.csv."""
import io, pathlib, sys
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from svgmin import minify_svg

plt.rcParams.update({"svg.fonttype": "none", "font.family": "sans-serif", "font.size": 9,
                     "axes.spines.top": False, "axes.spines.right": False})
C1, C2, C3, GREY = "#1f6f8b", "#e07a5f", "#81b29a", "#999999"


def save(fig, path):
    buf = io.StringIO(); fig.savefig(buf, format="svg", bbox_inches="tight"); plt.close(fig)
    path.write_text(minify_svg(buf.getvalue()))


def p_region(ax, t):
    d = pd.read_csv(t / "a_region_performance.csv").sort_values("profit")
    ax.barh(d.region + " (" + d.regional_manager.str.split().str[0] + ")", d.profit / 1000, color=C1)
    for i, (p, m) in enumerate(zip(d.profit, d.margin_pct)):
        ax.text(p / 1000 + 1, i, f"${p/1000:.1f}k | {m:.1f}% margin", va="center", fontsize=7)
    ax.set_xlabel("Profit ($k)"); ax.set_title("Profit by region (manager)")
    ax.set_xlim(0, d.profit.max() / 1000 * 1.6)


def p_discount(ax, t):
    d = pd.read_csv(t / "a_discount_impact.csv").sort_values("discount_band")
    cols = [C3 if v >= 0 else C2 for v in d.margin_pct]
    ax.bar(d.discount_band.str[4:], d.margin_pct, color=cols)
    for i, (v, n) in enumerate(zip(d.margin_pct, d.order_lines)):
        ax.text(i, v + (3 if v >= 0 else -10), f"{v:.1f}%\nn={n:,}", ha="center", fontsize=7)
    ax.axhline(0, color="#333", lw=0.6)
    ax.set_ylabel("Profit margin %"); ax.set_xlabel("Discount band"); ax.set_title("Discount impact on margin")
    ax.set_ylim(min(d.margin_pct.min() * 1.3, -10), d.margin_pct.max() * 1.4)


def p_subcat(ax, t):
    d = pd.read_csv(t / "a_discount_by_subcategory.csv").sort_values("profit")
    ax.barh(d.sub_category, d.profit / 1000, color=[C2 if v < 0 else C1 for v in d.profit])
    ax.axvline(0, color="#333", lw=0.6)
    for i, (v, dc) in enumerate(zip(d.profit, d.avg_discount_pct)):
        ax.text(v / 1000 + (1 if v >= 0 else -1), i, f"{dc:.0f}% disc", va="center", ha="left" if v >= 0 else "right", fontsize=6)
    ax.set_xlabel("Profit ($k)"); ax.set_title("Profit by sub-category (avg discount)")
    ax.set_xlim(d.profit.min() / 1000 * 1.8, d.profit.max() / 1000 * 1.35)


def p_ship(ax, t):
    d = pd.read_csv(t / "a_ship_mode.csv").sort_values("service_level_rank")
    ax.bar(d.ship_mode, d.order_share_pct, color=C1)
    for i, (s, days, m) in enumerate(zip(d.order_share_pct, d.avg_ship_days, d.margin_pct)):
        ax.text(i, s + 1.5, f"{s:.1f}% of orders\n{days:.1f} days | {m:.1f}% mgn", ha="center", fontsize=7)
    ax.set_ylabel("Share of orders %"); ax.set_ylim(0, d.order_share_pct.max() * 1.35)
    ax.set_title("Shipping modes: mix, speed, margin")


def p_year(ax, t):
    d = pd.read_csv(t / "a_yearly_trend.csv").sort_values("year")
    x = range(len(d)); w = 0.4
    ax.bar([i - w / 2 for i in x], d.sales / 1000, w, color=C1, label="Sales")
    ax.bar([i + w / 2 for i in x], d.profit / 1000, w, color=C3, label="Profit")
    for i, (s, m) in enumerate(zip(d.sales, d.margin_pct)):
        ax.text(i, s / 1000 + 15, f"${s/1000:.0f}k\n{m:.1f}%", ha="center", fontsize=7)
    ax.set_xticks(list(x)); ax.set_xticklabels(d.year.astype(str))
    ax.set_ylabel("$k"); ax.set_ylim(0, d.sales.max() / 1000 * 1.3); ax.legend(frameon=False, fontsize=7, loc="upper left")
    ax.set_title("Sales and profit by year (margin %)")


def p_state(ax, t):
    d = pd.read_csv(t / "a_state_profit.csv").sort_values("profit")
    d = pd.concat([d.head(5), d.tail(5)])
    ax.barh(d.state, d.profit / 1000, color=[C2 if v < 0 else C1 for v in d.profit])
    ax.axvline(0, color="#333", lw=0.6)
    for i, (v, dc) in enumerate(zip(d.profit, d.avg_discount_pct)):
        ax.text(v / 1000 + (1 if v >= 0 else -1), i, f"{dc:.0f}% disc", va="center", ha="left" if v >= 0 else "right", fontsize=6)
    ax.set_xlabel("Profit ($k)"); ax.set_title("Top 5 / bottom 5 states by profit")
    ax.set_xlim(d.profit.min() / 1000 * 1.6, d.profit.max() / 1000 * 1.3)


PANELS = [("region_profit", p_region), ("discount_impact", p_discount), ("subcategory_profit", p_subcat),
          ("ship_mode", p_ship), ("yearly_trend", p_year), ("state_profit", p_state)]


def make_all(tables, out):
    tables, out = pathlib.Path(tables), pathlib.Path(out); out.mkdir(parents=True, exist_ok=True)
    for name, fn in PANELS:
        fig, ax = plt.subplots(figsize=(6.4, 3.8)); fn(ax, tables); save(fig, out / f"{name}.svg")
    k = pd.read_csv(tables / "a_kpi_headline.csv").iloc[0]
    fig, axes = plt.subplots(3, 2, figsize=(14, 14)); fig.subplots_adjust(hspace=0.5, wspace=0.45, top=0.88)
    for ax, (_, fn) in zip(axes.flat, PANELS):
        fn(ax, tables)
    cards = [("Sales", f"${k.total_sales/1e6:.2f}M"), ("Profit", f"${k.total_profit/1e3:.0f}k"),
             ("Margin", f"{k.profit_margin_pct:.2f}%"), ("Orders", f"{int(k.orders):,}"),
             ("Avg discount", f"{k.avg_discount_pct:.1f}%"), ("Loss lines", f"{k.loss_line_pct:.1f}%"),
             ("Return rate", f"{k.order_return_rate_pct:.1f}%")]
    fig.suptitle("Sample Superstore sales dashboard (preview rendered from SQL outputs, full data)", fontsize=14, y=0.975)
    for i, (lab, val) in enumerate(cards):
        x = 0.1 + i * 0.13
        fig.text(x, 0.935, val, fontsize=13, weight="bold", ha="center", color=C1)
        fig.text(x, 0.918, lab, fontsize=9, ha="center", color="#555")
    save(fig, out / "dashboard.svg")
    print("charts ->", out, sorted(p.name for p in out.glob("*.svg")))


if __name__ == "__main__":
    root = pathlib.Path(__file__).resolve().parents[1]
    make_all(root / "results/tables", root / "results/charts")

#!/usr/bin/env python3
"""Build the reproducible raw subset in data/raw/ from data/raw_full/ (run download_full_data.py first).

Rule (deterministic): keep every line of orders whose numeric order number (last 6 digits of order_id, e.g.
CA-2020-152156 -> 152156) is divisible by 160, the Returns rows for those orders, and all 4 People rows.
Values are copied as strings; the only change is that non-breaking spaces (U+00A0, present in a few product
names) become plain spaces so the committed CSVs are plain ASCII. All other cleaning is in sql/02_cleaning.sql.
"""
import pathlib, duckdb

ROOT = pathlib.Path(__file__).resolve().parents[1]
FULL, OUT = (ROOT / "data/raw_full").as_posix(), ROOT / "data/raw"
OUT.mkdir(parents=True, exist_ok=True)
con = duckdb.connect()
keep = "TRY_CAST(right(trim(order_id), 6) AS INT) % 160 = 0"
jobs = {
    "orders.csv": f"SELECT * FROM read_csv('{FULL}/orders.csv', header = true, all_varchar = true) WHERE {keep} ORDER BY TRY_CAST(row_id AS INT)",
    "returns.csv": f"SELECT * FROM read_csv('{FULL}/returns.csv', header = true, all_varchar = true) WHERE {keep}",
    "people.csv": f"SELECT * FROM read_csv('{FULL}/people.csv', header = true, all_varchar = true)",
}
for name, q in jobs.items():
    con.execute(f"COPY ({q}) TO '{(OUT / name).as_posix()}' (HEADER, DELIMITER ',')")
    n = con.execute(f"SELECT COUNT(*) FROM read_csv('{(OUT / name).as_posix()}', header = true, all_varchar = true)").fetchone()[0]
    path = OUT / name
    path.write_text(path.read_text(encoding="utf-8").replace("\u00a0", " "), encoding="utf-8")
    print(f"{name:12s} {n:5d} rows")

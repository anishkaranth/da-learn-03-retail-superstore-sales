#!/usr/bin/env python3
"""Download the full Sample Superstore workbook and export its 3 sheets to CSV in data/raw_full/.

Kaggle (same data, Orders sheet only): https://www.kaggle.com/datasets/vivek468/superstore-dataset-final
Original publisher: Tableau "Sample - Superstore" (US, Orders / Returns / People sheets).
Mirror used (Tableau workbook archived 2021-07-08, dates 2018-2021):
  https://raw.githubusercontent.com/chuawt-archive/datasets/master/superstore/sample_superstore_2021.xls
Export rules: header names -> snake_case (e.g. "Order ID" -> order_id, "Sub-Category" -> sub_category);
values are written verbatim as text (dates ISO yyyy-mm-dd, numbers as stored in the workbook). No rows are changed.
Requires: pandas + xlrd (pip install -r requirements.txt).
"""
import hashlib, pathlib, re, urllib.request
import pandas as pd

MIRROR = "https://raw.githubusercontent.com/chuawt-archive/datasets/master/superstore/sample_superstore_2021.xls"
SHA256 = "03d9e99f29755e641075b0caedf00d10e9416fda3668039dc7c9982500a329fc"
XLS = "sample_superstore_2021.xls"
SHEETS = {"Orders": "orders.csv", "Returns": "returns.csv", "People": "people.csv"}

out = pathlib.Path(__file__).resolve().parents[1] / "data" / "raw_full"
out.mkdir(parents=True, exist_ok=True)
p = out / XLS
if not p.exists():
    print("downloading", MIRROR)
    urllib.request.urlretrieve(MIRROR, p)
got = hashlib.sha256(p.read_bytes()).hexdigest()
print(f"{XLS:32s} {'OK' if got == SHA256 else 'CHECKSUM MISMATCH ' + got}")
if got != SHA256:
    raise SystemExit(1)


def snake(c):
    return re.sub(r"[^0-9a-z]+", "_", c.strip().lower()).strip("_")


for sheet, name in SHEETS.items():
    df = pd.read_excel(p, sheet_name=sheet, dtype=object)
    df.columns = [snake(c) for c in df.columns]
    for c in df.columns:
        if "date" in c:
            df[c] = pd.to_datetime(df[c]).dt.strftime("%Y-%m-%d")
    df.to_csv(out / name, index=False, lineterminator="\n")
    print(f"{name:14s} {len(df):6d} rows  {len(df.columns)} cols")

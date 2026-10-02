# Data

| Folder | Content | In git? |
|---|---|---|
| `raw/` | **Reproducible subset** of the 3 raw CSVs (original columns, values verbatim) | yes |
| `raw_full/` | Full workbook + 3 CSVs (~5.4 MB) - `python scripts/download_full_data.py` | no (`.gitignore`) |
| `clean_full/star/` | Star-schema tables from the full run (`--source full`) | no (`.gitignore`) |

## Source
* Tableau **Sample - Superstore** (US), sheets Orders (9,994 rows x 21), Returns (800 x 2), People (4 x 2), order dates 2018-01-03 .. 2021-12-30.
* Kaggle: https://www.kaggle.com/datasets/vivek468/superstore-dataset-final (Orders sheet only; licence "Other")
* Mirror used: https://raw.githubusercontent.com/chuawt-archive/datasets/master/superstore/sample_superstore_2021.xls (archived from Tableau 2021-07-08, SHA-256 pinned)
* Export: `download_full_data.py` writes each sheet to CSV with **snake_case headers** (`Order ID` -> `order_id`, `Country/Region` -> `country_region`)
  and ISO dates; values are otherwise verbatim (including float artefacts and 4-digit postal codes, which the SQL cleans).

## Subset rule (`scripts/make_sample.py`, deterministic)
* `orders.csv`: all lines whose order number (last 6 digits of `order_id`) % 160 = 0 -> **66 lines / 33 orders**
* `returns.csv`: Returns rows for those orders -> **7 rows**; `people.csv`: all **4** rows
* **All numbers in `results/` come from the FULL dataset.** The subset only proves the pipeline runs (`results/sample/JSON.shot`).

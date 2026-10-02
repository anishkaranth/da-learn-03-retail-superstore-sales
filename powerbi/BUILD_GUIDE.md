# Power BI build guide

> A `.pbix` cannot be produced on the Linux box this project was built on (Power BI Desktop is Windows-only, no headless authoring),
> so this folder is a **kit**: data + model + measures + layout spec. Estimated build time: 30-45 min.

1. **Get the data.** `powerbi/data/` holds the star schema from the 66-line **sample** (text-friendly size). For the full model run
   `pip install -r requirements.txt && python scripts/download_full_data.py && python run_pipeline.py --source full` and load
   `data/clean_full/star/*.csv` instead (9,993 fact rows).
2. **Load.** *Get data -> Text/CSV* for the 6 files (`fact_sales`, `dim_date`, `dim_customer`, `dim_product`, `dim_geography`, `dim_ship_mode`).
   Set `postal_code` to Text before loading (keeps leading zeros). Locale: English (United States).
3. **Model.** Create the 5 relationships in `model.md` (all *:1, single direction); mark `dim_date` as a date table.
4. **Measures.** New table `_Measures`; paste each line of `measures.dax`. Format %/currency as noted.
5. **Pages.** Build the 3 pages in `dashboard_spec.md`; compare with `results/charts/dashboard.svg`.
6. **Validate** (full data): Sales $2,296,919.61, Profit $286,409.08, Margin 12.47 %, Orders 5,009, >50 % discount margin -119.20 %.
7. Save as `superstore_sales.pbix` (not committed - binary).

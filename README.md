# Delivery Performance & SLA Analysis

I wanted to answer a simple ops question: which shipping modes, regions and product categories miss their delivery promise most often, and what does that cost? I framed it around Indian e-commerce (think Flipkart, Meesho, Nykaa), where the promised delivery date at checkout matters a lot and a missed date usually means a support ticket, a cancellation or an RTO.

Short version: only 42.7% of orders arrived on time in the last 12 months of data, against a 95% target. Lateness costs roughly Rs 23.4 lakh a year. It isn't a geography problem. It's the delivery promise per shipping mode. First Class promises 1 day and takes 2 every single time.

Tools: PostgreSQL, SQL, Tableau Public, a bit of Python for the significance tests.

## Data

[DataCo Smart Supply Chain](https://www.kaggle.com/datasets/shashwatwork/dataco-smart-supply-chain-for-big-data-analysis) from Kaggle: 180,519 order lines, 65,752 orders, Jan 2015 to Jan 2018. It has about 2,150 orders shipped to 146 Indian cities, which is what made the metro vs Tier 2/3 comparison possible.

I started with the smaller "Supply Chain Analysis" dataset that gets recommended for this kind of project. It has 100 rows and no dates, so there is no way to compare scheduled vs actual delivery or show a trend. DataCo has both.

The raw CSV is 96 MB, so it isn't in the repo. Download `DataCoSupplyChainDataset.csv` from the link above.

## Data cleaning

I first opened the file in Excel to get a feel for it, then did all the actual cleaning in SQL so it can be re-run.

**1. Exploring in Excel**
- Opened the CSV, saved a working copy and looked through the 53 columns.
- Spotted the problems listed below: extra spaces, Spanish place names, US dates that Excel was converting wrongly, and SUSPECTED_FRAUD / CANCELED orders.
- Checked that 6 pairs of columns were exact duplicates using `SUMPRODUCT` (0 differences in every pair).

**2. Loading (`sql/01_load.sql`)**
- Loaded the raw CSV into a table where every column is text, so a bad value can't break the load.
- The file is Latin-1, not UTF-8, so it's loaded with `ENCODING 'LATIN1'`. Otherwise names like Rajastán and São Paulo come out garbled.
- Check: 180,519 rows loaded.

**3. Cleaning (`sql/02_clean.sql`)**

| Step | Rows affected | What I did |
|---|---:|---|
| Dropped columns I didn't need | all | Removed 15 of 53 columns: masked email/password, customer name and street (personal data), `product_description` (100% empty), `order_zipcode` (86% empty), `product_image`, `product_status` (always 0) and 6 duplicate columns |
| Fixed data types | all | Text to integers, decimals and timestamps |
| Parsed dates | all | Dates are US format (M/D/YYYY), so I read them with `TO_TIMESTAMP(..., 'MM/DD/YYYY HH24:MI')`. Excel had read 2/3/2018 as 2 March. |
| Removed extra spaces | 17,925 in region, 1,774 in product, 1,543 in category, 362 in department | `TRIM` plus collapsing double spaces (e.g. `'South of  USA '`) so the same value doesn't show up twice in charts |
| Flagged cancelled orders | 7,754 | `is_cancelled = 1` for SUSPECTED_FRAUD and CANCELED orders. These are left out of all on-time numbers. |
| Added delivery columns | all | `promised_days`, `actual_days`, `delay_days` (days past the promise, 0 if on time), `is_late`, `order_month` |

Checks after cleaning: 180,519 rows, 7,754 cancelled, 98,977 late, 160,163 total delay days. The late count matches the dataset's own `Late_delivery_risk` flag.

**4. India city tiers (`sql/03_city_tiers.sql`)**
- Built a lookup of 85 cities from the government HRA city list (X = Metro, Y = Tier 2, everything else Tier 3), using the dataset's own spellings ('Dehra Dun', 'Nasik', 'Allahabad').
- Result: 380 Metro, 1,263 Tier 2 and 427 Tier 3 delivered orders.

**5. One row per order (`sql/04_orders_view.sql`)**
- The data has one row per item, so an order with 5 items would be counted 5 times. I collapsed it to one row per order.
- Checked first that every item in an order has the same shipping mode, dates and late flag: 0 conflicts.
- Result: 65,752 orders, 62,897 delivered.

**Other things worth knowing about the data**
- There's no carrier column, so I used shipping mode (Standard / Second / First Class / Same Day) as the service level instead.
- State and country names are in Spanish (Rajastán, Guyarat, Alemania). That didn't affect the analysis, since it uses city names for India.
- Actual shipping days are spread almost perfectly evenly within each mode (Second Class is basically uniform between 2 and 6 days), so the data looks simulated. I treat the results as a demo of the method rather than a real-world finding.

## How it's built

On-time means actual shipping days are less than or equal to the promised days. `delay_days` is how many days over the promise an order was (0 if on time).

| File | What it does |
|---|---|
| [sql/01_load.sql](sql/01_load.sql) | Raw table (everything as text) and the `COPY` load |
| [sql/02_clean.sql](sql/02_clean.sql) | Typed, trimmed `deliveries` table with `delay_days`, `is_late`, `is_cancelled` |
| [sql/03_city_tiers.sql](sql/03_city_tiers.sql) | India Metro / Tier 2 / Tier 3 lookup |
| [sql/04_orders_view.sql](sql/04_orders_view.sql) | One row per order |
| [sql/05_ontime_by_dimension.sql](sql/05_ontime_by_dimension.sql) | On-time % by mode, market, region, tier and category, ranked worst first, with the gap to 95% |
| [sql/06_cost_impact.sql](sql/06_cost_impact.sql) | Cost of late deliveries and the what-if scenarios |
| [sql/07_monthly_trend.sql](sql/07_monthly_trend.sql) | Monthly trend with a 3-month rolling average |
| [sql/08_export_for_tableau.sql](sql/08_export_for_tableau.sql) | CSV exports for Tableau |
| [python/stat_tests.py](python/stat_tests.py) | Chi-square and z-tests behind the "X is worse than Y" claims |

India tiers follow the government's HRA city classification: X cities are Metro, Y cities are Tier 2, everything else is Tier 3. Kolkata and Ahmedabad aren't in the India orders, so there are 7 metros.

For cost I used two parts:

1. Holding cost, the way the brief suggested: delay days x order value x 25% a year / 365.
2. A flat Rs 150 per late order for the support contact, goodwill voucher and some share of cancellations/RTO.

Sales are in USD, so I converted at Rs 85. All of these numbers are assumptions and they sit in one table (`cost_params`), so they're easy to change. Holding cost on its own is small (Rs 5.1 L). Most of the cost comes from the broken-promise part.

## What I found

Latest 12 months (Feb 2017 to Jan 2018), 21,262 delivered orders:

| Shipping mode | Orders | On-time | Gap to 95% | Late cost (Rs L / yr) |
|---|---:|---:|---:|---:|
| First Class | 3,245 | 0.0% | -95.0 pts | 5.71 |
| Second Class | 4,153 | 20.3% | -74.7 pts | 7.11 |
| Same Day | 1,169 | 47.4% | -47.6 pts | 1.07 |
| Standard Class | 12,695 | 60.5% | -34.5 pts | 9.49 |
| All orders | 21,262 | 42.7% | -52.3 pts | 23.38 |

- Shipping mode is what drives lateness (chi-square p < 0.001, Cramér's V 0.48). First Class is promised in 1 day and always takes 2. Second Class is promised in 2 and takes anywhere from 2 to 6.
- Geography doesn't explain it. Market (p = 0.53), region (p = 0.10) and India tier (p = 0.53) show no real difference. Indian metros were actually 1.4 points worse than Tier 2/3 cities, which isn't significant either. Every tier shows the same pattern by mode.
- Standard Class has the best on-time rate but the biggest share of the cost (41%), because it carries most of the volume.
- The monthly trend is flat (41.3% to 45.0%), so this isn't seasonal.

## Recommendation

Full write-up: [reports/recommendation.md](reports/recommendation.md)

| Scenario (12 months) | On-time | Saving |
|---|---:|---:|
| Today | 42.7% | |
| Change the First Class promise from 1 to 2 days | 58.0% | Rs 5.7 L |
| Move 30% of Second Class volume to Standard | 45.1% | Rs 1.2 L |
| Both | 60.3% | Rs 6.9 L |

I'd also renegotiate the Second Class transit SLA (3 days max, with a penalty per late order). I wouldn't spend money on a Tier 2/3-specific programme, since the tier difference isn't real.

## Dashboard

Live on Tableau Public: [Delivery Performance](https://public.tableau.com/app/profile/deepti.singh.kushwaha/viz/DeliveryPerformance_17945713159400/ExecutiveOverview). The workbook is also in the repo at [tableau/Delivery Performance.twbx](tableau/Delivery%20Performance.twbx). It has three dashboards:

- Executive Overview: KPIs, on-time by mode (click a bar to filter the rest), monthly trend, mode x market heatmap and a "how late" distribution
- India Lens: a city map, Metro vs Tier 2 vs Tier 3, and a tier x mode heatmap
- Cost Simulator: sliders for the cost assumptions, the volume shift and the target. The cost, projected on-time rate and saving update as you move them.

![Executive overview](reports/dashboard_overview.jpg)

![India lens](reports/dashboard_india.jpg)

![Cost simulator](reports/dashboard_cost.jpg)

## Running it

1. Create a PostgreSQL database called `delivery_sla`.
2. Copy the DataCo CSV to `C:\Users\Public\dataco.csv`. The PostgreSQL service on Windows can't read from my Downloads folder, but it can read from Public.
3. Run `run_all.bat`. It runs `sql/01` to `08` in order and writes the CSVs to `exports/`.
4. Optional: `py python/stat_tests.py` (needs pandas, scipy and statsmodels).

## Limitations

- The data looks simulated, so I'd want to check this against real carrier scan data before acting on it.
- Shipping mode stands in for carrier.
- The cost inputs are my assumptions. A real ops team would plug in their actual carrying cost and contact-centre numbers.

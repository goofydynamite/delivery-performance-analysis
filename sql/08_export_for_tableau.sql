-- 08_export_for_tableau.sql
-- CSV exports for Tableau Public (it can't connect to Postgres directly).
-- Run from the project folder with psql:
--   psql -h 127.0.0.1 -U postgres -d delivery_sla -f sql/08_export_for_tableau.sql

-- one row per delivered order, with cost
\copy (SELECT order_id, order_ts, order_month, shipping_mode, promised_days, actual_days, delay_days, is_late, order_status, market, order_region, order_country, order_state, order_city, customer_segment, india_tier, items, units, order_value_usd, order_profit_usd, holding_cost_inr, broken_promise_cost_inr, total_late_cost_inr, in_last_12m FROM v_order_cost ORDER BY order_id) TO 'exports/orders.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

-- item level, for category analysis
\copy (SELECT order_id, order_item_id, order_month, shipping_mode, category_name, department_name, product_name, quantity, order_item_total, is_late, delay_days FROM deliveries WHERE is_cancelled = 0 ORDER BY order_item_id) TO 'exports/order_items.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

-- summaries, used to check the Tableau numbers
\copy (SELECT * FROM v_ontime_by_dimension ORDER BY dimension, worst_rank) TO 'exports/ontime_by_dimension.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM v_monthly_trend ORDER BY order_month) TO 'exports/monthly_trend.csv' WITH (FORMAT csv, HEADER true)

-- last 12 months with readable column names, used by the Tableau workbook
\copy (SELECT order_id AS "Order ID", order_month AS "Order Month", shipping_mode AS "Shipping Mode", promised_days AS "Promised Days", actual_days AS "Actual Days", delay_days AS "Delay Days", is_late AS "Is Late", market AS "Market", order_region AS "Order Region", order_country AS "Order Country", order_city AS "Order City", COALESCE(india_tier, 'Outside India') AS "India Tier", order_value_usd AS "Order Value USD", holding_cost_inr AS "Holding Cost INR", total_late_cost_inr AS "Late Cost INR" FROM v_order_cost WHERE in_last_12m ORDER BY order_id) TO 'exports/tableau_orders_12m.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy (SELECT CASE WHEN scenario LIKE 'Baseline%' THEN '1. Baseline' WHEN scenario LIKE 'A:%' THEN '2. First Class promise 1 to 2 days' WHEN scenario LIKE 'B:%' THEN '3. Shift 30% Second Class to Standard' ELSE '4. Both actions' END AS "Scenario", ontime_pct / 100.0 AS "On-time Rate", cost_lakh AS "Late Cost Lakh", COALESCE(saving_lakh, 0) AS "Saving Lakh" FROM v_scenarios) TO 'exports/tableau_scenarios.csv' WITH (FORMAT csv, HEADER true)

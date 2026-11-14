-- 06_cost_impact.sql
-- Cost of late deliveries.
--   1) Holding cost (the brief's method): delay_days x order value x annual carrying rate / 365
--   2) Broken-promise cost: a flat cost per late order for support contacts, goodwill vouchers
--      and cancellations/RTO caused by missing the promised date.
-- All inputs are ASSUMPTIONS kept in one place (cost_params) so they are easy to change.
-- "Annual" figures use the latest 12 full months in the data: Feb 2017 - Jan 2018.

DROP TABLE IF EXISTS cost_params CASCADE;
CREATE TABLE cost_params AS
SELECT
  0.25::NUMERIC  AS carrying_rate_annual,      -- 25% inventory carrying cost per year (typical textbook range 20-30%)
  85::NUMERIC    AS usd_to_inr,                -- assumed FX rate; update to the current rate before publishing
  150::NUMERIC   AS broken_promise_cost_inr,   -- assumed cost per late order (support + voucher + share of RTO)
  DATE '2017-02-01' AS window_start,
  DATE '2018-01-31' AS window_end;

-- Cost per delivered order
DROP VIEW IF EXISTS v_order_cost CASCADE;
CREATE VIEW v_order_cost AS
SELECT
  o.*,
  ROUND(o.delay_days * o.order_value_usd * p.carrying_rate_annual / 365 * p.usd_to_inr, 2) AS holding_cost_inr,
  CASE WHEN o.is_late = 1 THEN p.broken_promise_cost_inr ELSE 0 END                        AS broken_promise_cost_inr,
  ROUND(o.delay_days * o.order_value_usd * p.carrying_rate_annual / 365 * p.usd_to_inr, 2)
    + CASE WHEN o.is_late = 1 THEN p.broken_promise_cost_inr ELSE 0 END                     AS total_late_cost_inr,
  (o.order_month BETWEEN p.window_start AND p.window_end)                                   AS in_last_12m
FROM v_orders o
CROSS JOIN cost_params p
WHERE o.is_cancelled = 0;

-- 1) Last-12-month cost by shipping mode (the business-case table)
SELECT
  shipping_mode,
  COUNT(*)                                                  AS orders,
  SUM(is_late)                                              AS late_orders,
  ROUND(100.0 * (1 - AVG(is_late)), 1)                      AS ontime_pct,
  SUM(delay_days)                                           AS delay_days,
  ROUND(SUM(holding_cost_inr) / 1e5, 2)                     AS holding_cost_lakh,
  ROUND(SUM(broken_promise_cost_inr) / 1e5, 2)              AS broken_promise_lakh,
  ROUND(SUM(total_late_cost_inr) / 1e5, 2)                  AS total_cost_lakh,
  ROUND(100.0 * SUM(total_late_cost_inr) / SUM(SUM(total_late_cost_inr)) OVER (), 1) AS share_of_cost_pct
FROM v_order_cost
WHERE in_last_12m
GROUP BY shipping_mode
ORDER BY total_cost_lakh DESC;

-- 2) Network total, last 12 months
SELECT
  COUNT(*)                                       AS orders,
  SUM(c.is_late)                                 AS late_orders,
  ROUND(100.0 * (1 - AVG(c.is_late)), 1)         AS ontime_pct,
  ROUND(SUM(c.holding_cost_inr) / 1e5, 2)        AS holding_cost_lakh,
  ROUND(SUM(c.broken_promise_cost_inr) / 1e5, 2) AS broken_promise_lakh,
  ROUND(SUM(c.total_late_cost_inr) / 1e5, 2)     AS total_cost_lakh,
  ROUND(SUM(c.order_value_usd) * MIN(p.usd_to_inr) / 1e7, 2) AS revenue_crore,
  ROUND(100.0 * SUM(c.total_late_cost_inr)
        / (SUM(c.order_value_usd) * MIN(p.usd_to_inr)), 3)  AS cost_pct_of_revenue
FROM v_order_cost c CROSS JOIN cost_params p
WHERE c.in_last_12m;

-- 3) India tier cost, full period (India volume is too small to split by 12 months)
SELECT
  india_tier,
  COUNT(*)                                 AS orders,
  SUM(is_late)                             AS late_orders,
  ROUND(100.0 * (1 - AVG(is_late)), 1)     AS ontime_pct,
  ROUND(SUM(total_late_cost_inr) / 1e5, 2) AS total_cost_lakh,
  ROUND(AVG(total_late_cost_inr), 0)       AS cost_per_order_inr
FROM v_order_cost
WHERE india_tier IS NOT NULL
GROUP BY india_tier
ORDER BY ontime_pct;

-- 4) Scenarios (last 12 months)
--   A: Re-baseline First Class promise from 1 day to 2 days (it ALWAYS takes 2 days)
--   B: Shift 30% of Second Class volume to Standard Class (late rate of Standard applied)
--   C: A + B together
DROP VIEW IF EXISTS v_scenarios CASCADE;
CREATE VIEW v_scenarios AS
WITH base AS (
  SELECT shipping_mode,
         COUNT(*)                   AS orders,
         SUM(is_late)               AS late_orders,
         AVG(is_late)               AS late_rate,
         AVG(total_late_cost_inr) FILTER (WHERE is_late = 1) AS cost_per_late_order,
         SUM(total_late_cost_inr)   AS cost
  FROM v_order_cost
  WHERE in_last_12m
  GROUP BY shipping_mode
),
totals AS (
  SELECT SUM(late_orders) AS late_orders, SUM(cost) AS cost, SUM(orders) AS orders FROM base
),
fc AS (SELECT * FROM base WHERE shipping_mode = 'First Class'),
sc AS (SELECT * FROM base WHERE shipping_mode = 'Second Class'),
st AS (SELECT * FROM base WHERE shipping_mode = 'Standard Class'),
scenario_a AS (
  -- With a 2-day promise every First Class order is on time: all its late orders and cost disappear
  SELECT fc.late_orders AS late_saved, fc.cost AS cost_saved FROM fc
),
scenario_b AS (
  SELECT
    0.30 * sc.orders * (sc.late_rate - st.late_rate) AS late_saved,
    0.30 * sc.orders * (sc.late_rate * sc.cost_per_late_order
                        - st.late_rate * st.cost_per_late_order) AS cost_saved
  FROM sc, st
)
SELECT 'Baseline (last 12 months)' AS scenario,
       t.late_orders::NUMERIC AS late_orders,
       ROUND(100.0 * (1 - t.late_orders::NUMERIC / t.orders), 1) AS ontime_pct,
       ROUND(t.cost / 1e5, 2) AS cost_lakh,
       NULL::NUMERIC AS saving_lakh
FROM totals t
UNION ALL
SELECT 'A: First Class promise 1 -> 2 days',
       t.late_orders - a.late_saved,
       ROUND(100.0 * (1 - (t.late_orders - a.late_saved) / t.orders), 1),
       ROUND((t.cost - a.cost_saved) / 1e5, 2),
       ROUND(a.cost_saved / 1e5, 2)
FROM totals t, scenario_a a
UNION ALL
SELECT 'B: Shift 30% of Second Class to Standard',
       ROUND(t.late_orders - b.late_saved),
       ROUND(100.0 * (1 - (t.late_orders - b.late_saved) / t.orders), 1),
       ROUND((t.cost - b.cost_saved) / 1e5, 2),
       ROUND(b.cost_saved / 1e5, 2)
FROM totals t, scenario_b b
UNION ALL
SELECT 'C: A + B',
       ROUND(t.late_orders - a.late_saved - b.late_saved),
       ROUND(100.0 * (1 - (t.late_orders - a.late_saved - b.late_saved) / t.orders), 1),
       ROUND((t.cost - a.cost_saved - b.cost_saved) / 1e5, 2),
       ROUND((a.cost_saved + b.cost_saved) / 1e5, 2)
FROM totals t, scenario_a a, scenario_b b;

SELECT * FROM v_scenarios;

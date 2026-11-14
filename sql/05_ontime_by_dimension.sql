-- 05_ontime_by_dimension.sql
-- On-time delivery rate by dimension, ranked worst -> best, against a 95% target.
-- Order grain, cancelled orders excluded. Groups with < 30 orders are dropped (too small to judge).

-- Reusable summary: one row per (dimension, value)
DROP VIEW IF EXISTS v_ontime_by_dimension CASCADE;
CREATE VIEW v_ontime_by_dimension AS
WITH delivered AS (
  SELECT * FROM v_orders WHERE is_cancelled = 0
),
long_format AS (
  SELECT 'Shipping mode'    AS dimension, shipping_mode    AS value, is_late, delay_days, order_value_usd FROM delivered
  UNION ALL
  SELECT 'Market',           market,           is_late, delay_days, order_value_usd FROM delivered
  UNION ALL
  SELECT 'Order region',     order_region,     is_late, delay_days, order_value_usd FROM delivered
  UNION ALL
  SELECT 'Customer segment', customer_segment, is_late, delay_days, order_value_usd FROM delivered
  UNION ALL
  SELECT 'India tier',       india_tier,       is_late, delay_days, order_value_usd FROM delivered
  WHERE india_tier IS NOT NULL
)
SELECT
  dimension,
  value,
  COUNT(*)                                                        AS orders,
  SUM(is_late)                                                    AS late_orders,
  ROUND(100.0 * (1 - AVG(is_late)), 1)                            AS ontime_pct,
  ROUND(100.0 * (1 - AVG(is_late)) - 95, 1)                       AS gap_to_95_target_pp,
  ROUND(AVG(delay_days) FILTER (WHERE is_late = 1), 2)            AS avg_delay_days_when_late,
  SUM(delay_days)                                                 AS total_delay_days,
  RANK() OVER (PARTITION BY dimension ORDER BY AVG(is_late) DESC) AS worst_rank
FROM long_format
GROUP BY dimension, value
HAVING COUNT(*) >= 30;

-- 1) Shipping mode (DataCo's equivalent of "carrier service level")
SELECT value AS shipping_mode, orders, late_orders, ontime_pct, gap_to_95_target_pp,
       avg_delay_days_when_late, worst_rank
FROM v_ontime_by_dimension WHERE dimension = 'Shipping mode' ORDER BY worst_rank;

-- 2) Market
SELECT value AS market, orders, late_orders, ontime_pct, gap_to_95_target_pp, worst_rank
FROM v_ontime_by_dimension WHERE dimension = 'Market' ORDER BY worst_rank;

-- 3) Order region (worst 5 and best 5 shown by rank)
SELECT value AS order_region, orders, ontime_pct, gap_to_95_target_pp, worst_rank
FROM v_ontime_by_dimension WHERE dimension = 'Order region' ORDER BY worst_rank;

-- 4) India: Metro vs Tier 2 vs Tier 3
SELECT value AS india_tier, orders, late_orders, ontime_pct, gap_to_95_target_pp,
       avg_delay_days_when_late, worst_rank
FROM v_ontime_by_dimension WHERE dimension = 'India tier' ORDER BY worst_rank;

-- 5) India tier x shipping mode: is a mode bad everywhere or only in Tier 2/3?
SELECT india_tier, shipping_mode,
       COUNT(*)                              AS orders,
       ROUND(100.0 * (1 - AVG(is_late)), 1)  AS ontime_pct
FROM v_orders
WHERE is_cancelled = 0 AND india_tier IS NOT NULL
GROUP BY india_tier, shipping_mode
ORDER BY shipping_mode, india_tier;

-- 6) Product category (item grain: an order can contain several categories;
--    each item inherits its order's late flag)
SELECT category_name,
       COUNT(DISTINCT order_id)                                AS orders,
       COUNT(*)                                                AS items,
       ROUND(100.0 * (1 - AVG(is_late)), 1)                    AS ontime_pct_items,
       RANK() OVER (ORDER BY AVG(is_late) DESC)                AS worst_rank
FROM deliveries
WHERE is_cancelled = 0
GROUP BY category_name
HAVING COUNT(DISTINCT order_id) >= 30
ORDER BY worst_rank;

-- 7) Cancellations (SUSPECTED_FRAUD + CANCELED order statuses) by shipping mode
SELECT shipping_mode,
       COUNT(*)                                    AS orders,
       SUM(is_cancelled)                           AS cancelled_orders,
       ROUND(100.0 * AVG(is_cancelled), 1)         AS cancel_rate_pct
FROM v_orders
GROUP BY shipping_mode
ORDER BY cancel_rate_pct DESC;

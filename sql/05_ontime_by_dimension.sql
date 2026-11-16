-- 05_ontime_by_dimension.sql
-- On-time rate by dimension, worst first, compared with a 95% target.
-- Per order, cancelled orders left out. Groups under 30 orders are dropped.

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

-- shipping mode (no carrier column in DataCo, so this is the closest thing)
SELECT value AS shipping_mode, orders, late_orders, ontime_pct, gap_to_95_target_pp,
       avg_delay_days_when_late, worst_rank
FROM v_ontime_by_dimension WHERE dimension = 'Shipping mode' ORDER BY worst_rank;

-- market
SELECT value AS market, orders, late_orders, ontime_pct, gap_to_95_target_pp, worst_rank
FROM v_ontime_by_dimension WHERE dimension = 'Market' ORDER BY worst_rank;

-- order region
SELECT value AS order_region, orders, ontime_pct, gap_to_95_target_pp, worst_rank
FROM v_ontime_by_dimension WHERE dimension = 'Order region' ORDER BY worst_rank;

-- India: metro vs tier 2 vs tier 3
SELECT value AS india_tier, orders, late_orders, ontime_pct, gap_to_95_target_pp,
       avg_delay_days_when_late, worst_rank
FROM v_ontime_by_dimension WHERE dimension = 'India tier' ORDER BY worst_rank;

-- is a mode bad everywhere, or only in smaller cities?
SELECT india_tier, shipping_mode,
       COUNT(*)                              AS orders,
       ROUND(100.0 * (1 - AVG(is_late)), 1)  AS ontime_pct
FROM v_orders
WHERE is_cancelled = 0 AND india_tier IS NOT NULL
GROUP BY india_tier, shipping_mode
ORDER BY shipping_mode, india_tier;

-- product category (counted per item, since one order can have several categories)
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

-- cancellations (SUSPECTED_FRAUD + CANCELED) by mode
SELECT shipping_mode,
       COUNT(*)                                    AS orders,
       SUM(is_cancelled)                           AS cancelled_orders,
       ROUND(100.0 * AVG(is_cancelled), 1)         AS cancel_rate_pct
FROM v_orders
GROUP BY shipping_mode
ORDER BY cancel_rate_pct DESC;

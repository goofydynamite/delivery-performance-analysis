-- 04_orders_view.sql
-- One row per ORDER. All items in an order share shipping mode, dates and the late flag
-- (verified below), so SLA metrics are counted per order; otherwise big orders count twice.

-- Check: should return 0 (no order has conflicting delivery attributes)
SELECT COUNT(*) AS conflicting_orders
FROM (
  SELECT order_id
  FROM deliveries
  GROUP BY order_id
  HAVING COUNT(DISTINCT shipping_mode) > 1
      OR COUNT(DISTINCT actual_days)   > 1
      OR COUNT(DISTINCT is_late)       > 1
) x;

DROP VIEW IF EXISTS v_orders CASCADE;
CREATE VIEW v_orders AS
SELECT
  d.order_id,
  MIN(d.order_ts)          AS order_ts,
  MIN(d.order_month)       AS order_month,
  MIN(d.shipping_mode)     AS shipping_mode,
  MIN(d.promised_days)     AS promised_days,
  MIN(d.actual_days)       AS actual_days,
  MIN(d.delay_days)        AS delay_days,
  MAX(d.is_late)           AS is_late,
  MAX(d.is_cancelled)      AS is_cancelled,
  MIN(d.order_status)      AS order_status,
  MIN(d.market)            AS market,
  MIN(d.order_region)      AS order_region,
  MIN(d.order_country)     AS order_country,
  MIN(d.order_state)       AS order_state,
  MIN(d.order_city)        AS order_city,
  MIN(d.customer_segment)  AS customer_segment,
  CASE WHEN MIN(d.order_country) = 'India'
       THEN COALESCE(MIN(t.tier), 'Tier 3') END AS india_tier,
  COUNT(*)                 AS items,
  SUM(d.quantity)          AS units,
  ROUND(SUM(d.order_item_total), 2) AS order_value_usd,
  ROUND(SUM(d.profit), 2)  AS order_profit_usd
FROM deliveries d
LEFT JOIN india_city_tier t ON d.order_city = t.city
GROUP BY d.order_id;

-- Checks: 65752 orders | 62897 delivered (not cancelled) | 42.7% on-time
SELECT COUNT(*)                                                   AS orders,
       COUNT(*) FILTER (WHERE is_cancelled = 0)                   AS delivered_orders,
       ROUND(100.0 * (1 - AVG(is_late) FILTER (WHERE is_cancelled = 0)), 1) AS ontime_pct
FROM v_orders;

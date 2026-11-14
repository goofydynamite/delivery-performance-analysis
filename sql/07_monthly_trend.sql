-- 07_monthly_trend.sql
-- Monthly on-time trend with a 3-month rolling average and month-over-month change.
-- Note: from Oct 2017 item rows roughly halve but ORDER counts rise slightly
-- (orders become single-item). Counting per order keeps the trend comparable.

DROP VIEW IF EXISTS v_monthly_trend CASCADE;
CREATE VIEW v_monthly_trend AS
WITH monthly AS (
  SELECT
    order_month,
    COUNT(*)                              AS orders,
    SUM(is_late)                          AS late_orders,
    100.0 * (1 - AVG(is_late))            AS ontime_pct,
    SUM(total_late_cost_inr)              AS late_cost_inr
  FROM v_order_cost
  GROUP BY order_month
)
SELECT
  order_month,
  orders,
  late_orders,
  ROUND(ontime_pct, 1)                                                          AS ontime_pct,
  ROUND(AVG(ontime_pct) OVER (ORDER BY order_month
                              ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 1)     AS ontime_pct_3m_avg,
  ROUND(ontime_pct - LAG(ontime_pct) OVER (ORDER BY order_month), 1)            AS mom_change_pp,
  ROUND(late_cost_inr / 1e5, 2)                                                 AS late_cost_lakh
FROM monthly;

-- Latest 12 full months (Feb 2017 - Jan 2018)
SELECT * FROM v_monthly_trend
WHERE order_month BETWEEN DATE '2017-02-01' AND DATE '2018-01-01'
ORDER BY order_month;

-- Spread over those 12 months: is there a real trend?
SELECT MIN(ontime_pct) AS worst_month_pct,
       MAX(ontime_pct) AS best_month_pct,
       ROUND(MAX(ontime_pct) - MIN(ontime_pct), 1) AS range_pp
FROM v_monthly_trend
WHERE order_month BETWEEN DATE '2017-02-01' AND DATE '2018-01-01';

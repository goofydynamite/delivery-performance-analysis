-- 02_clean.sql
-- Cleaned and typed version of raw_dataco. One row per order item (180,519 rows).
-- On time = actual_days <= promised_days. Cancelled orders don't count as late.

DROP TABLE IF EXISTS deliveries CASCADE;

CREATE TABLE deliveries AS
WITH base AS (
  SELECT
    -- dates in the file are US format (M/D/YYYY)
    order_id::INT                                                AS order_id,
    order_item_id::INT                                           AS order_item_id,
    TO_TIMESTAMP(order_date,    'MM/DD/YYYY HH24:MI')::TIMESTAMP AS order_ts,
    TO_TIMESTAMP(shipping_date, 'MM/DD/YYYY HH24:MI')::TIMESTAMP AS ship_ts,

    -- delivery info
    shipping_mode,
    days_for_shipment_scheduled::INT AS promised_days,
    days_for_shipping_real::INT      AS actual_days,
    delivery_status,
    order_status,
    type AS payment_type,

    -- some names have trailing/double spaces, e.g. 'South of  USA '
    market,
    REGEXP_REPLACE(TRIM(order_region), '\s+', ' ', 'g') AS order_region,
    order_country,
    order_state,
    order_city,

    -- customer + product
    customer_segment,
    REGEXP_REPLACE(TRIM(category_name), '\s+', ' ', 'g') AS category_name,
    TRIM(department_name)                                AS department_name,
    REGEXP_REPLACE(TRIM(product_name), '\s+', ' ', 'g')  AS product_name,

    -- money (USD)
    order_item_quantity::INT          AS quantity,
    sales::NUMERIC                    AS sales,
    order_item_discount_rate::NUMERIC AS discount_rate,
    order_item_total::NUMERIC         AS order_item_total,
    order_profit_per_order::NUMERIC   AS profit
  FROM raw_dataco
  -- Left out: masked customer email/password/name/street, product_description (empty),
  -- product_image, order_zipcode (86% empty), product_status (always 0) and
  -- 6 columns that are exact copies of other columns.
)
SELECT *,
  GREATEST(actual_days - promised_days, 0)                          AS delay_days,
  CASE WHEN delivery_status = 'Shipping canceled' THEN 1 ELSE 0 END AS is_cancelled,
  CASE WHEN delivery_status <> 'Shipping canceled'
        AND actual_days > promised_days THEN 1 ELSE 0 END           AS is_late,
  DATE_TRUNC('month', order_ts)::DATE                               AS order_month
FROM base;

-- expect 180519 | 7754 | 98977 | 160163
SELECT COUNT(*)                                        AS total_rows,
       SUM(is_cancelled)                               AS cancelled,
       SUM(is_late)                                    AS late,
       SUM(delay_days) FILTER (WHERE is_cancelled = 0) AS total_delay_days
FROM deliveries;

-- 01_load.sql
-- Raw table, every column as text so a bad value can't break the load. Types get fixed in 02.
DROP TABLE IF EXISTS raw_dataco CASCADE;

CREATE TABLE raw_dataco (
  type TEXT, days_for_shipping_real TEXT, days_for_shipment_scheduled TEXT,
  benefit_per_order TEXT, sales_per_customer TEXT, delivery_status TEXT,
  late_delivery_risk TEXT, category_id TEXT, category_name TEXT,
  customer_city TEXT, customer_country TEXT, customer_email TEXT,
  customer_fname TEXT, customer_id TEXT, customer_lname TEXT,
  customer_password TEXT, customer_segment TEXT, customer_state TEXT,
  customer_street TEXT, customer_zipcode TEXT, department_id TEXT,
  department_name TEXT, latitude TEXT, longitude TEXT, market TEXT,
  order_city TEXT, order_country TEXT, order_customer_id TEXT,
  order_date TEXT, order_id TEXT, order_item_cardprod_id TEXT,
  order_item_discount TEXT, order_item_discount_rate TEXT, order_item_id TEXT,
  order_item_product_price TEXT, order_item_profit_ratio TEXT,
  order_item_quantity TEXT, sales TEXT, order_item_total TEXT,
  order_profit_per_order TEXT, order_region TEXT, order_state TEXT,
  order_status TEXT, order_zipcode TEXT, product_card_id TEXT,
  product_category_id TEXT, product_description TEXT, product_image TEXT,
  product_name TEXT, product_price TEXT, product_status TEXT,
  shipping_date TEXT, shipping_mode TEXT
);

-- The Postgres service can't read my Downloads folder, so the CSV is copied to C:\Users\Public first
TRUNCATE raw_dataco;

COPY raw_dataco
FROM 'C:/Users/Public/dataco.csv'
WITH (FORMAT csv, HEADER true, ENCODING 'LATIN1');

-- should be 180519
SELECT COUNT(*) FROM raw_dataco;

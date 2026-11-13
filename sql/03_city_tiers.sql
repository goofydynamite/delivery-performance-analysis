-- 03_city_tiers.sql
-- India city tier lookup, based on the Government of India HRA city classification
-- (X cities = Metro, Y cities = Tier 2, all other cities = Tier 3).
-- Spellings match the dataset (e.g. 'Dehra Dun', 'Nasik', 'Allahabad').
-- Kolkata and Ahmedabad (X cities) do not appear in the India orders.

DROP TABLE IF EXISTS india_city_tier CASCADE;
CREATE TABLE india_city_tier (city TEXT PRIMARY KEY, tier TEXT NOT NULL);

INSERT INTO india_city_tier (city, tier)
SELECT city, 'Metro' FROM unnest(ARRAY[
  'Delhi','New Delhi','Mumbai','Bangalore','Chennai','Hyderabad','Pune'
]) AS city
UNION ALL
SELECT city, 'Tier 2' FROM unnest(ARRAY[
  'Agra','Ajmer','Aligarh','Allahabad','Amravati','Amritsar','Asansol','Aurangabad',
  'Bareilly','Belgaum','Bhavnagar','Bhilai','Bhiwandi','Bhopal','Bhubaneswar','Bijapur',
  'Bikaner','Bilaspur','Bokaro','Chandigarh','Coimbatore','Cuttack','Dehra Dun','Durgapur',
  'Faridabad','Firozabad','Ghaziabad','Gorakhpur','Gulbarga','Guntur','Guwahati','Gwalior',
  'Hubli','Indore','Jabalpur','Jaipur','Jammu','Jamnagar','Jamshedpur','Jhansi','Jodhpur',
  'Kakinada','Kanpur','Kochi','Kolhapur','Kollam','Kota','Kozhikode','Lucknow','Ludhiana',
  'Madurai','Mangalore','Mathura','Meerut','Moradabad','Mysore','Nagpur','Nasik','Nellore',
  'Patna','Puducherry','Raipur','Rajkot','Ranchi','Salem','Sangli','Solapur','Srinagar',
  'Surat','Thiruvananthapuram','Tiruchchirappalli','Tiruppur','Ujjain','Vadodara',
  'Varanasi','Vijayawada','Visakhapatnam','Warangal'
]) AS city;

-- Check (non-cancelled India orders): Tier 2 = 1263, Tier 3 = 427, Metro = 380
SELECT COALESCE(t.tier, 'Tier 3') AS tier,
       COUNT(DISTINCT d.order_id) AS orders
FROM deliveries d
LEFT JOIN india_city_tier t ON d.order_city = t.city
WHERE d.order_country = 'India' AND d.is_cancelled = 0
GROUP BY 1
ORDER BY 2 DESC;

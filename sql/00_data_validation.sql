-- 1. Row counts

SELECT 'customers' AS table_name, COUNT(*) FROM customers
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL
SELECT 'order_payments', COUNT(*) FROM order_payments
UNION ALL
SELECT 'order_reviews', COUNT(*) FROM order_reviews
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'sellers', COUNT(*) FROM sellers;


-- 2. Duplicate key checks

SELECT
    COUNT(*) - COUNT(DISTINCT order_id) AS duplicate_orders
FROM orders;

SELECT
    COUNT(*) - COUNT(DISTINCT customer_id) AS duplicate_customers
FROM customers;

SELECT
    COUNT(*) - COUNT(DISTINCT (order_id, order_item_id)) AS duplicate_order_items
FROM order_items;


-- 3. Missing values and order status

SELECT
    COUNT(*) FILTER (WHERE customer_id IS NULL) AS missing_customer_id,
    COUNT(*) FILTER (WHERE order_purchase_timestamp IS NULL) AS missing_purchase_date,
    COUNT(*) FILTER (WHERE order_delivered_customer_date IS NULL) AS missing_delivery_date
FROM orders;

SELECT
    order_status,
    COUNT(*) AS total_orders
FROM orders
GROUP BY
    order_status
ORDER BY
    total_orders DESC;


-- 4. Customer identity / table grain

SELECT
    COUNT(DISTINCT customer_id) AS customer_ids,
    COUNT(DISTINCT customer_unique_id) AS unique_customers
FROM customers;

SELECT
    MAX(item_count) AS max_items_per_order
FROM (
    SELECT
        order_id,
        COUNT(*) AS item_count
    FROM order_items
    GROUP BY
        order_id
) AS item_counts;


-- VALIDATON NOTES --
-- Primary and composite key checks returned no duplicates.
-- 2,965 orders have no customer delivery timestamp, mostly due to non-delivered order statuses.
-- customer_unique_id should be used for repeat-customer analysis.
-- Orders can contain multiple items and multiple payments, so joins must respect table grain to avoid double counting.

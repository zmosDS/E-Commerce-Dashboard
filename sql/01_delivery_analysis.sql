-- Late vs On-time deliveries by month

WITH delivery_rate AS 
(
SELECT 
    order_id,
    order_delivered_customer_date,  
    order_estimated_delivery_date,
    order_purchase_timestamp,
CASE
    WHEN (order_delivered_customer_date - order_estimated_delivery_date) >= '1 day' THEN 'late'
    WHEN (order_delivered_customer_date - order_estimated_delivery_date) <= '-1 day' THEN 'early'
    ELSE 'on time'
END AS delivery,
DATE_PART('day', order_delivered_customer_date - order_estimated_delivery_date) AS delivery_diff -- This creates a column for the difference between estimated & delivered
FROM orders
WHERE 
    order_delivered_customer_date IS NOT NULL
)

SELECT 
    TO_CHAR(order_purchase_timestamp, 'YYYY-MM') AS month,
    COUNT(*) AS total_orders,
    COUNT(*) FILTER (WHERE delivery = 'late') AS late_orders,
    COUNT(*) FILTER (WHERE delivery = 'early' OR delivery = 'on time') AS on_time_orders,
    ROUND(COUNT(*) FILTER (WHERE delivery = 'late') * 100.0 / COUNT(*), 1) AS late_pct
FROM delivery_rate
GROUP BY 
    TO_CHAR(order_purchase_timestamp, 'YYYY-MM')
ORDER BY
    TO_CHAR(order_purchase_timestamp, 'YYYY-MM');


-- Average delivery time in days by state

SELECT
    customer_state,
    COUNT(*) AS total_orders,
    ROUND(AVG(DATE_PART('day', order_delivered_customer_date - order_purchase_timestamp))::numeric, 0) AS avg_delivery_time,
    ROUND(AVG(DATE_PART('day', order_delivered_customer_date - order_estimated_delivery_date))::numeric, 0) AS avg_days_vs_estimate, -- negative means arrived early, most arrive early 
    ROUND(COUNT(*) FILTER (WHERE ((order_delivered_customer_date - order_estimated_delivery_date) >= '1 day')) * 100.0 / COUNT(*), 1) AS late_pct
FROM
    orders
INNER JOIN 
    customers ON orders.customer_id = customers.customer_id -- inner join for orders in both tables only
WHERE 
    order_delivered_customer_date IS NOT NULL
GROUP BY
    customer_state
ORDER BY
    avg_delivery_time DESC;


-- For late orders, how late were they and does freight cost correlate with lateness

SELECT
    COUNT(*) AS total_orders,
    ROUND(AVG(freight_value)::numeric, 2) AS avg_freight_cost,
CASE 
    WHEN DATE_PART('day', order_delivered_customer_date - order_estimated_delivery_date) < 1 THEN 'on time or early' 
    WHEN DATE_PART('day', order_delivered_customer_date - order_estimated_delivery_date) BETWEEN 1 AND 3 THEN '1-3 days late'
    WHEN DATE_PART('day', order_delivered_customer_date - order_estimated_delivery_date) BETWEEN 4 AND 7 THEN '4-7 days late'
    WHEN DATE_PART('day', order_delivered_customer_date - order_estimated_delivery_date) > 7 THEN '7+ days late'
END AS lateness_bucket
FROM orders 
JOIN order_items ON orders.order_id = order_items.order_id
WHERE
    order_delivered_customer_date IS NOT NULL
GROUP BY
    lateness_bucket
ORDER BY 
    avg_freight_cost ASC;
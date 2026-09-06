-- Olist E-Commerce Delivery Analysis

-- 1. How is delivery performance changing over time?

WITH delivery_rate AS (
    SELECT 
        order_id,
        order_purchase_timestamp,
        CASE
            WHEN order_delivered_customer_date - order_estimated_delivery_date >= '1 day' THEN 'late'
            WHEN order_delivered_customer_date - order_estimated_delivery_date <= '-1 day' THEN 'early'
            ELSE 'on time'
        END AS delivery
    FROM orders
    WHERE
        order_delivered_customer_date IS NOT NULL
)

SELECT 
    TO_CHAR(order_purchase_timestamp, 'YYYY-MM') AS month,
    COUNT(*) AS total_orders,
    COUNT(*) FILTER (WHERE delivery = 'late') AS late_orders,
    COUNT(*) FILTER (WHERE delivery <> 'late') AS on_time_or_early_orders,
    ROUND(
        COUNT(*) FILTER (WHERE delivery = 'late') * 100.0 / COUNT(*),
        1
    ) AS late_pct
FROM delivery_rate
GROUP BY
    TO_CHAR(order_purchase_timestamp, 'YYYY-MM')
ORDER BY
    month;


-- 2. Which customer states have the weakest delivery performance?

SELECT
    c.customer_state,
    COUNT(*) AS total_orders,
    ROUND(
        AVG(DATE_PART('day', o.order_delivered_customer_date - o.order_purchase_timestamp))::numeric, 1) AS avg_delivery_days,
    ROUND(
        AVG(DATE_PART('day', o.order_delivered_customer_date - o.order_estimated_delivery_date))::numeric, 1) AS avg_days_vs_estimate,
    ROUND(
        COUNT(*) FILTER (WHERE o.order_delivered_customer_date - o.order_estimated_delivery_date >= '1 day') * 100.0 / COUNT(*), 1) AS late_pct
FROM orders o
JOIN customers c
    ON o.customer_id = c.customer_id
WHERE
    o.order_delivered_customer_date IS NOT NULL
GROUP BY
    c.customer_state
ORDER BY
    late_pct DESC;


-- 3. How severe are late deliveries, and how do order characteristics differ by lateness?

-- Aggregate order_items to one row per order before comparing averages to avoid double counting multi-item orders.

WITH order_summary AS (
    SELECT
        o.order_id,
        DATE_PART('day', o.order_delivered_customer_date - o.order_estimated_delivery_date
        ) AS days_vs_estimate,
        SUM(oi.price) AS order_value,
        SUM(oi.freight_value) AS freight_value,
        COUNT(*) AS item_count
    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
    WHERE
        o.order_delivered_customer_date IS NOT NULL
    GROUP BY
        o.order_id,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date
),

lateness_groups AS (
    SELECT
        *,
        CASE
            WHEN days_vs_estimate < 1 THEN 'on time or early'
            WHEN days_vs_estimate BETWEEN 1 AND 3 THEN '1-3 days late'
            WHEN days_vs_estimate BETWEEN 4 AND 7 THEN '4-7 days late'
            ELSE '8+ days late'
        END AS lateness_bucket,
        CASE
            WHEN days_vs_estimate < 1 THEN 1
            WHEN days_vs_estimate BETWEEN 1 AND 3 THEN 2
            WHEN days_vs_estimate BETWEEN 4 AND 7 THEN 3
            ELSE 4
        END AS lateness_order
    FROM order_summary
)

SELECT
    lateness_bucket,
    COUNT(*) AS total_orders,
    ROUND(AVG(days_vs_estimate)::numeric, 1) AS avg_days_vs_estimate,
    ROUND(AVG(order_value)::numeric, 2) AS avg_order_value,
    ROUND(AVG(freight_value)::numeric, 2) AS avg_freight_value,
    ROUND(AVG(item_count)::numeric, 1) AS avg_items_per_order
FROM lateness_groups
GROUP BY
    lateness_bucket,
    lateness_order
ORDER BY
    lateness_order;


-- 4. Which high-volume sellers contribute most to late deliveries?

WITH seller_delivery AS (
    SELECT
        oi.seller_id,
        COUNT(DISTINCT o.order_id) AS total_orders,
        COUNT(DISTINCT o.order_id) FILTER (
            WHERE o.order_delivered_customer_date - o.order_estimated_delivery_date >= '1 day') AS late_orders,
        ROUND(
            AVG(DATE_PART('day', o.order_delivered_customer_date - o.order_estimated_delivery_date))::numeric, 1) AS avg_days_vs_estimate,
        SUM(oi.price) AS revenue
    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
    WHERE
        o.order_delivered_customer_date IS NOT NULL
    GROUP BY
        oi.seller_id
)

-- Limit to sellers with at least 25 orders so very low-volume sellers do not distort the ranking.
SELECT
    seller_id,
    total_orders,
    late_orders,
    ROUND(late_orders * 100.0 / total_orders, 1) AS late_pct,
    avg_days_vs_estimate, ROUND(revenue::numeric, 2) AS revenue
FROM seller_delivery
WHERE
    total_orders >= 25
ORDER BY
    late_pct DESC,
    total_orders DESC;


-- 5. How does delivery performance affect customer review scores?

WITH delivery_reviews AS (
    SELECT
        o.order_id,
        r.review_score,
        CASE
            WHEN o.order_delivered_customer_date - o.order_estimated_delivery_date < '1 day'
                THEN 'on time or early'
            WHEN DATE_PART('day', o.order_delivered_customer_date - o.order_estimated_delivery_date
            ) BETWEEN 1 AND 3
                THEN '1-3 days late'
            WHEN DATE_PART('day', o.order_delivered_customer_date - o.order_estimated_delivery_date
            ) BETWEEN 4 AND 7
                THEN '4-7 days late'
            ELSE '8+ days late'
        END AS lateness_bucket,
        CASE
            WHEN o.order_delivered_customer_date - o.order_estimated_delivery_date < '1 day' THEN 1
            WHEN DATE_PART('day', o.order_delivered_customer_date - o.order_estimated_delivery_date
            ) BETWEEN 1 AND 3 THEN 2
            WHEN DATE_PART('day', o.order_delivered_customer_date - o.order_estimated_delivery_date
            ) BETWEEN 4 AND 7 THEN 3
            ELSE 4
        END AS lateness_order
    FROM orders o
    JOIN order_reviews r
        ON o.order_id = r.order_id
    WHERE
        o.order_delivered_customer_date IS NOT NULL
        AND r.review_score IS NOT NULL
)

SELECT
    lateness_bucket,
    COUNT(*) AS total_reviews,
    ROUND(AVG(review_score)::numeric, 2) AS avg_review_score,
    ROUND(
        COUNT(*) FILTER (WHERE review_score <= 2) * 100.0 / COUNT(*), 1) AS low_review_pct,
    ROUND(
        COUNT(*) FILTER (WHERE review_score >= 4) * 100.0 / COUNT(*), 1) AS high_review_pct
FROM delivery_reviews
GROUP BY
    lateness_bucket,
    lateness_order
ORDER BY
    lateness_order;
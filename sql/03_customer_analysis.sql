-- Olist E-Commerce Customer Analysis


-- 1. How many customers are one-time vs repeat customers?

-- customer_unique_id is used to track the same customer across multiple orders.

WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS total_orders
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    WHERE
        o.order_status = 'delivered'
    GROUP BY
        c.customer_unique_id
)

SELECT
    COUNT(*) AS total_customers,
    COUNT(*) FILTER (WHERE total_orders = 1) AS one_time_customers,
    COUNT(*) FILTER (WHERE total_orders > 1) AS repeat_customers,
    ROUND(
        COUNT(*) FILTER (WHERE total_orders > 1) * 100.0 / COUNT(*),
        1
    ) AS repeat_customer_pct,
    ROUND(AVG(total_orders)::numeric, 2) AS avg_orders_per_customer
FROM customer_orders;


-- 2. Are repeat customers more valuable than one-time customers?

WITH customer_value AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM(oi.price) AS total_spend
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    JOIN order_items oi
        ON o.order_id = oi.order_id
    WHERE
        o.order_status = 'delivered'
    GROUP BY
        c.customer_unique_id
)

SELECT
    CASE
        WHEN total_orders = 1 THEN 'one-time customer'
        ELSE 'repeat customer'
    END AS customer_type,
    COUNT(*) AS total_customers,
    ROUND(AVG(total_orders)::numeric, 2) AS avg_orders,
    ROUND(AVG(total_spend)::numeric, 2) AS avg_customer_spend,
    ROUND(
        AVG(total_spend / total_orders)::numeric,
        2
    ) AS avg_order_value
FROM customer_value
GROUP BY
    customer_type
ORDER BY
    avg_customer_spend DESC;


-- 3. What is the historical value of each customer?

SELECT
    c.customer_unique_id,
    MIN(o.order_purchase_timestamp) AS first_purchase,
    MAX(o.order_purchase_timestamp) AS last_purchase,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.price)::numeric, 2) AS total_spend,
    ROUND(
        (SUM(oi.price) / COUNT(DISTINCT o.order_id))::numeric,
        2
    ) AS avg_order_value,
    DATE_PART(
        'day',
        MAX(o.order_purchase_timestamp) - MIN(o.order_purchase_timestamp)
    ) AS customer_lifespan_days
FROM customers c
JOIN orders o
    ON c.customer_id = o.customer_id
JOIN order_items oi
    ON o.order_id = oi.order_id
WHERE
    o.order_status = 'delivered'
GROUP BY
    c.customer_unique_id
ORDER BY
    total_spend DESC;


-- 4. How long does it take customers to make a second purchase?

WITH ranked_orders AS (
    SELECT
        c.customer_unique_id,
        o.order_purchase_timestamp,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY o.order_purchase_timestamp
        ) AS purchase_number
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    WHERE
        o.order_status = 'delivered'
),

first_second_purchase AS (
    SELECT
        customer_unique_id,
        MIN(order_purchase_timestamp) FILTER (
            WHERE purchase_number = 1
        ) AS first_purchase,
        MIN(order_purchase_timestamp) FILTER (
            WHERE purchase_number = 2
        ) AS second_purchase
    FROM ranked_orders
    GROUP BY
        customer_unique_id
)

SELECT
    COUNT(*) AS repeat_customers,
    ROUND(
        AVG(
            DATE_PART('day', second_purchase - first_purchase)
        )::numeric,
        1
    ) AS avg_days_to_second_purchase,
    ROUND(
        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY DATE_PART('day', second_purchase - first_purchase)
        )::numeric,
        1
    ) AS median_days_to_second_purchase
FROM first_second_purchase
WHERE
    second_purchase IS NOT NULL;


-- 5. How is customer acquisition changing over time?

WITH customer_first_purchase AS (
    SELECT
        c.customer_unique_id,
        MIN(o.order_purchase_timestamp) AS first_purchase
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    WHERE
        o.order_status = 'delivered'
    GROUP BY
        c.customer_unique_id
)

SELECT
    TO_CHAR(first_purchase, 'YYYY-MM') AS acquisition_month,
    COUNT(*) AS new_customers
FROM customer_first_purchase
GROUP BY
    TO_CHAR(first_purchase, 'YYYY-MM')
ORDER BY
    acquisition_month;


-- 6. What does customer cohort retention look like?

-- Cohorts are based on each customer's first delivered-order month.

WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        DATE_TRUNC('month', o.order_purchase_timestamp) AS order_month
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    WHERE
        o.order_status = 'delivered'
),

customer_cohorts AS (
    SELECT
        customer_unique_id,
        MIN(order_month) AS cohort_month
    FROM customer_orders
    GROUP BY
        customer_unique_id
),

cohort_activity AS (
    SELECT DISTINCT
        co.customer_unique_id,
        cc.cohort_month,
        co.order_month,
        (
            EXTRACT(YEAR FROM AGE(co.order_month, cc.cohort_month)) * 12
            + EXTRACT(MONTH FROM AGE(co.order_month, cc.cohort_month))
        )::int AS months_since_first_purchase
    FROM customer_orders co
    JOIN customer_cohorts cc
        ON co.customer_unique_id = cc.customer_unique_id
),

cohort_size AS (
    SELECT
        cohort_month,
        COUNT(DISTINCT customer_unique_id) AS cohort_customers
    FROM customer_cohorts
    GROUP BY
        cohort_month
)

SELECT
    TO_CHAR(ca.cohort_month, 'YYYY-MM') AS cohort_month,
    ca.months_since_first_purchase,
    COUNT(DISTINCT ca.customer_unique_id) AS retained_customers,
    ROUND(
        COUNT(DISTINCT ca.customer_unique_id) * 100.0 / cs.cohort_customers,
        1
    ) AS retention_pct
FROM cohort_activity ca
JOIN cohort_size cs
    ON ca.cohort_month = cs.cohort_month
GROUP BY
    ca.cohort_month,
    ca.months_since_first_purchase,
    cs.cohort_customers
ORDER BY
    ca.cohort_month,
    ca.months_since_first_purchase;
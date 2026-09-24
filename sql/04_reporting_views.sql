-- 1. Order-level reporting view
-- One row per order with customer, delivery, revenue, freight, and item count

CREATE OR REPLACE VIEW vw_order_summary AS

SELECT
    o.order_id,
    o.customer_id,
    c.customer_unique_id,
    c.customer_state,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,

    DATE_PART(
        'day',
        o.order_delivered_customer_date - o.order_purchase_timestamp
    ) AS delivery_days,

    DATE_PART(
        'day',
        o.order_delivered_customer_date - o.order_estimated_delivery_date
    ) AS days_vs_estimate,

    SUM(oi.price) AS order_value,
    SUM(oi.freight_value) AS freight_value,
    COUNT(*) AS item_count,
    o.order_purchase_timestamp::date AS order_purchase_date

FROM orders o
JOIN customers c
    ON o.customer_id = c.customer_id
JOIN order_items oi
    ON o.order_id = oi.order_id

GROUP BY
    o.order_id,
    o.customer_id,
    c.customer_unique_id,
    c.customer_state,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date;


-- 2. Order item reporting view
-- One row per order item for product, category, seller, and revenue analysis

CREATE OR REPLACE VIEW vw_order_items AS

SELECT
    oi.order_id,
    oi.order_item_id,
    oi.product_id,
    oi.seller_id,
    o.order_purchase_timestamp,
    c.customer_state,

    COALESCE(
        pct.product_category_name_english,
        'Unknown'
    ) AS product_category,

    oi.price,
    oi.freight_value,
    o.order_purchase_timestamp::date AS order_purchase_date

FROM order_items oi
JOIN orders o
    ON oi.order_id = o.order_id
JOIN customers c
    ON o.customer_id = c.customer_id
LEFT JOIN products p
    ON oi.product_id = p.product_id
LEFT JOIN product_category_name_translation pct
    ON p.product_category_name = pct.product_category_name

WHERE
    o.order_status = 'delivered';


-- 3. Customer-level reporting view
-- One row per unique customer

CREATE OR REPLACE VIEW vw_customer_summary AS

SELECT
    c.customer_unique_id,
    MIN(o.order_purchase_timestamp) AS first_purchase,
    MAX(o.order_purchase_timestamp) AS last_purchase,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(oi.price) AS total_spend,
    SUM(oi.price) / COUNT(DISTINCT o.order_id) AS avg_order_value,

    CASE
        WHEN COUNT(DISTINCT o.order_id) > 1 THEN 'repeat customer'
        ELSE 'one-time customer'
    END AS customer_type

FROM customers c

JOIN orders o
    ON c.customer_id = o.customer_id

JOIN order_items oi
    ON o.order_id = oi.order_id

WHERE
    o.order_status = 'delivered'

GROUP BY
    c.customer_unique_id;



-- 4. Review reporting view
-- One row per reviewed order with delivery performance

CREATE OR REPLACE VIEW vw_delivery_reviews AS

SELECT
    o.order_id,
    r.review_score,

    DATE_PART(
        'day',
        o.order_delivered_customer_date - o.order_estimated_delivery_date
    ) AS days_vs_estimate,

    CASE
        WHEN o.order_delivered_customer_date - o.order_estimated_delivery_date < '1 day'
            THEN 'on time or early'

        WHEN DATE_PART(
            'day',
            o.order_delivered_customer_date - o.order_estimated_delivery_date
        ) BETWEEN 1 AND 3
            THEN '1-3 days late'

        WHEN DATE_PART(
            'day',
            o.order_delivered_customer_date - o.order_estimated_delivery_date
        ) BETWEEN 4 AND 7
            THEN '4-7 days late'

        ELSE '8+ days late'
    END AS lateness_bucket

FROM orders o

JOIN order_reviews r
    ON o.order_id = r.order_id

WHERE
    o.order_delivered_customer_date IS NOT NULL;


-- 5. Date reporting view
-- One row per calendar date for time-based reporting

CREATE OR REPLACE VIEW vw_date AS

SELECT
    day::date AS date,
    EXTRACT(YEAR FROM day)::int AS year,
    EXTRACT(MONTH FROM day)::int AS month_number,
    TO_CHAR(day, 'Mon') AS month,
    TO_CHAR(day, 'YYYY-MM') AS year_month

FROM GENERATE_SERIES(
    (SELECT MIN(order_purchase_timestamp)::date FROM orders),
    (SELECT MAX(order_purchase_timestamp)::date FROM orders),
    INTERVAL '1 day'
) AS day;


-- Format for order purchases
SELECT
    TO_CHAR(order_purchase_timestamp, 'YYYY-MM') AS month,
    COUNT(*) AS total_orders,
    COUNT(*) FILTER (
        WHERE order_delivered_customer_date - order_estimated_delivery_date >= '1 day'
    ) AS late_orders,
    ROUND(
        COUNT(*) FILTER (
            WHERE order_delivered_customer_date - order_estimated_delivery_date >= '1 day'
        ) * 100.0 / COUNT(*),
        1
    ) AS late_pct
FROM orders
WHERE
    order_delivered_customer_date IS NOT NULL
GROUP BY
    TO_CHAR(order_purchase_timestamp, 'YYYY-MM')
ORDER BY
    month;


    -- Customer cohort retention

CREATE OR REPLACE VIEW vw_customer_cohorts AS

WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        DATE_TRUNC('month', o.order_purchase_timestamp)::date AS order_month
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
),

customer_cohorts AS (
    SELECT
        customer_unique_id,
        MIN(order_month) AS cohort_month
    FROM customer_orders
    GROUP BY customer_unique_id
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
    GROUP BY cohort_month
)

SELECT
    ca.cohort_month,
    ca.months_since_first_purchase,
    COUNT(DISTINCT ca.customer_unique_id) AS retained_customers,
    cs.cohort_customers,
    ROUND(
        COUNT(DISTINCT ca.customer_unique_id) * 100.0
        / cs.cohort_customers,
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


-- Export queries for reports

SELECT * FROM vw_order_summary;
SELECT * FROM vw_order_items;
SELECT * FROM vw_customer_summary;
SELECT * FROM vw_delivery_reviews;
SELECT * FROM vw_date;
SELECT * FROM vw_customer_cohorts;
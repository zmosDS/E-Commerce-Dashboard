-- Olist E-Commerce Revenue Analysis

-- Revenue uses order_items.price rather than payment_value to measure product sales consistently.

-- 1. How are revenue, orders, units sold, and average order value changing over time?

WITH monthly_orders AS (
    SELECT
        TO_CHAR(o.order_purchase_timestamp, 'YYYY-MM') AS month,
        COUNT(DISTINCT o.order_id) AS total_orders,
        COUNT(*) AS units_sold,
        SUM(oi.price) AS revenue
    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
    WHERE
        o.order_status = 'delivered'
    GROUP BY
        TO_CHAR(o.order_purchase_timestamp, 'YYYY-MM')
)

SELECT
    month,
    total_orders,
    units_sold,
    ROUND(revenue::numeric, 2) AS revenue,
    ROUND((revenue / total_orders)::numeric, 2) AS avg_order_value
FROM monthly_orders
ORDER BY
    month;


-- 2. What is month-over-month revenue growth?

WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', o.order_purchase_timestamp) AS month,
        SUM(oi.price) AS revenue
    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
    WHERE
        o.order_status = 'delivered'
    GROUP BY
        DATE_TRUNC('month', o.order_purchase_timestamp)
),

revenue_growth AS (
    SELECT
        month,
        revenue,
        LAG(revenue) OVER (ORDER BY month) AS previous_month_revenue
    FROM monthly_revenue
)

SELECT
    TO_CHAR(month, 'YYYY-MM') AS month,
    ROUND(revenue::numeric, 2) AS revenue,
    ROUND(previous_month_revenue::numeric, 2) AS previous_month_revenue,
    ROUND(
        ((revenue - previous_month_revenue) * 100.0 / previous_month_revenue)::numeric,
        1
    ) AS mom_growth_pct
FROM revenue_growth
ORDER BY
    month;


-- 3. Which product categories generate the most revenue?

SELECT
    pct.product_category_name_english AS product_category,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    COUNT(*) AS units_sold,
    ROUND(SUM(oi.price)::numeric, 2) AS revenue,
    ROUND(AVG(oi.price)::numeric, 2) AS avg_item_price,
    ROUND(
        SUM(oi.price) * 100.0 / SUM(SUM(oi.price)) OVER (),
        2
    ) AS revenue_pct,
    RANK() OVER (
        ORDER BY SUM(oi.price) DESC
    ) AS revenue_rank
FROM order_items oi
JOIN orders o
    ON oi.order_id = o.order_id
JOIN products p
    ON oi.product_id = p.product_id
LEFT JOIN product_category_name_translation pct
    ON p.product_category_name = pct.product_category_name
WHERE
    o.order_status = 'delivered'
GROUP BY
    pct.product_category_name_english
ORDER BY
    revenue DESC;


-- 4. Which product categories are growing or declining over time?

WITH category_monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', o.order_purchase_timestamp) AS month,
        pct.product_category_name_english AS product_category,
        SUM(oi.price) AS revenue
    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
    JOIN products p
        ON oi.product_id = p.product_id
    LEFT JOIN product_category_name_translation pct
        ON p.product_category_name = pct.product_category_name
    WHERE
        o.order_status = 'delivered'
    GROUP BY
        DATE_TRUNC('month', o.order_purchase_timestamp),
        pct.product_category_name_english
),

category_growth AS (
    SELECT
        month,
        product_category,
        revenue,
        LAG(revenue) OVER (
            PARTITION BY product_category
            ORDER BY month
        ) AS previous_month_revenue
    FROM category_monthly_revenue
)

SELECT
    TO_CHAR(month, 'YYYY-MM') AS month,
    product_category,
    ROUND(revenue::numeric, 2) AS revenue,
    ROUND(previous_month_revenue::numeric, 2) AS previous_month_revenue,
    ROUND(
        ((revenue - previous_month_revenue) * 100.0 / previous_month_revenue)::numeric,
        1
    ) AS mom_growth_pct
FROM category_growth
WHERE
    previous_month_revenue IS NOT NULL
ORDER BY
    month,
    revenue DESC;


-- 5. Which customer states generate the most revenue?

SELECT
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(DISTINCT c.customer_unique_id) AS unique_customers,
    ROUND(SUM(oi.price)::numeric, 2) AS revenue,
    ROUND(
        (SUM(oi.price) / COUNT(DISTINCT o.order_id))::numeric,
        2
    ) AS avg_order_value,
    ROUND(
        (SUM(oi.price) / COUNT(DISTINCT c.customer_unique_id))::numeric,
        2
    ) AS revenue_per_customer
FROM orders o
JOIN customers c
    ON o.customer_id = c.customer_id
JOIN order_items oi
    ON o.order_id = oi.order_id
WHERE
    o.order_status = 'delivered'
GROUP BY
    c.customer_state
ORDER BY
    revenue DESC;

-- 6. How concentrated is revenue among sellers?

-- Cumulative revenue is used to measure how concentrated sales are among sellers.

WITH seller_revenue AS (
    SELECT
        oi.seller_id,
        SUM(oi.price) AS revenue
    FROM order_items oi
    JOIN orders o
        ON oi.order_id = o.order_id
    WHERE
        o.order_status = 'delivered'
    GROUP BY
        oi.seller_id
),

seller_ranked AS (
    SELECT
        seller_id,
        revenue,
        RANK() OVER (
            ORDER BY revenue DESC
        ) AS revenue_rank,
        SUM(revenue) OVER (
            ORDER BY revenue DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_revenue,
        SUM(revenue) OVER () AS total_revenue
    FROM seller_revenue
)

SELECT
    seller_id,
    revenue_rank,
    ROUND(revenue::numeric, 2) AS revenue,
    ROUND(
        (revenue * 100.0 / total_revenue)::numeric,
        2
    ) AS revenue_pct,
    ROUND(
        (cumulative_revenue * 100.0 / total_revenue)::numeric,
        2
    ) AS cumulative_revenue_pct
FROM seller_ranked
ORDER BY
    revenue_rank;
SELECT
    customer_state,
    COUNT(DISTINCT customer_unique_id) AS customers,
    ROUND(AVG(order_value)::numeric, 2) AS avg_order_value,
    ROUND(AVG(freight_value)::numeric, 2) AS avg_freight,
    ROUND(AVG(delivery_days)::numeric, 2) AS avg_delivery_days,
    ROUND(
        (
            100.0 * COUNT(*) FILTER (WHERE days_vs_estimate >= 1)
            / COUNT(*)
        )::numeric,
        1
    ) AS late_delivery_pct
FROM vw_order_summary
WHERE
    order_status = 'delivered'
    AND order_purchase_timestamp >= '2017-01-01'
GROUP BY customer_state
HAVING COUNT(DISTINCT customer_unique_id) >= 100
ORDER BY customers DESC;




SELECT
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY total_spend)::numeric, 2) AS median_spend,
    ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY total_spend)::numeric, 2) AS p75_spend,
    ROUND(PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY total_spend)::numeric, 2) AS p90_spend,
    ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY total_spend)::numeric, 2) AS p95_spend,
    ROUND(AVG(total_spend)::numeric, 2) AS avg_spend
FROM vw_customer_summary
WHERE first_purchase >= '2017-01-01';

SELECT
    CASE
        WHEN total_spend < 50 THEN '< $50'
        WHEN total_spend < 100 THEN '$50-$99'
        WHEN total_spend < 200 THEN '$100-$199'
        WHEN total_spend < 500 THEN '$200-$499'
        ELSE '$500+'
    END AS spend_band,
    COUNT(*) AS customers,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (),
        1
    ) AS customer_pct,
    ROUND(SUM(total_spend)::numeric, 2) AS total_spend,
    ROUND(
        SUM(total_spend) * 100.0 / SUM(SUM(total_spend)) OVER (),
        1
    ) AS revenue_pct
FROM vw_customer_summary
WHERE first_purchase >= '2017-01-01'
GROUP BY spend_band
ORDER BY MIN(total_spend);


SELECT
    CASE
        WHEN item_count = 1 THEN '1 item'
        WHEN item_count = 2 THEN '2 items'
        WHEN item_count BETWEEN 3 AND 4 THEN '3-4 items'
        ELSE '5+ items'
    END AS basket_size,
    COUNT(*) AS orders,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (),
        1
    ) AS order_pct,
    ROUND(AVG(order_value)::numeric, 2) AS avg_order_value,
    ROUND(
        SUM(order_value) * 100.0 / SUM(SUM(order_value)) OVER (),
        1
    ) AS revenue_pct
FROM vw_order_summary
WHERE
    order_status = 'delivered'
    AND order_purchase_timestamp >= '2017-01-01'
GROUP BY basket_size
ORDER BY MIN(item_count);


WITH threshold AS (
    SELECT
        PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY total_spend) AS p90
    FROM vw_customer_summary
    WHERE first_purchase >= '2017-01-01'
),

customer_groups AS (
    SELECT
        cs.*,
        CASE
            WHEN cs.total_spend >= t.p90 THEN 'Top 10%'
            ELSE 'Other 90%'
        END AS customer_group
    FROM vw_customer_summary cs
    CROSS JOIN threshold t
    WHERE cs.first_purchase >= '2017-01-01'
)

SELECT
    customer_group,
    COUNT(*) AS customers,
    ROUND(AVG(total_spend)::numeric, 2) AS avg_customer_spend,
    ROUND(AVG(total_orders)::numeric, 2) AS avg_orders,
    ROUND(AVG(avg_order_value)::numeric, 2) AS avg_order_value
FROM customer_groups
GROUP BY customer_group;


SELECT
    customer_state,
    COUNT(*) AS customers,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (),
        1
    ) AS customer_pct,
    ROUND(AVG(total_spend)::numeric, 2) AS avg_customer_spend,
    ROUND(SUM(total_spend)::numeric, 2) AS total_customer_spend
FROM vw_customer_summary
WHERE first_purchase >= '2017-01-01'
GROUP BY customer_state
HAVING COUNT(*) >= 100
ORDER BY customers DESC;
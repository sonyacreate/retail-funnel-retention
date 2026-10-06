-- Customer Retention & Revenue Analytics
-- DuckDB / PostgreSQL-style analytical SQL
-- Input: order-level table with:
-- "Customer ID", Invoice, InvoiceDate, revenue

-- 1. Order-level customer base
WITH orders AS (
    SELECT
        "Customer ID",
        Invoice,
        MIN(InvoiceDate) AS order_date,
        SUM(revenue) AS order_revenue
    FROM sales
    GROUP BY "Customer ID", Invoice
),
customer_metrics AS (
    SELECT
        "Customer ID",
        COUNT(Invoice) AS orders_count,
        SUM(order_revenue) AS total_revenue,
        AVG(order_revenue) AS avg_order_value,
        MIN(order_date) AS first_purchase,
        MAX(order_date) AS last_purchase
    FROM orders
    GROUP BY "Customer ID"
)

-- 2. One-time vs repeat customers and revenue share
SELECT
    CASE
        WHEN orders_count = 1 THEN 'One-time'
        ELSE 'Repeat'
    END AS customer_type,
    COUNT(*) AS customers,
    SUM(total_revenue) AS total_revenue,
    SUM(total_revenue) * 100.0
        / SUM(SUM(total_revenue)) OVER () AS revenue_share_pct
FROM customer_metrics
GROUP BY customer_type
ORDER BY customers DESC;


-- 3. High-value inactive customers
WITH orders AS (
    SELECT
        "Customer ID",
        Invoice,
        MIN(InvoiceDate) AS order_date,
        SUM(revenue) AS order_revenue
    FROM sales
    GROUP BY "Customer ID", Invoice
),
customer_metrics AS (
    SELECT
        "Customer ID",
        COUNT(Invoice) AS orders_count,
        SUM(order_revenue) AS total_revenue,
        AVG(order_revenue) AS avg_order_value,
        MIN(order_date) AS first_purchase,
        MAX(order_date) AS last_purchase
    FROM orders
    GROUP BY "Customer ID"
),
customer_base AS (
    SELECT
        cm.*,
        DATE_DIFF('day', cm.last_purchase, MAX(cm.last_purchase) OVER ()) AS recency_days,
        MEDIAN(cm.total_revenue) OVER () AS median_revenue
    FROM customer_metrics cm
)
SELECT
    "Customer ID",
    orders_count,
    total_revenue,
    avg_order_value,
    first_purchase,
    last_purchase,
    recency_days,
    CASE
        WHEN total_revenue >= median_revenue AND recency_days >= 90
            THEN 'High-value inactive'
        WHEN recency_days >= 90
            THEN 'Low-value inactive'
        ELSE 'Active'
    END AS customer_segment
FROM customer_base
ORDER BY total_revenue DESC;


-- 4. Revenue concentration / cumulative share
WITH customer_metrics AS (
    SELECT
        "Customer ID",
        SUM(revenue) AS total_revenue
    FROM sales
    GROUP BY "Customer ID"
),
ranked AS (
    SELECT
        "Customer ID",
        total_revenue,
        SUM(total_revenue) OVER (
            ORDER BY total_revenue DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_revenue
    FROM customer_metrics
)
SELECT
    "Customer ID",
    total_revenue,
    cumulative_revenue,
    cumulative_revenue * 100.0
        / SUM(total_revenue) OVER () AS cumulative_revenue_share_pct,
    ROW_NUMBER() OVER (ORDER BY total_revenue DESC) AS revenue_rank
FROM ranked
ORDER BY revenue_rank;

-- 1. ABC-анализ товаров (Сегментация по вкладу в выручку)
WITH product_revenue AS (
    SELECT 
        p.id, p.name,
        SUM(oi.quantity * oi.unit_price) AS total_revenue
    FROM products p
    JOIN order_items oi ON p.id = oi.product_id
    GROUP BY p.id, p.name
),
ranked AS (
    SELECT 
        id, name, total_revenue,
        SUM(total_revenue) OVER (ORDER BY total_revenue DESC) AS cumulative_revenue,
        SUM(total_revenue) OVER () AS grand_total
    FROM product_revenue
)
SELECT 
    id, name, total_revenue,
    ROUND((cumulative_revenue / grand_total) * 100, 2) AS cumulative_pct,
    CASE 
        WHEN (cumulative_revenue / grand_total) <= 0.80 THEN 'A'
        WHEN (cumulative_revenue / grand_total) <= 0.95 THEN 'B'
        ELSE 'C'
    END AS abc_class
FROM ranked
ORDER BY total_revenue DESC;

-- 2. Анализ оборачиваемости запасов по зонам склада (Inventory Turnover)
SELECT 
    z.name AS zone_name,
    w.name AS warehouse_name,
    SUM(i.quantity * p.unit_price) AS avg_inventory_value,
    COALESCE(SUM(oi.quantity * oi.unit_price), 0) AS cogs_sold,
    CASE 
        WHEN SUM(i.quantity * p.unit_price) > 0 
        THEN ROUND(COALESCE(SUM(oi.quantity * oi.unit_price), 0) / SUM(i.quantity * p.unit_price), 2)
        ELSE 0 
    END AS turnover_ratio
FROM zones z
JOIN warehouses w ON z.warehouse_id = w.id
JOIN inventory i ON z.id = i.zone_id
JOIN products p ON i.product_id = p.id
LEFT JOIN order_items oi ON p.id = oi.product_id
GROUP BY z.name, w.name
ORDER BY turnover_ratio DESC;

-- 3. RFM-анализ клиентов (Сегментация B2B/B2C)
WITH customer_metrics AS (
    SELECT 
        c.id, c.name,
        EXTRACT(DAY FROM CURRENT_TIMESTAMP - MAX(o.order_date)) AS recency,
        COUNT(DISTINCT o.id) AS frequency,
        SUM(oi.quantity * oi.unit_price) AS monetary
    FROM customers c
    JOIN orders o ON c.id = o.customer_id
    JOIN order_items oi ON o.id = oi.order_id
    GROUP BY c.id, c.name
),
ranked_metrics AS (
    SELECT *,
        NTILE(4) OVER (ORDER BY recency DESC) AS r_rank, -- 1 = самые давние
        NTILE(4) OVER (ORDER BY frequency DESC) AS f_rank,
        NTILE(4) OVER (ORDER BY monetary DESC) AS m_rank
    FROM customer_metrics
)
SELECT 
    name, recency, frequency, monetary,
    CONCAT('R', r_rank, 'F', f_rank, 'M', m_rank) AS rfm_segment,
    CASE 
        WHEN r_rank <= 2 AND f_rank >= 3 AND m_rank >= 3 THEN 'Champions'
        WHEN r_rank >= 3 AND f_rank <= 2 THEN 'Lost'
        ELSE 'Regular'
    END AS customer_label
FROM ranked_metrics
ORDER BY monetary DESC;

-- 4. Точность инвентаризации и потери по поставщикам (Косвенная оценка качества)
SELECT 
    s.name AS supplier_name,
    COUNT(DISTINCT ai.product_id) AS audited_products,
    SUM(ABS(ai.discrepancy)) AS total_abs_discrepancy,
    ROUND(AVG(ABS(ai.discrepancy) / NULLIF(ai.system_qty, 0)) * 100, 2) AS avg_error_pct
FROM audit_items ai
JOIN products p ON ai.product_id = p.id
JOIN replenishment_items ri ON p.id = ri.product_id
JOIN replenishment_orders ro ON ri.order_id = ro.id
JOIN suppliers s ON ro.supplier_id = s.id
GROUP BY s.name
HAVING SUM(ABS(ai.discrepancy)) > 0;

-- 5. Прогноз потребности (Forecasting) на основе скользящего среднего
WITH daily_sales AS (
    SELECT 
        p.id AS product_id,
        p.name,
        DATE(o.order_date) AS sale_date,
        SUM(oi.quantity) AS daily_qty
    FROM products p
    JOIN order_items oi ON p.id = oi.product_id
    JOIN orders o ON oi.order_id = o.id
    WHERE o.order_date >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY p.id, p.name, DATE(o.order_date)
)
SELECT 
    product_id,
    name,
    AVG(daily_qty) OVER (PARTITION BY product_id ORDER BY sale_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS moving_avg_7_days,
    STDDEV(daily_qty) OVER (PARTITION BY product_id) AS sales_volatility
FROM daily_sales;

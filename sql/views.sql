--Текущий статус запасов и их стоимость
CREATE OR REPLACE VIEW v_current_inventory_status AS
SELECT 
    p.id AS product_id,
    p.name AS product_name,
    c.name AS category_name,
    SUM(i.quantity) AS total_qty,
    SUM(i.reserved_qty) AS reserved_qty,
    (SUM(i.quantity) - SUM(i.reserved_qty)) AS available_qty,
    p.unit_price,
    (SUM(i.quantity) - SUM(i.reserved_qty)) * p.unit_price AS available_value
FROM products p
JOIN inventory i ON p.id = i.product_id
JOIN categories c ON p.category_id = c.id
GROUP BY p.id, p.name, c.name, p.unit_price;

--Рекомендации по пополнению (Автоматическое создание логики заказа)
CREATE OR REPLACE VIEW v_replenishment_recommendations AS
SELECT 
    p.id AS product_id,
    p.name,
    p.reorder_point,
    COALESCE(inv.total_available, 0) AS current_available,
    COALESCE(avg_sales.avg_daily_sales, 0) AS avg_daily_sales,
    s.lead_time_days,
    CASE 
        WHEN COALESCE(inv.total_available, 0) <= p.reorder_point THEN 'URGENT'
        WHEN COALESCE(inv.total_available, 0) <= (COALESCE(avg_sales.avg_daily_sales, 0) * s.lead_time_days) THEN 'WARNING'
        ELSE 'OK'
    END AS stock_status
FROM products p
LEFT JOIN (
    SELECT product_id, SUM(quantity - reserved_qty) AS total_available 
    FROM inventory GROUP BY product_id
) inv ON p.id = inv.product_id
LEFT JOIN (
    SELECT product_id, SUM(quantity) / NULLIF(CURRENT_DATE - MIN(order_date::date), 0) AS avg_daily_sales
    FROM order_items oi JOIN orders o ON oi.order_id = o.id
    WHERE o.order_date >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY product_id
) avg_sales ON p.id = avg_sales.product_id
LEFT JOIN replenishment_items ri ON p.id = ri.product_id
LEFT JOIN replenishment_orders ro ON ri.order_id = ro.id
LEFT JOIN suppliers s ON ro.supplier_id = s.id;

--Агрегированные ежедневные продажи и движения
CREATE OR REPLACE VIEW v_daily_operations_summary AS
SELECT 
    DATE(m.movement_date) AS operation_date,
    m.movement_type,
    COUNT(DISTINCT m.product_id) AS unique_products,
    SUM(ABS(m.quantity)) AS total_units_moved,
    SUM(ABS(m.quantity) * p.unit_price) AS total_value_moved
FROM movements m
JOIN products p ON m.product_id = p.id
GROUP BY DATE(m.movement_date), m.movement_type;

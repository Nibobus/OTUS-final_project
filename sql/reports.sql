-- ОТЧЕТ 1: Финансовая стоимость запасов и ABC-класс (Для Pie Chart & Bar Chart)
SELECT 
    COALESCE(p.abc_class, 'Unclassified') AS abc_segment,
    c.name AS category,
    COUNT(DISTINCT p.id) AS sku_count,
    SUM(i.quantity) AS total_units,
    SUM(i.quantity * p.unit_price) AS total_value
FROM products p
JOIN inventory i ON p.id = i.product_id
JOIN categories c ON p.category_id = c.id
GROUP BY ROLLUP (p.abc_class, c.name)
ORDER BY abc_segment, total_value DESC;
/* Визуализация: 
   1. Круговая диаграмма (Pie Chart) распределения стоимости по ABC-классам.
   2. Столбчатая диаграмма (Bar Chart) стоимости по категориям внутри класса А. */

-- ОТЧЕТ 2: Дашборд "Здоровье склада" (KPI Report)
SELECT 
    'Total SKUs' AS kpi_name, COUNT(DISTINCT product_id) AS kpi_value FROM inventory
UNION ALL
SELECT 
    'Out of Stock SKUs', COUNT(DISTINCT product_id) 
    FROM inventory GROUP BY product_id HAVING SUM(quantity - reserved_qty) <= 0
UNION ALL
SELECT 
    'Total Inventory Value', ROUND(SUM(quantity * unit_price), 2) 
    FROM inventory i JOIN products p ON i.product_id = p.id
UNION ALL
SELECT 
    'Pending Replenishment Orders', COUNT(*) 
    FROM replenishment_orders WHERE status IN ('Draft', 'Generated');
/* Визуализация: 
   Карточки (Scorecards) с 4 главными метриками для верхнего дашборда. 
   Индикаторы красного цвета, если Out of Stock > 0. */

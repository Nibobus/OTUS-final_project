-- 0. ОЧИСТКА ТАБЛИЦ
TRUNCATE TABLE 
    movements,
    audit_items,
    inventory_audits,
    replenishment_items,
    replenishment_orders,
    order_items,
    orders,
    inventory,
    products,
    zones,
    customers,
    suppliers,
    warehouses,
    categories
CASCADE;

-- 1. СПРАВОЧНИКИ
-- Категории товаров (15 штук)
INSERT INTO categories (name) VALUES
('Электроника'), ('Смартфоны'), ('Ноутбуки'), ('Аксессуары'),
('Мебель'), ('Офисная мебель'), ('Домашняя мебель'),
('Продукты питания'), ('Напитки'), ('Сладости'),
('Бытовая химия'), ('Косметика'), ('Одежда'),
('Инструменты'), ('Стройматериалы');

-- Склады (5 штук)
INSERT INTO warehouses (name, location) VALUES
('Склад Центр', 'Москва, ул. Складская, 1'),
('Склад Юг', 'Краснодар, ул. Логистическая, 15'),
('Склад Север', 'Санкт-Петербург, пр. Индустриальный, 42'),
('Склад Восток', 'Екатеринбург, ул. Транспортная, 8'),
('Склад Запад', 'Казань, ул. Промышленная, 23');

-- Поставщики (20 штук)
INSERT INTO suppliers (name, lead_time_days) VALUES
('ТехноОпт', 5), ('МегаСмарт', 7), ('НоутбукПром', 10),
('АксессуарПлюс', 3), ('МебельГрад', 14), ('ОфисСтиль', 12),
('ДомУют', 15), ('ФудЛайн', 2), ('НапиткиОпт', 3),
('СладкийМир', 4), ('ЧистыйДом', 5), ('КрасотаКо', 6),
('МодаТренд', 8), ('ИнструментПро', 7), ('СтройБаза', 10),
('ГлобалТрейд', 20), ('ЕвроИмпорт', 25), ('АзияТорг', 30),
('ЛокалСнаб', 4), ('ЭкспрессПоставка', 1);

-- Клиенты (100 штук)
INSERT INTO customers (name, segment)
SELECT 
    CASE 
        WHEN g <= 30 THEN 'ООО Компания_' || g::text
        WHEN g <= 60 THEN 'ИП Предприниматель_' || g::text
        ELSE 'АО Корпорация_' || g::text
    END AS name,
    CASE 
        WHEN random() < 0.2 THEN 'VIP'
        WHEN random() < 0.5 THEN 'Premium'
        ELSE 'Standard'
    END AS segment
FROM generate_series(1, 100) AS g;

-- 2. ЗАВИСИМЫЕ СПРАВОЧНИКИ
-- Зоны складов (по 3-4 зоны на каждый склад = ~18 зон)
INSERT INTO zones (warehouse_id, name, zone_type)
SELECT 
    w.id AS warehouse_id,
    w.name || ' - ' || z.type_name AS name,
    z.type_name AS zone_type
FROM warehouses w
CROSS JOIN (
    VALUES ('Storage'), ('Picking'), ('Receiving'), ('Shipping')
) AS z(type_name)
WHERE random() > 0.2; 

-- Товары (150 штук, по ~10 на каждую категорию)
INSERT INTO products (category_id, name, unit_price, min_stock_level, reorder_point)
SELECT 
    c.id AS category_id,
    c.name || ' - Модель_' || g::text AS name,
    ROUND((random() * 50000 + 100)::numeric, 2) AS unit_price,
    ROUND((random() * 50 + 5)::numeric, 2) AS min_stock_level,
    ROUND((random() * 100 + 20)::numeric, 2) AS reorder_point
FROM categories c
CROSS JOIN generate_series(1, 10) AS g;

-- 3. ОСТАТКИ НА СКЛАДЕ
-- Инвентарь (по 1-3 записи на каждый товар в разных зонах)
INSERT INTO inventory (product_id, zone_id, quantity, reserved_qty)
SELECT 
    p.id AS product_id,
    (SELECT z.id FROM zones z ORDER BY random() LIMIT 1) AS zone_id,
    ROUND((random() * 500 + 10)::numeric, 2) AS quantity,
    ROUND((random() * 50)::numeric, 2) AS reserved_qty
FROM products p
CROSS JOIN generate_series(1, 2) AS s  -- 2 записи на товар
WHERE random() > 0.1  -- 90% товаров имеют остатки
ON CONFLICT (product_id, zone_id) DO NOTHING;

-- 4. ЗАКАЗЫ КЛИЕНТОВ
-- Заказы (500 штук)
INSERT INTO orders (customer_id, order_date, status)
SELECT 
    c.id AS customer_id,
    (timestamp '2025-08-24' - (random() * interval '365 days')) AS order_date,
    (ARRAY['Pending', 'Processing', 'Completed', 'Shipped', 'Cancelled'])[floor(random() * 5 + 1)] AS status
FROM (
    SELECT id FROM customers ORDER BY random()
) c
CROSS JOIN generate_series(1, 5) AS g
LIMIT 500;

-- Позиции заказов 
INSERT INTO order_items (order_id, product_id, quantity, unit_price)
SELECT 
    o.id AS order_id,
    p.id AS product_id,
    (floor(random() * 20 + 1))::int AS quantity,
    ROUND((random() * 50000 + 100)::numeric, 2) AS unit_price
FROM orders o
CROSS JOIN (
    SELECT id FROM products ORDER BY random()
) p
WHERE random() > 0.2
LIMIT 1500;

-- 5. ЗАКАЗЫ НА ПОПОЛНЕНИЕ
-- Заказы поставщикам (100 штук)
INSERT INTO replenishment_orders (supplier_id, order_date, status)
SELECT 
    s.id AS supplier_id,
    (timestamp '2025-08-24' - (random() * interval '180 days')) AS order_date,
    (ARRAY['Draft', 'Sent', 'Confirmed', 'Received', 'Cancelled'])[floor(random() * 5 + 1)] AS status
FROM (
    SELECT id FROM suppliers ORDER BY random()
) s
CROSS JOIN generate_series(1, 5) AS g
LIMIT 100;

-- Позиции заказов на пополнение
INSERT INTO replenishment_items (order_id, product_id, quantity)
SELECT 
    ro.id AS order_id,
    p.id AS product_id,
    (floor(random() * 200 + 50))::int AS quantity
FROM replenishment_orders ro
CROSS JOIN (
    SELECT id FROM products ORDER BY random()
) p
WHERE random() > 0.3
LIMIT 300;

-- 6. ИНВЕНТАРИЗАЦИИ
-- Аудиты складов (20 штук)
INSERT INTO inventory_audits (warehouse_id, audit_date, status)
SELECT 
    w.id AS warehouse_id,
    (timestamp '2025-08-24' - (random() * interval '365 days')) AS audit_date,
    (ARRAY['In Progress', 'Completed', 'Cancelled'])[floor(random() * 3 + 1)] AS status
FROM (
    SELECT id FROM warehouses ORDER BY random()
) w
CROSS JOIN generate_series(1, 4) AS g
LIMIT 20;

-- 7. ДВИЖЕНИЯ ТОВАРОВ
-- Движения
INSERT INTO movements (product_id, warehouse_id, movement_date, movement_type, quantity)
SELECT 
    p.id AS product_id,
    w.id AS warehouse_id,
    (timestamp '2025-01-01' + (random() * interval '599 days')) AS movement_date,
    (ARRAY['Inbound', 'Outbound', 'Transfer', 'Adjustment'])[floor(random() * 4 + 1)] AS movement_type,
    ROUND((random() * 100 + 1)::numeric, 2) AS quantity
FROM (
    SELECT id FROM products ORDER BY random()
) p
CROSS JOIN (
    SELECT id FROM warehouses ORDER BY random()
) w
CROSS JOIN generate_series(1, 5) AS g
LIMIT 2500;

-- 8. ОБНОВЛЕНИЕ ABC-КЛАССОВ (на основе продаж)
-- Пересчет ABC-классов товаров
WITH product_revenue AS (
    SELECT 
        p.id,
        SUM(oi.quantity * oi.unit_price) AS total_revenue
    FROM products p
    LEFT JOIN order_items oi ON p.id = oi.product_id
    GROUP BY p.id
),
ranked AS (
    SELECT 
        id,
        SUM(total_revenue) OVER (ORDER BY total_revenue DESC) AS cumulative_revenue,
        SUM(total_revenue) OVER () AS grand_total
    FROM product_revenue
)
UPDATE products p
SET abc_class = CASE 
    WHEN (r.cumulative_revenue / NULLIF(r.grand_total, 0)) <= 0.80 THEN 'A'
    WHEN (r.cumulative_revenue / NULLIF(r.grand_total, 0)) <= 0.95 THEN 'B'
    ELSE 'C'
END
FROM ranked r
WHERE p.id = r.id;

-- ПРОВЕРКА РЕЗУЛЬТАТОВ
SELECT 'categories' AS table_name, COUNT(*) AS row_count FROM categories
UNION ALL
SELECT 'warehouses', COUNT(*) FROM warehouses
UNION ALL
SELECT 'suppliers', COUNT(*) FROM suppliers
UNION ALL
SELECT 'customers', COUNT(*) FROM customers
UNION ALL
SELECT 'zones', COUNT(*) FROM zones
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'inventory', COUNT(*) FROM inventory
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL
SELECT 'replenishment_orders', COUNT(*) FROM replenishment_orders
UNION ALL
SELECT 'replenishment_items', COUNT(*) FROM replenishment_items
UNION ALL
SELECT 'inventory_audits', COUNT(*) FROM inventory_audits
UNION ALL
SELECT 'audit_items', COUNT(*) FROM audit_items
UNION ALL
SELECT 'movements', COUNT(*) FROM movements
ORDER BY row_count DESC;

-- Справочники
INSERT INTO categories (name) VALUES ('Электроника'), ('Мебель'), ('Продукты питания');
INSERT INTO warehouses (name, location) VALUES ('Склад Центр', 'Москва'), ('Склад Юг', 'Краснодар');
INSERT INTO zones (warehouse_id, name, zone_type) VALUES 
(1, 'Зона А1', 'Storage'), (1, 'Зона отгрузки', 'Shipping'), (2, 'Зона приемки', 'Receiving');
INSERT INTO suppliers (name, lead_time_days) VALUES ('ТехноОпт', 5), ('МебельПром', 14), ('ФудЛайн', 2);
INSERT INTO customers (name, segment) VALUES ('ООО Ромашка', 'VIP'), ('ИП Иванов', 'Standard'), ('АО Гигант', 'VIP');

-- Товары
INSERT INTO products (category_id, name, unit_price, min_stock_level, reorder_point) VALUES
(1, 'Смартфон X', 50000, 10, 20),
(1, 'Ноутбук Y', 80000, 5, 10),
(2, 'Стол офисный', 15000, 20, 40),
(3, 'Кофе в зернах 1кг', 1500, 100, 200);

-- Остатки
INSERT INTO inventory (product_id, zone_id, quantity, reserved_qty) VALUES
(1, 1, 50, 5), (2, 1, 15, 2), (3, 1, 100, 10), (4, 1, 300, 50);

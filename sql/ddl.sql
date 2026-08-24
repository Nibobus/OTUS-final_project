-- Таблицы справочников
CREATE TABLE categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE warehouses (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    location VARCHAR(255)
);

CREATE TABLE zones (
    id SERIAL PRIMARY KEY,
    warehouse_id INT REFERENCES warehouses(id),
    name VARCHAR(100) NOT NULL,
    zone_type VARCHAR(50) CHECK (zone_type IN ('Storage', 'Picking', 'Receiving', 'Shipping'))
);

CREATE TABLE suppliers (
    id SERIAL PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    lead_time_days INT DEFAULT 7
);

CREATE TABLE customers (
    id SERIAL PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    segment VARCHAR(50) DEFAULT 'Standard'
);

CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    category_id INT REFERENCES categories(id),
    name VARCHAR(200) NOT NULL,
    unit_price NUMERIC(10, 2) NOT NULL,
    min_stock_level NUMERIC(10, 2) DEFAULT 0,
    reorder_point NUMERIC(10, 2) DEFAULT 0,
    abc_class CHAR(1) CHECK (abc_class IN ('A', 'B', 'C', NULL))
);

-- Таблицы транзакций и остатков
CREATE TABLE inventory (
    product_id INT REFERENCES products(id),
    zone_id INT REFERENCES zones(id),
    quantity NUMERIC(12, 2) DEFAULT 0 CHECK (quantity >= 0),
    reserved_qty NUMERIC(12, 2) DEFAULT 0 CHECK (reserved_qty >= 0),
    PRIMARY KEY (product_id, zone_id)
);

CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    customer_id INT REFERENCES customers(id),
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(50) DEFAULT 'Pending'
);

CREATE TABLE order_items (
    id SERIAL PRIMARY KEY,
    order_id INT REFERENCES orders(id) ON DELETE CASCADE,
    product_id INT REFERENCES products(id),
    quantity NUMERIC(10, 2) NOT NULL,
    unit_price NUMERIC(10, 2) NOT NULL
);

CREATE TABLE replenishment_orders (
    id SERIAL PRIMARY KEY,
    supplier_id INT REFERENCES suppliers(id),
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(50) DEFAULT 'Draft'
);

CREATE TABLE replenishment_items (
    id SERIAL PRIMARY KEY,
    order_id INT REFERENCES replenishment_orders(id) ON DELETE CASCADE,
    product_id INT REFERENCES products(id),
    quantity NUMERIC(10, 2) NOT NULL
);

CREATE TABLE inventory_audits (
    id SERIAL PRIMARY KEY,
    warehouse_id INT REFERENCES warehouses(id),
    audit_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(50) DEFAULT 'In Progress'
);

CREATE TABLE audit_items (
    id SERIAL PRIMARY KEY,
    audit_id INT REFERENCES inventory_audits(id) ON DELETE CASCADE,
    product_id INT REFERENCES products(id),
    system_qty NUMERIC(10, 2),
    actual_qty NUMERIC(10, 2),
    discrepancy NUMERIC(10, 2) GENERATED ALWAYS AS (actual_qty - system_qty) STORED
);

-- Таблица для истории движений (Оптимизация)
CREATE TABLE movements (
    id SERIAL,
    product_id INT REFERENCES products(id),
    warehouse_id INT REFERENCES warehouses(id),
    movement_date TIMESTAMP NOT NULL,
    movement_type VARCHAR(50) CHECK (movement_type IN ('Inbound', 'Outbound', 'Transfer', 'Adjustment')),
    quantity NUMERIC(10, 2) NOT NULL,
    PRIMARY KEY (id, movement_date)
) PARTITION BY RANGE (movement_date);

-- Создание партиций за текущий год
CREATE TABLE movements_2025 PARTITION OF movements FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
CREATE TABLE movements_2026 PARTITION OF movements FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');

-- ИНДЕКСЫ (Оптимизация)
CREATE INDEX idx_inventory_product ON inventory(product_id);
CREATE INDEX idx_orders_customer_date ON orders(customer_id, order_date);
CREATE INDEX idx_movements_product_date ON movements(product_id, movement_date);
CREATE INDEX idx_order_items_product ON order_items(product_id);

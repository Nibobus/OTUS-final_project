-- Функция расчета дней запаса (Days of Supply)
CREATE OR REPLACE FUNCTION fn_days_of_supply(p_product_id INT) 
RETURNS NUMERIC AS $$
DECLARE
    v_available NUMERIC;
    v_avg_daily_sales NUMERIC;
BEGIN
    SELECT SUM(quantity - reserved_qty) INTO v_available 
    FROM inventory WHERE product_id = p_product_id;
    
    SELECT COALESCE(SUM(quantity) / NULLIF(CURRENT_DATE - MIN(order_date::date), 0), 0) 
    INTO v_avg_daily_sales
    FROM order_items oi JOIN orders o ON oi.order_id = o.id
    WHERE product_id = p_product_id AND o.order_date >= CURRENT_DATE - INTERVAL '30 days';
    
    IF v_avg_daily_sales = 0 THEN RETURN 999; -- Бесконечный запас, если нет продаж
    END IF;
    
    RETURN v_available / v_avg_daily_sales;
END;
$$ LANGUAGE plpgsql;

-- Процедура автоматического создания заказов на пополнение
CREATE OR REPLACE PROCEDURE sp_auto_replenishment()
LANGUAGE plpgsql
AS $$
DECLARE
    r RECORD;
    v_order_id INT;
    v_supplier_id INT;
BEGIN
    -- Находим товары, требующие срочного пополнения
    FOR r IN 
        SELECT p.id, p.name, p.reorder_point, 
               (SELECT SUM(quantity - reserved_qty) FROM inventory WHERE product_id = p.id) as avail
        FROM products p
        WHERE (SELECT SUM(quantity - reserved_qty) FROM inventory WHERE product_id = p.id) <= p.reorder_point
    LOOP
        -- Получаем поставщика (в упрощенном виде берем первого из истории или дефолтного)
        SELECT supplier_id INTO v_supplier_id FROM replenishment_orders LIMIT 1;
        IF v_supplier_id IS NULL THEN v_supplier_id := 1; END IF;

        -- Создаем заказ на пополнение
        INSERT INTO replenishment_orders (supplier_id, status) 
        VALUES (v_supplier_id, 'Generated') RETURNING id INTO v_order_id;
        
        -- Добавляем позицию (заказываем до уровня reorder_point * 2)
        INSERT INTO replenishment_items (order_id, product_id, quantity)
        VALUES (v_order_id, r.id, (r.reorder_point * 2) - r.avail);
        
        RAISE NOTICE 'Создан заказ % для товара %', v_order_id, r.name;
    END LOOP;
END;
$$;

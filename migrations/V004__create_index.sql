-- Индексы для оптимизации запроса выборки заказов по диапазону дат

-- Ускоряет фильтрацию по date_created и покрывает JOIN по id (Index Only Scan)
CREATE INDEX idx_orders_date_created_id ON orders (date_created, id);

-- Ускоряет JOIN между order_product и orders
CREATE INDEX idx_order_product_order_id ON order_product (order_id);

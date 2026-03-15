-- Нормализация схемы: объединяем дублирующие таблицы и добавляем ключи

-- Переносим price из product_info в product
ALTER TABLE product ADD COLUMN price DOUBLE PRECISION;

UPDATE product p
SET price = pi.price
FROM product_info pi
WHERE pi.product_id = p.id;

-- Переносим date_created из orders_date в orders
ALTER TABLE orders ADD COLUMN date_created DATE;

UPDATE orders o
SET date_created = od.date_created
FROM orders_date od
WHERE od.order_id = o.id;

-- Первичные ключи
ALTER TABLE product ADD CONSTRAINT product_pkey PRIMARY KEY (id);
ALTER TABLE orders  ADD CONSTRAINT orders_pkey  PRIMARY KEY (id);

-- Внешние ключи для order_product
ALTER TABLE order_product
    ADD CONSTRAINT order_product_orders_fk  FOREIGN KEY (order_id)   REFERENCES orders (id);
ALTER TABLE order_product
    ADD CONSTRAINT order_product_product_fk FOREIGN KEY (product_id) REFERENCES product (id);

-- Удаляем ставшие ненужными таблицы
DROP TABLE orders_date;
DROP TABLE product_info;

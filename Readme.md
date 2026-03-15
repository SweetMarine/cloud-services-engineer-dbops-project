# dbops-project
Исходный репозиторий для выполнения проекта дисциплины "DBOps"

## Шаг 3. Создание БД и пользователя
```sql
CREATE DATABASE store;
CREATE USER store_user WITH PASSWORD 'store_password';
GRANT ALL PRIVILEGES ON DATABASE store TO store_user;

\c store

GRANT USAGE, CREATE ON SCHEMA public TO store_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO store_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO store_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON TABLES TO store_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON SEQUENCES TO store_user;
```

## Шаг 10. Количество проданных сосисок за прошлую неделю

```sql
SELECT o.date_created, SUM(op.quantity)
FROM orders AS o
JOIN order_product AS op ON o.id = op.order_id
WHERE o.status = 'shipped'
  AND o.date_created >= (date_trunc('week', CURRENT_DATE)::date - INTERVAL '1 week')
  AND o.date_created < date_trunc('week', CURRENT_DATE)::date
GROUP BY o.date_created
ORDER BY o.date_created;
```

---

## Шаг 11. Сравнение до/после индексов

### Запрос

```sql
EXPLAIN ANALYZE
SELECT
    o.date_created AS order_date,
    SUM(op.quantity) AS total_sausages
FROM orders o
JOIN order_product op ON op.order_id = o.id
WHERE o.date_created >= (date_trunc('week', CURRENT_DATE)::date - INTERVAL '1 week')
  AND o.date_created < date_trunc('week', CURRENT_DATE)::date
GROUP BY o.date_created
ORDER BY o.date_created;
```

---

### До создания индексов

**Время выполнения: `41 272 мс (~41 сек)`**

```
Finalize GroupAggregate  (cost=386562.10..386585.16 rows=91 width=12) (actual time=41165.003..41222.560 rows=7 loops=1)
  Group Key: o.date_created
  ->  Gather Merge  (cost=386562.10..386583.34 rows=182 width=12) (actual time=41164.987..41222.541 rows=21 loops=1)
        Workers Planned: 2
        Workers Launched: 2
        ->  Sort  (cost=385562.08..385562.31 rows=91 width=12) (actual time=41146.626..41146.708 rows=7 loops=3)
              Sort Key: o.date_created
              Sort Method: quicksort  Memory: 25kB
              ->  Partial HashAggregate  (cost=385558.21..385559.12 rows=91 width=12) (actual time=41146.595..41146.678 rows=7 loops=3)
                    Group Key: o.date_created
                    ->  Parallel Hash Join  (cost=225442.80..383976.29 rows=316385 width=8) (actual time=38589.132..41111.607 rows=258889 loops=3)
                          Hash Cond: (op.order_id = o.id)
                          ->  Parallel Seq Scan on order_product op  (cost=0.00..105361.13 rows=4166613 width=12) (actual time=1.483..20341.099 rows=3333333 loops=3)
                          ->  Parallel Hash  (cost=219942.98..219942.98 rows=316385 width=12) (actual time=17377.965..17377.966 rows=258889 loops=3)
                                Buckets: 262144  Batches: 8  Memory Usage: 6656kB
                                ->  Parallel Seq Scan on orders o  (cost=0.00..219942.98 rows=316385 width=12) (actual time=13.682..17301.225 rows=258889 loops=3)
                                      Filter: ((date_created < ...) AND (date_created >= ...))
                                      Rows Removed by Filter: 3074444
Planning Time: 45.714 ms
Execution Time: 41272.077 ms
```

> ⚠️ **Узкое место:** `Parallel Seq Scan on orders` — PostgreSQL перебирает все 10 000 000 строк таблицы, отфильтровывая 3 074 444 лишних. Индекса нет, поиск по дате идёт полным сканом.

---

### После создания индексов

**Время выполнения: `10 691 мс (~11 сек)`**

```
Finalize GroupAggregate  (cost=219623.38..219646.43 rows=91 width=12) (actual time=9655.718..10672.244 rows=7 loops=1)
  Group Key: o.date_created
  ->  Gather Merge  (cost=219623.38..219644.61 rows=182 width=12) (actual time=9655.689..10672.212 rows=21 loops=1)
        Workers Planned: 2
        Workers Launched: 2
        ->  Sort  (cost=218623.36..218623.58 rows=91 width=12) (actual time=9633.141..9633.226 rows=7 loops=3)
              Sort Key: o.date_created
              Sort Method: quicksort  Memory: 25kB
              ->  Partial HashAggregate  (cost=218619.49..218620.40 rows=91 width=12) (actual time=9633.096..9633.182 rows=7 loops=3)
                    Group Key: o.date_created
                    ->  Parallel Hash Join  (cost=58501.37..217037.54 rows=316389 width=8) (actual time=8847.797..9579.295 rows=258889 loops=3)
                          Hash Cond: (op.order_id = o.id)
                          ->  Parallel Seq Scan on order_product op  (cost=0.00..105361.67 rows=4166667 width=12) (actual time=0.037..5215.179 rows=3333333 loops=3)
                          ->  Parallel Hash  (cost=53001.51..53001.51 rows=316389 width=12) (actual time=2072.582..2072.582 rows=258889 loops=3)
                                Buckets: 262144  Batches: 8  Memory Usage: 6656kB
                                ->  Parallel Index Only Scan using idx_orders_date_created_id on orders o  (cost=0.46..53001.51 rows=316389 width=12) (actual time=17.295..2020.375 rows=258889 loops=3)
                                      Index Cond: ((date_created >= ...) AND (date_created < ...))
                                      Heap Fetches: 92775
Planning Time: 23.151 ms
Execution Time: 10690.786 ms
```

> ✅ **Улучшение:** `Parallel Index Only Scan using idx_orders_date_created_id` — PostgreSQL использует индекс и сразу находит нужный диапазон дат, не сканируя всю таблицу.

---

### Итог

| Метрика                  | До индексов     | После индексов  |
|--------------------------|-----------------|-----------------|
| Время выполнения         | 41 272 мс       | 10 691 мс       |
| Planning Time            | 45.714 мс       | 23.151 мс       |
| Метод доступа к `orders` | Seq Scan        | Index Only Scan |
| Отфильтровано лишних строк | 3 074 444     | 0               |

**Вывод:** время выполнения сократилось с ~41 000 мс до ~10 700 мс — **ускорение в ~3.9 раза**. PostgreSQL перестал делать полный перебор таблицы `orders` и начал использовать индекс `idx_orders_date_created_id` для точного поиска по диапазону дат.

/* Проект первого модуля: анализ данных для агентства недвижимости
 * Часть 2. Решаем ad hoc задачи
 * 
 * Автор:Жигарева Виктория
 * Дата: 14.12.2025
*/



-- Задача 1: Время активности объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS(
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
-- Найдем все объявления из городов и категоризируем их по продолжительности размещения
all_region_and_segment as (
select
case 
	when f.city_id='6X8I' then 'Cанкт_Петербург'
	when f.city_id<>'6X8I' then 'ЛенОбл'
end as регион,
case 
	when a.days_exposition between 1 and 30 then 'меньше месяца'
	when a.days_exposition between 31 and 90 then  'до 3 месяцев'
	when a.days_exposition between 91 and 180 then  'до полугода'
	when a.days_exposition>180 then 'более полугода'
	else 'non category'
end as сегмент_активности, 
f.id,
a.last_price,
f.total_area,
f.living_area,
f.ceiling_height,
f.rooms,
f.balcony,
f.floors_total
from real_estate.flats as f
left join real_estate.advertisement as a on f.id=a.id
where f.id IN (SELECT * FROM filtered_id) and f.type_id='F8EM' and EXTRACT(year from a.first_day_exposition) between 2015 and 2018)
-- Выведем финальным запрос с группировкой по категориям
select регион, сегмент_активности, 
COUNT(id) as "количество объявлений",
ROUND(COUNT(id)*1.0/(select COUNT(id) from all_region_and_segment),2) as "доля объявлений от общего числа",
ROUND(AVG(last_price/total_area)) as "средняя цена кв м", 
ROUND(AVG(total_area)) as "средняя общая площадь",
ROUND(AVG(living_area)) as "средняя жилая площадь",
ROUND(AVG(ceiling_height)) as "средняя высота потолка",
PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY rooms) as "медиана кол-ва комнат",
PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY balcony) as "медиана кол-во балконов",
PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY floors_total) as "медиана этажности"
from all_region_and_segment
group by регион, сегмент_активности

-- Задача 2: Сезонность объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS(
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
--- данные по месяцем активности
month_activity as (
select f.id, f.total_area,
EXTRACT(month from a.first_day_exposition) as "месяц публикации",
EXTRACT(month from (a.first_day_exposition+(a.days_exposition*interval '1 day'))) as "месяц продажи",
last_price/total_area as "цена кв м",
a.first_day_exposition
from real_estate.flats as f
left join real_estate.advertisement as a on f.id=a.id
where f.id IN (SELECT * FROM filtered_id) and f.type_id='F8EM' and EXTRACT(year from a.first_day_exposition) between 2015 and 2018),
-- данные по месяцу публикации
month_published as (
select "месяц публикации",
COUNT(id) as "кол-во опубликованных объявлений",
ROUND(COUNT(id)*1.0/(select COUNT(id) from month_activity),2) as "доля объявлений от общего числа (опуб)",
ROUND(AVG("цена кв м")::numeric,2) as "средняя цена за  кв м (опуб)",
ROUND(AVG(total_area)::numeric,2) as "средняя общая площадь(опуб)"
from month_activity
group by "месяц публикации"),
-- данные по месяцу продажи
month_sale as (
select "месяц продажи",
COUNT(id) as "кол-во снятых объявлений",
ROUND(COUNT(id)*1.0/(select COUNT(id) from month_activity),2) as "доля объявлений от общего числа (снятые)",
ROUND(AVG("цена кв м")::numeric,2) as "средняя цена за  кв м (снятые)",
ROUND(AVG(total_area)::numeric,2) as "средняя общая площадь (снятые)"
from month_activity 
where first_day_exposition is not NULL
group by "месяц продажи")
-- итоговая статистика 
select coalesce("месяц публикации", "месяц продажи") as "месяц", 
"кол-во опубликованных объявлений", 
"кол-во снятых объявлений",
"доля объявлений от общего числа (опуб)",
"доля объявлений от общего числа (снятые)",
"средняя цена за  кв м (опуб)",
"средняя цена за  кв м (снятые)",
"средняя общая площадь(опуб)",
"средняя общая площадь (снятые)"
from month_published as mp
left join month_sale as ms on mp."месяц публикации"=ms."месяц продажи"
order by "месяц"


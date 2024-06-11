/* 
PostgreSQL 16
Данный запрос предназначен для расчета DAU, DAU сглаженного скользящим средним и DAU сглаженного скользящей медианой онлайн школы с 1 января 2024г.
Таблица userentry содержит информацию о входе пользователя на платформу - когда, 
в какое время и на какую страницу пользователь зашел первый раз за сутки.
Описание стобцов:
entry_at - дата и время входа на платформу
user_id - идентификатор пользователя (FK - Users)
 */

with agg as (
	select count(distinct user_id) as active_users, to_char(entry_at, 'YYYY-MM-DD') as date
	from userentry
	where entry_at >= '20240101'
	group by date
)
select 
date, active_users, Round(avg (active_users) over(), 2) as DAU,
Round(avg(active_users) over (order by date rows between unbounded preceding and current row), 2) as sliding_average,
(
	select percentile_cont(0.5) within group(order by a.active_users)
	from agg as a
	where a.date <= agg.date
) as sliding_median
from agg

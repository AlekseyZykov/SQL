/* 
PostgreSQL 16
Данный запрос предназначен для расчета MAU онлайн школы. Месяц берется в расчет, если в нем было 25 и более активных дней.
Таблица userentry содержит информацию о входе пользователя на платформу - когда, 
в какое время и на какую страницу пользователь зашел первый раз за сутки.
Описание стобцов:
entry_at - дата и время входа на платформу
user_id - идентификатор пользователя (FK - Users)
 */

with day_in_month as (
	select count(distinct user_id) as cnt_users, to_char(entry_at, 'YYYY-MM') as month
	from userentry
	group by month
	having count(distinct to_char(entry_at, 'YYYY-MM-DD')) >= 25
)
select 
Round(avg(cnt_users),0) as MAU
from day_in_month

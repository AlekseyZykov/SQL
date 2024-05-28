--PostgreSQL 16 

with day_in_month as (
	select count(distinct user_id) as cnt_users, to_char(entry_at, 'YYYY-MM') as month
	from userentry
	group by month
	having count(distinct to_char(entry_at, 'YYYY-MM-DD')) >= 25
)
select 
Round(avg(cnt_users),0) as MAU
from day_in_month

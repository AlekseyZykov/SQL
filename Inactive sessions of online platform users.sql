/*
PostgreSQL 16
Работа над вовлеченностью пользователей онлайн платформы.
Какой процент входов на платформу не сопровождается активностью?
Необходимо рассчитать % визитов, в которых человек зашел на платформу (есть запись в UserEntry за конкретный день), 
но не проявил активность (нет записей в CodeRun, CodeSubmit, TestStart за этот же день).
Важные моменты:
Входы пользователя на платформу смотрим в таблице UserEntry.
Запись в UserEntry делается только один раз в сутки для каждого юзера - в момент первого визита.
Когда человек отправляет код на Выполнение, делается запись в таблицу CodeRun.
Когда человек отправляет код на Проверку, делается запись в таблицу CodeSubmit.
Когда человек стартует тест, делается запись в таблицу TestStart.
*/
with activities as (
    select
        user_id,
        date(created_at) as dt
    from
        coderun c
    union
    select
        user_id,
        date(created_at) as dt
    from
        codesubmit c2
    union
    select
        user_id,
        date(created_at) as dt
    from
        teststart
),
cnt_none_active as (select count(u.user_id) as cnt_none_active
from userentry u 
where not exists (select * from activities a where u.user_id = a.user_id and u.entry_at::date = a.dt)
),
entry_users as (
	select count(user_id) as entry
	from userentry
)
select Round(100.0*cnt_none_active/entry,2)
from cnt_none_active, entry_users 

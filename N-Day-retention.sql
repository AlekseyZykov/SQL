/* 
PostgreSQL 16
Данный запрос предназначен для расчета N-DAY-retention 1, 3, 7, 14, 30, 60, и 90 дня в разрезе месячных когорт пользователей онлайн-школы за 2022 год. 
Сервис характеризуется подписной моделью бизнеса.
 
Таблица users содержит информацию о всех пользователях.
Описание стобцов:
id - уникальный идентификатор пользователя
date_joined - дата и время регистрации

Таблица userentry содержит информацию входе пользователя на платформу - когда, 
в какое время и на какую страницу пользователь зашел первый раз за сутки.
Описание стобцов:
id - уникальный идентификатор пользователя
entry_at - дата и время входа на платформу
user_id - идентификатор пользователя (FK - Users)
 */
--Объединяем пользователей в когорты по месяцу регистрации в 2022 году
with a as (
    select
        u.user_id,
        date(u.entry_at) as entry_at,
        date(u2.date_joined) as date_joined,
        extract(days from u.entry_at - u2.date_joined) as diff,
        to_char(u2.date_joined, 'YYYY-MM') as cohort
    from userentry u
    join users u2
    on u.user_id = u2.id
    where to_char(u2.date_joined, 'YYYY') = '2022'
)
--Для каждой когорты рассчитываем N-DAY-retention 1, 3, 7, 14, 30, 60, и 90 дня
select
    cohort,
    round(count(distinct case when diff >= 0 then user_id end) * 100.0 / count(distinct case when diff >= 0 then user_id end), 2) as "0 (%)",
    round(count(distinct case when diff >= 1 then user_id end) * 100.0 / count(distinct case when diff >= 0 then user_id end), 2) as "1 (%)",
    round(count(distinct case when diff >= 3 then user_id end) * 100.0 / count(distinct case when diff >= 0 then user_id end), 2) as "3 (%)",
    round(count(distinct case when diff >= 7 then user_id end) * 100.0 / count(distinct case when diff >= 0 then user_id end), 2) as "7 (%)",
    round(count(distinct case when diff >= 14 then user_id end) * 100.0 / count(distinct case when diff >= 0 then user_id end), 2) as "14 (%)",
    round(count(distinct case when diff >= 30 then user_id end) * 100.0 / count(distinct case when diff >= 0 then user_id end), 2) as "30 (%)",
    round(count(distinct case when diff >= 60 then user_id end) * 100.0 / count(distinct case when diff >= 0 then user_id end), 2) as "60 (%)",
    round(count(distinct case when diff >= 90 then user_id end) * 100.0 / count(distinct case when diff >= 0 then user_id end), 2) as "90 (%)"
from a
group by cohort


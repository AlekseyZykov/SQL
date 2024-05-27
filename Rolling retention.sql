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
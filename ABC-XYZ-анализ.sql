with agg_xyz as (
select 	
	dr_ndrugs as product,	
	to_char(dr_dat, 'YYYY-WW') as week,
	sum(dr_kol) as amount
from
	sales
group by
	product, week
),
agg_abc as (
select 
	dr_ndrugs as product, sum(dr_kol) as cnt, 
	SUM((dr_croz - dr_czak)*dr_kol - dr_sdisc) as profit,
	SUM(dr_croz*dr_kol-dr_sdisc) as revenue
from 
	sales s 
group by 
	product
),
abc as (
select 
	product, 
	case 
		when sum(cnt) over (order by cnt desc) / sum(cnt) over () <= 0.8 then 'A'
		when sum(cnt) over (order by cnt desc) / sum(cnt) over () <= 0.95 then 'B'
		else 'C'
	end as amount_abc,
		case 
		when sum(profit) over (order by profit desc) / (select sum(profit) from agg_abc) <= 0.8 then 'A'
		when sum(profit) over (order by profit desc) / (select sum(profit) from agg_abc) <= 0.95 then 'B'
		else 'C'
	end as profit_abc,
			case 
		when sum(revenue) over (order by revenue desc) / (select sum(revenue) from agg_abc) <= 0.8 then 'A'
		when sum(revenue) over (order by revenue desc) / (select sum(revenue) from agg_abc) <= 0.95 then 'B'
		else 'C'
	end as revenue_abc
from
	agg_abc
),
xyz as (
select 
	product, 
	case 
		when count(product) < 4 then null
		when stddev_samp(amount) / avg(amount) <= 0.1 then 'X'
		when stddev_samp(amount) / avg(amount) <= 0.25 then 'Y'
		else 'Z'
	end as xyz_sales
from
	agg_xyz
group by
	product
)
select 
	a.product, a.amount_abc, a.profit_abc, a.revenue_abc, x.xyz_sales
from
	abc a
join xyz x on a.product = x.product
order by product
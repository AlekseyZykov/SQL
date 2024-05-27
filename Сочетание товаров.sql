with cte as (
	select distinct s1.dr_apt, s1.dr_nchk, s1.dr_dat, s1.dr_ndrugs as product1, s2.dr_ndrugs as product2
	from sales s1
	join sales s2 on s1.dr_apt=s2.dr_apt and s1.dr_nchk = s2.dr_nchk and s1.dr_dat=s2.dr_dat
	where s1.dr_ndrugs < s2.dr_ndrugs
)
select product1, product2, count (product1 || product2) as cnt
from cte  
group by product1, product2
order by cnt desc
/* 
PostgreSQL 16
Данный запрос предназначен для анализа сочетаемости товаров региональной аптечной сети. Какой товар и как часто встречается одновременно с другими товарами в чеке.
Таблица sales содержит агрегированную информацию о продажах.
Описание стобцов:
dr_ndrugs - наименование товара
dr_apt - идентификатор аптеки
dr_nchk - идентификатор чека
dr_dat - дата чека
 */
--Формируем уникальные сочетания товаров
with cte as (
	select distinct s1.dr_apt, s1.dr_nchk, s1.dr_dat, s1.dr_ndrugs as product1, s2.dr_ndrugs as product2
	from sales s1
	join sales s2 on s1.dr_apt=s2.dr_apt and s1.dr_nchk = s2.dr_nchk and s1.dr_dat=s2.dr_dat
	where s1.dr_ndrugs < s2.dr_ndrugs
)
--Рассчитываем как часто товар встречается одновременно с другими товарами в чеке (сочетаемость)
select product1, product2, count (product1 || product2) as cnt
from cte  
group by product1, product2
order by cnt desc
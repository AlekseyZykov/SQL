--=================================================================
/* SQL Server 2022

Общее описание:
Проект представляет собой прототип базы данных простого интернет-магазина. 
Предлагается реализовать логику работы с БД в виде модулей на языке Transact SQL. 
Проект состоит из трех функциональных блоков: блок работы с заказами, блок для отображения информации, блок отчетов. 

Требование к обработке ошибок:
При возникновении ошибки, предусмотренной логикой процедуры - выполнение процедуры должно прекращаться.
*/

--=================================================================
-- Блок работы с заказами

---------------------------
-- Описание: Процедура просмотра заказа(ов) клиента
create or alter proc dbo.Orders_get
	@CustomerID int, -- ИД клиента, заказы которого необходимо вывести, если не задан или клиента не существует - выдается ошибка "Клиент не задан или не существует".
	@OrderID int = null, -- ИД заказа, который необходимо вывести, если не задан, то выводятся все заказы клиента, если задан, но заказа с таким ИД не существует, выводится ошибка "Неверно указан ИД заказа".
	@OrderDateStart datetime = null, -- Дата начала диапазона для поиска заказов по OrderDate. Параметр игнорируется, если задан ИД заказа.
	@OrderDateEnd datetime = null, -- Дата окончания диапазона для поиска заказов по OrderDate. Параметр игнорируется, если задан ИД заказа.
	@Status char(1) = null -- Статус заказов, которые необходимо вывести. Параметр игнорируется, если задан ИД заказа.
as
/*
Возвращаемый набор данных:
	OrderID,
	OrderDate,
	StatusName - расшифровка текущего статуса заказа: N – новый, A – активный, D – доставляется, F – обработан,
	CustomerName - ФИО клиента в формате "Фамилия Имя",
	CustomerPhone - телефон клиента,
	CustomerEmail - эл. адрес клиента,
	ManagerInfo - ФИО и телефон менеджера в формате "Фамилия Имя, телефон",
	ShipmentDate - дата доставки
	ShipmentAddressID - если указан, то адрес доставки в формате "Город, Улица, Дом, Квартира", если не указан, то прочерк
*/
IF @CustomerID is null or not exists (select * from dbo.Customers where CustomerID = @CustomerID)
begin
raiserror ('Клиент не задан или не существует', 11, 1);
return;
end
IF
@OrderID is not null and not exists (select o.OrderID from dbo.Orders o 
join dbo.Customers c on  o.CustomerID = c.CustomerID where o.CustomerID=@CustomerID and o.OrderID = @OrderID)
begin
raiserror ('Неверно указан ИД заказа', 11, 1);
return;
end
Select
	o.OrderID,
	o.OrderDate,
	case 
	when o.Status = 'N' then 'Новый'
	when o.Status = 'A' then 'Активный'
	when o.Status = 'D' then 'Доставляется'
	when o.Status = 'F' then 'Обработан'
	end as StatusName,
	concat_ws (' ', c.LastName, c.FirstName ) as CustomerName, 
	c.Phone as CustomerPhone,
	c.Email as CustomerEmail,
	ManagerInfo = m.LastName + ' ' + m.FirstName + ', ' + m.Phone,
	o.ShipmentDate,
	ISNULL(concat_ws (', ', ct.Name, a.Street, a.House, a.Apt), '-') as ShipmentAddress
	from
	dbo. Orders o
	join dbo.Customers c on c.CustomerID = o.CustomerID
	join dbo.Managers m on o.ManagerID = m.ManagerID
	join dbo.Address a on o.ShipmentAddressID = a.AddressID
	join dbo.City ct on ct.CityID = a.CityID
	where
	(@CustomerID = c.CustomerID and @OrderID = o.OrderID)
	or (@CustomerID = c.CustomerID and @OrderID is null and @OrderDateStart is null and @OrderDateEnd is null and @Status is null)
	or (@CustomerID = c.CustomerID and o.OrderDate >=@OrderDateStart and o.OrderDate <= @OrderDateEnd and @Status = o.Status); 
go

---------------------------
-- Описание: Процедура создания нового заказа, либо обновления существующего
create or alter proc dbo.Orders_save
	@CustomerID int, -- ИД клиента, если не задан или клиента не существует, выдается ошибка "Клиент не задан или не существует".
	@OrderID int = null out, -- ИД заказа, если не задан, то создается новый заказ, если задан, то обновляется в соответствии с переданным ИД, если ИД передан неверно, выдается ошибка - "Неверно указан ИД заказа".
	@OrderDate datetime, -- Дата создания заказа - при создании проставляется автоматически равной текущей, в дальнейшем не меняется
	@Status char(1), -- При создании автоматически проставляется статус N, при обновлении проставляется переданное значение. Статус может меняться только в порядке N -> A -> D -> F. В случае попытки обновить статус на предыдущий должна выдаваться ошибка "Статус заказа %переданный% не может быть изменен на %предыдущий%".
	@ManagerID int, -- ИД менеджера, при создании проставляется автоматически, выбирается менеджер с наименьшим числом активных заказов, при последующем обновлении проставляется из переданного значения.
	@ShipmentDate datetime, -- Дата доставки. При создании проставляется автоматически +3 дня от текущей. При изменении проставляется из передаваемого значения, но не может быть меньше трех дней от даты создания заказа.
	@ShipmentAddressID int -- Адрес доставки. Может быть не указан. Если адрес указан, но такого адреса не существует выдается ошибка "Неверно указан адрес".
as
/*
Возвращаемый набор данных:
	В параметре @OrderID int = null out - возвращается ИД созданного заказа. Если заказ обновляется, то процедура не возвращает ничего.
*/
IF @CustomerID is null or not exists (select * from dbo.Customers where CustomerID = @CustomerID)
begin
raiserror ('Клиент не задан или не существует', 11, 1);
return;
end
IF @OrderID is not null and not exists (select * from dbo.Orders o 
join dbo.Customers c on  o.CustomerID = c.CustomerID where o.CustomerID=@CustomerID and o.OrderID = @OrderID)
begin
raiserror ('Неверно указан ИД заказа', 11, 1);
return;
end
IF @ShipmentAddressID is not null and not exists (select * from dbo.Orders o 
join dbo.Address a on a.AddressID = o.ShipmentAddressID where @ShipmentAddressID = o.ShipmentAddressID)
begin
raiserror ('Неверно указан адрес', 11, 1);
return;
end
IF @OrderID is null 
begin
	set @Status = 'N'
	set @OrderDate = GETDATE()
	set @ShipmentDate = DATEADD(dd,3,GETDATE())
	set @ManagerID = (SELECT TOP (1) ManagerID from dbo.Orders group by ManagerID order by count(OrderID) asc)
	INSERT dbo.Orders (OrderDate, Status, CustomerID, ManagerID, ShipmentDate, ShipmentAddressID)
	Values (@OrderDate, @Status, @CustomerID, @ManagerID, @ShipmentDate, @ShipmentAddressID);
	Select SCOPE_IDENTITY() as NewOrderID
end;
IF @OrderID is not null and exists (select * from dbo.Orders o 
join dbo.Customers c on  o.CustomerID = c.CustomerID where o.CustomerID=@CustomerID and o.OrderID = @OrderID) and
@ShipmentDate < Dateadd(dd,3,(select OrderDate from dbo.Orders o where o.OrderID = @OrderID))
begin
raiserror ('Дата доставки не может быть меньше трех дней от даты создания заказа', 11, 1);
return;
end
IF @OrderID is not null and exists (select * from dbo.Orders o 
join dbo.Customers c on  o.CustomerID = c.CustomerID where o.CustomerID=@CustomerID and o.OrderID = @OrderID) and
(
(@Status in ('N', 'A','D') and (select Status from dbo.Orders o where o.OrderID = @OrderID)='F') or
(@Status in ('N', 'A') and (select Status from dbo.Orders o where o.OrderID = @OrderID) in ('D', 'F')) or
(@Status in ('N') and (select Status from dbo.Orders o where o.OrderID = @OrderID) in ('A', 'D', 'F') ))
begin
raiserror ('Статус заказа %i не может быть изменен на %s', 11, 1, @OrderID, @Status)
return;
end
UPDATE dbo.Orders 
set
CustomerID = @CustomerID,
[Status] = @Status,
ManagerID = @ManagerID,
ShipmentDate = @ShipmentDate,
ShipmentAddressID = @ShipmentAddressID
where
OrderID=@OrderID;
go

---------------------------
-- Описание: Процедура удаления заказа по его ИД
create or alter proc dbo.Orders_delete
	@OrderID int -- ИД заказа для удаления, если заказ не задан или задан несуществующий, возвращается ошибка "Заказ не задан или задан неверно."
as
/*
Условия удаления:
	При попытке удалить заказ в статусе "доставляется" или "обработан", процедура возвращает ошибку "Удаление заказа в статусе %статус% запрещено."
	При удалении заказа удаляются и все его позиции в таблице OrderDetails.

Возвращаемый набор данных: 
	ничего не возвращает
*/
IF @OrderID is null or not exists (select OrderID from dbo.Orders o where @OrderID=o.OrderID)
begin
raiserror ('Заказ не задан или задан неверно', 11,1)
return;
end
IF exists (select * from dbo.Orders o where o.OrderID = @OrderID) and
(select [Status] from dbo.Orders o where o.OrderID = @OrderID) in ('D', 'F')
begin
declare @Status char(1) = (Select [Status] from dbo.Orders o where o.OrderID = @OrderID); 
raiserror ('Удаление заказа в статусе %s запрещено', 11, 1, @Status)
return;
end;
Delete dbo.OrderDetails
where
OrderID = @OrderID;
Delete dbo.Orders
where
OrderID = @OrderID;
go

---------------------------
-- Описание: Процедура выводит все позиции для определенного заказа по ИД заказа
create or alter proc dbo.OrderDetails_get
	@OrderID int -- ИД заказа, если заказ не задан или задан несуществующий, возвращается ошибка "Заказ не задан или задан неверно."
as
/*
Возвращаемый набор данных: 
	OrderDetailID,
	ProductCategoryName - название категории товара,
	ProductName - название товара,
	Quantity - количество единиц товара,
	Price -- цена товара, выводится поле Price непосредственно из этой же таблицы dbo.OrderDetails,
	Cost - общая стоимость всех единиц товара
*/
IF @OrderID is null or not exists (select OrderID from dbo.OrderDetails where @OrderID=OrderID)
begin
raiserror ('Заказ не задан или задан неверно', 11,1)
return;
end
Select 
od.OrderDetailID,
pc.Name as ProductCategoryName,
p.Name as ProductName,
od.Quantity,
od.Price,
Cost = od.Quantity * od.Price
from
dbo.OrderDetails od
join Products p on p.ProductID = od.ProductID
join ProductCategory pc on pc.ProductCategoryID = p.ProductCategoryID
where
OrderID=@OrderID;
go

---------------------------
-- Описание: Процедура создает новую или обновляет существующую позицию заказа по ИД
create or alter proc dbo.OrderDetails_save
	@OrderDetailID int = null out, -- ИД позиции заказа, если не задан, создается новая позиция, если задан, обновляется заданная позиция, если задана несуществующая, то возвращается ошибка "Позиция заказа не найдена."
	@OrderID int, -- ИД заказа, если не задан или задан несуществующий, возвращается ошибка "Заказ не задан или задан неверно."
	@ProductID int, -- ИД товара, если не задан или задан несуществующий возвращается ошибка "Товар не найден."
	@Quantity int -- Количество товара. Не может быть не задано или меньше 0.
as
/*
Возвращаемый набор данных:
	@OrderDetailID int = null out - возвращается ИД созданной позиции заказа. Если позиция заказа обновляется, то процедура не возвращает ничего.

Условия создания позиции заказа:
	Если заказ не находится в статусе Новый - создавать позиции запрещено
	При создании в поле Price записывается соответствующая цена товара из таблицы Products поля Price.
	При этом, если на момент создания записи на данную категорию товаров распространяется скидка, то в поле Price записывается цена со скидкой от базовой цены из таблицы Products поля Price.

Условия обновления позиции заказа:
	Если заказ не находится в статусе Новый - корректировать позиции запрещено
	Поле Price не затрагивается при обновлении.
	Если в параметре @Quantity указывается 0, то позиция заказа удаляется.
*/
IF @OrderID is null or not exists (select OrderID from dbo.OrderDetails where @OrderID=OrderID)
begin
raiserror ('Заказ не задан или задан неверно', 11,1)
return;
end
IF (SELECT [Status] FROM dbo.Orders WHERE @OrderID=OrderID) <> 'N'
begin
declare @Status char(1) = (Select [Status] from dbo.Orders o where o.OrderID = @OrderID); 
raiserror ('Создавать или корректировать позицию в заказе со статусом %s запрещено', 11, 1, @Status)
return;
end
IF not exists (select ProductID from dbo.Products where @ProductID=ProductID)
begin
raiserror ('Товар не найден', 11,1)
return;
end
IF @Quantity <0 or @Quantity is null
begin
raiserror ('Количество товара не может быть не задано или меньше 0', 11,1)
return;
end
IF @OrderDetailID is not null and not exists (select OrderDetailID from dbo.OrderDetails where @OrderDetailID=OrderDetailID and @OrderID=OrderID)
begin
raiserror ('Позиция заказа не найдена', 11,1)
return;
end
IF @OrderDetailID is null
begin
declare @Price money
set @Price = ISNULL(
(select 
Price = p.Price - p.Price*d.DiscountPct/100 
from
dbo.Products p
join dbo.OrderDetails od on p.ProductID=od.ProductID
join dbo.Discounts d on d.ProductCategoryID=p.ProductCategoryID
join dbo.Orders o on o.OrderID=od.OrderID
where p.ProductID=@ProductID and o.OrderID=@OrderID and (o.OrderDate <d.DateEnd and o.OrderDate >= d.DateStart)),
(Select Price from dbo.Products where @ProductID=ProductID))
INSERT dbo.OrderDetails (OrderID, ProductID, Quantity, Price)
Values (@OrderID, @ProductID, @Quantity, @Price);
Select SCOPE_IDENTITY() as NewOrderDetailID;
end
IF @OrderDetailID is not null and exists (select OrderDetailID from dbo.OrderDetails where @OrderDetailID=OrderDetailID and @OrderID=OrderID) and @Quantity=0
begin
DELETE dbo.OrderDetails
where
OrderDetailID=@OrderDetailID;
end
IF @OrderDetailID is not null and exists (select OrderDetailID from dbo.OrderDetails where @OrderDetailID=OrderDetailID and @OrderID=OrderID)
begin
UPDATE dbo.OrderDetails 
set OrderID=@OrderID, ProductID = @ProductID, Quantity = @Quantity
where OrderDetailID = @OrderDetailID;
end
go

---------------------------
-- Описание: Процедура удаляет позицию заказа по ИД
create or alter proc dbo.OrderDetails_delete
	@OrderDetailID int -- ИД позиции заказа для удаления, если не задана или если задана несуществующая, то возвращается ошибка "Позиция заказа не найдена."
as
/*
	Условия удаления:
		Если заказ не находится в статусе Новый - удалять позиции запрещено
		Если удаляемая позиция последняя, то заказ удаляется целиком из таблицы Orders

	Возвращаемый набор данных:
		ничего не возвращает
*/
IF @OrderDetailID is not null and not exists (select OrderDetailID from dbo.OrderDetails where @OrderDetailID=OrderDetailID)
begin
raiserror ('Позиция заказа не найдена', 11,1)
return;
end
IF (SELECT [Status] FROM dbo.Orders o
join dbo.OrderDetails od on o.OrderID=od.OrderID
WHERE @OrderDetailID=OrderDetailID) <> 'N'
begin
declare @Status char(1) = (Select [Status] from dbo.Orders o 
join dbo.OrderDetails od on o.OrderID=od.OrderID
where @OrderDetailID=OrderDetailID); 
raiserror ('Удалять позицию в заказе со статусом %s запрещено', 11, 1, @Status)
return;
end
Create table #DeletedOrderDetails (DeletedOrderIDDetails int)
DELETE dbo.OrderDetails
output deleted.OrderID into #DeletedOrderDetails
where @OrderDetailID=OrderDetailID;
IF not exists (
Select DeletedOrderIDDetails from #DeletedOrderDetails dod
join dbo.OrderDetails od on od.OrderID = dod.DeletedOrderIDDetails)
begin
Delete dbo.Orders
from dbo.Orders o
join #DeletedOrderDetails dod on dod.DeletedOrderIDDetails=o.OrderID;
end
go

--=================================================================
-- Блок для отображения информации

---------------------------
-- Описание: Процедура выводит категории товаров с количеством товаров доступных в каждой категории
create or alter proc dbo.ProductCategory_get
	@ParentCategoryID int -- ИД родительской категории
as
/*
Возвращаемый набор данных:
	ProductCategoryID,
	ParentCategoryID,
	Name, -- название категории в формате "название родительской категории\название категории", если родительской категории нет, то выводится просто "название категории"
	ProductsQuantity - количество товаров в данной категории
*/
Select
pc.ProductCategoryID,
pc.ParentCategoryID,
ProductsQuantity = (select ProductID = count(ProductID) from dbo.Products p where pc.ProductCategoryID = p.ProductCategoryID),
Name = (select name from dbo.ProductCategory where ProductCategoryID = @ParentCategoryID) + ' / ' + Name
from
dbo.ProductCategory pc 
where pc.ParentCategoryID = @ParentCategoryID;
go
---------------------------
-- Описание: Процедура выводит товары доступные для заказа для их постраничного отображения.
create or alter proc dbo.Products_get
	@PageNumber int, -- номер страницы для постраничного вывода, должен быть больше 0, иначе ошибка "Страница не найдена."
	@ProductsOnPage int, -- количество товаров на странице, должен быть больше 0, иначе ошибка "Неверное количество товаров для отображения на странице."
	@ProductCategoryID int = null, -- ИД категории товара, если не задан или задан неверно, значение параметра при поиске игнорируется. Если задана категория, то возвращаются все товары данной категории, и все товары категорий, которые являются дочерними по отношению к заданной независимо от уровня вложенности.
	@BrandID int = null, -- ИД бренда товара, если не задан, значение параметра при поиске игнорируется, если задан несуществующий, то ошибка "Производитель не найден."
	@Name varchar(250) = null, -- Название товара для поиска. Если не задано, значение параметра при поиске игнорируется. Поиск по названию должен в том числе осуществляться по подстроке. Если значение в параметре @Name присутствует в любой части строки название товара, товар попадает в выборку. Минимальная длина для поиска 3 символа, если меньше, то поиск по подстроке не осуществляется.
	@PriceStart money = null, -- Начало диапазона для поиска по цене товара. Если не задано, значение параметра при поиске игнорируется.
	@PriceEnd money = null -- Окончание диапазона для поиска по цене товара. Если не задано, значение параметра при поиске игнорируется. Если окончание диапазона для поиска меньше начала диапазона, то ошибка "Неверно задан диапазон цен для поиска."
as
/*
Возвращаемый набор данных:
	ProductID,
	ProductCategoryID,
	ProductCategoryName - название категории товаров,
	BrandID,
	BrandName - название бренда,
	Name,
	Price,
	Color,
	Memory,
	SellStartDate

*/
IF @PageNumber <=0
begin
raiserror ('Страница не найдена.', 11, 1)
return;
end
IF @ProductsOnPage <=0
begin
raiserror ('Неверное количество товаров для отображения на странице.', 11, 1)
return;
end
IF @BrandID is not null and not exists (Select * from dbo.Brands where BrandID = @BrandID)
begin
raiserror ('Производитель не найден.', 11, 1)
return;
end
IF @PriceStart > @PriceEnd and @PriceStart is not null and @PriceEnd is not null
begin
raiserror ('Неверно задан диапазон цен для поиска.', 11, 1)
return;
end
Select 
p.ProductID,
p.ProductCategoryID,
pc.[Name] as ProductCategoryName,
p.BrandID,
b.[Name] as BrandName,
p.[Name],
p.Price,
p.Color,
p.Memory,
p.SellStartDate
from dbo.Products p
left join dbo.Brands b on p.BrandID=b.BrandID
join dbo.ProductCategory pc on p.ProductCategoryID=pc.ProductCategoryID
where 
((@BrandID is not null and @BrandID=p.BrandID)or @BrandID is null) and 
((@ProductCategoryID is not null and exists (select * from dbo.Products where @ProductCategoryID=p.ProductCategoryID) and @ProductCategoryID=p.ProductCategoryID) or @ProductCategoryID is null)
and ((@Name is not null and Len(@Name)>=3 and p.[Name] like '%'+@Name+'%')or @Name is null)
and((@PriceStart is not null and @PriceEnd is null and p.Price >=@PriceStart) or (@PriceStart is null and @PriceEnd is null) or(@PriceEnd is not null and @PriceStart is null and p.Price<=@PriceEnd) or (@PriceStart is not null and @PriceEnd is not null and p.Price >=@PriceStart and p.Price<=@PriceEnd))
Order by p.ProductID asc
offset (@PageNumber-1)*@ProductsOnPage rows fetch next @ProductsOnPage rows only;
go

--=================================================================
-- Блок отчетов

---------------------------
-- Отчет: наиболее лояльные клиенты
-- Описание: Отчет выводит сумму и количество всех заказов по клиенту, сортировка по убыванию стоимости заказов клиента.
create or alter proc dbo.Report_LoyalClients
	@DateStart datetime, -- дата начала отчетного периода, если не задано, отчет за весь период
	@DateEnd datetime -- дата окончания отчетного периода, если не задано, отчет за весь период. Если дата окончания периода меньше даты начала, ошибка "Неверно указан период отчета".
as
/*
Возвращаемый набор данных, сортировка по ФИО клиента:
	ClientName, -- Имя клиента в формате "Фамилия Имя"
	Year, -- Год
	Quarter, -- Номер квартала в году
	QuarterOrderSum -- сумма заказов клиента в квартале года
*/

IF @DateStart > @DateEnd
begin
raiserror ('Неверно указан период отчета.',11,1)
return;
end;
with LoyalClients
as
(
Select
CONCAT_WS(' ',(Select LastName from dbo.Customers c where c.CustomerID=o.CustomerID),(Select FirstName from dbo.Customers c where c.CustomerID=o.CustomerID)) as ClientName,
Year(o.OrderDate) as [Year],
Case 
when Month(o.OrderDate) in (1,2,3) then 1
when Month(o.OrderDate) in (4,5,6) then 2
when Month(o.OrderDate) in (7,8,9) then 3
when Month(o.OrderDate) in (10,11,12) then 4
end as [Quarter],
od.Quantity*od.Price as Total
from dbo.Orders o
join dbo.OrderDetails od on o.OrderID=od.OrderDetailID
Where
(@DateStart is not null and @DateEnd is not null and o.OrderDate>= @DateStart and o.OrderDate <= @DateEnd)
or (@DateStart is null or @DateEnd is null)
)
Select
ClientName,
[Year],
[Quarter],
QuarterOrderSum = SUM (Total)
from LoyalClients
group by
[ClientName],[Year], [Quarter]
Order By QuarterOrderSum desc, [ClientName] asc;
go

---------------------------
-- Отчет: по продажам.
-- Описание: сумма всех заказов по каждому кварталу по каждой категории с разницей предыдущего квартала.
create or alter proc dbo.Report_SalesByCategory
	@DateStart datetime, -- дата начала отчетного периода, если не задано, отчет за весь период
	@DateEnd datetime -- дата окончания отчетного периода, если не задано, отчет за весь период. Если дата окончания периода меньше даты начала, ошибка "Неверно указан период отчета".
as
/*
Возвращаемый набор данных, сортировка по году и кварталу:
	ProductCategoryName,
	Year, -- Год
	Quarter, -- Номер квартала в году
	QuarterOrderSum -- сумма заказов клиента в квартале года
	QuarterOrderSumDiff -- разница с предыдущим кварталом
*/
IF @DateStart > @DateEnd
begin
raiserror ('Неверно указан период отчета.',11,1)
return;
end;
with SalesByCategory 
as
(
Select
pc.[Name] as ProductCategoryName,
Year(o.OrderDate) as [Year],
Case 
when Month(o.OrderDate) in (1,2,3) then 1
when Month(o.OrderDate) in (4,5,6) then 2
when Month(o.OrderDate) in (7,8,9) then 3
when Month(o.OrderDate) in (10,11,12) then 4
end as [Quarter],
od.Quantity*od.Price as Total
from dbo.Orders o
join dbo.OrderDetails od on o.OrderID=od.OrderDetailID
join dbo.Products p on od.ProductID=p.ProductID
join dbo.ProductCategory pc on p.ProductCategoryID = pc.ProductCategoryID
Where
(@DateStart is not null and @DateEnd is not null and o.OrderDate>= @DateStart and o.OrderDate <= @DateEnd)
or (@DateStart is null or @DateEnd is null)
)
Select
ProductCategoryName,
[Year],
[Quarter],
QuarterOrderSum = SUM (Total),
QuarterOrderSumDiff = SUM (Total)- LAG(SUM (Total),1) over (Partition by [ProductCategoryName] Order by [Year], [Quarter])
from SalesByCategory
group by
[ProductCategoryName],[Year], [Quarter]
Order By [Year], [Quarter] asc;
go

---------------------------
-- Отчет: по продажам менеджеров 
-- Описание: сумма всех заказов по каждому менеджеру по месяцам
create or alter proc dbo.Report_SalesByManager
	@DateStart datetime, -- дата начала отчетного периода, если не задано, отчет за весь период
	@DateEnd datetime -- дата окончания отчетного периода, если не задано, отчет за весь период. Если дата окончания периода меньше даты начала, ошибка "Неверно указан период отчета".
as
/*
Возвращаемый набор данных, сортировка по ФИО менеджера:
	ManagerName, -- имя менеджера в формате "Фамилия Имя"
	Year, -- год
	Month, -- название месяца
	MonthOrderSum -- сумма заказов за месяц
*/
IF @DateStart > @DateEnd
begin
raiserror ('Неверно указан период отчета.',11,1)
return;
end;
with SalesByManager
as
(
Select
CONCAT_WS(' ',(Select LastName from dbo.Managers m where m.ManagerID=o.ManagerID),(Select FirstName from dbo.Managers m where m.ManagerID=o.ManagerID)) as ManagerName,
Year(o.OrderDate) as [Year],
MONTH(o.OrderDate) as [Month],
Total = od.Quantity*od.Price
from
dbo.Orders o
join dbo.Managers m on m.ManagerID=o.ManagerID
join dbo.OrderDetails od on od.OrderID=o.OrderID
Where
(@DateStart is not null and @DateEnd is not null and o.OrderDate>= @DateStart and o.OrderDate <= @DateEnd)
or (@DateStart is null or @DateEnd is null)
)
Select
ManagerName,
[Year],
[MONTH],
MonthOrderSum = Sum(Total)
from
SalesByManager
group by
ManagerName,
[Year],
[MONTH]
Order by ManagerName asc;
go

---------------------------
-- Отчет: нарастающим итогом
-- Описание: нарастающий итог продаж по месяцам за определенный год
create or alter proc dbo.Report_SalesRunningTotal
	@Year int -- Год отчетного периода. Год должен быть задан в диапазоне от 2000 до 2050, иначе ошибка "Год отчета должен быть задан в диапазоне от 2000 до 2050".
as
/*
Возвращаемый набор данных, сортировка по году и месяцу:
	Year, -- год
	Month, -- название месяца
	MonthRunningTotal -- нарастающий итог по месяцам года
*/
IF @Year < 2000 and @Year > 2050
begin
raiserror ('Год отчета должен быть задан в диапазоне от 2000 до 2050.',11,1)
return;
end;
with SalesRunningTotal
as
(
Select
Year(o.OrderDate) as [Year],
MONTH(o.OrderDate) as [Month],
Total = SUM(od.Quantity*od.Price)
from
dbo.Orders o
join dbo.OrderDetails od on od.OrderID=o.OrderID
Where
@Year = Year(o.OrderDate)
group by
Year(o.OrderDate),
MONTH(o.OrderDate)
)
Select
[Year],
[Month],
MonthRunningTotal = SUM(Total) over (Partition by [Year] Order by [Year], [Month] rows between Unbounded preceding  and current row)
from SalesRunningTotal
Order by
[Year], [Month];
go

---------------------------
-- Отчет: по доставкам
-- Описание: Экспорт активных доставок на дату для курьерской службы.
create or alter proc dbo.Report_DeliveryService
	@Date date, -- день доставки
	@CityID int -- Город доставки. Если не задан или задан несуществующий, ошибка "Не указан город".
as
/*
Возвращаемый набор данных, сортировка по дате и времени доставки:
	ShipmentDate, -- дата и время доставки
	CityName, -- название города
	Address -- адрес доставки в формате "Улица, Дом, Квартира"

Условия формирования отчета:
	В отчет должны попадать только заказы со статусом "доставляются", датой доставки, совпадающей с днем доставки, и только те, для которых указан адрес.	
*/
IF @CityID is null or exists (select * from dbo.City where @CityID = CityID)
begin
raiserror ('Не указан город',11,1)
return;
end
Select
o.ShipmentDate,
c.Name as CityName,
Concat_ws(' ',(select Street from dbo.Address where CityID=@CityID),(select House from dbo.Address where CityID=@CityID),(select Apt from dbo.Address where CityID=@CityID)) as [Address]
from dbo.Orders o
join dbo.Address a on o.ShipmentAddressID=a.AddressID
join dbo.City c on c.CityID=a.CityID
where
o.Status = 'D' and @Date=o.ShipmentDate and exists(select * from dbo.Address a where @CityID=a.CityID and Street is not null and House is not null)
Order by o.ShipmentDate;
go
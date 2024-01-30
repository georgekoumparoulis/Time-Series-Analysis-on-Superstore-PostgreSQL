/*
Table creation
*/

create table superstore(
	Row_ID int,
	Order_ID varchar(50),
	Order_Date date,
	Ship_Date date,
	Ship_Mode varchar(50),
	Customer_ID varchar(50),
	Customer_Name varchar(50),
	Segment varchar(50),
	Country varchar(50),
	City varchar(50),
	State varchar(50),
	Postal_Code int,
	Region varchar(50),
	Product_ID varchar(50),
	Category varchar(50),
	Sub_Category varchar(50),
	Product_Name varchar(500),
	Sales real,
	Quantity int,
	Discount varchar(50),
	Profit real)
;

/*
Duplicate values search
*/

select 
	*
from 
	superstore as st
where 
	(select 
	 	count(*) 
	 from 
	 	superstore as nd
	 where 
	 	st.order_id = nd.order_id and 
	 	st.product_name = nd.product_name and 
	 	st.quantity = nd.quantity
	  )>1
;

		/* 2nd approach for duplicate values (faster)*/
select 
	*
from 
	superstore as st
join 
	superstore as nd
on 
	st.row_id != nd.row_id and
	st.order_id = nd.order_id and 
	st.product_name = nd.product_name and 
	st.quantity = nd.quantity
;

/*
Remove duplicate values
*/

delete 
from 
	superstore st
using 
	superstore nd
where 
	st.order_id = nd.order_id and 
	st.product_name = nd.product_name and 
	st.quantity = nd.quantity and 
	st.row_id>nd.row_id
;

/*
Initial price and relationship between discount and profit in percentage
*/

with cte as
	(
	select 
		product_id, 
		sales,
		discount,
		quantity, 
		profit,
		(sales/(1-cast(discount as numeric))) as initial_price,
		(sales - profit) as cost,
		((sales/(1-cast(discount as numeric))) - (sales - profit))as initial_profit,
		(sales/(1-cast(discount as numeric)))/quantity as initial_price_per_item,
		profit/quantity as profit_per_item, 
		sales/quantity as price, 
		(profit/quantity)/(sales/quantity) as profit_percentage, 
		(((sales/(1-cast(discount as numeric))) - (sales - profit))/quantity)/((sales/(1-cast(discount as numeric)))/quantity)as initial_profit_percentage,
		row_number() over(partition by product_id) as ind
	from 
		superstore
	)
select 
	product_id, 
	sales, 
    	initial_price, 
    	cost, 
    	initial_profit, 
    	initial_price_per_item, 
    	initial_profit_percentage, 
    	quantity, 
    	discount, 
    	profit, 
    	profit_per_item, 
    	price, 
    	profit_percentage
from 
	cte
where 
	ind = 1
order by 
	product_id
;

/*
Table creation for profitpercentage per item to join with initial table to validate calculations 
about discounts and profit
*/

create table profit_product_id(
				product_id2 varchar(50),
				profitpercentage real
   			       )
;

/*
Unique values of produtc_ids and respectively profit percentage into new table
*/

insert into 
	profit_product_id (product_id2, profitpercentage)
with cte_a as
	(
	select
		product_id,
		(((sales/(1-cast(discount as numeric))) - (sales - profit))/quantity)/((sales/(1-cast(discount as numeric)))/quantity) as initial_profit_percentage,
		row_number() over(partition by product_id) as dml
	from 
		superstore
	)
select 
	product_id, 
	initial_profit_percentage
from 
	cte_a
where 
	dml = 1
;

/*
Validation on profit per discount and profit percentage and per metric volume
*/

with cte_b as
	(
	select 
		*, 
		round(cast(((initial_profit)-(initial_price * cast(discount as numeric))) as numeric), 1) as profit2,
		case 
			when round(cast(((initial_profit)-(initial_price * cast(discount as numeric))) as numeric), 1) - round(cast(profit as numeric), 1) < 0.5
			then 'num ok'
			else 'null'
		end as num_check
	from(
		select *,
			((sales/(1-cast(discount as numeric))) - (sales - profit))as initial_profit,
			(sales/(1-cast(discount as numeric))) as initial_price,
			case 
				when profit < 0 and cast(discount as numeric) > profitpercentage
				then 'Correct'
				when profit < 0 and cast(discount as numeric) < profitpercentage
				then 'Error'
				when profit >= 0
				then 'Ok'
				else 'null'
			end as discount_check
		from 
			superstore
		join 
			profit_product_id
		on superstore.product_id = profit_product_id.product_id2
		)as numcheck
	)
select 
	row_id, 
	order_id, 
    	order_date, 
   	ship_date, 
    	ship_mode, 
	customer_id, 
    	customer_name,
    	segment, 
    	country, 
    	city, 
    	state, 
    	postal_code, 
    	region, 
    	product_id, 
    	category, 
    	sub_category, 
	product_name, 
	sales, 
	quantity, 
	discount, 
    	profit, 
    	round(cast(profitpercentage as numeric), 2) as profit_percentage, 
    	discount_check, 
    	num_check
from 
	cte_b
where 
	num_check = 'num ok' and 
	discount_check = 'Error'
;

/*
Remove values that are not validated
*/

delete 
from 
	superstore
where 
	row_id in (
				with cte_b as
					(
					select 
						*, 
						round(cast(((initial_profit)-(initial_price * cast(discount as numeric))) as numeric), 1) as profit2,
						case 
							when round(cast(((initial_profit)-(initial_price * cast(discount as numeric))) as numeric), 1) - round(cast(profit as numeric), 1) < 0.5
							then 'num ok'
							else 'null'
						end as num_check
					from(
						select *,
							((sales/(1-cast(discount as numeric))) - (sales - profit))as initial_profit,
							(sales/(1-cast(discount as numeric))) as initial_price,
							case 
								when profit < 0 and cast(discount as numeric) > profitpercentage
								then 'Correct'
								when profit < 0 and cast(discount as numeric) < profitpercentage
								then 'Error'
								when profit >= 0
								then 'Ok'
								else 'null'
							end as discount_check
						from 
							superstore
						join 
							profit_product_id
						on superstore.product_id = profit_product_id.product_id2
						)as numcheck
					)
				select 
					row_id
				from 
					cte_b
				where 
					num_check = 'num ok' and 
					discount_check = 'Error'
				) 
;

/*
Use of LEAD window function to create a two new columns sales_previous and sales_next that displays the sales of the previous and next row in the dataset.
*/

select 
	row_id, 
	order_id, 
	order_date, 
	ship_date, 
	ship_mode, 
	customer_id, 
	customer_name,
	segment, 
	country, 
	city, 
	state, 
	postal_code, 
	region, 
	product_id, 
	category, 
	sub_category, 
	product_name, 
	lead(sales, -1 ) over (order by order_date) as sales_previous,
	sales,
	lead(sales, 1 ) over (order by order_date) as sales_next,
	quantity, 
	discount, 
	profit
from 
	superstore
order by 
	order_date
;

/*
Dataset rankng based on sales in descending order with the use of rank function
*/

select
	rank() over(order by sales) as ranking,
	*
from 
	superstore
;

/*
Year and monthly sales averages
*/
			
		/* yearly average sales */
select
	distinct(extract(year from order_date)) as year,
	round(cast ((avg(sales) over(partition by extract(year from order_date))) as numeric), 2) as avg_year
from
	superstore
order by
	extract(year from order_date)
;

		/* monthly average sales */
select
	distinct(extract(month from order_date)) as month,
	round(cast ((avg(sales) over(partition by extract(month from order_date))) as numeric), 2) as avg_month
from
	superstore
order by
	extract(month from order_date)
;


/*
Discount Analysis
*/

			/*
			Discounts Analysis on two consecutive days
			*/

		/* day with max orders with previous and next dates */
select
	concat(extract(year from order_date),'-',extract(month from order_date),'-',dafter)as dateafter,
	order_date,
	concat(extract(year from order_date),'-',extract(month from order_date),'-',dbefore)as datebefore
from
	(select 
	 	(extract(day from odate) +1) as dafter, 
	 	(extract(day from odate) -1) as dbefore, 
	 	odate, 
	 	order_date
	from
	 	(select 
		 	order_date as odate, 
		 	count(order_date), 
		 	order_date
		from 
		 	superstore
		group by 
		 	order_date
		order by 
		 	count(order_date) desc
		limit 1) as initial_date
	) as extended_date
;

		/* selection between two specific dates */
select 
	count(order_date), 
	order_date
from 
	superstore
where 
	order_date ='2016-09-06' or 
	order_date = '2016-09-04'
group by 
	order_date
order by 
	count(order_date) desc
limit 1
;

			
select 
	category,
	sub_category,
    	order_date,
    	round((avg(cast(discount as numeric))),2),
    	lag(round((avg(cast(discount as numeric))),2)) over (partition by category, sub_category order by order_date ) AS previous_day_discount,
    	(round((avg(cast(discount as numeric))),2)) - lag(round((avg(cast(discount as numeric))),2)) over (partition by category, sub_category order by order_date) AS discount_change
from 
    	superstore
where
	order_date between '2016-09-04' and '2016-09-05' 
group by
	category, order_date, sub_category
order by
    	category, sub_category, order_date
;

			/*
			Further discount analysis
			*/
				
		/*preview discount per category and item count*/
select
	*
from(
	select
		category,
		count(category) as item_count,
		round((cast(discount as numeric)),1) as discount
	from
		superstore
	where
		discount != '0.0'
	group by
		category,
		discount
	union
	select
		category,
		count(category),
		round((cast(discount as numeric)),1)
	from
		superstore
	where
		discount = '0.0'
	group by
		category,
		discount) as count_per_category
order by
	category,
	discount
;				
				
		/*preview of the discount per category*/
do $$
declare 
	disc numeric;
	item_type varchar;
	outcome numeric;
begin
	for disc in
		select
			distinct(cast(discount as numeric))
		from
			superstore
		order by 
			cast(discount as numeric)	
	loop 
		for item_type in
			select
				distinct(category)
			from superstore
		loop 
			for outcome in
				select
					count(category)
				from
					superstore
				where
					cast(discount as numeric) = disc and category = item_type
			loop
				raise notice 'discount % for category % counting % sales', disc, item_type, outcome;
			end loop;
		end loop;
	end loop;
end $$
;


		/*table creation and initial zero values for discount per category file*/
create table 
		pd_discount(
				pmkey numeric,
				discpercentage numeric,
				furniture varchar(50),
				office_supplies varchar(50),
				technology varchar(50))
;

insert into 
		pd_discount(
				pmkey,
				discpercentage, 
				furniture, 
				office_supplies, 
				technology)
values(1,0,0,0,0),
      (2,0,0,0,0),
      (3,0,0,0,0),
      (4,0,0,0,0),
      (5,0,0,0,0),
      (6,0,0,0,0),
      (7,0,0,0,0),
      (8,0,0,0,0),
      (9,0,0,0,0),
      (10,0,0,0,0),
      (11,0,0,0,0),
      (12,0,0,0,0)
;
		/*table update with discount values and infos*/
do $$
declare 
	disc numeric;
	rtnum integer := 0;
begin
	for disc in
		select 
			distinct(cast(discount as numeric))
		from
			superstore
		order by 
			cast(discount as numeric)	
	loop rtnum := rtnum + 1;
		update 
			pd_discount
		set 
			discpercentage = disc,
			furniture = (select count(category) from superstore where category = 'Furniture' and cast(discount as numeric) = disc),
			office_supplies = (select count(category) from superstore where category = 'Office Supplies' and cast(discount as numeric) = disc),
			technology = (select count(category) from superstore where category = 'Technology' and cast(discount as numeric) = disc)
		where 
			pmkey = rtnum;
	end loop;
end $$
;

select 
	*
from 
	pd_discount
;

		/*Total count orders and ammount spent with avg discount per customer_id*/
select
	customer_id,
	count(order_id) as count_orders,
	round(avg(cast(discount as numeric)),3) as avg_discount,
	sum(sales) as total_sale
from
	superstore
group by
	customer_id
order by
	sum(sales) desc
;

		/*avg discount per sub_category per category*/
		/* the value '*****' can be Furniture or Office Supplies or Technology */
select 
	*
from(
	select 
		count(*) as num_of_items, 
		sub_category, 
		round(avg(cast(discount as numeric)),1) as avg_discount
	from(
		select 
			discount, 
			sub_category
		from 
			superstore
		where 
			category = 'Furniture') as category
	where 
		discount = '0.0'
	group by 
		sub_category
	union
	select 
		count(*) as ct_without_shown_title, 
		sub_category, 
		round(avg(cast(discount as numeric)),1)
	from(
		select 
			discount, 
			sub_category
		from 
			superstore
		where 
			category = 'Furniture') as category2
	where 
		discount > '0.0'
	group by 
		sub_category) as discount_counting
order by 
	sub_category
;

		/*correlation coeffiecient between discount and profit*/
select 
	category,
	sub_category, 
	corr(cast(discount as numeric), profit) 
from 
	superstore
group by 
	category, 
	sub_category
;

		/*correlation coeffiecient between discount and sales*/
select 
	category,
	sub_category, 
	corr(cast(discount as numeric), sales) 
from 
	superstore
group by 
	category, 
	sub_category
;
		/*correlation coeffiecient between sales and profit*/
select 
	category,
	sub_category, 
	corr(sales, profit) 
from 
	superstore
group by 
	category, 
	sub_category
;

/*
Moving average on sales
*/

select
    sales,
    round(cast((avg(sales) over (order by order_date rows between 2 preceding and current row)) as numeric),3) as moving_average_sales
from
    superstore
;

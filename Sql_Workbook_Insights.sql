use project;
-- Table structure for table `dim_campaigns`

DROP TABLE IF EXISTS `dim_campaigns`;

CREATE TABLE `dim_campaigns` (
  `campaign_id` varchar(20) NOT NULL,
  `campaign_name` varchar(50) NOT NULL,
  `start_date` date NOT NULL,
  `end_date` date NOT NULL,
  PRIMARY KEY (`campaign_id`)
);

-- Table structure for table `dim_products`

DROP TABLE IF EXISTS `dim_products`;

CREATE TABLE `dim_products` (
  `product_code` varchar(10) NOT NULL,
  `product_name` varchar(255) NOT NULL,
  `category` varchar(50) NOT NULL,
  PRIMARY KEY (`product_code`)
) ;

-- Table structure for table `dim_stores`

DROP TABLE IF EXISTS `dim_stores`;
CREATE TABLE `dim_stores` (
  `store_id` varchar(15) NOT NULL,
  `city` varchar(50) NOT NULL,
  PRIMARY KEY (`store_id`)
) ;

-- Table structure for table `fact_events`

DROP TABLE IF EXISTS `fact_events`;
CREATE TABLE `fact_events` (
  `event_id` varchar(10) NOT NULL,
  `store_id` varchar(10) NOT NULL,
  `campaign_id` varchar(20) NOT NULL,
  `product_code` varchar(10) NOT NULL,
  `base_price` int NOT NULL,
  `promo_type` varchar(50) DEFAULT NULL,
  `quantity_sold(before_promo)` int NOT NULL,
  `quantity_sold(after_promo)` int NOT NULL
) ;

select * from dim_campaigns;
select * from dim_products;
select count(*) from dim_products;
select * from dim_stores;
select count(*) from dim_stores;
select * from fact_events;
select count(*) from fact_events;
Alter table fact_events 
rename COLUMN `quantity_sold(before_promo)` TO qty_before ;
Alter table fact_events
rename column `quantity_sold(after_promo)` to qty_after;

-- Insights
-- 1.List products priced over 500 and that are featured in promo type 'BOGOF' (Buy One Get One Free)
 select distinct p.product_name,f.base_price as price
 from fact_events f
 join dim_products p
 on f.product_code = p.product_code
 where f.promo_type= 'BOGOF' and f.base_price > 500;
 
-- 2.The number of stores in each city.

SELECT City,COUNT(store_id) as Total_Stores
FROM dim_stores
GROUP BY City
ORDER BY Total_Stores DESC;

-- 3.Promotional Campaign Revenue Analysis - Display total revenue generated before and after each promotional campaign.
  
  select 
     campaign_name,
     round(sum(f.base_price * qty_before)/1000000,0) 
     as total_revenue_before_promotion,
     round(sum(case 
               when promo_type ='BOGOF' then base_price * 0.5 * (qty_after * 2)
               when promo_type = '500 Cashback' then (base_price -500) * qty_after
               when promo_type = '50% OFF' then base_price * 0.5 * qty_after
               when promo_type = '33% OFF' then base_price * 0.67 * qty_after
               when promo_type = '25% OFF' then base_price * 0.75 * qty_after
               end)/1000000,0) as total_revenue_after_promotion
  from fact_events f
  join dim_campaigns c
  on f.campaign_id = c.campaign_id
  group by campaign_name;
  
  -- 4.Calculate Incremental Sold Quantity (ISU%) for each category during the Diwali campaign.

with Diwali_campaign_sale as (select category,
round(sum((case when promo_type = 'BOGOF' Then qty_after *2  else qty_after end ) -
          qty_before) *100 / sum(qty_before),0) as `ISU%`
from fact_events
join dim_products using(product_code)
join dim_campaigns using(campaign_id)
where campaign_name = 'Diwali'
group by category )

Select category,`ISU%`, row_number() over (order by `ISU%` desc) as Rank_Order
from Diwali_campaign_sale;
    
  -- 5. Identify the top 5 products ranked by Incremental Revenue Percentage (IR%) across all campaigns.
  
  select product_name,category,
   round((sum(case 
               when promo_type ='BOGOF' then base_price * 0.5 * (qty_after * 2)
               when promo_type = '500 Cashback' then (base_price -500) * qty_after
               when promo_type = '50% OFF' then base_price * 0.5 * qty_after
               when promo_type = '33% OFF' then base_price * 0.67 * qty_after
               when promo_type = '25% OFF' then base_price * 0.75 * qty_after
               else 0
               end) - sum(base_price * qty_before))*100 / sum(base_price * qty_before),0) as `IR%`
from fact_events 
inner join dim_products using(product_code)
group by product_name,category
order by `IR%` desc
limit 5 ;
/* =====================================================================
   PROJECT: Azure Cloud Cost Analysis
   TOOL   : MySQL 8.0
   DATA   : cost-analysis.csv (89 rows, May 2023 - Apr 2024, 10 services)
   SECTIONS:  1 Clean and check | 2 Analysis | 3 Budget variance
             4 Key findings
   ===================================================================== */
use cloud_cost;

-- =====================================================================
-- SECTION 1: CLEAN AND CHECK
-- =====================================================================
select count(*) as total_rows from cloud_cost;
 
select min(UsageDate) as first_month, max(UsageDate) as last_month,
count(distinct UsageDate) as months
from cloud_cost;
 
-- Missing values (expect 0)
select sum(UsageDate is null) as null_dates,
       sum(ServiceName is null or trim(ServiceName) = '') as null_services,
       sum(CostUSD is null) as null_costs
from cloud_cost;
 
-- Duplicate month + service rows (expect none)
select UsageDate, ServiceName, count(*) as n
from cloud_cost
group by UsageDate, ServiceName
having count(*) > 1;
 
-- Negative costs (expect none)
select * from cloud_cost where CostUSD < 0;
 
-- Implied exchange rate (Cost / CostUSD), should be stable around 82-83 INR per USD
select round(min(Cost / CostUSD), 2) as min_rate,
       round(max(Cost / CostUSD), 2) as max_rate,
       round(avg(Cost / CostUSD), 2) as avg_rate
from cloud_cost
where CostUSD > 0.01;   -- ignore near-zero rows where rounding distorts the rate
 
-- Whitespace in service names (expect 0)
select count(*) as dirty_names from cloud_cost where ServiceName <> trim(ServiceName);
 
-- =====================================================================
-- SECTION 2: ANALYSIS
-- =====================================================================
 
-- 3.1 Total spend
select round(sum(CostUSD), 2) as total_usd,
       round(sum(CostUSD) / count(distinct UsageDate), 2) as avg_monthly_usd
from cloud_cost;
 
-- 3.2 Spend and share by service
select ServiceName,
       round(sum(CostUSD), 2) as total_usd,
       round(sum(CostUSD) / (select sum(CostUSD) from cloud_cost) * 100, 2) as pct_of_total
from cloud_cost
group by ServiceName
order by total_usd desc;
 
-- 3.3 Cumulative share (Pareto): how many services make up 80% of spend?
with s as (
    select ServiceName, sum(CostUSD) as total_usd
    from cloud_cost
    group by ServiceName
)
select ServiceName,
       round(total_usd, 2) as total_usd,
       round(sum(total_usd) over (order by total_usd desc)
             / sum(total_usd) over () * 100, 2) as cumulative_pct
from s
order by total_usd desc;
 
-- 3.4 Monthly spend and month-over-month change
with monthly as (
    select UsageDate, sum(CostUSD) as monthly_usd
    from cloud_cost
    group by UsageDate
)
select UsageDate,
       round(monthly_usd, 2) as monthly_usd,
       round(lag(monthly_usd) over (order by UsageDate), 2) as prev_month_usd,
       round((monthly_usd - lag(monthly_usd) over (order by UsageDate))
             / lag(monthly_usd) over (order by UsageDate) * 100, 2) as mom_change_pct
from monthly
order by UsageDate;
 
-- 3.5 Spend by service per month (for a stacked chart)
select UsageDate, ServiceName, round(sum(CostUSD), 2) as cost_usd
from cloud_cost
group by UsageDate, ServiceName
order by UsageDate, cost_usd desc;
 
-- 3.6 Which service drove the latest rise? (latest month vs Dec 2023 - Feb 2024 average)
with monthly_service as (
    select ServiceName, UsageDate, sum(CostUSD) as cost_usd
    from cloud_cost
    group by ServiceName, UsageDate
),
baseline as (
    select ServiceName, avg(cost_usd) as baseline_usd
    from monthly_service
    where UsageDate between '2023-12-01' and '2024-02-01'
    group by ServiceName
),
latest as (
    select ServiceName, cost_usd as latest_usd
    from monthly_service
    where UsageDate = (select max(UsageDate) from cloud_cost)
)
select l.ServiceName,
       round(b.baseline_usd, 2) as baseline_usd,
       round(l.latest_usd, 2)   as latest_usd,
       round(l.latest_usd - b.baseline_usd, 2) as increase_usd
from latest l
join baseline b on l.ServiceName = b.ServiceName
order by increase_usd desc;
 
-- =====================================================================
-- SECTION 3: BUDGET VARIANCE (ASSUMED BUDGET)
-- The source data has no budget column, so this uses an ASSUMED monthly
-- budget to demonstrate variance analysis. Change the figure as needed.
-- =====================================================================
create table monthly_budget (
    UsageDate  date primary key,
    budget_usd decimal(10,2)
);
 
insert into monthly_budget (UsageDate, budget_usd)
select distinct UsageDate, 350.00      -- assumed budget per month
from cloud_cost;
 
select c.UsageDate,
       round(c.actual_usd, 2) as actual_usd,
       b.budget_usd,
       round(c.actual_usd - b.budget_usd, 2) as variance_usd,
       round((c.actual_usd - b.budget_usd) / b.budget_usd * 100, 2) as variance_pct,
       case when c.actual_usd > b.budget_usd then 'Over budget' else 'Within budget' end as status
from (select UsageDate, sum(CostUSD) as actual_usd
      from cloud_cost
      group by UsageDate) c
join monthly_budget b on c.UsageDate = b.UsageDate
order by c.UsageDate;
 
-- Cumulative actual vs cumulative budget
select c.UsageDate,
       round(sum(c.actual_usd) over (order by c.UsageDate), 2) as cumulative_actual,
       sum(b.budget_usd)       over (order by c.UsageDate)     as cumulative_budget
from (select UsageDate, sum(CostUSD) as actual_usd
      from cloud_cost
      group by UsageDate) c
join monthly_budget b on c.UsageDate = b.UsageDate
order by c.UsageDate;
 
-- =====================================================================
-- SECTION 4: KEY FINDINGS (see README for the full write-up)
-- 1. Total spend over 12 months: about USD 4,197 (about USD 350 per month).
-- 2. Storage (40.8%) and Bandwidth (36.9%) account for about 78% of spend.
-- 3. Spend rose in March and April 2024 (USD 403 and USD 442),
--    about 43% above February 2024 (USD 309). Run query 3.6 to see which services drove it.
-- 4. Several services (Automation, Logic Apps, Network Watcher) cost almost nothing.
-- =====================================================================
 
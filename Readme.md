# Azure Cloud Cost Analysis – SQL Project

SQL analysis of 12 months of Azure cloud spending in **MySQL 8.0**. The project checks data quality, finds where the money goes, tracks monthly trends, and compares actual spend with a budget.

## Project Overview
- **Data:** `cost-analysis.csv`, 89 rows covering May 2023 to Apr 2024 and 10 Azure services
- **Tool:** MySQL 8.0 (MySQL Workbench)
- **Script:** [`cloud_cost.sql`](cloud_cost.sql)

> The CSV file is not included in this repository. To run the script, import your own `cost-analysis.csv` (see *How to Run*).

## Table: `cloud_cost`
| Column | Description |
|---|---|
| `UsageDate` | First day of the billing month (DATE) |
| `ServiceName` | Azure service name |
| `Cost` | Cost in local currency (INR) |
| `CostUSD` | Cost in US dollars |

## What the Script Does

| Section | Content |
|---|---|
| **2. Clean and check** | Row count, date range, missing values, duplicate month + service rows, negative costs, exchange-rate stability, whitespace in service names |
| **3. Analysis** | Total and average monthly spend, spend and share by service, Pareto (cumulative %), month-over-month change, monthly spend by service, drivers of the latest rise |
| **4. Budget variance** | Monthly actual vs an **assumed** budget, variance in USD and %, cumulative actual vs cumulative budget |
| **5. Key findings** | Summary of results |

## SQL Skills Demonstrated
- Data quality checks (`NULL`, duplicates, negatives, `TRIM`)
- CTEs (`WITH`) and subqueries
- Window functions: `LAG()`, `SUM() OVER (...)`
- Aggregation with `GROUP BY` / `HAVING`
- Joins, `CASE` expressions, creating and populating tables

## Key Findings
- **Total spend:** about USD 4,197 over 12 months, an average of USD 349.75 per month.
- **Concentration:** Storage (40.8%) and Bandwidth (36.9%) make up about 78% of spend. Four services cost almost nothing (Automation, Logic Apps, Network Watcher and Azure DNS).
- **Recent increase:** Spend rose to USD 403 in March and USD 442 in April 2024, up about 43% from USD 309 in February.
- **What drove the rise** (April vs the Dec to Feb average):
  - **Backup:** about +USD 77. It had almost no cost until March.
  - **Storage:** about +USD 25
  - **Virtual Machines:** about +USD 22. It was USD 0 from December to March and returned in April.
  - **Bandwidth:** about +USD 8

## Budget Note
The source data has **no budget column**. Section 4 uses an **assumed** flat budget of USD 350 per month, which is close to the actual average, to demonstrate variance analysis. Replace it with a real budget to get meaningful over/under results.

## How to Run
1. Create the database and a `cloud_cost` table with the four columns above, with `UsageDate` as `DATE`.
2. Import `cost-analysis.csv` into the table (MySQL Workbench: *Table Data Import Wizard*).
3. Run `cloud_cost.sql` from top to bottom.

Requires MySQL 8.0 or later (window functions). Section 4 creates the `monthly_budget` table, so drop it first if you run the script again: `DROP TABLE IF EXISTS monthly_budget;`

## Author
**Roshna Assi**
[GitHub](https://github.com/RoshnaAssi21)

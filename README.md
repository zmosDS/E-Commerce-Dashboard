# Olist E-Commerce Analytics Dashboard

End-to-end e-commerce analytics project using PostgreSQL, SQL, Microsoft Fabric, and Power BI to analyze delivery performance, revenue trends, and customer behavior.

## Goal

The goal of this project is to build a practical BI workflow around a relational e-commerce dataset. The project covers database setup, SQL validation and analysis, reusable reporting views, semantic modeling, DAX measures, and a multi-page Power BI dashboard.

The analysis focuses on three areas:

- Delivery & Operations
- Revenue & Sales
- Customer Analysis

---

## Highlights

- Built a relational PostgreSQL database from the Olist e-commerce dataset
- Validated keys, missing values, order status distributions, and table grain before analysis
- Developed SQL analysis using joins, CTEs, conditional aggregation, window functions, ranking, and cohort logic
- Created reusable reporting views for Power BI
- Loaded reporting tables into Microsoft Fabric and built a semantic model with one-to-many relationships
- Created reusable DAX measures for delivery, revenue, and customer KPIs
- Built a three-page Power BI report covering fulfillment performance, sales trends, and customer behavior
- Excluded sparse 2016 activity from dashboard reporting to keep time-series analysis focused on the complete 2017–2018 period

---

## Built With

- PostgreSQL
- SQL
- Microsoft Fabric
- Power BI
- DAX
- Git / GitHub

---

## Analysis

### Delivery & Operations

Analyzes fulfillment performance and the relationship between delivery delays and customer satisfaction.

**Key metrics**
- On-Time Delivery %
- Late Delivery %
- Late Orders
- Average Delivery Days

**Analysis**
- Monthly late-delivery trends
- States with the highest late-delivery rates
- Severity of delivery delays
- High-volume seller delivery performance
- Review scores by delivery delay

### Revenue & Sales

Analyzes sales performance, product mix, geography, and seller contribution.

**Key metrics**
- Total Revenue
- Total Orders
- Average Order Value
- Units Sold

**Analysis**
- Monthly revenue trends
- Month-over-month revenue growth
- Revenue by product category
- Revenue by customer state
- Units sold by product category
- Seller revenue concentration

### Customer Analysis

Analyzes acquisition, repeat purchasing, customer value, and retention.

**Key metrics**
- Total Customers
- Repeat Customers
- Repeat Customer %
- Average Customer Spend

**Analysis**
- New customers by month
- One-time vs repeat customer behavior
- Average spend by customer type
- Average orders by customer type
- Time to second purchase
- Cohort retention

---

## SQL Techniques

- Multi-table joins
- Common table expressions (CTEs)
- Conditional aggregation
- Window functions
- `LAG()`
- `ROW_NUMBER()`
- Ranking
- Cumulative calculations
- Date analysis
- Customer-level aggregation
- Cohort analysis
- Data validation and table-grain checks

---

## Power BI

The Power BI report uses a semantic model built from reusable PostgreSQL reporting views loaded into Microsoft Fabric.

The model includes:

- Customer summary
- Order summary
- Order item detail
- Delivery reviews
- Date table
- Customer cohort table

DAX measures are stored in a dedicated KPI measures table and reused across dashboard pages.

### Dashboard Pages

1. Delivery & Operations
2. Revenue & Sales
3. Customer Analysis

**Live Dashboard:** Coming soon

---

## Data Notes

- Analysis begins in 2017 because 2016 contains sparse and incomplete order activity
- `customer_unique_id` is used to identify repeat customers across orders
- Order-item data is aggregated carefully to avoid double counting across different table grains
- Revenue is calculated from `order_items.price`
- Delivered orders are used for revenue and delivery-performance reporting

---

## Files

```text
E-Commerce Dashboard/
├── sql/
│   ├── 00_data_validation.sql
│   ├── 00_schema.sql
│   ├── 01_delivery_analysis.sql
│   ├── 02_revenue_analysis.sql
│   ├── 03_customer_analysis.sql
│   └── 04_reporting_views.sql
├── .gitignore
└── README.md

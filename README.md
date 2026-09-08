# Olist E-Commerce Analytics Dashboard

E-commerce analytics solution built with PostgreSQL, SQL, Power BI, and DAX to monitor sales performance, delivery issues, and customer behavior.

## Goal

Build an e-commerce reporting workflow that gives business users a clear view of sales performance, fulfillment issues, and customer behavior.

Raw transactional data is organized into reusable reporting tables and Power BI dashboards so key trends and problem areas can be monitored without repeatedly querying the source data.

## Dashboard Overview

### Delivery & Operations
Tracks on-time delivery, late-order trends, regional performance, delay severity, seller performance, and customer review impact.

### Revenue & Sales
Tracks revenue, order volume, average order value, product-category performance, geographic sales trends, and seller contribution.

### Customer Analysis
Tracks customer acquisition, repeat purchasing, customer spend, purchase frequency, and cohort retention.

## Built With

- PostgreSQL
- SQL
- Power BI
- DAX

## Reporting Workflow

- Loaded the Olist relational dataset into PostgreSQL
- Validated table relationships, missing values, and order status data
- Built reusable reporting views for orders, order items, customers, delivery reviews, dates, and cohorts
- Created a Power BI semantic model with reusable DAX measures
- Built a three-page dashboard for operations, sales, and customer reporting

## Dashboard

### Delivery & Operations
[Dashboard screenshot]

### Revenue & Sales
[Dashboard screenshot]

### Customer Analysis
[Dashboard screenshot]

**Live Dashboard:** Coming soon

## Data Notes

- Dashboard analysis begins in 2017 because 2016 contains sparse order activity
- `customer_unique_id` is used to identify repeat customers across orders
- Revenue is calculated from product sales in `order_items.price`
- Delivered orders are used for revenue and delivery-performance reporting

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
```

## Data Source

[Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)

The dataset contains approximately 100,000 orders across customers, sellers, products, payments, reviews, and delivery records.

Raw and exported CSV files are excluded from the repository due to file size.

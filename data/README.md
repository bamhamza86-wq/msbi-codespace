# Sample Data Files

This directory contains sample CSV data files for testing MSBI/SSIS ETL processes.

## Files Description

### customers.csv
Sample customer data including:
- Customer ID
- Name (First and Last)
- Contact information (Email, Phone)
- Location (City, Country)
- Registration Date

### products.csv
Sample product catalog data including:
- Product ID
- Product Name
- Category
- Price
- Stock quantity
- Supplier ID

### orders.csv
Sample order transaction data including:
- Order ID
- Customer ID (references customers)
- Product ID (references products)
- Quantity
- Order Date
- Total Amount
- Status

## Usage

These files can be used for:
1. Testing SSIS data import packages
2. Populating staging tables
3. ETL pipeline development
4. Data warehouse testing

## Loading Data

Use the SQL scripts in `/sql-scripts/` directory to load this data into SQL Server.

Example:
```bash
sqlcmd -S localhost -U sa -P Passw0rd123! -i sql-scripts/load-sample-data.sql -C
```

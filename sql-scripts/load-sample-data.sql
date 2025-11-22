-- Load Sample Data from CSV files
-- Note: This uses BULK INSERT which requires the CSV files to be accessible to SQL Server

USE [SampleDW];
GO

-- First, ensure tables are created
PRINT 'Loading sample data...';
GO

-- Clear existing data
TRUNCATE TABLE [dbo].[Orders];
DELETE FROM [dbo].[Products];
DELETE FROM [dbo].[Customers];
GO

-- Insert Customers
INSERT INTO [dbo].[Customers] (CustomerID, FirstName, LastName, Email, Phone, City, Country, RegistrationDate)
VALUES
    (1, 'Jean', 'Dupont', 'jean.dupont@example.fr', '+33123456789', 'Paris', 'France', '2024-01-15'),
    (2, 'Marie', 'Martin', 'marie.martin@example.fr', '+33123456790', 'Lyon', 'France', '2024-01-16'),
    (3, 'Pierre', 'Bernard', 'pierre.bernard@example.fr', '+33123456791', 'Marseille', 'France', '2024-01-17'),
    (4, 'Sophie', 'Dubois', 'sophie.dubois@example.fr', '+33123456792', 'Toulouse', 'France', '2024-01-18'),
    (5, 'Luc', 'Thomas', 'luc.thomas@example.fr', '+33123456793', 'Nice', 'France', '2024-01-19'),
    (6, 'Emma', 'Robert', 'emma.robert@example.fr', '+33123456794', 'Nantes', 'France', '2024-01-20'),
    (7, 'Julie', 'Petit', 'julie.petit@example.fr', '+33123456795', 'Strasbourg', 'France', '2024-01-21'),
    (8, 'Nicolas', 'Durand', 'nicolas.durand@example.fr', '+33123456796', 'Montpellier', 'France', '2024-01-22'),
    (9, 'Camille', 'Leroy', 'camille.leroy@example.fr', '+33123456797', 'Bordeaux', 'France', '2024-01-23'),
    (10, 'Antoine', 'Moreau', 'antoine.moreau@example.fr', '+33123456798', 'Lille', 'France', '2024-01-24');
GO

-- Insert Products
INSERT INTO [dbo].[Products] (ProductID, ProductName, Category, Price, Stock, SupplierID)
VALUES
    (101, 'Laptop Dell XPS', 'Electronics', 1299.99, 45, 1001),
    (102, 'iPhone 15 Pro', 'Electronics', 1199.99, 120, 1002),
    (103, 'Samsung Galaxy S24', 'Electronics', 999.99, 85, 1002),
    (104, 'Sony Headphones WH-1000XM5', 'Electronics', 399.99, 200, 1003),
    (105, 'MacBook Pro M3', 'Electronics', 2499.99, 30, 1001),
    (106, 'iPad Air', 'Electronics', 699.99, 150, 1002),
    (107, 'Logitech MX Master 3', 'Electronics', 99.99, 300, 1004),
    (108, 'Dell Monitor 27"', 'Electronics', 349.99, 75, 1001),
    (109, 'Mechanical Keyboard', 'Electronics', 149.99, 180, 1004),
    (110, 'Webcam Logitech C920', 'Electronics', 79.99, 220, 1004);
GO

-- Insert Orders
INSERT INTO [dbo].[Orders] (OrderID, CustomerID, ProductID, Quantity, OrderDate, TotalAmount, Status)
VALUES
    (1001, 1, 101, 1, '2024-01-25', 1299.99, 'Completed'),
    (1002, 2, 102, 2, '2024-01-26', 2399.98, 'Completed'),
    (1003, 3, 104, 1, '2024-01-27', 399.99, 'Completed'),
    (1004, 4, 107, 3, '2024-01-28', 299.97, 'Shipped'),
    (1005, 5, 103, 1, '2024-01-29', 999.99, 'Processing'),
    (1006, 6, 105, 1, '2024-01-30', 2499.99, 'Completed'),
    (1007, 7, 106, 2, '2024-01-31', 1399.98, 'Shipped'),
    (1008, 8, 108, 1, '2024-02-01', 349.99, 'Completed'),
    (1009, 9, 109, 1, '2024-02-02', 149.99, 'Processing'),
    (1010, 10, 110, 4, '2024-02-03', 319.96, 'Completed');
GO

-- Verify the data
PRINT 'Data loading complete!';
PRINT '';
PRINT 'Verification:';
SELECT 'Customers' AS TableName, COUNT(*) AS RecordCount FROM [dbo].[Customers]
UNION ALL
SELECT 'Products', COUNT(*) FROM [dbo].[Products]
UNION ALL
SELECT 'Orders', COUNT(*) FROM [dbo].[Orders];
GO

-- SQL Server Initialization Script
-- Run this on initial setup

-- Create sample database
CREATE DATABASE [SampleDW];
GO

USE [SampleDW];
GO

-- Create sample schema for ETL
CREATE SCHEMA [ETL];
GO

-- Create sample staging table (common in SSIS scenarios)
CREATE TABLE [ETL].[StagingCustomer] (
    CustomerID INT PRIMARY KEY,
    FirstName NVARCHAR(100),
    LastName NVARCHAR(100),
    Email NVARCHAR(100),
    CreatedDate DATETIME DEFAULT GETDATE()
);
GO

-- Create SSIS catalog (required for SSIS packages)
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Passw0rd123!';
GO

-- Create login for SSIS operations
CREATE LOGIN [ssis_user] WITH PASSWORD = 'Passw0rd123!';
GO
ALTER ROLE [dbcreator] ADD MEMBER [ssis_user];
GO

PRINT 'SQL Server initialization complete!';

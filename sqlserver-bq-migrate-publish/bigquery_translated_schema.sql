-- =========================================================================
-- BigQuery GoogleSQL DDL Schema (Translated from SQL Server)
-- =========================================================================

-- Create Customers Table
CREATE OR REPLACE TABLE dbo.Customers (
    CustomerID STRING NOT NULL,
    CompanyName STRING NOT NULL,
    ContactName STRING,
    ContactTitle STRING,
    Address STRING,
    City STRING,
    Region STRING,
    PostalCode STRING,
    Country STRING,
    Phone STRING,
    -- BigQuery uses NOT ENFORCED for primary keys (used for query optimization)
    PRIMARY KEY (CustomerID) NOT ENFORCED
);

-- Create Products Table
CREATE OR REPLACE TABLE dbo.Products (
    -- ProductID: Auto-increment IDENTITY(1,1) is removed (handled upstream/ETL)
    ProductID INT64 NOT NULL,
    ProductName STRING NOT NULL,
    SupplierID INT64,
    CategoryID INT64,
    QuantityPerUnit STRING,
    -- UnitPrice: MONEY mapped to NUMERIC
    UnitPrice NUMERIC DEFAULT 0 NOT NULL,
    -- UnitsInStock: SMALLINT mapped to INT64
    UnitsInStock INT64 DEFAULT 0 NOT NULL,
    UnitsOnOrder INT64 DEFAULT 0 NOT NULL,
    ReorderLevel INT64 DEFAULT 0 NOT NULL,
    -- Discontinued: BIT mapped to BOOL
    Discontinued BOOL DEFAULT FALSE NOT NULL,
    PRIMARY KEY (ProductID) NOT ENFORCED
);

-- Create Orders Table
CREATE OR REPLACE TABLE dbo.Orders (
    OrderID INT64 NOT NULL,
    CustomerID STRING,
    EmployeeID INT64,
    -- OrderDate: DATETIME is natively supported
    OrderDate DATETIME,
    RequiredDate DATETIME,
    ShippedDate DATETIME,
    ShipVia INT64,
    Freight NUMERIC DEFAULT 0,
    ShipName STRING,
    ShipAddress STRING,
    ShipCity STRING,
    ShipRegion STRING,
    ShipPostalCode STRING,
    ShipCountry STRING,
    PRIMARY KEY (OrderID) NOT ENFORCED,
    -- Informational Foreign Key (NOT ENFORCED)
    CONSTRAINT FK_Orders_Customers FOREIGN KEY (CustomerID) REFERENCES dbo.Customers (CustomerID) NOT ENFORCED
);

-- Create Order Details Table
CREATE OR REPLACE TABLE dbo.OrderDetails (
    OrderID INT64 NOT NULL,
    ProductID INT64 NOT NULL,
    UnitPrice NUMERIC DEFAULT 0 NOT NULL,
    Quantity INT64 DEFAULT 1 NOT NULL,
    -- Discount: REAL mapped to FLOAT64
    Discount FLOAT64 DEFAULT 0.0 NOT NULL,
    PRIMARY KEY (OrderID, ProductID) NOT ENFORCED,
    CONSTRAINT FK_OrderDetails_Orders FOREIGN KEY (OrderID) REFERENCES dbo.Orders (OrderID) NOT ENFORCED,
    CONSTRAINT FK_OrderDetails_Products FOREIGN KEY (ProductID) REFERENCES dbo.Products (ProductID) NOT ENFORCED
    -- Note: CHECK constraints are not supported in BigQuery and have been removed.
);

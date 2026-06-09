-- =========================================================================
-- SQL Server DDL Schema (Northwind Subset for BQ Migration Simulation)
-- =========================================================================

-- Create Customers Table
CREATE TABLE dbo.Customers (
    CustomerID NVARCHAR(5) NOT NULL,
    CompanyName NVARCHAR(40) NOT NULL,
    ContactName NVARCHAR(30) NULL,
    ContactTitle NVARCHAR(30) NULL,
    [Address] NVARCHAR(60) NULL,
    City NVARCHAR(15) NULL,
    Region NVARCHAR(15) NULL,
    PostalCode NVARCHAR(10) NULL,
    Country NVARCHAR(15) NULL,
    Phone NVARCHAR(24) NULL,
    CONSTRAINT PK_Customers PRIMARY KEY CLUSTERED (CustomerID ASC)
);

-- Create Products Table
CREATE TABLE dbo.Products (
    ProductID INT IDENTITY(1,1) NOT NULL,
    ProductName NVARCHAR(40) NOT NULL,
    SupplierID INT NULL,
    CategoryID INT NULL,
    QuantityPerUnit NVARCHAR(20) NULL,
    UnitPrice MONEY NOT NULL CONSTRAINT DF_Products_UnitPrice DEFAULT (0),
    UnitsInStock SMALLINT NOT NULL CONSTRAINT DF_Products_UnitsInStock DEFAULT (0),
    UnitsOnOrder SMALLINT NOT NULL CONSTRAINT DF_Products_UnitsOnOrder DEFAULT (0),
    ReorderLevel SMALLINT NOT NULL CONSTRAINT DF_Products_ReorderLevel DEFAULT (0),
    Discontinued BIT NOT NULL CONSTRAINT DF_Products_Discontinued DEFAULT (0),
    CONSTRAINT PK_Products PRIMARY KEY CLUSTERED (ProductID ASC)
);

-- Create Orders Table
CREATE TABLE dbo.Orders (
    OrderID INT IDENTITY(1,1) NOT NULL,
    CustomerID NVARCHAR(5) NULL,
    EmployeeID INT NULL,
    OrderDate DATETIME NULL,
    RequiredDate DATETIME NULL,
    ShippedDate DATETIME NULL,
    ShipVia INT NULL,
    Freight MONEY NULL CONSTRAINT DF_Orders_Freight DEFAULT (0),
    ShipName NVARCHAR(40) NULL,
    ShipAddress NVARCHAR(60) NULL,
    ShipCity NVARCHAR(15) NULL,
    ShipRegion NVARCHAR(15) NULL,
    ShipPostalCode NVARCHAR(10) NULL,
    ShipCountry NVARCHAR(15) NULL,
    CONSTRAINT PK_Orders PRIMARY KEY CLUSTERED (OrderID ASC),
    CONSTRAINT FK_Orders_Customers FOREIGN KEY (CustomerID) REFERENCES dbo.Customers (CustomerID)
);

-- Create Order Details Table
CREATE TABLE dbo.OrderDetails (
    OrderID INT NOT NULL,
    ProductID INT NOT NULL,
    UnitPrice MONEY NOT NULL CONSTRAINT DF_OrderDetails_UnitPrice DEFAULT (0),
    Quantity SMALLINT NOT NULL CONSTRAINT DF_OrderDetails_Quantity DEFAULT (1),
    Discount REAL NOT NULL CONSTRAINT DF_OrderDetails_Discount DEFAULT (0),
    CONSTRAINT PK_OrderDetails PRIMARY KEY CLUSTERED (OrderID ASC, ProductID ASC),
    CONSTRAINT FK_OrderDetails_Orders FOREIGN KEY (OrderID) REFERENCES dbo.Orders (OrderID),
    CONSTRAINT FK_OrderDetails_Products FOREIGN KEY (ProductID) REFERENCES dbo.Products (ProductID),
    CONSTRAINT CK_Quantity CHECK (Quantity > 0),
    CONSTRAINT CK_Discount CHECK (Discount >= 0 AND Discount <= 1)
);

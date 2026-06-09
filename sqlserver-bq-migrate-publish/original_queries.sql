-- =========================================================================
-- SQL Server Test Queries (Northwind Subset for BQ Migration Simulation)
-- =========================================================================

-- ==========================================
-- Query 1: Simple (Baseline Check)
-- ==========================================
-- Goal: Test column selections, string concatenation, and simple text filtering.
SELECT 
    CustomerID, 
    CompanyName, 
    City + ', ' + ISNULL(Region, '') + ' ' + Country AS FullAddress
FROM dbo.Customers
WHERE Country = 'Mexico';


-- ==========================================
-- Query 2: Medium (Joins & Date Operations)
-- ==========================================
-- Goal: Test joining two tables, date arithmetic, timezone calls, and conditional branching.
SELECT 
    o.OrderID,
    ISNULL(c.CompanyName, 'Walk-in Customer') AS CustomerName,
    o.OrderDate,
    DATEDIFF(day, o.OrderDate, o.ShippedDate) AS DaysToShip,
    CASE WHEN o.Freight > 50 THEN 'High Freight' ELSE 'Low Freight' END AS CostTier
FROM dbo.Orders o
LEFT JOIN dbo.Customers c ON o.CustomerID = c.CustomerID
WHERE o.OrderDate >= DATEADD(year, -5, GETDATE());


-- ==========================================
-- Query 3: Complex (CTEs, Window Functions, Money & Date Formatting)
-- ==========================================
-- Goal: Test multi-table joins, subqueries using CTEs, date truncation, window functions, and legacy data type casting.
WITH MonthlySales AS (
    SELECT 
        o.CustomerID,
        EOMONTH(o.OrderDate) AS SalesMonthEnd,
        od.ProductID,
        p.ProductName,
        CAST((od.Quantity * od.UnitPrice * (1.0 - od.Discount)) AS MONEY) AS NetSales
    FROM dbo.Orders o
    INNER JOIN dbo.OrderDetails od ON o.OrderID = od.OrderID
    INNER JOIN dbo.Products p ON od.ProductID = p.ProductID
)
SELECT 
    CustomerID,
    CONVERT(VARCHAR(10), SalesMonthEnd, 101) AS MonthEndFormatted,
    ProductName,
    SUM(NetSales) AS TotalAmount,
    RANK() OVER (
        PARTITION BY CustomerID, SalesMonthEnd 
        ORDER BY SUM(NetSales) DESC
    ) AS ProductRankWithinMonth
FROM MonthlySales
GROUP BY CustomerID, SalesMonthEnd, ProductName;


-- ==========================================
-- Query 4: SQL Server Specific Functions (STUFF, DATENAME)
-- ==========================================
-- Goal: Test 3-table join with complex formulas and SQL Server specific functions.
WITH OrderFreightAllocation AS (
    SELECT 
        o.OrderID,
        o.CustomerID,
        o.OrderDate,
        od.ProductID,
        (od.UnitPrice * od.Quantity * (1.0 - od.Discount)) AS LineNetSales,
        o.Freight / COUNT(od.ProductID) OVER(PARTITION BY o.OrderID) AS AllocatedFreight
    FROM dbo.Orders o
    INNER JOIN dbo.OrderDetails od ON o.OrderID = od.OrderID
)
SELECT 
    ofa.OrderID,
    ofa.ProductID,
    -- STUFF() masks the first 5 characters of the phone number
    STUFF(c.Phone, 1, 5, '(XXX) ') AS MaskedPhone,
    -- ISNULL() handles empty regions
    ISNULL(c.Region, 'N/A') AS CustomerRegion,
    -- DATENAME(weekday) returns full day name (e.g. 'Wednesday')
    DATENAME(weekday, ofa.OrderDate) AS DayOfWeekOrdered,
    CAST((ofa.LineNetSales + ofa.AllocatedFreight) AS MONEY) AS TotalLineCost
FROM OrderFreightAllocation ofa
INNER JOIN dbo.Customers c ON ofa.CustomerID = c.CustomerID;


-- ==========================================
-- Query 5: Cursor (Procedural Loop Logic)
-- ==========================================
-- Goal: Test row-by-row procedural looping structures.
DECLARE @ProdID INT;
DECLARE @ProdName NVARCHAR(40);
DECLARE @Stock SMALLINT;

-- Declare the cursor
DECLARE alert_cursor CURSOR FOR
SELECT ProductID, ProductName, UnitsInStock
FROM dbo.Products;

-- Open the cursor
OPEN alert_cursor;

-- Fetch the first row
FETCH NEXT FROM alert_cursor INTO @ProdID, @ProdName, @Stock;

-- Loop through all rows
WHILE @@FETCH_STATUS = 0
BEGIN
    IF @Stock < 15
    BEGIN
        PRINT 'WARNING: Product ' + @ProdName + ' (ID: ' + CAST(@ProdID AS VARCHAR) + ') is low on stock. Current level: ' + CAST(@Stock AS VARCHAR);
    END
    ELSE
    BEGIN
        PRINT 'Product ' + @ProdName + ' is healthy (' + CAST(@Stock AS VARCHAR) + ' units).';
    END

    -- Fetch the next row
    FETCH NEXT FROM alert_cursor INTO @ProdID, @ProdName, @Stock;
END;

-- Clean up
CLOSE alert_cursor;
DEALLOCATE alert_cursor;


-- ==========================================
-- Query 6: Advanced DML - MERGE (UPSERT)
-- ==========================================
-- Goal: Test SQL Server MERGE syntax, which requires terminating semicolons
-- and is used for matching source and target tables to perform updates or inserts.
MERGE dbo.Products AS target
USING (
    SELECT 1 AS ProductID, 'Chai Refreshed' AS ProductName, 45 AS UnitsInStock
) AS source
ON (target.ProductID = source.ProductID)
WHEN MATCHED THEN
    UPDATE SET 
        target.UnitsInStock = source.UnitsInStock, 
        target.ProductName = source.ProductName
WHEN NOT MATCHED THEN
    -- In SQL Server, ProductID is IDENTITY, so it is omitted from the INSERT list
    INSERT (ProductName, UnitsInStock) 
    VALUES (source.ProductName, source.UnitsInStock);


-- ==========================================
-- Query 7: Advanced SELECT - Temp Tables & Timezones
-- ==========================================
-- Goal: Test SQL Server local temp tables (prefixed with #) and date timezone shifting using AT TIME ZONE.
CREATE TABLE #TempOrders (
    OrderID INT,
    OrderDateUTC DATETIME,
    OrderDateLocal DATETIMEOFFSET
);

INSERT INTO #TempOrders (OrderID, OrderDateUTC, OrderDateLocal)
SELECT 
    OrderID, 
    OrderDate,
    -- Convert datetime to UTC, then shift to Eastern Standard Time (EST) offset
    OrderDate AT TIME ZONE 'UTC' AT TIME ZONE 'Eastern Standard Time'
FROM dbo.Orders;

SELECT * FROM #TempOrders;

DROP TABLE #TempOrders;


-- ==========================================
-- Query 8: Session Logic - Dynamic SQL
-- ==========================================
-- Goal: Test executing dynamically constructed SQL string via sp_executesql.
DECLARE @SQL NVARCHAR(MAX);
DECLARE @ParamDef NVARCHAR(500);
DECLARE @MinStock INT = 10;

SET @SQL = N'SELECT ProductID, ProductName FROM dbo.Products WHERE UnitsInStock >= @StockThreshold';
SET @ParamDef = N'@StockThreshold INT';

EXEC sp_executesql @SQL, @ParamDef, @StockThreshold = @MinStock;

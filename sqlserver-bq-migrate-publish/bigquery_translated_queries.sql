-- =========================================================================
-- BigQuery GoogleSQL Test Queries (Translated from SQL Server)
-- =========================================================================

-- ==========================================
-- Query 1: Simple (Baseline Check)
-- ==========================================
-- SQL Server: City + ', ' + ISNULL(Region, '') + ' ' + Country AS FullAddress
-- GoogleSQL: 
-- 1. Using CONCAT() function instead of '+' (which causes type coercion errors in BQ)
-- 2. Mapping ISNULL() to IFNULL()
SELECT 
    CustomerID, 
    CompanyName, 
    CONCAT(City, ', ', IFNULL(Region, ''), ' ', Country) AS FullAddress
FROM dbo.Customers
WHERE Country = 'Mexico';


-- ==========================================
-- Query 2: Medium (Joins & Date Operations)
-- ==========================================
-- SQL Server: DATEDIFF(day, o.OrderDate, o.ShippedDate)
-- GoogleSQL: 
-- 1. DATETIME_DIFF(o.ShippedDate, o.OrderDate, DAY) [Parameters order is swapped!]
-- 2. CURRENT_DATETIME() is used instead of GETDATE()
-- 3. DATETIME_SUB(..., INTERVAL 5 YEAR) replaces DATEADD(year, -5, ...)
SELECT 
    o.OrderID,
    IFNULL(c.CompanyName, 'Walk-in Customer') AS CustomerName,
    o.OrderDate,
    DATETIME_DIFF(o.ShippedDate, o.OrderDate, DAY) AS DaysToShip,
    CASE WHEN o.Freight > 50 THEN 'High Freight' ELSE 'Low Freight' END AS CostTier
FROM dbo.Orders o
LEFT JOIN dbo.Customers c ON o.CustomerID = c.CustomerID
WHERE o.OrderDate >= DATETIME_SUB(CURRENT_DATETIME(), INTERVAL 5 YEAR);


-- ==========================================
-- Query 3: Complex (CTEs, Window Functions, Money & Date Formatting)
-- ==========================================
-- SQL Server: EOMONTH(o.OrderDate), CAST(... AS MONEY), CONVERT(VARCHAR(10), ..., 101)
-- GoogleSQL:
-- 1. EOMONTH() maps to LAST_DAY(date, MONTH)
-- 2. MONEY maps to NUMERIC
-- 3. CONVERT(VARCHAR, date, 101) maps to FORMAT_DATE('%m/%d/%Y', date)
-- 4. Window function RANK() OVER is fully native standard SQL and remains unchanged.
WITH MonthlySales AS (
    SELECT 
        o.CustomerID,
        LAST_DAY(CAST(o.OrderDate AS DATE), MONTH) AS SalesMonthEnd,
        od.ProductID,
        p.ProductName,
        -- MONEY mapped to NUMERIC
        CAST((od.Quantity * od.UnitPrice * (1.0 - od.Discount)) AS NUMERIC) AS NetSales
    FROM dbo.Orders o
    INNER JOIN dbo.OrderDetails od ON o.OrderID = od.OrderID
    INNER JOIN dbo.Products p ON od.ProductID = p.ProductID
)
SELECT 
    CustomerID,
    FORMAT_DATE('%m/%d/%Y', SalesMonthEnd) AS MonthEndFormatted,
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
-- SQL Server: STUFF(c.Phone, 1, 5, '(XXX) '), DATENAME(weekday, ofa.OrderDate)
-- GoogleSQL:
-- 1. STUFF() is refactored using CONCAT and SUBSTR. Since start=1, len=5, we strip the 
--    first 5 characters using SUBSTR(str, 6) and prepend the mask.
-- 2. DATENAME(weekday, date) maps to FORMAT_DATETIME('%A', date)
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
    -- STUFF(c.Phone, 1, 5, '(XXX) ') equivalent
    CONCAT('(XXX) ', SUBSTR(c.Phone, 6)) AS MaskedPhone,
    IFNULL(c.Region, 'N/A') AS CustomerRegion,
    -- DATENAME(weekday) equivalent
    FORMAT_DATETIME('%A', ofa.OrderDate) AS DayOfWeekOrdered,
    CAST((ofa.LineNetSales + ofa.AllocatedFreight) AS NUMERIC) AS TotalLineCost
FROM OrderFreightAllocation ofa
INNER JOIN dbo.Customers c ON ofa.CustomerID = c.CustomerID;


-- ==========================================
-- Query 5: Cursor (Procedural Loop Logic)
-- ==========================================
-- SQL Server: DECLARE CURSOR, OPEN, FETCH NEXT, WHILE @@FETCH_STATUS = 0, CLOSE, DEALLOCATE
-- GoogleSQL:
-- 1. Cursors are refactored into clean BigQuery Scripting FOR loops: FOR record IN (SELECT...) DO ... END FOR;
-- 2. Variables do not use '@' prefix in BigQuery.
-- 3. PRINT statements map to SELECT outputs.
-- NOTE: In a production BigQuery environment, row-by-row loops are extremely inefficient.
-- It is highly recommended to refactor loops into set-based logic (e.g. Query 4) wherever possible.
FOR record IN (
    SELECT ProductID, ProductName, UnitsInStock
    FROM dbo.Products
)
DO
    IF record.UnitsInStock < 15 THEN
        SELECT CONCAT('WARNING: Product ', record.ProductName, ' (ID: ', record.ProductID, ') is low on stock. Current level: ', record.UnitsInStock) AS alert_message;
    ELSE
        SELECT CONCAT('Product ', record.ProductName, ' is healthy (', record.UnitsInStock, ' units).') AS alert_message;
    END IF;
END FOR;


-- ==========================================
-- Query 6: Advanced DML - MERGE (UPSERT)
-- ==========================================
-- SQL Server: MERGE statement with identity column omission and T-SQL structure.
-- GoogleSQL:
-- 1. BigQuery fully supports standard SQL MERGE.
-- 2. NOTE: Since ProductID is NOT an auto-increment identity in BigQuery, we MUST
--    explicitly insert ProductID during the WHEN NOT MATCHED branch (unlike T-SQL).
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
    -- In BigQuery, we must explicitly insert ProductID since it's not an identity
    INSERT (ProductID, ProductName, UnitsInStock) 
    VALUES (source.ProductID, source.ProductName, source.UnitsInStock);


-- ==========================================
-- Query 7: Advanced SELECT - Temp Tables & Timezones
-- ==========================================
-- SQL Server: #TempTable, OrderDate AT TIME ZONE 'UTC' AT TIME ZONE 'Eastern Standard Time'
-- GoogleSQL:
-- 1. Temp tables do not use '#' prefix; created using 'CREATE TEMP TABLE' syntax.
-- 2. Timezone conversion: BigQuery stores timestamps in UTC. To convert timezone offsets,
--    we use IANA database timezone names (e.g., 'America/New_York') instead of Windows names 
--    (e.g., 'Eastern Standard Time') using standard date/timestamp conversion functions.
CREATE TEMP TABLE TempOrders (
    OrderID INT64,
    OrderDateUTC DATETIME,
    OrderDateLocal TIMESTAMP
);

INSERT INTO TempOrders (OrderID, OrderDateUTC, OrderDateLocal)
SELECT 
    OrderID, 
    OrderDate,
    -- Assume OrderDate is UTC, shift and convert to America/New_York TIMESTAMP
    TIMESTAMP(OrderDate, 'America/New_York')
FROM dbo.Orders;

SELECT * FROM TempOrders;

-- Table is dropped (optional in BQ since temp tables clean up automatically at session end)
DROP TABLE TempOrders;


-- ==========================================
-- Query 8: Session Logic - Dynamic SQL
-- ==========================================
-- SQL Server: sp_executesql N'...', N'@StockThreshold INT', @StockThreshold = @MinStock
-- GoogleSQL:
-- 1. Dynamic SQL is executed via EXECUTE IMMEDIATE statement.
-- 2. BigQuery supports parameter passing using the USING keyword.
-- 3. Variable names do not use '@' prefix.
DECLARE sql STRING;
DECLARE min_stock INT64 = 10;

SET sql = 'SELECT ProductID, ProductName FROM dbo.Products WHERE UnitsInStock >= @StockThreshold';

EXECUTE IMMEDIATE sql USING min_stock AS StockThreshold;

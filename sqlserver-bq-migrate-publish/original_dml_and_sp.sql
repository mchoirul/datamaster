-- =========================================================================
-- SQL Server DML & Stored Procedure (Northwind Subset for BQ Migration Simulation)
-- =========================================================================

-- 1. Insert Customers
INSERT INTO dbo.Customers (CustomerID, CompanyName, ContactName, City, Country, Phone)
VALUES 
('ALFKI', 'Alfreds Futterkiste', 'Maria Anders', 'Berlin', 'Germany', '030-0074321'),
('ANATR', 'Ana Trujillo Emparedados', 'Ana Trujillo', 'México D.F.', 'Mexico', '(5) 555-4729'),
('ANTON', 'Antonio Moreno Taquería', 'Antonio Moreno', 'México D.F.', 'Mexico', '(5) 555-3932'),
('AROUT', 'Around the Horn', 'Thomas Hardy', 'London', 'UK', '(171) 555-7788'),
('BERGS', 'Berglunds snabbköp', 'Christina Berglund', 'Luleå', 'Sweden', '0921-12 34 56');

-- 2. Insert Products (Enable Identity Insert)
SET IDENTITY_INSERT dbo.Products ON;
INSERT INTO dbo.Products (ProductID, ProductName, UnitPrice, UnitsInStock, Discontinued)
VALUES
(1, 'Chai', 18.00, 39, 0),
(2, 'Chang', 19.00, 17, 0),
(3, 'Aniseed Syrup', 10.00, 13, 0),
(4, 'Chef Anton''s Cajun Seasoning', 22.00, 53, 0),
(5, 'Chef Anton''s Gumbo Mix', 21.35, 0, 1);
SET IDENTITY_INSERT dbo.Products OFF;

-- 3. Insert Orders (Enable Identity Insert)
SET IDENTITY_INSERT dbo.Orders ON;
INSERT INTO dbo.Orders (OrderID, CustomerID, OrderDate, RequiredDate, ShippedDate, Freight)
VALUES
(10248, 'ALFKI', '2023-07-04 08:30:00', '2023-08-01 00:00:00', '2023-07-16 00:00:00', 32.38),
(10249, 'ANATR', '2023-07-05 14:15:00', '2023-08-16 00:00:00', '2023-07-10 00:00:00', 11.61),
(10250, 'ANTON', '2023-07-08 11:00:00', '2023-08-05 00:00:00', '2023-07-12 00:00:00', 65.83);
SET IDENTITY_INSERT dbo.Orders OFF;

-- 4. Insert Order Details
INSERT INTO dbo.OrderDetails (OrderID, ProductID, UnitPrice, Quantity, Discount)
VALUES
(10248, 1, 14.00, 12, 0),
(10248, 2, 9.80, 10, 0),
(10249, 3, 18.60, 9, 0.1),
(10250, 4, 42.40, 40, 0.15),
(10250, 5, 7.70, 10, 0);

-- 5. Stored Procedure for Processing an Order and Updating Inventory
-- Demonstrates variables, conditional branching, transaction handling, and TRY-CATCH.
GO
CREATE PROCEDURE dbo.ProcessOrderAndInventory
    @OrderID INT,
    @ProductID INT,
    @Qty SMALLINT,
    @UnitPrice MONEY,
    @Discount REAL,
    @Success BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @Success = 0;

    DECLARE @CurrentStock INT;

    BEGIN TRANSACTION;

    BEGIN TRY
        -- Check if product exists and check stock levels
        SELECT @CurrentStock = UnitsInStock 
        FROM dbo.Products 
        WHERE ProductID = @ProductID;

        IF @CurrentStock IS NULL
        BEGIN
            PRINT 'Product does not exist';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF @CurrentStock < @Qty
        BEGIN
            PRINT 'Insufficient stock';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Insert into OrderDetails
        INSERT INTO dbo.OrderDetails (OrderID, ProductID, UnitPrice, Quantity, Discount)
        VALUES (@OrderID, @ProductID, @UnitPrice, @Qty, @Discount);

        -- Update stock in Products table
        UPDATE dbo.Products
        SET UnitsInStock = UnitsInStock - @Qty
        WHERE ProductID = @ProductID;

        -- Commit Transaction
        COMMIT TRANSACTION;
        SET @Success = 1;
    END TRY
    BEGIN CATCH
        -- Rollback if any error occurs
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        PRINT 'Error occurred: ' + ERROR_MESSAGE();
    END CATCH
END;
GO

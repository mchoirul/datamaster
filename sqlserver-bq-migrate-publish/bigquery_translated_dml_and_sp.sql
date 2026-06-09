-- =========================================================================
-- BigQuery GoogleSQL DML & Stored Procedure (Translated)
-- =========================================================================

-- 1. Insert Customers
INSERT INTO dbo.Customers (CustomerID, CompanyName, ContactName, City, Country, Phone)
VALUES 
('ALFKI', 'Alfreds Futterkiste', 'Maria Anders', 'Berlin', 'Germany', '030-0074321'),
('ANATR', 'Ana Trujillo Emparedados', 'Ana Trujillo', 'México D.F.', 'Mexico', '(5) 555-4729'),
('ANTON', 'Antonio Moreno Taquería', 'Antonio Moreno', 'México D.F.', 'Mexico', '(5) 555-3932'),
('AROUT', 'Around the Horn', 'Thomas Hardy', 'London', 'UK', '(171) 555-7788'),
('BERGS', 'Berglunds snabbköp', 'Christina Berglund', 'Luleå', 'Sweden', '0921-12 34 56');

-- 2. Insert Products
-- IDENTITY column does not exist; IDs are loaded directly
INSERT INTO dbo.Products (ProductID, ProductName, UnitPrice, UnitsInStock, Discontinued)
VALUES
(1, 'Chai', 18.00, 39, FALSE),
(2, 'Chang', 19.00, 17, FALSE),
(3, 'Aniseed Syrup', 10.00, 13, FALSE),
(4, 'Chef Anton''s Cajun Seasoning', 22.00, 53, FALSE),
(5, 'Chef Anton''s Gumbo Mix', 21.35, 0, TRUE);

-- 3. Insert Orders
INSERT INTO dbo.Orders (OrderID, CustomerID, OrderDate, RequiredDate, ShippedDate, Freight)
VALUES
(10248, 'ALFKI', '2023-07-04 08:30:00', '2023-08-01 00:00:00', '2023-07-16 00:00:00', 32.38),
(10249, 'ANATR', '2023-07-05 14:15:00', '2023-08-16 00:00:00', '2023-07-10 00:00:00', 11.61),
(10250, 'ANTON', '2023-07-08 11:00:00', '2023-08-05 00:00:00', '2023-07-12 00:00:00', 65.83);

-- 4. Insert Order Details
INSERT INTO dbo.OrderDetails (OrderID, ProductID, UnitPrice, Quantity, Discount)
VALUES
(10248, 1, 14.00, 12, 0.0),
(10248, 2, 9.80, 10, 0.0),
(10249, 3, 18.60, 9, 0.1),
(10250, 4, 42.40, 40, 0.15),
(10250, 5, 7.70, 10, 0.0);

-- 5. Stored Procedure for Processing an Order and Updating Inventory
-- Translated to BigQuery SQL Scripting syntax.
CREATE OR REPLACE PROCEDURE dbo.ProcessOrderAndInventory(
    in_OrderID INT64,
    in_ProductID INT64,
    in_Qty INT64,
    in_UnitPrice NUMERIC,
    in_Discount FLOAT64,
    OUT out_Success BOOL
)
BEGIN
    DECLARE current_stock INT64;
    SET out_Success = FALSE;

    -- Start Multi-statement Transaction
    BEGIN TRANSACTION;

    BEGIN
        -- Check if product exists and check stock levels (uses table prefix 'p' to prevent variable collision)
        SET current_stock = (
            SELECT p.UnitsInStock 
            FROM dbo.Products p
            WHERE p.ProductID = in_ProductID
        );

        IF current_stock IS NULL THEN
            ROLLBACK TRANSACTION;
            SELECT 'Product does not exist' AS status_message;
            RETURN;
        END IF;

        IF current_stock < in_Qty THEN
            ROLLBACK TRANSACTION;
            SELECT 'Insufficient stock' AS status_message;
            RETURN;
        END IF;

        -- Insert into OrderDetails
        INSERT INTO dbo.OrderDetails (OrderID, ProductID, UnitPrice, Quantity, Discount)
        VALUES (in_OrderID, in_ProductID, in_UnitPrice, in_Qty, in_Discount);

        -- Update stock in Products table
        UPDATE dbo.Products
        SET UnitsInStock = UnitsInStock - in_Qty
        WHERE ProductID = in_ProductID;

        -- Commit Transaction
        COMMIT TRANSACTION;
        SET out_Success = TRUE;

    EXCEPTION WHEN ERROR THEN
        -- Rollback on error
        ROLLBACK TRANSACTION;
        -- SELECT @@error.message to output error information
        SELECT CONCAT('Error occurred: ', @@error.message) AS status_message;
    END;
END;

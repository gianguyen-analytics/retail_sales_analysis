USE Retail_Sales_Analysis;
GO

SELECT
    COUNT(*) AS Total_Rows,
    COUNT(DISTINCT Order_ID) AS Total_Orders,
    SUM(Sales) AS Total_Sales,
    SUM(Profit) AS Total_Profit,
    SUM(Quantity) AS Total_Quantity
FROM dbo.Orders_Clean;

-- 1. Kiểm tra Row_ID bị trùng
SELECT Row_ID, COUNT(*) AS Row_Count
FROM dbo.Orders_Clean
GROUP BY Row_ID
HAVING COUNT(*) > 1;

-- 2. Kiểm tra Postal Code bị thiếu
SELECT COUNT(*) AS Missing_Postal_Code
FROM dbo.Orders_Clean
WHERE Postal_Code IS NULL
   OR LTRIM(RTRIM(Postal_Code)) = '';

-- 3. Kiểm tra ngày giao trước ngày đặt
SELECT COUNT(*) AS Invalid_Shipping_Dates
FROM dbo.Orders_Clean
WHERE Ship_Date < Order_Date;

-- 4. Kiểm tra giá trị ngoài phạm vi hợp lệ
SELECT
    SUM(CASE WHEN Sales <= 0 THEN 1 ELSE 0 END)
        AS Non_Positive_Sales,
    SUM(CASE WHEN Quantity <= 0 THEN 1 ELSE 0 END)
        AS Non_Positive_Quantity,
    SUM(CASE WHEN Discount < 0 OR Discount > 1 THEN 1 ELSE 0 END)
        AS Invalid_Discount
FROM dbo.Orders_Clean;

-- 5. Kiểm tra khoảng thời gian dữ liệu
SELECT
    MIN(Order_Date) AS First_Order_Date,
    MAX(Order_Date) AS Last_Order_Date
FROM dbo.Orders_Clean;

-- 6. Phân tích hiệu quả kinh doanh theo khu vực
SELECT
    Region,
    COUNT(DISTINCT Order_ID) AS Total_Orders,
    SUM(Quantity) AS Total_Quantity,
    CAST(SUM(Sales) AS decimal(18,2)) AS Total_Sales,
    CAST(SUM(Profit) AS decimal(18,2)) AS Total_Profit,
    CAST(
        100.0 * SUM(Profit) / NULLIF(SUM(Sales), 0)
        AS decimal(10,2)
    ) AS Profit_Margin_Pct
FROM dbo.Orders_Clean
GROUP BY Region
ORDER BY Total_Profit DESC;

-- 7. Doanh thu và lợi nhuận theo nhóm sản phẩm
SELECT
    Category,
    Sub_Category,
    SUM(Quantity) AS Total_Quantity,
    CAST(SUM(Sales) AS decimal(18,2)) AS Total_Sales,
    CAST(SUM(Profit) AS decimal(18,2)) AS Total_Profit,
    CAST(
        100.0 * SUM(Profit) / NULLIF(SUM(Sales), 0)
        AS decimal(10,2)
    ) AS Profit_Margin_Pct
FROM dbo.Orders_Clean
GROUP BY Category, Sub_Category
ORDER BY Total_Profit DESC;

-- 8. Chỉ lấy các nhóm có tổng lợi nhuận âm
SELECT
    Sub_Category,
    CAST(SUM(Sales) AS decimal(18,2)) AS Total_Sales,
    CAST(SUM(Profit) AS decimal(18,2)) AS Total_Profit,
    CAST(
        100.0 * SUM(Profit) / NULLIF(SUM(Sales), 0)
        AS decimal(10,2)
    ) AS Profit_Margin_Pct
FROM dbo.Orders_Clean
GROUP BY Sub_Category
HAVING SUM(Profit) < 0
ORDER BY Total_Profit ASC;

-- 9. Phân tích Tables theo nhóm giảm giá
SELECT
    Discount_Group,
    COUNT(*) AS Total_Order_Lines,
    CAST(SUM(Sales) AS decimal(18,2)) AS Total_Sales,
    CAST(SUM(Profit) AS decimal(18,2)) AS Total_Profit,
    CAST(
        100.0 * SUM(Profit) / NULLIF(SUM(Sales), 0)
        AS decimal(10,2)
    ) AS Profit_Margin_Pct
FROM dbo.Orders_Clean
WHERE Sub_Category = N'Tables'
GROUP BY Discount_Group
ORDER BY MIN(Discount);

-- 10. Tăng trưởng doanh thu và lợi nhuận theo năm
;WITH Yearly AS (
    SELECT
        YEAR(Order_Date) AS Order_Year,
        SUM(Sales) AS Total_Sales,
        SUM(Profit) AS Total_Profit
    FROM dbo.Orders_Clean
    GROUP BY YEAR(Order_Date)
),
Previous_Year AS (
    SELECT
        *,
        LAG(Total_Sales) OVER (
            ORDER BY Order_Year
        ) AS Previous_Sales,
        LAG(Total_Profit) OVER (
            ORDER BY Order_Year
        ) AS Previous_Profit
    FROM Yearly
)
SELECT
    Order_Year,
    CAST(Total_Sales AS decimal(18,2)) AS Total_Sales,
    CAST(Total_Profit AS decimal(18,2)) AS Total_Profit,
    CAST(
        100.0 * (Total_Sales - Previous_Sales)
        / NULLIF(Previous_Sales, 0)
        AS decimal(10,2)
    ) AS Sales_YoY_Pct,
    CAST(
        100.0 * (Total_Profit - Previous_Profit)
        / NULLIF(Previous_Profit, 0)
        AS decimal(10,2)
    ) AS Profit_YoY_Pct,
    CAST(
        100.0 * Total_Profit / NULLIF(Total_Sales, 0)
        AS decimal(10,2)
    ) AS Profit_Margin_Pct
FROM Previous_Year
ORDER BY Order_Year;

-- 11. Top 5 sản phẩm có tổng lỗ lớn nhất mỗi khu vực
;WITH Product_Profit AS (
    SELECT
        Region,
        Product_ID,
        MAX(Product_Name) AS Product_Name,
        SUM(Sales) AS Total_Sales,
        SUM(Profit) AS Total_Profit
    FROM dbo.Orders_Clean
    GROUP BY Region, Product_ID
    HAVING SUM(Profit) < 0
),
Ranked_Products AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY Region
            ORDER BY Total_Profit ASC, Product_ID
        ) AS Loss_Rank
    FROM Product_Profit
)
SELECT
    Region,
    Loss_Rank,
    Product_ID,
    Product_Name,
    CAST(Total_Sales AS decimal(18,2)) AS Total_Sales,
    CAST(Total_Profit AS decimal(18,2)) AS Total_Profit,
    CAST(
        100.0 * Total_Profit / NULLIF(Total_Sales, 0)
        AS decimal(10,2)
    ) AS Profit_Margin_Pct
FROM Ranked_Products
WHERE Loss_Rank <= 5
ORDER BY Region, Loss_Rank;
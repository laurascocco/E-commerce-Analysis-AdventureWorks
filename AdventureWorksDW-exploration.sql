-- Exploring AdventureWorks2020 Database


-- Extraction of all product codes with a list price greater than or equal to the average list price. 
-- The relevant codes are all those related to Mountain-type bicycles.

SELECT 
	ProductKey, 
	EnglishProductName, 
	ListPrice
FROM DimProduct
WHERE  
	ListPrice >= (
					SELECT AVG(ListPrice) 
					FROM DimProduct
					WHERE EnglishProductName LIKE '%Mountain%'
						);

-- List of products sold to resellers or through the internet portal

SELECT *
FROM DimProduct
WHERE ProductKey IN (
						SELECT ProductKey
						FROM FactResellerSales
						UNION
						SELECT ProductKey
						FROM FactInternetSales );

-- Code and name of customers who placed an order in 2020

SELECT 
	CustomerKey,
	CONCAT(FirstName, ' ', LastName) AS Customer
FROM DimCustomer
WHERE CustomerKey IN (
						SELECT CustomerKey
						FROM FactInternetSales
						WHERE YEAR(OrderDate) = 2020);


-- checking if there are 2021 sales

SELECT *
FROM FactResellerSales
WHERE YEAR(OrderDate) = 2021		-- zero sales


SELECT *
FROM FactInternetSales
WHERE YEAR(OrderDate) = 2021		-- there are sales


-- Most recent date for reseller

SELECT 
	SalesOrderNumber, 
	SalesOrderLineNumber, 
	ResellerKey, 
	OrderDate
FROM FactResellerSales AS r1
WHERE r1.OrderDate = (
						SELECT MAX(r2.OrderDate)
						FROM FactResellerSales AS r2
						WHERE r1.ResellerKey = r2.ResellerKey)
ORDER BY ResellerKey;

-- Check on the totalproductcost field to see where and how many null values there are

SELECT COUNT (*)
FROM (
		SELECT
			SalesOrderNumber
			, SalesOrderLineNumber
			, OrderDate
			, ProductKey
			, OrderQuantity
			, TotalProductCost
			, SalesAmount
		FROM FactResellerSales
	) AS Sales
WHERE Sales.TotalProductCost IS NULL

SELECT COUNT (*)
FROM (
		SELECT
			SalesOrderNumber
			, SalesOrderLineNumber
			, OrderDate
			, ProductKey
			, OrderQuantity
			, TotalProductCost
			, SalesAmount
			, 'Reseller'	AS FlagSales
		FROM FactResellerSales
		UNION ALL
		SELECT
			SalesOrderNumber
			, SalesOrderLineNumber
			, OrderDate
			, ProductKey
			, OrderQuantity
			, TotalProductCost
			, SalesAmount
			, 'Internet'
		FROM FactInternetSales
	) AS Sales
WHERE Sales.TotalProductCost IS NULL

-- the null values are only in the FactResellerSales because the number doesn't change

-- Filling the null values to create the profit column and profit margin column

CREATE VIEW VW_LS_SalesTrans AS (

SELECT 
	s.SalesOrderNumber,
	s.SalesOrderLineNumber,
	s.OrderDate,
	s.ProductKey,
	s.OrderQuantity,
	s.TotalProductCost,
	s.SalesAmount,
	s.FlagSales,
	p.StandardCost,
	CASE
		WHEN TotalProductCost IS NULL THEN SalesAmount - OrderQuantity * p.StandardCost
		ELSE SalesAmount - TotalProductCost
		--WHEN TotalProductCost IS NOT NULL THEN SalesAmount - TotalProductCost
		END	AS Profit,
	CASE
		WHEN TotalProductCost IS NULL THEN (SalesAmount - OrderQuantity * p.StandardCost)/ SalesAmount 
		ELSE (SalesAmount - TotalProductCost)/ SalesAmount
		END	AS ProfitMargin
FROM (
		SELECT
			SalesOrderNumber
			, SalesOrderLineNumber
			, OrderDate
			, ProductKey
			, OrderQuantity
			, TotalProductCost
			, SalesAmount
			, UnitPrice
			, ShipDate
			, 'Reseller'	AS FlagSales
		FROM FactResellerSales
		UNION ALL
		SELECT
			SalesOrderNumber
			, SalesOrderLineNumber
			, OrderDate
			, ProductKey
			, OrderQuantity
			, TotalProductCost
			, SalesAmount
			, UnitPrice
			, ShipDate
			, 'Internet'
		FROM FactInternetSales
	) AS s

INNER JOIN DimProduct AS p
ON s.ProductKey = p.ProductKey );

-- List of only the products sold, and for each of these, the total revenue per year

SELECT
    p.ProductKey,
    p.EnglishProductName,
	c.EnglishProductCategoryName,
    YEAR(r.OrderDate) AS SalesYear,
    SUM(r.SalesAmount) AS TotalAmount
FROM 
	DimProduct AS p
	JOIN FactResellerSales AS r
	ON p.ProductKey = r.ProductKey
	JOIN DimProductCategory AS c
	ON p.ProductKey = r.ProductKey
GROUP BY
    p.ProductKey, p.EnglishProductName, c.EnglishProductCategoryName , YEAR(r.OrderDate)
ORDER BY
	p.ProductKey, YEAR(r.OrderDate), TotalAmount;


-- Total revenue per state per year. The result are orered by date and by descending revenue

SELECT 
	g.StateProvinceName,
    YEAR(r.OrderDate) AS SalesYear,
    SUM(r.SalesAmount) AS TotalAmount
FROM FactInternetSales AS r
JOIN DimSalesTerritory AS t
ON r.SalesTerritoryKey = t.SalesTerritoryKey
JOIN DimGeography AS g
ON g.SalesTerritoryKey = r.SalesTerritoryKey
GROUP BY
    g.StateProvinceName, YEAR(r.OrderDate)
ORDER BY
    SalesYear DESC, TotalAmount DESC;

-- The most requested item category by the market

SELECT TOP 1
    c.EnglishProductCategoryName,
    COUNT(*) AS NumberSales
FROM 
	DimProduct AS p
	JOIN FactResellerSales AS r
	ON p.ProductKey = r.ProductKey
	JOIN DimProductCategory AS c
	ON p.ProductKey = r.ProductKey
GROUP BY
    c.EnglishProductCategoryName
ORDER BY
    NumberSales DESC;


-- I create the views to use on PowerBI
CREATE VIEW LS_VW_Products AS(
SELECT 
	ProductKey,
	EnglishProductName AS Product,
	EnglishProductCategoryName AS Category,
	EnglishProductSubcategoryName AS SubCategory,
	StandardCost, 
	FinishedGoodsFlag
FROM DimProduct AS p
LEFT JOIN DimProductSubcategory AS s
ON p.ProductSubcategoryKey = s.ProductSubcategoryKey
LEFT JOIN DimProductCategory AS c
On s.ProductCategoryKey = c.ProductCategoryKey
WHERE FinishedGoodsFlag = 1
	);


CREATE VIEW VW_LS_Reseller AS(
SELECT 
	ResellerKey,
	BusinessType,
	ResellerName,
	City,
	StateProvinceName AS StateProvince,
	EnglishCountryRegionName AS CountryRegion
FROM DimReseller AS r
LEFT JOIN DimGeography AS g
ON r.GeographyKey = g.GeographyKey)



CREATE VIEW LS_VW_Customer AS(
SELECT 
	c.CustomerKey,
	CONCAT(c.FirstName, ' ', c.LastName) AS CustomerName,
	g.City,
	g.StateProvinceName AS StateProvince,
	g.EnglishCountryRegionName AS CountryRegion
FROM DimCustomer AS c
INNER JOIN DimGeography AS g
	ON c.GeographyKey = g.GeographyKey
	);

CREATE VIEW LS_VW_InternetSales AS(
SELECT
	ProductKey,
	CustomerKey,
	CAST(OrderDate AS DATE) AS OrderDate,
	SUM(SalesAmount) AS Sales,
	SUM(OrderQuantity) AS Quantity,
	COUNT(SalesOrderLineNumber) AS Transactions,
	SUM(TotalProductCost) AS TotalProductCost
FROM FactInternetSales
GROUP BY ProductKey, CustomerKey, OrderDate
	);

CREATE VIEW VW_LS_Sales AS (
		
SELECT
	Sales.*
	, p.StandardCost
	, CASE
		WHEN TotalProductCost IS NULL THEN SalesAmount - OrderQuantity * p.StandardCost
		ELSE SalesAmount - TotalProductCost
		--WHEN TotalProductCost IS NOT NULL THEN SalesAmount - TotalProductCost
		END	AS Profit
	, CASE
		WHEN TotalProductCost IS NULL THEN (SalesAmount - OrderQuantity * p.StandardCost)/ SalesAmount
		ELSE (SalesAmount - TotalProductCost)/ SalesAmount
		END	AS ProfitMargin
FROM (
		SELECT
			SalesOrderNumber
			, SalesOrderLineNumber
			, OrderDate
			, ProductKey
			, ResellerKey
			, null AS CustomerKey
			, OrderQuantity
			, UnitPrice
			, TotalProductCost
			, SalesAmount
			, 'Reseller'	AS FlagSales
		FROM FactResellerSales
		UNION
		SELECT
			SalesOrderNumber
			, SalesOrderLineNumber
			, OrderDate
			, ProductKey
			, null
			, CustomerKey
			, OrderQuantity
			, UnitPrice
			, TotalProductCost
			, SalesAmount
			, 'Internet'
		FROM FactInternetSales
	) AS Sales
JOIN DimProduct AS p
ON Sales.ProductKey = p.ProductKey

)



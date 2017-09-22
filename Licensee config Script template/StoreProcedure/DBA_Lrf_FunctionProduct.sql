USE [bodb_licensee]
GO
/****** Object:  StoredProcedure [dbo].[DBA_Lrf_FunctionProduct]    Script Date: 05/04/2015 15:07:49 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER   PROCEDURE [dbo].[DBA_Lrf_FunctionProduct]
(
	@ProductCode VARCHAR(100) = ''
)
/*
Created: 20140502@Jim
Task : re-structure create new licensee flow
DB: DBLIC.bodb_licensee
Original :
	
Revisions:
	- 20150320@Jim: add more funtion permission for 'Active Customer Summary' report
	- 20150421@Jim: add more function Gold Deluxe
	- 20150421@Jim: correct function product for Void Bridge
	- 20170526@Harper: add new product AllBet, Macau Game, Number Game 2, Fishing World and CashOut
Param's Explanation:
		
	
*/
AS
BEGIN 
	DECLARE @tblFunctions AS TABLE (ProductId INT,FunctionId INT,TypeID INT)
	IF @ProductCode = 'SB'
		BEGIN 
			INSERT INTO @tblFunctions (ProductId, FunctionId,TypeID)
			SELECT	0 AS ProductId -- SB
					,FunctionID  
					,1 AS TypeId	 -- Lrf Function
			FROM dbo.Functions WITH (NOLOCK)
			WHERE FunctionId NOT IN (
									5  --DATA WAREHOUSE
									,44 --Warehouse/WinLoss
									,45 --Warehouse/TopCustomer
									,59 --Report/WinLossByLeague
									,22 -- Racing
									,23 -- Number Game
									,34 -- Racing Commission
									,35 -- Daily Racing Win Loss
									,58 -- AGENCY SYSTEM 
									,59 -- WinLoss By League
									,60 -- AGENCY SYSTEM 
									,61 -- Playtech Casino Win Loss
									,62 -- AG Casino Win Loss
									,6	-- ACCOUNT MANAGEMENT
									,46	-- Manage Account
									,47	-- Add New Account
									,48	-- Edit New Account
									,49	-- Assign Permission
									,50	-- Reset Password
									,57	-- Assign Currency
									,65 -- Gold Deluxe Winloss
									,66 -- Void Bridge Winloss
									)	
			UNION ALL 
			SELECT	0 AS ProductId -- SB
					,FunctionID  
					,2 AS TypeId	 -- Lrf Special Function
			FROM dbo.Functions WITH (NOLOCK)	
			WHERE FunctionId = 6 OR  ParentId = 6
		END
	IF @ProductCode = 'RB'
		BEGIN 
			INSERT INTO @tblFunctions (ProductId, FunctionId,TypeID)
			SELECT	1 AS ProductId -- RB
					,FunctionID  
					,1 AS TypeId	 -- Lrf Function
			FROM dbo.Functions WITH (NOLOCK)
			WHERE FunctionId    IN (
									 1  -- TOTAL BETS
									,3  -- REPORTS
									,52 -- CUSTOMER REPORTS
									,22 -- Racing
									,27 -- Licensee Win Loss
									,28 -- Settled Match Count
									,31 -- Match Win Loss
									,32 -- Win Loss By Products
									,33 -- Win Loss By Bet Type
									,34 -- Racing Commission
									,35 -- Daily Racing Win Loss
									,36 -- Cancelled Bets
									,37 -- Daily Bet List
									,38 -- Live Report
									,39 -- Turnover
									,53 -- Mobile Win Loss
									,41 -- Results
									,42 -- Balance
									,29 -- Customer Win Loss
									,30 -- Customer Pending Funds
									,40 --Customer Balance
									,64	-- Active Customer Summary
									)
			UNION ALL 
			SELECT 	1 AS ProductId -- RB
			,7 AS FunctionID ---Racing		
			,2 AS TypeId	--- LA Function
			
		END
	IF @ProductCode = 'NG'
		BEGIN 
			INSERT INTO @tblFunctions (ProductId, FunctionId,TypeID)
			SELECT	2 AS ProductId -- NG
					,FunctionID  
					,1 AS TypeId	 -- Lrf Function
			FROM dbo.Functions WITH (NOLOCK)
			WHERE FunctionId    IN (
									 3  -- REPORTS
									,23 -- Number Game 
									,27 -- Licensee Win Loss
									,28 -- Settled Match Count
									,31 -- Match Win Loss
									,32 -- Win Loss By Products
									,33 -- Win Loss By Bet Type
									,36 -- Cancelled Bets
									,37 -- Daily Bet List
									,38 -- Live Report
									,39 -- Turnover
									,52 -- CUSTOMER REPORTS
									,53 -- Mobile Win Loss
									,41 -- Results
									,42 -- Balance
									,29 -- Customer Win Loss
									,30 -- Customer Pending Funds
									,40 --Customer Balance
									,51 -- Customer Turnover
									,64	-- Active Customer Summary
									)
			UNION ALL 
			SELECT 	2 AS ProductId -- NG
			,15 AS FunctionID ---Number Game Win Loss		
			,2 AS TypeId	--- LA Function
			
		END
	IF @ProductCode = 'BA'
		BEGIN 
			INSERT INTO @tblFunctions (ProductId, FunctionId,TypeID)
			SELECT	3 AS ProductId -- BA
					,FunctionID  
					,3 AS TypeId	 -- Lrf special Function
			FROM dbo.Functions WITH (NOLOCK)
			WHERE FunctionId    IN (
									 54  -- SpecialBA
									)
		END
	IF @ProductCode = 'LC'
		BEGIN 
			INSERT INTO @tblFunctions (ProductId, FunctionId,TypeID)
			SELECT	4 AS ProductId -- lC
					,FunctionID  
					,1 AS TypeId	 -- Lrf Function
			FROM dbo.Functions WITH (NOLOCK)
			WHERE FunctionId    IN (
									 3  -- REPORTS
									,27 -- Licensee Win Loss
									,28 -- Settled Match Count
									,31 -- Match Win Loss
									,32 -- Win Loss By Products
									,33 -- Win Loss By Bet Type
									,36 -- Cancelled Bets
									,37 -- Daily Bet List
									,38 -- Live Report
									,39 -- Turnover
									,52 -- CUSTOMER REPORTS
									,53 -- Mobile Win Loss
									,41 -- Results
									,42 -- Balance
									,29 -- Customer Win Loss
									,30 -- Customer Pending Funds
									,40 --Customer Balance
									,64	-- Active Customer Summary
									)
			UNION ALL 
			SELECT 	4 AS ProductId -- LC
			,17 AS FunctionID ---Live Casino Win Loss
			,2 AS TypeId	--- LA Function	
		END
	IF @ProductCode = 'VS'
		BEGIN 
			INSERT INTO @tblFunctions (ProductId, FunctionId,TypeID)
			SELECT	5 AS ProductId -- VS
					,FunctionID  
					,1 AS TypeId	 -- Lrf Function
			FROM dbo.Functions WITH (NOLOCK)
			WHERE FunctionId    IN (
									 3  -- REPORTS
									,27 -- Licensee Win Loss
									,28 -- Settled Match Count
									,31 -- Match Win Loss
									,32 -- Win Loss By Products
									,33 -- Win Loss By Bet Type
									,36 -- Cancelled Bets
									,37 -- Daily Bet List
									,38 -- Live Report
									,39 -- Turnover
									,52 -- CUSTOMER REPORTS
									,53 -- Mobile Win Loss
									,41 -- Results
									,42 -- Balance
									,29 -- Customer Win Loss
									,30 -- Customer Pending Funds
									,40 --Customer Balance
									,51 -- Customer Turnover
									,64	-- Active Customer Summary
									)
			UNION ALL 
			SELECT 	5 AS ProductId -- VS
			,16 AS FunctionID ---Virtual Sports
			,2 AS TypeId	--- LA Function
			
		END
	IF @ProductCode = 'CS'
		BEGIN 
			INSERT INTO @tblFunctions (ProductId, FunctionId,TypeID)
			SELECT	6 AS ProductId -- CS
					,FunctionID  
					,1 AS TypeId	 -- Lrf Function
			FROM dbo.Functions WITH (NOLOCK)
			WHERE FunctionId    IN (
									 3  -- REPORTS
									,27 -- Licensee Win Loss
									,32 -- Win Loss By Products
									,33 -- Win Loss By Bet Type
									,36 -- Cancelled Bets
									,37 -- Daily Bet List
									,38 -- Live Report
									,39 -- Turnover
									,52 -- CUSTOMER REPORTS
									,41 -- Results
									,42 -- Balance
									,29 -- Customer Win Loss
									,40 --Customer Balance
									,64	-- Active Customer Summary
									)
			UNION ALL 
			SELECT 	6 AS ProductId -- CS
			,21 AS FunctionID ---RNG Casino Win Loss
			,2 AS TypeId	--- LA Function
			
		END
	IF @ProductCode = 'KN'
		BEGIN 
			INSERT INTO @tblFunctions (ProductId, FunctionId,TypeID)
			SELECT	8 AS ProductId -- KN
					,FunctionID  
					,1 AS TypeId	 -- Lrf Function
			FROM dbo.Functions WITH (NOLOCK)
			WHERE FunctionId    IN (
									 3  -- REPORTS
									,27 -- Licensee Win Loss
									,32 -- Win Loss By Products
									,36 -- Cancelled Bets
									,37 -- Daily Bet List
									,38 -- Live Report
									,39 -- Turnover
									,52 -- CUSTOMER REPORTS
									,42 -- Balance
									,29 -- Customer Win Loss
									,40 --Customer Balance
									,64	-- Active Customer Summary
									)
		END
	IF @ProductCode = 'PTCS'
		BEGIN 
			INSERT INTO @tblFunctions (ProductId, FunctionId,TypeID)
			SELECT	9 AS ProductId -- PTCS
					,FunctionID  
					,1 AS TypeId	 -- Lrf Function
			FROM dbo.Functions WITH (NOLOCK)
			WHERE FunctionId    IN (
									 3  -- REPORTS
									,61 -- Playtech Casino Win Loss
									)
		END
	IF @ProductCode = 'AGC'
		BEGIN 
			INSERT INTO @tblFunctions (ProductId, FunctionId,TypeID)
			SELECT	10 AS ProductId -- AGC
					,FunctionID  
					,1 AS TypeId	 -- Lrf Function
			FROM dbo.Functions WITH (NOLOCK)
			WHERE FunctionId    IN (
									 3  -- REPORTS
									,62 -- AG Casino Win Loss
									)
		END	
	IF @ProductCode = 'GD'
		BEGIN 
			INSERT INTO @tblFunctions (ProductId, FunctionId,TypeID)
			SELECT	11 AS ProductId -- AGC
					,FunctionID  
					,1 AS TypeId	 -- Lrf Function
			FROM dbo.Functions WITH (NOLOCK)
			WHERE FunctionId    IN (
									 3  -- REPORTS
									,65 -- Gold Deluxe Winloss
									)
		END	

	IF @ProductCode = 'AB'
	BEGIN
		INSERT INTO @tblFunctions (ProductId, FunctionId,TypeID)
		SELECT	21 AS ProductId -- AB
				,FunctionID  
				,1 AS TypeId	 -- Lrf Function
		FROM dbo.Functions WITH (NOLOCK)
		WHERE FunctionId    IN (
								3  -- REPORTS
								,27 -- Licensee Win Loss
								,28 -- Settled Match Count
								,31 -- Match Win Loss
								,32 -- Win Loss By Products
								,36 -- Cancelled Bets
								,37 -- Daily Bet List
								,38 -- Live Report
								,39 -- Turnover
								,52 -- CUSTOMER REPORTS
								,53 -- Mobile Win Loss
								,41 -- Results
								,42 -- Balance
								,29 -- Customer Win Loss
								,30 -- Customer Pending Funds
								,40 -- Customer Balance
								,51 -- Customer Turnover
								,64	-- Active Customer Summary
								)
		UNION ALL 
		SELECT 	21 AS ProductId -- AB
				,64 AS FunctionID -- AllBet Win lossS		
				,2 AS TypeId	--- LA Function
	END

	IF @ProductCode = 'VB'
	BEGIN
		INSERT INTO @tblFunctions (ProductId, FunctionId,TypeID)
		SELECT	22 AS ProductId -- VB - Macau Game
				,FunctionID  
				,1 AS TypeId	 -- Lrf Function
		FROM dbo.Functions WITH (NOLOCK)
		WHERE FunctionId    IN (
								3  -- REPORTS
								,27 -- Licensee Win Loss
								,28 -- Settled Match Count
								,31 -- Match Win Loss
								,32 -- Win Loss By Products
								,36 -- Cancelled Bets
								,37 -- Daily Bet List
								,38 -- Live Report
								,39 -- Turnover
								,52 -- CUSTOMER REPORTS
								,53 -- Mobile Win Loss
								,41 -- Results
								,42 -- Balance
								,29 -- Customer Win Loss
								,30 -- Customer Pending Funds
								,40 -- Customer Balance
								,51 -- Customer Turnover
								,64	-- Active Customer Summary
								)	
	END

	IF @ProductCode = 'NG2'
	BEGIN
		INSERT INTO @tblFunctions (ProductId, FunctionId,TypeID)
		SELECT	23 AS ProductId -- Number Game 2
				,FunctionID  
				,1 AS TypeId	 -- Lrf Function
		FROM dbo.Functions WITH (NOLOCK)
		WHERE FunctionId    IN (
								3  -- REPORTS
								,27 -- Licensee Win Loss
								,28 -- Settled Match Count
								,31 -- Match Win Loss
								,32 -- Win Loss By Products
								,36 -- Cancelled Bets
								,37 -- Daily Bet List
								,38 -- Live Report
								,39 -- Turnover
								,52 -- CUSTOMER REPORTS
								,53 -- Mobile Win Loss
								,41 -- Results
								,42 -- Balance
								,29 -- Customer Win Loss
								,30 -- Customer Pending Funds
								,40 -- Customer Balance
								,51 -- Customer Turnover
								,64	-- Active Customer Summary
								)
		UNION ALL 
		SELECT 	23 AS ProductId -- Number Game 2
				,65 AS FunctionID -- Number Game 2 Winloss
				,2 AS TypeId	--- LA Function
	END
	
	IF @ProductCode = 'FW'
	BEGIN
		INSERT INTO @tblFunctions (ProductId, FunctionId,TypeID)
		SELECT	24 AS ProductId -- Fishing World
				,FunctionID  
				,1 AS TypeId	 -- Lrf Function
		FROM dbo.Functions WITH (NOLOCK)
		WHERE FunctionId    IN (
								3  -- REPORTS
								,27 -- Licensee Win Loss
								,28 -- Settled Match Count
								,31 -- Match Win Loss
								,32 -- Win Loss By Products
								,36 -- Cancelled Bets
								,37 -- Daily Bet List
								,38 -- Live Report
								,39 -- Turnover
								,52 -- CUSTOMER REPORTS
								,53 -- Mobile Win Loss
								,41 -- Results
								,42 -- Balance
								,29 -- Customer Win Loss
								,30 -- Customer Pending Funds
								,40 -- Customer Balance
								,51 -- Customer Turnover
								,64	-- Active Customer Summary
								)
		UNION ALL 
		SELECT 	24 AS ProductId -- Fishing World
				,66 AS FunctionID -- AllBet Win lossS		
				,2 AS TypeId	--- LA Function
	END
		
	IF @ProductCode = 'CO'
	BEGIN
		INSERT INTO @tblFunctions (ProductId, FunctionId,TypeID)
		SELECT	25 AS ProductId -- CashOut
				,FunctionID  
				,1 AS TypeId	 -- Lrf Function
		FROM dbo.Functions WITH (NOLOCK)
		WHERE FunctionId    IN (
								3  -- REPORTS
								,27 -- Licensee Win Loss
								,28 -- Settled Match Count
								,31 -- Match Win Loss
								,32 -- Win Loss By Products
								,36 -- Cancelled Bets
								,37 -- Daily Bet List
								,38 -- Live Report
								,39 -- Turnover
								,52 -- CUSTOMER REPORTS
								,53 -- Mobile Win Loss
								,41 -- Results
								,42 -- Balance
								,29 -- Customer Win Loss
								,30 -- Customer Pending Funds
								,40 -- Customer Balance
								,51 -- Customer Turnover
								,64	-- Active Customer Summary
								,72 -- Cashout Win Loss
								)
		UNION ALL 
		SELECT 	25 AS ProductId -- CashOut
				,68 AS FunctionID -- Cashout Winloss Win lossS		
				,2 AS TypeId	--- LA Function
	END

	SELECT DISTINCT ProductId, FunctionId,TypeID
	FROM @tblFunctions ORDER BY ProductId,FunctionId  ASC
		/*
			EXEC DBA_FunctionProduct
		*/
END
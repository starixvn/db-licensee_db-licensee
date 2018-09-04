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
		- 20171208@Harper: add new product CB, LT, VS2
		- 20171214@Harper: Edit for GMT +8 and Exchange Product
		- 20180521@Harper: Remove CasinoProgressiveWins report
		- 20180820@Harper: AG Casino Balance report just using for 12bet

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
		WHERE FunctionId IN (
								1  -- TOTAL BETS
								,2 -- FORECAST
								,3 -- REPORTS
								,4 -- CUSTOMER INFORMATION
								,64 -- Active Customer Summary
								,69 -- Weekly Live Matches
								,70 -- Edit Bet Setting		
								,76 -- GMT +8							
								)
			OR FunctionId BETWEEN 51 AND 56
			OR FunctionId BETWEEN 36 AND 43
			OR FunctionId BETWEEN 7 AND 33
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
		WHERE FunctionId IN (		
								3 -- REPORTS						
								,22 -- Racing								
								,34 -- Racing Commission
								,35 -- Daily Racing Win Loss								
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
								3 -- REPORTS						
								,23 -- Number Game 								
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
								3 -- REPORTS						
								,54  -- SpecialBA
								)
	END
	
	IF @ProductCode = 'VS'
	BEGIN 
		INSERT INTO @tblFunctions (ProductId, FunctionId,TypeID)		
		SELECT 	5 AS ProductId -- VS
		,16 AS FunctionID ---Virtual Sports
		,2 AS TypeId	--- LA Function
			
	END

	IF @ProductCode = 'CS'
	BEGIN 
		INSERT INTO @tblFunctions (ProductId, FunctionId,TypeID)					
		SELECT 	6 AS ProductId -- CS
		,19 AS FunctionID ---RNG Casino Win Loss
		,2 AS TypeId	--- LA Function
			
	END

	IF @ProductCode = 'KN'
	BEGIN 
		INSERT INTO @tblFunctions (ProductId, FunctionId,TypeID)
		SELECT	8 AS ProductId -- KN
				,32  
				,2 AS TypeId	 -- LA Function
		UNION ALL
		SELECT 8 AS ProductId -- KN
				,57  
				,2 AS TypeId	 -- LA Function
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
								--,63 -- AG Casino Balance	-- just open for 12bet					
								)
		UNION ALL
		SELECT 10 AS ProductId -- AGC
				,58  
				,2 AS TypeId	 -- LA Function
	END	

	IF @ProductCode = 'GD'
	BEGIN 
		INSERT INTO @tblFunctions (ProductId, FunctionId,TypeID)
		SELECT	11 AS ProductId -- GD
				,FunctionID  
				,1 AS TypeId	 -- Lrf Function
		FROM dbo.Functions WITH (NOLOCK)
		WHERE FunctionId    IN (
									3  -- REPORTS
								,65 -- Gold Deluxe Winloss
								)
		UNION ALL
		SELECT 11 AS ProductId -- GD
				,43  
				,2 AS TypeId	 -- LA Function
	END
	
	IF @ProductCode = 'VG' -- Voidbridge aka  Vegas games  
	BEGIN   
		INSERT INTO @tblFunctions (ProductId, FunctionId,TypeID)  
		SELECT 12 AS ProductId -- VG  
			,FunctionID    
			,1 AS TypeId  -- Lrf Function  
		FROM dbo.Functions WITH (NOLOCK)  
		WHERE FunctionId IN (  
								3  -- REPORTS  
								,66 -- Vegas games Winloss  
							)  
	END  
   
	IF @ProductCode = 'MGCRNG'    
	BEGIN   
		INSERT INTO @tblFunctions (ProductId, FunctionId,TypeID)  
		SELECT 17 AS ProductId -- MGCRNG  
			,FunctionID    
			,1 AS TypeId  -- Lrf Function  
		FROM dbo.Functions WITH (NOLOCK)  
		WHERE FunctionId IN (  
								3		-- REPORTS  
								,67 -- Microgamming WL
								,68	-- CasinoProgressiveWins  
							)  
	END   

	IF @ProductCode = 'MGCLC'    
	BEGIN   
		INSERT INTO @tblFunctions (ProductId, FunctionId,TypeID)  
		SELECT 14 AS ProductId -- MGCLC  
			,FunctionID    
			,1 AS TypeId  -- Lrf Function  
		FROM dbo.Functions WITH (NOLOCK)  
		WHERE FunctionId IN (  
								3	-- REPORTS 
								,67 -- Microgamming WL								
							)  
	END   

	IF @ProductCode = 'AB'
	BEGIN
		INSERT INTO @tblFunctions (ProductId, FunctionId,TypeID)		
		SELECT 	21 AS ProductId -- AB
				,64 AS FunctionID -- AllBet Win lossS		
				,2 AS TypeId	--- LA Function
	END
	
	IF @ProductCode = 'NG2'
	BEGIN
		INSERT INTO @tblFunctions (ProductId, FunctionId,TypeID)		
		SELECT 	23 AS ProductId -- Number Game 2
				,65 AS FunctionID -- Number Game 2 Winloss
				,2 AS TypeId	--- LA Function
	END

	IF @ProductCode = 'CB'
	BEGIN
		INSERT INTO @tblFunctions (ProductId, FunctionId,TypeID)
		SELECT	15 AS ProductId -- CB
				,FunctionID  
				,1 AS TypeId	 -- Lrf Function
		FROM dbo.Functions WITH (NOLOCK)
		WHERE FunctionId    IN (
									3  -- REPORTS
								,71 -- Gold Deluxe Winloss
								)
		UNION ALL
		SELECT 15 AS ProductId -- CB
				,55  
				,2 AS TypeId	 -- LA Function
	END
	
	IF @ProductCode = 'FW'
	BEGIN
		INSERT INTO @tblFunctions (ProductId, FunctionId,TypeID)		
		SELECT 	24 AS ProductId -- Fishing World
				,66 AS FunctionID -- Fishing World Win lossS		
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
								,72 -- Cashout Win Loss
								)
		UNION ALL 
		SELECT 	25 AS ProductId -- CashOut
				,68 AS FunctionID -- Cashout Winloss Win lossS		
				,2 AS TypeId	--- LA Function
	END

	IF @ProductCode = 'LT'
	BEGIN
		INSERT INTO @tblFunctions (ProductId, FunctionId,TypeID)		 
		SELECT 	28 AS ProductId -- LT
				,70 AS FunctionID -- LT Winloss Win lossS		
				,2 AS TypeId	--- LA Function
	END

	IF @ProductCode = 'VS2'
	BEGIN
		INSERT INTO @tblFunctions (ProductId, FunctionId,TypeID)		 
		SELECT 	27 AS ProductId -- VS2
				,71 AS FunctionID -- VS2 Winloss Win lossS		
				,2 AS TypeId	--- LA Function
	END

	IF @ProductCode = 'BX'
	BEGIN 
		INSERT INTO @tblFunctions (ProductId, FunctionId,TypeID)	
		SELECT	31 AS ProductId -- Exchange
				,FunctionID  
				,1 AS TypeId	 -- Lrf special Function
		FROM dbo.Functions WITH (NOLOCK)
		WHERE FunctionId    IN (
								3 -- REPORTS						
								,77  -- Exchange Winloss
								)
	END

	SELECT DISTINCT ProductId, FunctionId,TypeID
	FROM @tblFunctions ORDER BY ProductId,FunctionId  ASC
		/*
			EXEC DBA_FunctionProduct
		*/
END
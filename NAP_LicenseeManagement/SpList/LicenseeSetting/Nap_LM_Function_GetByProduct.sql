/*<info serverAlias="DBCUST-bodb_Licensee" executers="bodbLicenseeNet,Dot_Member" viewers="" isFunction="0" isNested="1"></info>*/

CREATE PROCEDURE [dbo].[Nap_LM_Function_GetByProduct]
(
	@ProductCode VARCHAR(10) = ''
)
/*
	Created: Amanda
	Date: 2019-04-19
	Task: Get corresponding functions of product 
	DB: DBCUST.bodb_licensee
	Original : DBA_Lrf_FunctionProduct
	
	Revisions:
		- 20190419@Amanda: Copy code from DBA_Lrf_FunctionProduct [Redmine: #111321]
		- 20190422@Amanda: Remove Racing from LRF [Redmine: #99378]
		- 20190422@Amanda: Remove MicroGaming [Redmine: #107704]
		- 20191202@Amanda: Remove LA functions and inactive LRF functions [Redmine: #119443]
*/
AS
BEGIN
	SET NOCOUNT ON

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
								,69 -- Weekly Live Matches
								,70 -- Edit Bet Setting		
								,76 -- GMT +8
								,79 -- Betting ticket center
								)
			OR FunctionId BETWEEN 51 AND 56
			OR FunctionId BETWEEN 36 AND 43
			OR FunctionId BETWEEN 7 AND 33
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
								,71 -- Colossus Bets Win loss
								)
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
END
GO
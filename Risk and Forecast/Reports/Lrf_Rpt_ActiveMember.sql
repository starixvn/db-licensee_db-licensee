/*<info serverAlias="DBEXT-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/
USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Lrf_Rpt_ActiveMember]   
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@Products		VARCHAR(100) = '',
	@TotalActive	INT OUTPUT,
	@AgentList		VARCHAR(MAX)
AS
/*  Created: Florent.Nguyen    
	Date: 2015-01-25  
    Task: Count Active Member for Licensee by Month  
    DB: DB052.bodb02    
     
    Revisions:    
     - 20150624@Winnie: exclude 3 transactions SOLD/BOUGHT/BetTrade Commission 
	 - 20170228@Paul: Get @AgentList by web instead of @UserId, @CurrencyID, @LicenseeID, Remove @excludeTest [Redmine: #71679]
	
	Param's Explanation:         
	   + @excludeTest: remove currency UUS  
	   + @Products: List all product short name, seperate by ','  
  
DECLARE @TotalActive INT  
EXEC [Lrf_Rpt_ActiveMember]   
   @LicenseeID  = 1  
 , @UserID   = 1288  
 , @CurrencyID  = 0  
 , @FromDate   = '2014-01-30'  
 , @ToDate   = '2014-09-30'  
 , @Products   = 'SB,NG,VS,RB'  
 , @excludeTest  = 0  
 , @TotalActive  = @TotalActive OUTPUT  
SELECT @TotalActive TotalActive  
*/    
BEGIN     
	SET NOCOUNT ON    
  
	CREATE TABLE #Data
	(
		TransDate	DATE,
		CustID		INT,
		ProductID	INT,
		Memcount	BIGINT
	)

	CREATE TABLE #ProductsID
	(
		ProductID		INT,
		ProductPrefix	VARCHAR(10)
	)

	DECLARE @tempAg TABLE
	(
		CustID			INT,
		Currency		INT
	)
	DECLARE @_FromDate	SMALLDATETIME,
			@_ToDate	SMALLDATETIME,
			@Cols		NVARCHAR(MAX) = NULL,
			@Query		NVARCHAR(MAX)
  
	SELECT	@_FromDate = @FromDate,
			@_ToDate   = @ToDate  
  
	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@AgentList
	
		INSERT INTO @TempAg(CustId, Currency)
		SELECT AgentId, Currency 
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
			,ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH;

	IF ISNULL(@Products, '') = ''  
		RETURN  
	ELSE    
		BEGIN  
			INSERT INTO #ProductsID(ProductID, ProductPrefix)  
			SELECT ProductID, ProductPrefix  
			FROM bodb_licensee.dbo.LRF_f_Products3rd(@Products)  
		END    
  
	DELETE FROM #ProductsID WHERE ProductID = 13 -- bettrade
	
	INSERT INTO #Data(TransDate, CustID, ProductID, Memcount)  
	(  
		SELECT
			DATEADD(DAY, 1 - DATEPART(DAY, c.TransDate), c.TransDate) AS TransDate,
			c.CustId,
			c.ProductId,
			COUNT(1) AS MemCount  
		FROM bodb_LicenseeReport.dbo.rptCustomerActive c WITH(NOLOCK)    
			INNER JOIN @tempAg t ON c.Recommend = t.CustID AND c.CurrencyId = t.Currency    		
		WHERE c.TransDate BETWEEN @_FromDate AND @_ToDate  
			AND EXISTS (SELECT ProductID FROM #ProductsID p WHERE c.ProductId = p.ProductID)  
		GROUP BY DATEADD(DAY, 1 - DATEPART(DAY, c.TransDate), c.TransDate), c.CustId, c.ProductId  
	)  
  
	SELECT
		TransDate,
		COUNT (a.MemCount) AS MemCount
	INTO #CountPerMonth  
	FROM
	(  
		SELECT
			TransDate,
			COUNT(d.MemCount) AS MemCount
		FROM #Data d  
		GROUP BY d.TransDate, d.CustID
	) a
	GROUP BY TransDate
  
	SELECT @Cols = COALESCE(@Cols + ',' + QUOTENAME(CAST(ProductPrefix AS VARCHAR)), QUOTENAME(CAST(ProductPrefix AS VARCHAR)))  
	FROM #ProductsID  
  
	SET @Query = 'SELECT TransDate, ' + @Cols + ' , MemCountPerMonth  
					FROM  
					(  
						SELECT s.TransDate, ProductPrefix, s.MemCount, MemCountPerMonth  
						FROM  
						(  
						SELECT d.TransDate, p.ProductPrefix , COUNT(d.MemCount) AS MemCount, t.MemCount AS MemCountPerMonth  
						FROM #Data d  
							INNER JOIN #CountPerMonth t ON t.TransDate = d.TransDate   
							LEFT JOIN #ProductsID p ON d.ProductId = p.ProductID      
						GROUP BY d.TransDate, ProductPrefix, t.MemCount  
						) s      
					) x  
					PIVOT   
					(  
						SUM(MemCount)  
						FOR ProductPrefix IN (' + CONVERT(VARCHAR(1000), @Cols) + ')  
					) p ORDER BY TransDate'  
	
	EXECUTE sp_executesql @Query;   
  
	SELECT @TotalActive = COUNT (1)   
	FROM   
	(  
		SELECT COUNT(d.MemCount) AS MemCount  
		FROM #Data d  
		GROUP BY d.CustID  
	) a  

	DROP TABLE #Data
	DROP TABLE #CountPerMonth
	DROP TABLE #ProductsID

END     

GO
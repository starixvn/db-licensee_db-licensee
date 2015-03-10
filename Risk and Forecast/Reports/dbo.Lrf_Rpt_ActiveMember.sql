USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_Rpt_ActiveMember]    Script Date: 10/02/2015 14:24:02 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
  
ALTER PROCEDURE [dbo].[Lrf_Rpt_ActiveMember]   
	  @LicenseeID		INT  
	, @UserID			INT  
	, @CurrencyID		INT				= 0  
	, @FromDate		SMALLDATETIME  
	, @ToDate			SMALLDATETIME  
	, @Products		VARCHAR(100)	= ''   
	, @excludeTest		BIT				= 0  
	, @TotalActive		INT OUTPUT  
AS    
/*  Created: Florent.Nguyen    
	Date: 2015-01-25  
    Task : Count Active Member for Licensee by Month  
    DB: DB052.bodb02    
     
    Revisions:    
      
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
  
	CREATE TABLE #Data (
		TransDate		DATE
		, CustID		INT
		, ProductID		INT
		, Memcount		BIGINT
		)

	CREATE TABLE #ProductsID (
		ProductID			INT
		, ProductPrefix		VARCHAR(10)
		)

	DECLARE @tempAg AS TABLE (
		CustID			INT
		, Currency		INT
		)
	DECLARE @_FromDate SMALLDATETIME
		, @_ToDate		SMALLDATETIME
		, @Cols			NVARCHAR(MAX) = NULL
		, @Query		NVARCHAR(MAX)
  
	SELECT @_FromDate = @FromDate
		, @_ToDate = @ToDate  
  
	SELECT currencyID, LicenseeID   
	INTO #Currency  
	FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID, @userID, 1)-- System is default=1 (LRF)  
	WHERE (@CurrencyID = 0  OR (@CurrencyID <> 0 AND CurrencyID = @CurrencyID))  
   
	INSERT INTO @tempAg (CustID, Currency)   
	SELECT lc.CustID, lc.Currency   
	FROM bodb_Licensee.dbo.f_SelLicenseeCust(@licenseeID) lc   
		INNER JOIN #Currency c ON lc.LicenseeID = c.LicenseeID AND lc.Currency = c.CurrencyID   
	WHERE (@excludeTest = 0 OR (@excludeTest = 1 AND lc.Currency <> 20))  
  
	---  
	DROP TABLE #Currency  
	---  
	IF ISNULL(@Products, '') = ''  
		RETURN  
	ELSE    
		BEGIN  
			INSERT INTO #ProductsID(ProductID, ProductPrefix)  
			SELECT ProductID, ProductPrefix  
			FROM bodb_licensee.dbo.LRF_f_Products3rd(@Products)  
		END    
  
	INSERT INTO #Data(TransDate, CustID, ProductID, Memcount)  
	(  
		SELECT DATEADD(DAY, 1 - DATEPART(DAY, c.TransDate), c.TransDate) AS TransDate
			, c.CustId
			, c.ProductId
			, COUNT(1) AS MemCount  
		FROM bodb_LicenseeReport.dbo.rptCustomerActive c WITH(NOLOCK)    
			INNER JOIN @tempAg t ON c.Recommend = t.CustID AND c.CurrencyId = t.Currency    		
		WHERE c.TransDate BETWEEN @_FromDate AND @_ToDate  
			AND EXISTS (SELECT ProductID FROM #ProductsID p WHERE c.ProductId = p.ProductID)  
		GROUP BY DATEADD(DAY, 1 - DATEPART(DAY, c.TransDate), c.TransDate), c.CustId, c.ProductId  
	)  
  
	SELECT TransDate  
		, COUNT (a.MemCount) AS MemCount  
	INTO #CountPerMonth  
	FROM   
	(  
		SELECT TransDate  
			, COUNT(d.MemCount) AS MemCount    
		FROM #Data d  
		GROUP BY d.TransDate, d.CustID  
	) a  
	GROUP BY TransDate  
  
	SELECT @Cols = COALESCE(@Cols + ',' + QUOTENAME(CAST(ProductPrefix AS VARCHAR)),QUOTENAME(CAST(ProductPrefix AS VARCHAR)))  
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
	--print (@query)  
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
GRANT EXECUTE ON [dbo].[Lrf_Rpt_ActiveMember] TO [bodbLicenseeNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_ActiveMember] TO [vnteam] 
USE [bodb_licensee]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROC [dbo].[Lrf_rpt_DWTopCustomerSel]
    @FromDate		SMALLDATETIME ,
    @ToDate			SMALLDATETIME ,
    @sortingid		BIT				= 0 ,
    @currencyid		INT				= 0 ,
    @customer		VARCHAR(150)	= '' ,
    @activemin		INT				= 0 ,
    @wlmtotalmin	MONEY			= 0 ,
    @betcountmin	INT				= 0 ,
    @sportid		INT				= 0 ,     
    @toprow			INT				= 10,
	@UserID			INT,
	@basedcurrency  SMALLINT		= 0
AS 
/*
Created: 20140402@Winnie
Task : 

DB: DBLIC.bodb_licensee

Revison:
	- 20140620@Florent: offer 14 new bettypes and Sporting Solution (36 new bettypes)

Param's Explanation:
    @sortingid: (0: order by best winloss member, 1: order by worst winloss member)
	@basedcurrency: convert to currency USD or EURO (-2:USD -1:EURO)
*/
DECLARE  @LicenseeID	INT
DECLARE  @ActiveDate	SMALLDATETIME
SET @LicenseeID		=3
SET @activemin		= ISNULL(@activemin, 0)
SET @wlmtotalmin	= ISNULL(@wlmtotalmin, 0)
SET @betcountmin	= ISNULL(@betcountmin, 0)
SET @customer		= ISNULL(@customer, '')
SET @basedcurrency	= ISNULL(@basedcurrency, 0)
SET @ActiveDate		=CONVERT(VARCHAR(10), DATEADD(day,
                                -@activemin,
                                CURRENT_TIMESTAMP), 120)
    
SELECT  currencyID,LicenseeID into #currency
FROM  bodb02.dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)
WHERE (@CurrencyID=0  OR (@CurrencyID<>0 AND CurrencyID=@CurrencyID))
DELETE FROM #currency WHERE CurrencyID=20
DECLARE @TempAg AS TABLE ( CustId INT,Currency INT,CurrencyName VARCHAR(20) )
INSERT  INTO @TempAg(CustId,Currency,CurrencyName)
SELECT CustID,Currency,CurrencyName
FROM bodb_Licensee.dbo.LicenseeCust lc WITH ( NOLOCK )
	INNER JOIN #Currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID

DROP TABLE #Currency 

DECLARE @Exchange	AS TABLE (
	ExchangeDate	SMALLDATETIME,
	ExchangeId		INT,
	Code			VARCHAR(20) NULL,
	MYR				FLOAT,
	USD				FLOAT,
	EUR				FLOAT
	, PRIMARY KEY(ExchangeDate,ExchangeId)
)
INSERT INTO @Exchange (ExchangeDate,ExchangeId,Code,MYR,USD,EUR)
SELECT 
	ExchangeDate,
	ExchangeId,
	b.CurrencyName,
	MYR,
	USD,
	EUR
FROM bodb02.dbo.Lrf_f_GetExchangeDaily(@FromDate,@ToDate) a
INNER JOIN @TempAg b ON a.ExchangeId=b.Currency

    CREATE TABLE #TempCust
(	
	CustId				INT PRIMARY KEY	
	) 
IF(@sortingid=0)
BEGIN
	IF(@activemin=0)
	BEGIN

	SELECT  TOP (@toprow)	
			c.UserName,			
			e.Code	AS Currency,		
			MAX(b.winlostdate) AS LastActiveDate,
			CASE @basedcurrency
			WHEN -2
			THEN
			SUM(b.stake*e.USD)
			WHEN -1
			THEN 
			SUM(b.stake*e.EUR)
			ELSE
			SUM(b.stake)
			END AS Turnover,
			CASE @basedcurrency
			WHEN -2
			THEN
			SUM(b.winlost*e.USD)
			WHEN -1
			THEN 
			SUM(b.winlost*e.EUR)
			ELSE
			SUM(b.winlost)
			END AS MemberWinlost,
			CASE @basedcurrency
			WHEN -2
			THEN
			-SUM(b.winlost*e.USD)
			WHEN -1
			THEN 
			-SUM(b.winlost*e.EUR)
			ELSE
			-SUM(b.winlost)
			END AS LicenseeWL,		
			SUM(b.BetCount)			AS betcount
		
		
		FROM    
			bodb_LicenseeReport.[dbo].[rptCustomerTurnover] b WITH ( NOLOCK)
			INNER JOIN @TempAg ag  ON ag.custid = b.recommend
			INNER JOIN bodb02.dbo.Customer c WITH ( NOLOCK) ON b.custid=c.custid			
			LEFT  JOIN @Exchange e  ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency

		WHERE   
			b.winlostdate BETWEEN @FromDate AND @ToDate
			AND (b.bettype<31 OR (b.bettype BETWEEN 121 AND 999) OR (b.bettype BETWEEN 1301 AND 1399))			
			AND (@sportid=0 OR(@sportid<>0 AND b.sporttype=@sportid))
			AND (@customer='' OR (@customer<>'' AND c.username=@customer))				
		GROUP BY c.UserName,e.Code
		HAVING
		(@betcountmin=0 OR (@betcountmin<>0 AND SUM(b.BetCount)>=@betcountmin))
		AND
		(@wlmtotalmin=0 OR
		(
		@wlmtotalmin<=
		CASE @basedcurrency WHEN -2
		THEN
		SUM(b.winlost*e.USD)
		WHEN -1
		THEN
		SUM(b.winlost*e.EUR)
		ELSE		
		SUM(b.winlost)
		END
		)
		)
		ORDER BY  
		CASE 
		WHEN  @basedcurrency=-2
		THEN
		SUM(b.winlost*e.USD) 
		WHEN  @basedcurrency=-1
		THEN
		SUM(b.winlost*e.EUR) 	
		ELSE
		SUM(b.winlost) 
		END
		DESC
		
		END
		ELSE
		BEGIN
    INSERT INTO #TempCust
    
     SELECT
			DISTINCT b.custid AS CustId--,
		
		FROM    
			DBWH.bodb_Account.dbo.rptCustomerSite b WITH ( NOLOCK)		
		WHERE   
			b.rptDate <	@ActiveDate 
            AND SiteId=37       
    
    
	SELECT  	TOP (@toprow)
			c.UserName,			
			e.Code						AS Currency,			
			MAX(b.winlostdate) AS LastActiveDate,
				CASE @basedcurrency
			WHEN -2
			THEN
			SUM(b.stake*e.USD)
			WHEN -1
			THEN 
			SUM(b.stake*e.EUR)
			ELSE
			SUM(b.stake)
			END AS Turnover,
			CASE @basedcurrency
			WHEN -2
			THEN
			SUM(b.winlost*e.USD)
			WHEN -1
			THEN 
			SUM(b.winlost*e.EUR)
			ELSE
			SUM(b.winlost)
			END AS MemberWinlost,
			CASE @basedcurrency
			WHEN -2
			THEN
			-SUM(b.winlost*e.USD)
			WHEN -1
			THEN 
			-SUM(b.winlost*e.EUR)
			ELSE
			-SUM(b.winlost)
			END AS LicenseeWL,		
			SUM(b.BetCount)			AS betcount
			
		FROM    
			bodb_LicenseeReport.[dbo].[rptCustomerTurnover] b WITH ( NOLOCK)
			INNER JOIN @TempAg ag  ON ag.custid = b.recommend
			INNER JOIN #TempCust aa ON b.custid=aa.CustId	
			INNER JOIN bodb02.dbo.Customer c WITH ( NOLOCK) ON b.custid=c.custid					
			LEFT  JOIN @Exchange e  ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
			
		WHERE   
			b.winlostdate BETWEEN @FromDate AND @ToDate
			AND (b.bettype<31 OR (b.bettype BETWEEN 121 AND 999) OR (b.bettype BETWEEN 1301 AND 1399))	
			AND (@sportid=0 OR(@sportid<>0 AND b.sporttype=@sportid))
			AND (@customer='' OR (@customer<>'' AND c.username=@customer))	
				
		GROUP BY c.UserName,e.Code
		HAVING
		(@betcountmin=0 OR (@betcountmin<>0 AND SUM(b.BetCount)>=@betcountmin))
		AND
		(@wlmtotalmin=0 OR
		(
		@wlmtotalmin<=
		CASE @basedcurrency WHEN -2
		THEN
		SUM(b.winlost*e.USD)
		WHEN -1
		THEN
		SUM(b.winlost*e.EUR)
		ELSE		
		SUM(b.winlost)
		END
		)
		)
		ORDER BY  
		CASE 
		WHEN  @basedcurrency=-2
		THEN
		SUM(b.winlost*e.USD) 
		WHEN  @basedcurrency=-1
		THEN
		SUM(b.winlost*e.EUR) 	
		ELSE
		SUM(b.winlost) 
		END
		DESC
	
		END
END
ELSE
BEGIN
	IF(@activemin=0)
	BEGIN

	SELECT  TOP (@toprow)	
			c.UserName,			
			e.Code						AS Currency,		
			MAX(b.winlostdate) AS LastActiveDate,
				CASE @basedcurrency
			WHEN -2
			THEN
			SUM(b.stake*e.USD)
			WHEN -1
			THEN 
			SUM(b.stake*e.EUR)
			ELSE
			SUM(b.stake)
			END AS Turnover,
			CASE @basedcurrency
			WHEN -2
			THEN
			SUM(b.winlost*e.USD)
			WHEN -1
			THEN 
			SUM(b.winlost*e.EUR)
			ELSE
			SUM(b.winlost)
			END AS MemberWinlost,
			CASE @basedcurrency
			WHEN -2
			THEN
			-SUM(b.winlost*e.USD)
			WHEN -1
			THEN 
			-SUM(b.winlost*e.EUR)
			ELSE
			-SUM(b.winlost)
			END AS LicenseeWL,		
			SUM(b.BetCount)			AS betcount
		
		FROM    
			bodb_LicenseeReport.[dbo].[rptCustomerTurnover] b WITH ( NOLOCK)
			INNER JOIN @TempAg ag  ON ag.custid = b.recommend			
			INNER JOIN bodb02.dbo.Customer c WITH ( NOLOCK) ON b.custid=c.custid			
			LEFT  JOIN @Exchange e  ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency

		WHERE   
			b.winlostdate BETWEEN @FromDate AND @ToDate
			AND (b.bettype<31 OR (b.bettype BETWEEN 121 AND 999) OR (b.bettype BETWEEN 1301 AND 1399))			
			AND (@sportid=0 OR(@sportid<>0 AND b.sporttype=@sportid))
			AND (@customer='' OR (@customer<>'' AND c.username=@customer))			
		GROUP BY c.UserName,e.Code
		HAVING
		(@betcountmin=0 OR (@betcountmin<>0 AND SUM(b.BetCount)>=@betcountmin))
		AND
		(@wlmtotalmin=0 OR
		(
		@wlmtotalmin<=
		CASE @basedcurrency WHEN -2
		THEN
		SUM(b.winlost*e.USD)
		WHEN -1
		THEN
		SUM(b.winlost*e.EUR)
		ELSE		
		SUM(b.winlost)
		END
		)
		)
		ORDER BY  
		CASE 
		WHEN  @basedcurrency=-2
		THEN
		SUM(b.winlost*e.USD) 
		WHEN  @basedcurrency=-1
		THEN
		SUM(b.winlost*e.EUR) 	
		ELSE
		SUM(b.winlost) 
		END
		ASC
		
		END
		ELSE
		BEGIN
    INSERT INTO #TempCust
    

   SELECT
			DISTINCT b.custid AS CustId
		
		FROM    
			DBWH.bodb_Account.dbo.rptCustomerSite b WITH ( NOLOCK)		
		WHERE   
			b.rptDate <	@ActiveDate
            AND SiteId=37       
   
    
	SELECT  	TOP (@toprow)
			c.UserName,			
			e.Code						AS Currency,
		
			MAX(b.winlostDate) AS LastActiveDate,
			CASE @basedcurrency
			WHEN -2
			THEN
			SUM(b.stake*e.USD)
			WHEN -1
			THEN 
			SUM(b.stake*e.EUR)
			ELSE
			SUM(b.stake)
			END AS Turnover,
			CASE @basedcurrency
			WHEN -2
			THEN
			SUM(b.winlost*e.USD)
			WHEN -1
			THEN 
			SUM(b.winlost*e.EUR)
			ELSE
			SUM(b.winlost)
			END AS MemberWinlost,
			CASE @basedcurrency
			WHEN -2
			THEN
			-SUM(b.winlost*e.USD)
			WHEN -1
			THEN 
			-SUM(b.winlost*e.EUR)
			ELSE
			-SUM(b.winlost)
			END AS LicenseeWL,		
			SUM(b.BetCount)			AS betcount
			
		FROM    
			bodb_LicenseeReport.[dbo].[rptCustomerTurnover] b WITH ( NOLOCK)
			INNER JOIN @TempAg ag  ON ag.custid = b.recommend
			INNER JOIN #TempCust aa ON b.custid=aa.CustId	
			INNER JOIN bodb02.dbo.Customer c WITH ( NOLOCK) ON b.custid=c.custid					
			LEFT  JOIN @Exchange e  ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
			
		WHERE   
			b.winlostdate BETWEEN @FromDate AND @ToDate
			AND (b.bettype<31 OR (b.bettype BETWEEN 121 AND 999) OR (b.bettype BETWEEN 1301 AND 1399))	
			AND (@sportid=0 OR(@sportid<>0 AND b.sporttype=@sportid))
			AND (@customer='' OR (@customer<>'' AND c.username=@customer))	
				
		GROUP BY c.UserName,e.Code
		HAVING
		(@betcountmin=0 OR (@betcountmin<>0 AND SUM(b.BetCount)>=@betcountmin))
		AND
		(@wlmtotalmin=0 OR
		(
		@wlmtotalmin<=
		CASE @basedcurrency WHEN -2
		THEN
		SUM(b.winlost*e.USD)
		WHEN -1
		THEN
		SUM(b.winlost*e.EUR)
		ELSE		
		SUM(b.winlost)
		END
		)
		)
		ORDER BY  
		CASE 
		WHEN  @basedcurrency=-2
		THEN
		SUM(b.winlost*e.USD) 
		WHEN  @basedcurrency=-1
		THEN
		SUM(b.winlost*e.EUR) 	
		ELSE
		SUM(b.winlost) 
		END
		ASC
	
		END
END		 
		DROP TABLE #TempCust
GO
GRANT EXECUTE ON [dbo].[Lrf_rpt_DWTopCustomerSel] TO [bodbLicenseeNet]
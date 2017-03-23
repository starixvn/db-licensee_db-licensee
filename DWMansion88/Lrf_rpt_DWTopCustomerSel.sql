USE [bodb_licensee]
GO
ALTER PROC [dbo].[Lrf_rpt_DWTopCustomerSel]
    @FromDate		SMALLDATETIME ,
    @ToDate			SMALLDATETIME ,
    @sortingid		BIT				= 0 ,
    @customer		VARCHAR(150)	= '',
    @activemin		INT				= 0 ,
    @wlmtotalmin	MONEY			= 0 ,
    @betcountmin	INT				= 0 ,
    @sportid		INT				= 0 ,     
    @toprow			INT				= 10,
	@basedcurrency  SMALLINT		= 0,
	@AgentList		VARCHAR(MAX)
AS 
/*
Created: 20140402@Winnie
Task : 

DB: DBLIC.bodb_licensee

Revison:
	- 20140620@Florent: offer 14 new bettypes and Sporting Solution (36 new bettypes)
	- 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
	- 20150127@Jim: support base on GBP Currency
	- 20170302@Paul: Get @AgentList by web instead of @UserId, @CurrencyID, @LicenseeID [Redmine: #71679]
Param's Explanation:
    @sortingid: (0: order by best winloss member, 1: order by worst winloss member)
	@basedcurrency: convert to currency USD or EURO (-2:USD -1:EURO)
*/
BEGIN
	DECLARE  @ActiveDate	SMALLDATETIME
	SET @activemin		= ISNULL(@activemin, 0)
	SET @wlmtotalmin	= ISNULL(@wlmtotalmin, 0)
	SET @betcountmin	= ISNULL(@betcountmin, 0)
	SET @customer		= ISNULL(@customer, '')
	SET @basedcurrency	= ISNULL(@basedcurrency, 0)
	SET @ActiveDate		=CONVERT(VARCHAR(10), DATEADD(day,
									-@activemin,
									CURRENT_TIMESTAMP), 120)
    
	DECLARE @TempAg AS TABLE (CustId INT, Currency INT)

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

	DECLARE @Exchange	AS TABLE (
		ExchangeDate	SMALLDATETIME,
		ExchangeId		INT,
		Code			VARCHAR(20) NULL,
		MYR				FLOAT,
		USD				FLOAT,
		EUR				FLOAT,
		GBP				FLOAT
		, PRIMARY KEY(ExchangeDate,ExchangeId)
	)
	INSERT INTO @Exchange (ExchangeDate, ExchangeId, Code, MYR, USD, EUR, GBP)
	SELECT 
		ExchangeDate,
		ExchangeId,
		lc.CurrencyName,
		MYR,
		USD,
		EUR,
		GBP
	FROM bodb02.dbo.Lrf_f_GetExchangeDaily(@FromDate,@ToDate) a
		INNER JOIN @TempAg b ON a.ExchangeId=b.Currency
		INNER JOIN dbo.f_SelLicenseeCust(0) lc ON b.Currency = lc.Currency AND b.CustId = lc.CustID

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
				WHEN -3
				THEN 
				SUM(b.stake*e.GBP)
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
				WHEN -3
				THEN 
				SUM(b.winlost*e.GBP)
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
				WHEN -3
				THEN 
				-SUM(b.winlost*e.GBP)
				ELSE
				-SUM(b.winlost)
				END AS LicenseeWL,		
				SUM(b.BetCount)			AS betcount
		
		
			FROM    
				bodb_LicenseeReport.[dbo].[rptCustomerTurnover] b WITH ( NOLOCK)
				INNER JOIN bodb02.dbo.Customer c WITH ( NOLOCK) ON b.custid=c.custid	
				INNER JOIN 	@TempAg ag ON b.recommend = ag.CustId AND b.Currency = ag.Currency
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
			WHEN -3
			THEN
			SUM(b.winlost*e.GBP)
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
			WHEN  @basedcurrency=-3
			THEN
			SUM(b.winlost*e.GBP) 		
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
				WHEN -3
				THEN 
				SUM(b.stake*e.GBP)
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
				WHEN -3
				THEN 
				SUM(b.winlost*e.GBP)
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
				WHEN -3
				THEN 
				-SUM(b.winlost*e.GBP)
				ELSE
				-SUM(b.winlost)
				END AS LicenseeWL,		
				SUM(b.BetCount)			AS betcount
			
			FROM    
				bodb_LicenseeReport.[dbo].[rptCustomerTurnover] b WITH ( NOLOCK)
				INNER JOIN #TempCust aa ON b.custid=aa.CustId	
				INNER JOIN bodb02.dbo.Customer c WITH ( NOLOCK) ON b.custid=c.custid	
				INNER JOIN 	@TempAg ag ON b.recommend = ag.CustID AND b.Currency = ag.Currency
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
			CASE @basedcurrency 
			WHEN -2
			THEN
			SUM(b.winlost*e.USD)
			WHEN -1
			THEN
			SUM(b.winlost*e.EUR)
			WHEN -3
			THEN
			SUM(b.winlost*e.GBP)
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
			WHEN  @basedcurrency=-3
			THEN
			SUM(b.winlost*e.GBP)	
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
				WHEN -3
				THEN 
				SUM(b.stake*e.GBP)
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
				WHEN -3
				THEN 
				SUM(b.winlost*e.GBP)
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
				WHEN -3
				THEN 
				-SUM(b.winlost*e.GBP)
				ELSE
				-SUM(b.winlost)
				END AS LicenseeWL,		
				SUM(b.BetCount)			AS betcount
		
			FROM    
				bodb_LicenseeReport.[dbo].[rptCustomerTurnover] b WITH ( NOLOCK)
				INNER JOIN bodb02.dbo.Customer c WITH ( NOLOCK) ON b.custid=c.custid	
				INNER JOIN 	@TempAg ag ON b.recommend = ag.CustID AND b.Currency = ag.Currency	
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
			CASE @basedcurrency 
			WHEN -2
			THEN
			SUM(b.winlost*e.USD)
			WHEN -1
			THEN
			SUM(b.winlost*e.EUR)
			WHEN -3
			THEN
			SUM(b.winlost*e.GBP)
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
			WHEN  @basedcurrency=-3
			THEN
			SUM(b.winlost*e.GBP) 		
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
				WHEN -3
				THEN 
				SUM(b.stake*e.GBP)
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
				WHEN -3
				THEN 
				SUM(b.winlost*e.GBP)
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
				WHEN -3
				THEN 
				-SUM(b.winlost*e.GBP)
				ELSE
				-SUM(b.winlost)
				END AS LicenseeWL,		
				SUM(b.BetCount)			AS betcount
			
			FROM    
				bodb_LicenseeReport.[dbo].[rptCustomerTurnover] b WITH ( NOLOCK)
				INNER JOIN #TempCust aa ON b.custid=aa.CustId	
				INNER JOIN bodb02.dbo.Customer c WITH ( NOLOCK) ON b.custid=c.custid	
				INNER JOIN 	@TempAg ag ON b.recommend = ag.CustID AND b.Currency = ag.Currency	
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
			WHEN -3
			THEN
			SUM(b.winlost*e.GBP)
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
			WHEN  @basedcurrency=-3
			THEN
			SUM(b.winlost*e.GBP) 
			ELSE
			SUM(b.winlost) 
			END
			ASC
	
			END
	END		 
		DROP TABLE #TempCust
END
GO
GRANT EXECUTE ON [dbo].[Lrf_rpt_DWTopCustomerSel] TO [bodbLicenseeNet]
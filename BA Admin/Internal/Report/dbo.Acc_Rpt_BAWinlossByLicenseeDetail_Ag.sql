/*<info serverAlias="DBEXT-bodb02" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_Rpt_BAWinlossByLicenseeDetail_Ag]  
	@LicenseeID		INT,
	@Currency		INT,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@drawfilter		SMALLINT = 1,
	@excludeTest	BIT = 0
AS
/*
	Created: Henry  
	Date: 2011-11-04
    Task: BA Winloss Report By Licensee Agent Detail
    DB: DBEXT.bodb02
   
    Revisions:  
		- 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily  
		- 20120803@Jim: add playercomm value (for give commision to member)
		- 20161022@Jim:move table to bodb_licenseereport [RedmineID :#60449]
		- 20191010@Percy: Replace LicenseeBATransaction to LicenseeBATransaction_active [RedmineID: #103656]
	
	Param's Explanation:  
	  +	@drawfilter: 'No Draw' filter is supportted (1:Normal 2:No Draw 3:No Draw for Turnover only)
	  + @excludeTest: remove currency UUS
*/  
BEGIN  
	SET NOCOUNT ON  
	--
	DECLARE @TempFromDate SMALLDATETIME  
	DECLARE @TempToDate SMALLDATETIME 
	DECLARE @FDate SMALLDATETIME  
	DECLARE @TDate SMALLDATETIME 	
	--to Deal With Parameter Sniffing
	SELECT @FDate=@FromDate,@TDate=@ToDate
	
	CREATE TABLE #tmp(  
		winlostdate		DATETIME,  
		Currency		INT,
		CustID			INT,
		TurnOver		MONEY,   	
		Winlost			MONEY,  
		AmtDueToBA		MONEY,   
		Comm			MONEY,
		PlayerComm		MONEY,
		Betcount		BIGINT
	)  
	

	IF @Tdate > @MoveBetsDay  
	--get FROM bettrans  
	BEGIN  
		IF @FDate <= @MoveBetsDay   
			SET @TempFromDate =  DATEADD(DAY,1,@MoveBetsDay)  
		ELSE  
			SET @TempFromDate = @FDate  
			
		INSERT INTO #tmp
		SELECT   
			b.winlostdate,
			b.Currency,
			b.recommend,
			SUM( stake
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111 THEN 0
					WHEN (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN 0.5
					ELSE 1 END
				ELSE 1 END
			) turnover,
			SUM(b.winlost - b.actual_stake) AS Winlost,
			- SUM (b.winlost - b.actual_stake + awinlost + comm)  AS AmtDueToBA ,
			SUM (comm ) AS Comm,
			SUM( b.playercomm ) AS PlayerComm, 
			COUNT(b.transid)
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
			   BetCount		
		FROM dbo.bettrans b WITH (NOLOCK,INDEX=PK_bettrans)   
			INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction_active BA WITH (NOLOCK) ON b.transid = BA.transid
			INNER JOIN bodb_Licensee.dbo.LicenseeCust lc WITH (NOLOCK) ON b.recommend = lc.custid
		WHERE 
			b.winlostdate BETWEEN @TempFromDate AND @Tdate AND
			b.ruben=1 AND   
			b.statusID NOT IN (101, 102, 103) AND
			lc.Currency = @Currency AND
			lc.LicenseeID = @LicenseeID 
		GROUP BY   
			b.winlostdate,b.currency,b.recommend, b.statusID
	END		

	IF @FDate <= @MoveBetsDay 
	BEGIN
		IF @TDate >= @MoveBetsDay
				SET @TempToDate = @MoveBetsDay
			ELSE
				SET  @TempToDate = @TDate
				
		INSERT INTO #tmp
		SELECT   
			b.winlostdate,
			b.currency,
			b.recommend,
			SUM(b.turnover
			*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111  THEN 0
					WHEN b.statusID IN (114,115) THEN 0.5
					ELSE 1 END
				ELSE 1 END
			),  
			sum(b.winlost) AS Winlost,
			- SUM (b.winlost+b.awinlost+b.comm) as AmountDueToBA,
			SUM (comm) as Comm,
			SUM( b.playercomm ) AS playercomm, 
			SUM(b.betcount)
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END	
			
		FROM bodb_licenseereport.dbo.rptLicWinloss2 b WITH ( NOLOCK )  
			INNER JOIN bodb_Licensee.dbo.LicenseeCust lc WITH (NOLOCK) ON b.recommend = lc.custid
		WHERE 
			b.winlostdate BETWEEN @FDate AND @TempToDate AND 
			b.roleid = 2 AND
			b.statusID <> 101 AND --exclude REJECT bets
			lc.Currency = @Currency AND
			lc.LicenseeID = @LicenseeID AND
			ISNULL(b.isBA,0) = 1
		GROUP BY   
			b.winlostdate,b.currency,b.recommend, b.statusID	
	END

	CREATE NONCLUSTERED INDEX IX_tmp on #tmp (Currency)	

	IF @excludeTest=1
	BEGIN
		DELETE FROM #tmp WHERE Currency = 20
	END 

	SELECT * INTO #TempExchange 
	FROM Lrf_f_GetExchangeDaily(@FDate,@TDate)
	WHERE exchangeid IN (SELECT DISTINCT Currency FROM #tmp)

	SELECT 
		c.username,
		b.custid,
		b.currency,
		CASE WHEN b.currency = 51 THEN 'INH' ELSE e.Code END AS CurrencyName,
		sum(b.Turnover)           AS Turnover,
		sum(b.winlost)            AS Winlost,
		sum(b.AmtDueToBA)         AS AmtDueToBA,
		sum(b.Comm) 			  AS Comm,
		sum(b.playercomm)         AS PlayerComm,
		sum(b.betcount)           AS BetCount,
		
		sum(b.Turnover * e.MYR)   AS TurnoverMYR,
		sum(b.winlost * e.MYR)    AS WinlostMYR,
		sum(b.AmtDueToBA * e.MYR) AS AmtDueToBAMYR,
		sum(b.Comm * e.MYR)       AS CommMYR,
		sum(b.playercomm*e.MYR)   AS PlayerCommMYR,
		
		sum(b.Turnover * e.USD)   AS TurnoverUSD,
		sum(b.winlost * e.USD)    AS WinlostUSD,
		sum(b.AmtDueToBA * e.USD) AS AmtDueToBAUSD,
		sum(b.Comm * e.USD)       AS CommUSD,
		sum(b.playercomm*e.USD)   AS PlayerCommUSD,
		
		sum(b.Turnover * e.EUR)   AS TurnoverEUR,
		sum(b.winlost * e.EUR)    AS WinlostEUR,
		sum(b.AmtDueToBA * e.EUR) AS AmtDueToBAEUR,
		sum(b.Comm * e.EUR)       AS CommEUR,
		sum(b.playercomm*e.EUR)   AS PlayerCommEUR
	FROM #tmp b
	INNER JOIN Customer c WITH (NOLOCK) ON b.custid = c.custid
	INNER JOIN #TempExchange e 
	ON b.Winlostdate = e.ExchangeDate AND b.currency = e.ExchangeId
	GROUP BY 
			b.currency,b.custid, c.username
			,CASE WHEN b.currency = 51 THEN 'INH' ELSE e.Code END
	ORDER BY c.username

	DROP TABLE #tmp
	DROP TABLE #TempExchange
END   
GO
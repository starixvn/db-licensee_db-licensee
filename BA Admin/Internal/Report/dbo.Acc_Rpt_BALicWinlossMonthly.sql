/*<info serverAlias="DBEXT-bodb02" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_Rpt_BALicWinlossMonthly]
	@FromDate SMALLDATETIME,
	@ToDate SMALLDATETIME
AS  
/*  Created: 20111024@Henry  
    Task: Monthly BA Winloss Report for Licensee By date range
    DB: DBEXT.bodb02  
   
    Revisions:  
		- 20111230@Henry: remove virtual concept
		- 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily  
		- 20120803@Jim: add playercomm value ( for give commision to member) 
		- 20161022@Jim:move table to bodb_licenseereport [RedmineID :#60449]
		- 20191010@Percy: Replace LicenseeBATransaction to LicenseeBATransaction_active [RedmineID: #103656]
	
	Param's Explanation:  
*/  
BEGIN  
SET NOCOUNT ON  


DECLARE @TempFromDate SMALLDATETIME  
DECLARE @TempToDate SMALLDATETIME 
DECLARE @MoveBetsDay SMALLDATETIME
DECLARE @FDate SMALLDATETIME 
DECLARE @TDate SMALLDATETIME

SELECT @FDate=@FromDate,@TDate=@ToDate 


SELECT @MoveBetsDay=MAX(eventdate)
	FROM bodb02.dbo.match14 WITH(NOLOCK)	


CREATE TABLE #tmp (
	Winlostdate SMALLDATETIME,
	Currency INT,
	LicenseeID INT,
	LicenseeName VARCHAR(50),
	turnover MONEY,
	winlost MONEY,
	--winlostVirtual MONEY,
	AmtDueToBA MONEY,
	--AmtDueToBAVirtual MONEY, 
	Comm MONEY,
	PlayerComm MONEY,
	--CommVirtual MONEY,
	Betcount INT)


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
		l.LicenseeID,
		l.LicenseeName,
		SUM(stake) AS turnover, 
		SUM(b.winlost - b.actual_stake) AS Winlost,
		--SUM((b.winlost - b.actual_stake)*b.virtualrate) AS WinlostVirtual,  
		- SUM (b.winlost - b.actual_stake + awinlost + comm)  AS AmtDueToBA ,
		--- SUM ((b.winlost - b.actual_stake + awinlost + comm) * b.virtualrate )  AS AmtDueToBAVirtual ,
		SUM (comm ) AS Comm,
		SUM(b.playercomm ) AS PlayerComm,
		--SUM ((comm - playercomm)*b.virtualrate) AS CommVirtual,
		COUNT(b.transid) AS BetCount	
	FROM dbo.bettrans b WITH (NOLOCK,INDEX=PK_bettrans)   
		INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction_active BA WITH (NOLOCK) ON b.transid = BA.transid
		INNER JOIN bodb_Licensee.dbo.LicenseeCust lc WITH (NOLOCK) ON b.recommend = lc.custid
		INNER JOIN bodb_Licensee.dbo.Licensees l WITH (NOLOCK) ON l.LicenseeID = lc.LicenseeID
	WHERE 
		b.winlostdate BETWEEN @TempFromDate AND @Tdate AND
		b.ruben=1 AND   
		b.statusID NOT IN (101, 102, 103) AND
		b.Currency <> 20
	GROUP BY   
		b.winlostdate,b.currency,l.LicenseeID,l.LicenseeName
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
		l.LicenseeID,
		l.LicenseeName,
		SUM(b.turnover) AS turnover, 
		sum(b.winlost) AS Winlost,
		--SUM(b.winlostvirtual) AS WinlostVirtual,
		- SUM (b.winlost+b.awinlost+b.comm) as AmountDueToBA,
		-- - SUM (b.winlostvirtual + b.commvirtual)  AS AmtDueToBAVirtual ,
		SUM (comm ) as Comm,
		SUM( b.playercomm  ) AS PlayerComm, 
		--SUM (b.commvirtual) AS CommVirtual,
		SUM(b.betcount) AS BetCount	
		
	FROM bodb_licenseereport.dbo.rptLicWinloss2 b WITH ( NOLOCK )  
		INNER JOIN bodb_Licensee.dbo.LicenseeCust lc WITH (NOLOCK) ON b.recommend = lc.custid
		INNER JOIN bodb_Licensee.dbo.Licensees l WITH (NOLOCK) ON l.LicenseeID = lc.LicenseeID
	WHERE 
		b.winlostdate BETWEEN @FDate AND @TempToDate AND 
		b.roleid = 2 AND
		lc.Currency <> 20 AND
		b.statusID <> 101 AND --exclude REJECT bets
		ISNULL(b.isBA,0) = 1
	GROUP BY   
		b.winlostdate,b.currency,l.LicenseeID,l.LicenseeName	
END

CREATE NONCLUSTERED INDEX IX_tmp on #tmp (Currency)	

SELECT * INTO #TempExchange 
	FROM Lrf_f_GetExchangeDaily(@FDate,@TDate)
	WHERE exchangeid IN (SELECT DISTINCT Currency FROM #tmp)

SELECT 
	b.LicenseeID,
	b.winlostdate,
	b.LicenseeName,
	b.currency,
	CASE WHEN b.currency = 51 THEN 'INH' ELSE e.Code END AS CurrencyName,
	sum(b.Turnover * e.ActualRate) AS TurnoverRM,
	--sum(b.winlostVirtual) AS WinlostVirtual,
	sum(b.winlost * e.ActualRate) AS WinlostRM,
	--sum(b.AmtDueToBAVirtual) AS AmtDueToBAVirtual,
	sum(b.AmtDueToBA * e.ActualRate) AS AmtDueToBARM,
	--sum(b.CommVirtual) AS CommVirtual,
	sum(b.Comm * e.ActualRate) AS CommRM,
	SUM(b.PlayerComm * e.ActualRate) AS PlayerCommRM,
	sum(b.betcount) AS BetCount
FROM #tmp b
INNER JOIN #TempExchange e 
ON b.Winlostdate = e.ExchangeDate AND b.currency = e.ExchangeId
GROUP BY b.LicenseeID,b.winlostdate,b.LicenseeName,b.currency,CASE WHEN b.currency = 51 THEN 'INH' ELSE e.Code END
ORDER BY b.LicenseeID,b.winlostdate,b.currency

DROP TABLE #tmp
DROP TABLE #TempExchange

END   
GO
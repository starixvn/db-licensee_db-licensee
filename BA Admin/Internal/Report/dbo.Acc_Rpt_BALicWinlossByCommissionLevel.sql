/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/
USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Acc_Rpt_BALicWinlossByCommissionLevel]  
	@LicenseeID	INT,
	@FromDate SMALLDATETIME,
	@ToDate SMALLDATETIME,
	@Currency		INT = 0,
	@drawfilter SMALLINT = 1,
	@excludeTest BIT = 0
AS  
/*  Created: Henry  
	Date: 2011-10-27
    TASk : BA Winloss Report By Commission Level
    DB: DBRPT/bodb02  
   
    Revisions:  
		- 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily  
		- 20130123@Daniel: Change link server alias
		- 20181031@Percy: Remove linked-server DBLIC [RedmineID: #103660]
		
	Param's Explanation:  
		+ @drawfilter: 'No Draw' filter is supportted (1:Normal 2:No Draw 3:No Draw for Turnover only)
		+ @excludeTest: remove currency UUS
		
*/  
 
SET NOCOUNT ON  

DECLARE @tmpAg	TABLE( custID INT PRIMARY KEY)  
DECLARE @MoveBetsDay SMALLDATETIME, @TempFromDate SMALLDATETIME, @TempToDate SMALLDATETIME ,@BalanceUpDay SMALLDATETIME
DECLARE @FDate SMALLDATETIME
DECLARE @TDate SMALLDATETIME

SELECT @FDate=@FromDate,@TDate=@ToDate

SELECT @MoveBetsDay=MAX(eventdate)
	FROM bodb02.dbo.match14 WITH(NOLOCK)	
	
SELECT 
		TOP 1 @BalanceUpDay = winlostdate
	FROM Bettrans WITH(NOLOCK)
	WHERE bettype = 20000 and matchid = 0	and custid = 3	


IF @Currency = 0   
BEGIN  
	INSERT INTO @tmpAg (custID) SELECT custID FROM bodb_Licensee.dbo.LicenseeCust WITH(NOLOCK) WHERE LicenseeID = @LicenseeID
END  
ELSE   
BEGIN  
	INSERT INTO @tmpAg (custID) SELECT custID FROM bodb_Licensee.dbo.LicenseeCust WITH(NOLOCK) WHERE LicenseeID = @LicenseeID AND Currency=@Currency
END  

CREATE TABLE #tmp
( 
    winlostdate        SMALLDATETIME,
    Currency        INT,
    discount        MONEY,
    Bettype            INT,
    Turnover        MONEY,      
    MemberWinlost    MONEY, 
    LicenseeComm        MONEY,
    AmtDueToBA        MONEY,
    BetCount        BIGINT
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
		b.winlostdate AS WinlostDate,
		b.Currency,
		discount AS Discount,
		bettype,
		SUM( stake
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111 THEN 0
					WHEN (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN 0.5
					ELSE 1 END
				ELSE 1 END
			) turnover, 
		
		SUM(b.winlost - b.actual_stake) AS MemberWinlost,
		SUM (comm) AS LicenseeComm,
		- SUM (b.winlost - b.actual_stake + awinlost + comm) AS AmtDueToBA,
		COUNT(b.transid)
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
			   BetCount	 
	FROM bettrans b WITH (NOLOCK,INDEX=PK_bettrans)
		INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction_active BA WITH (NOLOCK) ON b.transid = BA.transid
	WHERE
		b.winlostdate BETWEEN @TempFromDate AND @Tdate AND
		b.recommend IN (SELECT CustID FROM @tmpAg) AND
		b.ruben=1 AND
		b.statusID NOT IN (101, 102, 103)
		
	GROUP BY
		b.winlostdate,b.currency,discount, bettype,statusid
END

IF @FDate <= @MoveBetsDay 
BEGIN
	IF @TDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET  @TempToDate = @TDate
			
	IF @BalanceUpDay < @FDate 
		SELECT @BalanceUpDay=@FDate		
			
	INSERT INTO #tmp
	SELECT
		b.winlostdate AS WinlostDate,
		b.Currency,
		discount AS Discount,
		bettype,
		SUM( stake
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111 THEN 0
					WHEN (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN 0.5
					ELSE 1 END
				ELSE 1 END
			) turnover, 
		SUM(b.winlost - b.actual_stake) AS MemberWinlost,
		SUM (comm) AS LicenseeComm,
		- SUM (b.winlost - b.actual_stake + awinlost + comm) AS AmtDueToBA,
		COUNT(b.transid)
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
			   BetCount	 
	FROM bettrans14 b WITH (NOLOCK,INDEX=PK_bettrans14)
		INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction_bk BA WITH (NOLOCK) ON b.transid = BA.transid
	WHERE
		b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate AND 
		b.recommend IN (SELECT CustID FROM @tmpAg) AND
		b.ruben=1 AND
		b.statusID NOT IN (101, 102, 103)
		
	GROUP BY
		b.winlostdate,b.currency,discount, bettype	,statusid	
			
END

IF @FDate < @BalanceUpDay
BEGIN
	IF @TDate >= DATEADD(dd, -1, @BalanceUpDay)
		SET @TempToDate = DATEADD(dd, -1, @BalanceUpDay)
	ELSE
		SET @TempToDate = @TDate
		
	INSERT INTO #tmp
	SELECT
		b.winlostdate AS WinlostDate,
		b.Currency,
		discount AS Discount,
		bettype,
		SUM( stake
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111 THEN 0
					WHEN (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN 0.5
					ELSE 1 END
				ELSE 1 END
			) turnover, 
		SUM(b.winlost - b.actual_stake) AS MemberWinlost,
		SUM (comm) AS LicenseeComm,
		- SUM (b.winlost - b.actual_stake + awinlost + comm) AS AmtDueToBA,
		COUNT(b.transid)
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
			   BetCount	 
	FROM bodb_archive.dbo.bettrans_BK b WITH (NOLOCK,INDEX=IX_Transid)
		INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction_bk BA WITH (NOLOCK) ON b.transid = BA.transid
	WHERE
		b.winlostdate BETWEEN @FDate AND @TempToDate AND 
		b.recommend IN (SELECT CustID FROM @tmpAg) AND
		b.statusID NOT IN (101, 102, 103)
		
	GROUP BY
		b.winlostdate,b.currency,discount, bettype	,statusid		
		
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
    winlostdate,
    Currency,  
    CASE WHEN Currency = 51 THEN 'INH' ELSE e.Code END AS CurrencyName,
    discount,
    CASE WHEN bettype IN (1,2,3,7,8) THEN 'Asian HDP, OU, OE' ELSE 'Other bettypes' END AS Bettype,
   SUM(Turnover)    AS Turnover,  
   SUM(MemberWinlost)        AS MemberWinlost, 
   SUM(LicenseeComm) AS LicenseeComm,
   SUM(AmtDueToBA)    AS AmtDueToBA,
   SUM(Betcount)    AS Betcount,
  
    --BaseEUR 
   SUM(Turnover*e.EUR)    AS TurnoverEUR,  
   SUM(MemberWinlost*e.EUR)    AS MemberWinlostEUR, 
   SUM(LicenseeComm*e.EUR) AS LicenseeCommEUR,
   SUM(AmtDueToBA*e.EUR)    AS AmtDueToBAEUR
FROM   
    #tmp w  
    INNER JOIN #TempExchange e 
	ON w.winlostdate = e.ExchangeDate AND w.currency = e.ExchangeId
GROUP BY
    winlostdate,currency,CASE WHEN Currency = 51 THEN 'INH' ELSE e.Code END,discount,
	CASE WHEN bettype IN (1,2,3,7,8) THEN 'Asian HDP, OU, OE' ELSE 'Other bettypes' END
ORDER BY
  winlostdate,currency,CASE WHEN Currency = 51 THEN 'INH' ELSE e.Code END,discount,
	CASE WHEN bettype IN (1,2,3,7,8) THEN 'Asian HDP, OU, OE' ELSE 'Other bettypes' END
 
DROP TABLE #tmp 
DROP TABLE #TempExchange
GO
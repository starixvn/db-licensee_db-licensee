USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_Rpt_WinlossByLeagueDetail]    Script Date: 13/01/2014 10:09:46 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Lrf_Rpt_WinlossByLeagueDetail]  
	@LicenseeID INT
	,@UserID INT
	,@Odds FLOAT=0 
	,@CurrencyID INT=0
	,@LeagueID INT
	,@PageSize INT=1000
	,@PageIndex INT=1
	,@TotalRows INT=0 OUTPUT 	                
	,@FromDate SMALLDATETIME
	,@ToDate SMALLDATETIME
	,@MoveBetsDay SMALLDATETIME
	,@ShowWin BIT
	,@ShowLoss BIT
	,@ShowDraw BIT
AS   
/*  
Created: 20140102@Florent  
Task :   
DB: DB052.bodb02
Original:   
Revisions:  
Param's Explanation:   
   
*/  
  
/* demo script  
exec [Lrf_Rpt_MatchWinLossByBettype_xtest] @LicenseeID=3,@LicenseeType=default,@MatchID=1700257,@Date='May 19 2012 12:00:00:000AM',@MoveBetsDay='May 21 2012 12:00:00:000AM',@showSB=1,@showRB=1,@showNG=0,@showBA=0  
*/  

SET NOCOUNT ON

DECLARE @TempFromDate SMALLDATETIME
DECLARE @TempToDate SMALLDATETIME

DECLARE @ExchangeDaily TABLE (
	ExchangeDate SMALLDATETIME
	,ExchangeId INT
	,USD FLOAT
	,EUR FLOAT
	,PRIMARY KEY (
		ExchangeDate
		,ExchangeId
		)
	)

--SET @_Date = @Date  
DECLARE @Today SMALLDATETIME

SELECT @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120)

SELECT currencyID
	,LicenseeID
INTO #currency
FROM dbo.Lrf_f_GetCurrencybyUser(@licenseeID, @userID, 1) -- System is default=1 (LRF)
WHERE (
		@CurrencyID = 0
		OR (
			@CurrencyID <> 0
			AND CurrencyID = @CurrencyID
			)
		)

DECLARE @TempAg AS TABLE (CustId INT)

INSERT INTO @TempAg (CustId)
SELECT CustID
FROM bodb_Licensee.dbo.LicenseeCust lc WITH (NOLOCK)
INNER JOIN #Currency c ON lc.LicenseeID = c.LicenseeID
	AND lc.Currency = c.CurrencyID
--WHERE [Description] = COALESCE(@LicenseeType, [Description])

-----------------------------------    
DROP TABLE #currency

-----------------------------------
DECLARE @AgMatchWLDetails TABLE (
	custid INT
	,Winlostdate SMALLDATETIME
	,Currency INT
	,odds SMALLMONEY
	,sporttype SMALLINT
	,leagueid INT
	,turnover MONEY
	,MemberWinLost MONEY
	,LicenseeWL MONEY
	,AmtDueToBA MONEY
	,CommBA MONEY
	,PlayerComm MONEY
	,matchcode NVARCHAR(50)
	,isNeutral BIT
	,liveindicator BIT
	,betcount INT
	)

---
---
DECLARE @Status AS TABLE (StatusID INT)

IF @ShowWin = 1
BEGIN
	INSERT INTO @status
	SELECT 112
	INSERT INTO @status
	SELECT 114
END

IF @Showloss = 1
BEGIN
	INSERT INTO @status
	SELECT 113
	INSERT INTO @status
	SELECT 115
END

IF @Showdraw = 1
	INSERT INTO @status
	SELECT 111

----

--IF @_Date > @MoveBetsDay   
--BEGIN  
IF @Todate > @MoveBetsDay
BEGIN
	IF @FromDate <= @MoveBetsDay
		SET @TempFromDate = DATEADD(DAY, 1, @MoveBetsDay)
	ELSE
		SET @TempFromDate = @FromDate

	--Get general data  
	BEGIN
		INSERT INTO @AgMatchWLDetails
		SELECT b.custid
			,b.Winlostdate
			,b.currency
			,CASE WHEN OddsType = 1 THEN odds + 1 --decimal
					WHEN OddsType = 2 THEN Odds + 1 --hongkong to decimal
					WHEN OddsType IN (3,4) THEN --malay and indo to decimal
											CASE 
												WHEN odds < 0 THEN (1 -  cast(1 as float) / cast(odds AS float))
												WHEN odds >=0 THEN (1 + odds) END
					WHEN OddsType = 5 THEN --american odds to decimal
										CASE
										WHEN (odds * 100) < 0 THEN (1- cast (1 AS float)/ cast (odds AS float))
										WHEN (odds * 100) % 2 = 0 THEN 2
										WHEN (odds * 100) > 0 THEN (1 + odds) END 
					ELSE odds END odds
			,0 sporttype
			,m.leagueid
			,SUM(stake)
			,SUM(winlost-b.actual_stake)
			,- SUM(winlost-b.actual_stake) AS LicenseeWL
			,CASE 
				WHEN b.tpositiontaking = 0
					THEN - SUM(winlost-b.actual_stake + awinlost + comm)
				ELSE 0
				END AmountDueToBA
			,CASE 
				WHEN b.tpositiontaking = 0
					THEN - SUM(comm)
				ELSE 0
				END AS CommBA
			,SUM(b.playercomm) AS PlayerComm
			,m.matchcode
			,ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral
			,b.liveindicator AS liveindicator
			,COUNT(1) betcount
		FROM
			--#TempBetList b  
			bettrans AS b WITH (NOLOCK)
		INNER JOIN match m WITH (NOLOCK) ON m.matchid = b.matchid
		INNER JOIN @TempAg ta ON b.recommend = ta.CustId
		WHERE (
				b.bettype < 31
				OR (b.bettype BETWEEN 121 AND 999)
				)
			-- --AND b.tpositiontaking <> 0  
			AND b.winlostdate BETWEEN @TempFromDate AND @todate
			AND b.statusID IN (SELECT * FROM @status )
			AND m.leagueid = @LeagueID
		GROUP BY b.custid
			,b.Winlostdate
			,b.currency
			,m.leagueid
			,m.matchcode
			,m.isNeutral
			,b.liveindicator
			,b.tpositiontaking
			,CASE WHEN OddsType = 1 THEN odds + 1 --decimal
					WHEN OddsType = 2 THEN Odds + 1 --hongkong to decimal
					WHEN OddsType IN (3,4) THEN --malay and indo to decimal
											CASE 
												WHEN odds < 0 THEN (1 -  cast(1 as float) / cast(odds AS float))
												WHEN odds >=0 THEN (1 + odds) END
					WHEN OddsType = 5 THEN --american odds to decimal
										CASE
										WHEN (odds * 100) < 0 THEN (1- cast (1 AS float)/ cast (odds AS float))
										WHEN (odds * 100) % 2 = 0 THEN 2
										WHEN (odds * 100) > 0 THEN (1 + odds) END 
					ELSE odds END 
		ORDER BY b.winlostdate DESC
	END
	--SELECT * FROM @agMatchWLDetails

END

IF @Fromdate <= @MoveBetsDay
BEGIN
	IF @ToDate >= @MoveBetsDay
		SET @TempToDate = @MoveBetsDay
	ELSE
		SET @TempToDate = @ToDate

	--Get general data  
	--SELECT '222222222'
	BEGIN
		INSERT INTO @AgMatchWLDetails
		SELECT b.custid
			,b.Winlostdate
			,b.currency
			,CASE WHEN OddsType = 1 THEN odds + 1 --decimal
					WHEN OddsType = 2 THEN Odds + 1 --hongkong to decimal
					WHEN OddsType IN (3,4) THEN --malay and indo to decimal
											CASE 
												WHEN odds < 0 THEN (1 -  cast(1 as float) / cast(odds AS float))
												WHEN odds >=0 THEN (1 + odds) END
					WHEN OddsType = 5 THEN --american odds to decimal
										CASE
										WHEN (odds * 100) < 0 THEN (1- cast (1 AS float)/ cast (odds AS float))
										WHEN (odds * 100) % 2 = 0 THEN 2
										WHEN (odds * 100) > 0 THEN (1 + odds) END 
					ELSE odds END odds
			,0 AS sporttype
			,b.leagueid
			,SUM(stake)
			,SUM(winlost)
			,- SUM(b.winlost) AS LicenseeWL
			,
			CASE 
				WHEN b.isBA = 1
					THEN
						---sum(Winlost +  awinlost + comm) 
						0
				ELSE 0
				END AmountDueToBA
			,
			--SUM (comm ) AS CommBA, 
			0 AS CommBA
			,SUM(b.playercomm) AS PlayerComm
			,0 matchcode
			,0 AS IsNeutral
			,0 AS liveindicator
			,SUM(b.betcount) betcount
		FROM bodb_LicenseeReport.dbo.rptCustomerTurnover b WITH (NOLOCK,INDEX=IX_recommend)
		INNER JOIN @TempAg ta ON b.recommend = ta.CustId
		WHERE b.winlostdate BETWEEN @FromDate AND @TempToDate
		and (
				b.bettype < 31
				OR (b.bettype BETWEEN 121 AND 999)
		)
		AND b.leagueid=@LeagueID
		AND b.statusID IN (SELECT * FROM @status )
		GROUP BY b.custid
			,b.Winlostdate
			,b.currency
			,b.leagueid
			,b.isBA
			,CASE WHEN OddsType = 1 THEN odds + 1 --decimal
					WHEN OddsType = 2 THEN Odds + 1 --hongkong to decimal
					WHEN OddsType IN (3,4) THEN --malay and indo to decimal
											CASE 
												WHEN odds < 0 THEN (1 -  cast(1 as float) / cast(odds AS float))
												WHEN odds >=0 THEN (1 + odds) END
					WHEN OddsType = 5 THEN --american odds to decimal
										CASE
										WHEN (odds * 100) < 0 THEN (1- cast (1 AS float)/ cast (odds AS float))
										WHEN (odds * 100) % 2 = 0 THEN 2
										WHEN (odds * 100) > 0 THEN (1 + odds) END 
					ELSE odds END 
	END
END 

INSERT INTO @ExchangeDaily
SELECT ExchangeDate
	,ExchangeId
	,USD
	,EUR
FROM Lrf_f_GetExchangeDaily(@fromDate, @ToDate)

DECLARE @RowStart INT, @RowEnd INT 	
SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1

SELECT @TotalRows =count(a.custid)
FROM  
(SELECT custid FROM @AgMatchWLDetails
GROUP BY  custid	
		,sporttype
		,leagueid
		)A
		
--SELECT @TotalRow TotalRow 
-- Result  
SELECT A.* FROM 
	(
		SELECT	
		ROW_NUMBER() over(ORDER BY b.custid,
						  username
						  ,SUBSTRING(c.username2,  CHARINDEX('$',c.username2)+1, len(c.username2)-CHARINDEX('$',c.username2))
						  ,sporttype
						  ,leagueid) AS RowNum, 
		b.custid,
		c.username,
		SUBSTRING(c.username2,  CHARINDEX('$',c.username2)+1, len(c.username2)-CHARINDEX('$',c.username2)) AS nickname,
		sporttype
		,leagueid
		,CAST(SUM(turnover) AS MONEY) AS turnover
		,CAST(SUM(turnover * e.USD) AS MONEY) AS turnoverUSD
		,CAST(SUM(turnover * e.EUR) AS MONEY) AS turnoverEUR
		,CAST(SUM(MemberWinLost) AS MONEY) AS MemberWinLost
		,CAST(SUM(MemberWinLost * e.USD) AS MONEY) AS MemberWinLostUSD
		,CAST(SUM(MemberWinLost * e.EUR) AS MONEY) AS MemberWinLostEUR
		,
		--- licenseeWL  
		CAST(SUM(LicenseeWL) AS MONEY) AS LicenseeWL
		,CAST(SUM(LicenseeWL * e.USD) AS MONEY) AS LicenseeWLUSD
		,CAST(SUM(LicenseeWL * e.EUR) AS MONEY) AS LicenseeWLEUR
		,CAST(SUM(CommBA) AS MONEY) AS CommBA
		,CAST(SUM(CommBA * e.USD) AS MONEY) AS CommBAUSD
		,CAST(SUM(CommBA * e.EUR) AS MONEY) AS CommBAEUR
		,CAST(SUM(PlayerComm) AS MONEY) AS PlayerComm
		,CAST(SUM(PlayerComm * e.USD) AS MONEY) AS PlayerCommUSD
		,CAST(SUM(PlayerComm * e.EUR) AS MONEY) AS PlayerCommEUR
		,CAST(SUM(AmtDuetoBA) AS MONEY) AS AmtDuetoBA
		,CAST(SUM((AmtDuetoBA) * e.USD) AS MONEY) AS AmtDuetoBAUSD
		,CAST(SUM((AmtDuetoBA) * e.EUR) AS MONEY) AS AmtDuetoBAEUR
		,sum(b.betcount) betcount
	FROM @AgMatchWLDetails b
	INNER JOIN Customer c (NOLOCK) ON b.custid = c.custid
	INNER JOIN @ExchangeDaily e ON b.winlostdate = e.ExchangeDate
		AND b.currency = e.ExchangeId
	WHERE odds>=@odds
	GROUP BY b.custid,
	username
	,SUBSTRING(c.username2,  CHARINDEX('$',c.username2)+1, len(c.username2)-CHARINDEX('$',c.username2))
		,sporttype
		,leagueid
	--ORDER BY b.custid
	) A WHERE A.RowNum BETWEEN @RowStart AND @RowEnd

DROP TABLE @AgMatchWLDetails

GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_WinlossByLeagueDetail] TO [bodbLicenseeNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_WinlossByLeagueDetail] TO [vnteam] AS [dbo]
GO
	
	--SELECT TOP 100 * FROM bodb_LicenseeReport.dbo.rptCustomerTurnover AS rct WHERE rct.leagueid=3 
	--AND rct.winlostdate BETWEEN 'Nov 10 2013' AND 'Nov 15 2013' 
	--SELECT MIN(b.winlostdate),MAX(b.winlostdate) FROM dbo.bettrans14 AS b
	--SELECT MIN(b.winlostdate),MAX(b.winlostdate) FROM dbo.bettrans AS b

--EXEC Lrf_Rpt_MatchWinLossByCust_8828 1,1272,0,35,'2013-12-10','2013-12-15','2013-12-12'
--DECLARE @a int
--exec dbo.Lrf_Rpt_WinlossByLeagueDetail_8828 @LicenseeID=1,@UserID=1272,@CurrencyID=0,@LeagueID=29610,@FromDate='2013-12-30', @ToDate='2013-12-31',
--@MoveBetsDay='2013-12-28',@odds=2,@TotalRows=0
--SELECT @TotalRows

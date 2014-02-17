USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_Rpt_WinlossByLeagueDetail]    Script Date: 13/01/2014 10:09:46 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Lrf_Rpt_WinlossByLeagueDetail_11594] @LicenseeID INT
	,@UserID INT
	,@Odds FLOAT = 0
	,@CurrencyID INT = 0
	,@LeagueID INT
	,@MatchID INT =0
	,@PageSize INT = 1000
	,@PageIndex INT = 1
	,@TotalRows INT = 0 OUTPUT
	,@FromDate SMALLDATETIME
	,@ToDate SMALLDATETIME
	,@MoveBetsDay SMALLDATETIME
	,@ShowWin BIT =1
	,@ShowLoss BIT =1
	,@ShowDraw BIT =1
	,@ShowSB BIT = 1
	,@ShowBA BIT = 1
AS
/*  
Created: 20140102@Florent  
Task :   
DB: DB052.bodb02
Original:   
Revisions:  
	- 20140207@Florent: Add filter ShowBA and ShowSB
	- 20140214@Florent: use new sum table rptCustomerMatch
Param's Explanation:   
   
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

DECLARE @TempAg AS TABLE (CustId INT,Currency int)

INSERT INTO @TempAg (CustId,lc.currency)
SELECT CustID,lc.Currency
FROM bodb_Licensee.dbo.LicenseeCust lc WITH (NOLOCK)
INNER JOIN #Currency c ON lc.LicenseeID = c.LicenseeID
	AND lc.Currency = c.CurrencyID

--WHERE [Description] = COALESCE(@LicenseeType, [Description])
-----------------------------------    


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

	--ShowBA
	IF @ShowBA = 1
	BEGIN
		INSERT INTO @AgMatchWLDetails
		SELECT b.custid
			,b.Winlostdate
			,b.currency
			,CASE 
				WHEN (
						b.bettype IN (1, 2, 3, 7, 12, 8, 20)
						OR b.bettype BETWEEN 81 AND 88
						OR b.bettype BETWEEN 90 AND 120
						)
					THEN CASE 
							WHEN b.OddsType = 1
								THEN b.odds + 1 --decimal
							WHEN b.OddsType = 2
								THEN b.Odds + 1 --hongkong to decimal
							WHEN b.OddsType IN (3, 4)
								THEN --malay and indo to decimal
									CASE 
										WHEN b.odds < 0
											THEN (1 - cast(1 AS FLOAT) / cast(b.odds AS FLOAT))
										WHEN b.odds >= 0
											THEN (1 + b.odds)
										END
							WHEN OddsType = 5
								THEN --american odds to decimal
									CASE 
										WHEN (b.odds * 100) < 0
											THEN (1 - cast(1 AS FLOAT) / cast(b.odds AS FLOAT))
										WHEN (b.odds * 100) % 2 = 0
											THEN 2
										WHEN (b.odds * 100) > 0
											THEN (1 + b.odds)
										END
							END
				ELSE b.Odds
				END odds
			,0 sporttype
			,m.leagueid
			,SUM(stake)
			,SUM(winlost - b.actual_stake)
			,0 AS LicenseeWL
			,CASE 
				WHEN b.tpositiontaking = 0
					THEN - SUM(winlost - b.actual_stake + awinlost + comm)
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
		WHERE (--SportBook
				b.bettype < 31
				OR (b.bettype BETWEEN 121 AND 999)
				)
			-- --AND b.tpositiontaking <> 0  
			AND b.winlostdate BETWEEN @TempFromDate AND @todate
			AND b.statusID IN (
				SELECT *
				FROM @status
				)
			AND m.leagueid = @LeagueID
			and b.tpositiontaking=0--GetBA
		GROUP BY b.custid
			,b.Winlostdate
			,b.currency
			,m.leagueid
			,m.matchcode
			,m.isNeutral
			,b.liveindicator
			,b.tpositiontaking
			,CASE 
				WHEN (
						b.bettype IN (1, 2, 3, 7, 12, 8, 20)
						OR b.bettype BETWEEN 81 AND 88
						OR b.bettype BETWEEN 90 AND 120
						)
					THEN CASE 
							WHEN b.OddsType = 1
								THEN b.odds + 1 --decimal
							WHEN b.OddsType = 2
								THEN b.Odds + 1 --hongkong to decimal
							WHEN b.OddsType IN (3, 4)
								THEN --malay and indo to decimal
									CASE 
										WHEN b.odds < 0
											THEN (1 - cast(1 AS FLOAT) / cast(b.odds AS FLOAT))
										WHEN b.odds >= 0
											THEN (1 + b.odds)
										END
							WHEN OddsType = 5
								THEN --american odds to decimal
									CASE 
										WHEN (b.odds * 100) < 0
											THEN (1 - cast(1 AS FLOAT) / cast(b.odds AS FLOAT))
										WHEN (b.odds * 100) % 2 = 0
											THEN 2
										WHEN (b.odds * 100) > 0
											THEN (1 + b.odds)
										END
							END
				ELSE b.Odds
				END
		ORDER BY b.winlostdate DESC
	END

	IF @ShowSB = 1
	BEGIN
		INSERT INTO @AgMatchWLDetails
		SELECT b.custid
			,b.Winlostdate
			,b.currency
			,CASE 
				WHEN (
						b.bettype IN (1, 2, 3, 7, 12, 8, 20)
						OR b.bettype BETWEEN 81 AND 88
						OR b.bettype BETWEEN 90 AND 120
						)
					THEN CASE 
							WHEN b.OddsType = 1
								THEN b.odds + 1 --decimal
							WHEN b.OddsType = 2
								THEN b.Odds + 1 --hongkong to decimal
							WHEN b.OddsType IN (3, 4)
								THEN --malay and indo to decimal
									CASE 
										WHEN b.odds < 0
											THEN (1 - cast(1 AS FLOAT) / cast(b.odds AS FLOAT))
										WHEN b.odds >= 0
											THEN (1 + b.odds)
										END
							WHEN OddsType = 5
								THEN --american odds to decimal
									CASE 
										WHEN (b.odds * 100) < 0
											THEN (1 - cast(1 AS FLOAT) / cast(b.odds AS FLOAT))
										WHEN (b.odds * 100) % 2 = 0
											THEN 2
										WHEN (b.odds * 100) > 0
											THEN (1 + b.odds)
										END
							END
				ELSE b.Odds
				END odds
			,0 sporttype
			,m.leagueid
			,SUM(stake)
			,SUM(winlost - b.actual_stake)
			,- SUM(winlost - b.actual_stake) AS LicenseeWL
			,0 as AmountDueToBA
			,0 AS CommBA
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
			AND b.winlostdate BETWEEN @TempFromDate AND @todate
			AND b.statusID IN (
				SELECT *
				FROM @status
				)
			AND m.leagueid = @LeagueID
			AND b.tpositiontaking <> 0  
		GROUP BY b.custid
			,b.Winlostdate
			,b.currency
			,m.leagueid
			,m.matchcode
			,m.isNeutral
			,b.liveindicator
			,b.tpositiontaking
			,CASE 
				WHEN (
						b.bettype IN (1, 2, 3, 7, 12, 8, 20)
						OR b.bettype BETWEEN 81 AND 88
						OR b.bettype BETWEEN 90 AND 120
						)
					THEN CASE 
							WHEN b.OddsType = 1
								THEN b.odds + 1 --decimal
							WHEN b.OddsType = 2
								THEN b.Odds + 1 --hongkong to decimal
							WHEN b.OddsType IN (3, 4)
								THEN --malay and indo to decimal
									CASE 
										WHEN b.odds < 0
											THEN (1 - cast(1 AS FLOAT) / cast(b.odds AS FLOAT))
										WHEN b.odds >= 0
											THEN (1 + b.odds)
										END
							WHEN OddsType = 5
								THEN --american odds to decimal
									CASE 
										WHEN (b.odds * 100) < 0
											THEN (1 - cast(1 AS FLOAT) / cast(b.odds AS FLOAT))
										WHEN (b.odds * 100) % 2 = 0
											THEN 2
										WHEN (b.odds * 100) > 0
											THEN (1 + b.odds)
										END
							END
				ELSE b.Odds
				END
		ORDER BY b.winlostdate DESC
	END
END

IF @Fromdate <= @MoveBetsDay
BEGIN
	IF @ToDate >= @MoveBetsDay
		SET @TempToDate = @MoveBetsDay
	ELSE
		SET @TempToDate = @ToDate

	--Get general data  
	begin
		IF @ShowBA=1 
		BEGIN
			INSERT INTO @AgMatchWLDetails
			SELECT b.custid
				,b.Winlostdate
				,ta.currency
				,CASE 
					WHEN (
							b.bettype IN (1, 2, 3, 7, 12, 8, 20)
							OR b.bettype BETWEEN 81 AND 88
							OR b.bettype BETWEEN 90 AND 120
							)
						THEN CASE 
								WHEN b.OddsType = 1
									THEN b.odds + 1 --decimal
								WHEN b.OddsType = 2
									THEN b.Odds + 1 --hongkong to decimal
								WHEN b.OddsType IN (3, 4)
									THEN --malay and indo to decimal
										CASE 
											WHEN b.odds < 0
												THEN (1 - cast(1 AS FLOAT) / cast(b.odds AS FLOAT))
											WHEN b.odds >= 0
												THEN (1 + b.odds)
											END
								WHEN OddsType = 5
									THEN --american odds to decimal
										CASE 
											WHEN (b.odds * 100) < 0
												THEN (1 - cast(1 AS FLOAT) / cast(b.odds AS FLOAT))
											WHEN (b.odds * 100) % 2 = 0
												THEN 2
											WHEN (b.odds * 100) > 0
												THEN (1 + b.odds)
											END
								END
					ELSE b.Odds
					END odds
				,0 AS sporttype
				,@LeagueID leagueid
				,SUM(stake)
				,SUM(winlost)
				,0 AS LicenseeWL
				--,sum(AmtDueToBA) AS AmountDueToBA
				,sum(Winlost +  awinlost + comm) AS AmountDueToBA
				--0 AS AmountDueToBA,
				,SUM (comm ) AS CommBA
				--0 AS CommBA
				,0 PlayerComm
				,0 matchcode
				,0 AS IsNeutral
				,0 AS liveindicator
				,SUM(b.betcount) betcount
			FROM bodb_LicenseeReport.dbo.rptCustomerMatch b WITH (
					NOLOCK
					,INDEX = IX_recommend
					)
			INNER JOIN @TempAg ta ON b.recommend = ta.CustId
			WHERE b.winlostdate BETWEEN @FromDate AND @TempToDate
				AND (
					b.bettype < 31
					OR (b.bettype BETWEEN 121 AND 999)
					)
				AND (@matchid=0 or b.matchid = @MatchID)
				AND b.statusID IN (
					SELECT *
					FROM @status
					)
				And b.isBA=1
				AND b.leagueid=@leagueid
			GROUP BY b.custid
				,b.Winlostdate
				,ta.Currency
				,b.isBA
				,CASE 
					WHEN (
							b.bettype IN (1, 2, 3, 7, 12, 8, 20)
							OR b.bettype BETWEEN 81 AND 88
							OR b.bettype BETWEEN 90 AND 120
							)
						THEN CASE 
								WHEN b.OddsType = 1
									THEN b.odds + 1 --decimal
								WHEN b.OddsType = 2
									THEN b.Odds + 1 --hongkong to decimal
								WHEN b.OddsType IN (3, 4)
									THEN --malay and indo to decimal
										CASE 
											WHEN b.odds < 0
												THEN (1 - cast(1 AS FLOAT) / cast(b.odds AS FLOAT))
											WHEN b.odds >= 0
												THEN (1 + b.odds)
											END
								WHEN OddsType = 5
									THEN --american odds to decimal
										CASE 
											WHEN (b.odds * 100) < 0
												THEN (1 - cast(1 AS FLOAT) / cast(b.odds AS FLOAT))
											WHEN (b.odds * 100) % 2 = 0
												THEN 2
											WHEN (b.odds * 100) > 0
												THEN (1 + b.odds)
											END
								END
					ELSE b.Odds
					END
		END
			IF @ShowSB=1 
		BEGIN
			INSERT INTO @AgMatchWLDetails
			SELECT b.custid
				,b.Winlostdate
				,ta.currency
				,CASE 
					WHEN (
							b.bettype IN (1, 2, 3, 7, 12, 8, 20)
							OR b.bettype BETWEEN 81 AND 88
							OR b.bettype BETWEEN 90 AND 120
							)
						THEN CASE 
								WHEN b.OddsType = 1
									THEN b.odds + 1 --decimal
								WHEN b.OddsType = 2
									THEN b.Odds + 1 --hongkong to decimal
								WHEN b.OddsType IN (3, 4)
									THEN --malay and indo to decimal
										CASE 
											WHEN b.odds < 0
												THEN (1 - cast(1 AS FLOAT) / cast(b.odds AS FLOAT))
											WHEN b.odds >= 0
												THEN (1 + b.odds)
											END
								WHEN OddsType = 5
									THEN --american odds to decimal
										CASE 
											WHEN (b.odds * 100) < 0
												THEN (1 - cast(1 AS FLOAT) / cast(b.odds AS FLOAT))
											WHEN (b.odds * 100) % 2 = 0
												THEN 2
											WHEN (b.odds * 100) > 0
												THEN (1 + b.odds)
											END
								END
					ELSE b.Odds
					END odds
				,0 AS sporttype
				,@LeagueID leagueid
				,SUM(stake)
				,SUM(winlost)
				,- SUM(b.winlost) AS LicenseeWL
				,0 AmountDueToBA
				,0 AS CommBA			
				,0 AS PlayerComm
				,0 matchcode
				,0 AS IsNeutral
				,0 AS liveindicator
				,SUM(b.betcount) betcount
			FROM bodb_LicenseeReport.dbo.rptCustomerMatch b WITH (
					NOLOCK
					,INDEX = IX_recommend
					)
			INNER JOIN @TempAg ta ON b.recommend = ta.CustId
			WHERE b.winlostdate BETWEEN @FromDate AND @TempToDate
				AND (
					b.bettype < 31
					OR (b.bettype BETWEEN 121 AND 999)
					)
				--AND b.matchid = @MatchID
				AND (@matchid=0 or b.matchid = @MatchID)
				AND b.statusID IN (
					SELECT *
					FROM @status
					)
				AND b.isBA=0
				and b.leagueid=@leagueid
			GROUP BY b.custid
				,b.Winlostdate
				,ta.currency				
				,b.isBA
				,CASE 
					WHEN (
							b.bettype IN (1, 2, 3, 7, 12, 8, 20)
							OR b.bettype BETWEEN 81 AND 88
							OR b.bettype BETWEEN 90 AND 120
							)
						THEN CASE 
								WHEN b.OddsType = 1
									THEN b.odds + 1 --decimal
								WHEN b.OddsType = 2
									THEN b.Odds + 1 --hongkong to decimal
								WHEN b.OddsType IN (3, 4)
									THEN --malay and indo to decimal
										CASE 
											WHEN b.odds < 0
												THEN (1 - cast(1 AS FLOAT) / cast(b.odds AS FLOAT))
											WHEN b.odds >= 0
												THEN (1 + b.odds)
											END
								WHEN OddsType = 5
									THEN --american odds to decimal
										CASE 
											WHEN (b.odds * 100) < 0
												THEN (1 - cast(1 AS FLOAT) / cast(b.odds AS FLOAT))
											WHEN (b.odds * 100) % 2 = 0
												THEN 2
											WHEN (b.odds * 100) > 0
												THEN (1 + b.odds)
											END
								END
					ELSE b.Odds
					END
		END
	end
END

INSERT INTO @ExchangeDaily
SELECT ExchangeDate
	,ExchangeId
	,USD
	,EUR
FROM Lrf_f_GetExchangeDaily(@fromDate, @ToDate)

DECLARE @RowStart INT
	,@RowEnd INT

SELECT @PageIndex = @PageIndex - 1
	,@RowStart = @PageSize * @PageIndex + 1
	,@RowEnd = @RowStart + @PageSize - 1

SELECT @TotalRows = count(a.custid)
FROM (
	SELECT custid
	FROM @AgMatchWLDetails
	GROUP BY custid
		,sporttype
		,leagueid
	) A

--SELECT @TotalRow TotalRow 
-- Result  
SELECT A.*
FROM (
	SELECT ROW_NUMBER() OVER (
			ORDER BY b.custid
				,username
				,SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, len(c.username2) - CHARINDEX('$', c.username2))
				,sporttype
				,leagueid
			) AS RowNum
		,b.custid
		,c.username
		,SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, len(c.username2) - CHARINDEX('$', c.username2)) AS nickname
		,sporttype
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
	INNER JOIN Customer c(NOLOCK) ON b.custid = c.custid
	INNER JOIN @ExchangeDaily e ON b.winlostdate = e.ExchangeDate
		AND b.currency = e.ExchangeId
	WHERE odds >= @odds
	GROUP BY b.custid
		,username
		,SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, len(c.username2) - CHARINDEX('$', c.username2))
		,sporttype
		,leagueid
		--ORDER BY b.custid
	) A
WHERE A.RowNum BETWEEN @RowStart AND @RowEnd

SELECT  CAST(SUM(turnover) AS MONEY) AS turnover
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
	INNER JOIN Customer c(NOLOCK) ON b.custid = c.custid
	INNER JOIN @ExchangeDaily e ON b.winlostdate = e.ExchangeDate
		AND b.currency = e.ExchangeId
	WHERE odds >= @odds

DROP TABLE #currency
GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_WinlossByLeagueDetail] TO [bodbLicenseeNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_WinlossByLeagueDetail] TO [vnteam] AS [dbo]
GO  
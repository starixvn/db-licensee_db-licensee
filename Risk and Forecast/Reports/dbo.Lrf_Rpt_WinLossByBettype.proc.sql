USE [bodb02]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Lrf_Rpt_WinLossByBettype] 
	@LicenseeID INT
	, @UserID INT
	, @LicenseeType VARCHAR(100) = NULL
	, @CurrencyID INT = 0
	, @FromDate SMALLDATETIME
	, @ToDate SMALLDATETIME
	, @MoveBetsDay SMALLDATETIME
	, @BalanceUpDay SMALLDATETIME
	, @PageSize INT = 1000
	, @PageIndex INT = 1
AS
/*
Created: 20101201@Jacob
Task : Report WinLoss
DB: DB052.bodb02
Original: Age_Rpt_WinLossByBettype_Ag
Revisions:
    - 20101201@Jacob: Copy code from Age_Rpt_WinLossByBettype_Ag, remove redundant column
	- 20110303@Jacob: Allow to choose all type of licensee AND all currency + suppport based currency
	- 20110513@Henry: change bettype to new range
	- 20110616@Henry: Suport filter BA tickets  + add column commission
	- 20110707@Henry: show Comm, Amt Due to for each 3rd party product: BA, Racing
	- 20110802@Henry: Offer 3 new bettypes for Number Game
	- 20111028@Jim: change bettype condition
	- 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily   
	- 20120731@Jim: add Player Comm value 
	- 20120815@Jim: add live casino
	- 20120906@Jim: add virtual sport
	- 20121004@Jim: replace @currencyname input param by @currencyID
	- 20121128@Henry: use new table LicenseeBATransaction_active to get bettrans BA tickets
	- 20121225@Henry: enhance performance
	- 20130402@Jim: add support for base currency USD
	- 20130426@Scott: Doesn't support RNG casino and Bingo (bettype : 71,73)
	- 20130618@Jim: Restrict permission of Licensee Users by currency
	- 20131203@Jim: offer Virtual Greyhound, Virtual Motor Racing
	- 20140404@Florent: offer Keno products
	- 20140620@Florent: offer 14 new bettypes and Sporting Solution (36 new bettypes)
	- 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
Param's Explanation: 
*/
SET NOCOUNT ON

DECLARE @RowStart INT
	, @RowEnd INT
	, @TotalRows INT
	, @Today SMALLDATETIME
DECLARE @Exchange TABLE (
	ExchangeDate SMALLDATETIME
	, ExchangeId INT
	, EUR FLOAT
	, USD FLOAT
	, PRIMARY KEY (
		ExchangeDate
		, ExchangeId
		)
	)

SELECT @PageIndex = @PageIndex - 1
	, @RowStart = @PageSize * @PageIndex + 1
	, @RowEnd = @RowStart + @PageSize - 1
	, @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120)

SELECT currencyID
	, LicenseeID
INTO #currency
FROM dbo.Lrf_f_GetCurrencybyUser(@licenseeID, @userID, 1) -- System is default=1 (LRF)
WHERE (
		@CurrencyID = 0
		OR (
			@CurrencyID <> 0
			AND CurrencyID = @CurrencyID
			)
		)

DECLARE @TempAg AS TABLE (
	CustId INT
	, currency INT
	)

INSERT INTO @TempAg (
	CustId
	, currency
	)
SELECT CustID
	, currency
FROM bodb_Licensee.dbo.f_SelLicenseeCust(@licenseeID) lc
INNER JOIN #Currency c ON lc.LicenseeID = c.LicenseeID
	AND lc.Currency = c.CurrencyID
WHERE [Description] = COALESCE(@LicenseeType, [Description])

--------------------------------------
DROP TABLE #Currency

--------------------------------------                
CREATE TABLE #AgWinLoss (
	bettype INT
	, liveindicator BIT
	,
	--winlostdate 	SMALLDATETIME,
	--currency 		INT,
	TurnOver MONEY
	, MemberWinLost MONEY
	, LicenseeWL MONEY
	, --Sportbook and NumberGame
	WinlossRB MONEY
	, AmtDueToBA MONEY
	, AmtDueToRB MONEY
	, CommBA MONEY
	, CommRB MONEY
	, PlayerComm MONEY
	, TurnOverEUR MONEY
	, MemberWinLostEUR MONEY
	, LicenseeWLEUR MONEY
	, --Sportbook and NumberGame
	WinlossRBEUR MONEY
	, AmtDueToBAEUR MONEY
	, AmtDueToRBEUR MONEY
	, CommBAEUR MONEY
	, CommRBEUR MONEY
	, PlayerCommEUR MONEY
	, TurnOverUSD MONEY
	, MemberWinLostUSD MONEY
	, LicenseeWLUSD MONEY
	, --Sportbook and NumberGame
	WinlossRBUSD MONEY
	, AmtDueToBAUSD MONEY
	, AmtDueToRBUSD MONEY
	, CommBAUSD MONEY
	, CommRBUSD MONEY
	, PlayerCommUSD MONEY
	)

DECLARE @TempFromDate DATETIME
DECLARE @TempToDate DATETIME
DECLARE @FDate DATETIME
DECLARE @TDate DATETIME

--to Deal With Parameter Sniffing
SELECT @FDate = @FromDate
	, @TDate = @ToDate

INSERT INTO @Exchange (
	exchangedate
	, exchangeid
	, eur
	, usd
	)
SELECT exchangedate
	, exchangeid
	, eur
	, usd
FROM Lrf_f_GetExchangeDaily(@FDate, @TDate)
WHERE exchangeid IN (
		SELECT Currency
		FROM @TempAg
		)

IF @Tdate > @MoveBetsDay
BEGIN
	IF @FDate <= @MoveBetsDay
		SET @TempFromDate = DATEADD(DAY, 1, @MoveBetsDay)
	ELSE
		SET @TempFromDate = @FDate

	INSERT INTO #AgWinLoss
	SELECT bettype
		, CASE 
			WHEN b.bettype BETWEEN 81 AND 120
				THEN b.liveindicator
			ELSE 0
			END AS liveindicator
		,
		--b.winlostdate,
		--b.currency,
		SUM(CASE 
				WHEN b.liveawayscore = 0
					AND bettype IN (33, 43)
					THEN stake / 2
				ELSE stake
				END)
		, SUM(winlost - actual_stake)
		, - SUM(CASE 
				WHEN ISNULL(BA.transid, 0) = 0
					AND (
						(
							b.bettype < 31
							OR (b.bettype BETWEEN 121 AND 999)
							OR (b.Bettype BETWEEN 1301 and 1399) --new tennis's bettypes
							)
						OR b.bettype BETWEEN 81 AND 120
						OR b.bettype BETWEEN 1101 AND 1199
						OR b.bettype BETWEEN 1201 AND 1299
						OR b.bettype BETWEEN 1501 AND 1599--Keno
						)
					THEN (b.winlost - b.actual_stake)
				ELSE 0
				END) AS LicenseeWL
		, SUM(CASE 
				WHEN b.bettype IN (31, 32, 33)
					THEN b.awinlost
				ELSE 0
				END) AS WinlossRB
		, - SUM(CASE 
				WHEN ISNULL(BA.transid, 0) <> 0
					THEN (b.winlost - b.actual_stake + awinlost + comm)
				ELSE 0
				END) AS AmountDueToBA
		, - SUM(CASE 
				WHEN b.bettype IN (31, 32, 33)
					THEN (b.winlost - b.actual_stake + awinlost + comm)
				ELSE 0
				END) AS AmountDueToRB
		, SUM(CASE 
				WHEN ISNULL(BA.transid, 0) <> 0
					THEN comm
				ELSE 0
				END) AS CommBA
		, SUM(CASE 
				WHEN b.bettype IN (31, 32, 33)
					THEN comm
				ELSE 0
				END) AS CommRB
		, SUM(playercomm) AS PlayerComm
		,
		---- EUR
		SUM(CASE 
				WHEN b.liveawayscore = 0
					AND bettype IN (33, 43)
					THEN stake / 2
				ELSE stake
				END * e.EUR)
		, SUM((winlost - actual_stake) * e.EUR)
		, - SUM(CASE 
				WHEN ISNULL(BA.transid, 0) = 0
					AND (
						(
							b.bettype < 31
							OR (b.bettype BETWEEN 121 AND 999)
							OR (b.Bettype BETWEEN 1301 and 1399) --new tennis's bettypes
							)
						OR b.bettype BETWEEN 81 AND 120
						OR b.bettype BETWEEN 1101 AND 1199
						OR b.bettype BETWEEN 1201 AND 1299
						OR b.bettype BETWEEN 1501 AND 1599--Keno
						)
					THEN (b.winlost - b.actual_stake)
				ELSE 0
				END * e.EUR) AS LicenseeWLEUR
		, SUM(CASE 
				WHEN b.bettype IN (31, 32, 33)
					THEN b.awinlost
				ELSE 0
				END * e.EUR) AS WinlossRBEUR
		, - SUM(CASE 
				WHEN ISNULL(BA.transid, 0) <> 0
					THEN (b.winlost - b.actual_stake + awinlost + comm)
				ELSE 0
				END * e.EUR) AS AmountDueToBAEUR
		, - SUM(CASE 
				WHEN b.bettype IN (31, 32, 33)
					THEN (b.winlost - b.actual_stake + awinlost + comm)
				ELSE 0
				END * e.EUR) AS AmountDueToRBEUR
		, SUM(CASE 
				WHEN ISNULL(BA.transid, 0) <> 0
					THEN comm
				ELSE 0
				END * e.EUR) AS CommBAEUR
		, SUM(CASE 
				WHEN b.bettype IN (31, 32, 33)
					THEN comm
				ELSE 0
				END * e.EUR) AS CommRBEUR
		, SUM(playercomm * e.EUR) AS PlayerCommEUR
		,
		--- USD
		SUM(CASE 
				WHEN b.liveawayscore = 0
					AND bettype IN (33, 43)
					THEN stake / 2
				ELSE stake
				END * e.USD)
		, SUM((winlost - actual_stake) * e.USD)
		, - SUM(CASE 
				WHEN ISNULL(BA.transid, 0) = 0
					AND (
						(
							b.bettype < 31
							OR (b.bettype BETWEEN 121 AND 999)
							OR (b.Bettype BETWEEN 1301 and 1399) --new tennis's bettypes
							)
						OR b.bettype BETWEEN 81 AND 120
						OR b.bettype BETWEEN 1101 AND 1199
						OR b.bettype BETWEEN 1201 AND 1299
						OR b.bettype BETWEEN 1501 AND 1599 --Keno
						)
					THEN (b.winlost - b.actual_stake)
				ELSE 0
				END * e.USD) AS LicenseeWLUSD
		, SUM(CASE 
				WHEN b.bettype IN (31, 32, 33)
					THEN b.awinlost
				ELSE 0
				END * e.USD) AS WinlossRBUSD
		, - SUM(CASE 
				WHEN ISNULL(BA.transid, 0) <> 0
					THEN (b.winlost - b.actual_stake + awinlost + comm)
				ELSE 0
				END * e.USD) AS AmountDueToBAUSD
		, - SUM(CASE 
				WHEN b.bettype IN (31, 32, 33)
					THEN (b.winlost - b.actual_stake + awinlost + comm)
				ELSE 0
				END * e.USD) AS AmountDueToRBUSD
		, SUM(CASE 
				WHEN ISNULL(BA.transid, 0) <> 0
					THEN comm
				ELSE 0
				END * e.USD) AS CommBAUSD
		, SUM(CASE 
				WHEN b.bettype IN (31, 32, 33)
					THEN comm
				ELSE 0
				END * e.USD) AS CommRBUSD
		, SUM(playercomm * e.USD) AS PlayerCommUSD
	FROM dbo.bettrans b WITH (
			NOLOCK
			, INDEX = CIX_recommend_matchid_bettype
			)
	LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction_active BA WITH (NOLOCK) ON b.recommend = BA.recommend
		AND b.transid = BA.transid
	LEFT JOIN @Exchange e ON e.ExchangeDate = b.winlostdate
		AND e.exchangeid = b.currency
	WHERE b.recommend IN (
			SELECT DISTINCT custid
			FROM @TempAg
			)
		AND b.winlostdate BETWEEN @TempFromDate AND @TDate
		AND bettype <= 1599 --include Keno product
		AND bettype NOT IN (71, 73)
		AND b.ruben = 1
		AND statusID NOT IN (101, 102, 103)
	GROUP BY bettype
		, CASE 
			WHEN b.bettype BETWEEN 81 AND 120
				THEN b.liveindicator
			ELSE 0
			END
END

IF @FDate <= @MoveBetsDay
BEGIN
	IF @TDate >= @MoveBetsDay
		SET @TempToDate = @MoveBetsDay
	ELSE
		SET @TempToDate = @TDate

	IF @BalanceUpDay < @FDate
		SELECT @BalanceUpDay = @FDate

	INSERT INTO #AgWinLoss
	SELECT bettype
		, CASE 
			WHEN b.bettype BETWEEN 81 AND 120
				THEN b.liveindicator
			ELSE 0
			END AS liveindicator
		,
		--b.winlostdate,
		--b.currency,
		SUM(CASE 
				WHEN b.liveawayscore = 0
					AND bettype IN (33, 43)
					THEN stake / 2
				ELSE stake
				END)
		, SUM(winlost - actual_stake)
		, - SUM(CASE 
				WHEN ISNULL(BA.transid, 0) = 0
					AND (
						(
							b.bettype < 31
							OR (b.bettype BETWEEN 121 AND 999)
							OR (b.Bettype BETWEEN 1301 and 1399) --new tennis's bettypes
							)
						OR b.bettype BETWEEN 81 AND 120
						OR b.bettype BETWEEN 1101 AND 1199
						OR b.bettype BETWEEN 1201 AND 1299
						OR b.bettype BETWEEN 1501 AND 1599 --Keno products
						)
					THEN (b.winlost - b.actual_stake)
				ELSE 0
				END) AS LicenseeWL
		, SUM(CASE 
				WHEN b.bettype IN (31, 32, 33)
					THEN b.awinlost
				ELSE 0
				END) AS WinlossRB
		, - SUM(CASE 
				WHEN ISNULL(BA.transid, 0) <> 0
					THEN (b.winlost - b.actual_stake + awinlost + comm)
				ELSE 0
				END) AS AmountDueToBA
		, - SUM(CASE 
				WHEN b.bettype IN (31, 32, 33)
					THEN (b.winlost - b.actual_stake + awinlost + comm)
				ELSE 0
				END) AS AmountDueToRB
		, SUM(CASE 
				WHEN ISNULL(BA.transid, 0) <> 0
					THEN comm
				ELSE 0
				END) AS CommBA
		, SUM(CASE 
				WHEN b.bettype IN (31, 32, 33)
					THEN comm
				ELSE 0
				END) AS CommRB
		, SUM(playercomm) AS PlayerComm
		,
		--- EUR
		SUM(CASE 
				WHEN b.liveawayscore = 0
					AND bettype IN (33, 43)
					THEN stake / 2
				ELSE stake
				END * e.EUR)
		, SUM((winlost - actual_stake) * e.EUR)
		, - SUM(CASE 
				WHEN ISNULL(BA.transid, 0) = 0
					AND (
						(
							b.bettype < 31
							OR (b.bettype BETWEEN 121 AND 999)
							OR (b.Bettype BETWEEN 1301 and 1399) --new tennis's bettypes
							)
						OR b.bettype BETWEEN 81 AND 120
						OR b.bettype BETWEEN 1101 AND 1199
						OR b.bettype BETWEEN 1201 AND 1299
						OR b.bettype BETWEEN 1501 AND 1599--Keno
						)
					THEN (b.winlost - b.actual_stake)
				ELSE 0
				END * e.EUR) AS LicenseeWLEUR
		, SUM(CASE 
				WHEN b.bettype IN (31, 32, 33)
					THEN b.awinlost
				ELSE 0
				END * e.EUR) AS WinlossRBEUR
		, - SUM(CASE 
				WHEN ISNULL(BA.transid, 0) <> 0
					THEN (b.winlost - b.actual_stake + awinlost + comm)
				ELSE 0
				END * e.EUR) AS AmountDueToBAEUR
		, - SUM(CASE 
				WHEN b.bettype IN (31, 32, 33)
					THEN (b.winlost - b.actual_stake + awinlost + comm)
				ELSE 0
				END * e.EUR) AS AmountDueToRBEUR
		, SUM(CASE 
				WHEN ISNULL(BA.transid, 0) <> 0
					THEN comm
				ELSE 0
				END * e.EUR) AS CommBAEUR
		, SUM(CASE 
				WHEN b.bettype IN (31, 32, 33)
					THEN comm
				ELSE 0
				END * e.EUR) AS CommRBEUR
		, SUM(playercomm * e.EUR) AS PlayerCommEUR
		,
		--- USD
		SUM(CASE 
				WHEN b.liveawayscore = 0
					AND bettype IN (33, 43)
					THEN stake / 2
				ELSE stake
				END * e.USD)
		, SUM((winlost - actual_stake) * e.USD)
		, - SUM(CASE 
				WHEN ISNULL(BA.transid, 0) = 0
					AND (
						(
							b.bettype < 31
							OR (b.bettype BETWEEN 121 AND 999)
							OR (b.Bettype BETWEEN 1301 and 1399) --new tennis's bettypes
							)
						OR b.bettype BETWEEN 81 AND 120
						OR b.bettype BETWEEN 1101 AND 1199
						OR b.bettype BETWEEN 1201 AND 1299
						OR b.bettype BETWEEN 1501 AND 1599--Keno
						)
					THEN (b.winlost - b.actual_stake)
				ELSE 0
				END * e.USD) AS LicenseeWLUSD
		, SUM(CASE 
				WHEN b.bettype IN (31, 32, 33)
					THEN b.awinlost
				ELSE 0
				END * e.USD) AS WinlossRBUSD
		, - SUM(CASE 
				WHEN ISNULL(BA.transid, 0) <> 0
					THEN (b.winlost - b.actual_stake + awinlost + comm)
				ELSE 0
				END * e.USD) AS AmountDueToBAUSD
		, - SUM(CASE 
				WHEN b.bettype IN (31, 32, 33)
					THEN (b.winlost - b.actual_stake + awinlost + comm)
				ELSE 0
				END * e.USD) AS AmountDueToRBUSD
		, SUM(CASE 
				WHEN ISNULL(BA.transid, 0) <> 0
					THEN comm
				ELSE 0
				END * e.USD) AS CommBAUSD
		, SUM(CASE 
				WHEN b.bettype IN (31, 32, 33)
					THEN comm
				ELSE 0
				END * e.USD) AS CommRBUSD
		, SUM(playercomm * e.USD) AS PlayerCommUSD
	FROM Bettrans14 b WITH (
			NOLOCK
			, INDEX = bettrans143
			)
	LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction_bk BA WITH (NOLOCK) ON b.recommend = BA.recommend
		AND b.transid = BA.transid
	LEFT JOIN @Exchange e ON e.ExchangeDate = b.winlostdate
		AND e.exchangeid = b.currency
	WHERE b.recommend IN (SELECT DISTINCT CustId FROM @TempAg)
		AND b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate
		AND statusID NOT IN (101, 102, 103)
		AND bettype <= 1599 --Include Keno
		AND bettype NOT IN (71, 73)
	GROUP BY bettype
		, CASE 
			WHEN b.bettype BETWEEN 81 AND 120
				THEN b.liveindicator
			ELSE 0
			END --, b.winlostdate, b.currency	
END

-- Calculate total value
SELECT @TotalRows = COUNT(DISTINCT bettype)
FROM #AgWinLoss

SELECT wl.*
FROM (
	SELECT bettype
		, liveindicator
		, SUM(TurnOver) AS TurnOver
		, CAST(SUM(TurnOverEUR) AS MONEY) AS TurnOverEUR
		, CAST(SUM(TurnOverUSD) AS MONEY) AS TurnOverUSD
		, SUM(MemberWinLost) AS MemberWinLost
		, CAST(SUM(MemberWinLostEUR) AS MONEY) AS MemberWinLostEUR
		, CAST(SUM(MemberWinLostUSD) AS MONEY) AS MemberWinLostUSD
		, SUM(LicenseeWL) AS LicenseeWL
		, CAST(SUM(LicenseeWLEUR) AS MONEY) AS LicenseeWLEUR
		, CAST(SUM(LicenseeWLUSD) AS MONEY) AS LicenseeWLUSD
		, SUM(WinlossRB) AS WinlossRB
		, CAST(SUM(WinlossRBEUR) AS MONEY) AS WinlossRBEUR
		, CAST(SUM(WinlossRBUSD) AS MONEY) AS WinlossRBUSD
		, SUM(CommBA) AS CommBA
		, CAST(SUM(CommBAEUR) AS MONEY) AS CommBAEUR
		, CAST(SUM(CommBAUSD) AS MONEY) AS CommBAUSD
		, SUM(commRB) AS commRB
		, CAST(SUM(commRBEUR) AS MONEY) AS commRBEUR
		, CAST(SUM(commRBUSD) AS MONEY) AS commRBUSD
		, SUM(PlayerComm) AS PlayerComm
		, CAST(SUM(PlayerCommEUR) AS MONEY) AS PlayerCommEUR
		, CAST(SUM(PlayerCommUSD) AS MONEY) AS PlayerCommUSD
		, SUM(AmtDuetoBA) AS AmtDuetoBA
		, CAST(SUM(AmtDuetoBAEUR) AS MONEY) AS AmtDuetoBAEUR
		, CAST(SUM(AmtDuetoBAUSD) AS MONEY) AS AmtDuetoBAUSD
		, SUM(AmtDuetoRB) AS AmtDuetoRB
		, CAST(SUM(AmtDuetoRBEUR) AS MONEY) AS AmtDuetoRBEUR
		, CAST(SUM(AmtDuetoRBUSD) AS MONEY) AS AmtDuetoRBUSD
		, ROW_NUMBER() OVER (
			ORDER BY bettype
			) AS RowNum
	FROM #AgWinLoss b
	GROUP BY bettype
		, liveindicator
	) wl
WHERE wl.RowNum BETWEEN @RowStart AND @RowEnd

SELECT SUM(TurnOver) AS SumTurnOver
	, CAST(SUM(TurnOverEUR) AS MONEY) AS SumTurnOverEUR
	, CAST(SUM(TurnOverUSD) AS MONEY) AS SumTurnOverUSD
	, SUM(MemberWinLost) AS SumMemberWinLost
	, CAST(SUM(MemberWinLostEUR) AS MONEY) AS SumMemberWinLostEUR
	, CAST(SUM(MemberWinLostUSD) AS MONEY) AS SumMemberWinLostUSD
	, SUM(LicenseeWL) AS SumLicenseeWL
	, CAST(SUM(LicenseeWLEUR) AS MONEY) AS SumLicenseeWLEUR
	, CAST(SUM(LicenseeWLUSD) AS MONEY) AS SumLicenseeWLUSD
	, CAST(SUM(WinlossRBEUR) AS MONEY) AS SumWinlossRBEUR
	, CAST(SUM(WinlossRBUSD) AS MONEY) AS SumWinlossRBUSD
	, SUM(CommBA) AS SumCommBA
	, CAST(SUM(CommBAEUR) AS MONEY) AS SumCommBAEUR
	, CAST(SUM(CommBAUSD) AS MONEY) AS SumCommBAUSD
	, SUM(commRB) AS SumcommRB
	, CAST(SUM(commRBEUR) AS MONEY) AS SumcommRBEUR
	, CAST(SUM(commRBUSD) AS MONEY) AS SumcommRBUSD
	, SUM(PlayerComm) AS SumPlayerComm
	, CAST(SUM(PlayerCommEUR) AS MONEY) AS SumPlayerCommEUR
	, CAST(SUM(PlayerCommUSD) AS MONEY) AS SumPlayerCommUSD
	, SUM(AmtDuetoBA) AS SumAmtDuetoBA
	, CAST(SUM(AmtDuetoBAEUR) AS MONEY) AS SumAmtDuetoBAEUR
	, CAST(SUM(AmtDuetoBAUSD) AS MONEY) AS SumAmtDuetoBAUSD
	, SUM(AmtDuetoRB) AS SumAmtDuetoRB
	, CAST(SUM(AmtDuetoRBEUR) AS MONEY) AS SumAmtDuetoRBEUR
	, CAST(SUM(AmtDuetoRBUSD) AS MONEY) AS SumAmtDuetoRBUSD
	, ISNULL(@TotalRows, 0) AS TotalRows
FROM #AgWinLoss b

DROP TABLE #AgWinLoss
GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_WinLossByBettype] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_WinLossByBettype] TO [vnteam]
GO

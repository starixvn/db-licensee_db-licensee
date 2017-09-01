/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_WinLossByBettype] 	
	  @FromDate		SMALLDATETIME
	, @ToDate		SMALLDATETIME
	, @MoveBetsDay	SMALLDATETIME
	, @BalanceUpDay SMALLDATETIME
	, @PageSize		INT = 1000
	, @PageIndex	INT = 1
	, @AgentList	VARCHAR(MAX)
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
	- 20141017@Jim : Apply for the change in Sporting Solution structure (#24478)
	- 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
	- 20150123@Jim: support base on Currency GBP
	- 20150415@Jim: change to use f_GroupBettype instead of LRF_view_bettype_SS
	- 20150612@Jim: support MicroGaming
	- 20150623@Winnie: exclude 3 transactions SOLD/BOUGHT/BetTrade Commission 
	- 20151001@Jim: remove MicroGaming
	- 20160727@Jim:  LRF - Commercial terms changed for Bet Trade [Redmine: #61342]
	- 20160721@Percy: Enhance Performance - using index srecommend on bettrans [RedmineID: #60770]
	- 20161115@Jim: LRF - Integrate new product Fishing World [RedmineID : #66737]
	- 20170227@Harper: LRF - Get data by @AgentList instead of @UserID [RedmineID: #71679]
	- 20170327@Paul: Implement Cash Out [RedmineID :#71727]
	- 20170710@Harper: LRF - Integrate Bet Radar Virtual Sports [RedmineID: #78241]
	- 20170731@Harper: LRF - Integrate Lottery [RedmineID: #79997]

Param's Explanation: 
	+ @AgentList: xml structure
					<ROOT>
					<Agent AgentId="12345" Currency="3"/>  
					<Agent AgentId="12345" Currency="5"/>  
					</ROOT> 
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
	, GBP FLOAT
	, PRIMARY KEY (
		ExchangeDate
		, ExchangeId
		)
	)

SELECT @PageIndex = @PageIndex - 1
	, @RowStart = @PageSize * @PageIndex + 1
	, @RowEnd = @RowStart + @PageSize - 1
	, @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120)


DECLARE @TempAg AS TABLE ( CustId INT,Currency INT )
DECLARE @DocHandler INT

BEGIN TRY
	EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@AgentList
	INSERT INTO @TempAg (custID, currency)
	SELECT AgentId, Currency
	FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency INT) AS Data

	EXEC sp_xml_removedocument @DocHandler
END TRY

BEGIN CATCH
	SELECT ErrCode = 100
			,ErrMsg = N'Paramter invalid.'

	RETURN
END CATCH;

CREATE TABLE #TempSAg (srecommend INT, currency INT)
INSERT INTO #TempSAg (srecommend, currency)
SELECT DISTINCT
	c.srecommend, t.currency
FROM
	@TempAg t
	INNER JOIN dbo.Customer c WITH (NOLOCK) ON t.CustId = c.custid
WHERE
	c.roleid = 2
	         
CREATE TABLE #AgWinLoss (
	bettype INT
	, liveindicator BIT
	,
	winlostdate 	SMALLDATETIME,
	currency 		INT,
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
	,GBP
	)
SELECT exchangedate
	, exchangeid
	, eur
	, usd
	, GBP
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
		b.winlostdate,
		b.currency,
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
						OR b.bettype BETWEEN 2701 AND 2799
						OR b.bettype BETWEEN 1501 AND 1599 --Keno
						OR b.bettype BETWEEN 1021 AND 1049 -- Lottery						 
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
	FROM dbo.bettrans b WITH (NOLOCK)
	INNER JOIN #TempSAg s ON b.srecommend = s.srecommend AND b.currency = s.currency
	LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction_active BA WITH (NOLOCK) ON b.transid = BA.transid	 
	WHERE b.winlostdate BETWEEN @TempFromDate AND @TDate
		AND (bettype <= 1599 OR (b.bettype >= 2701 AND b.bettype <= 2799))
		AND (bettype NOT IN (71, 73,901,902,903,904,911,912,913,914) AND bettype NOT BETWEEN 1011 AND 1020)
		AND b.ruben = 1
		AND statusID NOT IN (101, 102, 103)
	GROUP BY bettype
		, CASE 
			WHEN b.bettype BETWEEN 81 AND 120
				THEN b.liveindicator
			ELSE 0
			END
		,b.winlostdate
		,b.currency
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
		b.winlostdate,
		b.currency,
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
						OR b.bettype BETWEEN 2701 AND 2799
						OR b.bettype BETWEEN 1501 AND 1599 --Keno products
						OR b.bettype BETWEEN 1021 AND 1049 --Lottery
						 
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
	FROM Bettrans14 b WITH (NOLOCK)
	INNER JOIN @TempAg s ON b.recommend = s.CustId AND b.currency = s.currency
	LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction_bk BA WITH (NOLOCK) ON b.transid = BA.transid	
	WHERE b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate
		AND statusID NOT IN (101, 102, 103)
		AND (bettype <= 1599 OR (b.bettype >= 2701 AND b.bettype <= 2799)) 
		AND (bettype NOT IN (71, 73,901,902,903,904,911,912,913,914) AND bettype NOT BETWEEN 1011 AND 1020)
	GROUP BY bettype
		, CASE 
			WHEN b.bettype BETWEEN 81 AND 120
				THEN b.liveindicator
			ELSE 0
			END , b.winlostdate, b.currency	
END

-- Calculate total value
SELECT @TotalRows = COUNT(DISTINCT bettype)
FROM #AgWinLoss

SELECT wl.*
FROM (
	SELECT CASE WHEN ISNULL(ss.bettype,0) <> 0 THEN ss.grouptypeId
				ELSE b.bettype 
				END bettype
		, liveindicator
		, SUM(TurnOver) AS TurnOver
		, CAST(SUM(TurnOver*e.EUR) AS MONEY) AS TurnOverEUR
		, CAST(SUM(TurnOver*e.USD) AS MONEY) AS TurnOverUSD
		, CAST(SUM(TurnOver*e.GBP) AS MONEY) AS TurnOverGBP
		, SUM(MemberWinLost) AS MemberWinLost
		, CAST(SUM(MemberWinLost*e.EUR) AS MONEY) AS MemberWinLostEUR
		, CAST(SUM(MemberWinLost*e.USD) AS MONEY) AS MemberWinLostUSD
		, CAST(SUM(MemberWinLost*e.GBP) AS MONEY) AS MemberWinLostGBP
		, SUM(LicenseeWL) AS LicenseeWL
		, CAST(SUM(LicenseeWL*e.EUR) AS MONEY) AS LicenseeWLEUR
		, CAST(SUM(LicenseeWL*e.USD) AS MONEY) AS LicenseeWLUSD
		, CAST(SUM(LicenseeWL*e.GBP) AS MONEY) AS LicenseeWLGBP
		, SUM(WinlossRB) AS WinlossRB
		, CAST(SUM(WinlossRB*e.EUR) AS MONEY) AS WinlossRBEUR
		, CAST(SUM(WinlossRB*e.USD) AS MONEY) AS WinlossRBUSD
		, CAST(SUM(WinlossRB*e.GBP) AS MONEY) AS WinlossRBGBP
		, SUM(CommBA) AS CommBA
		, CAST(SUM(CommBA*e.EUR) AS MONEY) AS CommBAEUR
		, CAST(SUM(CommBA*e.USD) AS MONEY) AS CommBAUSD
		, CAST(SUM(CommBA*e.GBP) AS MONEY) AS CommBAGBP
		, SUM(commRB) AS commRB
		, CAST(SUM(commRB*e.EUR) AS MONEY) AS commRBEUR
		, CAST(SUM(commRB*e.USD) AS MONEY) AS commRBUSD
		, CAST(SUM(commRB*e.GBP) AS MONEY) AS commRBGBP
		, SUM(PlayerComm) AS PlayerComm
		, CAST(SUM(PlayerComm*e.EUR) AS MONEY) AS PlayerCommEUR
		, CAST(SUM(PlayerComm*e.USD) AS MONEY) AS PlayerCommUSD
		, CAST(SUM(PlayerComm*e.GBP) AS MONEY) AS PlayerCommGBP
		, SUM(AmtDuetoBA) AS AmtDuetoBA
		, CAST(SUM(AmtDuetoBA*e.EUR) AS MONEY) AS AmtDuetoBAEUR
		, CAST(SUM(AmtDuetoBA*e.USD) AS MONEY) AS AmtDuetoBAUSD
		, CAST(SUM(AmtDuetoBA*e.GBP) AS MONEY) AS AmtDuetoBAGBP
		, SUM(AmtDuetoRB) AS AmtDuetoRB
		, CAST(SUM(AmtDuetoRB*e.EUR) AS MONEY) AS AmtDuetoRBEUR
		, CAST(SUM(AmtDuetoRB*e.USD) AS MONEY) AS AmtDuetoRBUSD
		, CAST(SUM(AmtDuetoRB*e.GBP) AS MONEY) AS AmtDuetoRBGBP
		, ROW_NUMBER() OVER (
			ORDER BY CASE WHEN ISNULL(ss.bettype,0) <> 0 THEN ss.grouptypeId
				ELSE b.bettype 
				END
			) AS RowNum
	FROM #AgWinLoss b
		LEFT JOIN @Exchange e ON b.winlostdate = e.ExchangeDate AND b.currency = e.ExchangeId
		LEFT JOIN dbo.f_GroupBettype() ss ON b.bettype = ss.bettype 	
	GROUP BY CASE WHEN ISNULL(ss.bettype,0) <> 0 THEN ss.grouptypeId
				ELSE b.bettype 
				END
			, liveindicator
			 
	) wl
WHERE wl.RowNum BETWEEN @RowStart AND @RowEnd

DROP TABLE #AgWinLoss
DROP TABLE #TempSAg
GO

GRANT EXECUTE ON [dbo].[Lrf_Rpt_WinLossByBettype] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_WinLossByBettype] TO [vnteam]
GO
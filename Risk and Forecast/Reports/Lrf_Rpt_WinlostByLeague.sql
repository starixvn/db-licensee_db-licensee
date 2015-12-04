USE [bodb02]
GO
 
ALTER PROCEDURE [dbo].[Lrf_Rpt_WinlostByLeague]
	@LicenseeID INT
	,@UserID INT
	,@CurrencyID INT
	,@FromDate SMALLDATETIME
	,@ToDate SMALLDATETIME
	,@Odds FLOAT = 0
	,@LeagueID INT
	,@MatchID INT =0
	,@MoveBetsDay SMALLDATETIME
	,@BalanceUpDay SMALLDATETIME
	,@ShowWin BIT = 1
	,@ShowLoss BIT = 1
	,@ShowDraw BIT = 1
	,@ShowSB BIT = 1
	,@ShowBA BIT = 1
AS
/*
	Created	: Florent
	Task: Winloss by League
	Date: 2013-12-30
	DB: DBEXT/BODB02
	Original: 
	Revision:
		- 20140207@Florent: Add filter ShowSB , ShowBA
		- 20140620@Florent: offer 14 new bettypes and Sporting Solution (36 new bettypes)
		- 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
		- 20150127@Jim: support base on GBP Currency
		- 20150623@Winnie: exclude 3 transactions SOLD/BOUGHT/BetTrade Commission
		- 20151127@Bobby: #48081 - Apply PH-AIO new bettypes
		- 20151203@Bobby: Database - Change datatype [Redmine: #48660]
		
	Parameter's Explanation:
		- @LicenseeID : Licensee ID
		- @UserID : UserID who run this report
		- @CurrencyID : Curenncy in Filter, default=0
		- @FromDate : From date, in range time
		- @ToDate : To date, in range time
		- @Odds : Decimals odds >=0
		- @LeagueID : LeagueID of sportbook
		- @MatchID :match ID on League
		- @ShowWin : Filter show only Win bet
		- @ShowLoss :Filter show only Loss bet
		- @ShowDraw :Filter show only Draw bet		
		- @MoveBetsDay: The day we move tickets to bettrans14
		- @BalanceUpDay: The day we move tickets to bettrans_bk		
			
*/
SET NOCOUNT ON

DECLARE @ExchangeDaily TABLE (
	ExchangeDate SMALLDATETIME
	,ExchangeId INT
	,USD FLOAT
	,EUR FLOAT
	,GBP FLOAT
	,PRIMARY KEY (
		ExchangeDate
		,ExchangeId
		)
	)
DECLARE @bettype AS TABLE (bettype INT)
DECLARE @TempFromDate SMALLDATETIME
DECLARE @TempToDate SMALLDATETIME
--
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
--SET @_Date = @Date
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

DECLARE @TempAg AS TABLE (
	CustId INT
	,currency INT
	)

INSERT INTO @TempAg (
	CustId
	,currency
	)
SELECT CustID
	,lc.Currency
FROM  bodb_licensee.dbo.f_SelLicenseeCust(@LicenseeId) lc 
	INNER JOIN #Currency c ON lc.LicenseeID = c.LicenseeID
	AND lc.Currency = c.CurrencyID

--WHERE [Description] = COALESCE(@LicenseeType, [Description])
-------------------------------
DROP TABLE #Currency

-------------------------------
DECLARE @AgMatchWLDetails TABLE (
	Winlostdate SMALLDATETIME
	,KickoffTime DATETIME
	,Currency INT
	,matchid INT
	,homeid INT
	,awayid INT
	,bettype SMALLINT
	,ProductName VARCHAR(4)
	,leagueid INT
	--,odds SMALLMONEY 
	,odds2 MONEY
	,turnover MONEY
	,MemberWinLost MONEY
	,LicenseeWL MONEY
	,--Sportbook and NumberGame  
	WinlossRB MONEY
	,AmtDueToBA MONEY
	,AmtDueToRB MONEY
	,CommBA MONEY
	,CommRB MONEY
	,PlayerComm MONEY
	,race NVARCHAR(20)
	,matchcode NVARCHAR(50)
	,isNeutral BIT
	,sporttype SMALLINT
	,showtime NVARCHAR(50)
	,betcount INT
	)

IF @Todate > @MoveBetsDay
BEGIN
	IF @FromDate <= @MoveBetsDay
		SET @TempFromDate = DATEADD(DAY, 1, @MoveBetsDay)
	ELSE
		SET @TempFromDate = @FromDate

	BEGIN
		--Get general data 
		--ShowBA
		IF @ShowBA = 1
		BEGIN
			INSERT INTO @AgMatchWLDetails
			SELECT b.Winlostdate
				,NULL
				,b.currency
				,m.matchid
				,m.homeid
				,m.awayid
				,b.bettype
				,'BA'
				,m.leagueid
				,CASE 
					WHEN (b.bettype IN (1,2,3,7,12,8,20,21,1301,1303,1305,1306,1308,1311,1312,1316,1318,1324,153,154,155,156)	 -- add more Sportting Solution bettype 
							OR b.bettype BETWEEN 81 AND 88
							OR b.bettype BETWEEN 90 AND 120
							OR b.bettype IN (157,178,183,184,194,197,198,203,204,205) -- add more bettype BetRadar 
							OR b.bettype BETWEEN 401 AND 404 -- add more PH-AIO new bettypes
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
					END odds2
				,SUM(stake)
				,SUM(winlost - b.actual_stake)
				,0 AS LicenseeWL
				,0 AS WinlossRB
				,-SUM(winlost - b.actual_stake + awinlost + comm) AS AmountDueToBA
				,0 AS AmountDueToRB
				,SUM(comm) AS CommBA
				,0 AS CommRB
				,SUM(b.playercomm) AS PlayerComm
				,''
				,m.matchcode
				,ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral
				,m.sporttype
				,'' AS ShowTime
				,count(1) betcount
			FROM bettrans AS b WITH (NOLOCK)
			INNER JOIN match m WITH (NOLOCK) ON m.matchid = b.matchid
			INNER JOIN @TempAg ta ON b.recommend = ta.CustId AND b.Currency = ta.Currency
			WHERE b.winlostdate BETWEEN @TempFromDate AND @todate
				AND (
					b.bettype < 31
					OR (b.bettype BETWEEN 121 AND 999)		
					OR (b.Bettype BETWEEN 1301 and 1399) --new tennis's bettypes		
					)
				AND b.bettype NOT IN (901,902,903)
				AND (
					@MatchID = 0
					OR m.matchid = @MatchID
					)
				AND m.leagueid = @leagueID
				AND b.statusid IN (
					SELECT StatusID
					FROM @Status
					)
				AND B.tpositiontaking = 0 --showBA
			GROUP BY b.Winlostdate
				,b.currency
				,m.matchid
				,m.homeid
				,m.awayid
				,b.bettype
				,m.leagueid
				,m.matchcode
				,m.isNeutral
				,m.sporttype
				--,CASE 
				--	WHEN b.tpositiontaking <> 0
				--		THEN m.showtime
				--	ELSE ''
				--	END
				,CASE 
					WHEN (b.bettype IN (1,2,3,7,12,8,20,21,1301,1303,1305,1306,1308,1311,1312,1316,1318,1324,153,154,155,156)	 -- add more Sportting Solution bettype 
							OR b.bettype BETWEEN 81 AND 88
							OR b.bettype BETWEEN 90 AND 120
							OR b.bettype IN (157,178,183,184,194,197,198,203,204,205) -- add more bettype BetRadar 
							OR b.bettype BETWEEN 401 AND 404 -- add more PH-AIO new bettypes
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

		--ShowBA
		IF @ShowSB = 1
		BEGIN
			INSERT INTO @AgMatchWLDetails
			SELECT b.Winlostdate
				,NULL
				,b.currency
				,m.matchid
				,m.homeid
				,m.awayid
				,b.bettype
				,'SB'
				,m.leagueid
				,CASE 
					WHEN (b.bettype IN (1,2,3,7,12,8,20,21,1301,1303,1305,1306,1308,1311,1312,1316,1318,1324,153,154,155,156)	 -- add more Sportting Solution bettype 
							OR b.bettype BETWEEN 81 AND 88
							OR b.bettype BETWEEN 90 AND 120
							OR b.bettype IN (157,178,183,184,194,197,198,203,204,205) -- add more bettype BetRadar 
							OR b.bettype BETWEEN 401 AND 404 -- add more PH-AIO new bettypes
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
					END odds2
				,SUM(stake)
				,SUM(winlost - b.actual_stake)
				,- SUM(winlost - b.actual_stake) AS LicenseeWL
				,0 AS WinlossRB
				,0 AS AmountDueToBA
				,0 AS AmountDueToRB
				,0 AS CommBA
				,0 AS CommRB
				,SUM(b.playercomm) AS PlayerComm
				,''
				,m.matchcode
				,ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral
				,m.sporttype
				,m.showtime AS ShowTime
				,count(1) betcount
			FROM bettrans AS b WITH (NOLOCK)
			INNER JOIN match m WITH (NOLOCK) ON m.matchid = b.matchid
			INNER JOIN @TempAg ta ON b.recommend = ta.CustId AND b.Currency = ta.Currency
			WHERE b.winlostdate BETWEEN @TempFromDate AND @todate
				AND (
					b.bettype < 31
					OR (b.bettype BETWEEN 121 AND 999)	
					OR (b.Bettype BETWEEN 1301 and 1399) --new tennis's bettypes			
					)
				AND b.bettype NOT IN (901,902,903)
				AND (
					@MatchID = 0
					OR m.matchid = @MatchID
					)
				AND m.leagueid = @leagueID
				AND b.statusid IN (
					SELECT *
					FROM @Status
					)
				AND b.tpositiontaking <> 0
			GROUP BY b.Winlostdate
				,b.currency
				,m.matchid
				,m.homeid
				,m.awayid
				,b.bettype
				,m.leagueid
				,m.matchcode
				,m.isNeutral
				,m.sporttype
				,m.showtime
				,CASE 
					WHEN (b.bettype IN (1,2,3,7,12,8,20,21,1301,1303,1305,1306,1308,1311,1312,1316,1318,1324,153,154,155,156)	 -- add more Sportting Solution bettype 
							OR b.bettype BETWEEN 81 AND 88
							OR b.bettype BETWEEN 90 AND 120
							OR b.bettype IN (157,178,183,184,194,197,198,203,204,205) -- add more bettype BetRadar 
							OR b.bettype BETWEEN 401 AND 404 -- add more PH-AIO new bettypes
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
	END
END
CREATE TABLE #match (
	matchid INT
	,homeid INT
	,awayid INT
	,leagueid INT
	,matchcode NVARCHAR(50)
	,sporttype TINYINT
	,showtime NVARCHAR(50)
	,isNeutral BIT
	)

IF @Fromdate <= @MoveBetsDay
BEGIN
	IF @ToDate >= @MoveBetsDay
		SET @TempToDate = @MoveBetsDay
	ELSE
		SET @TempToDate = @ToDate

	BEGIN
		INSERT INTO #match
		SELECT m.matchid
			,m.homeid
			,m.awayid
			,m.leagueid
			,m.matchcode
			,m.sporttype
			,m.showtime
			,m.isNeutral
		FROM match14 AS m WITH (NOLOCK)
		WHERE m.eventdate BETWEEN @fromdate AND @TempToDate
			AND m.leagueid = @LeagueID
			AND (
				m.matchid = @MatchID
				OR @MatchID = 0
				)

		INSERT INTO #match
		SELECT m.matchid
			,m.homeid
			,m.awayid
			,m.leagueid
			,m.matchcode
			,m.sporttype
			,m.showtime
			,m.isNeutral
		FROM DBARC.bodb_archive.dbo.match_bk AS m WITH (NOLOCK)
		WHERE m.eventdate BETWEEN @fromdate AND @TempToDate
			AND m.leagueid = @LeagueID
			AND (
				m.matchid = @MatchID
				OR @MatchID = 0
				)

		IF @ShowBA = 1
		BEGIN
			INSERT INTO @AgMatchWLDetails
			SELECT b.Winlostdate
				,NULL
				,ag.currency
				,m.matchid
				,m.homeid
				,m.awayid
				,b.bettype
				,'BA'
				,m.leagueid
				,CASE 
					WHEN (b.bettype IN (1,2,3,7,12,8,20,21,1301,1303,1305,1306,1308,1311,1312,1316,1318,1324,153,154,155,156)	 -- add more Sportting Solution bettype 
							OR b.bettype BETWEEN 81 AND 88
							OR b.bettype BETWEEN 90 AND 120
							OR b.bettype IN (157,178,183,184,194,197,198,203,204,205) -- add more bettype BetRadar 
							OR b.bettype BETWEEN 401 AND 404 -- add more PH-AIO new bettypes
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
					END odds2
				,SUM(stake)
				,SUM(winlost)
				,0 AS LicenseeWL
				,0 AS WinlossRB
				,-sum(Winlost + awinlost + comm) AS AmountDueToBA
				,0 AS AmountDueToRB
				,sum(comm) AS CommBA
				,0 AS CommRB
				,SUM(b.playercomm) AS playercomm
				,'' AS race
				,m.matchcode
				,ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral
				,m.sporttype
				,m.showtime AS showtime
				,sum(b.betcount) betcount
			FROM bodb_LicenseeReport.dbo.rptWinlostbyLeague b WITH (NOLOCK, INDEX = IX_recommend)
			INNER JOIN #match AS m WITH (NOLOCK) ON m.matchid = b.matchid
			INNER JOIN @TempAg ag ON b.recommend = ag.custid AND b.Currency = ag.Currency
			WHERE winlostdate BETWEEN @fromdate AND @TempToDate
				AND (
					b.bettype < 31
					OR (b.bettype BETWEEN 121 AND 999)			
					OR (b.Bettype BETWEEN 1301 and 1399) --new tennis's bettypes		
					)
				AND b.bettype NOT IN (901,902,903)
				AND b.leagueid = @LeagueID
				AND (
					m.matchid = @MatchID
					OR @MatchID = 0
					)
				AND b.statusID IN (
					SELECT *
					FROM @status
					)
				AND b.isba = 1
			GROUP BY b.Winlostdate
				,ag.currency
				,m.matchid
				,m.homeid
				,m.awayid
				,b.bettype
				,m.leagueid
				,m.matchcode
				,m.isNeutral
				,b.bettype
				,m.sporttype
				,m.showtime
				,CASE 
					WHEN (b.bettype IN (1,2,3,7,12,8,20,21,1301,1303,1305,1306,1308,1311,1312,1316,1318,1324,153,154,155,156)	 -- add more Sportting Solution bettype 
							OR b.bettype BETWEEN 81 AND 88
							OR b.bettype BETWEEN 90 AND 120
							OR b.bettype IN (157,178,183,184,194,197,198,203,204,205) -- add more bettype BetRadar 
							OR b.bettype BETWEEN 401 AND 404 -- add more PH-AIO new bettypes
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

		IF @ShowSB = 1
		BEGIN
			INSERT INTO @AgMatchWLDetails
			SELECT b.Winlostdate
				,NULL
				,ag.currency
				,m.matchid
				,m.homeid
				,m.awayid
				,b.bettype
				,'SB'
				,m.leagueid
				,CASE 
					WHEN (b.bettype IN (1,2,3,7,12,8,20,21,1301,1303,1305,1306,1308,1311,1312,1316,1318,1324,153,154,155,156)	 -- add more Sportting Solution bettype 
							OR b.bettype BETWEEN 81 AND 88
							OR b.bettype BETWEEN 90 AND 120
							OR b.bettype IN (157,178,183,184,194,197,198,203,204,205) -- add more bettype BetRadar 
							OR b.bettype BETWEEN 401 AND 404 -- add more PH-AIO new bettypes
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
					END odds2
				,SUM(stake)
				,SUM(winlost)
				,- SUM(b.winlost) AS LicenseeWL
				,0 AS WinlossRB
				,0 AS AmountDueToBA
				,0 AS AmountDueToRB
				,0 AS CommBA
				,0 AS CommRB
				,SUM(b.playercomm) AS playercomm
				,'' AS race
				,m.matchcode
				,ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral
				,m.sporttype
				,m.showtime AS showtime
				,sum(b.betcount) betcount
			FROM bodb_LicenseeReport.dbo.rptWinlostbyLeague b WITH (NOLOCK, INDEX = IX_recommend)
			INNER JOIN #match AS m WITH (NOLOCK) ON m.matchid = b.matchid
			INNER JOIN @TempAg ag ON b.recommend = ag.custid AND b.Currency = ag.Currency
			WHERE winlostdate BETWEEN @fromdate AND @TempToDate
				AND (
					b.bettype < 31
					OR (b.bettype BETWEEN 121 AND 999)	
					OR (b.Bettype BETWEEN 1301 and 1399) --new tennis's bettypes			
					)
				AND b.bettype NOT IN (901,902,903)
				AND b.leagueid = @LeagueID
				AND (
					m.matchid = @MatchID
					OR @MatchID = 0
					)
				AND b.statusID IN (
					SELECT *
					FROM @status
					)
				AND b.isba = 0
			GROUP BY b.Winlostdate
				,ag.currency
				,m.matchid
				,m.homeid
				,m.awayid
				,b.bettype
				,m.leagueid
				,m.matchcode
				,m.isNeutral
				,b.bettype
				,m.sporttype
				,m.showtime
				,CASE 
					WHEN (b.bettype IN (1,2,3,7,12,8,20,21,1301,1303,1305,1306,1308,1311,1312,1316,1318,1324,153,154,155,156)	 -- add more Sportting Solution bettype 
							OR b.bettype BETWEEN 81 AND 88
							OR b.bettype BETWEEN 90 AND 120
							OR b.bettype IN (157,178,183,184,194,197,198,203,204,205) -- add more bettype BetRadar 
							OR b.bettype BETWEEN 401 AND 404 -- add more PH-AIO new bettypes
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
	END
END

---
INSERT INTO @ExchangeDaily
SELECT ExchangeDate
	,ExchangeId
	,USD
	,EUR
	,GBP
FROM Lrf_f_GetExchangeDaily(@fromDate, @toDate)

-- Result  
SELECT matchid
	,CASE 
		WHEN b.sporttype IN (181, 182, 184)
			THEN 0
		ELSE homeid
		END homeID
	,CASE 
		WHEN b.sporttype IN (181, 182, 184)
			THEN 0
		ELSE awayid
		END awayid
	,CASE 
		WHEN ISNULL(b.KickoffTime, 0) = 0
			THEN 0
		ELSE b.KickoffTime
		END KickoffTime
	,CASE 
		WHEN b.bettype BETWEEN 1101 AND 1199
			THEN b.bettype
		ELSE 0
		END AS bettype
	--,ProductName
	,--bettype,  
	leagueid
	,CAST(SUM(turnover) AS MONEY) AS turnover
	,CAST(SUM(turnover * e.USD) AS MONEY) AS turnoverUSD
	,CAST(SUM(turnover * e.EUR) AS MONEY) AS turnoverEUR
	,CAST(SUM(turnover * e.GBP) AS MONEY) AS turnoverGBP
	
	,CAST(SUM(MemberWinLost) AS MONEY) AS MemberWinLost
	,CAST(SUM(MemberWinLost * e.USD) AS MONEY) AS MemberWinLostUSD
	,CAST(SUM(MemberWinLost * e.EUR) AS MONEY) AS MemberWinLostEUR
	,CAST(SUM(MemberWinLost * e.GBP) AS MONEY) AS MemberWinLostGBP
	
	,CAST(SUM(LicenseeWL) AS MONEY) AS LicenseeWL
	,CAST(SUM(LicenseeWL * e.USD) AS MONEY) AS LicenseeWLUSD
	,CAST(SUM(LicenseeWL * e.EUR) AS MONEY) AS LicenseeWLEUR
	,CAST(SUM(LicenseeWL * e.GBP) AS MONEY) AS LicenseeWLGBP
	--,CAST(SUM(WinlossRB) AS MONEY) AS WinlossRB
	--,CAST(SUM(WinlossRB * e.USD) AS MONEY) AS WinlossRBUSD
	--,CAST(SUM(WinlossRB * e.EUR) AS MONEY) AS WinlossRBEUR
	,CAST(SUM(CommBA) AS MONEY) AS CommBA
	,CAST(SUM(CommBA * e.USD) AS MONEY) AS CommBAUSD
	,CAST(SUM(CommBA * e.EUR) AS MONEY) AS CommBAEUR
	,CAST(SUM(CommBA * e.GBP) AS MONEY) AS CommBAGBP
	--,CAST(SUM(commRB) AS MONEY) AS commRB
	--,CAST(SUM(commRB * e.USD) AS MONEY) AS commRBUSD
	--,CAST(SUM(commRB * E.EUR) AS MONEY) AS commRBEUR
	,CAST(SUM(PlayerComm) AS MONEY) AS PlayerComm
	,CAST(SUM(PlayerComm * e.USD) AS MONEY) AS PlayerCommUSD
	,CAST(SUM(PlayerComm * e.EUR) AS MONEY) AS PlayerCommEUR
	,CAST(SUM(PlayerComm * e.GBP) AS MONEY) AS PlayerCommGBP
	
	,CAST(SUM(AmtDuetoBA) AS MONEY) AS AmtDuetoBA
	,CAST(SUM((AmtDuetoBA) * e.USD) AS MONEY) AS AmtDuetoBAUSD
	,CAST(SUM((AmtDuetoBA) * e.EUR) AS MONEY) AS AmtDuetoBAEUR
	,CAST(SUM((AmtDuetoBA) * e.GBP) AS MONEY) AS AmtDuetoBAGBP
	,CASE 
		WHEN b.sporttype IN (181, 182, 184)
			THEN ''
		ELSE matchcode
		END matchcode
	,isNeutral
	,b.sporttype
	,CASE 
		WHEN b.bettype BETWEEN 1101 AND 1199
			THEN b.showtime
		ELSE ''
		END AS showtime
	,sum(b.betcount) betcount
--,odds2
FROM @AgMatchWLDetails b
--INNER JOIN (SELECT *  FROM Lrf_f_GetExchangeDaily(@_FromDate,@_ToDate))e   
INNER JOIN @ExchangeDaily e ON b.winlostdate = e.ExchangeDate
	AND b.currency = e.ExchangeId
WHERE b.odds2 >= @Odds
GROUP BY matchid
	,CASE 
		WHEN b.sporttype IN (181, 182, 184)
			THEN 0
		ELSE homeid
		END
	,CASE 
		WHEN b.sporttype IN (181, 182, 184)
			THEN 0
		ELSE awayid
		END
	,CASE 
		WHEN ISNULL(b.KickoffTime, 0) = 0
			THEN 0
		ELSE b.KickoffTime
		END
	,CASE 
		WHEN b.bettype BETWEEN 1101 AND 1199
			THEN b.bettype
		ELSE 0
		END
	--,ProductName
	,--bettype,  
	CASE 
		WHEN b.sporttype IN (181, 182, 184)
			THEN ''
		ELSE matchcode
		END
	,leagueid
	,isNeutral
	,b.sporttype
	,CASE 
		WHEN b.bettype BETWEEN 1101 AND 1199
			THEN showtime
		ELSE ''
		END
--,b.odds2
--,b.betcount
/*ORDER BY CASE ProductName
		WHEN 'SB'
			THEN 0
		WHEN 'NG'
			THEN 1
		WHEN 'LC'
			THEN 2
		ELSE 3
		END
*/
DROP TABLE #match
GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_WinlostByLeague] TO [bodbLicenseeNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_WinlostByLeague] TO [vnteam] AS [dbo]
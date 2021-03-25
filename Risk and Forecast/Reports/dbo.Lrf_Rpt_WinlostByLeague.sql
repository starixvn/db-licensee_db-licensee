/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_WinlostByLeague]
	@AgentList		VARCHAR(MAX)
	,@FromDate SMALLDATETIME
	,@ToDate SMALLDATETIME
	,@Odds FLOAT = 0
	,@LeagueID INT
	,@MatchID INT = 0
	,@MoveBetsDay SMALLDATETIME
	,@BalanceUpDay SMALLDATETIME
	,@ShowWin BIT = 1
	,@ShowLoss BIT = 1
	,@ShowDraw BIT = 1
	,@ShowSB BIT = 1
	,@ShowBA BIT = 1
	,@BaseCurrency	VARCHAR(3) = ''
AS

/*
	Created	: Florent
	Task: Winloss by League
	Date: 2013-12-30
	DB: DBEXT.bodb02
	Revision:
		- 20140207@Florent: Add filter ShowSB , ShowBA
		- 20140620@Florent: offer 14 new bettypes and Sporting Solution (36 new bettypes)
		- 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
		- 20150127@Jim: support base on GBP Currency
		- 20150623@Winnie: exclude 3 transactions SOLD/BOUGHT/BetTrade Commission
		- 20151127@Bobby: #48081 - Apply PH-AIO new bettypes
		- 20151203@Bobby: Database - Change datatype [Redmine: #48660]
		- 20160727@Jim:  LRF - Commercial terms changed for Bet Trade [Redmine: #61342]
		- 20160720@Jim : Implement 67 new bet types (PH All in one - Phase 2) [Redmine : #53520]
		- 20170228@Paul: Get @AgentList by web instead of @UserId, @CurrencyID, @LicenseeID [Redmine: #71679]
		- 20170327@Paul: Implement Cash Out [RedmineID :#71727]
		- 20180129@Harper: Remove LC from product list [RedmineID: #85965]
		- 20180808@Amanda: Remove Racing [RedmineID: #99378]
		- 20181019@Amanda: Add new bet types for E-Sports 2.0 [RedmineID: #100721]
		- 20190620@Amanda: Add Base currency param [RedmineID: #112531]
		- 20190407@Amanda: Add new bet types (PH AIO - Phase 4a) [RedmineID: #115448]
		- 20191608@Amanda: Add new bet types (PH AIO - Phase 4b) [RedmineID: #118300]
		- 20191118@Amanda: Add new bet types (BM AIO - Phase 2) [RedmineID: #120336]
		- 20190102@Vickie: Add new bet types (PH AIO - Phase 5) [RedmineID: #126005]
		- 20200508@Vickie: Add new bet types for E-Sports 2.0 [RedmineID: #132548]
		- 20201023@Hogan: Integrate new bet type Time Machine OU [RedmineID: #142692]
		- 20201027@Kos: Change to use new table to check performance [RedmineID: #143310]
		- 20210304@Hogan: Offer Decimal Odds Only for Match [RedmineID: #151010]
		- 20210304@Hogan: Integrate Cricket AIO [RedmineID: #150386]

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

BEGIN
	SET NOCOUNT ON

	DECLARE @ExchangeDaily TABLE (
		FromDate SMALLDATETIME
		,ToDate SMALLDATETIME
		,ExchangeId INT
		,Rate FLOAT
		)
	
	DECLARE @bettype AS TABLE (bettype INT)
	DECLARE @TempFromDate SMALLDATETIME
	DECLARE @TempToDate SMALLDATETIME
	--
	DECLARE @Status AS TABLE (StatusID INT)

	--Set cut off date to convert  bettype 501
	DECLARE @501CutoffDate SMALLDATETIME = '2021-04-08'

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

	CREATE TABLE #TempAg (CustId INT, Currency INT, PRIMARY KEY (CustId, Currency))

	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@AgentList
	
		INSERT INTO #TempAg(CustId, Currency)
		SELECT AgentId, Currency 
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
			,ErrMsg = N'Parameter invalid.'

		RETURN
	END CATCH;

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
		,AmtDueToBA MONEY
		,CommBA MONEY
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
						WHEN (b.bettype IN (1,2,3,7,12,8,20,21,1301,1303,1305,1306,1308,1311,1312,1316,1318,1324,153,154,155,156,228)	 -- add more Sportting Solution bettype 
								OR b.bettype BETWEEN 9001 AND 9087	-- Esport 2
								OR b.bettype BETWEEN 81 AND 88
								OR b.bettype BETWEEN 90 AND 120
								OR b.bettype IN (157,178,183,184,194,197,198,203,204,205) -- add more bettype BetRadar 
								OR b.bettype BETWEEN 401 AND 404 -- add more PH-AIO new bettypes
								OR b.bettype = 428 -- 2H Odd/Even
								OR b.bettype IN (467,468,469) -- PH-AIO new bettypes (phase 4a)
								OR b.bettype IN (470,471,472,479,481,488,489,490,491,492) -- PH-AIO new bettypes (phase 4b)
								OR (b.bettype NOT IN (703, 711) AND b.bettype BETWEEN 701 AND 714) -- BM-AIO new bettypes (phase 2)
								OR b.bettype IN (381,382,386,387,388,389,390,393,394,400) -- PH-AIO new bettypes (phase 5)
								OR (b.bettype = 501 AND b.transdate < @501CutoffDate)
							)
							THEN CASE 
									WHEN b.OddsType = 1
										THEN b.odds + 1 --decimal
									WHEN b.OddsType = 2
										THEN b.Odds + 1 --hongkong to decimal
									WHEN b.OddsType IN (3, 4, 7)
										THEN --malay and indo and new oddstype to decimal
											CASE 
												WHEN b.odds < 0
													THEN (1 - CAST(1 AS FLOAT) / CAST(b.odds AS FLOAT))
												WHEN b.odds >= 0
													THEN (1 + b.odds)
												END
									WHEN OddsType = 5
										THEN --american odds to decimal
											CASE 
												WHEN (b.odds * 100) < 0
													THEN (1 - CAST(1 AS FLOAT) / CAST(b.odds AS FLOAT))
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
					,-SUM(winlost - b.actual_stake + awinlost + comm) AS AmountDueToBA
					,SUM(comm) AS CommBA
					,SUM(b.playercomm) AS PlayerComm
					,''
					,m.matchcode
					,ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral
					,m.sporttype
					,'' AS ShowTime
					,count(1) betcount
				FROM dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN dbo.match m WITH (NOLOCK) ON m.matchid = b.matchid
					INNER JOIN #TempAg ta ON b.recommend = ta.CustId AND b.Currency = ta.Currency
				WHERE b.winlostdate BETWEEN @TempFromDate AND @todate
					AND (
						b.bettype <= 30
						OR (b.bettype BETWEEN 121 AND 999)
						OR (b.Bettype BETWEEN 1301 AND 1399) --new tennis's bettye
						OR (b.Bettype BETWEEN 9001 AND 9399) -- E-Sports 2.0	
						OR (b.Bettype BETWEEN 9400 AND 9699) -- Cricket AIO
						)
					AND (b.bettype < 901 OR b.bettype > 904)
					AND (b.bettype < 911 OR b.bettype > 914)
					AND (
						@MatchID = 0
						OR m.matchid = @MatchID
						OR (m.sporttype = 50 AND m.ChildMatchType = 200 AND m.ParentID = @MatchID)
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
						WHEN (b.bettype IN (1,2,3,7,12,8,20,21,1301,1303,1305,1306,1308,1311,1312,1316,1318,1324,153,154,155,156,228)	 -- add more Sportting Solution bettype 
								OR b.bettype BETWEEN 9001 AND 9087	-- Esport 2
								OR b.bettype BETWEEN 81 AND 88
								OR b.bettype BETWEEN 90 AND 120
								OR b.bettype IN (157,178,183,184,194,197,198,203,204,205) -- add more bettype BetRadar 
								OR b.bettype BETWEEN 401 AND 404 -- add more PH-AIO new bettypes
								OR b.bettype = 428 -- 2H Odd/Even
								OR b.bettype IN (467,468,469) -- PH-AIO new bettypes (phase 4a)
								OR b.bettype IN (470,471,472,479,481,488,489,490,491,492) -- PH-AIO new bettypes (phase 4b)
								OR (b.bettype NOT IN (703, 711) AND b.bettype BETWEEN 701 AND 714) -- BM-AIO new bettypes (phase 2)
								OR b.bettype IN (381,382,386,387,388,389,390,393,394,400) -- PH-AIO new bettypes (phase 5)
								OR (b.bettype = 501 AND b.transdate < @501CutoffDate)
							)
							THEN CASE 
									WHEN b.OddsType = 1
										THEN b.odds + 1 --decimal
									WHEN b.OddsType = 2
										THEN b.Odds + 1 --hongkong to decimal
									WHEN b.OddsType IN (3, 4, 7)
										THEN --malay and indo and new oddstype to decimal
											CASE 
												WHEN b.odds < 0
													THEN (1 - CAST(1 AS FLOAT) / CAST(b.odds AS FLOAT))
												WHEN b.odds >= 0
													THEN (1 + b.odds)
											END
									WHEN OddsType = 5
										THEN --american odds to decimal
											CASE 
												WHEN (b.odds * 100) < 0
													THEN (1 - CAST(1 AS FLOAT) / CAST(b.odds AS FLOAT))
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
						WHEN (b.bettype IN (1,2,3,7,12,8,20,21,1301,1303,1305,1306,1308,1311,1312,1316,1318,1324,153,154,155,156,228)	 -- add more Sportting Solution bettype 
								OR b.bettype BETWEEN 9001 AND 9087	-- Esport 2
								OR b.bettype BETWEEN 81 AND 88
								OR b.bettype BETWEEN 90 AND 120
								OR b.bettype IN (157,178,183,184,194,197,198,203,204,205) -- add more bettype BetRadar 
								OR b.bettype BETWEEN 401 AND 404 -- add more PH-AIO new bettypes
								OR b.bettype = 428 -- 2H Odd/Even  
								OR b.bettype IN (467,468,469) -- PH-AIO new bettypes (phase 4a)
								OR b.bettype IN (470,471,472,479,481,488,489,490,491,492) -- PH-AIO new bettypes (phase 4b)
								OR (b.bettype NOT IN (703, 711) AND b.bettype BETWEEN 701 AND 714) -- BM-AIO new bettypes (phase 2)
								OR b.bettype IN (381,382,386,387,388,389,390,393,394,400) -- PH-AIO new bettypes (phase 5)
								OR (b.bettype = 501 AND b.transdate < @501CutoffDate)
							)
							THEN CASE 
									WHEN b.OddsType = 1
										THEN b.odds + 1 --decimal
									WHEN b.OddsType = 2
										THEN b.Odds + 1 --hongkong to decimal
									WHEN b.OddsType IN (3, 4, 7)
										THEN --malay and indo and new oddstype to decimal
											CASE
												WHEN b.odds < 0
													THEN (1 - CAST(1 AS FLOAT) / CAST(b.odds AS FLOAT))
												WHEN b.odds >= 0
													THEN (1 + b.odds)
											END
									WHEN OddsType = 5
										THEN --american odds to decimal
											CASE 
												WHEN (b.odds * 100) < 0
													THEN (1 - CAST(1 AS FLOAT) / CAST(b.odds AS FLOAT))
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
					,0 AS AmountDueToBA
					,0 AS CommBA
					,SUM(b.playercomm) AS PlayerComm
					,''
					,m.matchcode
					,ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral
					,m.sporttype
					,m.showtime AS ShowTime
					,count(1) betcount
				FROM dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN dbo.match m WITH (NOLOCK) ON m.matchid = b.matchid
					INNER JOIN #TempAg ta ON b.recommend = ta.CustId AND b.Currency = ta.Currency
				WHERE b.winlostdate BETWEEN @TempFromDate AND @todate
					AND (
						b.bettype <= 30
						OR (b.bettype BETWEEN 121 AND 999)	
						OR (b.Bettype BETWEEN 1301 AND 1399) --new tennis's bettypes
						OR (b.Bettype BETWEEN 9001 AND 9399) -- E-Sports 2.0
						OR (b.Bettype BETWEEN 9400 AND 9699) -- Cricket AIO
						)
					AND (b.bettype < 901 OR b.bettype > 904)
					AND (b.bettype < 911 OR b.bettype > 914)
					AND (
						@MatchID = 0
						OR m.matchid = @MatchID
						OR (m.sporttype = 50 AND m.ChildMatchType = 200 AND m.ParentID = @MatchID)
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
						WHEN (b.bettype IN (1,2,3,7,12,8,20,21,1301,1303,1305,1306,1308,1311,1312,1316,1318,1324,153,154,155,156,228)	 -- add more Sportting Solution bettype 
								OR b.bettype BETWEEN 9001 AND 9087	-- Esport 2
								OR b.bettype BETWEEN 81 AND 88
								OR b.bettype BETWEEN 90 AND 120
								OR b.bettype IN (157,178,183,184,194,197,198,203,204,205) -- add more bettype BetRadar 
								OR b.bettype BETWEEN 401 AND 404 -- add more PH-AIO new bettypes
								OR b.bettype = 428 -- 2H Odd/Even  
								OR b.bettype IN (467,468,469) -- PH-AIO new bettypes (phase 4a)
								OR b.bettype IN (470,471,472,479,481,488,489,490,491,492) -- PH-AIO new bettypes (phase 4b)
								OR (b.bettype NOT IN (703, 711) AND b.bettype BETWEEN 701 AND 714) -- BM-AIO new bettypes (phase 2)
								OR b.bettype IN (381,382,386,387,388,389,390,393,394,400) -- PH-AIO new bettypes (phase 5)
								OR (b.bettype = 501 AND b.transdate < @501CutoffDate)
							)
							THEN CASE 
									WHEN b.OddsType = 1
										THEN b.odds + 1 --decimal
									WHEN b.OddsType = 2
										THEN b.Odds + 1 --hongkong to decimal
									WHEN b.OddsType IN (3, 4, 7)
										THEN --malay and indo and new oddstype to decimal
											CASE 
												WHEN b.odds < 0
													THEN (1 - CAST(1 AS FLOAT) / CAST(b.odds AS FLOAT))
												WHEN b.odds >= 0
													THEN (1 + b.odds)
											END
									WHEN OddsType = 5
										THEN --american odds to decimal
											CASE 
												WHEN (b.odds * 100) < 0
													THEN (1 - CAST(1 AS FLOAT) / CAST(b.odds AS FLOAT))
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
		,ParentID INT
		,ChildMatchType INT
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
				,m.ParentID
				,m.ChildMatchType
			FROM dbo.match14 AS m WITH (NOLOCK)
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
				,m.ParentID
				,m.ChildMatchType
			FROM DBARC.bodb_archive.dbo.match_bk AS m WITH (NOLOCK)
			WHERE m.eventdate BETWEEN @fromdate AND @TempToDate
				AND m.leagueid = @LeagueID
				AND (
					m.matchid = @MatchID
					OR @MatchID = 0
					)

			CREATE TABLE #Date (Date SMALLDATETIME, PRIMARY KEY(Date))

			INSERT INTO #Date
			SELECT [Date]
			FROM f_GetDateBetweenTwoDates (@fromdate, @TempToDate)

			IF @ShowBA = 1
			BEGIN
				INSERT INTO @AgMatchWLDetails
				SELECT b.*
				FROM #Date AS d
					CROSS APPLY (
					SELECT b.Winlostdate
						,NULL AS KickoffTime
						,ag.currency
						,m.matchid
						,m.homeid
						,m.awayid
						,b.bettype
						,'BA' AS ProductName
						,m.leagueid
						,CASE 
							WHEN (b.bettype IN (1,2,3,7,12,8,20,21,1301,1303,1305,1306,1308,1311,1312,1316,1318,1324,153,154,155,156,228)	 -- add more Sportting Solution bettype 
									OR b.bettype BETWEEN 9001 AND 9087	-- Esport 2
									OR b.bettype BETWEEN 81 AND 88
									OR b.bettype BETWEEN 90 AND 120
									OR b.bettype IN (157,178,183,184,194,197,198,203,204,205) -- add more bettype BetRadar 
									OR b.bettype BETWEEN 401 AND 404 -- add more PH-AIO new bettypes
									OR b.bettype = 428 -- 2H Odd/Even  
									OR b.bettype IN (467,468,469) -- PH-AIO new bettypes (phase 4a)
									OR b.bettype IN (470,471,472,479,481,488,489,490,491,492) -- PH-AIO new bettypes (phase 4b)
									OR (b.bettype NOT IN (703, 711) AND b.bettype BETWEEN 701 AND 714) -- BM-AIO new bettypes (phase 2)
									OR b.bettype IN (381,382,386,387,388,389,390,393,394,400) -- PH-AIO new bettypes (phase 5)
									OR (b.bettype = 501 AND b.winlostdate < @501CutoffDate)
								)
								THEN CASE 
										WHEN b.OddsType = 1
											THEN b.odds + 1 --decimal
										WHEN b.OddsType = 2
											THEN b.Odds + 1 --hongkong to decimal
										WHEN b.OddsType IN (3, 4, 7)
											THEN --malay and indo and new oddstype to decimal
												CASE 
													WHEN b.odds < 0
														THEN (1 - CAST(1 AS FLOAT) / CAST(b.odds AS FLOAT))
													WHEN b.odds >= 0
														THEN (1 + b.odds)
													END
										WHEN OddsType = 5
											THEN --american odds to decimal
												CASE 
													WHEN (b.odds * 100) < 0
														THEN (1 - CAST(1 AS FLOAT) / CAST(b.odds AS FLOAT))
													WHEN (b.odds * 100) % 2 = 0
														THEN 2
													WHEN (b.odds * 100) > 0
														THEN (1 + b.odds)
													END
										END
							ELSE b.Odds
							END odds2
						,SUM(stake) AS Stake
						,SUM(winlost) AS WinLost
						,0 AS LicenseeWL
						,-sum(Winlost + awinlost + comm) AS AmountDueToBA
						,sum(comm) AS CommBA
						,SUM(b.playercomm) AS playercomm
						,'' AS race
						,m.matchcode
						,ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral
						,m.sporttype
						,m.showtime AS showtime
						,sum(b.betcount) betcount
					FROM bodb_LicenseeReport.dbo.rptWinlostbyLeague b WITH (NOLOCK)
						INNER JOIN #match AS m WITH (NOLOCK) ON m.matchid = b.matchid
						INNER JOIN #TempAg ag ON b.recommend = ag.custid AND b.Currency = ag.Currency
					WHERE winlostdate = d.Date
						AND (
							b.bettype <= 30
							OR (b.bettype BETWEEN 121 AND 999)
							OR (b.Bettype BETWEEN 1301 AND 1399) --new tennis's bettypes
							OR (b.Bettype BETWEEN 9001 AND 9399) -- E-Sports 2.0		
							OR (b.Bettype BETWEEN 9400 AND 9699) -- Cricket AIO	
							)
						AND (b.bettype < 901 OR b.bettype > 904)
						AND (b.bettype < 911 OR b.bettype > 914)
						AND b.leagueid = @LeagueID
						AND (
							m.matchid = @MatchID
							OR @MatchID = 0
							OR (m.sporttype = 50 AND m.ChildMatchType = 200 AND m.ParentID = @MatchID)
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
							WHEN (b.bettype IN (1,2,3,7,12,8,20,21,1301,1303,1305,1306,1308,1311,1312,1316,1318,1324,153,154,155,156,228)	 -- add more Sportting Solution bettype 
									OR b.bettype BETWEEN 9001 AND 9087	-- Esport 2
									OR b.bettype BETWEEN 81 AND 88
									OR b.bettype BETWEEN 90 AND 120
									OR b.bettype IN (157,178,183,184,194,197,198,203,204,205) -- add more bettype BetRadar 
									OR b.bettype BETWEEN 401 AND 404 -- add more PH-AIO new bettypes
									OR b.bettype = 428 -- 2H Odd/Even  
									OR b.bettype IN (467,468,469) -- PH-AIO new bettypes (phase 4a)
									OR b.bettype IN (470,471,472,479,481,488,489,490,491,492) -- PH-AIO new bettypes (phase 4b)
									OR (b.bettype NOT IN (703, 711) AND b.bettype BETWEEN 701 AND 714) -- BM-AIO new bettypes (phase 2)
									OR b.bettype IN (381,382,386,387,388,389,390,393,394,400) -- PH-AIO new bettypes (phase 5)
									OR (b.bettype = 501 AND b.winlostdate < @501CutoffDate)
								)
								THEN CASE 
										WHEN b.OddsType = 1
											THEN b.odds + 1 --decimal
										WHEN b.OddsType = 2
											THEN b.Odds + 1 --hongkong to decimal
										WHEN b.OddsType IN (3, 4, 7)
											THEN --malay and indo and new oddstype to decimal
												CASE 
													WHEN b.odds < 0
														THEN (1 - CAST(1 AS FLOAT) / CAST(b.odds AS FLOAT))
													WHEN b.odds >= 0
														THEN (1 + b.odds)
												END
										WHEN OddsType = 5
											THEN --american odds to decimal
												CASE 
													WHEN (b.odds * 100) < 0
														THEN (1 - CAST(1 AS FLOAT) / CAST(b.odds AS FLOAT))
													WHEN (b.odds * 100) % 2 = 0
														THEN 2
													WHEN (b.odds * 100) > 0
														THEN (1 + b.odds)
												END
										END
							ELSE b.Odds
						END
				) AS b
			END

			IF @ShowSB = 1
			BEGIN
				INSERT INTO @AgMatchWLDetails
				SELECT b.*
				FROM #Date AS d
					CROSS APPLY (
						SELECT b.Winlostdate
							,NULL AS KickoffTime
							,ag.currency
							,m.matchid
							,m.homeid
							,m.awayid
							,b.bettype
							,'SB' AS ProductName
							,m.leagueid
							,CASE 
								WHEN (b.bettype IN (1,2,3,7,12,8,20,21,1301,1303,1305,1306,1308,1311,1312,1316,1318,1324,153,154,155,156,228)	 -- add more Sportting Solution bettype 
										OR b.bettype BETWEEN 9001 AND 9087	-- Esport 2
										OR b.bettype BETWEEN 81 AND 88
										OR b.bettype BETWEEN 90 AND 120
										OR b.bettype IN (157,178,183,184,194,197,198,203,204,205) -- add more bettype BetRadar 
										OR b.bettype BETWEEN 401 AND 404 -- add more PH-AIO new bettypes
										OR b.bettype = 428 -- 2H Odd/Even  
										OR b.bettype IN (467,468,469) -- PH-AIO new bettypes (phase 4a)
										OR b.bettype IN (470,471,472,479,481,488,489,490,491,492) -- PH-AIO new bettypes (phase 4b)
										OR (b.bettype NOT IN (703, 711) AND b.bettype BETWEEN 701 AND 714) -- BM-AIO new bettypes (phase 2)
										OR b.bettype IN (381,382,386,387,388,389,390,393,394,400) -- PH-AIO new bettypes (phase 5)
										OR (b.bettype = 501 AND b.winlostdate < @501CutoffDate)
									)
									THEN CASE 
											WHEN b.OddsType = 1
												THEN b.odds + 1 --decimal
											WHEN b.OddsType = 2
												THEN b.Odds + 1 --hongkong to decimal
											WHEN b.OddsType IN (3, 4, 7)
												THEN --malay and indo and new oddstype to decimal
													CASE 
														WHEN b.odds < 0
															THEN (1 - CAST(1 AS FLOAT) / CAST(b.odds AS FLOAT))
														WHEN b.odds >= 0
															THEN (1 + b.odds)
														END
											WHEN OddsType = 5
												THEN --american odds to decimal
													CASE 
														WHEN (b.odds * 100) < 0
															THEN (1 - CAST(1 AS FLOAT) / CAST(b.odds AS FLOAT))
														WHEN (b.odds * 100) % 2 = 0
															THEN 2
														WHEN (b.odds * 100) > 0
															THEN (1 + b.odds)
														END
											END
								ELSE b.Odds
								END odds2
							,SUM(stake) AS Stake
							,SUM(winlost) AS WinLost
							,- SUM(b.winlost) AS LicenseeWL
							,0 AS AmountDueToBA
							,0 AS CommBA
							,SUM(b.playercomm) AS playercomm
							,'' AS race
							,m.matchcode
							,ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral
							,m.sporttype
							,m.showtime AS showtime
							,sum(b.betcount) betcount
						FROM bodb_LicenseeReport.dbo.rptWinlostbyLeague b WITH (NOLOCK)
							INNER JOIN #match AS m WITH (NOLOCK) ON m.matchid = b.matchid
							INNER JOIN #TempAg ag ON b.recommend = ag.custid AND b.Currency = ag.Currency
						WHERE winlostdate = d.Date
							AND (
								b.bettype <= 30
								OR (b.bettype BETWEEN 121 AND 999)	
								OR (b.Bettype BETWEEN 1301 AND 1399) --new tennis's bettypes
								OR (b.Bettype BETWEEN 9001 AND 9399) -- E-Sports 2.0	
								OR (b.Bettype BETWEEN 9400 AND 9699) -- Cricket AIO
								)
							AND (b.bettype < 901 OR b.bettype > 904)
							AND (b.bettype < 911 OR b.bettype > 914)
							AND b.leagueid = @LeagueID
							AND (
								m.matchid = @MatchID
								OR @MatchID = 0
								OR (m.sporttype = 50 AND m.ChildMatchType = 200 AND m.ParentID = @MatchID)
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
								WHEN (b.bettype IN (1,2,3,7,12,8,20,21,1301,1303,1305,1306,1308,1311,1312,1316,1318,1324,153,154,155,156,228)	 -- add more Sportting Solution bettype 
										OR b.bettype BETWEEN 9001 AND 9087	-- Esport 2
										OR b.bettype BETWEEN 81 AND 88
										OR b.bettype BETWEEN 90 AND 120
										OR b.bettype IN (157,178,183,184,194,197,198,203,204,205) -- add more bettype BetRadar 
										OR b.bettype BETWEEN 401 AND 404 -- add more PH-AIO new bettypes
										OR b.bettype = 428 -- 2H Odd/Even  
										OR b.bettype IN (467,468,469) -- PH-AIO new bettypes (phase 4a)
										OR b.bettype IN (470,471,472,479,481,488,489,490,491,492) -- PH-AIO new bettypes (phase 4b)
										OR (b.bettype NOT IN (703, 711) AND b.bettype BETWEEN 701 AND 714) -- BM-AIO new bettypes (phase 2)
										OR b.bettype IN (381,382,386,387,388,389,390,393,394,400) -- PH-AIO new bettypes (phase 5)
										OR (b.bettype = 501 AND b.winlostdate < @501CutoffDate)
									)
									THEN CASE 
											WHEN b.OddsType = 1
												THEN b.odds + 1 --decimal
											WHEN b.OddsType = 2
												THEN b.Odds + 1 --hongkong to decimal
											WHEN b.OddsType IN (3, 4, 7)
												THEN --malay and indo and new oddstype to decimal
													CASE 
														WHEN b.odds < 0
															THEN (1 - CAST(1 AS FLOAT) / CAST(b.odds AS FLOAT))
														WHEN b.odds >= 0
															THEN (1 + b.odds)
														END
											WHEN OddsType = 5
												THEN --american odds to decimal
													CASE 
														WHEN (b.odds * 100) < 0
															THEN (1 - CAST(1 AS FLOAT) / CAST(b.odds AS FLOAT))
														WHEN (b.odds * 100) % 2 = 0
															THEN 2
														WHEN (b.odds * 100) > 0
															THEN (1 + b.odds)
														END
											END
								ELSE b.Odds
							END
					) AS b
			END

			DROP TABLE #Date
		END
	END

	INSERT INTO @ExchangeDaily(FromDate, ToDate, ExchangeId, Rate)
	SELECT FromDate, ToDate, ExchangeID, Rate
	FROM dbo.Lrf_f_GetExchangeRate(@fromDate, @toDate, @BaseCurrency, '') e
	WHERE EXISTS (SELECT 1 FROM #TempAg a WHERE a.Currency = e.ExchangeID)

	-- Result
	SELECT b.matchid
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
		, 0 AS bettype
		, b.leagueid
		,CAST(SUM(b.turnover * e.Rate) AS MONEY) AS turnover
		,CAST(SUM(b.MemberWinLost * e.Rate) AS MONEY) AS MemberWinLost
		,CAST(SUM(b.LicenseeWL * e.Rate) AS MONEY) AS LicenseeWL
		,CAST(SUM(b.CommBA * e.Rate) AS MONEY) AS CommBA
		,CAST(SUM(b.PlayerComm * e.Rate) AS MONEY) AS PlayerComm
		,CAST(SUM((b.AmtDueToBA) * e.Rate) AS MONEY) AS AmtDuetoBA
		,CASE 
			WHEN b.sporttype IN (181, 182, 184)
				THEN ''
			ELSE matchcode
			END matchcode
		,b.isNeutral
		,b.sporttype
		,'' AS showtime
		,sum(b.betcount) betcount
	FROM @AgMatchWLDetails b
		INNER JOIN @ExchangeDaily e ON b.winlostdate BETWEEN e.FromDate AND e.ToDate
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
			WHEN b.sporttype IN (181, 182, 184)
				THEN ''
			ELSE matchcode
			END
		,b.leagueid
		,b.isNeutral
		,b.sporttype

	DROP TABLE #match
	DROP TABLE #TempAg
END
GO
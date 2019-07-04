/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

USE [bodb02]
GO
 
ALTER PROCEDURE [dbo].[Lrf_Rpt_WinlostByLeague]
	@FromDate SMALLDATETIME
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
	,@AgentList		VARCHAR(MAX)
	,@BaseCurrency	VARCHAR(3) = ''
AS
/*
exec Lrf_Rpt_WinlostByLeague 
@licenseeid=8,@userid=10
,@currencyid=0,@fromdate='2016-06-01 00:00:00'
,@todate='2016-06-30 00:00:00',@odds=0,@leagueid=10,@matchid=0
,@movebetsday='2016-07-11 00:00:00',@balanceupday='2016-07-09 00:00:00',@showwin=1
,@showloss=1,@showdraw=1,@showsb=1,@showba=1

*/
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
		- 20160727@Jim:  LRF - Commercial terms changed for Bet Trade [Redmine: #61342]
		- 20160720@Jim : Implement 67 new bet types (PH All in one - Phase 2) [Redmine : #53520]
		- 20170228@Paul: Get @AgentList by web instead of @UserId, @CurrencyID, @LicenseeID [Redmine: #71679]
		- 20170327@Paul: Implement Cash Out [RedmineID :#71727]
		- 20180129@Harper: Remove LC from product list [RedmineID: #85965]
		- 20180808@Amanda: Remove Racing [RedmineID: #99378]
		- 20181019@Amanda: Add new bet types for E-Sports 2.0 [RedmineID: #100721]
		- 20190620@Amanda: Add Base currency param [RedmineID: #112531]
		- 20181019@Amanda: Add new bet types (PH AIO - Phase 4a) [RedmineID: #115448]

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

	DECLARE @TempAg AS TABLE (CustId INT,Currency int)

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
						WHEN (b.bettype IN (1,2,3,7,12,8,20,21,1301,1303,1305,1306,1308,1311,1312,1316,1318,1324,153,154,155,156)	 -- add more Sportting Solution bettype 
								OR b.bettype BETWEEN 9001 AND 9086	-- Esport 2
								OR b.bettype BETWEEN 81 AND 88
								OR b.bettype BETWEEN 90 AND 120
								OR b.bettype IN (157,178,183,184,194,197,198,203,204,205) -- add more bettype BetRadar 
								OR b.bettype BETWEEN 401 AND 404 -- add more PH-AIO new bettypes
								OR b.bettype = 428 -- 2H Odd/Even
								OR b.bettype IN (467,468,469) -- PH-AIO new bettypes (phase 4a)
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
					,-SUM(winlost - b.actual_stake + awinlost + comm) AS AmountDueToBA
					,SUM(comm) AS CommBA
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
						b.bettype <= 30
						OR (b.bettype BETWEEN 121 AND 999)		
						OR (b.Bettype BETWEEN 1301 and 1399) --new tennis's bettye
						OR (b.Bettype BETWEEN 9001 and 9086) -- E-Sports 2.0	
						)
					AND (b.bettype < 901 OR b.bettype > 904)
					AND (b.bettype < 911 OR b.bettype > 914)
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
								OR b.bettype BETWEEN 9001 AND 9086	-- Esport 2
								OR b.bettype BETWEEN 81 AND 88
								OR b.bettype BETWEEN 90 AND 120
								OR b.bettype IN (157,178,183,184,194,197,198,203,204,205) -- add more bettype BetRadar 
								OR b.bettype BETWEEN 401 AND 404 -- add more PH-AIO new bettypes
								OR b.bettype = 428 -- 2H Odd/Even
								OR b.bettype IN (467,468,469) -- PH-AIO new bettypes (phase 4a)
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
								OR b.bettype BETWEEN 9001 AND 9086	-- Esport 2
								OR b.bettype BETWEEN 81 AND 88
								OR b.bettype BETWEEN 90 AND 120
								OR b.bettype IN (157,178,183,184,194,197,198,203,204,205) -- add more bettype BetRadar 
								OR b.bettype BETWEEN 401 AND 404 -- add more PH-AIO new bettypes
								OR b.bettype = 428 -- 2H Odd/Even  
								OR b.bettype IN (467,468,469) -- PH-AIO new bettypes (phase 4a)
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
					,0 AS AmountDueToBA
					,0 AS CommBA
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
						b.bettype <= 30
						OR (b.bettype BETWEEN 121 AND 999)	
						OR (b.Bettype BETWEEN 1301 and 1399) --new tennis's bettypes
						OR (b.Bettype BETWEEN 9001 and 9086) -- E-Sports 2.0			
						)
					AND (b.bettype < 901 OR b.bettype > 904)
					AND (b.bettype < 911 OR b.bettype > 914)
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
								OR b.bettype BETWEEN 9001 AND 9086	-- Esport 2
								OR b.bettype BETWEEN 81 AND 88
								OR b.bettype BETWEEN 90 AND 120
								OR b.bettype IN (157,178,183,184,194,197,198,203,204,205) -- add more bettype BetRadar 
								OR b.bettype BETWEEN 401 AND 404 -- add more PH-AIO new bettypes
								OR b.bettype = 428 -- 2H Odd/Even  
								OR b.bettype IN (467,468,469) -- PH-AIO new bettypes (phase 4a)
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
								OR b.bettype BETWEEN 9001 AND 9086	-- Esport 2
								OR b.bettype BETWEEN 81 AND 88
								OR b.bettype BETWEEN 90 AND 120
								OR b.bettype IN (157,178,183,184,194,197,198,203,204,205) -- add more bettype BetRadar 
								OR b.bettype BETWEEN 401 AND 404 -- add more PH-AIO new bettypes
								OR b.bettype = 428 -- 2H Odd/Even  
								OR b.bettype IN (467,468,469) -- PH-AIO new bettypes (phase 4a)
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
					,-sum(Winlost + awinlost + comm) AS AmountDueToBA
					,sum(comm) AS CommBA
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
						b.bettype <= 30
						OR (b.bettype BETWEEN 121 AND 999)			
						OR (b.Bettype BETWEEN 1301 and 1399) --new tennis's bettypes
						OR (b.Bettype BETWEEN 9001 and 9086) -- E-Sports 2.0		
						)
					AND (b.bettype < 901 OR b.bettype > 904)
					AND (b.bettype < 911 OR b.bettype > 914)
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
								OR b.bettype BETWEEN 9001 AND 9086	-- Esport 2
								OR b.bettype BETWEEN 81 AND 88
								OR b.bettype BETWEEN 90 AND 120
								OR b.bettype IN (157,178,183,184,194,197,198,203,204,205) -- add more bettype BetRadar 
								OR b.bettype BETWEEN 401 AND 404 -- add more PH-AIO new bettypes
								OR b.bettype = 428 -- 2H Odd/Even  
								OR b.bettype IN (467,468,469) -- PH-AIO new bettypes (phase 4a)
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
								OR b.bettype BETWEEN 9001 AND 9086	-- Esport 2
								OR b.bettype BETWEEN 81 AND 88
								OR b.bettype BETWEEN 90 AND 120
								OR b.bettype IN (157,178,183,184,194,197,198,203,204,205) -- add more bettype BetRadar 
								OR b.bettype BETWEEN 401 AND 404 -- add more PH-AIO new bettypes
								OR b.bettype = 428 -- 2H Odd/Even  
								OR b.bettype IN (467,468,469) -- PH-AIO new bettypes (phase 4a)
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
					,0 AS AmountDueToBA
					,0 AS CommBA
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
						b.bettype <= 30
						OR (b.bettype BETWEEN 121 AND 999)	
						OR (b.Bettype BETWEEN 1301 and 1399) --new tennis's bettypes
						OR (b.Bettype BETWEEN 9001 and 9086) -- E-Sports 2.0	
						)
					AND (b.bettype < 901 OR b.bettype > 904)
					AND (b.bettype < 911 OR b.bettype > 914)
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
								OR b.bettype BETWEEN 9001 AND 9086	-- Esport 2
								OR b.bettype BETWEEN 81 AND 88
								OR b.bettype BETWEEN 90 AND 120
								OR b.bettype IN (157,178,183,184,194,197,198,203,204,205) -- add more bettype BetRadar 
								OR b.bettype BETWEEN 401 AND 404 -- add more PH-AIO new bettypes
								OR b.bettype = 428 -- 2H Odd/Even  
								OR b.bettype IN (467,468,469) -- PH-AIO new bettypes (phase 4a)
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
	INSERT INTO @ExchangeDaily(FromDate, ToDate, ExchangeId, Rate)
	SELECT FromDate, ToDate, ExchangeID, Rate
	FROM dbo.Lrf_f_GetExchangeRate(@fromDate, @toDate, @BaseCurrency, '') e
	WHERE EXISTS (SELECT 1 FROM @TempAg a WHERE a.Currency = e.ExchangeID)

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
		, 0 AS bettype
		--,ProductName
		,--bettype,  
		leagueid
		,CAST(SUM(turnover * e.Rate) AS MONEY) AS turnover

		,CAST(SUM(MemberWinLost * e.Rate) AS MONEY) AS MemberWinLost

		,CAST(SUM(LicenseeWL * e.Rate) AS MONEY) AS LicenseeWL

		,CAST(SUM(CommBA * e.Rate) AS MONEY) AS CommBA

		,CAST(SUM(PlayerComm * e.Rate) AS MONEY) AS PlayerComm

		,CAST(SUM((AmtDuetoBA) * e.Rate) AS MONEY) AS AmtDuetoBA
		,CASE 
			WHEN b.sporttype IN (181, 182, 184)
				THEN ''
			ELSE matchcode
			END matchcode
		,isNeutral
		,b.sporttype
		,'' AS showtime
		,sum(b.betcount) betcount
	--,odds2
	FROM @AgMatchWLDetails b
	--INNER JOIN (SELECT *  FROM Lrf_f_GetExchangeDaily(@_FromDate,@_ToDate))e   
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
	
	DROP TABLE #match
END
GO
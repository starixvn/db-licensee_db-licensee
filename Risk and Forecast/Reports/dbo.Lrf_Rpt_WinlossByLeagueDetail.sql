/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_WinlossByLeagueDetail]
	@Odds FLOAT = 0
	,@LeagueID INT
	,@MatchID INT =0
	,@PageSize INT = 1000
	,@PageIndex INT = 1
	,@TotalRows INT = 0 OUTPUT
	,@FromDate SMALLDATETIME
	,@ToDate SMALLDATETIME
	,@MoveBetsDay SMALLDATETIME
	,@ShowWin BIT = 1
	,@ShowLoss BIT = 1
	,@ShowDraw BIT = 1
	,@ShowSB BIT = 1
	,@ShowBA BIT = 1
	,@AgentList		VARCHAR(MAX)
	,@BaseCurrency	VARCHAR(3) = ''
AS

/*
	Created: 20140102@Florent
	DB: DBEXT.bodb02

	Revisions:
		- 20140207@Florent: Add filter ShowBA and ShowSB
		- 20140214@Florent: use new sum table rptCustomerMatch
		- 20140620@Florent: offer 14 new bettypes and Sporting Solution (36 new bettypes)
		- 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
		- 20150127@Jim: support base on GBP Currency
		- 20150623@Winnie: exclude 3 transactions SOLD/BOUGHT/BetTrade Commission
		- 20151127@Bobby: #48081 - Apply PH-AIO new bettypes
		- 20151203@Bobby: Database - Change datatype [Redmine: #48660]
		- 20160727@Jim:  LRF - Commercial terms changed for Bet Trade [Redmine: #61342]
		- 20170228@Paul: Get @AgentList by web instead of @UserId, @CurrencyID, @LicenseeID [Redmine: #71679]
		- 20170328@Paul: Implement Cash Out [RedmineID :#71727]
		- 20180808@Amanda: Remove bet type related to Racing [RedmineID: #99378]
		- 20181019@Amanda: Add new bet types for E-Sports 2.0 [RedmineID: #100721]
		- 20190620@Amanda: Add Base currency param [RedmineID: #112531]
		- 20190407@Amanda: Add new bet types (PH AIO - Phase 4a) [RedmineID: #115448]
		- 20191608@Amanda: Add new bet types (PH AIO - Phase 4b) [RedmineID: #118300]
		- 20191118@Amanda: Add new bet types (BM AIO - Phase 2) [RedmineID: #120336]
		- 20190102@Vickie: Add new bet types (PH AIO - Phase 5) [RedmineID: #126005]
		- 20200508@Vickie: Add new bet types for E-Sports 2.0 [RedmineID: #132548]
		- 20201023@Hogan: Integrate new bet type Time Machine OU [RedmineID: #142692]
		- 20201027@Kos: Change to use new table to check performance [RedmineID: #143310]
		- 20201028@Louis: Licensee Spread Setting [RedmineID: #142532]	
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @TempFromDate SMALLDATETIME
	DECLARE @TempToDate SMALLDATETIME
	DECLARE @ExchangeDaily TABLE (
		FromDate SMALLDATETIME
		,ToDate SMALLDATETIME
		,ExchangeId INT
		,Rate FLOAT
		)

	DECLARE @Today SMALLDATETIME

	SELECT @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120)

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
	-----------------------------------    

	-----------------------------------
	DECLARE @AgMatchWLDetails TABLE (
		custid INT
		,Winlostdate SMALLDATETIME
		,Currency INT
		,odds MONEY
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
	
	DECLARE @ExcludedBetType TABLE (ProductId TINYINT, BetType INT)
	-- Insert Excluded BetType
	INSERT INTO @ExcludedBetType (ProductId, BetType)
	SELECT ProductId, BetType FROM Lrf_f_SelExcludedBetType()

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
					WHEN (b.bettype IN (1,2,3,7,12,8,20,21,1301,1303,1305,1306,1308,1311,1312,1316,1318,1324,153,154,155,156,228)	 -- add more Sportting Solution bettype 
						OR b.bettype BETWEEN 9001 AND 9087	-- Esport 2
						OR b.bettype BETWEEN 81 AND 88
						OR b.bettype BETWEEN 90 AND 120
						OR b.bettype IN (157,178,183,184,194,197,198,203,204,205) -- add more bettype BetRadar 
						OR b.bettype BETWEEN 401 AND 404 -- add more PH-AIO new bettypes
						OR b.bettype IN (467,468,469) -- PH-AIO new bettypes (phase 4a)
						OR b.bettype IN (470,471,472,479,481,488,489,490,491,492) -- PH-AIO new bettypes (phase 4b)
						OR (b.bettype NOT IN (703, 711) AND b.bettype BETWEEN 701 AND 714) -- BM-AIO new bettypes (phase 2)
						OR b.bettype IN (381,382,386,387,388,389,390,393,394,400) -- PH-AIO new bettypes (phase 5)
						)
						THEN CASE 
								WHEN b.OddsType = 1 THEN b.odds + 1 --decimal
								WHEN b.OddsType = 2 THEN b.Odds + 1 --hongkong to decimal
								WHEN b.OddsType IN (3, 4, 7)
									THEN --malay and indo and new oddstype to decimal
										CASE 
											WHEN b.odds < 0 THEN (1 - CAST(1 AS FLOAT) / CAST(b.odds AS FLOAT))
											WHEN b.odds >= 0 THEN (1 + b.odds)
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
					END odds
				,0 sporttype
				,m.leagueid
				,SUM(stake)
				,SUM(winlost - b.actual_stake)
				,0 AS LicenseeWL
				, - SUM(winlost - b.actual_stake + awinlost + comm)AS AmountDueToBA
				,SUM(comm) AS CommBA
				,SUM(b.playercomm) AS PlayerComm
				,m.matchcode
				,ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral
				,b.liveindicator AS liveindicator
				,COUNT(1) betcount
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN match m WITH (NOLOCK) ON m.matchid = b.matchid
				INNER JOIN #TempAg ta ON b.recommend = ta.CustId AND b.Currency = ta.Currency
			WHERE (--SportBook
					b.bettype <= 30
					OR (b.bettype BETWEEN 121 AND 999)
					OR (b.Bettype BETWEEN 1301 AND 1399) --new tennis's bettypes
					OR (b.Bettype BETWEEN 9001 AND 9399) -- E-Sports
					)
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
				AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.BetType = b.BetType)
				AND b.winlostdate BETWEEN @TempFromDate AND @todate
				AND b.statusID IN (
					SELECT *
					FROM @status
					)
				AND m.leagueid = @LeagueID
				AND b.tpositiontaking=0 --GetBA
				AND (@matchid=0 or b.matchid = @MatchID)
			GROUP BY b.custid
				,b.Winlostdate
				,b.currency
				,m.leagueid
				,m.matchcode
				,m.isNeutral
				,b.liveindicator
				,b.tpositiontaking
				,CASE 
					WHEN (b.bettype IN (1,2,3,7,12,8,20,21,1301,1303,1305,1306,1308,1311,1312,1316,1318,1324,153,154,155,156,228)	 -- add more Sportting Solution bettype 
								OR b.bettype BETWEEN 9001 AND 9087	-- Esport 2
								OR b.bettype BETWEEN 81 AND 88
								OR b.bettype BETWEEN 90 AND 120
								OR b.bettype IN (157,178,183,184,194,197,198,203,204,205) -- add more bettype BetRadar 
								OR b.bettype BETWEEN 401 AND 404 -- add more PH-AIO new bettypes
								OR b.bettype IN (467,468,469) -- PH-AIO new bettypes (phase 4a)
								OR b.bettype IN (470,471,472,479,481,488,489,490,491,492) -- PH-AIO new bettypes (phase 4b)
								OR (b.bettype NOT IN (703, 711) AND b.bettype BETWEEN 701 AND 714) -- BM-AIO new bettypes (phase 2)
								OR b.bettype IN (381,382,386,387,388,389,390,393,394,400) -- PH-AIO new bettypes (phase 5)
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
			ORDER BY b.winlostdate DESC
		END

		IF @ShowSB = 1
		BEGIN
			INSERT INTO @AgMatchWLDetails
			SELECT b.custid
				,b.Winlostdate
				,b.currency
				,CASE 
					WHEN (b.bettype IN (1,2,3,7,12,8,20,21,1301,1303,1305,1306,1308,1311,1312,1316,1318,1324,153,154,155,156,228)	 -- add more Sportting Solution bettype 
								OR b.bettype BETWEEN 9001 AND 9087	-- Esport 2
								OR b.bettype BETWEEN 81 AND 88
								OR b.bettype BETWEEN 90 AND 120
								OR b.bettype IN (157,178,183,184,194,197,198,203,204,205) -- add more bettype BetRadar 
								OR b.bettype BETWEEN 401 AND 404 -- add more PH-AIO new bettypes
								OR b.bettype IN (467,468,469) -- PH-AIO new bettypes (phase 4a)
								OR b.bettype IN (470,471,472,479,481,488,489,490,491,492) -- PH-AIO new bettypes (phase 4b)
								OR (b.bettype NOT IN (703, 711) AND b.bettype BETWEEN 701 AND 714) -- BM-AIO new bettypes (phase 2)
								OR b.bettype IN (381,382,386,387,388,389,390,393,394,400) -- PH-AIO new bettypes (phase 5)
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
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN match m WITH (NOLOCK) ON m.matchid = b.matchid
				INNER JOIN #TempAg ta ON b.recommend = ta.CustId AND b.Currency = ta.Currency
			WHERE (
					b.bettype <= 30
					OR (b.bettype BETWEEN 121 AND 999)
					OR (b.Bettype BETWEEN 1301 AND 1399) --new tennis's bettypes
					OR (b.Bettype BETWEEN 9001 AND 9399) -- E-Sports
					)
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
				AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.ProductId = 0 AND e.BetType = b.BetType)
				AND b.winlostdate BETWEEN @TempFromDate AND @todate
				AND b.statusID IN (SELECT * FROM @status)
				AND m.leagueid = @LeagueID
				AND b.tpositiontaking <> 0  
				AND (@matchid = 0 or b.matchid = @MatchID)
			GROUP BY b.custid
				,b.Winlostdate
				,b.currency
				,m.leagueid
				,m.matchcode
				,m.isNeutral
				,b.liveindicator
				,b.tpositiontaking
				,CASE 
					WHEN (b.bettype IN (1,2,3,7,12,8,20,21,1301,1303,1305,1306,1308,1311,1312,1316,1318,1324,153,154,155,156,228)	 -- add more Sportting Solution bettype 
								OR b.bettype BETWEEN 9001 AND 9087	-- Esport 2
								OR b.bettype BETWEEN 81 AND 88
								OR b.bettype BETWEEN 90 AND 120
								OR b.bettype IN (157,178,183,184,194,197,198,203,204,205) -- add more bettype BetRadar 
								OR b.bettype BETWEEN 401 AND 404 -- add more PH-AIO new bettypes
								OR b.bettype IN (467,468,469) -- PH-AIO new bettypes (phase 4a)
								OR b.bettype IN (470,471,472,479,481,488,489,490,491,492) -- PH-AIO new bettypes (phase 4b)
								OR (b.bettype NOT IN (703, 711) AND b.bettype BETWEEN 701 AND 714) -- BM-AIO new bettypes (phase 2)
								OR b.bettype IN (381,382,386,387,388,389,390,393,394,400) -- PH-AIO new bettypes (phase 5)
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
			ORDER BY b.winlostdate DESC
		END
	END

	IF @Fromdate <= @MoveBetsDay
	BEGIN
		IF @ToDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @ToDate

		CREATE TABLE #Date (Date SMALLDATETIME, PRIMARY KEY(Date))

		INSERT INTO #Date
		SELECT [Date]
		FROM f_GetDateBetweenTwoDates (@fromdate, @TempToDate)

		--Get general data
		BEGIN
			IF @ShowBA = 1
			BEGIN
				INSERT INTO @AgMatchWLDetails
				SELECT b.*
				FROM #Date AS d
					CROSS APPLY (
						SELECT b.custid
							,b.Winlostdate
							,ta.currency
							,CASE 
						WHEN (b.bettype IN (1,2,3,7,12,8,20,21,1301,1303,1305,1306,1308,1311,1312,1316,1318,1324,153,154,155,156,228)	 -- add more Sportting Solution bettype 
										OR b.bettype BETWEEN 9001 AND 9087	-- Esport 2
										OR b.bettype BETWEEN 81 AND 88
										OR b.bettype BETWEEN 90 AND 120
										OR b.bettype IN (157,178,183,184,194,197,198,203,204,205) -- add more bettype BetRadar 
										OR b.bettype BETWEEN 401 AND 404 -- add more PH-AIO new bettypes
										OR b.bettype IN (467,468,469) -- PH-AIO new bettypes (phase 4a)
										OR b.bettype IN (470,471,472,479,481,488,489,490,491,492) -- PH-AIO new bettypes (phase 4b)
										OR (b.bettype NOT IN (703, 711) AND b.bettype BETWEEN 701 AND 714) -- BM-AIO new bettypes (phase 2)
										OR b.bettype IN (381,382,386,387,388,389,390,393,394,400) -- PH-AIO new bettypes (phase 5)
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
								END odds
							,0 AS sporttype
							,@LeagueID leagueid
							,SUM(b.stake) AS Stake
							,SUM(b.winlost) AS WinLost
							,0 AS LicenseeWL
							,-SUM(Winlost +  awinlost + comm) AS AmountDueToBA
							,SUM(comm) AS CommBA
							,0 PlayerComm
							,0 matchcode
							,0 AS IsNeutral
							,0 AS liveindicator
							,SUM(b.betcount) betcount
						FROM bodb_LicenseeReport.dbo.rptCustomerMatch AS b WITH (NOLOCK)
							INNER JOIN #TempAg ta ON b.recommend = ta.CustId AND b.Currency = ta.Currency
						WHERE b.winlostdate = d.Date
							AND (
								b.bettype <= 30
								OR (b.bettype BETWEEN 121 AND 999)
								OR (b.Bettype BETWEEN 1301 AND 1399) --new tennis's bettypes
								OR (b.Bettype BETWEEN 9001 AND 9399) -- E-Sports
								)
							AND (b.bettype < 901 OR b.bettype > 904)
							AND (b.bettype < 911 OR b.bettype > 914)
					AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.BetType = b.BetType)
							AND (@matchid=0 or b.matchid = @MatchID)
							AND b.statusID IN (SELECT * FROM @status)
							And b.isBA = 1
							AND b.leagueid = @leagueid
						GROUP BY b.custid
							,b.Winlostdate
							,ta.Currency
							,b.isBA
							,CASE 
						WHEN (b.bettype IN (1,2,3,7,12,8,20,21,1301,1303,1305,1306,1308,1311,1312,1316,1318,1324,153,154,155,156,228)	 -- add more Sportting Solution bettype 
										OR b.bettype BETWEEN 9001 AND 9087	-- Esport 2
										OR b.bettype BETWEEN 81 AND 88
										OR b.bettype BETWEEN 90 AND 120
										OR b.bettype IN (157,178,183,184,194,197,198,203,204,205) -- add more bettype BetRadar 
										OR b.bettype BETWEEN 401 AND 404 -- add more PH-AIO new bettypes
										OR b.bettype IN (467,468,469) -- PH-AIO new bettypes (phase 4a)
										OR b.bettype IN (470,471,472,479,481,488,489,490,491,492) -- PH-AIO new bettypes (phase 4b)
										OR (b.bettype NOT IN (703, 711) AND b.bettype BETWEEN 701 AND 714) -- BM-AIO new bettypes (phase 2)
										OR b.bettype IN (381,382,386,387,388,389,390,393,394,400) -- PH-AIO new bettypes (phase 5)
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
						SELECT b.custid
							,b.Winlostdate
							,ta.currency
							,CASE 
						WHEN (b.bettype IN (1,2,3,7,12,8,20,21,1301,1303,1305,1306,1308,1311,1312,1316,1318,1324,153,154,155,156,228)	 -- add more Sportting Solution bettype 
										OR b.bettype BETWEEN 9001 AND 9087	-- Esport 2
										OR b.bettype BETWEEN 81 AND 88
										OR b.bettype BETWEEN 90 AND 120
										OR b.bettype IN (157,178,183,184,194,197,198,203,204,205) -- add more bettype BetRadar 
										OR b.bettype BETWEEN 401 AND 404 -- add more PH-AIO new bettypes
										OR b.bettype IN (467,468,469) -- PH-AIO new bettypes (phase 4a)
										OR b.bettype IN (470,471,472,479,481,488,489,490,491,492) -- PH-AIO new bettypes (phase 4b)
										OR (b.bettype NOT IN (703, 711) AND b.bettype BETWEEN 701 AND 714) -- BM-AIO new bettypes (phase 2)
										OR b.bettype IN (381,382,386,387,388,389,390,393,394,400) -- PH-AIO new bettypes (phase 5)
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
								END odds
							,0 AS sporttype
							,@LeagueID leagueid
							,SUM(b.stake) AS Stake
							,SUM(b.winlost) AS WinLost
							,- SUM(b.winlost) AS LicenseeWL
							,0 AmountDueToBA
							,0 AS CommBA
							,0 AS PlayerComm
							,0 matchcode
							,0 AS IsNeutral
							,0 AS liveindicator
							,SUM(b.betcount) betcount
						FROM bodb_LicenseeReport.dbo.rptCustomerMatch b WITH (NOLOCK)
							INNER JOIN #TempAg ta ON b.recommend = ta.CustId AND b.Currency = ta.Currency
						WHERE b.winlostdate = d.Date
							AND (
								b.bettype <= 30
								OR (b.bettype BETWEEN 121 AND 999)
								OR (b.Bettype BETWEEN 1301 AND 1399) --new tennis's bettypes
								OR (b.Bettype BETWEEN 9001 AND 9399) -- E-Sports
								)
							AND (b.bettype < 901 OR b.bettype > 904)
							AND (b.bettype < 911 OR b.bettype > 914)
					AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.ProductId = 0 AND e.BetType = b.BetType)
							AND (@matchid = 0 or b.matchid = @MatchID)
							AND b.statusID IN (
								SELECT *
								FROM @status
								)
							AND b.isBA = 0
							AND b.leagueid = @leagueid
						GROUP BY b.custid
							,b.Winlostdate
							,ta.currency
							,b.isBA
							,CASE 
								WHEN (b.bettype IN (1,2,3,7,12,8,20,21,1301,1303,1305,1306,1308,1311,1312,1316,1318,1324,153,154,155,156,228)	 -- add more Sportting Solution bettype 
										OR b.bettype BETWEEN 9001 AND 9087	-- Esport 2
										OR b.bettype BETWEEN 81 AND 88
										OR b.bettype BETWEEN 90 AND 120
										OR b.bettype IN (157,178,183,184,194,197,198,203,204,205) -- add more bettype BetRadar 
										OR b.bettype BETWEEN 401 AND 404 -- add more PH-AIO new bettypes
										OR b.bettype IN (467,468,469) -- PH-AIO new bettypes (phase 4a)
										OR b.bettype IN (470,471,472,479,481,488,489,490,491,492) -- PH-AIO new bettypes (phase 4b)
										OR (b.bettype NOT IN (703, 711) AND b.bettype BETWEEN 701 AND 714) -- BM-AIO new bettypes (phase 2)
										OR b.bettype IN (381,382,386,387,388,389,390,393,394,400) -- PH-AIO new bettypes (phase 5)
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
	FROM dbo.Lrf_f_GetExchangeRate(@fromDate, @ToDate, @BaseCurrency, '') e
	WHERE EXISTS (SELECT 1 FROM #TempAg a WHERE a.Currency = e.ExchangeID)

	DECLARE @RowStart INT
		,@RowEnd INT

	SELECT @PageIndex = @PageIndex - 1
		,@RowStart = @PageSize * @PageIndex + 1
		,@RowEnd = @RowStart + @PageSize - 1

	SELECT @TotalRows = count(a.custid)
	FROM (
		SELECT custid
		FROM @AgMatchWLDetails
		WHERE odds >= @odds
		GROUP BY custid
			,sporttype
			,leagueid
		) A

	SELECT A.*
	FROM (
		SELECT ROW_NUMBER() OVER (
				ORDER BY b.custid
					,c.username
					,SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, len(c.username2) - CHARINDEX('$', c.username2))
					,b.sporttype
					,b.leagueid
				) AS RowNum
			,b.custid
			,c.username
			,SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, len(c.username2) - CHARINDEX('$', c.username2)) AS nickname
			,b.sporttype
			,b.leagueid
			,CAST(SUM(turnover * e.Rate) AS MONEY) AS turnover
			,CAST(SUM(MemberWinLost * e.Rate) AS MONEY) AS MemberWinLost
			,CAST(SUM(LicenseeWL * e.Rate) AS MONEY) AS LicenseeWL
			,CAST(SUM(CommBA * e.Rate) AS MONEY) AS CommBA
			,CAST(SUM(PlayerComm * e.Rate) AS MONEY) AS PlayerComm
			,CAST(SUM((AmtDuetoBA) * e.Rate) AS MONEY) AS AmtDuetoBA
			,SUM(b.betcount) betcount
		FROM @AgMatchWLDetails b
			INNER JOIN dbo.Customer c WITH (NOLOCK) ON b.custid = c.custid
			INNER JOIN @ExchangeDaily e ON b.winlostdate BETWEEN e.FromDate AND e.ToDate
				AND b.currency = e.ExchangeId
		WHERE b.odds >= @odds
		GROUP BY b.custid
			,c.username
			,SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, len(c.username2) - CHARINDEX('$', c.username2))
			,b.sporttype
			,b.leagueid
		) A
	WHERE A.RowNum BETWEEN @RowStart AND @RowEnd

	SELECT
		CAST(SUM(b.turnover * e.Rate) AS MONEY) AS turnover
		,CAST(SUM(b.MemberWinLost * e.Rate) AS MONEY) AS MemberWinLost
		,CAST(SUM(b.LicenseeWL * e.Rate) AS MONEY) AS LicenseeWL
		,CAST(SUM(b.CommBA * e.Rate) AS MONEY) AS CommBA
		,CAST(SUM(b.PlayerComm * e.Rate) AS MONEY) AS PlayerComm
		,CAST(SUM((b.AmtDueToBA) * e.Rate) AS MONEY) AS AmtDuetoBA
		,SUM(b.betcount) betcount
	FROM @AgMatchWLDetails b
		INNER JOIN dbo.Customer c WITH (NOLOCK) ON b.custid = c.custid
		INNER JOIN @ExchangeDaily e ON b.winlostdate BETWEEN e.FromDate AND e.ToDate
			AND b.currency = e.ExchangeId
	WHERE b.odds >= @odds

	DROP TABLE #TempAg
END
GO
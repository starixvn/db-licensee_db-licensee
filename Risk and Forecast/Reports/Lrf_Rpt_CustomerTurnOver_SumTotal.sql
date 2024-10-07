/*<info serverAlias="DBEXT-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="1"></info>*/

ALTER PROCEDURE  [dbo].[Lrf_Rpt_CustomerTurnOver_SumTotal]
	@SearchCust		BIT				= 0,
	@FromDate		SMALLDATETIME,
	@tempFromDate	SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@tempToDate		SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@Odds			FLOAT,
	@ReportBy		TINYINT			= 1
AS

/*
	Created: 20150603@Bobby
	Task: Customer Performance Report
	DB: DBEXT/BODB02
	Revision:
		- 20151127@Bobby: #48081 - Apply PH-AIO new bettypes
		- 20151223@Jim: Add "Effective Betting Value" in Customer Turnover report [Redmine: #45736]
		- 20160720@Jim : Implement 67 new bet types (PH All in one - Phase 2) [Redmine : #53520]
		- 20171006@Percy: Hotfix - Add missing mutilple odds bettypes [RedmineID: #84457]
			1. Basketball (603-607, 609-613, 615-617)
			2. Virtual Sports 2 (2701-2707)
		- 20180409@Joseph: Implement new sports for VS2: BasketBall - Virual Soccer World Cup [Redmine: #90881]
		- 20180810@Joseph: Remove table LicenseeCustInfo [RedmineID: #99464]
		- 20180810@Paul: Enhance performance [Redmine: #98260]
		- 20181219@Joseph: Add new bet types for E-Sports 2.0 for report Customer Turnover [RedmineID: #106666]
		- 20181210@Joseph: Integrate Happy 5 for NumberGame [RedmineID: #103698]
		- 20190407@Amanda: Add new bet types (PH AIO - Phase 4a) [RedmineID: #115448]
		- 20191608@Amanda: Add new bet types (PH AIO - Phase 4b) [RedmineID: #118300]
		- 20191129@Walter: Add new bet types (BMAIO - Phase 2) [RedmineID: #120336]
		- 20190102@Vickie: Add new bet types (PH AIO - Phase 5) [RedmineID: #126005]
		- 20200508@Vickie: Add new bet types for E-Sports 2.0 [RedmineID: #132548] 
		- 20201023@Hogan: Integrate new bet type Time Machine OU [RedmineID: #142692]
		- 20201027@Louis: Licensee Spread Setting [RedmineID: #142532]
		- 20210119@Hogan: Integrate Four Guardians [RedmineID: #148100]
		- 20210304@Hogan: Offer Decimal Odds Only for Match [RedmineID: #151010]
		- 20210420@Mark: Integrate Time Machine HDP [Redmine: #153302]
		- 20220224@Hogan: Integrate Virtual Sports 3 (Leap Gaming)[RedmineID: #145337]
		- 20220322@Kos: Support Parlay sport [RedmineID: #169282]
		- 20220714@Hogan: Integrate Volleyball AIO [RedmineID: #175143]
		- 20241701@Evan: Remove VS3 (old) [RedmineID: #199523]
		- 20242901@Evan: Integrate VS4 [RedmineID: #199347]
		- 20241001@Kelvin: LAP - Integrate BetRadar Virtual Horses & Dogs Racing [RedmineID: #210808]
*/

BEGIN
	SET NOCOUNT ON;
 
	DECLARE @ExcludedBetType TABLE (ProductCode VARCHAR (10), BetType INT)
	-- Insert Excluded BetType
	INSERT INTO @ExcludedBetType (ProductCode, BetType)
	SELECT ProductCode, BetType FROM Lrf_f_SelExcludedBetType()

	--Set cut off date to convert  bettype 501
	DECLARE @501CutoffDate SMALLDATETIME = '2021-04-08'

	CREATE TABLE #tempSumData (
		sporttype		SMALLINT, 
		bettype			SMALLINT, 
		StatusID		TINYINT,
		betcount		INT,
		stake			MONEY,
		winlost			MONEY,
		BetEffective	MONEY,
		playercomm		MONEY,
		odds			MONEY
	)

	IF @searchCust = 1
	BEGIN
		IF @Todate > @MoveBetsDay
		BEGIN
			INSERT INTO #tempSumTotal
			SELECT 1				AS WhTicket
				, SUM(1)			AS betcount
				, SUM(stake)		AS turnover
				, SUM(winlost)		AS winlost
				, SUM(BetEffective) AS BetEffective
				, SUM(b.playercomm) AS playercomm
				, 0 AS totalrow
			FROM #tempBettrans b
		END

		IF @FromDate <= @MoveBetsDay
		BEGIN
			IF @odds = 0
			BEGIN
				INSERT INTO #tempSumData(
					sporttype,
					bettype,
					StatusID,
					betcount,
					stake,
					winlost,
					BetEffective,
					playercomm)
				SELECT
					sporttype,
					bettype,
					StatusID,
					SUM(b.betcount) AS betcount,
					SUM(b.stake) AS stake,
					SUM(b.winlost) AS winlost,
					SUM(b.BetEffective) AS BetEffective,
					SUM(b.playercomm) AS playercomm
				FROM (
					SELECT
						b.custid, 
						CASE
							WHEN b.bettype IN (9, 29, 38) THEN 999
							ELSE b.sporttype 
						END AS sporttype,
						b.bettype,
						b.statusid
						, SUM(b.betcount) AS betcount
						, SUM(b.stake) AS stake
						, SUM(b.winlost) AS winlost
						, SUM(b.BetEffective) AS BetEffective
						, SUM(b.playercomm) AS playercomm
					FROM #recommend AS rec
						JOIN bodb_LicenseeReport.dbo.rptcustomerturnOver AS b WITH (NOLOCK) ON b.Recommend = rec.CustID
					WHERE b.winlostdate BETWEEN @fromdate AND @tempToDate 
						AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.BetType = b.BetType)
					GROUP BY
						b.custid, 
						CASE
							WHEN b.bettype IN (9, 29, 38) THEN 999
							ELSE b.sporttype 
						END,
						b.bettype,
						b.statusid
					) b
					INNER JOIN #tempCust AS c WITH (NOLOCK) ON b.custid = c.custid
				GROUP BY
					sporttype,
					bettype,
					StatusID
				OPTION(RECOMPILE)

				INSERT INTO #tempSumTotal
				SELECT 2				AS WhTicket 
					, SUM(b.betcount)	AS betcount
					, SUM(b.stake) 		AS turnover
					, SUM(b.winlost)	AS winlost
					, SUM (b.BetEffective) AS BetEffective
					, SUM(b.playercomm) AS playercomm
					, 0 AS totalrow
				FROM #tempSumData AS b
					INNER JOIN #bettype AS bt ON b.bettype = bt.typeid
					INNER JOIN #Status AS st ON b.StatusID = st.StatusID
					INNER JOIN #ProductID AS p ON b.sporttype = p.sportID
			END 
			
			-- Has Odds Value
			IF @odds > 0
			BEGIN
				INSERT INTO #tempSumData (
					sporttype,
					bettype,
					StatusID,
					odds,
					betcount,
					stake,
					winlost,
					BetEffective,
					playercomm)
				SELECT
					b.sporttype,
					b.bettype,
					b.statusid,
					b.Odds
					, SUM(b.betcount)	AS betcount
					, SUM(b.stake) 		AS stake
					, SUM(b.winlost)  	AS winlost
					, SUM(b.BetEffective) AS BetEffective
					, SUM(b.playercomm) AS playercomm
				FROM (
					SELECT
						b.custid,
						CASE
							WHEN b.bettype IN (9, 29, 38) THEN 999
							ELSE b.sporttype 
						END AS sporttype,
						b.bettype,
						b.statusid
						, b.betcount	AS betcount
						, b.stake		AS stake
						, b.winlost  	AS winlost
						, b.BetEffective AS BetEffective
						, b.playercomm AS playercomm
						, CASE WHEN (b.bettype IN (1,2,3,7,12,8,20,21,1301,1303,1305,1306,1308,1311,1312,1316,1318,1324,153,154,155,156,228,229)	 -- add more Sportting Solution bettype 
									OR b.bettype BETWEEN 9001 AND 9087	-- Esport 2
									OR b.bettype BETWEEN 81 AND 88
									OR b.bettype BETWEEN 90 AND 120
									OR b.bettype BETWEEN 8101 AND 8120 -- Number Game: Happy 5
									OR b.bettype IN (157,178,183,184,194,197,198,203,204,205) -- add more bettype BetRadar 
									OR b.bettype BETWEEN 401 AND 404 -- add more PH-AIO new bettypes
									OR b.bettype = 428 -- 2H Odd/Even
									OR (b.bettype BETWEEN 603 AND 607 OR b.bettype BETWEEN 609 AND 613 OR b.bettype BETWEEN 615 AND 617) -- Basketball bettypes
									OR b.bettype BETWEEN 2701 AND 2707 -- Virtual Sport 2
									OR b.bettype BETWEEN 2770 AND 2789 -- Virtual Sport 2: Virtual Horses & Dogs Racing
									OR b.bettype BETWEEN 2800 AND 2829 -- Virtual Sport 2: basketball
									OR bettype BETWEEN 5302 AND 5399 -- Virtual Sport 3 (LG)
									OR b.bettype BETWEEN 10400 AND 10448 -- Virtual Sport 4
									OR bettype IN (467,468,469) -- PH-AIO new bettypes (phase 4a)
									OR bettype IN (470,471,472,479,481,488,489,490,491,492) -- PH-AIO new bettypes (phase 4b)
									OR (bettype NOT IN (703, 711) AND bettype BETWEEN 701 AND 714) -- BM-AIO new bettypes (phase 2)
									OR bettype IN (381,382,386,387,388,389,390,393,394,400) -- PH-AIO new bettypes (phase 5)
									OR bettype IN (219,220,3912,3914,3916,3918) -- Volleyball AIO
									OR bettype BETWEEN 3901 AND 3909 -- Volleyball AIO
									OR (b.bettype = 501 AND b.winlostdate < @501CutoffDate)
								)
								THEN 
										CASE WHEN b.OddsType = 1 THEN b.odds + 1 --decimal
												WHEN b.OddsType = 2 THEN b.Odds + 1 --hongkong to decimal
												WHEN b.OddsType IN (3,4,7) THEN --malay and indo and new oddstype to decimal
																	CASE 
																		WHEN b.odds < 0 THEN (1 -  cast(1 as float) / cast(b.odds AS float))
																		WHEN b.odds >=0 THEN (1 + b.odds) END
												WHEN OddsType = 5 THEN --american odds to decimal
																CASE
																WHEN (b.odds * 100) < 0 THEN (1- cast (1 AS float)/ cast (b.odds AS float))
																WHEN (b.odds * 100) % 2 = 0 THEN 2
																WHEN (b.odds * 100) > 0 THEN (1 + b.odds) END 
											END 
							ELSE b.Odds
						END AS Odds
					FROM #recommend AS rec
						JOIN bodb_LicenseeReport.dbo.rptcustomerturnOver AS b WITH(NOLOCK) ON b.Recommend = rec.CustID
					WHERE b.winlostdate BETWEEN @fromdate AND @tempToDate 
						AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.BetType = b.BetType)
					) b
					INNER JOIN #tempCust AS c WITH (NOLOCK) ON b.custid = c.custid
				GROUP BY
					b.sporttype,
					b.bettype,
					b.statusid,
					b.Odds
				OPTION(RECOMPILE)

				INSERT INTO #tempSumTotal
				SELECT 2				AS WhTicket 
					, SUM(b.betcount)	AS betcount
					, SUM(b.stake)		AS turnover
					, SUM(b.winlost)	AS winlost
					, SUM(b.BetEffective) AS BetEffective
					, SUM(b.playercomm) AS playercomm
					, 0 AS totalrow
				FROM #tempSumData AS b
					INNER JOIN #bettype AS bt ON b.bettype = bt.typeid
					INNER JOIN #Status AS st ON b.StatusID = st.StatusID
					INNER JOIN #ProductID AS p ON b.sporttype = p.sportID
				WHERE b.odds >= @odds
			END
		END
	END

	-- VIEW all member
	IF @searchCust = 0
	BEGIN		
		IF @Todate > @MoveBetsDay
		BEGIN
			INSERT INTO #tempSumTotal
			SELECT 1				AS WhTicket
				, SUM(1)			AS betcount
				, SUM(stake) 		AS turnover
				, SUM(winlost) 		AS winlost
				, SUM(BetEffective) AS BetEffective
				, SUM(b.playercomm) AS playercomm
				, 0 AS totalrow
			FROM #tempBettrans b
		END

		IF @FromDate <= @MoveBetsDay
		BEGIN
			IF @odds = 0
			BEGIN
				INSERT INTO #tempSumData(
					sporttype,
					bettype,
					StatusID
					, betcount
					, stake
					, winlost
					, BetEffective
					, playercomm)
				SELECT
					CASE
						WHEN b.bettype IN (9, 29, 38) THEN 999
						ELSE b.sporttype 
					END AS sporttype,
					b.bettype,
					b.statusid,
					SUM(b.betcount) AS betcount,
					SUM(b.stake) AS stake,
					SUM(b.winlost) AS winlost,
					SUM(b.BetEffective) AS BetEffective,
					SUM(b.playercomm) AS playercomm
				FROM #recommend AS rec
					JOIN bodb_LicenseeReport.dbo.rptcustomerturnOver AS b WITH(NOLOCK) ON b.Recommend = rec.CustID
				WHERE b.winlostdate BETWEEN @fromdate AND @tempToDate 
					AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.BetType = b.BetType)
				GROUP BY
					CASE
						WHEN b.bettype IN (9, 29, 38) THEN 999
						ELSE b.sporttype
					END,
					b.bettype,
					b.statusid
				OPTION(RECOMPILE)

				INSERT INTO #tempSumTotal
				SELECT 2				AS WhTicket 
					, SUM(b.betcount)	AS betcount
					, SUM(b.stake) 		AS turnover
					, SUM(b.winlost)  	AS winlost
					, SUM(b.BetEffective) AS BetEffective
					, SUM(b.playercomm) AS playercomm
					, 0 AS totalrow
				FROM #tempSumData AS b
					INNER JOIN #bettype AS bt ON b.bettype = bt.typeid
					INNER JOIN #Status AS st ON b.StatusID = st.StatusID
					INNER JOIN #ProductID AS p ON b.sporttype = p.sportID
			END
	
			-- Has Odds Value
			IF @odds > 0
			BEGIN
				INSERT INTO #tempSumData(
					sporttype,
					bettype,
					StatusID,
					odds
					, betcount
					, stake
					, winlost
					, BetEffective
					, playercomm)
				SELECT sporttype, bettype, StatusID, odds
					, SUM(b.betcount)	AS betcount
					, SUM(b.stake) 		AS stake
					, SUM(b.winlost)  	AS winlost
					, SUM(b.BetEffective) AS BetEffective
					, SUM(b.playercomm) AS playercomm
				FROM (
					SELECT
						CASE
							WHEN b.bettype IN (9, 29, 38) THEN 999
							ELSE b.sporttype 
						END AS sporttype,
						b.bettype,
						b.statusid
						, b.betcount	AS betcount
						, b.stake		AS stake
						, b.winlost  	AS winlost
						, b.BetEffective AS BetEffective
						, b.playercomm AS playercomm
						, CASE
							WHEN (b.bettype IN (1,2,3,7,12,8,20,21,1301,1303,1305,1306,1308,1311,1312,1316,1318,1324,153,154,155,156,228,229)	 -- add more Sportting Solution bettype 
							OR b.bettype BETWEEN 9001 AND 9087	-- Esport 2
							OR b.bettype BETWEEN 81 AND 88
							OR b.bettype BETWEEN 90 AND 120
							OR b.bettype BETWEEN 8101 AND 8120 -- Number Game: Happy 5
							OR b.bettype IN (157,178,183,184,194,197,198,203,204,205) -- add more bettype BetRadar 
							OR b.bettype BETWEEN 401 AND 404 -- add more PH-AIO new bettypes
							OR b.bettype = 428 -- 2H Odd/Even
							OR (b.bettype BETWEEN 603 AND 607 OR b.bettype BETWEEN 609 AND 613 OR b.bettype BETWEEN 615 AND 617) -- Basketball bettypes
							OR b.bettype BETWEEN 2701 AND 2707 -- Virtual Sport 2
							OR b.bettype BETWEEN 2770 AND 2789 -- Virtual Sport 2: Virtual Horses & Dogs Racing
							OR b.bettype BETWEEN 2800 AND 2829 -- Virtual Sport 2: basketball
							OR bettype BETWEEN 5302 AND 5399 -- Virtual Sport 3 (LG)
							OR b.bettype BETWEEN 10400 AND 10448 -- Virtual Sport 4
							OR bettype IN (467,468,469) -- PH-AIO new bettypes (phase 4a)
							OR bettype IN (470,471,472,479,481,488,489,490,491,492) -- PH-AIO new bettypes (phase 4b)
							OR (bettype NOT IN (703, 711) AND bettype BETWEEN 701 AND 714) -- BM-AIO new bettypes (phase 2)
							OR bettype IN (381,382,386,387,388,389,390,393,394,400) -- PH-AIO new bettypes (phase 5)
							OR b.bettype IN (219,220,3912,3914,3916,3918) -- Volleyball AIO
							OR b.bettype BETWEEN 3901 AND 3909 -- Volleyball AIO
							OR (b.bettype = 501 AND b.winlostdate < @501CutoffDate)
						)
								THEN
									CASE
										WHEN b.OddsType = 1 THEN b.odds + 1 --decimal
										WHEN b.OddsType = 2 THEN b.Odds + 1 --hongkong to decimal
										WHEN b.OddsType IN (3,4,7) THEN --malay and indo and new oddstype to decimal
															CASE 
																WHEN b.odds < 0 THEN (1 -  cast(1 as float) / cast(b.odds AS float))
																WHEN b.odds >=0 THEN (1 + b.odds) END
										WHEN OddsType = 5 THEN --american odds to decimal
														CASE
														WHEN (b.odds * 100) < 0 THEN (1- cast (1 AS float)/ cast (b.odds AS float))
														WHEN (b.odds * 100) % 2 = 0 THEN 2
														WHEN (b.odds * 100) > 0 THEN (1 + b.odds) END 
									END
							ELSE b.Odds
						END AS Odds
					FROM #recommend rec
						JOIN bodb_LicenseeReport.dbo.rptcustomerturnOver b WITH(NOLOCK) ON b.Recommend = rec.CustID
					WHERE b.winlostdate BETWEEN @fromdate AND @tempToDate 
						AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.BetType = b.BetType)
					) b
				GROUP BY sporttype, bettype, StatusID, odds
				OPTION(RECOMPILE)

				INSERT INTO #tempSumTotal
				SELECT 2				AS WhTicket 
					, SUM(b.betcount)	AS betcount
					, SUM(b.stake) 		AS turnover
					, SUM(b.winlost)  	AS winlost
					, SUM(b.BetEffective) AS BetEffective
					, SUM(b.playercomm) AS playercomm
					, 0 AS totalrow
				FROM #tempSumData AS b
					INNER JOIN #bettype AS bt ON b.bettype =  bt.typeid
					INNER JOIN #Status AS st ON b.StatusID =  st.StatusID
					INNER JOIN #ProductID AS p ON b.sporttype = p.sportID
				WHERE b.odds >= @odds
			END
		END
	END
	RETURN;
END
GO

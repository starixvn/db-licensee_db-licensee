/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="1"></info>*/

ALTER PROCEDURE  [dbo].[Lrf_Rpt_CustomerTurnOver_Pagination]
(
	@searchCust 	BIT = 0
	,@FromDate 		SMALLDATETIME
	,@tempFromDate 	SMALLDATETIME
	,@ToDate 		SMALLDATETIME
	,@tempToDate 	SMALLDATETIME
	,@MoveBetsDay 	SMALLDATETIME
	,@Odds 			FLOAT
	,@ReportBy  	TINYINT   =  1
	,@PageSize 		INT
	,@PageIndex 	INT
	,@IsExportExcel BIT
	,@totalBettrans	INT = 0 OUTPUT
	,@totalSumRpt	INT = 0 OUTPUT
) 
AS

/*
	Created: 20150603@Bobby
	Task: Customer Performance Report
	DB: DBEXT.bodb02
	Revision:
		- 20151127@Bobby: #48081 - Apply PH-AIO new bettypes
		- 20160720@Jim : Implement 67 new bet types (PH All in one - Phase 2) [Redmine : #53520]
		- 20171006@Percy: Hotfix - Add missing mutilple odds bettypes [RedmineID: #84457]
			1. Basketball (603-607, 609-613, 615-617)
			2. Virtual Sports 2 (2701-2707)
		- 20180129@Percy: Hotfix page size, page index [RedmineID: #90104]
		- 20180409@Joseph: Implement new sports for VS2: BasketBall - Virual Soccer World Cup [Redmine: #90881]
		- 20180810@Joseph: Remove table LicenseeCustInfo [RedmineID: #99464]
		- 20180810@Paul: Enhance performance [Redmine: #98260]
		- 20181219@Joseph: Add new bet types for E-Sports 2.0 for report Customer Turnover [RedmineID: #106666]
		- 20181210@Joseph: Integrate Happy 5 for NumberGame [RedmineID: #103698]
		- 20190407@Amanda: Add new bet types (PH AIO - Phase 4a) [RedmineID: #115448]
		- 20191608@Amanda: Add new bet types (PH AIO - Phase 4b) [RedmineID: #118300]
		- 20191129@Walter: Add new bet types (BMAIO - Phase 2) [RedmineID: #120336]
		- 20190102@Vickie: Add new bet types (PH AIO - Phase 5) [RedmineID: #126005]
		- 20191225@Amanda: Support display SystemID [RedmineID: #123583]
		- 20200508@Vickie: Add new bet types for E-Sports 2.0 [RedmineID: #132548]

	Parameter's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @offsetRow INT, @maxRow INT, @topRow INT

	CREATE TABLE #tempData (
		sporttype		SMALLINT, 
		bettype			SMALLINT, 
		custid			INT, 
		username		VARCHAR(50),
		nickname		VARCHAR(50),
		StatusID		TINYINT,
		winlostdate		SMALLDATETIME
	)

	CREATE TABLE #tempPagingData 
	(
		RowIdx			INT IDENTITY(1, 1) PRIMARY KEY
		, winlostdate	SMALLDATETIME
		, custid		INT
		, username		VARCHAR(50)
		, nickname		VARCHAR(50)
	)

	SELECT
		@offsetRow = (((@PageIndex - 1) * @PageSize) + 1)
		,@maxRow = (@PageSize * @PageIndex)

	SET @topRow = (@maxRow - @offsetRow) + 1

	-- VIEW specific members
	IF( @searchCust = 1 )
	BEGIN
		IF @ToDate > @MoveBetsDay
		BEGIN
			INSERT INTO #tempPagingData(winlostdate, custid, username, nickname)
			SELECT b.winlostdate
					, c.Custid
					, c.username
					, c.nickname
			FROM #tempBettrans b	
				INNER JOIN #tempCust  c ON b.custid = c.custid
			GROUP BY 
				b.winlostdate
				, c.custid
				, c.username
				, c.nickname
			ORDER BY b.winlostdate DESC, nickname

			SET @totalBettrans = @@ROWCOUNT
		END
		
		IF @FromDate <= @MoveBetsDay
		BEGIN
			IF ( @odds = 0 )
			BEGIN
				INSERT INTO #tempData(winlostdate, sporttype, bettype, custid, username, nickname, StatusID)
				SELECT winlostdate, sporttype, bettype, b.custid, c.username, c.nickname, StatusID
				FROM (
					SELECT DISTINCT	winlostdate, 
							CASE WHEN b.bettype IN (9, 10, 29) THEN 1
								ELSE b.sporttype 
							END AS sporttype, bettype, b.custid, StatusID
					FROM #recommend rec
						JOIN bodb_LicenseeReport.dbo.rptcustomerturnOver b WITH(NOLOCK) ON b.Recommend	= rec.CustID
					WHERE b.winlostdate BETWEEN @fromdate AND @tempToDate
					) b
					INNER JOIN #tempCust c ON b.custid = c.custid
				OPTION(RECOMPILE)
			END

			-- Has Odds Value
			IF (@odds > 0)
			BEGIN
				INSERT INTO #tempData(winlostdate, sporttype, bettype, custid, username, nickname, StatusID)
				SELECT winlostdate, sporttype, bettype, b.custid, c.username, c.nickname, StatusID
				FROM (
					SELECT DISTINCT	winlostdate, 
							CASE WHEN b.bettype IN (9, 10, 29) THEN 1
								ELSE b.sporttype 
							END AS sporttype, bettype, b.custid, StatusID
					FROM #recommend rec
						JOIN bodb_LicenseeReport.dbo.rptcustomerturnOver b WITH(NOLOCK) ON b.Recommend = rec.CustID
					WHERE b.winlostdate BETWEEN @fromdate AND @tempToDate
						AND CASE WHEN (b.bettype IN (1,2,3,7,12,8,20,21,1301,1303,1305,1306,1308,1311,1312,1316,1318,1324,153,154,155,156)	 -- add more Sportting Solution bettype 
										OR b.bettype BETWEEN 9001 AND 9087	-- Esport 2
										OR b.bettype BETWEEN 81 AND 88
										OR b.bettype BETWEEN 90 AND 120
										OR b.bettype BETWEEN 8101 AND 8120 -- Number Game: Happy 5
										OR b.bettype IN (157,178,183,184,194,197,198,203,204,205) -- add more bettype BetRadar 
										OR b.bettype BETWEEN 401 AND 404 -- add more PH-AIO new bettypes
										OR b.bettype = 428 -- 2H Odd/Even
										OR (b.bettype BETWEEN 603 AND 607 OR b.bettype BETWEEN 609 AND 613 OR b.bettype BETWEEN 615 AND 617) -- Basketball bettypes
										OR b.bettype BETWEEN 2701 AND 2707 -- Virtual Sport 2
										OR b.bettype BETWEEN 2800 AND 2829 -- Virtual Sport 2: basketball
										OR b.bettype IN (467,468,469) -- PH-AIO new bettypes (phase 4a)
										OR b.bettype IN (470,471,472,479,481,488,489,490,491,492) -- PH-AIO new bettypes (phase 4b)
										OR (bettype NOT IN (703, 711) AND bettype BETWEEN 701 AND 714) -- BM-AIO new bettypes (phase 2)
										OR b.bettype IN (381,382,386,387,388,389,390,393,394,400) -- PH-AIO new bettypes (phase 5)
									)
									THEN 
										CASE
											WHEN b.OddsType = 1 THEN b.odds + 1 --decimal
											WHEN b.OddsType = 2 THEN b.Odds + 1 --hongkong to decimal
											WHEN b.OddsType IN (3,4,7) THEN --malay and indo and new oddstype to decimal
																CASE 
																	WHEN b.odds < 0 THEN (1 -  cast(1 as float) / cast(b.odds AS float))
																	WHEN b.odds >=0 THEN (1 + b.odds) END
											WHEN b.OddsType = 5 THEN --american odds to decimal
															CASE
															WHEN (b.odds * 100) < 0 THEN (1- cast (1 AS float)/ cast (b.odds AS float))
															WHEN (b.odds * 100) % 2 = 0 THEN 2
															WHEN (b.odds * 100) > 0 THEN (1 + b.odds) END 
										END 
									ELSE b.Odds
								END >= @odds
					) b
					INNER JOIN #tempCust c ON b.custid = c.custid
				OPTION(RECOMPILE)
			END

			IF @totalBettrans < @maxRow OR @IsExportExcel = 1
			BEGIN
				INSERT INTO #tempPagingData(winlostdate, custid, username, nickname)
				SELECT b.winlostdate
						, b.Custid
						, b.username
						, b.nickname					
				FROM #tempData b
					INNER JOIN #bettype bt ON b.bettype =  bt.typeid
					INNER JOIN #Status st ON b.StatusID =  st.StatusID
					INNER JOIN #ProductID p ON b.sporttype = p.sportID
				GROUP BY 
					b.winlostdate
					, b.custid
					, b.username
					, b.nickname
				ORDER BY winlostdate DESC, nickname
				
				SET @totalSumRpt = @@ROWCOUNT	
			END
			ELSE
			BEGIN
				SELECT @totalSumRpt = COUNT(1)
				FROM (
					SELECT
						b.winlostdate
						, b.Custid
						, b.username
					FROM #tempData b
						INNER JOIN #bettype bt ON b.bettype =  bt.typeid
						INNER JOIN #Status st ON b.StatusID =  st.StatusID
						INNER JOIN #ProductID p ON b.sporttype = p.sportID
					GROUP BY 
						b.winlostdate
						, b.custid
						, b.username
				) d
			END
		END
	END

	-- VIEW all members
	IF (@searchCust = 0)
	BEGIN
		IF @ToDate > @MoveBetsDay
		BEGIN
			INSERT INTO #tempPagingData(winlostdate, custid, username, nickname)
			SELECT b.winlostdate
					, c.Custid
					, c.username
					, ISNULL(SUBSTRING(c.username2,CHARINDEX ('$',c.username2,1)+1,LEN(c.username2)),c.username) AS nickname
			FROM #tempBettrans b
				INNER JOIN dbo.Customer  c WITH (NOLOCK, INDEX = IX_custid) ON b.custid = c.custid
			GROUP BY
				b.winlostdate
				, c.username
				, ISNULL(SUBSTRING(c.username2,CHARINDEX ('$',c.username2,1)+1,LEN(c.username2)),c.username)
				, c.custid
			ORDER BY b.winlostdate DESC, username

			SET @totalBettrans = @@ROWCOUNT
		END	

		IF @FromDate <= @MoveBetsDay
		BEGIN
			IF(@odds = 0)
			BEGIN
				INSERT INTO #tempData(winlostdate, sporttype, bettype, custid, username, nickname, StatusID)
				SELECT winlostdate, sporttype, bettype, b.custid, c.username, ISNULL(SUBSTRING(c.username2,CHARINDEX ('$',c.username2,1)+1,LEN(c.username2)),c.username) AS nickname, StatusID
				FROM (
					SELECT DISTINCT	winlostdate, 
							CASE WHEN b.bettype IN (9, 10, 29) THEN 1
								ELSE b.sporttype 
							END AS sporttype, bettype, b.custid, StatusID
					FROM #recommend rec
						JOIN bodb_LicenseeReport.dbo.rptcustomerturnOver b WITH(NOLOCK)
							ON b.Recommend	= rec.CustID
					WHERE b.winlostdate BETWEEN @fromdate AND @tempToDate
					) b
					INNER JOIN dbo.Customer  c WITH (NOLOCK, INDEX = IX_custid)
						ON b.custid 	= c.custid
				OPTION(RECOMPILE)
			END

			-- Has Odds Value
			IF ( @odds > 0 )
			BEGIN
				INSERT INTO #tempData(winlostdate, sporttype, bettype, custid, username, nickname, StatusID)
				SELECT winlostdate, sporttype, bettype, b.custid, c.username, ISNULL(SUBSTRING(c.username2,CHARINDEX ('$',c.username2,1)+1,LEN(c.username2)),c.username) AS nickname, StatusID
				FROM (
					SELECT DISTINCT	winlostdate, 
							CASE WHEN b.bettype IN (9, 10, 29) THEN 1
								ELSE b.sporttype 
							END AS sporttype, bettype, b.custid, StatusID
					FROM #recommend rec
						JOIN bodb_LicenseeReport.dbo.rptcustomerturnOver b WITH(NOLOCK)
							ON b.Recommend	= rec.CustID
					WHERE b.winlostdate BETWEEN @fromdate AND @tempToDate
						AND CASE WHEN (b.bettype IN (1,2,3,7,12,8,20,21,1301,1303,1305,1306,1308,1311,1312,1316,1318,1324,153,154,155,156)	 -- add more Sportting Solution bettype 
										OR b.bettype BETWEEN 9001 AND 9087	-- Esport 2
										OR b.bettype BETWEEN 81 AND 88
										OR b.bettype BETWEEN 90 AND 120
										OR b.bettype BETWEEN 8101 AND 8120 -- Number Game: Happy 5
										OR b.bettype IN (157,178,183,184,194,197,198,203,204,205) -- add more bettype BetRadar 
										OR b.bettype BETWEEN 401 AND 404 -- add more PH-AIO new bettypes
										OR b.bettype = 428 -- 2H Odd/Even
										OR (b.bettype BETWEEN 603 AND 607 OR b.bettype BETWEEN 609 AND 613 OR b.bettype BETWEEN 615 AND 617) -- Basketball bettypes
										OR b.bettype BETWEEN 2701 AND 2707 -- Virtual Sport 2
										OR b.bettype BETWEEN 2800 AND 2829 -- Virtual Sport 2: basketball
										OR b.bettype IN (467,468,469) -- PH-AIO new bettypes (phase 4a)
										OR b.bettype IN (470,471,472,479,481,488,489,490,491,492) -- PH-AIO new bettypes (phase 4b)
										OR (bettype NOT IN (703, 711) AND bettype BETWEEN 701 AND 714) -- BM-AIO new bettypes (phase 2)
										OR b.bettype IN (381,382,386,387,388,389,390,393,394,400) -- PH-AIO new bettypes (phase 5)
									)
									THEN 
										CASE
											WHEN b.OddsType = 1 THEN b.odds + 1 --decimal
											WHEN b.OddsType = 2 THEN b.Odds + 1 --hongkong to decimal
											WHEN b.OddsType IN (3,4,7) THEN --malay and indo and new oddstype to decimal
																CASE 
																	WHEN b.odds < 0 THEN (1 -  cast(1 as float) / cast(b.odds AS float))
																	WHEN b.odds >=0 THEN (1 + b.odds) END
											WHEN b.OddsType = 5 THEN --american odds to decimal
															CASE
															WHEN (b.odds * 100) < 0 THEN (1- cast (1 AS float)/ cast (b.odds AS float))
															WHEN (b.odds * 100) % 2 = 0 THEN 2
															WHEN (b.odds * 100) > 0 THEN (1 + b.odds) END 
										END 
									ELSE b.Odds
								END >= @odds
					) b
					INNER JOIN dbo.Customer  c WITH (NOLOCK, INDEX = IX_custid) ON b.custid = c.custid
				OPTION(RECOMPILE)
			END

			IF @totalBettrans < @maxRow OR @IsExportExcel = 1
			BEGIN
				INSERT INTO #tempPagingData(winlostdate, custid, username, nickname)
				SELECT b.winlostdate
						, b.Custid
						, b.username
						, b.nickname				
				FROM #tempData b
					INNER JOIN #bettype bt
					ON b.bettype 	=  bt.typeid
					INNER JOIN #Status st
					ON b.StatusID 	=  st.StatusID
					INNER JOIN #ProductID p 
					ON b.sporttype = p.sportID
				GROUP BY 
					b.winlostdate
					, b.custid
					, b.username
					, b.nickname
				ORDER BY winlostdate DESC, nickname
				
				SET @totalSumRpt = @@ROWCOUNT	
			END
			ELSE
			BEGIN
				SELECT @totalSumRpt = COUNT(1)
				FROM (
					SELECT b.winlostdate
							, b.Custid
							, b.username
					FROM #tempData b
						INNER JOIN #bettype bt ON b.bettype 	=  bt.typeid
						INNER JOIN #Status st ON b.StatusID 	=  st.StatusID
						INNER JOIN #ProductID p ON b.sporttype = p.sportID
					GROUP BY 
						b.winlostdate
						, b.custid
						, b.username
				) d
			END
		END
	END
	
	IF @IsExportExcel = 1
	BEGIN
		INSERT INTO #tempCustPaging 
		SELECT
			p.RowIdx AS rowno
			, p.winlostdate
			, p.custid
			, p.username
			, p.nickname
		FROM #tempPagingData p
	END
	ELSE
	BEGIN
		INSERT INTO #tempCustPaging 
		SELECT
			p.RowIdx AS rowno
			, p.winlostdate
			, p.custid
			, p.username
			, p.nickname
		FROM #tempPagingData p
		WHERE p.RowIdx BETWEEN @offsetRow AND @maxRow
	END

	RETURN;
END
GO
/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="1"></info>*/
USE [bodb02]
GO
 
ALTER PROCEDURE  [dbo].[Lrf_Rpt_CustomerTurnOver_SumMember]
(
	@pStartDate		DATE
	,@pEndDate 		DATE
	,@MoveBetsDay 	SMALLDATETIME
	,@Odds 			FLOAT
	,@ReportBy  	TINYINT
) 
AS
/*	
Created: 20150603@Bobby
Task: Customer Performance Report
DB: DBEXT/BODB02
Revision:
	- 20151127@Bobby: #48081 - Apply PH-AIO new bettypes
	- 20151223@Jim: Add "Effective Betting Value" in Customer Turnover report [Redmine: #45736]
	- 20160720@Jim : Implement 67 new bet types (PH All in one - Phase 2) [Redmine : #53520]
	- 20170615@Harper: Customer Turnover report values are inconsistent [RedmineID: #78391]
	- 20171006@Percy: Hotfix - Add missing mutilple odds bettypes [RedmineID: #84457]
		1. Basketball (603-607, 609-613, 615-617)
		2. Virtual Sports 2 (2701-2707)
	- 20180409@Joseph: Implement new sports for VS2: BasketBall - Virual Soccer World Cup [Redmine: #90881]
	- 20180810@Paul: Enhance performance [Redmine: #98260]
	- 20181219@Joseph: Add new bet types for E-Sports 2.0 for report Customer Turnover [RedmineID: #106666]
	- 20181210@Joseph: Integrate Happy 5 for NumberGame [RedmineID: #103698]

Parameter's Explanation:
			
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @tempFromDate SMALLDATETIME, 
			@tempToDate SMALLDATETIME

	CREATE TABLE #tempCustData (
		winlostdate		SMALLDATETIME,
		sporttype		SMALLINT, 
		bettype			SMALLINT, 
		custid			INT, 
		currency		INT,
		StatusID		TINYINT,
		betcount		INT,
		stake			MONEY,
		winlost			MONEY,
		BetEffective	MONEY,
		playercomm		MONEY
	)

	CREATE CLUSTERED INDEX CIX_tempCustData ON #tempCustData(custid, winlostdate)

	SELECT @tempFromDate =  CASE WHEN @pStartDate <= @MoveBetsDay THEN DATEADD(DAY,1,@MoveBetsDay)
								ELSE @pStartDate
							END

	SELECT @tempToDate 	=  CASE WHEN @pEndDate >= @MoveBetsDay THEN @MoveBetsDay 
								ELSE @pEndDate 
							END
	--GET sum member detial
	IF(@pEndDate > @MoveBetsDay)
	BEGIN
		INSERT INTO #custData
		SELECT c.rowno
			, c.winlostdate 
			, c.custid
			, c.username
			, b.currency
			, b.sporttype
			, b.bettype
			, SUM(1) 			as betcount
			, SUM(b.stake) 		as turnover 
			, SUM(b.winlost) 	as winlost
			, SUM (b.BetEffective) as BetEffective
			, SUM(b.playercomm) as playercomm
		FROM #tempBettrans b
			INNER JOIN #tempCustPaging c 
			ON  b.custid		= c.custid 
			AND c.winlostdate 	= b.winlostdate
		GROUP BY
			c.rowno
			,c.winlostdate 
			,c.custid
			,c.username
			,b.currency
			,b.sporttype
			,b.bettype
	END

	IF(@pStartDate <= @MoveBetsDay)
	BEGIN
		IF ( @odds = 0 )
		BEGIN
			INSERT INTO #tempCustData (
				winlostdate,
				custid, 
				currency,
				sporttype, 
				bettype, 
				StatusID,
				betcount,
				stake,
				winlost,
				BetEffective,
				playercomm
			)
			SELECT CASE WHEN @ReportBy =  2 THEN DATEADD(M, DATEDIFF(M, 0, b.winlostdate), 0) 
						ELSE winlostdate
					END AS winlostdate, b.custid, rec.currency,
					CASE WHEN b.bettype IN (9, 10, 29) THEN 1
						ELSE b.sporttype 
					END AS sporttype, bettype, StatusID
					, SUM(b.betcount)	AS betcount
					, SUM(b.stake) 		AS stake
					, SUM(b.winlost)  	AS winlost
					, SUM(b.BetEffective) AS BetEffective
					, SUM(b.playercomm) AS playercomm
			FROM #recommend rec
				JOIN bodb_LicenseeReport.dbo.rptcustomerturnOver b WITH(NOLOCK)
						ON b.Recommend	= rec.CustID
			WHERE b.winlostdate BETWEEN @pStartDate AND @tempToDate
			GROUP BY b.custid, CASE WHEN @ReportBy =  2 THEN DATEADD(M, DATEDIFF(M, 0, b.winlostdate), 0) 
						ELSE winlostdate
					END, rec.currency, 
					CASE WHEN b.bettype IN (9, 10, 29) THEN 1
						ELSE b.sporttype 
					END, bettype, StatusID
			OPTION(RECOMPILE)	
		END
		
		--Has Odds Value
		IF ( @odds > 0 )
		BEGIN
			INSERT INTO #tempCustData (
				winlostdate,
				custid, 
				currency,
				sporttype, 
				bettype, 
				StatusID,
				betcount,
				stake,
				winlost,
				BetEffective,
				playercomm
			)
			SELECT CASE WHEN @ReportBy =  2 THEN DATEADD(M, DATEDIFF(M, 0, b.winlostdate), 0) 
						ELSE winlostdate
					END AS winlostdate, b.custid, rec.currency,
					CASE WHEN b.bettype IN (9, 10, 29) THEN 1
						ELSE b.sporttype 
					END AS sporttype, bettype, StatusID
					, SUM(b.betcount)	AS betcount
					, SUM(b.stake) 		AS stake
					, SUM(b.winlost)  	AS winlost
					, SUM(b.BetEffective) AS BetEffective
					, SUM(b.playercomm) AS playercomm
			FROM #recommend rec
				JOIN bodb_LicenseeReport.dbo.rptcustomerturnOver b WITH(NOLOCK)
						ON b.Recommend	= rec.CustID
			WHERE b.winlostdate BETWEEN @pStartDate AND @tempToDate
				AND CASE WHEN (b.bettype IN (1,2,3,7,12,8,20,21,1301,1303,1305,1306,1308,1311,1312,1316,1318,1324,153,154,155,156)	 -- add more Sportting Solution bettype 
								OR b.bettype BETWEEN 9001 AND 9086	-- Esport 2
								OR b.bettype BETWEEN 81 AND 88
								OR b.bettype BETWEEN 90 AND 120
								OR b.bettype BETWEEN 8101 AND 8120 -- Number Game: Happy 5
								OR b.bettype IN (157,178,183,184,194,197,198,203,204,205) -- add more bettype BetRadar 
								OR b.bettype BETWEEN 401 AND 404 -- add more PH-AIO new bettypes
								OR b.bettype = 428 -- 2H Odd/Even
								OR (bettype BETWEEN 603 AND 607 OR bettype BETWEEN 609 AND 613 OR bettype BETWEEN 615 AND 617) -- Basketball bettypes
								OR bettype BETWEEN 2701 AND 2707 -- Virtual Sport 2
								OR bettype BETWEEN 2800 AND 2829 -- Virtual Sport 2: basketball
							)
							THEN 
									CASE WHEN b.OddsType = 1 THEN b.odds + 1 --decimal
										 WHEN b.OddsType = 2 THEN b.Odds + 1 --hongkong to decimal
										 WHEN b.OddsType IN (3,4) THEN --malay and indo to decimal
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
				 END >= @odds
			GROUP BY b.custid, CASE WHEN @ReportBy =  2 THEN DATEADD(M, DATEDIFF(M, 0, b.winlostdate), 0) 
						ELSE winlostdate
					END, rec.currency, 
					CASE WHEN b.bettype IN (9, 10, 29) THEN 1
						ELSE b.sporttype 
					END, bettype, StatusID
			OPTION(RECOMPILE)
		END

		INSERT INTO #custData
		SELECT 
			c.rowno
			, b.winlostdate 
			, b.custid
			, c.username
			, b.currency
			, b.sporttype  
			, b.bettype
			, SUM(b.betcount) as betcount
			, SUM(b.stake) as turnover 
			, SUM(b.winlost) as winlost
			, SUM(b.BetEffective) As BetEffective
			, SUM(b.playercomm) as playercomm
				
		FROM #tempCustData b
			INNER JOIN #tempCustPaging c 
				ON  b.custid	= c.custid AND c.winlostdate 	= b.winlostdate
			INNER JOIN #bettype bt
				ON b.bettype 	=  bt.typeid
			INNER JOIN #Status st
				ON b.StatusID 	=  st.StatusID
			INNER JOIN #ProductID p 
				ON b.sporttype = p.sportID				
		GROUP BY
			c.rowno
			, b.winlostdate 
			, b.custid
			, c.username
			, b.currency
			, b.sporttype 
			, b.bettype		
	END

	RETURN;
END
GO
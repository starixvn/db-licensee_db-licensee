USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Task_rptCustomerTurnOver_Bettrans_bk]    Script Date: 20/12/2013 3:23:18 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER  PROCEDURE [dbo].[Task_rptCustomerTurnOver_Bettrans_bk]
    @Fromdate smalldatetime,
	@Todate smalldatetime
AS
/*	
	Created	: Florent Nguyen
	Task: Customer Performance Report
	Date: 2013-11-25
	DB: DBACC.bodb02
	Original: 
	Revision:
	Parameter's Explanation:			
*/
SET NOCOUNT ON;



;WITH cte_isBATrans
AS 
(
	SELECT * FROM DBLIC.bodb_licensee.dbo.LicenseeBATransaction
	WHERE Transdate BETWEEN @fromdate and DATEADD(DAY,2,@Todate)
)
 ,TEMPS
AS (
	SELECT a.CustID
		,a.recommend
		,a.matchid
		,a.bettype
		,SUM(ABS(a.stake)) as stake
		,sum(a.winlost- a.actual_stake) winlost
		,sum(a.PlayerComm) PlayerComm
		,a.Odds
		--,a.modds
		,a.oddsid
		,a.oddstype
		--,a.statusID
		,CASE 
		WHEN a.statusID = 112
			AND a.bettype IN (1, 3, 7, 8, 17, 18)
			AND ABS(modds) = 0.25
			THEN 114
		WHEN a.statusID = 112
			AND a.liveawayscore = 0 
			AND a.bettype IN(33,43) 
			THEN 114
		WHEN a.statusID = 113
			AND a.bettype IN (1, 3, 7, 8, 17, 18)
			AND ABS(modds) = 0.25
			THEN 115
		WHEN a.statusID = 113
			AND a.liveawayscore = 0 
			AND a.bettype IN(33,43)
			THEN 115
		ELSE a.statusID
		END AS statusID
		,a.winlostdate
		,COUNT(custid) betcount
		,CASE 
		WHEN BA.transid IS NULL THEN 0
		WHEN BA.transid IS NOT NULL THEN 1 END AS isBA
	FROM bodb_archive.dbo.bettrans_bk a WITH (NOLOCK)
	LEFT JOIN cte_isBATrans AS BA ON a.transid=ba.transid
	WHERE a.winlostdate BETWEEN @fromdate AND @todate
	AND a.statusID IN (111,112,113) 
	--AND a.bettype<=19999
	GROUP BY a.matchid
		,a.CustID
		,a.recommend
		,a.bettype
		,a.Odds
		,a.modds
		,a.oddsid
		,a.oddstype
		,a.statusID
		,a.winlostdate
		,a.liveawayscore
		,CASE 
		WHEN BA.transid IS NULL THEN 0
		WHEN BA.transid IS NOT NULL THEN 1 END
	)
	,cte_tempLicenseeCust
AS (
	SELECT DISTINCT currency
		,custid
	FROM DBLIC.bodb_licensee.dbo.LicenseeCust lc WITH (NOLOCK)
	)
	,cte_bettrans
AS (
	SELECT a.*
		,LC.currency
	FROM TEMPS a WITH (NOLOCK)
		,cte_tempLicenseeCust lc WITH (NOLOCK)
	WHERE a.recommend = lc.custid
	)
	,cte_raceinfo
AS (
	SELECT o.Orid
		,r.SportType
		,r.LeagueID
	FROM bodb_archive.dbo.VSOutright_bk o WITH (NOLOCK)
	INNER JOIN dbo.VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
	WHERE EventTime BETWEEN @fromdate AND @todate
)
--SELECT * FROM cte_bettrans

--INSERT INTO DB052.bodb_LicenseeReport.dbo.rptCustomerTurnOver  
SELECT
	ROW_NUMBER() OVER (ORDER BY a.custid ) num 
    ,a.CustID
	,a.bettype
	,CASE 
		WHEN a.bettype IN (71, 72)
			THEN 251 --casino
		WHEN a.bettype = 1000
			THEN 253 --games
		WHEN a.bettype BETWEEN 81 AND 120
			THEN 161 --Number Game 
		WHEN a.bettype BETWEEN 1101 AND 1199
			THEN 162 -- Live casino
		WHEN a.bettype BETWEEN 1201 AND 1299
			THEN 
				CASE 
					WHEN result.sporttype IS NOT NULL THEN result.sporttype
					WHEN b.sporttype IS NOT NULL THEN b.sporttype
					ELSE 180 --Virtual Sport
				END   --Virtual Sport
				 --isnull(result.sporttype,isNULL(b.sporttype,180))  --Virtual Sport
		WHEN a.bettype BETWEEN 51 AND 69
			THEN 201
		WHEN a.bettype IN (31, 32, 33, 41, 42, 43)
			THEN 151
		ELSE isNULL(b.sporttype,0)
		END sporttype,
	a.Currency
	,stake
	,winlost 
	,playercomm
	,a.Odds
	,oddstype
	,a.statusID
	,a.recommend
	,CASE 
		WHEN a.bettype IN (9, 29)
			THEN - 9
		WHEN a.bettype = 10
			OR (
				a.bettype > 30
				AND a.bettype < 50
				)
			THEN ISNULL(ob.leagueid, - 1)
		WHEN a.bettype IN (1231, 1232, 1233, 1237, 1238)
			THEN isnull(result.LeagueID,-1)
		ELSE isnull(b.LeagueID, - 1)
		END LeagueID
	,winlostdate
	,a.betcount
	,a.isba	
INTO #datatemp
FROM cte_bettrans a
LEFT JOIN bodb_archive.dbo.MATCH_BK b WITH (NOLOCK) ON a.matchid = b.matchid
LEFT JOIN cte_raceinfo result ON a.oddsid = result.Orid
LEFT JOIN bodb_archive.dbo.outright_bk AS ob WITH (NOLOCK) ON a.matchid = ob.orid


DECLARE @i INT,@step int
SET @i=1  
SET @step=20000
WHILE (1=1)
BEGIN 
	INSERT INTO DBLIC.bodb_LicenseeReport.dbo.rptCustomerTurnOver
	SELECT CustID,bettype
	,sporttype
	,Currency
	,stake
	,winlost 
	,playercomm
	,Odds
	,oddstype
	,statusID
	,recommend
	,LeagueID
	,winlostdate
	,betcount
	,isba 
	FROM #datatemp WHERE num BETWEEN @i AND @i+@step
	delete #datatemp WHERE num BETWEEN @i AND @i+@step
	SET @i=@i+@step
	IF not EXISTS (SELECT 1 FROM #datatemp )
	BREAK
END 

DROP TABLE #datatemp

GO
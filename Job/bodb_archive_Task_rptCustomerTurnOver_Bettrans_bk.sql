USE bodb02 
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.Task_rptCustomerTurnOver_Bettrans_bk
    @Fromdate smalldatetime,
	@Todate smalldatetime
AS
/*	
	Created	: Florent Nguyen
	Task: Customer Performance Report
	Date: 2013-11-30
	DB: DBARC.bodb_Archive
	Original: 
	Revision:

	Parameter's Explanation:

			
*/
SET NOCOUNT ON;

WITH TEMPS
AS (
	SELECT a.CustID
		,a.recommend
		,a.matchid
		,a.bettype
		,sum(a.stake) stake
		,sum(a.winlost) winlost
		,sum(a.actual_stake) actual_stake
		,sum(a.PlayerComm) PlayerComm
		,a.Odds
		,a.modds
		,a.oddsid
		,a.oddstype
		,a.statusID
		,a.winlostdate
		,COUNT(custid) betcount
	FROM bodb_archive.dbo.bettrans_bk a WITH (NOLOCK)
	WHERE a.winlostdate BETWEEN @fromdate AND @todate
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

--INSERT INTO DB052.bodb_LicenseeReport.dbo.rptCustomerTurnOver  
SELECT a.CustID
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
			THEN 180 --Virtual Sport
		WHEN a.bettype BETWEEN 51 AND 69
			THEN 201
		WHEN a.bettype IN (31, 32, 33, 41, 42, 43)
			THEN 151
		ELSE isNULL(b.sporttype,0)
		END sporttype
	,
	a.Currency
	--,sum(stake) stake
	--,sum(winlost) winlost
	--,sum(actual_stake) actual_stake
	--,sum(PlayerComm) PlayerComm
	,stake
	,winlost 
	,actual_stake 
	,playercomm
	,a.Odds
	,oddstype
	,CASE 
		WHEN a.statusID = 112
			AND a.bettype IN (1, 3, 7, 8, 17, 18)
			AND ABS(modds) = 0.25
			THEN 114
		WHEN a.statusID = 113
			AND a.bettype IN (1, 3, 7, 8, 17, 18)
			AND ABS(modds) = 0.25
			THEN 115
		ELSE a.statusID
		END AS statusID
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
FROM cte_bettrans a
LEFT JOIN bodb_archive.dbo.MATCH_BK b WITH (NOLOCK) ON a.matchid = b.matchid
LEFT JOIN cte_raceinfo result ON a.oddsid = result.Orid
LEFT JOIN bodb_archive.dbo.outright_bk AS ob WITH (NOLOCK) ON a.matchid = ob.orid

--INSERT INTO DB052.bodb_LicenseeReport.dbo.rptCustomerTurnOver  
while (1=1)
begin
  delete top(20000) from #datatemp
  output deleted.*
   into DB052.bodb_LicenseeReport.dbo.rptCustomerTurnOver  
  if @@rowcount=0 break
END

GO
GRANT VIEW DEFINITION ON dbo.Task_rptCustomerTurnOver_Bettrans_bk TO vnteam AS dbo
GO

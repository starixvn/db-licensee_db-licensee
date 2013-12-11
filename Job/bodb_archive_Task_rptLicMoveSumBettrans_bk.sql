USE [bodb_archive]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Task_rptLicMoveSumBettrans_bk]
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
SET NOCOUNT ON

;WITH TEMPS
AS
	(
	SELECT  a.CustID,     
	  a.recommend,
		a.matchid,	
	  a.bettype,
	  --lc.currency,
	  sum(a.stake)stake,
	  sum(a.winlost)winlost,
	  sum(a.actual_stake) actual_stake,
	  sum(a.PlayerComm) PlayerComm,
	  a.Odds,
	  a.oddsid,
	  a.oddstype,
	  a.statusID,
	  a.winlostdate
	FROM dbo.bettrans_bk a with (nolock)
	WHERE a.winlostdate BETWEEN @fromdate AND @todate
	GROUP BY 
	  a.CustID,     
	  a.recommend,
	  a.matchid,	
	  a.bettype,
	  --lc.currency,
	  a.Odds,
	  a.oddsid,
	  a.oddstype,
	  a.statusID,
	  a.winlostdate
	)
, cte_bettrans
AS 
	(
		SELECT  a.*,LC.currency
		FROM TEMPS a with (nolock)
		INNER JOIN bodb_licensee.dbo.LicenseeCust lc WITH (NOLOCK) 
		ON a.recommend=lc.custid
	)
, cte_raceinfo
AS 
(
	SELECT  o.Orid,r.SportType,r.LeagueID
	FROM dbo.VSOutright_bk  o WITH (NOLOCK)
	INNER JOIN bodb02.dbo.VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID  
	WHERE EventTime BETWEEN @fromdate AND @todate
)

INSERT INTO DB052.bodb_LicenseeReport.dbo.rptCustomerTurnOver  
SELECT 
	  a.CustID, 
	  a.bettype,
	  CASE WHEN a.bettype  IN (9,10,29) THEN 1
		WHEN a.bettype IN (1231,1232,1233,1237,1238) THEN result.SportType 
		ELSE b.sporttype END sporttype,
	  a.Currency,  
	  sum(stake)stake,
	  sum(winlost)winlost,
	  sum(actual_stake) actual_stake,
	  sum(PlayerComm) PlayerComm,
	  Odds,
	  oddstype,
	  statusID,
	  a.recommend,
	  CASE 
		WHEN a.bettype IN (1231,1232,1233,1237,1238) THEN result.LeagueID 
		ELSE b.LeagueID END LeagueID,
	  winlostdate
--INTO #DATATEMP 
FROM  cte_bettrans a
LEFT JOIN
		dbo.MATCH_BK b WITH (NOLOCK) ON a.matchid = b.matchid
LEFT JOIN 
		cte_raceinfo result ON  a.oddsid=result.Orid

GROUP BY 
	 a.CustID,     
	 a.recommend,
	 a.bettype,
	 CASE WHEN a.bettype  IN (9,10,29) THEN 1
	  WHEN a.bettype IN (1231,1232,1233,1237,1238) THEN result.SportType 
	  ELSE b.sporttype END,
	  a.Currency,
	 Odds,
	 oddstype,
	 b.leagueid,
	 statusID,
	 CASE  WHEN a.bettype IN (1231,1232,1233,1237,1238) THEN result.LeagueID 
		ELSE b.LeagueID END,
	winlostdate

GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_MovBettrans_bk_RPT] TO [vnteam] AS [dbo]
GO

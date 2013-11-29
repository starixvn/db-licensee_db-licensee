USE [bodb_archive]
GO

/****** Object:  StoredProcedure [dbo].[Lrf_MovBettrans_bk_RPT]    Script Date: 21/11/2013 3:10:57 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Lrf_MovBettrans_bk_RPT]
    @Fromdate smalldatetime,
	@Todate smalldatetime
AS
/*	
	Created	: Florent Nguyen
	Task: Customer Performance Report
	Date: 2013-11-29
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
	SELECT  o.Orid,r.SportType
	FROM dbo.VSOutright_bk  o WITH (NOLOCK)
	INNER JOIN bodb02.dbo.VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID  
	WHERE EventTime BETWEEN @fromdate AND @todate
)

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
	  winlostdate
INTO #DATATEMP 
FROM  cte_bettrans a
LEFT JOIN
		dbo.MATCH_BK b WITH (NOLOCK,index=pk_match_bk) ON a.matchid = b.matchid
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
	 statusID,
	winlostdate
WHILE (1=1)
	BEGIN
	--delay 1minute?
	--WAITFOR DELAY '00:00';
		delete top(10000) from #DATATEMP 
		output deleted.*
		into DB052.bodb_LicenseeReport.dbo.rptCustomerTurnOver
		if @@rowcount=0 break
	END
DROP TABLE  #datatemp

GO
GO
ALTER AUTHORIZATION ON [dbo].[Lrf_MovBettrans_bk_RPT] TO  SCHEMA OWNER 
GO
GRANT EXECUTE ON [dbo].[Lrf_MovBettrans_bk_RPT] TO [bodbLicenseeNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_MovBettrans_bk_RPT] TO [vnteam] AS [dbo]
GO

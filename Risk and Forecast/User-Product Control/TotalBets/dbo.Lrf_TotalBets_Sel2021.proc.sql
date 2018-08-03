USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Lrf_TotalBets_Sel2021]	
	@PageSize	INT=50,
	@PageIndex	INT=0,
	@TotalRows	INT=0 OUTPUT,
	@AgentList	VARCHAR(MAX)
AS 
/*
Created: 20101201@Henry
Task: Retrieve Total Bet values for MoneyLine.
DB: DB042.bodb02
Original: [Age_TotalBets_Sel2021_Ag]
Revisions:
	- 201133@Alex:Allow to choose all type of licensee AND all currency + suppport based currency
	- 20110801@Henry: Remove PT + exclude BA ticket
	- 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily  
	- 20121004@Jim: replace @currencyname input param by @currencyID
	- 20130514@Jim:Restrict permission of Licensee Users by currency
	- 20140718@Hannah: Change liveindicator datatype to INT to fix running live matches are not being showed at the top list (RedmineID:19136)
	- 20141110@Winnie: Change from LicenseeCust table to [f_SelLicenseeCust] function
	- 20150124@Winnie: Add base currency GBP 
	- 20150617@Jim:  Enhance Total Bets with sum values of running stakes  (Feature #36839)
	- 20170227@Harper: LRF - Get data by @AgentList instead of @UserID [RedmineID: #71679]
	- 20180802@Sophia: HA - Status IN (0,1) to use new index on DB042 [Redmine: #98631]

Param's Explanation:
	+ @AgentList: xml structure
					<ROOT>
					<Agent AgentId="12345" Currency="3"/>  
					<Agent AgentId="12345" Currency="5"/>  
					</ROOT>
*/

SET NOCOUNT ON

DECLARE @Today smalldatetime 
SET @Today = convert(VARCHAR(10), CURRENT_TIMESTAMP, 120) 

DECLARE @TempAg AS TABLE ( CustId INT,Currency INT )
DECLARE @DocHandler INT

BEGIN TRY
	EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@AgentList
	INSERT INTO @TempAg (custID, currency)
	SELECT AgentId, Currency
	FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency INT) AS Data

	EXEC sp_xml_removedocument @DocHandler
END TRY

BEGIN CATCH
	SELECT ErrCode = 100
			,ErrMsg = N'Paramter invalid.'

	RETURN
END CATCH;

DECLARE @RowCount INT, @RowStart INT, @RowEnd INT  
SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1 

DECLARE @Data as TABLE
(
	showtime nvarchar (50),
	leagueid INT,
	matchcode nvarchar(50),
	liveindicator INT,
	matchid INT,
	homeID INT,
	awayID INT,
	livehomescore INT,
	liveawayscore INT,
	
	home_odds MONEY,
	home_oddsUSD MONEY,
	home_oddsEUR MONEY,
	home_oddsGBP MONEY,
	
	home_odds_ori MONEY,
	home_oddsUSD_ori MONEY,
	home_oddsEUR_ori MONEY,
	home_oddsGBP_ori MONEY,
	
	away_odds MONEY,
	away_oddsUSD MONEY,
	away_oddsEUR MONEY,
	away_oddsGBP MONEY,
	
	away_odds_ori MONEY,
	away_oddsUSD_ori MONEY,
	away_oddsEUR_ori MONEY,
	away_oddsGBP_ori MONEY,
	
	WinLost_home MONEY,
	WinLost_homeUSD MONEY,
	WinLost_homeEUR MONEY,
	WinLost_homeGBP MONEY,
	
	WinLost_home_ori MONEY,
	WinLost_homeUSD_ori MONEY,
	WinLost_homeEUR_ori MONEY,
	WinLost_homeGBP_ori MONEY,
	
	WinLost_away MONEY,
	WinLost_awayUSD MONEY,
	WinLost_awayEUR MONEY,
	WinLost_awayGBP MONEY,
	
	WinLost_away_ori MONEY,
	WinLost_awayUSD_ori MONEY,
	WinLost_awayEUR_ori MONEY,
	WinLost_awayGBP_ori MONEY,
	
	home_odds_HT MONEY,
	home_odds_HTUSD MONEY,
	home_odds_HTEUR MONEY,
	home_odds_HTGBP MONEY,
	
	home_odds_HT_ori MONEY,
	home_odds_HTUSD_ori MONEY,
	home_odds_HTEUR_ori MONEY,
	home_odds_HTGBP_ori MONEY,
	
	away_odds_HT MONEY,
	away_odds_HTUSD MONEY,
	away_odds_HTEUR MONEY,
	away_odds_HTGBP MONEY,
	
	away_odds_HT_ori MONEY,
	away_odds_HTUSD_ori MONEY,
	away_odds_HTEUR_ori MONEY,
	away_odds_HTGBP_ori MONEY,
	
	
	WinLost_home_HT MONEY,
	WinLost_home_HTUSD MONEY,
	WinLost_home_HTEUR MONEY,
	WinLost_home_HTGBP MONEY,
	
	WinLost_home_HT_ori MONEY,
	WinLost_home_HTUSD_ori MONEY,
	WinLost_home_HTEUR_ori MONEY,
	WinLost_home_HTGBP_ori MONEY,
	
	WinLost_away_HT MONEY,
	WinLost_away_HTUSD MONEY,
	WinLost_away_HTEUR MONEY,
	WinLost_away_HTGBP MONEY,
	
	WinLost_away_HT_ori MONEY,
	WinLost_away_HTUSD_ori MONEY,
	WinLost_away_HTEUR_ori MONEY,
	WinLost_away_HTGBP_ori MONEY,
	
	
	isNeutral BIT
)

INSERT INTO @Data
SELECT
		m.showtime, 
		m.leagueid,
		m.matchcode,
		a.liveindicator,
		m.matchid,
		m.homeid,
		m.awayid,
		a.livehomescore,
		a.liveawayscore,
		
		sum((CASE WHEN bettype = 20 THEN (CASE WHEN betteam = 'h' THEN stake ELSE 0 END)*(CASE WHEN abs(odds) <1 THEN 1 ELSE abs(odds) END) ELSE 0 END)) AS home_odds,
		sum((CASE WHEN bettype = 20 THEN (CASE WHEN betteam = 'h' THEN stake*e.USD ELSE 0 END)*(CASE WHEN abs(odds) <1 THEN 1 ELSE abs(odds) END) ELSE 0 END)) AS home_oddsUSD,
		sum((CASE WHEN bettype = 20 THEN (CASE WHEN betteam = 'h' THEN stake*e.EUR ELSE 0 END)*(CASE WHEN abs(odds) <1 THEN 1 ELSE abs(odds) END) ELSE 0 END)) AS home_oddsEUR,
		sum((CASE WHEN bettype = 20 THEN (CASE WHEN betteam = 'h' THEN stake*e.GBP ELSE 0 END)*(CASE WHEN abs(odds) <1 THEN 1 ELSE abs(odds) END) ELSE 0 END)) AS home_oddsGBP,
		--
		sum((CASE WHEN bettype = 20 THEN (CASE WHEN betteam = 'h' THEN stake ELSE 0 END) ELSE 0 END)) AS home_odds_ori,
		sum((CASE WHEN bettype = 20 THEN (CASE WHEN betteam = 'h' THEN stake*e.USD ELSE 0 END) ELSE 0 END)) AS home_oddsUSD_ori,
		sum((CASE WHEN bettype = 20 THEN (CASE WHEN betteam = 'h' THEN stake*e.EUR ELSE 0 END) ELSE 0 END)) AS home_oddsEUR_ori,
		sum((CASE WHEN bettype = 20 THEN (CASE WHEN betteam = 'h' THEN stake*e.GBP ELSE 0 END) ELSE 0 END)) AS home_oddsGBP_ori,
		--
		sum((CASE WHEN bettype = 20 THEN (CASE WHEN betteam = 'a' THEN stake ELSE 0 END)*(CASE WHEN abs(odds) <1 THEN 1 ELSE abs(odds) END) ELSE 0 END)) AS away_odds,
		sum((CASE WHEN bettype = 20 THEN (CASE WHEN betteam = 'a' THEN stake*e.USD ELSE 0 END)*(CASE WHEN abs(odds) <1 THEN 1 ELSE abs(odds) END) ELSE 0 END)) AS away_oddsUSD,
		sum((CASE WHEN bettype = 20 THEN (CASE WHEN betteam = 'a' THEN stake*e.EUR ELSE 0 END)*(CASE WHEN abs(odds) <1 THEN 1 ELSE abs(odds) END) ELSE 0 END)) AS away_oddsEUR,
		sum((CASE WHEN bettype = 20 THEN (CASE WHEN betteam = 'a' THEN stake*e.GBP ELSE 0 END)*(CASE WHEN abs(odds) <1 THEN 1 ELSE abs(odds) END) ELSE 0 END)) AS away_oddsGBP,
		---
		sum((CASE WHEN bettype = 20 THEN (CASE WHEN betteam = 'a' THEN stake ELSE 0 END) ELSE 0 END)) AS away_odds_ori,
		sum((CASE WHEN bettype = 20 THEN (CASE WHEN betteam = 'a' THEN stake*e.USD ELSE 0 END) ELSE 0 END)) AS away_oddsUSD_ori,
		sum((CASE WHEN bettype = 20 THEN (CASE WHEN betteam = 'a' THEN stake*e.EUR ELSE 0 END) ELSE 0 END)) AS away_oddsEUR_ori,
		sum((CASE WHEN bettype = 20 THEN (CASE WHEN betteam = 'a' THEN stake*e.GBP ELSE 0 END) ELSE 0 END)) AS away_oddsGBP_ori,
		---
		sum(CASE WHEN bettype = 20 THEN (CASE WHEN betteam = 'h' THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds END) ELSE -actual_stake END) ELSE 0 END ) AS WinLost_home,
		sum(CASE WHEN bettype = 20 THEN (CASE WHEN betteam = 'h' THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds END)*e.USD ELSE -actual_stake*e.USD END) ELSE 0 END ) AS WinLost_homeUSD,
		sum(CASE WHEN bettype = 20 THEN (CASE WHEN betteam = 'h' THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds END)*e.EUR ELSE -actual_stake*e.EUR END) ELSE 0 END ) AS WinLost_homeEUR,
		sum(CASE WHEN bettype = 20 THEN (CASE WHEN betteam = 'h' THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds END)*e.GBP ELSE -actual_stake*e.GBP END) ELSE 0 END ) AS WinLost_homeGBP,
		---
		sum(CASE WHEN bettype = 20 THEN (CASE WHEN betteam = 'h' THEN stake  END) ELSE 0 END ) AS WinLost_home_ori, 
		sum(CASE WHEN bettype = 20 THEN (CASE WHEN betteam = 'h' THEN stake*e.USD END) ELSE 0 END ) AS WinLost_homeUSD_ori,
		sum(CASE WHEN bettype = 20 THEN (CASE WHEN betteam = 'h' THEN stake *e.EUR   END) ELSE 0 END ) AS WinLost_homeEUR_ori,
		sum(CASE WHEN bettype = 20 THEN (CASE WHEN betteam = 'h' THEN stake*e.GBP   END) ELSE 0 END ) AS WinLost_homeGBP_ori,
		--
		sum(CASE WHEN bettype = 20 THEN (CASE WHEN betteam = 'a' THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds END) ELSE -actual_stake END) ELSE 0 END) AS WinLost_away,
		sum(CASE WHEN bettype = 20 THEN (CASE WHEN betteam = 'a' THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds END)*e.USD ELSE -actual_stake*e.USD END) ELSE 0 END) AS WinLost_awayUSD,
		sum(CASE WHEN bettype = 20 THEN (CASE WHEN betteam = 'a' THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds END)*e.EUR ELSE -actual_stake*e.EUR END) ELSE 0 END) AS WinLost_awayEUR,
		sum(CASE WHEN bettype = 20 THEN (CASE WHEN betteam = 'a' THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds END)*e.GBP ELSE -actual_stake*e.GBP END) ELSE 0 END) AS WinLost_awayGBP,
		--
		sum(CASE WHEN bettype = 20 THEN (CASE WHEN betteam = 'a' THEN stake  END) ELSE 0 END) AS WinLost_away_ori,
		sum(CASE WHEN bettype = 20 THEN (CASE WHEN betteam = 'a' THEN stake *e.USD  ELSE 0 END) ELSE 0 END) AS WinLost_awayUSD_ori, 
		sum(CASE WHEN bettype = 20 THEN (CASE WHEN betteam = 'a' THEN stake*e.EUR  END) ELSE 0 END) AS WinLost_awayEUR_ori,
		sum(CASE WHEN bettype = 20 THEN (CASE WHEN betteam = 'a' THEN stake*e.GBP END) ELSE 0 END) AS WinLost_awayGBP_ori,
		--
		sum((CASE WHEN bettype = 21 THEN (CASE WHEN betteam = 'h' THEN stake ELSE 0 END)*(CASE WHEN abs(odds) <1 THEN 1 ELSE abs(odds) END) ELSE 0 END)) AS home_odds_HT,
		sum((CASE WHEN bettype = 21 THEN (CASE WHEN betteam = 'h' THEN stake*e.USD ELSE 0 END)*(CASE WHEN abs(odds) <1 THEN 1 ELSE abs(odds) END) ELSE 0 END)) AS home_odds_HTUSD,
		sum((CASE WHEN bettype = 21 THEN (CASE WHEN betteam = 'h' THEN stake*e.EUR ELSE 0 END)*(CASE WHEN abs(odds) <1 THEN 1 ELSE abs(odds) END) ELSE 0 END)) AS home_odds_HTEUR,
		sum((CASE WHEN bettype = 21 THEN (CASE WHEN betteam = 'h' THEN stake*e.GBP ELSE 0 END)*(CASE WHEN abs(odds) <1 THEN 1 ELSE abs(odds) END) ELSE 0 END)) AS home_odds_HTGBP,
		---
		sum((CASE WHEN bettype = 21 THEN (CASE WHEN betteam = 'h' THEN stake ELSE 0 END)  ELSE 0 END)) AS home_odds_HT_ori,
		sum((CASE WHEN bettype = 21 THEN (CASE WHEN betteam = 'h' THEN stake*e.USD ELSE 0 END) ELSE 0 END)) AS home_odds_HTUSD_ori,
		sum((CASE WHEN bettype = 21 THEN (CASE WHEN betteam = 'h' THEN stake*e.EUR ELSE 0 END)  ELSE 0 END)) AS home_odds_HTEUR_ori,
		sum((CASE WHEN bettype = 21 THEN (CASE WHEN betteam = 'h' THEN stake*e.GBP ELSE 0 END)  ELSE 0 END)) AS home_odds_HTGBP_ori,

		--
		sum((CASE WHEN bettype = 21 THEN (CASE WHEN betteam = 'a' THEN stake ELSE 0 END)*(CASE WHEN abs(odds) <1 THEN 1 ELSE abs(odds) END) ELSE 0 END)) AS away_odds_HT,
		sum((CASE WHEN bettype = 21 THEN (CASE WHEN betteam = 'a' THEN stake*e.USD ELSE 0 END)*(CASE WHEN abs(odds) <1 THEN 1 ELSE abs(odds) END) ELSE 0 END)) AS away_odds_HTUSD,
		sum((CASE WHEN bettype = 21 THEN (CASE WHEN betteam = 'a' THEN stake*e.EUR ELSE 0 END)*(CASE WHEN abs(odds) <1 THEN 1 ELSE abs(odds) END) ELSE 0 END)) AS away_odds_HTEUR,
		sum((CASE WHEN bettype = 21 THEN (CASE WHEN betteam = 'a' THEN stake*e.GBP ELSE 0 END)*(CASE WHEN abs(odds) <1 THEN 1 ELSE abs(odds) END) ELSE 0 END)) AS away_odds_HTGBP,
		--
		sum((CASE WHEN bettype = 21 THEN (CASE WHEN betteam = 'a' THEN stake ELSE 0 END)  ELSE 0 END)) AS away_odds_HT_ori,
		sum((CASE WHEN bettype = 21 THEN (CASE WHEN betteam = 'a' THEN stake*e.USD ELSE 0 END)  ELSE 0 END)) AS away_odds_HTUSD_ori,
		sum((CASE WHEN bettype = 21 THEN (CASE WHEN betteam = 'a' THEN stake*e.EUR ELSE 0 END)  ELSE 0 END)) AS away_odds_HTEUR_ori,
		sum((CASE WHEN bettype = 21 THEN (CASE WHEN betteam = 'a' THEN stake*e.GBP ELSE 0 END) ELSE 0 END)) AS away_odds_HTGBP_ori,
		
		sum(CASE WHEN bettype = 21 THEN (CASE WHEN betteam = 'h' THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds END) ELSE -actual_stake END) ELSE 0 END) AS WinLost_home_HT,
		sum(CASE WHEN bettype = 21 THEN (CASE WHEN betteam = 'h' THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds END)*e.USD ELSE -actual_stake*e.USD END) ELSE 0 END) AS WinLost_home_HTUSD,	
		sum(CASE WHEN bettype = 21 THEN (CASE WHEN betteam = 'h' THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds END)*e.EUR ELSE -actual_stake*e.EUR END) ELSE 0 END) AS WinLost_home_HTEUR,
		sum(CASE WHEN bettype = 21 THEN (CASE WHEN betteam = 'h' THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds END)*e.GBP ELSE -actual_stake*e.GBP END) ELSE 0 END) AS WinLost_home_HTGBP,		
		--
		sum(CASE WHEN bettype = 21 THEN (CASE WHEN betteam = 'h' THEN stake  END) ELSE 0 END) AS WinLost_home_HT_ori,
		sum(CASE WHEN bettype = 21 THEN (CASE WHEN betteam = 'h' THEN stake *e.USD   END) ELSE 0 END) AS WinLost_home_HTUSD_ori,	
		sum(CASE WHEN bettype = 21 THEN (CASE WHEN betteam = 'h' THEN stake *e.EUR   END) ELSE 0 END) AS WinLost_home_HTEUR_ori,
		sum(CASE WHEN bettype = 21 THEN (CASE WHEN betteam = 'h' THEN stake* e.GBP   END) ELSE 0 END) AS WinLost_home_HTGBP_ori,
		--
		sum(CASE WHEN bettype = 21 THEN (CASE WHEN betteam = 'a' THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds END) ELSE -actual_stake END) ELSE 0 END) AS WinLost_away_HT,
		sum(CASE WHEN bettype = 21 THEN (CASE WHEN betteam = 'a' THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds END)*e.USD ELSE -actual_stake*e.USD END) ELSE 0 END) AS WinLost_away_HTUSD,
		sum(CASE WHEN bettype = 21 THEN (CASE WHEN betteam = 'a' THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds END)*e.EUR ELSE -actual_stake*e.EUR END) ELSE 0 END) AS WinLost_away_HTEUR,
		sum(CASE WHEN bettype = 21 THEN (CASE WHEN betteam = 'a' THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds END)*e.GBP ELSE -actual_stake*e.GBP END) ELSE 0 END) AS WinLost_away_HTGBP,
		--
		sum(CASE WHEN bettype = 21 THEN (CASE WHEN betteam = 'a' THEN stake  ELSE 0 END) ELSE 0 END) AS WinLost_away_HT_ori,
		sum(CASE WHEN bettype = 21 THEN (CASE WHEN betteam = 'a' THEN stake *e.USD  END) ELSE 0 END) AS WinLost_away_HTUSD_ori,
		sum(CASE WHEN bettype = 21 THEN (CASE WHEN betteam = 'a' THEN stake*  e.EUR END) ELSE 0 END) AS WinLost_away_HTEUR_ori,
		sum(CASE WHEN bettype = 21 THEN (CASE WHEN betteam = 'a' THEN stake*  e.GBP END) ELSE 0 END) AS WinLost_away_HTGBP_ori,
		
		isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral
			
	FROM
		bettrans a  WITH (NOLOCK)
		INNER JOIN match 	m  WITH (NOLOCK) ON m.matchid       = a.matchid 
		INNER JOIN (SELECT *  FROM Lrf_f_GetExchangeDaily(@Today,@Today))e ON e.exchangeid = a.currency
		INNER JOIN @TempAg ag ON a.recommend = ag.CustId AND a.currency = ag.Currency
	WHERE 		
		a.bettype IN (20,21) AND
		a.statusID IN (0,1) AND
		m.eventstatus = 'running' AND
		a.tpositiontaking <> 0
		
	GROUP BY
		a.liveindicator,
		m.homeid,
		m.awayid,	
		m.matchid,
		m.matchcode,
		m.leagueid,	 
		a.livehomescore,
		a.liveawayscore,
		m.showtime,
		m.isNeutral
	ORDER BY
	m.matchcode

IF @TotalRows = 0  
BEGIN  
	SELECT @TotalRows = count(matchid) FROM @Data
END

SELECT c.* FROM
(
	SELECT
		ROW_NUMBER() over (order by matchcode) as RowNum ,
		showtime ,
	leagueid  ,
	matchcode  ,
	liveindicator  ,
	matchid  ,
	homeID  ,
	awayID  ,
	livehomescore  ,
	liveawayscore  ,
	
	home_odds  ,
	home_oddsUSD  ,
	home_oddsEUR  ,
	home_oddsGBP  ,
	
	away_odds  ,
	away_oddsUSD  ,
	away_oddsEUR  ,
	away_oddsGBP  ,
	
	WinLost_home  ,
	WinLost_homeUSD  ,
	WinLost_homeEUR  ,
	WinLost_homeGBP  ,
	
 
	WinLost_away  ,
	WinLost_awayUSD  ,
	WinLost_awayEUR  ,
	WinLost_awayGBP  ,
	
	 
	home_odds_HT  ,
	home_odds_HTUSD  ,
	home_odds_HTEUR  ,
	home_odds_HTGBP  ,
	
 
	away_odds_HT  ,
	away_odds_HTUSD  ,
	away_odds_HTEUR  ,
	away_odds_HTGBP  ,
	
	 
	WinLost_home_HT  ,
	WinLost_home_HTUSD  ,
	WinLost_home_HTEUR  ,
	WinLost_home_HTGBP  ,
	
	WinLost_away_HT  ,
	WinLost_away_HTUSD  ,
	WinLost_away_HTEUR  ,
	WinLost_away_HTGBP  ,
	
	isNeutral BIT
	FROM @Data
) c WHERE c.RowNum between @RowStart AND @RowEnd

SELECT 
	SUM(home_odds_ori) home_odds,
	SUM(home_oddsUSD_ori) home_oddsUSD,
	SUM(home_oddsEUR_ori) home_oddsEUR,
	SUM(home_oddsGBP_ori) home_oddsGBP,
	 
	SUM(away_odds_ori) away_odds,
	SUM(away_oddsUSD_ori) away_oddsUSD,
	SUM(away_oddsEUR_ori) away_oddsEUR,
	SUM(away_oddsGBP_ori) away_oddsGBP,
	
	SUM(WinLost_home_ori) WinLost_home,
	SUM(WinLost_homeUSD_ori) WinLost_homeUSD_,
	SUM(WinLost_homeEUR_ori) WinLost_homeEUR,
	SUM(WinLost_homeGBP_ori) WinLost_homeGBP,
	
	SUM(WinLost_away_ori) WinLost_away,
	SUM(WinLost_awayUSD_ori) WinLost_awayUSD,
	SUM(WinLost_awayEUR_ori) WinLost_awayEUR,
	SUM(WinLost_awayGBP_ori) WinLost_awayGBP,
	
	SUM(home_odds_HT_ori) home_odds_HT,
	SUM(home_odds_HTUSD_ori) home_odds_HTUSD,
	SUM(home_odds_HTEUR_ori) home_odds_HTEUR,
	SUM(home_odds_HTGBP_ori) home_odds_HTGBP,
	
	SUM(away_odds_HT_ori) away_odds_HT,
	SUM(away_odds_HTUSD_ori) away_odds_HTUSD,
	SUM(away_odds_HTEUR_ori) away_odds_HTEUR,
	SUM(away_odds_HTGBP_ori) away_odds_HTGBP,
	
	SUM(WinLost_home_HT_ori) WinLost_home_HT,
	SUM(WinLost_home_HTUSD_ori) WinLost_home_HTUSD,
	SUM(WinLost_home_HTEUR_ori) WinLost_home_HTEUR,
	SUM(WinLost_home_HTGBP_ori) WinLost_home_HTGBP,
	
	SUM(WinLost_away_HT_ori) WinLost_away_HT,
	SUM(WinLost_away_HTUSD_ori) WinLost_away_HTUSD,
	SUM(WinLost_away_HTEUR_ori) WinLost_away_HTEUR,
	SUM(WinLost_away_HTGBP_ori) WinLost_away_HTGBP
FROM @Data

GO

GRANT EXECUTE ON [dbo].[Lrf_TotalBets_Sel2021] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_TotalBets_Sel2021] TO [vnteam]


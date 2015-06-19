USE [bodb02]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
 

ALTER PROCEDURE [dbo].[Lrf_TotalBets_Sel25] 
	@LicenseeID INT,
	@CurrencyID INT=0,
	@UserID		INT,
	@licenseetype VARCHAR(100) = NULL,
	@PageSize INT=50,
	@PageIndex INT=0,
	@TotalRows INT=0 OUTPUT
 AS

/*
Created: 20101201@Henry
Task : Retrieve Total bets for bettype 25
DB: DB052.bodb02
Original:[Age_TotalBets_Sel25_Ag]
Revisions:
	- 201133@Alex:Allow to choose all type of licensee AND all currency + suppport based currency
	- 20110801@Henry: Remove PT + exclude BA ticket
	- 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily  
	- 20120703@Henry: Add new bettype 123 for Draw/No Draw
	- 20121004@Jim: replace @currencyname input param by @currencyID
	- 20130514@Jim:Restrict permission of Licensee Users by currency
	- 20140718@Hannah: Change liveindicator datatype to INT to fix running live matches are not being showed at the top list (RedmineID:19136)
	- 20141110@Winnie: Change from LicenseeCust table to [f_SelLicenseeCust] function
	- 20150124@Winnie: Add base currency GBP 
	- 20150413@Jim: add more bettype Odd/Even (3rd) (157) ,Extra Time 1H 1X2 (167)
	- 20150617@Jim:  Enhance Total Bets with sum values of running stakes  (Feature #36839)
Param's Explanation:
• @CustID: AgentID
*/

SET NOCOUNT ON
DECLARE @Today SMALLDATETIME 
SET @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120) 

SELECT  currencyID,LicenseeID into #currency
FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)
WHERE (@CurrencyID=0  OR (@CurrencyID<>0 AND CurrencyID=@CurrencyID))

DECLARE @TempAg AS TABLE (CustID INT)
INSERT INTO @TempAg (CustID)
SELECT  DISTINCT CustID  
                FROM    bodb_Licensee.dbo.[f_SelLicenseeCust](0) lc --WITH ( NOLOCK )
				INNER JOIN #currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID		
                WHERE  [Description] = COALESCE(@LicenseeType,  
                                                     [Description])
-------------------

-------------------
DECLARE @RowCount INT, @RowStart INT, @RowEnd INT  
SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1 

DECLARE @Data AS Table
(
	showtime NVARCHAR (50),
	leagueid INT,
	matchcode NVARCHAR(50),
	liveindicator INT,
	livehomescore INT,
	liveawayscore INT,
	matchid INT,
	homeID INT,
	awayID INT,
	bettype INT,
	
	home_odds_OE MONEY,
	home_odds_OEUSD MONEY,
	home_odds_OEEUR MONEY,
	home_odds_OEGBP MONEY,
	
	home_odds_OE_ori MONEY,
	home_odds_OEUSD_ori MONEY,
	home_odds_OEEUR_ori MONEY,
	home_odds_OEGBP_ori MONEY,
	
	away_odds_OE MONEY,
	away_odds_OEUSD MONEY,
	away_odds_OEEUR MONEY,
	away_odds_OEGBP MONEY,
	
	away_odds_OE_ori MONEY,
	away_odds_OEUSD_ori MONEY,
	away_odds_OEEUR_ori MONEY,
	away_odds_OEGBP_ori MONEY,
	
	home_odds_OE_1st MONEY,
	home_odds_OE_1stUSD MONEY,
	home_odds_OE_1stEUR MONEY,
	home_odds_OE_1stGBP MONEY,
	
	home_odds_OE_1st_ori MONEY,
	home_odds_OE_1stUSD_ori MONEY,
	home_odds_OE_1stEUR_ori MONEY,
	home_odds_OE_1stGBP_ori MONEY,
	
	away_odds_OE_1st MONEY,
	away_odds_OE_1stUSD MONEY,
	away_odds_OE_1stEUR MONEY,
	away_odds_OE_1stGBP MONEY,
	
	away_odds_OE_1st_ori MONEY,
	away_odds_OE_1stUSD_ori MONEY,
	away_odds_OE_1stEUR_ori MONEY,
	away_odds_OE_1stGBP_ori MONEY,
	
	odds_1 MONEY,
	odds_1USD MONEY,
	odds_1EUR MONEY,
	odds_1GBP MONEY,
	
	odds_x MONEY,
	odds_xUSD MONEY,
	odds_xEUR MONEY,
	odds_xGBP MONEY,
	
	odds_2 MONEY,
	odds_2USD MONEY,
	odds_2EUR MONEY,
	odds_2GBP MONEY,
	
	odds_1_1st MONEY,
	odds_1_1stUSD MONEY,
	odds_1_1stEUR MONEY,
	odds_1_1stGBP MONEY,
	
	odds_x_1st MONEY,
	odds_x_1stUSD MONEY,
	odds_x_1stEUR MONEY,
	odds_x_1stGBP MONEY,
	
	odds_2_1st MONEY,
	odds_2_1stUSD MONEY,
	odds_2_1stEUR MONEY,
	odds_2_1stGBP MONEY,
	
	home_odds_DND MONEY,
	home_odds_DNDUSD MONEY,
	home_odds_DNDEUR MONEY,
	home_odds_DNDGBP MONEY,
	
	away_odds_DND MONEY,
	away_odds_DNDUSD MONEY,
	away_odds_DNDEUR MONEY,
	away_odds_DNDGBP MONEY,
	
	BetCount_OE INT,
	BetCount_OE_1st INT,
	BetCount_1x2 INT,
	BetCount_1x2_1st INT,
	BetCount_DND INT,
	isNeutral BIT
)

INSERT INTO @Data
SELECT 
		m.showtime, 
		m.leagueid,
		m.matchcode, 
		a.liveindicator, 
		a.livehomescore,
		a.liveawayscore,
		m.matchid,
		m.homeid,
		m.awayid,
		CASE  WHEN a.bettype IN (2,12) THEN 2
			  WHEN a.bettype IN (5,15) THEN 5	
			  ELSE a.bettype END  bettype,
		sum((CASE WHEN bettype in (2,157) AND betteam = 'h' THEN stake ELSE 0 END)*(CASE WHEN ABS(odds) <1 THEN 1 ELSE ABS(odds) END)) AS home_odds_OE,
		sum((CASE WHEN bettype in (2,157) AND betteam = 'h' THEN stake*e.USD ELSE 0 END)*(CASE WHEN ABS(odds) <1 THEN 1 ELSE ABS(odds) END)) AS home_odds_OEUSD,
		sum((CASE WHEN bettype in (2,157) AND betteam = 'h' THEN stake*e.EUR ELSE 0 END)*(CASE WHEN ABS(odds) <1 THEN 1 ELSE ABS(odds) END)) AS home_odds_OEEUR,
		sum((CASE WHEN bettype in (2,157) AND betteam = 'h' THEN stake*e.GBP ELSE 0 END)*(CASE WHEN ABS(odds) <1 THEN 1 ELSE ABS(odds) END)) AS home_odds_OEGBP,
		--
		sum((CASE WHEN bettype in (2,157) AND betteam = 'h' THEN stake ELSE 0 END)) AS home_odds_OE_ori,
		sum((CASE WHEN bettype in (2,157) AND betteam = 'h' THEN stake*e.USD ELSE 0 END)) AS home_odds_OEUSD_ori,
		sum((CASE WHEN bettype in (2,157) AND betteam = 'h' THEN stake*e.EUR ELSE 0 END)) AS home_odds_OEEUR_ori,
		sum((CASE WHEN bettype in (2,157) AND betteam = 'h' THEN stake*e.GBP ELSE 0 END)) AS home_odds_OEGBP_ori,
		
		sum((CASE WHEN bettype in (2,157) AND betteam = 'a' THEN stake ELSE 0 END)*(CASE WHEN ABS(odds) <1 THEN 1 ELSE ABS(odds) END)) AS away_odds_OE,
		sum((CASE WHEN bettype in (2,157) AND betteam = 'a' THEN stake*e.USD ELSE 0 END)*(CASE WHEN ABS(odds) <1 THEN 1 ELSE ABS(odds) END)) AS away_odds_OEUSD,
		sum((CASE WHEN bettype in (2,157) AND betteam = 'a' THEN stake*e.EUR ELSE 0 END)*(CASE WHEN ABS(odds) <1 THEN 1 ELSE ABS(odds) END)) AS away_odds_OEEUR,
		sum((CASE WHEN bettype in (2,157) AND betteam = 'a' THEN stake*e.GBP ELSE 0 END)*(CASE WHEN ABS(odds) <1 THEN 1 ELSE ABS(odds) END)) AS away_odds_OEGBP,
		--
		sum((CASE WHEN bettype in (2,157) AND betteam = 'a' THEN stake ELSE 0 END) ) AS away_odds_OE_ori,
		sum((CASE WHEN bettype in (2,157) AND betteam = 'a' THEN stake*e.USD ELSE 0 END)) AS away_odds_OEUSD_ori,
		sum((CASE WHEN bettype in (2,157) AND betteam = 'a' THEN stake*e.EUR ELSE 0 END)) AS away_odds_OEEUR_ori,
		sum((CASE WHEN bettype in (2,157) AND betteam = 'a' THEN stake*e.GBP ELSE 0 END)) AS away_odds_OEGBP_ori,
		
		sum((CASE WHEN bettype=12 AND betteam = 'h' THEN stake ELSE 0 END)*(CASE WHEN ABS(odds) <1 THEN 1 ELSE ABS(odds) END)) AS home_odds_OE_1st,
		sum((CASE WHEN bettype=12 AND betteam = 'h' THEN stake*e.USD ELSE 0 END)*(CASE WHEN ABS(odds) <1 THEN 1 ELSE ABS(odds) END)) AS home_odds_OE_1stUSD,
		sum((CASE WHEN bettype=12 AND betteam = 'h' THEN stake*e.EUR ELSE 0 END)*(CASE WHEN ABS(odds) <1 THEN 1 ELSE ABS(odds) END)) AS home_odds_OE_1stEUR,
		sum((CASE WHEN bettype=12 AND betteam = 'h' THEN stake*e.GBP ELSE 0 END)*(CASE WHEN ABS(odds) <1 THEN 1 ELSE ABS(odds) END)) AS home_odds_OE_1stGBP,
		--
		sum((CASE WHEN bettype=12 AND betteam = 'h' THEN stake ELSE 0 END)) AS home_odds_OE_1st_ori,
		sum((CASE WHEN bettype=12 AND betteam = 'h' THEN stake*e.USD ELSE 0 END)) AS home_odds_OE_1stUSD_ori,
		sum((CASE WHEN bettype=12 AND betteam = 'h' THEN stake*e.EUR ELSE 0 END)) AS home_odds_OE_1stEUR_ori,
		sum((CASE WHEN bettype=12 AND betteam = 'h' THEN stake*e.GBP ELSE 0 END)) AS home_odds_OE_1stGBP_ori,
		
		sum((CASE WHEN bettype=12 AND betteam = 'a' THEN stake ELSE 0 END)*(CASE WHEN ABS(odds) <1 THEN 1 ELSE ABS(odds) END)) AS away_odds_OE_1st,
		sum((CASE WHEN bettype=12 AND betteam = 'a' THEN stake*e.USD ELSE 0 END)*(CASE WHEN ABS(odds) <1 THEN 1 ELSE ABS(odds) END)) AS away_odds_OE_1stUSD,
		sum((CASE WHEN bettype=12 AND betteam = 'a' THEN stake*e.EUR ELSE 0 END)*(CASE WHEN ABS(odds) <1 THEN 1 ELSE ABS(odds) END)) AS away_odds_OE_1stEUR,
		sum((CASE WHEN bettype=12 AND betteam = 'a' THEN stake*e.GBP ELSE 0 END)*(CASE WHEN ABS(odds) <1 THEN 1 ELSE ABS(odds) END)) AS away_odds_OE_1stGBP,
		--
		sum((CASE WHEN bettype=12 AND betteam = 'a' THEN stake ELSE 0 END)) AS away_odds_OE_1st_ori,
		sum((CASE WHEN bettype=12 AND betteam = 'a' THEN stake*e.USD ELSE 0 END)) AS away_odds_OE_1stUSD_ori,
		sum((CASE WHEN bettype=12 AND betteam = 'a' THEN stake*e.EUR ELSE 0 END)) AS away_odds_OE_1stEUR_ori,
		sum((CASE WHEN bettype=12 AND betteam = 'a' THEN stake*e.GBP ELSE 0 END)) AS away_odds_OE_1stGBP_ori,
		
		--league.lcolor,
		sum(CASE WHEN bettype=5 AND betteam = '1' THEN  stake   ELSE 0 END) AS odds_1,
		sum(CASE WHEN bettype=5 AND betteam = '1' THEN  stake*e.USD   ELSE 0 END) AS odds_1USD,
		sum(CASE WHEN bettype=5 AND betteam = '1' THEN  stake*e.EUR   ELSE 0 END) AS odds_1EUR,
		sum(CASE WHEN bettype=5 AND betteam = '1' THEN  stake*e.GBP   ELSE 0 END) AS odds_1GBP,
		
		sum(CASE WHEN bettype=5 AND betteam = 'x' THEN  stake   ELSE 0 END) AS odds_x,
		sum(CASE WHEN bettype=5 AND betteam = 'x' THEN  stake*e.USD   ELSE 0 END) AS odds_xUSD,
		sum(CASE WHEN bettype=5 AND betteam = 'x' THEN  stake*e.EUR   ELSE 0 END) AS odds_xEUR,
		sum(CASE WHEN bettype=5 AND betteam = 'x' THEN  stake*e.GBP   ELSE 0 END) AS odds_xGBP,

		sum(CASE WHEN bettype=5 AND betteam = '2' THEN  stake   ELSE 0 END) AS odds_2,
		sum(CASE WHEN bettype=5 AND betteam = '2' THEN  stake*e.USD   ELSE 0 END) AS odds_2USD,
		sum(CASE WHEN bettype=5 AND betteam = '2' THEN  stake*e.EUR   ELSE 0 END) AS odds_2EUR,
		sum(CASE WHEN bettype=5 AND betteam = '2' THEN  stake*e.GBP   ELSE 0 END) AS odds_2GBP,

		sum(CASE WHEN bettype IN (15,167) AND betteam = '1' THEN  stake   ELSE 0 END) AS odds_1_1st,
		sum(CASE WHEN bettype IN (15,167) AND betteam = '1' THEN  stake*e.USD   ELSE 0 END) AS odds_1_1stUSD,
		sum(CASE WHEN bettype IN (15,167) AND betteam = '1' THEN  stake*e.EUR   ELSE 0 END) AS odds_1_1stEUR,
		sum(CASE WHEN bettype IN (15,167) AND betteam = '1' THEN  stake*e.GBP   ELSE 0 END) AS odds_1_1stGBP,
		
		sum(CASE WHEN bettype IN (15,167) AND betteam = 'x' THEN  stake   ELSE 0 END) AS odds_x_1st,
		sum(CASE WHEN bettype IN (15,167) AND betteam = 'x' THEN  stake*e.USD   ELSE 0 END) AS odds_x_1stUSD,
		sum(CASE WHEN bettype IN (15,167) AND betteam = 'x' THEN  stake*e.EUR   ELSE 0 END) AS odds_x_1stEUR,
		sum(CASE WHEN bettype IN (15,167) AND betteam = 'x' THEN  stake*e.GBP   ELSE 0 END) AS odds_x_1stGBP,
		
		sum(CASE WHEN bettype IN (15,167) AND betteam = '2' THEN  stake   ELSE 0 END) AS odds_2_1st,
		sum(CASE WHEN bettype IN (15,167) AND betteam = '2' THEN  stake*e.USD   ELSE 0 END) AS odds_2_1stUSD,
		sum(CASE WHEN bettype IN (15,167) AND betteam = '2' THEN  stake*e.EUR   ELSE 0 END) AS odds_2_1stEUR,
		sum(CASE WHEN bettype IN (15,167) AND betteam = '2' THEN  stake*e.GBP   ELSE 0 END) AS odds_2_1stGBP,

		sum(Case when bettype=123 and betteam = 'h' then  stake   else 0 end) AS home_odds_DND,
		sum(Case when bettype=123 and betteam = 'h' then  stake*e.USD   else 0 end) AS home_odds_DNDUSD,
		sum(Case when bettype=123 and betteam = 'h' then  stake*e.EUR   else 0 end) AS home_odds_DNDEUR,
		sum(Case when bettype=123 and betteam = 'h' then  stake*e.GBP   else 0 end) AS home_odds_DNDGBP,
		
		sum(Case when bettype=123 and betteam = 'a' then  stake   else 0 end) AS away_odds_DND,
		sum(Case when bettype=123 and betteam = 'a' then  stake*e.USD   else 0 end) AS away_odds_DNDUSD,
		sum(Case when bettype=123 and betteam = 'a' then  stake*e.EUR   else 0 end) AS away_odds_DNDEUR,
		sum(Case when bettype=123 and betteam = 'a' then  stake*e.GBP   else 0 end) AS away_odds_DNDGBP,

		sum(CASE WHEN bettype in (2,157)  THEN 1 ELSE 0 END) AS BetCount_OE,
		sum(CASE WHEN bettype=12 THEN 1 ELSE 0 END) AS BetCount_OE_1st,
		sum(CASE WHEN bettype=5 THEN 1 ELSE 0 END) AS BetCount_1x2,
		sum(CASE WHEN bettype IN (15,167) THEN 1 ELSE 0 END) AS BetCount_1x2_1st,
		sum(case when bettype=123 then 1 else 0 end) as BetCount_DND,
		isnull(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral
	FROM
		bettrans AS a  WITH (NOLOCK)
		INNER JOIN match AS m  WITH (NOLOCK) ON m.matchid       = a.matchid 
		INNER JOIN (SELECT *  FROM Lrf_f_GetExchangeDaily(@Today,@Today))e 
		ON e.exchangeid = a.currency
	WHERE  	
		a.recommend IN (SELECT CustID FROM @TempAg) AND
		 ((@CurrencyID=0 AND currency IN (SELECT currencyId FROM #currency))  OR (@CurrencyID<>0 AND Currency=@CurrencyID)) AND
		a.bettype in (2, 12, 5, 15,123,157,167)
		AND a.statusID in (0,1)
		AND a.ruben = 0
		AND m.eventstatus='running'
		AND a.tpositiontaking <> 0
	GROUP BY a.liveindicator, 
		a.livehomescore,
		a.liveawayscore,
		m.homeid,
		m.awayid,
		m.matchid,
		m.matchcode, 
		m.leagueid,
		m.showtime,
		m.isNeutral,
		CASE  WHEN a.bettype IN (2,12) THEN 2
			  WHEN a.bettype IN (5,15) THEN 5	
			  ELSE a.bettype END
		
	ORDER BY m.matchcode

IF @TotalRows = 0  
BEGIN  
	SELECT @TotalRows = COUNT(matchid) FROM @Data
END

SELECT c.* FROM
(
	SELECT 
		ROW_NUMBER() over (ORDER BY matchcode) AS RowNum ,
		*
	FROM @Data
) c WHERE c.RowNum BETWEEN @RowStart AND @RowEnd

SELECT 
	SUM(home_odds_OE_ori) home_odds_OE ,
	SUM(home_odds_OEUSD_ori) home_odds_OEUSD,
	SUM(home_odds_OEEUR_ori) home_odds_OEEUR ,
	SUM(home_odds_OEGBP_ori) home_odds_OEGBP ,
	
	 
	SUM(away_odds_OE_ori) away_odds_OE ,
	SUM(away_odds_OEUSD_ori) away_odds_OEUSD ,
	SUM(away_odds_OEEUR_ori) away_odds_OEEUR ,
	SUM(away_odds_OEGBP_ori) away_odds_OEGBP,
	
	 
	
	SUM(home_odds_OE_1st_ori) home_odds_OE_1st,
	SUM(home_odds_OE_1stUSD_ori) home_odds_OE_1stUSD,
	SUM(home_odds_OE_1stEUR_ori) home_odds_OE_1stEUR,
	SUM(home_odds_OE_1stGBP_ori) home_odds_OE_1stGBP,
	
	 
	SUM(away_odds_OE_1st_ori) away_odds_OE_1st,
	SUM(away_odds_OE_1stUSD_ori) away_odds_OE_1stUSD,
	SUM(away_odds_OE_1stEUR_ori) away_odds_OE_1stEUR,
	SUM(away_odds_OE_1stGBP_ori) away_odds_OE_1stGBP,
	
	SUM(odds_1) odds_1,
	SUM(odds_1USD) odds_1USD,
	SUM(odds_1EUR) odds_1EUR,
	SUM(odds_1GBP) odds_1GBP,
	
	SUM(odds_x) odds_x,
	SUM(odds_xUSD) odds_xUSD,
	SUM(odds_xEUR) odds_xEUR,
	SUM(odds_xGBP) odds_xGBP,
	
	SUM(odds_2) odds_2,
	SUM(odds_2USD) odds_2USD,
	SUM(odds_2EUR) odds_2EUR,
	SUM(odds_2GBP) odds_2GBP,
	
	SUM(odds_1_1st) odds_1_1st,
	SUM(odds_1_1stUSD) odds_1_1stUSD,
	SUM(odds_1_1stEUR) odds_1_1stEUR,
	SUM(odds_1_1stGBP) odds_1_1stGBP,
	
	SUM(odds_x_1st) odds_x_1st,
	SUM(odds_x_1stUSD) odds_x_1stUSD,
	SUM(odds_x_1stEUR) odds_x_1stEUR,
	SUM(odds_x_1stGBP) odds_x_1stGBP,
	
	SUM(odds_2_1st) odds_2_1st,
	SUM(odds_2_1stUSD) odds_2_1stUSD,
	SUM(odds_2_1stEUR) odds_2_1stEUR,
	SUM(odds_2_1stGBP) odds_2_1stGBP,
	
	SUM(home_odds_DND) home_odds_DND,
	SUM(home_odds_DNDUSD) home_odds_DNDUSD,
	SUM(home_odds_DNDEUR) home_odds_DNDEUR,
	SUM(home_odds_DNDGBP) home_odds_DNDGBP,
	
	SUM(away_odds_DND) away_odds_DND,
	SUM(away_odds_DNDUSD) away_odds_DNDUSD,
	SUM(away_odds_DNDEUR) away_odds_DNDEUR,
	SUM(away_odds_DNDGBP) away_odds_DNDGBP
FROM @Data
DROP TABLE #currency

GO
GRANT EXECUTE ON [dbo].[Lrf_TotalBets_Sel25] TO [bodbLicenseeNet]

GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_TotalBets_Sel25] TO [vnteam]
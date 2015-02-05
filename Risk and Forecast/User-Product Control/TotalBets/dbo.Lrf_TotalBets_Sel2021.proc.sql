USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_TotalBets_Sel2021]    Script Date: 02/20/2014 18:31:06 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.Lrf_TotalBets_Sel2021    Script Date: 6/26/2013 10:58:31 PM ******/
/****** Object:  Stored Procedure dbo.Lrf_TotalBets_Sel2021    Script Date: 5/31/2013 2:41:29 PM ******/
ALTER PROCEDURE [dbo].[Lrf_TotalBets_Sel2021]
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
Task: Retrieve Total Bet values for MoneyLine.
DB: DB052.bodb02
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
*/
SET NOCOUNT ON

DECLARE @Today smalldatetime 
SET @Today = convert(VARCHAR(10), CURRENT_TIMESTAMP, 120) 

SELECT  currencyID,LicenseeID into #currency
FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)
WHERE (@CurrencyID=0  OR (@CurrencyID<>0 AND CurrencyID=@CurrencyID))

DECLARE @TempAg as TABLE (CustID INT)
INSERT INTO @TempAg (CustID)
SELECT DISTINCT CustID  
                FROM    bodb_Licensee.dbo.[f_SelLicenseeCust](0) lc --WITH ( NOLOCK ) 
				INNER JOIN #currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID
                WHERE   [Description] = COALESCE(@LicenseeType,  
                                                     [Description])
-------------------------

-----------------------
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

	away_odds MONEY,
	away_oddsUSD MONEY,
	away_oddsEUR MONEY,
	away_oddsGBP MONEY,
	
	WinLost_home MONEY,
	WinLost_homeUSD MONEY,
	WinLost_homeEUR MONEY,
	WinLost_homeGBP MONEY,

	WinLost_away MONEY,
	WinLost_awayUSD MONEY,
	WinLost_awayEUR MONEY,
	WinLost_awayGBP MONEY,
	
	home_odds_HT MONEY,
	home_odds_HTUSD MONEY,
	home_odds_HTEUR MONEY,
	home_odds_HTGBP MONEY,

	away_odds_HT MONEY,
	away_odds_HTUSD MONEY,
	away_odds_HTEUR MONEY,
	away_odds_HTGBP MONEY,
	
	WinLost_home_HT MONEY,
	WinLost_home_HTUSD MONEY,
	WinLost_home_HTEUR MONEY,
	WinLost_home_HTGBP MONEY,

	WinLost_away_HT MONEY,
	WinLost_away_HTUSD MONEY,
	WinLost_away_HTEUR MONEY,
	WinLost_away_HTGBP MONEY,
	
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

		sum((CASE WHEN bettype = 20 THEN (CASE WHEN betteam = 'a' THEN stake ELSE 0 END)*(CASE WHEN abs(odds) <1 THEN 1 ELSE abs(odds) END) ELSE 0 END)) AS away_odds,
		sum((CASE WHEN bettype = 20 THEN (CASE WHEN betteam = 'a' THEN stake*e.USD ELSE 0 END)*(CASE WHEN abs(odds) <1 THEN 1 ELSE abs(odds) END) ELSE 0 END)) AS away_oddsUSD,
		sum((CASE WHEN bettype = 20 THEN (CASE WHEN betteam = 'a' THEN stake*e.EUR ELSE 0 END)*(CASE WHEN abs(odds) <1 THEN 1 ELSE abs(odds) END) ELSE 0 END)) AS away_oddsEUR,
		sum((CASE WHEN bettype = 20 THEN (CASE WHEN betteam = 'a' THEN stake*e.GBP ELSE 0 END)*(CASE WHEN abs(odds) <1 THEN 1 ELSE abs(odds) END) ELSE 0 END)) AS away_oddsGBP,

		sum(CASE WHEN bettype = 20 THEN (CASE WHEN betteam = 'h' THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds END) ELSE -actual_stake END) ELSE 0 END ) AS WinLost_home,
		sum(CASE WHEN bettype = 20 THEN (CASE WHEN betteam = 'h' THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds END)*e.USD ELSE -actual_stake*e.USD END) ELSE 0 END ) AS WinLost_homeUSD,
		sum(CASE WHEN bettype = 20 THEN (CASE WHEN betteam = 'h' THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds END)*e.EUR ELSE -actual_stake*e.EUR END) ELSE 0 END ) AS WinLost_homeEUR,
		sum(CASE WHEN bettype = 20 THEN (CASE WHEN betteam = 'h' THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds END)*e.GBP ELSE -actual_stake*e.GBP END) ELSE 0 END ) AS WinLost_homeGBP,
		
		sum(CASE WHEN bettype = 20 THEN (CASE WHEN betteam = 'a' THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds END) ELSE -actual_stake END) ELSE 0 END) AS WinLost_away,
		sum(CASE WHEN bettype = 20 THEN (CASE WHEN betteam = 'a' THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds END)*e.USD ELSE -actual_stake*e.USD END) ELSE 0 END) AS WinLost_awayUSD,
		sum(CASE WHEN bettype = 20 THEN (CASE WHEN betteam = 'a' THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds END)*e.EUR ELSE -actual_stake*e.EUR END) ELSE 0 END) AS WinLost_awayEUR,
		sum(CASE WHEN bettype = 20 THEN (CASE WHEN betteam = 'a' THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds END)*e.GBP ELSE -actual_stake*e.GBP END) ELSE 0 END) AS WinLost_awayGBP,

		sum((CASE WHEN bettype = 21 THEN (CASE WHEN betteam = 'h' THEN stake ELSE 0 END)*(CASE WHEN abs(odds) <1 THEN 1 ELSE abs(odds) END) ELSE 0 END)) AS home_odds_HT,
		sum((CASE WHEN bettype = 21 THEN (CASE WHEN betteam = 'h' THEN stake*e.USD ELSE 0 END)*(CASE WHEN abs(odds) <1 THEN 1 ELSE abs(odds) END) ELSE 0 END)) AS home_odds_HTUSD,
		sum((CASE WHEN bettype = 21 THEN (CASE WHEN betteam = 'h' THEN stake*e.EUR ELSE 0 END)*(CASE WHEN abs(odds) <1 THEN 1 ELSE abs(odds) END) ELSE 0 END)) AS home_odds_HTEUR,
		sum((CASE WHEN bettype = 21 THEN (CASE WHEN betteam = 'h' THEN stake*e.GBP ELSE 0 END)*(CASE WHEN abs(odds) <1 THEN 1 ELSE abs(odds) END) ELSE 0 END)) AS home_odds_HTGBP,

		sum((CASE WHEN bettype = 21 THEN (CASE WHEN betteam = 'a' THEN stake ELSE 0 END)*(CASE WHEN abs(odds) <1 THEN 1 ELSE abs(odds) END) ELSE 0 END)) AS away_odds_HT,
		sum((CASE WHEN bettype = 21 THEN (CASE WHEN betteam = 'a' THEN stake*e.USD ELSE 0 END)*(CASE WHEN abs(odds) <1 THEN 1 ELSE abs(odds) END) ELSE 0 END)) AS away_odds_HTUSD,
		sum((CASE WHEN bettype = 21 THEN (CASE WHEN betteam = 'a' THEN stake*e.EUR ELSE 0 END)*(CASE WHEN abs(odds) <1 THEN 1 ELSE abs(odds) END) ELSE 0 END)) AS away_odds_HTEUR,
		sum((CASE WHEN bettype = 21 THEN (CASE WHEN betteam = 'a' THEN stake*e.GBP ELSE 0 END)*(CASE WHEN abs(odds) <1 THEN 1 ELSE abs(odds) END) ELSE 0 END)) AS away_odds_HTGBP,


		sum(CASE WHEN bettype = 21 THEN (CASE WHEN betteam = 'h' THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds END) ELSE -actual_stake END) ELSE 0 END) AS WinLost_home_HT,
		sum(CASE WHEN bettype = 21 THEN (CASE WHEN betteam = 'h' THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds END)*e.USD ELSE -actual_stake*e.USD END) ELSE 0 END) AS WinLost_home_HTUSD,	
		sum(CASE WHEN bettype = 21 THEN (CASE WHEN betteam = 'h' THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds END)*e.EUR ELSE -actual_stake*e.EUR END) ELSE 0 END) AS WinLost_home_HTEUR,
		sum(CASE WHEN bettype = 21 THEN (CASE WHEN betteam = 'h' THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds END)*e.GBP ELSE -actual_stake*e.GBP END) ELSE 0 END) AS WinLost_home_HTGBP,		

		sum(CASE WHEN bettype = 21 THEN (CASE WHEN betteam = 'a' THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds END) ELSE -actual_stake END) ELSE 0 END) AS WinLost_away_HT,
		sum(CASE WHEN bettype = 21 THEN (CASE WHEN betteam = 'a' THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds END)*e.USD ELSE -actual_stake*e.USD END) ELSE 0 END) AS WinLost_away_HTUSD,
		sum(CASE WHEN bettype = 21 THEN (CASE WHEN betteam = 'a' THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds END)*e.EUR ELSE -actual_stake*e.EUR END) ELSE 0 END) AS WinLost_away_HTEUR,
		sum(CASE WHEN bettype = 21 THEN (CASE WHEN betteam = 'a' THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds END)*e.GBP ELSE -actual_stake*e.GBP END) ELSE 0 END) AS WinLost_away_HTGBP,

		isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral
			
	FROM
		bettrans a  WITH (NOLOCK)
		INNER JOIN match 	m  WITH (NOLOCK) ON m.matchid       = a.matchid 
		INNER JOIN (SELECT *  FROM Lrf_f_GetExchangeDaily(@Today,@Today))e 
		ON e.exchangeid = a.currency
	WHERE 
		a.recommend  IN (SELECT CustID FROM @TempAg) AND
		((@CurrencyID=0 AND currency IN (SELECT currencyId FROM #currency))  OR (@CurrencyID<>0 AND Currency=@CurrencyID)) AND
		a.bettype IN (20,21) AND
		a.statusID = 0 AND
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
		*
	FROM @Data
) c WHERE c.RowNum between @RowStart AND @RowEnd
DROP TABLE #currency
GO
GRANT EXECUTE ON [dbo].[Lrf_TotalBets_Sel2021] TO [bodbLicenseeNet]

GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_TotalBets_Sel2021] TO [vnteam]


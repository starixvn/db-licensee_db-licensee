ALTER PROCEDURE [dbo].[Lrf_TotalBets_Sel121] 
	@LicenseeID INT,
	@UserID		INT,
	@CurrencyID INT=0,
	@licenseetype VARCHAR(100) = NULL,
	@PageSize INT=50,
	@PageIndex INT=0,
	@TotalRows INT=0 OUTPUT
 AS

/*
Created: 20120703@Henry
Task : Retrieve Total bets for bettype No Bet (Home/Draw/Away No bet)
DB: DB052.bodb02
Original:
Revisions:
	 - 20121004@Jim: replace @currencyname input param by @currencyID
	 - 20130514@Jim:Restrict permission of Licensee Users by currency
	 - 20140718@Hannah: Change liveindicator datatype to INT to fix running live matches are not being showed at the top list (RedmineID:19136)
	 - 20141110@Winnie: Change from LicenseeCust table to [f_SelLicenseeCust] function
	 - 20150123@Jim: support base on Currency GBP
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
                WHERE    [Description] = COALESCE(@LicenseeType,  
                                                     [Description])
-------------------------

-------------------------

DECLARE @RowCount INT, @RowStart INT, @RowEnd INT  
SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1 

DECLARE @Data AS Table
(
	currency INT,
	showtime NVARCHAR (50),
	leagueid INT,
	matchcode NVARCHAR(50),
	liveindicator INT,
	livehomescore INT,
	liveawayscore INT,
	matchid INT,
	homeID INT,
	awayID INT,

	home_odds_DNB MONEY,
	away_odds_DNB MONEY,
	home_odds_HNB MONEY,
	away_odds_HNB MONEY,
	home_odds_ANB MONEY,
	away_odds_ANB MONEY,

	BetCount_DNB INT,
	BetCount_HNB INT,
	BetCount_ANB INT,
	isNeutral BIT
)

INSERT INTO @Data
SELECT 
		b.currency,
		m.showtime, 
		m.leagueid,
		m.matchcode, 
		b.liveindicator, 
		b.livehomescore,
		b.liveawayscore,
		m.matchid,
		m.homeid,
		m.awayid,
		sum(Case when bettype=25 and betteam = 'h' then  stake   else 0 end) AS home_odds_DNB,
		sum(Case when bettype=25 and betteam = 'a' then  stake   else 0 end) AS away_odds_DNB,

		sum(Case when bettype=121 and betteam = 'x' then  stake   else 0 end) AS home_odds_HNB,
		sum(Case when bettype=121 and betteam = 'a' then  stake   else 0 end) AS away_odds_HNB,
		
		sum(Case when bettype=122 and betteam = 'h' then  stake   else 0 end) AS home_odds_ANB,
		sum(Case when bettype=122 and betteam = 'x' then  stake   else 0 end) AS away_odds_ANB,

		sum(case when bettype=25 then 1 else 0 end) as BetCount_DNB,
		sum(case when bettype=121 then 1 else 0 end) as BetCount_HNB,
		sum(case when bettype=122 then 1 else 0 end) as BetCount_ANB,
		isnull(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral
	FROM
		bettrans AS b  WITH (NOLOCK)
		INNER JOIN match AS m  WITH (NOLOCK) ON m.matchid = b.matchid and m.eventstatus='running'
	WHERE  	
		b.recommend IN (SELECT CustID FROM @TempAg) AND
		 ((@CurrencyID=0 AND currency IN (SELECT currencyId FROM #currency))   OR (@CurrencyID<>0 AND Currency=@CurrencyID)) 
		AND b.bettype in (25,121,122)
		AND b.statusID in (0,1)
		AND b.ruben = 0
		AND b.tpositiontaking <> 0
	GROUP BY 
		b.currency,
		b.liveindicator, 
		b.livehomescore,
		b.liveawayscore,
		m.homeid,
		m.awayid,
		m.matchid,
		m.matchcode, 
		m.leagueid,
		m.showtime,
		m.isNeutral
	ORDER BY m.matchcode

IF @TotalRows = 0  
BEGIN  
	SELECT @TotalRows = COUNT(matchid) FROM @Data
END

SELECT * INTO #TempExchange 
FROM Lrf_f_GetExchangeDaily(@Today,@Today)
WHERE exchangeid IN (SELECT DISTINCT Currency FROM @Data)

SELECT c.* FROM
(
	SELECT 
		ROW_NUMBER() over (ORDER BY matchcode) AS RowNum ,
		*,
		home_odds_DNB * e.USD home_odds_DNBUSD,
		home_odds_DNB * e.EUR home_odds_DNBEUR,
		home_odds_DNB * e.GBP home_odds_DNBGBP,
		
		away_odds_DNB * e.USD away_odds_DNBUSD,
		away_odds_DNB * e.EUR away_odds_DNBEUR,
		away_odds_DNB * e.GBP away_odds_DNBGBP,
		
		home_odds_HNB * e.USD home_odds_HNBUSD,
		home_odds_HNB * e.EUR home_odds_HNBEUR,
		home_odds_HNB * e.GBP home_odds_HNBGBP,
		
		away_odds_HNB * e.USD away_odds_HNBUSD,
		away_odds_HNB * e.EUR away_odds_HNBEUR,
		away_odds_HNB * e.GBP away_odds_HNBGBP,
		
		home_odds_ANB * e.USD home_odds_ANBUSD,
		home_odds_ANB * e.EUR home_odds_ANBEUR,
		home_odds_ANB * e.GBP home_odds_ANBGBP,
		
		away_odds_ANB * e.USD away_odds_ANBUSD,
		away_odds_ANB * e.EUR away_odds_ANBEUR,
		away_odds_ANB * e.GBP away_odds_ANBGBP
		
	FROM @Data b
	INNER JOIN #TempExchange e ON b.currency = e.exchangeid
) c WHERE c.RowNum BETWEEN @RowStart AND @RowEnd
DROP TABLE #currency

GO
GRANT EXECUTE ON [dbo].[Lrf_TotalBets_Sel121] TO [bodbLicenseeNet]

GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_TotalBets_Sel121] TO [vnteam]

 
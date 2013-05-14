ALTER PROCEDURE [dbo].[Lrf_TotalBets_Sel25] 
	@LicenseeID INT,
	@CurrencyID INT=0,
	@licenseetype VARCHAR(100) = NULL,
	@PageSize INT=50,
	@PageIndex INT=0,
	@TotalRows INT=0 OUTPUT
 AS

/*
Created: 20101201@Henry
Task : Retrieve Total bets for bettype 25
DB: DB05.bodb02
Original:[Age_TotalBets_Sel25_Ag]
Revisions:
	- 201133@Alex:Allow to choose all type of licensee AND all currency + suppport based currency
	- 20110801@Henry: Remove PT + exclude BA ticket
	- 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily  
	- 20120703@Henry: Add new bettype 123 for Draw/No Draw
	- 20121004@Jim: replace @currencyname input param by @currencyID
	 

Param's Explanation:
• @CustID: AgentID
*/

SET NOCOUNT ON
DECLARE @Today SMALLDATETIME 
SET @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120) 

DECLARE @TempAg AS TABLE (CustID INT)
INSERT INTO @TempAg (CustID)
SELECT  CustID  
                FROM    bodb_Licensee.dbo.LicenseeCust WITH ( NOLOCK )  
                WHERE   LicenseeID = @LicenseeID  
                        AND  (@CurrencyID=0 OR (@CurrencyID <> 0 AND  Currency = @CurrencyID))
                        AND [Description] = COALESCE(@LicenseeType,  
                                                     [Description])

DECLARE @RowCount INT, @RowStart INT, @RowEnd INT  
SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1 

DECLARE @Data AS Table
(
	showtime NVARCHAR (50),
	leagueid INT,
	matchcode NVARCHAR(50),
	liveindicator BIT,
	livehomescore INT,
	liveawayscore INT,
	matchid INT,
	homeID INT,
	awayID INT,

	home_odds_OE MONEY,
	home_odds_OEUSD MONEY,
	home_odds_OEEUR MONEY,

	away_odds_OE MONEY,
	away_odds_OEUSD MONEY,
	away_odds_OEEUR MONEY,

	home_odds_OE_1st MONEY,
	home_odds_OE_1stUSD MONEY,
	home_odds_OE_1stEUR MONEY,

	away_odds_OE_1st MONEY,
	away_odds_OE_1stUSD MONEY,
	away_odds_OE_1stEUR MONEY,

	odds_1 MONEY,
	odds_1USD MONEY,
	odds_1EUR MONEY,

	odds_x MONEY,
	odds_xUSD MONEY,
	odds_xEUR MONEY,

	odds_2 MONEY,
	odds_2USD MONEY,
	odds_2EUR MONEY,

	odds_1_1st MONEY,
	odds_1_1stUSD MONEY,
	odds_1_1stEUR MONEY,

	odds_x_1st MONEY,
	odds_x_1stUSD MONEY,
	odds_x_1stEUR MONEY,

	odds_2_1st MONEY,
	odds_2_1stUSD MONEY,
	odds_2_1stEUR MONEY,

	home_odds_DND MONEY,
	home_odds_DNDUSD MONEY,
	home_odds_DNDEUR MONEY,
	
	away_odds_DND MONEY,
	away_odds_DNDUSD MONEY,
	away_odds_DNDEUR MONEY,
	

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
		sum((CASE WHEN bettype=2 AND betteam = 'h' THEN stake ELSE 0 END)*(CASE WHEN ABS(odds) <1 THEN 1 ELSE ABS(odds) END)) AS home_odds_OE,
		sum((CASE WHEN bettype=2 AND betteam = 'h' THEN stake*e.USD ELSE 0 END)*(CASE WHEN ABS(odds) <1 THEN 1 ELSE ABS(odds) END)) AS home_odds_OEUSD,
		sum((CASE WHEN bettype=2 AND betteam = 'h' THEN stake*e.EUR ELSE 0 END)*(CASE WHEN ABS(odds) <1 THEN 1 ELSE ABS(odds) END)) AS home_odds_OEEUR,

		sum((CASE WHEN bettype=2 AND betteam = 'a' THEN stake ELSE 0 END)*(CASE WHEN ABS(odds) <1 THEN 1 ELSE ABS(odds) END)) AS away_odds_OE,
		sum((CASE WHEN bettype=2 AND betteam = 'a' THEN stake*e.USD ELSE 0 END)*(CASE WHEN ABS(odds) <1 THEN 1 ELSE ABS(odds) END)) AS away_odds_OEUSD,
		sum((CASE WHEN bettype=2 AND betteam = 'a' THEN stake*e.EUR ELSE 0 END)*(CASE WHEN ABS(odds) <1 THEN 1 ELSE ABS(odds) END)) AS away_odds_OEEUR,

		sum((CASE WHEN bettype=12 AND betteam = 'h' THEN stake ELSE 0 END)*(CASE WHEN ABS(odds) <1 THEN 1 ELSE ABS(odds) END)) AS home_odds_OE_1st,
		sum((CASE WHEN bettype=12 AND betteam = 'h' THEN stake*e.USD ELSE 0 END)*(CASE WHEN ABS(odds) <1 THEN 1 ELSE ABS(odds) END)) AS home_odds_OE_1stUSD,
		sum((CASE WHEN bettype=12 AND betteam = 'h' THEN stake*e.EUR ELSE 0 END)*(CASE WHEN ABS(odds) <1 THEN 1 ELSE ABS(odds) END)) AS home_odds_OE_1stEUR,

		sum((CASE WHEN bettype=12 AND betteam = 'a' THEN stake ELSE 0 END)*(CASE WHEN ABS(odds) <1 THEN 1 ELSE ABS(odds) END)) AS away_odds_OE_1st,
		sum((CASE WHEN bettype=12 AND betteam = 'a' THEN stake*e.USD ELSE 0 END)*(CASE WHEN ABS(odds) <1 THEN 1 ELSE ABS(odds) END)) AS away_odds_OE_1stUSD,
		sum((CASE WHEN bettype=12 AND betteam = 'a' THEN stake*e.EUR ELSE 0 END)*(CASE WHEN ABS(odds) <1 THEN 1 ELSE ABS(odds) END)) AS away_odds_OE_1stEUR,
		--league.lcolor,
		sum(CASE WHEN bettype=5 AND betteam = '1' THEN  stake   ELSE 0 END) AS odds_1,
		sum(CASE WHEN bettype=5 AND betteam = '1' THEN  stake*e.USD   ELSE 0 END) AS odds_1USD,
		sum(CASE WHEN bettype=5 AND betteam = '1' THEN  stake*e.EUR   ELSE 0 END) AS odds_1EUR,

		sum(CASE WHEN bettype=5 AND betteam = 'x' THEN  stake   ELSE 0 END) AS odds_x,
		sum(CASE WHEN bettype=5 AND betteam = 'x' THEN  stake*e.USD   ELSE 0 END) AS odds_xUSD,
		sum(CASE WHEN bettype=5 AND betteam = 'x' THEN  stake*e.EUR   ELSE 0 END) AS odds_xEUR,

		sum(CASE WHEN bettype=5 AND betteam = '2' THEN  stake   ELSE 0 END) AS odds_2,
		sum(CASE WHEN bettype=5 AND betteam = '2' THEN  stake*e.USD   ELSE 0 END) AS odds_2USD,
		sum(CASE WHEN bettype=5 AND betteam = '2' THEN  stake*e.EUR   ELSE 0 END) AS odds_2EUR,

		sum(CASE WHEN bettype=15 AND betteam = '1' THEN  stake   ELSE 0 END) AS odds_1_1st,
		sum(CASE WHEN bettype=15 AND betteam = '1' THEN  stake*e.USD   ELSE 0 END) AS odds_1_1stUSD,
		sum(CASE WHEN bettype=15 AND betteam = '1' THEN  stake*e.EUR   ELSE 0 END) AS odds_1_1stEUR,
		
		sum(CASE WHEN bettype=15 AND betteam = 'x' THEN  stake   ELSE 0 END) AS odds_x_1st,
		sum(CASE WHEN bettype=15 AND betteam = 'x' THEN  stake*e.USD   ELSE 0 END) AS odds_x_1stUSD,
		sum(CASE WHEN bettype=15 AND betteam = 'x' THEN  stake*e.EUR   ELSE 0 END) AS odds_x_1stEUR,
		
		sum(CASE WHEN bettype=15 AND betteam = '2' THEN  stake   ELSE 0 END) AS odds_2_1st,
		sum(CASE WHEN bettype=15 AND betteam = '2' THEN  stake*e.USD   ELSE 0 END) AS odds_2_1stUSD,
		sum(CASE WHEN bettype=15 AND betteam = '2' THEN  stake*e.EUR   ELSE 0 END) AS odds_2_1stEUR,

		sum(Case when bettype=123 and betteam = 'h' then  stake   else 0 end) AS home_odds_DND,
		sum(Case when bettype=123 and betteam = 'h' then  stake*e.USD   else 0 end) AS home_odds_DNDUSD,
		sum(Case when bettype=123 and betteam = 'h' then  stake*e.EUR   else 0 end) AS home_odds_DNDEUR,
		
		sum(Case when bettype=123 and betteam = 'a' then  stake   else 0 end) AS away_odds_DND,
		sum(Case when bettype=123 and betteam = 'a' then  stake*e.USD   else 0 end) AS away_odds_DNDUSD,
		sum(Case when bettype=123 and betteam = 'a' then  stake*e.EUR   else 0 end) AS away_odds_DNDEUR,

		sum(CASE WHEN bettype=2 THEN 1 ELSE 0 END) AS BetCount_OE,
		sum(CASE WHEN bettype=12 THEN 1 ELSE 0 END) AS BetCount_OE_1st,
		sum(CASE WHEN bettype=5 THEN 1 ELSE 0 END) AS BetCount_1x2,
		sum(CASE WHEN bettype=15 THEN 1 ELSE 0 END) AS BetCount_1x2_1st,
		sum(case when bettype=123 then 1 else 0 end) as BetCount_DND,
		isnull(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral
	FROM
		bettrans AS a  WITH (NOLOCK)
		INNER JOIN match AS m  WITH (NOLOCK) ON m.matchid       = a.matchid 
		INNER JOIN (SELECT *  FROM Lrf_f_GetExchangeDaily(@Today,@Today))e 
		ON e.exchangeid = a.currency
	WHERE  	
		a.recommend IN (SELECT CustID FROM @TempAg) AND
		a.bettype in (2, 12, 5, 15,123)
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
		m.isNeutral
	ORDER BY a.liveindicator DESC, m.matchcode

IF @TotalRows = 0  
BEGIN  
	SELECT @TotalRows = COUNT(matchid) FROM @Data
END

SELECT c.* FROM
(
	SELECT 
		ROW_NUMBER() over (ORDER BY liveindicator DESC, matchcode) AS RowNum ,
		*
	FROM @Data
) c WHERE c.RowNum BETWEEN @RowStart AND @RowEnd

GO
GRANT EXECUTE ON [dbo].[Lrf_TotalBets_Sel25] TO [bodbLicenseeNet]

GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_TotalBets_Sel25] TO [vnteam]


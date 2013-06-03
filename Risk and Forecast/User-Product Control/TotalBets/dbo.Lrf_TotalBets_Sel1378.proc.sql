ALTER PROCEDURE [dbo].[Lrf_TotalBets_Sel1378]
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
Task : Retrieve Total Bet values for bettype 1,3,7,8
DB: DB052.bodb02
Original: Age_TotalBets_Sel1378_Ag

Revisions:
 201133@Alex :  Allow to choose all type of licensee AND all currency + suppport based currency
 - 20110801@Henry: Remove PT + exclude BA ticket
 - 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily  
 - 20121004@Jim: replace @currencyname input param by @currencyID
 - 20130514@Jim:Restrict permission of Licensee Users by currency 

Param's Explanation:
• @custid: agent ID
*/

SET NOCOUNT ON
DECLARE @Today SMALLDATETIME 
SET @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120) 

SELECT  currencyID,LicenseeID into #currency
FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)
WHERE (@CurrencyID=0  OR (@CurrencyID<>0 AND CurrencyID=@CurrencyID))

DECLARE @TempAg AS TABLE (CustID INT)
INSERT INTO @TempAg (CustID)
SELECT  CustID  
                FROM    bodb_Licensee.dbo.LicenseeCust lc WITH ( NOLOCK )  
						INNER JOIN #currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID
                WHERE   lc.Description = COALESCE(@LicenseeType,  
                                                     lc.[Description])

---------------------
DROP TABLE #currency
---------------------
DECLARE @RowCount INT, @RowStart INT, @RowEnd INT  
SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1 

DECLARE @Data AS TABLE
(
	showtime NVARCHAR (50),
	leagueid INT,
	matchcode NVARCHAR(50),
	liveindicator BIT,
	matchid INT,
	homeID INT,
	awayID INT,
	livehomescore INT,
	liveawayscore INT,

	home_odds_HDP MONEY,
    home_odds_HDPUSD MONEY,
    home_odds_HDPEUR MONEY,

	away_odds_HDP MONEY,
	away_odds_HDPUSD MONEY,
	away_odds_HDPEUR MONEY,

	home_odds_HTHDP MONEY,
	home_odds_HTHDPUSD MONEY,
	home_odds_HTHDPEUR MONEY,

	away_odds_HTHDP MONEY,
	away_odds_HTHDPUSD MONEY,
	away_odds_HTHDPEUR MONEY,

	home_odds_OU MONEY,
	home_odds_OUUSD MONEY,
	home_odds_OUEUR MONEY,
	
	away_odds_OU MONEY,
	away_odds_OUUSD MONEY,
	away_odds_OUEUR MONEY,

	home_odds_HTOU MONEY,
	home_odds_HTOUUSD MONEY,
	home_odds_HTOUEUR MONEY,

	away_odds_HTOU MONEY,
	away_odds_HTOUUSD MONEY,
	away_odds_HTOUEUR MONEY,

	BetCount_HDP INT,
	BetCount_HTHDP INT,
	BetCount_OU INT,
	BetCount_HTOU INT,
	isNeutral BIT
)


INSERT INTO @Data
SELECT
		m.showtime, 
		m.leagueID,
		m.matchcode,
		b.liveindicator,
		m.matchid,
		m.homeID,
		m.awayID,
		b.livehomescore,
		b.liveawayscore,
		SUM(CASE WHEN bettype=1 AND betteam = 'h' THEN Stake ELSE 0 END) AS home_odds_HDP,
		SUM(CASE WHEN bettype=1 AND betteam = 'h' THEN StakeUSD ELSE 0 END) AS home_odds_HDPUSD,
		SUM(CASE WHEN bettype=1 AND betteam = 'h' THEN StakeEUR ELSE 0 END) AS home_odds_HDPEUR,

		SUM(CASE WHEN bettype=1 AND betteam = 'a' THEN Stake ELSE 0 END) AS away_odds_HDP,
		SUM(CASE WHEN bettype=1 AND betteam = 'a' THEN StakeUSD ELSE 0 END) AS away_odds_HDPUSD,
		SUM(CASE WHEN bettype=1 AND betteam = 'a' THEN StakeEUR ELSE 0 END) AS away_odds_HDPEUR,

	    SUM(CASE WHEN bettype=7 AND betteam = 'h' THEN Stake ELSE 0 END) AS home_odds_HTHDP,
		SUM(CASE WHEN bettype=7 AND betteam = 'h' THEN StakeUSD ELSE 0 END) AS home_odds_HTHDPUSD,
		SUM(CASE WHEN bettype=7 AND betteam = 'h' THEN StakeEUR ELSE 0 END) AS home_odds_HTHDPEUR,

		SUM(CASE WHEN bettype=7 AND betteam = 'a' THEN Stake ELSE 0 END) AS away_odds_HTHDP,
		SUM(CASE WHEN bettype=7 AND betteam = 'a' THEN StakeUSD ELSE 0 END) AS away_odds_HTHDPUSD,
		SUM(CASE WHEN bettype=7 AND betteam = 'a' THEN StakeEUR ELSE 0 END) AS away_odds_HTHDPEUR,
		
		SUM(CASE WHEN bettype=3 AND betteam = 'h' THEN Stake ELSE 0 END) AS home_odds_OU,
		SUM(CASE WHEN bettype=3 AND betteam = 'h' THEN StakeUSD ELSE 0 END) AS home_odds_OUUSD,
		SUM(CASE WHEN bettype=3 AND betteam = 'h' THEN StakeEUR ELSE 0 END) AS home_odds_OUEUR,
		
		SUM(CASE WHEN bettype=3 AND betteam = 'a' THEN Stake ELSE 0 END) AS away_odds_OU,
		SUM(CASE WHEN bettype=3 AND betteam = 'a' THEN StakeUSD ELSE 0 END) AS away_odds_OUUSD,
		SUM(CASE WHEN bettype=3 AND betteam = 'a' THEN StakeEUR ELSE 0 END) AS away_odds_OUEUR,


		SUM(CASE WHEN bettype=8 AND betteam = 'h' THEN Stake ELSE 0 END) AS home_odds_HTOU,
		SUM(CASE WHEN bettype=8 AND betteam = 'h' THEN StakeUSD ELSE 0 END) AS home_odds_HTOU,
		SUM(CASE WHEN bettype=8 AND betteam = 'h' THEN StakeEUR ELSE 0 END) AS home_odds_HTOU,

		SUM(CASE WHEN bettype=8 AND betteam = 'a' THEN Stake ELSE 0 END) AS away_odds_HTOU,
		SUM(CASE WHEN bettype=8 AND betteam = 'a' THEN StakeUSD ELSE 0 END) AS away_odds_HTOUUSD,
		SUM(CASE WHEN bettype=8 AND betteam = 'a' THEN StakeEUR ELSE 0 END) AS away_odds_HTOUEUR,
		
		SUM(CASE WHEN bettype=1 THEN BetCount ELSE 0 END) AS BetCount_HDP,
		SUM(CASE WHEN bettype=7 THEN BetCount ELSE 0 END) AS BetCount_HTHDP,
		SUM(CASE WHEN bettype=3 THEN BetCount ELSE 0 END) AS BetCount_OU,
		SUM(CASE WHEN bettype=8 THEN BetCount ELSE 0 END) AS BetCount_HTOU,
		ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral
	FROM
		(SELECT
			matchid, bettype, betteam,
			liveindicator, livehomescore, liveawayscore,
			SUM(stake * CASE WHEN ABS(odds) <1 THEN 1 ELSE ABS(odds) END) Stake,
			SUM(stake * CASE WHEN ABS(odds) <1 THEN 1 ELSE ABS(odds) END * e.USD) StakeUSD,
			SUM(stake * CASE WHEN ABS(odds) <1 THEN 1 ELSE ABS(odds) END * e.EUR) StakeEUR,

			COUNT(*) BetCount
		FROM bettrans b WITH (NOLOCK)
       	INNER JOIN (SELECT * FROM Lrf_f_GetExchangeDaily(@Today,@Today))e ON e.exchangeid = b.currency
		WHERE
				recommend IN (SELECT CustID FROM @TempAg)
				AND bettype IN (1,3,7,8)
				AND statusID IN (0,1)
				AND ruben = 0
				AND tpositiontaking <> 0
		GROUP BY matchid, bettype, betteam, liveindicator, livehomescore, liveawayscore) AS b
		INNER JOIN match 	m  WITH (NOLOCK) ON m.matchid       = b.matchid 	
	WHERE	
		m.eventstatus = 'running'	
	GROUP BY
		m.showtime, 
		m.leagueID,
		m.matchcode,
		b.liveindicator,
		m.matchid,
		m.homeID,
		m.awayID,
		b.livehomescore,
		b.liveawayscore,
		m.isNeutral
	ORDER BY b.liveindicator desc, m.matchcode

IF @TotalRows = 0  
BEGIN  
	SELECT @TotalRows = COUNT(matchid) FROM @Data
END

SELECT 
	c.*
FROM
(
	SELECT
		ROW_NUMBER() over (ORDER BY liveindicator desc, matchcode) AS RowNum ,
		* 
	FROM @Data
) c WHERE c.RowNum between @RowStart AND @RowEnd

GO
GRANT EXECUTE ON [dbo].[Lrf_TotalBets_Sel1378] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_TotalBets_Sel1378] TO [vnteam]
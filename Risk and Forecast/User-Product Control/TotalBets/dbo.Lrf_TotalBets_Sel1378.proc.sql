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
 - 20140717@Francis: Change liveindicator datatype to INT to fix running live matches are not being showed at the top list (RedmineID:19136)
 - 20130718@Hannah: Group each match for Bodog (#19163)
 - 20141110@Winnie: Change from LicenseeCust table to [f_SelLicenseeCust] function
 - 20150124@Winnie: Add base currency GBP 
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
SELECT DISTINCT CustID  
                FROM    bodb_Licensee.dbo.[f_SelLicenseeCust](0) lc --WITH ( NOLOCK )
						INNER JOIN #currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID
                WHERE   lc.Description = COALESCE(@LicenseeType,  
                                                     lc.[Description])

---------------------

---------------------
DECLARE @RowCount INT, @RowStart INT, @RowEnd INT  
SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1 

DECLARE @Data AS TABLE
(
	showtime NVARCHAR (50),
	leagueid INT,
	matchcode NVARCHAR(50),
	liveindicator INT,
	matchid INT,
	homeID INT,
	awayID INT,
	livehomescore INT,
	liveawayscore INT,

	home_odds_HDP MONEY,
    home_odds_HDPUSD MONEY,
    home_odds_HDPEUR MONEY,
	home_odds_HDPGBP MONEY,

	away_odds_HDP MONEY,
	away_odds_HDPUSD MONEY,
	away_odds_HDPEUR MONEY,
	away_odds_HDPGBP MONEY,

	home_odds_HTHDP MONEY,
	home_odds_HTHDPUSD MONEY,
	home_odds_HTHDPEUR MONEY,
	home_odds_HTHDPGBP MONEY,

	away_odds_HTHDP MONEY,
	away_odds_HTHDPUSD MONEY,
	away_odds_HTHDPEUR MONEY,
	away_odds_HTHDPGBP MONEY,

	home_odds_OU MONEY,
	home_odds_OUUSD MONEY,
	home_odds_OUEUR MONEY,
	home_odds_OUGBP MONEY,
	
	away_odds_OU MONEY,
	away_odds_OUUSD MONEY,
	away_odds_OUEUR MONEY,
	away_odds_OUGBP MONEY,

	home_odds_HTOU MONEY,
	home_odds_HTOUUSD MONEY,
	home_odds_HTOUEUR MONEY,
	home_odds_HTOUGBP MONEY,

	away_odds_HTOU MONEY,
	away_odds_HTOUUSD MONEY,
	away_odds_HTOUEUR MONEY,
	away_odds_HTOUGBP MONEY,

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
		SUM(CASE WHEN bettype=1 AND betteam = 'h' THEN StakeGBP ELSE 0 END) AS home_odds_HDPGBP,

		SUM(CASE WHEN bettype=1 AND betteam = 'a' THEN Stake ELSE 0 END) AS away_odds_HDP,
		SUM(CASE WHEN bettype=1 AND betteam = 'a' THEN StakeUSD ELSE 0 END) AS away_odds_HDPUSD,
		SUM(CASE WHEN bettype=1 AND betteam = 'a' THEN StakeEUR ELSE 0 END) AS away_odds_HDPEUR,
		SUM(CASE WHEN bettype=1 AND betteam = 'a' THEN StakeGBP ELSE 0 END) AS away_odds_HDPGBP,

	    SUM(CASE WHEN bettype=7 AND betteam = 'h' THEN Stake ELSE 0 END) AS home_odds_HTHDP,
		SUM(CASE WHEN bettype=7 AND betteam = 'h' THEN StakeUSD ELSE 0 END) AS home_odds_HTHDPUSD,
		SUM(CASE WHEN bettype=7 AND betteam = 'h' THEN StakeEUR ELSE 0 END) AS home_odds_HTHDPEUR,
		SUM(CASE WHEN bettype=7 AND betteam = 'h' THEN StakeGBP ELSE 0 END) AS home_odds_HTHDPGBP,

		SUM(CASE WHEN bettype=7 AND betteam = 'a' THEN Stake ELSE 0 END) AS away_odds_HTHDP,
		SUM(CASE WHEN bettype=7 AND betteam = 'a' THEN StakeUSD ELSE 0 END) AS away_odds_HTHDPUSD,
		SUM(CASE WHEN bettype=7 AND betteam = 'a' THEN StakeEUR ELSE 0 END) AS away_odds_HTHDPEUR,
		SUM(CASE WHEN bettype=7 AND betteam = 'a' THEN StakeGBP ELSE 0 END) AS away_odds_HTHDPGBP,
		
		SUM(CASE WHEN bettype=3 AND betteam = 'h' THEN Stake ELSE 0 END) AS home_odds_OU,
		SUM(CASE WHEN bettype=3 AND betteam = 'h' THEN StakeUSD ELSE 0 END) AS home_odds_OUUSD,
		SUM(CASE WHEN bettype=3 AND betteam = 'h' THEN StakeEUR ELSE 0 END) AS home_odds_OUEUR,
		SUM(CASE WHEN bettype=3 AND betteam = 'h' THEN StakeGBP ELSE 0 END) AS home_odds_OUGBP,
		
		SUM(CASE WHEN bettype=3 AND betteam = 'a' THEN Stake ELSE 0 END) AS away_odds_OU,
		SUM(CASE WHEN bettype=3 AND betteam = 'a' THEN StakeUSD ELSE 0 END) AS away_odds_OUUSD,
		SUM(CASE WHEN bettype=3 AND betteam = 'a' THEN StakeEUR ELSE 0 END) AS away_odds_OUEUR,
		SUM(CASE WHEN bettype=3 AND betteam = 'a' THEN StakeGBP ELSE 0 END) AS away_odds_OUGBP,

		SUM(CASE WHEN bettype=8 AND betteam = 'h' THEN Stake ELSE 0 END) AS home_odds_HTOU,
		SUM(CASE WHEN bettype=8 AND betteam = 'h' THEN StakeUSD ELSE 0 END) AS home_odds_HTOUUSD,
		SUM(CASE WHEN bettype=8 AND betteam = 'h' THEN StakeEUR ELSE 0 END) AS home_odds_HTOUEUR,
		SUM(CASE WHEN bettype=8 AND betteam = 'h' THEN StakeGBP ELSE 0 END) AS home_odds_HTOUGBP,

		SUM(CASE WHEN bettype=8 AND betteam = 'a' THEN Stake ELSE 0 END) AS away_odds_HTOU,
		SUM(CASE WHEN bettype=8 AND betteam = 'a' THEN StakeUSD ELSE 0 END) AS away_odds_HTOUUSD,
		SUM(CASE WHEN bettype=8 AND betteam = 'a' THEN StakeEUR ELSE 0 END) AS away_odds_HTOUEUR,
		SUM(CASE WHEN bettype=8 AND betteam = 'a' THEN StakeGBP ELSE 0 END) AS away_odds_HTOUGBP,
		
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
			SUM(stake * CASE WHEN ABS(odds) <1 THEN 1 ELSE ABS(odds) END * e.GBP) StakeGBP,

			COUNT(*) BetCount
		FROM bettrans b WITH (NOLOCK)
       	INNER JOIN (SELECT * FROM Lrf_f_GetExchangeDaily(@Today,@Today))e ON e.exchangeid = b.currency
		WHERE
				recommend IN (SELECT CustID FROM @TempAg)
				AND  ((@CurrencyID=0 AND currency IN (SELECT currencyId FROM #currency))  OR (@CurrencyID<>0 AND Currency=@CurrencyID))
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

DECLARE @LicenseeID_temp INT

SELECT @LicenseeID_temp = LicenseeID 
FROM bodb_licensee.dbo.licensees WITH (NOLOCK)
WHERE LicenseeName = 'Bodog'

IF (@licenseeID_temp <> @LicenseeID)
BEGIN
	IF @TotalRows = 0  
	BEGIN  
		SELECT @TotalRows = COUNT(matchid) FROM @Data
	END

	SELECT 
		c.*
	FROM
	(
		SELECT
			ROW_NUMBER() over (ORDER BY matchcode) AS RowNum ,
			* 
		FROM @Data
	) c WHERE c.RowNum between @RowStart AND @RowEnd
END
ELSE
BEGIN
	UPDATE b
	SET 
		b.livehomescore = m.livehomescore,
		b.liveawayscore = m.liveawayscore,
		b.liveindicator = 1
	FROM @Data b
		INNER JOIN bodb02.dbo.match m WITH (NOLOCK)	ON m.matchid = b.matchid 
	WHERE b.matchid IN 
	(
		SELECT DISTINCT(matchid)
		FROM @Data
		WHERE liveindicator = 1
	)

	IF @TotalRows = 0  
	BEGIN  
		SELECT @TotalRows = COUNT(DISTINCT matchid) FROM @Data
	END

	SELECT 
		c.*
	FROM
	(
		SELECT
			ROW_NUMBER() over (ORDER BY m.matchcode) AS RowNum ,
			m.showtime, 
			m.leagueID,
			m.matchcode,
			b.liveindicator,
			m.matchid,
			m.homeID,
			m.awayID,
			b.livehomescore,
			b.liveawayscore,
			SUM(home_odds_HDP) AS home_odds_HDP,
			SUM(home_odds_HDPUSD) AS home_odds_HDPUSD,
			SUM(home_odds_HDPEUR) AS home_odds_HDPEUR,
			SUM(home_odds_HDPGBP) AS home_odds_HDPGBP,

			SUM(away_odds_HDP) AS away_odds_HDP,
			SUM(away_odds_HDPUSD) AS away_odds_HDPUSD,
			SUM(away_odds_HDPEUR) AS away_odds_HDPEUR,
			SUM(away_odds_HDPGBP) AS away_odds_HDPGBP,

			SUM(home_odds_HTHDP) AS home_odds_HTHDP,
			SUM(home_odds_HTHDPUSD) AS home_odds_HTHDPUSD,
			SUM(home_odds_HTHDPEUR) AS home_odds_HTHDPEUR,
			SUM(home_odds_HTHDPGBP) AS home_odds_HTHDPGBP,

			SUM(away_odds_HTHDP) AS away_odds_HTHDP,
			SUM(away_odds_HTHDPUSD) AS away_odds_HTHDPUSD,
			SUM(away_odds_HTHDPEUR) AS away_odds_HTHDPEUR,
			SUM(away_odds_HTHDPGBP) AS away_odds_HTHDPGBP,
		
			SUM(home_odds_OU) AS home_odds_OU,
			SUM(home_odds_OUUSD) AS home_odds_OUUSD,
			SUM(home_odds_OUEUR) AS home_odds_OUEUR,
			SUM(home_odds_OUGBP) AS home_odds_OUGBP,
		
			SUM(away_odds_OU) AS away_odds_OU,
			SUM(away_odds_OUUSD) AS away_odds_OUUSD,
			SUM(away_odds_OUEUR) AS away_odds_OUEUR,
			SUM(away_odds_OUGBP) AS away_odds_OUGBP,


			SUM(home_odds_HTOU) AS home_odds_HTOU,
			SUM(home_odds_HTOUUSD) AS home_odds_HTOUUSD,
			SUM(home_odds_HTOUEUR) AS home_odds_HTOUEUR,
			SUM(home_odds_HTOUGBP) AS home_odds_HTOUGBP,

			SUM(away_odds_HTOU) AS away_odds_HTOU,
			SUM(away_odds_HTOUUSD) AS away_odds_HTOUUSD,
			SUM(away_odds_HTOUEUR) AS away_odds_HTOUEUR,
			SUM(away_odds_HTOUGBP) AS away_odds_HTOUGBP,
		
			SUM(BetCount_HDP) AS BetCount_HDP,
			SUM(BetCount_HTHDP) AS BetCount_HTHDP,
			SUM(BetCount_OU) AS BetCount_OU,
			SUM(BetCount_HTOU) AS BetCount_HTOU,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral
		FROM @Data AS b
			INNER JOIN match m  WITH (NOLOCK) ON m.matchid = b.matchid 	
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
	) c WHERE c.RowNum between @RowStart AND @RowEnd

END

DROP TABLE #currency
GO
GRANT EXECUTE ON [dbo].[Lrf_TotalBets_Sel1378] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_TotalBets_Sel1378] TO [vnteam]
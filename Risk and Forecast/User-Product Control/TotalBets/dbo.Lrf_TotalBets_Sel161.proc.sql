ALTER PROCEDURE [dbo].[Lrf_TotalBets_Sel161]
	@LicenseeID INT,
	@UserID		INT,
	@CurrencyID INT=0,
	@LicenseeType VARCHAR(100) = NULL,
	@PageSize INT=50,
	@PageIndex INT=0,
	@TotalRows INT=0 OUTPUT
AS

/*
Created: 20110519@Henry
Task : Retrieve Total Bet values for Number Game
DB: DB052.bodb02
Original: [Age_TotalBets_Sel161_Ag]


Revisions: 
     - 20110801@Henry: Add 3 new bettypes for Number Game (88,89,90) + Remove PT + exclude BA tickets
	 - 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily  
	 - 20120703@Henry: Number Group support Live Game and Pre-game
	 - 20121004@Jim: replace @currencyname input param by @currencyID
	 - 20130514@Jim:Restrict permission of Licensee Users by currency
Param's Explanation:
• @custid: agent ID
• Bettype AND betteam explanation:
	* First ball over/under: 81, over = h , under = a
	* Last ball over/under: 82, over = h , under = a
	* First ball odd/even: 83, odd = h , even = a
	* Last ball odd/even: 84, odd = h , even = a
	* Over/Under FT: 85 (also use for LIVE over/under), over = h , under = a
	* Odd/Even FT: 86 (also use for LIVE odd/even), odd = h  , even = a
	* High/Low: 87, high = h , low = a
*/

SET NOCOUNT ON

DECLARE @Today SMALLDATETIME 
SET @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120) 

SELECT  currencyID,LicenseeID into #currency
FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)
WHERE (@CurrencyID=0  OR (@CurrencyID<>0 AND CurrencyID=@CurrencyID))

DECLARE @TempAg AS TABLE (custid INT)
INSERT INTO @TempAg (custid)
SELECT  CustID  
                FROM    bodb_Licensee.dbo.LicenseeCust lc WITH ( NOLOCK )  
				INNER JOIN #currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID
                WHERE   [Description] = COALESCE(@LicenseeType,  
                                                     [Description])
-------------------------
DROP TABLE #currency
-------------------------

DECLARE @RowCount INT, @RowStart INT, @RowEnd INT  
SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1 

DECLARE @Data table
(
	winlostdate DATETIME,
	currency INT,
	leagueid INT,
	matchcode nvarchar(50),
	matchid INT,
	over_1stBall MONEY,
	under_1stBall MONEY,
	over_lastBall MONEY,
	under_lastBall MONEY,
	odd_1stBall MONEY,
	even_1stBall MONEY,
	odd_lastBall MONEY,
	even_lastBall MONEY,
	odd_fullTime MONEY,
	even_fullTime MONEY,
	over_next MONEY,
	under_next MONEY,
	odd_next MONEY,
	even_next MONEY,
	[high] MONEY,
	[low] MONEY,
	Warrior_SecondBall MONEY,
	Warrior_LastBall MONEY,
	NextCombo_OverOdd MONEY,
	NextCombo_OverEven MONEY,
	NextCombo_UnderOdd MONEY,
	NextCombo_UnderEven MONEY,
	NumberGroup_live MONEY,
	NumberGroup_pre MONEY,
	betcount_OU1stBall INT,
	betcount_OULastBall INT,
	betcount_OE1stBall INT,
	betcount_OElastBall INT,
	betcount_OEfullTime INT,
	betcount_OUNext INT,
	betcount_OENext INT,
	betcount_highlow INT,
	betcount_Warrior INT,
	betcount_NextCombo INT,
	betcount_NumberGroup_live INT,
	betcount_NumberGroup_pre INT
)

INSERT INTO @Data
SELECT
		b.winlostdate,
		b.currency,
		m.leagueID,
		m.matchcode,
		m.matchid,
		SUM(CASE WHEN bettype=81 AND betteam = 'h' THEN Stake ELSE 0 END) AS over_1stBall,
		SUM(CASE WHEN bettype=81 AND betteam = 'a' THEN Stake ELSE 0 END) AS under_1stBall,
		SUM(CASE WHEN bettype=82 AND betteam = 'h' THEN Stake ELSE 0 END) AS over_lastBall,
		SUM(CASE WHEN bettype=82 AND betteam = 'a' THEN Stake ELSE 0 END) AS under_lastBall,
		SUM(CASE WHEN bettype=83 AND betteam = 'h' THEN Stake ELSE 0 END) AS odd_1stBall,
		SUM(CASE WHEN bettype=83 AND betteam = 'a' THEN Stake ELSE 0 END) AS even_1stBall,
		SUM(CASE WHEN bettype=84 AND betteam = 'h' THEN Stake ELSE 0 END) AS odd_lastBall,
		SUM(CASE WHEN bettype=84 AND betteam = 'a' THEN Stake ELSE 0 END) AS even_lastBall,
		SUM(CASE WHEN bettype=86 AND betteam = 'h' AND b.liveindicator=0 THEN Stake ELSE 0 END) AS odd_fullTime,
		SUM(CASE WHEN bettype=86 AND betteam = 'a' AND b.liveindicator=0 THEN Stake ELSE 0 END) AS even_fullTime,
		SUM(CASE WHEN bettype=85 AND betteam = 'h' AND b.liveindicator=1 THEN Stake ELSE 0 END) AS over_next,
		SUM(CASE WHEN bettype=85 AND betteam = 'a' AND b.liveindicator=1 THEN Stake ELSE 0 END) AS under_next,
		SUM(CASE WHEN bettype=86 AND betteam = 'h' AND b.liveindicator=1 THEN Stake ELSE 0 END) AS odd_next,
		SUM(CASE WHEN bettype=86 AND betteam = 'a' AND b.liveindicator=1 THEN Stake ELSE 0 END) AS even_next,		
		SUM(CASE WHEN bettype=87 AND betteam = 'h' THEN Stake ELSE 0 END) AS high,
		SUM(CASE WHEN bettype=87 AND betteam = 'a' THEN Stake ELSE 0 END) AS low,
		SUM(CASE WHEN bettype=88 AND betteam = 'h' THEN Stake ELSE 0 END) AS Warrior_SecondBall,  
		SUM(CASE WHEN bettype=88 AND betteam = 'a' THEN Stake ELSE 0 END) AS Warrior_LastBall,
		SUM(CASE WHEN bettype=89 AND betteam = '1:1' THEN Stake ELSE 0 END) AS NextCombo_OverOdd ,  
		SUM(CASE WHEN bettype=89 AND betteam = '1:2' THEN Stake ELSE 0 END) AS NextCombo_OverEven,  
		SUM(CASE WHEN bettype=89 AND betteam = '2:1' THEN Stake ELSE 0 END) AS NextCombo_UnderOdd ,  
		SUM(CASE WHEN bettype=89 AND betteam = '2:2' THEN Stake ELSE 0 END) AS NextCombo_UnderEven,
		SUM(CASE WHEN bettype=90 AND b.liveindicator=1 THEN Stake ELSE 0 END) AS NumberGroup_live,    
		SUM(CASE WHEN bettype=90 AND b.liveindicator=0 THEN Stake ELSE 0 END) AS NumberGroup_pre,    
		SUM(CASE WHEN bettype=81 THEN BetCount ELSE 0 END) AS betcount_OU1stBall,
		SUM(CASE WHEN bettype=82 THEN BetCount ELSE 0 END) AS betcount_OULastBall,
		SUM(CASE WHEN bettype=83 THEN BetCount ELSE 0 END) AS betcount_OE1stBall,
		SUM(CASE WHEN bettype=84 THEN BetCount ELSE 0 END) AS betcount_OElastBall,
		SUM(CASE WHEN bettype=86 AND b.liveindicator=0 THEN BetCount ELSE 0 END) AS betcount_OEfullTime,
		SUM(CASE WHEN bettype=85 AND b.liveindicator=1 THEN BetCount ELSE 0 END) AS betcount_OUNext,
		SUM(CASE WHEN bettype=86 AND b.liveindicator=1 THEN BetCount ELSE 0 END) AS betcount_OENext,
		SUM(CASE WHEN bettype=87 THEN BetCount ELSE 0 END) AS betcount_highlow,
		SUM(CASE WHEN bettype=88 THEN BetCount ELSE 0 END) AS betcount_Warrior,  
		SUM(CASE WHEN bettype=89 THEN BetCount ELSE 0 END) AS betcount_NextCombo, 
		
		SUM(CASE WHEN bettype=90 AND b.liveindicator=1 THEN BetCount ELSE 0 END) AS betcount_NumberGroup_live,
		SUM(CASE WHEN bettype=90 AND b.liveindicator=0 THEN BetCount ELSE 0 END) AS betcount_NumberGroup_pre  
	FROM
		(SELECT 
				winlostdate,
				matchid, 
				currency,
				bettype, 
				betteam,
				liveindicator,
				SUM(stake * CASE WHEN ABS(odds) <1 THEN 1 ELSE ABS(odds) END) Stake,
				COUNT(1) AS BetCount
		FROM bettrans WITH (NOLOCK)
		WHERE
				bettype BETWEEN 81 AND 120
				AND recommend  IN (SELECT custid FROM @TempAg)
				AND statusID IN (0,1)
				AND ruben = 0
		GROUP BY winlostdate,matchid,currency, bettype, betteam, liveindicator) AS b
		INNER JOIN match m WITH (NOLOCK) ON m.matchid = b.matchid
	WHERE	
		m.eventstatus = 'running'
	GROUP BY
		b.winlostdate,
		b.currency,
		m.leagueID,
		m.matchcode,
		m.matchid
	ORDER BY  m.matchcode

IF @TotalRows = 0  
BEGIN  
	SELECT @TotalRows = COUNT(matchid) FROM @Data
	
END

SELECT c.* FROM
(
	SELECT
		ROW_NUMBER() over (ORDER BY matchcode) AS RowNum ,
		*,
		CAST(over_1stBall * e.usd AS MONEY)   over_1stBallusd,
		CAST(over_1stBall * e.eur AS MONEY)   over_1stBalleur,
		CAST(under_1stBall * e.usd AS MONEY) under_1stBallusd,
		CAST(under_1stBall * e.eur AS MONEY) under_1stBalleur,
		CAST(over_lastBall * e.usd AS MONEY) over_lastBallusd,
		CAST(over_lastBall * e.eur AS MONEY) over_lastBalleur,
		CAST(under_lastBall * e.usd AS MONEY) under_lastBallusd,
		CAST(under_lastBall * e.eur AS MONEY) under_lastBalleur,
		CAST(odd_1stBall * e.usd AS MONEY) odd_1stBallusd,
		CAST(odd_1stBall * e.eur AS MONEY) odd_1stBalleur,
		CAST(even_1stBall * e.usd AS MONEY) even_1stBallusd,
		CAST(even_1stBall * e.eur AS MONEY) even_1stBalleur,
		CAST(odd_lastBall * e.usd AS MONEY) odd_lastBallusd,
		CAST(odd_lastBall * e.eur AS MONEY) odd_lastBalleur,
		CAST(even_lastBall * e.usd AS MONEY) even_lastBallusd,
		CAST(even_lastBall * e.eur AS MONEY) even_lastBalleur,
		CAST(odd_fullTime * e.usd AS MONEY) odd_fullTimeusd,
		CAST(odd_fullTime * e.eur AS MONEY) odd_fullTimeeur,
		CAST(even_fullTime * e.usd AS MONEY) even_fullTimeusd,
		CAST(even_fullTime * e.eur AS MONEY) even_fullTimeeur,
		CAST(over_next * e.usd AS MONEY) over_nextusd,
		CAST(over_next * e.eur AS MONEY) over_nexteur,
		CAST(under_next * e.usd AS MONEY) under_nextusd,
		CAST(under_next * e.eur AS MONEY) under_nexteur,
		CAST(odd_next * e.usd AS MONEY)  odd_nextusd,
		CAST(odd_next * e.eur AS MONEY)	odd_nexteur,
		CAST(even_next * e.usd AS MONEY)  even_nextusd,
		CAST(even_next * e.eur AS MONEY)	even_nexteur,
		CAST(high * e.usd AS MONEY) highusd,
		CAST(high * e.eur AS MONEY) higheur,
		CAST(low * e.usd AS MONEY) lowusd,
		CAST(low * e.eur AS MONEY) loweur,
		CAST(Warrior_SecondBall * e.usd AS MONEY) Warrior_SecondBallusd,
		CAST(Warrior_SecondBall * e.eur AS MONEY) Warrior_SecondBalleur,
		CAST(Warrior_LastBall * e.usd AS MONEY) Warrior_LastBallusd,
		CAST(Warrior_LastBall * e.eur AS MONEY) Warrior_LastBalleur,
		CAST(NextCombo_OverOdd * e.usd AS MONEY) NextCombo_OverOddusd,
		CAST(NextCombo_OverOdd * e.eur AS MONEY) NextCombo_OverOddeur,
		CAST(NextCombo_OverEven * e.usd AS MONEY) NextCombo_OverEvenusd,
		CAST(NextCombo_OverEven * e.eur AS MONEY) NextCombo_OverEveneur,
		CAST(NextCombo_UnderOdd * e.usd AS MONEY) NextCombo_UnderOddusd,
		CAST(NextCombo_UnderOdd * e.eur AS MONEY) NextCombo_UnderOddeur,
		CAST(NextCombo_UnderEven * e.usd AS MONEY) NextCombo_UnderEvenusd,
		CAST(NextCombo_UnderEven * e.eur AS MONEY) NextCombo_UnderEveneur,
		CAST(NumberGroup_live * e.usd AS MONEY) NumberGroup_liveusd,
		CAST(NumberGroup_live * e.eur AS MONEY) NumberGroup_liveeur,
		CAST(NumberGroup_pre * e.usd AS MONEY) NumberGroup_preusd,
		CAST(NumberGroup_pre * e.eur AS MONEY) NumberGroup_preeur
		
	FROM @Data d
	INNER JOIN (SELECT *  FROM Lrf_f_GetExchangeDaily(@Today,@Today))e 
	ON e.exchangeid = d.currency
) c WHERE c.RowNum BETWEEN @RowStart AND @RowEnd
GO
GRANT EXECUTE ON [dbo].[Lrf_TotalBets_Sel161] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_TotalBets_Sel161] TO [vnteam]
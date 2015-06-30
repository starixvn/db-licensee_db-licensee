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
	 - 20141110@Winnie: Change from LicenseeCust table to [f_SelLicenseeCust] function
	 - 20150123@Jim: support base on Currency GBP
	 - 20150617@Jim:  Enhance Total Bets with sum values of running stakes  (Feature #36839)
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
SELECT DISTINCT CustID  
                FROM    bodb_Licensee.dbo.[f_SelLicenseeCust](0) lc --WITH ( NOLOCK )
				INNER JOIN #currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID
                WHERE   [Description] = COALESCE(@LicenseeType,  
                                                     [Description])
-------------------------

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
	over_1stBall_ori MONEY,
	under_1stBall MONEY,
	under_1stBall_ori MONEY,
	over_lastBall MONEY,
	over_lastBall_ori MONEY,
	under_lastBall MONEY,
	under_lastBall_ori MONEY,
	odd_1stBall MONEY,
	odd_1stBall_ori MONEY,
	even_1stBall MONEY,
	even_1stBall_ori MONEY,
	odd_lastBall MONEY,
	odd_lastBall_ori MONEY,
	even_lastBall MONEY,
	even_lastBall_ori MONEY,
	odd_fullTime MONEY,
	odd_fullTime_ori MONEY,
	even_fullTime MONEY,
	even_fullTime_ori MONEY,
	over_next MONEY,
	over_next_ori MONEY,
	under_next MONEY,
	under_next_ori MONEY,
	odd_next MONEY,
	odd_next_ori MONEY,
	even_next MONEY,
	even_next_ori MONEY,
	[high] MONEY,
	[high_ori] MONEY,
	[low] MONEY,
	[low_ori] MONEY,
	Warrior_SecondBall MONEY,
	Warrior_SecondBall_ori MONEY,
	Warrior_LastBall MONEY,
	Warrior_LastBall_ori MONEY,
	NextCombo_OverOdd MONEY,
	NextCombo_OverOdd_ori MONEY,
	NextCombo_OverEven MONEY,
	NextCombo_OverEven_ori MONEY,
	NextCombo_UnderOdd MONEY,
	NextCombo_UnderOdd_ori MONEY,
	NextCombo_UnderEven MONEY,
	NextCombo_UnderEven_ori MONEY,
	NumberGroup_live MONEY,
	NumberGroup_live_ori MONEY,
	NumberGroup_pre MONEY,
	NumberGroup_pre_ori MONEY,
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
		SUM(CASE WHEN bettype=81 AND betteam = 'h' THEN Stake_ori ELSE 0 END) AS over_1stBall_ori,
		SUM(CASE WHEN bettype=81 AND betteam = 'a' THEN Stake ELSE 0 END) AS under_1stBall,
		SUM(CASE WHEN bettype=81 AND betteam = 'a' THEN Stake_ori ELSE 0 END) AS under_1stBall_ori,
		SUM(CASE WHEN bettype=82 AND betteam = 'h' THEN Stake ELSE 0 END) AS over_lastBall,
		SUM(CASE WHEN bettype=82 AND betteam = 'h' THEN Stake_ori ELSE 0 END) AS over_lastBall_ori,
		SUM(CASE WHEN bettype=82 AND betteam = 'a' THEN Stake ELSE 0 END) AS under_lastBall,
		SUM(CASE WHEN bettype=82 AND betteam = 'a' THEN Stake_ori ELSE 0 END) AS under_lastBall_ori,
		SUM(CASE WHEN bettype=83 AND betteam = 'h' THEN Stake ELSE 0 END) AS odd_1stBall,
		SUM(CASE WHEN bettype=83 AND betteam = 'h' THEN Stake_ori ELSE 0 END) AS odd_1stBall_ori,
		SUM(CASE WHEN bettype=83 AND betteam = 'a' THEN Stake ELSE 0 END) AS even_1stBall,
		SUM(CASE WHEN bettype=83 AND betteam = 'a' THEN Stake_ori ELSE 0 END) AS even_1stBall_ori,
		SUM(CASE WHEN bettype=84 AND betteam = 'h' THEN Stake ELSE 0 END) AS odd_lastBall,
		SUM(CASE WHEN bettype=84 AND betteam = 'h' THEN Stake_ori ELSE 0 END) AS odd_lastBall_ori,
		SUM(CASE WHEN bettype=84 AND betteam = 'a' THEN Stake ELSE 0 END) AS even_lastBall,
		SUM(CASE WHEN bettype=84 AND betteam = 'a' THEN Stake_ori ELSE 0 END) AS even_lastBall_ori,
		SUM(CASE WHEN bettype=86 AND betteam = 'h' AND b.liveindicator=0 THEN Stake ELSE 0 END) AS odd_fullTime,
		SUM(CASE WHEN bettype=86 AND betteam = 'h' AND b.liveindicator=0 THEN Stake_ori ELSE 0 END) AS odd_fullTime_ori,
		SUM(CASE WHEN bettype=86 AND betteam = 'a' AND b.liveindicator=0 THEN Stake ELSE 0 END) AS even_fullTime,
		SUM(CASE WHEN bettype=86 AND betteam = 'a' AND b.liveindicator=0 THEN Stake_ori ELSE 0 END) AS even_fullTime_ori,
		SUM(CASE WHEN bettype=85 AND betteam = 'h' AND b.liveindicator=1 THEN Stake ELSE 0 END) AS over_next,
		SUM(CASE WHEN bettype=85 AND betteam = 'h' AND b.liveindicator=1 THEN Stake_ori ELSE 0 END) AS over_next_ori,
		SUM(CASE WHEN bettype=85 AND betteam = 'a' AND b.liveindicator=1 THEN Stake ELSE 0 END) AS under_next,
		SUM(CASE WHEN bettype=85 AND betteam = 'a' AND b.liveindicator=1 THEN Stake_ori ELSE 0 END) AS under_next_ori,
		SUM(CASE WHEN bettype=86 AND betteam = 'h' AND b.liveindicator=1 THEN Stake ELSE 0 END) AS odd_next,
		SUM(CASE WHEN bettype=86 AND betteam = 'h' AND b.liveindicator=1 THEN Stake_ori ELSE 0 END) AS odd_next_ori,
		SUM(CASE WHEN bettype=86 AND betteam = 'a' AND b.liveindicator=1 THEN Stake ELSE 0 END) AS even_next,		
		SUM(CASE WHEN bettype=86 AND betteam = 'a' AND b.liveindicator=1 THEN Stake_ori ELSE 0 END) AS even_next_ori,
		SUM(CASE WHEN bettype=87 AND betteam = 'h' THEN Stake ELSE 0 END) AS high,
		SUM(CASE WHEN bettype=87 AND betteam = 'h' THEN Stake_ori ELSE 0 END) AS high_ori,
		SUM(CASE WHEN bettype=87 AND betteam = 'a' THEN Stake ELSE 0 END) AS low,
		SUM(CASE WHEN bettype=87 AND betteam = 'a' THEN Stake_ori ELSE 0 END) AS low_ori,
		SUM(CASE WHEN bettype=88 AND betteam = 'h' THEN Stake ELSE 0 END) AS Warrior_SecondBall,  
		SUM(CASE WHEN bettype=88 AND betteam = 'h' THEN Stake_ori ELSE 0 END) AS Warrior_SecondBall_ori,
		SUM(CASE WHEN bettype=88 AND betteam = 'a' THEN Stake ELSE 0 END) AS Warrior_LastBall,
		SUM(CASE WHEN bettype=88 AND betteam = 'a' THEN Stake_ori ELSE 0 END) AS Warrior_LastBall_ori,
		SUM(CASE WHEN bettype=89 AND betteam = '1:1' THEN Stake ELSE 0 END) AS NextCombo_OverOdd ,  
		SUM(CASE WHEN bettype=89 AND betteam = '1:1' THEN Stake_ori ELSE 0 END) AS NextCombo_OverOdd_ori ,  
		SUM(CASE WHEN bettype=89 AND betteam = '1:2' THEN Stake ELSE 0 END) AS NextCombo_OverEven,  
		SUM(CASE WHEN bettype=89 AND betteam = '1:2' THEN Stake_ori ELSE 0 END) AS NextCombo_OverEven_ori,  
		SUM(CASE WHEN bettype=89 AND betteam = '2:1' THEN Stake ELSE 0 END) AS NextCombo_UnderOdd ,  
		SUM(CASE WHEN bettype=89 AND betteam = '2:1' THEN Stake_ori ELSE 0 END) AS NextCombo_UnderOdd_ori ,
		SUM(CASE WHEN bettype=89 AND betteam = '2:2' THEN Stake ELSE 0 END) AS NextCombo_UnderEven,
		SUM(CASE WHEN bettype=89 AND betteam = '2:2' THEN Stake_ori ELSE 0 END) AS NextCombo_UnderEven_ori,
		SUM(CASE WHEN bettype=90 AND b.liveindicator=1 THEN Stake ELSE 0 END) AS NumberGroup_live,    
		SUM(CASE WHEN bettype=90 AND b.liveindicator=1 THEN Stake_ori ELSE 0 END) AS NumberGroup_live_ori,
		SUM(CASE WHEN bettype=90 AND b.liveindicator=0 THEN Stake ELSE 0 END) AS NumberGroup_pre,    
		SUM(CASE WHEN bettype=90 AND b.liveindicator=0 THEN Stake_ori ELSE 0 END) AS NumberGroup_pre_ori,
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
				SUM(stake) Stake_ori,
				COUNT(1) AS BetCount
		FROM bettrans WITH (NOLOCK)
		WHERE
				bettype BETWEEN 81 AND 120
				AND recommend  IN (SELECT custid FROM @TempAg)
				AND ((@CurrencyID=0 AND currency IN (SELECT currencyId FROM #currency))   OR (@CurrencyID<>0 AND Currency=@CurrencyID))
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
		CAST(over_1stBall * e.gbp AS MONEY)   over_1stBallgbp,
		
		CAST(under_1stBall * e.usd AS MONEY) under_1stBallusd,
		CAST(under_1stBall * e.eur AS MONEY) under_1stBalleur,
		CAST(under_1stBall * e.gbp AS MONEY) under_1stBallgbp,
		
		CAST(over_lastBall * e.usd AS MONEY) over_lastBallusd,
		CAST(over_lastBall * e.eur AS MONEY) over_lastBalleur,
		CAST(over_lastBall * e.gbp AS MONEY) over_lastBallgbp,
		
		CAST(under_lastBall * e.usd AS MONEY) under_lastBallusd,
		CAST(under_lastBall * e.eur AS MONEY) under_lastBalleur,
		CAST(under_lastBall * e.gbp AS MONEY) under_lastBallgbp,
		
		CAST(odd_1stBall * e.usd AS MONEY) odd_1stBallusd,
		CAST(odd_1stBall * e.eur AS MONEY) odd_1stBalleur,
		CAST(odd_1stBall * e.gbp AS MONEY) odd_1stBallgbp,
		
		CAST(even_1stBall * e.usd AS MONEY) even_1stBallusd,
		CAST(even_1stBall * e.eur AS MONEY) even_1stBalleur,
		CAST(even_1stBall * e.gbp AS MONEY) even_1stBallgbp,
		
		CAST(odd_lastBall * e.usd AS MONEY) odd_lastBallusd,
		CAST(odd_lastBall * e.eur AS MONEY) odd_lastBalleur,
		CAST(odd_lastBall * e.gbp AS MONEY) odd_lastBallgbp,
		
		CAST(even_lastBall * e.usd AS MONEY) even_lastBallusd,
		CAST(even_lastBall * e.eur AS MONEY) even_lastBalleur,
		CAST(even_lastBall * e.gbp AS MONEY) even_lastBallgbp,
		
		CAST(odd_fullTime * e.usd AS MONEY) odd_fullTimeusd,
		CAST(odd_fullTime * e.eur AS MONEY) odd_fullTimeeur,
		CAST(odd_fullTime * e.gbp AS MONEY) odd_fullTimegbp,
		
		CAST(even_fullTime * e.usd AS MONEY) even_fullTimeusd,
		CAST(even_fullTime * e.eur AS MONEY) even_fullTimeeur,
		CAST(even_fullTime * e.gbp AS MONEY) even_fullTimegbp,
		
		CAST(over_next * e.usd AS MONEY) over_nextusd,
		CAST(over_next * e.eur AS MONEY) over_nexteur,
		CAST(over_next * e.gbp AS MONEY) over_nextgbp,
		
		CAST(under_next * e.usd AS MONEY) under_nextusd,
		CAST(under_next * e.eur AS MONEY) under_nexteur,
		CAST(under_next * e.gbp AS MONEY) under_nextgbp,
		
		CAST(odd_next * e.usd AS MONEY)  odd_nextusd,
		CAST(odd_next * e.eur AS MONEY)	odd_nexteur,
		CAST(odd_next * e.gbp AS MONEY)	odd_nextgbp,
		
		CAST(even_next * e.usd AS MONEY)  even_nextusd,
		CAST(even_next * e.eur AS MONEY)	even_nexteur,
		CAST(even_next * e.gbp AS MONEY)	even_nextgbp,
		
		CAST(high * e.usd AS MONEY) highusd,
		CAST(high * e.eur AS MONEY) higheur,
		CAST(high * e.gbp AS MONEY) highgbp,
		
		CAST(low * e.usd AS MONEY) lowusd,
		CAST(low * e.eur AS MONEY) loweur,
		CAST(low * e.gbp AS MONEY) lowgbp,
		
		CAST(Warrior_SecondBall * e.usd AS MONEY) Warrior_SecondBallusd,
		CAST(Warrior_SecondBall * e.eur AS MONEY) Warrior_SecondBalleur,
		CAST(Warrior_SecondBall * e.gbp AS MONEY) Warrior_SecondBallgbp,
		
		CAST(Warrior_LastBall * e.usd AS MONEY) Warrior_LastBallusd,
		CAST(Warrior_LastBall * e.eur AS MONEY) Warrior_LastBalleur,
		CAST(Warrior_LastBall * e.gbp AS MONEY) Warrior_LastBallgbp,
		
		CAST(NextCombo_OverOdd * e.usd AS MONEY) NextCombo_OverOddusd,
		CAST(NextCombo_OverOdd * e.eur AS MONEY) NextCombo_OverOddeur,
		CAST(NextCombo_OverOdd * e.gbp AS MONEY) NextCombo_OverOddgbp,
		
		CAST(NextCombo_OverEven * e.usd AS MONEY) NextCombo_OverEvenusd,
		CAST(NextCombo_OverEven * e.eur AS MONEY) NextCombo_OverEveneur,
		CAST(NextCombo_OverEven * e.gbp AS MONEY) NextCombo_OverEvengbp,
		
		CAST(NextCombo_UnderOdd * e.usd AS MONEY) NextCombo_UnderOddusd,
		CAST(NextCombo_UnderOdd * e.eur AS MONEY) NextCombo_UnderOddeur,
		CAST(NextCombo_UnderOdd * e.gbp AS MONEY) NextCombo_UnderOddgbp,
		
		CAST(NextCombo_UnderEven * e.usd AS MONEY) NextCombo_UnderEvenusd,
		CAST(NextCombo_UnderEven * e.eur AS MONEY) NextCombo_UnderEveneur,
		CAST(NextCombo_UnderEven * e.gbp AS MONEY) NextCombo_UnderEvengbp,
		
		CAST(NumberGroup_live * e.usd AS MONEY) NumberGroup_liveusd,
		CAST(NumberGroup_live * e.eur AS MONEY) NumberGroup_liveeur,
		CAST(NumberGroup_live * e.gbp AS MONEY) NumberGroup_livegbp,
		
		CAST(NumberGroup_pre * e.usd AS MONEY) NumberGroup_preusd,
		CAST(NumberGroup_pre * e.eur AS MONEY) NumberGroup_preeur,
		CAST(NumberGroup_pre * e.gbp AS MONEY) NumberGroup_pregbp
		
	FROM @Data d
	INNER JOIN (SELECT *  FROM Lrf_f_GetExchangeDaily(@Today,@Today))e 
	ON e.exchangeid = d.currency
) c WHERE c.RowNum BETWEEN @RowStart AND @RowEnd
---CAST(over_1stBall * e.usd AS MONEY)   over_1stBallusd, eur,gbp
SELECT 
	SUM(over_1stBall_ori) over_1stBall,
	SUM(over_1stBall_ori*e.usd) over_1stBallusd,
	SUM(over_1stBall_ori*e.eur) over_1stBalleur,
	SUM(over_1stBall_ori*e.gbp) over_1stBallgbp,
	
	SUM(under_1stBall_ori) under_1stBall,
	SUM(under_1stBall_ori*e.usd) under_1stBallusd,
	SUM(under_1stBall_ori*e.eur) under_1stBalleur,
	SUM(under_1stBall_ori*e.gbp) under_1stBallgbp,
	
	SUM(over_lastBall_ori) over_lastBall,
	SUM(over_lastBall_ori*e.usd) over_lastBallusd,
	SUM(over_lastBall_ori*e.eur) over_lastBalleur,
	SUM(over_lastBall_ori*e.gbp) over_lastBallgbp,
	
	SUM(under_lastBall_ori) under_lastBall,
	SUM(under_lastBall_ori*e.usd) under_lastBallusd,
	SUM(under_lastBall_ori*e.eur) under_lastBalleur,
	SUM(under_lastBall_ori*e.gbp) under_lastBallgbp,
	
	SUM(odd_1stBall_ori) odd_1stBall,
	SUM(odd_1stBall_ori*e.usd) odd_1stBallusd,
	SUM(odd_1stBall_ori*e.eur) odd_1stBalleur,
	SUM(odd_1stBall_ori*e.gbp) odd_1stBallgbp,
	
	SUM(even_1stBall_ori) even_1stBall,
	SUM(even_1stBall_ori*e.usd) even_1stBallusd,
	SUM(even_1stBall_ori*e.eur) even_1stBalleur,
	SUM(even_1stBall_ori*e.gbp) even_1stBallgbp,
	
	SUM(odd_lastBall_ori) odd_lastBall,
	SUM(odd_lastBall_ori*e.usd) odd_lastBallusd,
	SUM(odd_lastBall_ori*e.eur) odd_lastBalleur,
	SUM(odd_lastBall_ori*e.gbp) odd_lastBallgbp,
	
	SUM(even_lastBall_ori) even_lastBall,
	SUM(even_lastBall_ori*e.usd) even_lastBallusd,
	SUM(even_lastBall_ori*e.eur) even_lastBalleur,
	SUM(even_lastBall_ori*e.gbp) even_lastBallgbp,
	
	SUM(odd_fullTime_ori) odd_fullTime,
	SUM(odd_fullTime_ori*e.usd) odd_fullTimeusd,
	SUM(odd_fullTime_ori*e.eur) odd_fullTimeeur,
	SUM(odd_fullTime_ori*e.gbp) odd_fullTimegbp,
	
	SUM(even_fullTime_ori) even_fullTime,
	SUM(even_fullTime_ori*e.usd) even_fullTimeusd,
	SUM(even_fullTime_ori*e.eur) even_fullTimeeur,
	SUM(even_fullTime_ori*e.gbp) even_fullTimegbp,
	
	SUM(over_next_ori) over_next,
	SUM(over_next_ori*e.usd) over_nextusd,
	SUM(over_next_ori*e.eur) over_nexteur,
	SUM(over_next_ori*e.gbp) over_nextgbp,
	
	SUM(under_next_ori) under_next,
	SUM(under_next_ori*e.usd) under_nextusd,
	SUM(under_next_ori*e.eur) under_nexteur,
	SUM(under_next_ori*e.gbp) under_nextgbp,
	
	SUM(odd_next_ori) odd_next,
	SUM(odd_next_ori*e.usd) odd_nextusd,
	SUM(odd_next_ori*e.eur) odd_nexteur,
	SUM(odd_next_ori*e.gbp) odd_nextgbp,
	
	SUM(even_next_Ori) even_next,
	SUM(even_next_Ori*e.usd) even_nextusd,
	SUM(even_next_Ori*e.eur) even_nexteur,
	SUM(even_next_Ori*e.gbp) even_nextgbp,
	
	SUM([high_ori]) [high],
	SUM([high_ori]*e.usd) [highusd],
	SUM([high_ori]*e.eur) [higheur],
	SUM([high_ori]*e.gbp) [highgbp],
	
	SUM([low_ori]) [low],
	SUM([low_ori]*e.usd) [lowusd],
	SUM([low_ori]*e.eur) [loweur],
	SUM([low_ori]*e.gbp) [lowgbp],
	
	SUM(Warrior_SecondBall_ori) Warrior_SecondBall,
	SUM(Warrior_SecondBall_ori*e.usd) Warrior_SecondBallusd,
	SUM(Warrior_SecondBall_ori*e.eur) Warrior_SecondBalleur,
	SUM(Warrior_SecondBall_ori*e.gbp) Warrior_SecondBallgbp,
	
	SUM(Warrior_LastBall_ori) Warrior_LastBall,
	SUM(Warrior_LastBall_ori*e.usd) Warrior_LastBallusd,
	SUM(Warrior_LastBall_ori*e.eur) Warrior_LastBalleur,
	SUM(Warrior_LastBall_ori*e.gbp) Warrior_LastBallgbp,
	
	SUM(NextCombo_OverOdd_ori) NextCombo_OverOdd,
	SUM(NextCombo_OverOdd_ori*e.usd) NextCombo_OverOddusd,
	SUM(NextCombo_OverOdd_ori*e.eur) NextCombo_OverOddeur,
	SUM(NextCombo_OverOdd_ori*e.gbp) NextCombo_OverOddgbp,
	
	SUM(NextCombo_OverEven_ori) NextCombo_OverEven,
	SUM(NextCombo_OverEven_ori*e.usd) NextCombo_OverEvenusd,
	SUM(NextCombo_OverEven_ori*e.eur) NextCombo_OverEveneur,
	SUM(NextCombo_OverEven_ori*e.gbp) NextCombo_OverEvengbp,
	
	SUM(NextCombo_UnderOdd_ori) NextCombo_UnderOdd,
	SUM(NextCombo_UnderOdd_ori*e.usd) NextCombo_UnderOddusd,
	SUM(NextCombo_UnderOdd_ori*e.eur) NextCombo_UnderOddeur,
	SUM(NextCombo_UnderOdd_ori*e.gbp) NextCombo_UnderOddgbp,
	
	SUM(NextCombo_UnderEven_ori) NextCombo_UnderEven,
	SUM(NextCombo_UnderEven_ori*e.usd) NextCombo_UnderEvenusd,
	SUM(NextCombo_UnderEven_ori*e.eur) NextCombo_UnderEveneur,
	SUM(NextCombo_UnderEven_ori*e.gbp) NextCombo_UnderEvengbp,
	
	SUM(NumberGroup_live_ori) NumberGroup_live,
	SUM(NumberGroup_live_ori*e.usd) NumberGroup_liveusd,
	SUM(NumberGroup_live_ori*e.eur) NumberGroup_liveeur,
	SUM(NumberGroup_live_ori*e.gbp) NumberGroup_livegbp,
	
	SUM(NumberGroup_pre_ori) NumberGroup_pre,
	SUM(NumberGroup_pre_ori*e.usd) NumberGroup_preusd,
	SUM(NumberGroup_pre_ori*e.eur) NumberGroup_preeur,
	SUM(NumberGroup_pre_ori*e.gbp) NumberGroup_pregbp
	
	
FROM 
	@Data d
	INNER JOIN (SELECT *  FROM Lrf_f_GetExchangeDaily(@Today,@Today))e 
	ON e.exchangeid = d.currency
DROP TABLE #currency
GO
GRANT EXECUTE ON [dbo].[Lrf_TotalBets_Sel161] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_TotalBets_Sel161] TO [vnteam]
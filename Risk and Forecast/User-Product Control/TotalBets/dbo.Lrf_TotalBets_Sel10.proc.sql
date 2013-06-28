USE [bodb02]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER PROCEDURE [dbo].[Lrf_TotalBets_Sel10]
@LicenseeID INT,
@UserID		INT,
@CurrencyID INT=0,
@LicenseeType VARCHAR(100) = NULL,
@PageSize INT=50,
@PageIndex INT=0,
@TotalRows INT=0 OUTPUT
 AS
 
/*
Created: 20101201@Henry
Task : Retrieve Total Bet values for bettype 10
DB: DB052.bodb02
Original: Age_TotalBets_Sel10_Ag

Revisions:
   - 20110302@Henry: Allow to choose all type of licensee AND all currency + suppport based currency
   - 20110801@Henry: Remove PT + exclude BA ticket
   - 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily  
   - 20121004@Jim: replace @currencyname input param by @currencyID
   - 20130410@Jim: improve performance
   - 20130514@Jim:Restrict permission of Licensee Users by currency
   - 20130628@Jim: fix bug wrong totalwinlost value in case @CurrencyID=0
	 
Param's Explanation:
• @custid: agent ID
*/

SET NOCOUNT ON

DECLARE @Today smalldatetime 
SET @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120) 

SELECT  currencyID,LicenseeID into #currency
FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)
WHERE (@CurrencyID=0  OR (@CurrencyID<>0 AND CurrencyID=@CurrencyID))

DECLARE @TempAg as TABLE (custid INT)
INSERT INTO @TempAg (custid)
    SELECT  CustID  
                FROM    bodb_Licensee.dbo.LicenseeCust lc WITH (NOLOCK)
				INNER JOIN #currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID
                WHERE   [Description] = COALESCE(@LicenseeType,  
                                                     [Description])
----------------------
DROP TABLE #currency
---------------------
DECLARE @RowCount INT, @RowStart INT, @RowEnd INT  
SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1  

DECLARE @Data as TABLE
(
	matchcode VARCHAR (50),
	leagueid INT,
	teamid INT,
	orid INT,
	balance MONEY,
	balanceusd MONEY,
	balanceeur MONEY,
	betcount INT,
	totalwinlost MONEY,
	totalwinlostusd MONEY,
	totalwinlosteur MONEY,
	IsNeutral BIT
	
)


SELECT * INTO #TempExchange 
FROM Lrf_f_GetExchangeDaily(@Today,@Today)

INSERT INTO @Data
SELECT
		m.matchcode, 
		m.leagueid, 
		m.teamid,
		m.orid,
		SUM(stake) AS balance,
		SUM(stake*e.usd) AS balanceusd,
		SUM(stake*e.eur) AS balanceeur,
		SUM(1) as BetCount,
		SUM(stake*a.odds-stake) AS totalwinlost,
		SUM(stake*a.odds*e.usd-stake*e.usd) AS totalwinlostusd,
		SUM(stake*a.odds*e.eur-stake*e.eur) AS totalwinlosteur,
		CONVERT(BIT,0) as IsNeutral
	FROM
		bettrans AS a  WITH (NOLOCK)
		INNER JOIN outright AS m  WITH (NOLOCK) ON m.orid= a.matchid AND a.statusID = 0
		INNER JOIN @TempAg t ON a.recommend=t.custid
		INNER JOIN #TempExchange e 
		ON e.exchangeid = a.currency
	WHERE  	
		a.bettype = 10 AND
		a.statusID=0 AND
		a.tpositiontaking <>0
	GROUP BY 
		m.teamid,
		m.orid,
		m.matchcode, 
		m.leagueid,
		a.winlostdate,a.currency
	ORDER BY  a.winlostdate,a.currency

-----------------------------
DROP TABLE #TempExchange
----------------------------
SELECT c.*
FROM
(
	SELECT
		ROW_NUMBER() over (order by matchcode desc) as RowNum ,
		* FROM @Data
) as c
WHERE RowNum BETWEEN @RowStart AND @RowEnd

GO
GRANT EXECUTE ON [dbo].[Lrf_TotalBets_Sel10] TO [bodbLicenseeNet]

GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_TotalBets_Sel10] TO [vnteam]
ALTER  PROCEDURE [dbo].[Lrf_TotalBets_Sel10]
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
-----------------
DROP TABLE #currency
-----------------
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

DECLARE @Temp1 as TABLE
(
	matchcode VARCHAR (50),
	leagueid INT,
	teamid INT,
	orid INT,
	balance MONEY,
	balanceusd MONEY,
	balanceeur MONEY,
	betcount INT,
	wl MONEY,
	wlusd MONEY,
	wleur MONEY,
	IsNeutral BIT
)
SELECT * INTO #TempExchange 
FROM Lrf_f_GetExchangeDaily(@Today,@Today)

INSERT INTO @Temp1
SELECT
		m.matchcode, 
		m.leagueid, 
		m.teamid,
		m.orid,
		SUM(stake) AS balance,
		SUM(stake*e.usd) AS balanceusd,
		SUM(stake*e.eur) AS balanceeur,
		SUM(1) as BetCount,
		SUM(stake*a.odds) AS wl,
		SUM(stake*a.odds*e.usd) AS wlusd,
		SUM(stake*a.odds*e.eur) AS wleur,
		CONVERT(BIT,0) as IsNeutral
	FROM
		bettrans AS a  WITH (NOLOCK)
		INNER JOIN outright AS m  WITH (NOLOCK) ON m.orid     = a.matchid 
									AND a.statusID = 0
		INNER JOIN @TempAg t ON a.recommend=t.custid
		INNER JOIN #TempExchange e 
		ON e.exchangeid = a.currency
	WHERE  	
--		a.recommend IN (SELECT custid FROM @TempAg) AND
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

DECLARE @Temp2 as TABLE
(
	leagueid INT,
	totalbalance MONEY,
	totalbalanceusd MONEY,
	totalbalanceeur MONEY
)
INSERT INTO  @Temp2
SELECT 
						m.leagueid, 
						SUM(stake) as totalbalance,
						SUM(stake*e.usd) as totalbalanceusd,
						SUM(stake*e.eur) as totalbalanceeur
					FROM
						bettrans AS a  WITH (NOLOCK)
						INNER JOIN outright AS m  WITH (NOLOCK) ON m.orid = a.matchid  AND a.statusID = 0
						INNER JOIN 	@TempAg t ON a.recommend=t.custid
						INNER JOIN #TempExchange e ON e.exchangeid = a.currency
					WHERE  	
						a.bettype = 10 AND
						 a.statusID = 0 AND
						a.tpositiontaking <>0
						
					GROUP BY  m.leagueid
					ORDER BY   m.leagueid ASC 


INSERT INTO @Data
SELECT 
A.matchcode,
A.leagueid,
A.teamid,
A.orid,
A.balance,
A.balanceusd,
A.balanceeur,
A.BetCount,
A.wl - B.totalbalance as totalwinlost,
A.wlusd - B.totalbalanceusd as totalwinlostusd,
A.wleur - B.totalbalanceeur as totalwinlosteur,
A.IsNeutral 
FROM @Temp1 A
INNER JOIN @Temp2 B on A.leagueid = B.leagueid

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
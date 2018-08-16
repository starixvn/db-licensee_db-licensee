USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Lrf_TotalBets_Sel10]
@PageSize	INT=50,
@PageIndex	INT=0,
@TotalRows	INT=0 OUTPUT,
@AgentList	VARCHAR(MAX)
 AS
 
/*
Created: 20101201@Henry
Task : Retrieve Total Bet values for bettype 10
DB: DB042.bodb02
Original: Age_TotalBets_Sel10_Ag

Revisions:
   - 20110302@Henry: Allow to choose all type of licensee AND all currency + suppport based currency
   - 20110801@Henry: Remove PT + exclude BA ticket
   - 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily  
   - 20121004@Jim: replace @currencyname input param by @currencyID
   - 20130410@Jim: improve performance
   - 20130514@Jim:Restrict permission of Licensee Users by currency
   - 20141110@Winnie: Change from LicenseeCust table to [f_SelLicenseeCust] function
   - 20150123@Jim: support base on Currency GBP
   - 20170227@Harper: LRF - Get data by @AgentList instead of @UserID [RedmineID: #71679]
   - 20180802@Sophia: HA - Status IN (0,1) to use new index on DB042 [Redmine: #98631]

Param's Explanation:
	+ @AgentList: xml structure
					<ROOT>
					<Agent AgentId="12345" Currency="3"/>  
					<Agent AgentId="12345" Currency="5"/>  
					</ROOT>	
*/

SET NOCOUNT ON

DECLARE @Today smalldatetime 
SET @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120) 

DECLARE @TempAg AS TABLE ( CustId INT,Currency INT )
DECLARE @DocHandler INT

BEGIN TRY
	EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@AgentList
	INSERT INTO @TempAg (custID, currency)
	SELECT AgentId, Currency
	FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency INT) AS Data

	EXEC sp_xml_removedocument @DocHandler
END TRY

BEGIN CATCH
	SELECT ErrCode = 100
			,ErrMsg = N'Paramter invalid.'

	RETURN
END CATCH;

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
	balancegbp MONEY,
	betcount INT,
	totalwinlost MONEY,
	totalwinlostusd MONEY,
	totalwinlosteur MONEY,
	totalwinlostgbp MONEY,
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
	balancegbp MONEY,
	betcount INT,
	wl MONEY,
	wlusd MONEY,
	wleur MONEY,
	wlgbp MONEY,
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
		SUM(stake*e.gbp) AS balancegbp,
		SUM(1) as BetCount,
		SUM(stake*a.odds) AS wl,
		SUM(stake*a.odds*e.usd) AS wlusd,
		SUM(stake*a.odds*e.eur) AS wleur,
		SUM(stake*a.odds*e.gbp) AS wlgbp,
		CONVERT(BIT,0) as IsNeutral
	FROM
		bettrans AS a  WITH (NOLOCK)
		INNER JOIN outright AS m  WITH (NOLOCK) ON m.orid     = a.matchid 									
		INNER JOIN @TempAg t ON a.recommend = t.custid AND t.Currency = a.currency
		INNER JOIN #TempExchange e ON e.exchangeid = a.currency
	WHERE
		a.bettype = 10 AND
		a.statusID IN (0,1) AND
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
	totalbalanceeur MONEY,
	totalbalancegbp MONEY
)
INSERT INTO  @Temp2
SELECT 
						m.leagueid, 
						SUM(stake) as totalbalance,
						SUM(stake*e.usd) as totalbalanceusd,
						SUM(stake*e.eur) as totalbalanceeur,
						SUM(stake*e.gbp) as totalbalancegbp
					FROM
						bettrans AS a  WITH (NOLOCK)
						INNER JOIN outright AS m  WITH (NOLOCK) ON m.orid = a.matchid  
						INNER JOIN 	@TempAg t ON a.recommend = t.custid AND t.Currency = a.currency
						INNER JOIN #TempExchange e ON e.exchangeid = a.currency
					WHERE						
						a.bettype = 10 AND
						a.statusID IN (0,1) AND
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
A.balancegbp,
A.BetCount,
A.wl - B.totalbalance as totalwinlost,
A.wlusd - B.totalbalanceusd as totalwinlostusd,
A.wleur - B.totalbalanceeur as totalwinlosteur,
A.wleur - B.totalbalancegbp as totalwinlostgbp,
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
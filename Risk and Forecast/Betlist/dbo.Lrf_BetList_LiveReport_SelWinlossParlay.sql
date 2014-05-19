ALTER PROCEDURE [dbo].[Lrf_BetList_LiveReport_SelWinlossParlay]
	@LicenseeID INT ,
	@UserID		INT,
	@CurrencyID INT = 0,
    @Bettype INT = 9,
    @ShowBA BIT = 0,
    @ShowSB BIT = 0,
	@FromDate SMALLDATETIME,
	@ToDate SMALLDATETIME,
	@MoveBetsDay SMALLDATETIME,
	@PageSize INT=1000,
	@PageIndex INT=1,
	@Sort VARCHAR(20) = 'Transid DESC'
	
AS
/*
Created: Henry@20120111
Task : Betlist for Parlay
DB: DB052.bodb02
Original: [Age_BetList_SelWinlossParlay_Ag]
Revisions:    
	    -20120214@Jim: change table ExchangeDaily by function Lrf_f_GetExchangeDaily
	    - 20120319@Henry: show main transid for sub-ticket of system parlay 
		- 20120614@Jim: optimize code 
		- 20120724@Jim: add playercomm value 
		- 20121004@Jim: replace @currency input param by @currencyID
		- 20130305@Jim: remove Grand total row in the result data
		- 20130404@Jim: set default @ShowBA=0
		- 20130514@Jim:Restrict permission of Licensee Users by currency
		- 20130625@Jim: Support to view currency UUS
		- 20140507@Hannah: Sort betlist
Param's Explanation: 

*/
SET NOCOUNT ON

SELECT  currencyID,LicenseeID into #currency
FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)
WHERE (@CurrencyID=0  OR (@CurrencyID<>0 AND CurrencyID=@CurrencyID))

DECLARE @TempAg AS TABLE (custid INT)

INSERT  INTO @TempAg ( CustId)
SELECT  CustID  
FROM    bodb_Licensee.dbo.LicenseeCust lc WITH ( NOLOCK )  
		INNER JOIN #currency c ON c.LicenseeID=lc.LicenseeID AND c.CurrencyID=lc.Currency
-- WHERE   lc.Currency <> 20
------------------------------
DROP TABLE #currency 
------------------------------

CREATE TABLE #AgWinlossMP
(
	username NVARCHAR(50),
	custid INT,
	bettype SMALLINT,		
	refno NVARCHAR(50),		
	transid BIGINT,	
	BetID BIGINT,
	hdp1 SMALLMONEY,
	hdp2 SMALLMONEY,
	odds SMALLMONEY,
	modds SMALLMONEY,
	status NVARCHAR(50),
	Stake MONEY, 
	Actual_Stake	MONEY,
	winlost MONEY,
	licenseeWL MONEY,
	comm MONEY,
	playercomm MONEY,
	transdate DATETIME,
	winlostdate DATETIME,
	betteam NVARCHAR(25),
	liveindicator BIT,
	livehomescore SMALLINT,
	liveawayscore SMALLINT,
	IP VARCHAR(30),
	isNeutral BIT,
	currency SMALLINT,
	isBA INT	
)

IF @Todate > @MoveBetsDay
BEGIN
	IF @ShowBA = 1
	BEGIN
		INSERT INTO #AgWinlossMP 
		SELECT
			b.username,
			b.custid,
			b.bettype,		
			CONVERT(NVARCHAR,b.refno),		
			CASE WHEN bettype <> 29 THEN b.transid
				ELSE CASE WHEN ISNULL(b.BetID,0)=0 THEN b.transid ELSE betid END
				END AS transid,		
			ISNULL(b.BetID,0),
			b.hdp1,
			b.hdp2,
			b.odds,
			b.modds,
			b.status,
			b.stake,
			b.actual_stake, 
			(b.winlost-actual_stake),
			0 AS LicenseeWL ,
			b.comm,
			b.playercomm,
			b.transdate,
			b.winlostdate,
			b.betteam,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.IP AS IP,
			CONVERT(BIT,0) AS IsNeutral,
			b.currency,
			1 AS isBA
		FROM
			bettrans b WITH (nolock) 
		WHERE
			b.recommend IN (SELECT custid FROM @TempAg)	AND
			b.Winlostdate>=@FromDate AND
			b.Winlostdate<=@ToDate AND
			b.Bettype=@BetType AND
			b.matchid = @BetType AND
			b.tpositiontaking=0 AND
			b.statusID IN (111,112,113)		
	END

	IF @ShowSB = 1
	BEGIN
		INSERT INTO #AgWinlossMP 
		SELECT
			b.username,
			b.custid,
			b.bettype,		
			CONVERT(NVARCHAR,b.refno),		
			CASE WHEN bettype <> 29 THEN b.transid
				ELSE CASE WHEN ISNULL(b.BetID,0)=0 THEN b.transid ELSE betid END
				END AS transid,	
			ISNULL(b.BetID,0),
			b.hdp1,
			b.hdp2,
			b.odds,
			b.modds,
			b.status,
			b.stake,
			b.actual_stake, 
			(b.winlost-actual_stake),
			 -(b.winlost-b.actual_stake) AS LicenseeWL ,
			b.comm,
			b.playercomm,
			b.transdate,
			b.winlostdate,
			b.betteam,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.IP AS IP,
			CONVERT(BIT,0) AS IsNeutral,
			b.currency,
			0 AS isBA
		FROM
			bettrans b WITH (nolock) 				
		WHERE
			b.recommend IN (SELECT custid FROM @TempAg)	AND
			b.Winlostdate>=@FromDate AND
			b.Winlostdate<=@ToDate AND
			b.Bettype = @Bettype AND
			b.matchid = @Bettype AND
			b.tpositiontaking<>0 AND
			b.statusID IN (111,112,113)
	END	
END

IF @Fromdate <= @MoveBetsDay
BEGIN
	IF @ShowBA = 1
	BEGIN
		INSERT INTO #AgWinlossMP 
		SELECT
			b.username,
			b.custid,
			b.bettype,		
			CONVERT(NVARCHAR,b.refno),		
			CASE WHEN bettype <> 29 THEN b.transid
				ELSE CASE WHEN ISNULL(b.BetID,0)=0 THEN b.transid ELSE betid END
				END AS transid,	
			ISNULL(b.BetID,0),
			b.hdp1,
			b.hdp2,
			b.odds,
			b.modds,
			b.status,
			b.stake,
			b.actual_stake, 
			(b.winlost-actual_stake),
			0 AS LicenseeWL ,
			b.comm,
			b.playercomm,
			b.transdate,
			b.winlostdate,
			b.betteam,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.IP AS IP,
			CONVERT(BIT,0) AS IsNeutral,
			b.currency,
			1 AS IsBA
		FROM
			bettrans14 b WITH (nolock) 
		WHERE
			b.recommend IN (SELECT custid FROM @TempAg)	AND
			b.Winlostdate>=@FromDate AND
			b.Winlostdate<=@ToDate AND
			b.Bettype=@BetType AND
			b.matchid = @BetType AND
			b.tpositiontaking=0 AND
			b.statusID IN (111,112,113)	
	END	

	IF @ShowSB = 1
	BEGIN
		INSERT INTO #AgWinlossMP 
		SELECT
			b.username,
			b.custid,
			b.bettype,		
			CONVERT(NVARCHAR,b.refno),		
			CASE WHEN bettype <> 29 THEN b.transid
				ELSE CASE WHEN ISNULL(b.BetID,0)=0 THEN b.transid ELSE betid END
				END AS transid,		
			ISNULL(b.BetID,0),
			b.hdp1,
			b.hdp2,
			b.odds,
			b.modds,
			b.status,
			b.stake,
			b.actual_stake, 
			(b.winlost-actual_stake),
			 -(b.winlost-b.actual_stake) AS LicenseeWL ,
			b.comm,
			b.playercomm,
			b.transdate,
			b.winlostdate,
			b.betteam,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.IP AS IP,
			CONVERT(BIT,0) AS IsNeutral,
			b.currency,
			0 AS IsBA
		FROM
			bettrans14 b WITH (nolock) 		
		WHERE
			b.recommend IN (SELECT custid FROM @TempAg)	AND
			b.Winlostdate>=@FromDate AND
			b.Winlostdate<=@ToDate AND
			b.Bettype = @Bettype AND
			b.matchid = @Bettype AND
			b.tpositiontaking<>0 AND
			b.statusID IN (111,112,113) 
	END		
END

DECLARE @RowStart INT, @RowEnd INT  
SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1

CREATE NONCLUSTERED INDEX IDX_Index_Ag ON #AgWinlossMP (Currency)

SELECT * INTO #TempExchange 
FROM Lrf_f_GetExchangeDaily(@FromDate,@ToDate)
WHERE exchangeid IN (SELECT DISTINCT Currency FROM #AgWinlossMP)

DECLARE @sql NVARCHAR(2500)
DECLARE @SortTemp VARCHAR(250) 

IF (@Sort LIKE '%USD%') OR (@Sort LIKE '%EUR%')
BEGIN
	DECLARE @charindex INT
	SELECT @charindex = CHARINDEX( ' ', @Sort, 1)
	
	SELECT @SortTemp = substring (@Sort, 1, @charindex - 4) + '*e.'+SUBSTRING(@Sort, @charindex - 3,4) + SUBSTRING(@Sort, @charindex + 1, LEN(@Sort))
END
ELSE
BEGIN
	SET @SortTemp = @Sort
END

SELECT @sql = 
'SELECT A.* ,'''' betstatus, '''' matchcode, 0 homeid, 0 awayid, 0 leagueid, 0 matchid, 0 sporttype
FROM
(
	SELECT  
			ROW_NUMBER() over(ORDER BY '+@SortTemp +') AS RowNum,
			b.* ,
			SUBSTRING(c.username2,  CHARINDEX(''$'',c.username2)+1, len(c.username2)-CHARINDEX(''$'',c.username2)) AS nickname,
			--USD
			stake * e.USD stakeUSD,
			actual_stake * e.USD actual_stakeUSD,
			winlost * e.USD winlostUSD,
			LicenseeWL* e.USD LicenseeWLUSD,
			comm * e.USD commUSD,
			playercomm*e.USD PlayerCommUSD,
			--EUR
			stake * e.EUR stakeEUR,
			actual_stake * e.EUR actual_stakeEUR,
			winlost * e.EUR winlostEUR,
			LicenseeWL * e.EUR LicenseeWLEUR,
			comm * e.EUR commEUR,
			playercomm*e.EUR playercommEUR
			
	FROM #AgWinlossMP b
		INNER JOIN customer c WITH(NOLOCK) ON c.custid=b.custid
		INNER JOIN #TempExchange e ON b.currency=e.exchangeID AND b.winlostdate=e.exchangeDate
) A WHERE A.RowNum BETWEEN '+CAST(@RowStart AS VARCHAR(50))+' AND '+CAST(@RowEnd AS VARCHAR(50))
+' ORDER BY A.' +@Sort

EXEC (@sql)

DROP TABLE #AgWinlossMP
DROP TABLE #TempExchange 

GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_LiveReport_SelWinlossParlay] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_LiveReport_SelWinlossParlay] TO [vnteam] 
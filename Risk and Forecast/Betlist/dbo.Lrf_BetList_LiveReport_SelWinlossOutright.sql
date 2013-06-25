ALTER PROCEDURE [dbo].[Lrf_BetList_LiveReport_SelWinlossOutright]
	@LicenseeID INT ,
	@UserID		INT,
    @CurrencyID INT = 0 , 
	@FromDate SMALLDATETIME,
	@ToDate SMALLDATETIME,
	@ShowBA BIT = 0,
    @ShowSB BIT = 0,
	@MoveBetsDay SMALLDATETIME,
	@PageSize INT=1000,
	@PageIndex INT=0
	
AS
/*
Created: Henry@20120111
Task : get bet tickets for outright, horse racing in Live Report
DB: DB052.bodb02
Original: [Lrf_BetList_SelWinlossOutright]
		
Revisions:  
	    -20120214@Jim: change table ExchangeDaily by function Lrf_f_GetExchangeDaily  
		-20120614@Jim: optimize code
		-20120724@Jim: add playercomm value 
		-20121004@Jim: replace @currency input param by @currencyID
		-20130305@Jim: remove Grand Total Row in the result data	
		-20130404@Jim: set default @ShowBA=0
		-20130514@Jim: Restrict permission of Licensee Users by currency
		-20130625@Jim: support to view currency UUS
*/

SET NOCOUNT ON

SELECT  currencyID,LicenseeID into #currency
FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)
WHERE (@CurrencyID=0  OR (@CurrencyID<>0 AND CurrencyID=@CurrencyID))

DECLARE @TempAg AS TABLE (custid INT)

INSERT  INTO @TempAg ( CustId)
SELECT  lc.CustID  
FROM    bodb_Licensee.dbo.LicenseeCust lc WITH ( NOLOCK )  
		INNER JOIN #currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID 
-- WHERE   lc.Currency <> 20
		
----------------------------------
DROP TABLE #currency
----------------------------------
CREATE TABLE #AgWinlossOutright
(
	sporttype INT,
	CustID INT,
	bettype SMALLINT,			
	transid BIGINT,
	matchcode VARCHAR(50),
	homeID INT,
	awayID INT,
	hdp1 SMALLMONEY,
	hdp2 SMALLMONEY,
	odds SMALLMONEY,
	status NVARCHAR(50),
	stake MONEY,
	winlost MONEY,
	licenseeWL MONEY,
	comm MONEY,
	playercomm MONEY,
	transdate DATETIME,
	betteam NVARCHAR(50),
	liveindicator BIT,
	livehomescore SMALLINT,
	liveawayscore SMALLINT,
	leagueID INT,
	matchid INT, 
	IP VARCHAR(30),
	betstatus VARCHAR(50),
	isNeutral BIT,
	winlostdate DATETIME,
	currency SMALLINT,
	isBA INT
)


IF @Todate > @MoveBetsDay
BEGIN	
	IF @ShowBA = 1
	BEGIN		
		INSERT INTO #AgWinlossOutright 		
		SELECT
			l.sporttype,
			b.custid,
			b.bettype,					
			b.transid,
			m.matchcode,
			m.teamID,
			0,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.status,
			b.stake,
			(b.winlost-actual_stake),
			0 AS LicenseeWL ,
			b.comm,
			b.playercomm,
			b.transdate,
			b.betteam,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			l.leagueID,
			b.matchid, 
			b.IP AS IP,
			NULL,
			CONVERT(BIT,0) AS IsNeutral,
			b.winlostdate,
			b.currency ,
			1 AS isBA
		FROM
			bettrans b WITH (NOLOCK) 
			INNER JOIN outright m WITH (NOLOCK) ON b.matchid=m.orid	
			INNER JOIN League l WITH (NOLOCK) ON m.leagueID=l.leagueID	 	
			--INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid 	
		WHERE
			b.recommend IN (SELECT custid FROM @TempAg)	AND
			b.Winlostdate>=@FromDate AND
			b.Winlostdate<=@ToDate AND
			b.Bettype=10 AND
			b.tpositiontaking=0 AND
			b.statusID IN (111,112,113)
	END			

	IF @ShowSB = 1
	BEGIN		
		INSERT INTO #AgWinlossOutright 		
		SELECT
			l.sporttype,
			b.custid,
			b.bettype,					
			b.transid,
			m.matchcode,
			m.teamID,
			0,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.status,
			b.stake,
			(b.winlost-actual_stake),
			-(b.winlost-b.actual_stake)AS LicenseeWL ,
			b.comm,
			b.playercomm,
			b.transdate,
			b.betteam,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			l.leagueID,
			b.matchid, 
			b.IP AS IP,
			NULL,
			CONVERT(BIT,0) AS IsNeutral,
			b.winlostdate,
			b.currency ,
			0 AS IsBA
		FROM
			bettrans b WITH (NOLOCK) 
			INNER JOIN outright m WITH (NOLOCK) ON b.matchid=m.orid	
			INNER JOIN League l WITH (NOLOCK) ON m.leagueID=l.leagueID		
			
		WHERE
			b.recommend IN (SELECT custid FROM @TempAg)	AND
			b.Winlostdate>=@FromDate AND
			b.Winlostdate<=@ToDate AND
			b.Bettype=10 AND
			b.statusID IN (111,112,113) AND
			b.tpositiontaking<>0
			
			
	END		
	
	
END

IF @Fromdate <= @MoveBetsDay
BEGIN
	IF @ShowBA = 1
	BEGIN		
		INSERT INTO #AgWinlossOutright 		
		SELECT
			l.sporttype,
			b.custid,
			b.bettype,					
			b.transid,
			m.matchcode,
			m.teamID,
			0,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.status,
			b.stake,
			(b.winlost-actual_stake),
			0 AS LicenseeWL ,
			b.comm,
			b.playercomm,
			b.transdate,
			b.betteam,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			l.leagueID,
			b.matchid, 
			b.IP AS IP,
			NULL,
			CONVERT(BIT,0) AS IsNeutral,
			b.winlostdate,
			b.currency ,
			1 AS IsBA
		FROM
			bettrans14 b WITH (NOLOCK) 
			INNER JOIN outright14 m WITH (NOLOCK) ON b.matchid=m.orid	
			INNER JOIN League l WITH (NOLOCK) ON m.leagueID=l.leagueID	 	
			--INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid	 	
		WHERE
			b.recommend IN (SELECT custid FROM @TempAg)	AND
			b.Winlostdate>=@FromDate AND
			b.Winlostdate<=@ToDate AND
			b.Bettype=10 AND
			b.statusID IN (111,112,113) AND
			b.tpositiontaking=0
			
		
	END	

	IF @ShowSB = 1
	BEGIN		
		INSERT INTO #AgWinlossOutright 		
		SELECT
			l.sporttype,
			b.custid,
			b.bettype,					
			b.transid,
			m.matchcode,
			m.teamID,
			0,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.status,
			b.stake,
			(b.winlost-actual_stake),
			-(b.winlost-b.actual_stake)AS LicenseeWL ,
			b.comm,
			b.playercomm,
			b.transdate,
			b.betteam,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			l.leagueID,
			b.matchid, 
			b.IP AS IP,
			NULL,
			CONVERT(BIT,0) AS IsNeutral,
			b.winlostdate,
			b.currency ,
			0 AS IsBA
		FROM
			bettrans14 b WITH (NOLOCK) 
			INNER JOIN outright14 m WITH (NOLOCK) ON b.matchid=m.orid	
			INNER JOIN League l WITH (NOLOCK) ON m.leagueID=l.leagueID	  	 	
		WHERE
			b.recommend IN (SELECT custid FROM @TempAg)	AND
			b.Winlostdate>=@FromDate AND
			b.Winlostdate<=@ToDate AND
			b.Bettype=10 AND
			b.tpositiontaking<>0 AND
			b.statusID IN (111,112,113)
	END		
	
	
	
END


DECLARE @RowStart INT, @RowEnd INT  
SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1


CREATE NONCLUSTERED INDEX IDX_Index_Ag ON #AgWinlossOutright(Currency)


SELECT * INTO #TempExchange 
FROM Lrf_f_GetExchangeDaily(@FromDate,@ToDate)
WHERE exchangeid IN (SELECT DISTINCT Currency FROM #AgWinlossOutright)

SELECT A.* 
FROM
(
	SELECT  
			ROW_NUMBER() over(ORDER BY Transid) AS RowNum,
			b.* ,
			c.username,
			SUBSTRING(c.username2,  CHARINDEX('$',c.username2)+1, len(c.username2)-CHARINDEX('$',c.username2)) AS nickname,
			
			--USD
			stake*e.USD stakeUSD,
			winlost*e.USD winlostUSD,
			LicenseeWL*e.USD LicenseeWLUSD,
			comm*e.USD commUSD,
			playercomm*e.USD playercommUSD,
			
			--EUR
			stake*e.EUR stakeEUR,
			winlost*e.EUR winlostEUR,
			LicenseeWL*e.EUR LicenseeWLEUR,
			comm*e.EUR commEUR,
			playercomm*e.EUR playercommEUR
			
	FROM 
		#AgWinlossOutright b
		INNER JOIN customer c WITH(NOLOCK) ON c.custid=b.custid
		INNER JOIN #TempExchange e ON b.currency=e.exchangeID AND b.winlostdate=e.exchangeDate
) A WHERE A.RowNum BETWEEN @RowStart AND @RowEnd

DROP TABLE #AgWinlossOutright
DROP TABLE #TempExchange 
GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_LiveReport_SelWinlossOutright] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_LiveReport_SelWinlossOutright] TO [VNTeam] 
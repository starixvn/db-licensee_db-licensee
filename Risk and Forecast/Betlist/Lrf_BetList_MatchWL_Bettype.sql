set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go



ALTER PROCEDURE [dbo].[Lrf_BetList_MatchWL_Bettype]
	@MatchID INT,
	@LicenseeID INT,
	@UserID	 INT,
	@LicenseeType VARCHAR(100) = NULL,
	@CurrencyID INT=0,
	@bettype INT=0,
	@liveindicator INT = -1,
	@Langkey VARCHAR(10) = 'en-US',
	@PageSize INT=1000,
	@PageIndex INT=1,
	@TotalRows INT=0 OUTPUT,
	@SumWinlost MONEY=0 OUTPUT,
	@SumLicenseeWL MONEY=0 OUTPUT,
	@SumComm MONEY=0 OUTPUT,
	@SumPlayerComm MONEY=0 OUTPUT,
	@SumWinlostUSD MONEY=0 OUTPUT,
	@SumLicenseeWLUSD MONEY=0 OUTPUT,
	@SumCommUSD MONEY=0 OUTPUT,
	@SumPlayerCommUSD MONEY=0 OUTPUT,
	@SumWinlostEUR MONEY=0 OUTPUT,
	@SumLicenseeWLEUR MONEY=0 OUTPUT,
	@SumCommEUR MONEY=0 OUTPUT,
	@SumPlayerCommEUR MONEY=0 OUTPUT,
	@ShowSB BIT = 0,
	@ShowNG BIT = 0,
	@ShowBA BIT = 0,
	@ShowLC BIT = 0,
	@ShowVS BIT = 0,
	@Date SMALLDATETIME = NULL
AS

/*
Created: 20101209@Henry
Task : Betlist
DB: DB052.bodb02
Original:[Age_BetList_SelWinlossByBettypeMatch_Ag]
Revisions:
   -- 20110214@Jacob: Add column discount IN the result SET
   -- 20110216@Jacob: Add column nickname IN the result SET
   -- 20110303@Henry: suppport based currency
   -- 20110408@Amy: Change function to get Odds value AND odds type
   - 20110712@Henry: Add column LicenseeWL
   - 20110729@Henry: offer 3 new bettypes for Number Game
   - 20111208@Jim: Change condition bettype<31 
   - 20111229@Jim: change the way to get odds/oddstype/betteam to web dev
   - 20120214@Jim: change to use table ExchangeDaily by use function Lrf_f_GetExchangeDaily  
   - 20120614@Jim: optimize code 
   - 20120726@Jim: add playercomm value 
   - 20120817@Jim: add live casino 
   - 20120918@Jim: add virtual sport 
   - 20121004@Jim: replace @currencyname input param by @currencyID
   - 20121115@Henry: Only Sportsbook needs to exclude BA
   - 20121207@Henry: fix bug 1 match got 2 different winlostdate by add param @Date
   - 20130417@Jim: support base currency USD	
   - 20130514@Jim: Restrict permission of Licensee Users by currency
 
Param's Explanation: 
	
*/


SET NOCOUNT ON

DECLARE @_Date AS SMALLDATETIME
IF @Date IS NOT NULL
SET @_Date = @Date

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
DROP TABLE #Currency 
													 
DECLARE @Fromdate DATETIME
DECLARE @Todate  DATETIME

DECLARE @TempBettype AS TABLE (bettype INT PRIMARY KEY)

SELECT @bettype = isnull(@bettype,0)

CREATE TABLE #Data 
(
	Sporttype INT,
	Username NVARCHAR(50),
	CustID INT,
	Bettype INT,
	LeagueID INT,
	Transid BIGINT,
	Matchcode VARCHAR(50),
	HomeID INT,
	AwayID INT,
	hdp1 SMALLMONEY,
	hdp2 SMALLMONEY,
	odds SMALLMONEY,
	status NVARCHAR(50),
	stake MONEY,
	Winlost MONEY,
	licenseeWL MONEY,
	comm MONEY,
	playercomm MONEY,
	transdate DATETIME,
	Winlostdate DATETIME,
	betteam VARCHAR (50),
	liveindicator INT,
	livehomescore SMALLINT,
	liveawayscore SMALLINT,
	MatchID INT,
	Betstatus NVARCHAR(50),
	IsNeutral BIT,
	oddstype INT,
	betid BIGINT,
	currency SMALLINT,
	RefNO			BIGINT,	
	showtime NVARCHAR(50) -- table - shoe - hand of Live Casino
)

IF @ShowNG = 1
BEGIN
	INSERT INTO @TempBettype(bettype)
	SELECT typeid FROM bettype (NOLOCK)
	WHERE (typeid BETWEEN 81 AND 120)
END 

IF @ShowLC = 1
BEGIN
    INSERT INTO @TempBettype(bettype)
	SELECT typeid FROM bettype (NOLOCK)
	WHERE (typeid BETWEEN 1101 AND 1199)
END

IF @ShowVS = 1
BEGIN
	INSERT INTO @TempBettype(bettype)
	SELECT typeid FROM bettype (NOLOCK)
	WHERE (typeid BETWEEN 1201 AND 1299)
END 


IF EXISTS(SELECT TOP 1 1 FROM Match WITH(NOLOCK) WHERE MatchID=@MatchID)
BEGIN	
	
	IF @ShowBA = 1
	BEGIN
		INSERT INTO #Data	
		SELECT
			m.sporttype,
			b.username,
			b.custid,
			b.bettype,
			m.leagueID,			
			b.transid,
			m.matchcode,
			m.homeID,
			m.awayID,
			CONVERT(FLOAT, b.hdp1) AS hdp1, 
			CONVERT(FLOAT, b.hdp2) AS hdp2, 
			b.odds,
			b.status,
			b.stake,
			(b.winlost-actual_stake) winlost,
			0 AS LicenseeWL ,
			b.comm,
			b.playercomm  AS PlayerComm,
			b.transdate,
			b.winlostdate,
			b.betteam,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.matchid, 
			m.betstatus,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.OddsType,
			b.betid,
			b.currency,
			b.refno,
			'' AS ShowTime 
		FROM
			bettrans b WITH (NOLOCK) 
			INNER JOIN match m WITH (NOLOCK) ON b.matchid=m.matchid
		WHERE
			b.matchid=@matchid AND
			(@bettype=0 OR (@bettype<>0 AND b.bettype=@bettype)) AND
			b.recommend IN (SELECT custid FROM @TempAg)	AND
			b.statusID IN (111,112,113) AND
			b.tpositiontaking=0 AND
			(b.bettype<31 OR (b.bettype BETWEEN 121 AND 999)) AND
			((@Liveindicator=-1) OR (@Liveindicator=0 AND b.Liveindicator = 0) OR (@Liveindicator=1 AND b.Liveindicator = 1))	AND
			(@_Date IS NULL OR (@_Date IS NOT NULL AND b.winlostdate=@_Date))
		ORDER BY
			b.status, b.transid
			
		
	END

	IF (@ShowSB=1)
	BEGIN
		INSERT INTO #Data	
		SELECT
			m.sporttype,
			b.username,
			b.custid,
			b.bettype,
			m.leagueID,			
			b.transid,
			m.matchcode,
			m.homeID,
			m.awayID,
			CONVERT(FLOAT, b.hdp1) AS hdp1, 
			CONVERT(FLOAT, b.hdp2) AS hdp2, 
			b.odds,
			b.status,
			b.stake,
			(b.winlost-actual_stake) winlost,
			- (b.winlost-b.actual_stake) AS LicenseeWL ,
			b.comm,
			b.playercomm AS PlayerComm,
			b.transdate,
			b.winlostdate,
			b.betteam,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.matchid, 
			m.betstatus,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.OddsType,
			b.betid,
			b.currency,
			b.refno,
			'' AS ShowTime 
		FROM
			bettrans b WITH (NOLOCK) 
			INNER JOIN match m WITH (NOLOCK) ON b.matchid=m.matchid
		WHERE
			b.matchid=@matchid AND
			(@bettype=0 OR (@bettype<>0 AND b.bettype=@bettype)) AND
			(b.bettype<31 OR (b.bettype BETWEEN 121 AND 999)) AND
			b.recommend IN (SELECT custid FROM @TempAg)	AND
			b.statusID IN (111,112,113) AND
			b.tpositiontaking<>0 AND
			((@Liveindicator=-1) OR (@Liveindicator=0 AND b.Liveindicator = 0) OR (@Liveindicator=1 AND b.Liveindicator = 1)) AND
			(@_Date IS NULL OR (@_Date IS NOT NULL AND b.winlostdate=@_Date))
		ORDER BY
			b.status, b.transid
	END

	IF (@ShowNG = 1 OR @ShowLC=1 OR @ShowVS=1)
	BEGIN
		INSERT INTO #Data	
		SELECT
			m.sporttype,
			b.username,
			b.custid,
			b.bettype,
			m.leagueID,			
			b.transid,
			m.matchcode,
			m.homeID,
			m.awayID,
			CONVERT(FLOAT, b.hdp1) AS hdp1, 
			CONVERT(FLOAT, b.hdp2) AS hdp2, 
			b.odds,
			b.status,
			b.stake,
			(b.winlost-actual_stake) winlost,
			- (b.winlost-b.actual_stake) AS LicenseeWL ,
			b.comm,
			b.playercomm AS PlayerComm,
			b.transdate,
			b.winlostdate,
			b.betteam,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.matchid, 
			m.betstatus,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.OddsType,
			b.betid,
			b.currency,
			b.refno,
			CASE WHEN b.bettype BETWEEN 1101 AND 1199 THEN ISNULL(m.showtime,'') ELSE '' END AS ShowTime 
		FROM
			bettrans b WITH (NOLOCK) 
			INNER JOIN match m WITH (NOLOCK) ON b.matchid=m.matchid
			INNER JOIN @TempBettype bt ON b.bettype = bt.bettype
		WHERE
			b.matchid=@matchid AND
			(@bettype=0 OR (@bettype<>0 AND b.bettype=@bettype)) AND
			b.recommend IN (SELECT custid FROM @TempAg)	AND
			b.statusID IN (111,112,113) AND
			((@Liveindicator=-1) OR (@Liveindicator=0 AND b.Liveindicator = 0) OR (@Liveindicator=1 AND b.Liveindicator = 1)) AND
			(@_Date IS NULL OR (@_Date IS NOT NULL AND b.winlostdate=@_Date))
		ORDER BY
			b.status, b.transid
	END
	
	
END
ELSE
BEGIN			
	IF @ShowBA = 1
	BEGIN
		INSERT INTO #Data	
		SELECT
			m.sporttype,
			b.username,
			b.custid,
			b.bettype,
			m.leagueID,			
			b.transid,
			m.matchcode,
			m.homeID,
			m.awayID,
			CONVERT(FLOAT, b.hdp1) AS hdp1, 
			CONVERT(FLOAT, b.hdp2) AS hdp2, 
			b.odds,
			b.status,
			b.stake,
			(b.winlost-actual_stake) winlost,
			0 AS LicenseeWL ,
			b.comm,
			b.playercomm  AS PlayerComm,
			b.transdate,
			b.winlostdate,
			b.betteam,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.matchid, 
			m.betstatus,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.OddsType,
			b.betid,
			b.currency,
			b.refno,
			'' AS ShowTime 
		FROM
			bettrans14 b WITH (NOLOCK) 
			--INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid 
			INNER JOIN match14 m WITH (NOLOCK) ON b.matchid=m.matchid 				
		WHERE
			b.matchid=@matchid AND
			(@bettype=0 OR (@bettype<>0 AND b.bettype=@bettype)) AND
			b.recommend IN (SELECT custid FROM @TempAg) AND
			b.statusID IN (111,112,113) AND
			(b.bettype<31 OR (b.bettype BETWEEN 121 AND 999)) AND
			b.tpositiontaking=0 AND
			(@_Date IS NULL OR (@_Date IS NOT NULL AND b.winlostdate=@_Date)) AND
			1= CASE @Liveindicator 
				WHEN 0 THEN CASE WHEN b.Liveindicator = 0 THEN 1 ELSE 0 END
				WHEN 1 THEN CASE WHEN b.Liveindicator = 1 THEN 1 ELSE 0 END
				ELSE 1 
				END
		ORDER BY
			b.status, b.transid
			
		
	END

	IF (@ShowSB=1)
	BEGIN
		INSERT INTO #Data	
		SELECT
			m.sporttype,
			b.username,
			b.custid,
			b.bettype,
			m.leagueID,			
			b.transid,
			m.matchcode,
			m.homeID,
			m.awayID,
			CONVERT(FLOAT, b.hdp1) AS hdp1, 
			CONVERT(FLOAT, b.hdp2) AS hdp2, 
			b.odds,
			b.status,
			b.stake,
			(b.winlost-actual_stake) winlost,
			- (b.winlost-b.actual_stake) AS LicenseeWL ,
			b.comm,
			b.playercomm AS PlayerComm,
			b.transdate,
			b.winlostdate,
			b.betteam,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.matchid, 
			m.betstatus,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.OddsType,
			b.betid,
			b.currency,
			b.refno,
			CASE WHEN b.bettype BETWEEN 1101 AND 1199 THEN ISNULL(m.showtime,'') ELSE '' END AS ShowTime 
		FROM
			bettrans14 b WITH (NOLOCK) 
			INNER JOIN match14 m WITH (NOLOCK) ON b.matchid=m.matchid 		
		WHERE
			b.matchid=@matchid AND
			(@bettype=0 OR (@bettype<>0 AND b.bettype=@bettype)) AND
			(b.bettype<31 OR (b.bettype BETWEEN 121 AND 999)) AND
			b.recommend IN (SELECT custid FROM @TempAg) AND
			b.tpositiontaking <>0 AND
			b.statusID IN (111,112,113) AND
			((@Liveindicator=-1) OR (@Liveindicator=0 AND b.Liveindicator = 0) OR (@Liveindicator=1 AND b.Liveindicator = 1)) AND
			(@_Date IS NULL OR (@_Date IS NOT NULL AND b.winlostdate=@_Date))
		ORDER BY
			b.status, b.transid
	END

	IF (@ShowNG=1 OR @ShowLC=1 OR @ShowVS=1)
	BEGIN
		INSERT INTO #Data	
		SELECT
			m.sporttype,
			b.username,
			b.custid,
			b.bettype,
			m.leagueID,			
			b.transid,
			m.matchcode,
			m.homeID,
			m.awayID,
			CONVERT(FLOAT, b.hdp1) AS hdp1, 
			CONVERT(FLOAT, b.hdp2) AS hdp2, 
			b.odds,
			b.status,
			b.stake,
			(b.winlost-actual_stake) winlost,
			- (b.winlost-b.actual_stake) AS LicenseeWL ,
			b.comm,
			b.playercomm AS PlayerComm,
			b.transdate,
			b.winlostdate,
			b.betteam,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.matchid, 
			m.betstatus,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.OddsType,
			b.betid,
			b.currency,
			b.refno,
			CASE WHEN b.bettype BETWEEN 1101 AND 1199 THEN ISNULL(m.showtime,'') ELSE '' END AS ShowTime 
		FROM
			bettrans14 b WITH (NOLOCK) 
			INNER JOIN match14 m WITH (NOLOCK) ON b.matchid=m.matchid 		
			INNER JOIN @TempBettype bt ON b.bettype = bt.bettype
		WHERE
			b.matchid=@matchid AND
			(@bettype=0 OR (@bettype<>0 AND b.bettype=@bettype)) AND
			b.recommend IN (SELECT custid FROM @TempAg) AND
			b.statusID IN (111,112,113) AND
			((@Liveindicator=-1) OR (@Liveindicator=0 AND b.Liveindicator = 0) OR (@Liveindicator=1 AND b.Liveindicator = 1)) AND
			(@_Date IS NULL OR (@_Date IS NOT NULL AND b.winlostdate=@_Date))
		ORDER BY
			b.status, b.transid
	END
	
END

DECLARE @RowStart INT, @RowEnd INT  
SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1

DECLARE @Today SMALLDATETIME 
SET @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120)

SELECT @FromDate=CASE WHEN MIN(winlostdate)>@Today THEN @Today ELSE MIN(winlostdate) END,
	   @Todate=CASE WHEN MAX(winlostdate)>@Today THEN @Today ELSE MAX(winlostdate) END
FROM  #Data

 
CREATE NONCLUSTERED INDEX IDX_Index_Data ON #Data (Currency)

SELECT * INTO #TempExchange 
FROM Lrf_f_GetExchangeDaily(@FromDate,@ToDate)
WHERE exchangeid IN (SELECT DISTINCT Currency FROM #Data)

SELECT 
	@TotalRows = COUNT(transid),
	@SumWinlost=SUM(ISNULL(winlost,0)),
	@SumLicenseeWL=SUM(ISNULL(LicenseeWL,0)),
	@SumComm=SUM(ISNULL(comm,0)) ,
	@SumPlayerComm=SUM(ISNULL(playercomm,0)),
	--USD
	@SumWinlostUSD=SUM(ISNULL(winlost*e.USD,0)),
	@SumLicenseeWLUSD=SUM(ISNULL(LicenseeWL*e.USD,0)),
	@SumCommUSD=SUM(ISNULL(comm*e.USD,0)) ,
	@SumPlayerCommUSD=SUM(ISNULL(playercomm*e.USD,0)),
	--EUR
	@SumWinlostEUR=SUM(ISNULL(winlost*e.EUR,0)),
	@SumLicenseeWLEUR=SUM(ISNULL(LicenseeWL*e.EUR,0)),
	@SumCommEUR=SUM(ISNULL(comm*e.EUR,0)),
	@SumPlayerCommEUR=SUM(ISNULL(playercomm*e.EUR,0))	
FROM #Data b
	INNER JOIN #TempExchange e
	ON e.ExchangeDate = (CASE WHEN b.winlostdate <= @Today THEN  b.winlostdate ELSE @Today END)   AND e.exchangeid = b.currency

SELECT A.* 
FROM
(
	SELECT  
			ROW_NUMBER() over(ORDER BY b.status, b.transid) AS RowNum,
			b.* ,
			SUBSTRING(c.username2,  CHARINDEX('$',c.username2)+1, len(c.username2)-CHARINDEX('$',c.username2)) AS nickname,   		
			--USD
			stake*e.USD stakeUSD,
			Winlost*e.USD WinlostUSD,
			LicenseeWL*e.USD LicenseeWLUSD,
			comm*e.USD commUSD,
			playercomm*e.USD PlayerCommUSD,
			stake*e.EUR stakeEUR,
			Winlost*e.EUR WinlostEUR,
			LicenseeWL*e.EUR LicenseeWLEUR,
			comm*e.EUR commEUR,
			playercomm*e.EUR PlayerCommEUR
	FROM #Data b
	INNER JOIN Customer c (NOLOCK) ON b.custid = c.custid
	INNER JOIN #TempExchange e
	ON e.ExchangeDate = (CASE WHEN b.winlostdate <= @Today THEN  b.winlostdate ELSE @Today END)   AND e.exchangeid = b.currency
) A WHERE A.RowNum BETWEEN @RowStart AND @RowEnd

DECLARE @BettransDetail TABLE(  
	refno BIGINT,  
	odds SMALLMONEY,  
	stake MONEY,
	status NVARCHAR(10),  
	apositiontaking SMALLMONEY,  
	bettype SMALLINT,
	Betteam nvarchar (10),
	stakeEUR MONEY,
	stakeUSD MONEY	
	 )   

IF @ShowLC=1
BEGIN
	IF EXISTS(SELECT TOP 1 1 FROM Match WITH(NOLOCK) WHERE MatchID=@MatchID)
	BEGIN
		INSERT INTO @BettransDetail
		SELECT 
			BG.refno, 
			BG.odds, 
			BG.stake,
			BG.status, 
			BG.apositiontaking, 
			BG.bettype  ,
			BG.Betteam,
			BG.stake*e.EUR,
			BG.stake*e.USD
		FROM bettransg BG WITH (NOLOCK)
		INNER JOIN #Data B ON BG.refno = B.refno and BG.custid = B.custid
		INNER JOIN #TempExchange e ON e.ExchangeDate = B.winlostdate   AND e.exchangeid = B.currency
		WHERE B.Bettype BETWEEN 1101 AND 1199
	END
		
	IF EXISTS(SELECT TOP 1 1 FROM Match14 WITH(NOLOCK) WHERE MatchID=@MatchID)
	BEGIN
		INSERT INTO @BettransDetail
		SELECT 
			BG.refno, 
			BG.odds, 
			BG.stake,
			BG.status, 
			BG.apositiontaking, 
			BG.bettype  ,
			BG.Betteam ,
			BG.stake*e.EUR,
			BG.stake*e.USD	
		FROM bettransg14 BG WITH (NOLOCK)
		INNER JOIN #Data B ON BG.refno = B.refno and BG.custid = B.custid
		INNER JOIN #TempExchange e ON e.ExchangeDate = B.winlostdate   AND e.exchangeid = B.currency
		WHERE B.Bettype BETWEEN 1101 AND 1199
	END	
END


SELECT * FROM @BettransDetail ORDER BY RefNo,Bettype

DROP TABLE #TempExchange
DROP TABLE #Data

GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_MatchWL_Bettype] TO [bodbLicenseeNet]

GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_MatchWL_Bettype] TO vnteam




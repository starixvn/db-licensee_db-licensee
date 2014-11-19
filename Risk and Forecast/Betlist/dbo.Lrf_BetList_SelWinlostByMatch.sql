ALTER PROCEDURE [dbo].[Lrf_BetList_SelWinlossByMatch]
	@MatchID INT,
	@LicenseeID INT,
	@UserID	 INT,
	@CurrencyID INT=0,
	@LicenseeType VARCHAR(100) = NULL,	
	@PageSize INT=1000,
	@PageIndex INT=1,	
	@ShowSB BIT = 0,	
	@ShowBA BIT = 0,
	@ShowLC BIT = 0,
	@ShowVS BIT = 0 
AS

/*
Created: 20111109@Jacob
Task : Betlist
DB: DB052.bodb02
Original:[Lrf_BetList_SelWinlossByBettypeMatch]
Revisions:
	-20111229@Jim: change the way to get odds/oddstype/betteam to web dev
	-20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily  
	-20120726@Jim: add playercomm value 
	-20120817@Jim: add live casino 
	-20120913@Jim: add virtual sport 
	-20121004@Jim: replace @currencyname input param by @currencyID
	- 20121115@Henry: Only Sportsbook needs to exclude BA
	- 20130411@Jim: support base currency USD
	- 20130514@Jim: Restrict permission of Licensee Users by currency
	- 20130904@Jim: support Virtual Horse Racing
	- 20141111@Winnie: change from LicenseeCust to f_SelLicenseeCust 
   Get all tickets for a match
Param's Explanation: 
	
*/


SET NOCOUNT ON

SELECT  currencyID,LicenseeID into #currency
FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)
WHERE (@CurrencyID=0  OR (@CurrencyID<>0 AND CurrencyID=@CurrencyID))

DECLARE @TempAg AS TABLE (custid INT)
INSERT INTO @TempAg (custid)
SELECT DISTINCT CustID 
FROM bodb_Licensee.dbo.f_SelLicenseeCust(0) lc --WITH ( NOLOCK )
	INNER JOIN #Currency c ON lc.LicenseeID=c.LicenseeID  AND lc.Currency=c.CurrencyID
WHERE    [Description] = COALESCE(@LicenseeType,[Description])    




DECLARE @RowStart INT, @RowEnd INT  
SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1
DECLARE @Fromdate DATETIME
DECLARE @Todate  DATETIME
DECLARE @bettype AS TABLE (bettype INT)  

IF @ShowLC = 1
BEGIN
	
    INSERT INTO @bettype(bettype)
	SELECT typeid FROM bettype (NOLOCK)
	WHERE (typeid BETWEEN 1101 AND 1199)
END



IF @ShowVS = 1
BEGIN
	INSERT INTO @bettype(bettype)
	SELECT typeid FROM bettype (NOLOCK)
	WHERE (typeid BETWEEN 1201 AND 1299)
END 

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
	ip NVARCHAR(30),
	Betstatus NVARCHAR(50),
	IsNeutral BIT,
	oddstype INT,
	betid BIGINT,
	refno BIGINT,
	currency SMALLINT,
	showtime NVARCHAR(50) -- table - shoe - hand of Live Casino
)




IF EXISTS(SELECT TOP 1 1 FROM Match WITH(NOLOCK) WHERE MatchID=@MatchID)
BEGIN	
	IF @ShowBA = 1
	BEGIN
		INSERT INTO #Data	
		SELECT TOP(@RowEnd)
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
			b.IP AS IP,
			m.betstatus,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.OddsType,
			b.betid,
			'' AS refno,
			b.currency,
			'' AS ShowTime 
		FROM
			bettrans b WITH (NOLOCK) 
			--INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid 	 		
			INNER JOIN match m WITH (NOLOCK) ON b.matchid=m.matchid
		WHERE
			b.matchid=@matchid AND			
			(b.bettype<31 OR (b.bettype BETWEEN 121 AND 999)) AND
			b.recommend IN (SELECT custid FROM @TempAg)	AND
			((@CurrencyID=0 AND currency IN (SELECT currencyId FROM #currency))  OR (@CurrencyID<>0 AND Currency=@CurrencyID)) AND
			b.ruben=1 AND 			
			b.tpositiontaking=0 AND
			b.statusID NOT IN (101, 102, 103)
			
		ORDER BY
			b.status, b.transid
			
			
		
	END

	IF (@ShowSB=1)
	BEGIN
		INSERT INTO #Data	
		SELECT TOP(@RowEnd)
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
			b.playercomm  AS PlayerComm,
			b.transdate,
			b.winlostdate,
			b.betteam,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.matchid, 
			b.IP AS IP,
			m.betstatus,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.OddsType,
			b.betid,
			b.refno,
			b.currency,
			CASE WHEN b.bettype BETWEEN 1101 AND 1199 THEN ISNULL(m.showtime,'') ELSE '' END AS ShowTime
		FROM
			bettrans b WITH (NOLOCK) 
			INNER JOIN match m WITH (NOLOCK) ON b.matchid=m.matchid
		WHERE
			b.matchid=@matchid AND			
			b.recommend IN (SELECT custid FROM @TempAg)	AND
			((@CurrencyID=0 AND currency IN (SELECT currencyId FROM #currency))  OR (@CurrencyID<>0 AND Currency=@CurrencyID)) AND
			(b.bettype<31 OR (b.bettype BETWEEN 121 AND 999)) AND
			b.ruben=1 AND 			
			b.tpositiontaking<>0 AND
			b.statusID NOT IN (101, 102, 103)
		ORDER BY
			b.status, b.transid
	END


	IF (@ShowLC=1 OR @ShowVS=1)
	BEGIN
		INSERT INTO #Data	
		SELECT TOP(@RowEnd)
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
			b.playercomm  AS PlayerComm,
			b.transdate,
			b.winlostdate,
			b.betteam,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.matchid, 
			b.IP AS IP,
			m.betstatus,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.OddsType,
			b.betid,
			b.refno,
			b.currency,
			CASE WHEN b.bettype BETWEEN 1101 AND 1199 THEN ISNULL(m.showtime,'') ELSE '' END AS ShowTime
		FROM
			bettrans b WITH (NOLOCK) 
			INNER JOIN match m WITH (NOLOCK) ON b.matchid=m.matchid
			INNER JOIN @bettype bt ON b.bettype = bt.bettype
		WHERE
			b.matchid=@matchid AND			
			b.recommend IN (SELECT custid FROM @TempAg)	AND
			((@CurrencyID=0 AND currency IN (SELECT currencyId FROM #currency))  OR (@CurrencyID<>0 AND Currency=@CurrencyID)) AND
			b.ruben=1 AND 			
			b.statusID NOT IN (101, 102, 103)
		ORDER BY
			b.status, b.transid
		IF EXISTS (SELECT 1 FROM @bettype WHERE bettype IN (1231, 1232, 1233, 1237, 1238))
			BEGIN 
				INSERT INTO #Data	
				SELECT TOP(@RowEnd)
					r.sporttype,
					b.username,
					b.custid,
					b.bettype,
					r.leagueID,			
					b.transid,
					CONVERT (VARCHAR(50),o.RacerNum) matchcode,
					o.RacerID homeID,
					0 awayID,
					CONVERT(FLOAT, b.hdp1) AS hdp1, 
					CONVERT(FLOAT, b.hdp2) AS hdp2, 
					b.odds,
					b.status,
					b.stake,
					(b.winlost-actual_stake) winlost,
					- (b.winlost-b.actual_stake) AS LicenseeWL ,
					b.comm,
					b.playercomm  AS PlayerComm,
					b.transdate,
					b.winlostdate,
					b.betteam,
					b.liveindicator,
					b.livehomescore,
					b.liveawayscore,
					b.matchid, 
					b.IP AS IP,
					r.betstatus,
					ISNULL(0, CONVERT(BIT,0)) AS IsNeutral,
					b.OddsType,
					b.betid,
					b.refno,
					b.currency,
					r.EventTime AS ShowTime
				FROM
					bettrans b WITH (NOLOCK) 
					INNER JOIN VSOutright o with (nolock) ON b.oddsid=o.Orid
					INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID	
					INNER JOIN @bettype bt ON b.bettype = bt.bettype
				WHERE
					b.matchid=@matchid AND			
					b.recommend IN (SELECT custid FROM @TempAg)	AND
					((@CurrencyID=0 AND currency IN (SELECT currencyId FROM #currency))  OR (@CurrencyID<>0 AND Currency=@CurrencyID)) AND
					b.ruben=1 AND 			
					b.statusID NOT IN (101, 102, 103)
				ORDER BY
					b.status, b.transid
			END
	END
	
	
END
ELSE
BEGIN
	IF @ShowBA = 1
	BEGIN
		INSERT INTO #Data	
		SELECT TOP(@RowEnd)
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
			b.playercomm AS PlayerComm,
			b.transdate,
			b.winlostdate,
			b.betteam,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.matchid, 
			b.IP AS IP,
			m.betstatus,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.OddsType,
			b.betid,
			b.currency,
			'' AS refno, 
			'' AS ShowTime 
		FROM
			bettrans14 b WITH (NOLOCK) 			
			--INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid 	 		
			INNER JOIN @TempAg t  ON b.recommend =t.custid  
			INNER JOIN match14 m WITH (NOLOCK) ON b.matchid=m.matchid
		WHERE
			b.matchid=@matchid AND
			((@CurrencyID=0 AND currency IN (SELECT currencyId FROM #currency))  OR (@CurrencyID<>0 AND Currency=@CurrencyID)) AND					
			b.ruben=1 AND 
			(b.bettype<31 OR (b.bettype BETWEEN 121 AND 999)) AND
			b.tpositiontaking=0 AND
			b.statusID NOT IN (101, 102, 103)
			
		ORDER BY
			b.status, b.transid
			
		
	END

	IF (@ShowSB=1)
	BEGIN
		INSERT INTO #Data	
		SELECT TOP(@RowEnd)
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
			b.IP AS IP,
			m.betstatus,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.OddsType,
			b.betid,
			b.refno,
			b.currency,
			CASE WHEN b.bettype BETWEEN 1101 AND 1199 THEN ISNULL(m.showtime,'') ELSE '' END AS ShowTime 
		FROM
			bettrans14 b WITH (NOLOCK) 
			INNER JOIN @TempAg t  ON b.recommend =t.custid  
			INNER JOIN match14 m WITH (NOLOCK) ON b.matchid=m.matchid
		WHERE
			b.matchid=@matchid AND				
			((@CurrencyID=0 AND currency IN (SELECT currencyId FROM #currency))  OR (@CurrencyID<>0 AND Currency=@CurrencyID)) AND
			b.ruben=1 AND 			
			b.tpositiontaking<>0 AND
			(b.bettype<31 OR (b.bettype BETWEEN 121 AND 999)) AND
			b.statusID NOT IN (101, 102, 103)
		ORDER BY
			b.status, b.transid
	END

	IF (@ShowLC=1 OR @ShowVS=1)
	BEGIN
		INSERT INTO #Data	
		SELECT TOP(@RowEnd)
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
			b.IP AS IP,
			m.betstatus,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.OddsType,
			b.betid,
			b.refno,
			b.currency,
			CASE WHEN b.bettype BETWEEN 1101 AND 1199 THEN ISNULL(m.showtime,'') ELSE '' END AS ShowTime 
		FROM
			bettrans14 b WITH (NOLOCK) 
			INNER JOIN @TempAg t  ON b.recommend =t.custid  
			INNER JOIN match14 m WITH (NOLOCK) ON b.matchid=m.matchid
			INNER JOIN @bettype bt ON b.bettype = bt.bettype
		WHERE
			b.matchid=@matchid AND	
			((@CurrencyID=0 AND currency IN (SELECT currencyId FROM #currency))  OR (@CurrencyID<>0 AND Currency=@CurrencyID)) AND				
			b.ruben=1 AND 			
			b.statusID NOT IN (101, 102, 103)
		ORDER BY
			b.status, b.transid
		IF EXISTS (SELECT 1 FROM @bettype WHERE bettype IN (1231, 1232, 1233, 1237, 1238))
			BEGIN 
				INSERT INTO #Data	
				SELECT TOP(@RowEnd)
					r.sporttype,
					b.username,
					b.custid,
					b.bettype,
					r.leagueID,			
					b.transid,
					CONVERT (VARCHAR(50),o.RacerNum) matchcode,
					o.RacerID homeID,
					0 awayID,
					CONVERT(FLOAT, b.hdp1) AS hdp1, 
					CONVERT(FLOAT, b.hdp2) AS hdp2, 
					b.odds,
					b.status,
					b.stake,
					(b.winlost-actual_stake) winlost,
					- (b.winlost-b.actual_stake) AS LicenseeWL ,
					b.comm,
					b.playercomm  AS PlayerComm,
					b.transdate,
					b.winlostdate,
					b.betteam,
					b.liveindicator,
					b.livehomescore,
					b.liveawayscore,
					b.matchid, 
					b.IP AS IP,
					r.betstatus,
					ISNULL(0, CONVERT(BIT,0)) AS IsNeutral,
					b.OddsType,
					b.betid,
					b.refno,
					b.currency,
					r.EventTime AS ShowTime
				FROM
					bettrans14 b WITH (NOLOCK) 
					INNER JOIN VSOutright14 o with (nolock) ON b.oddsid=o.Orid
					INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID	
					INNER JOIN @bettype bt ON b.bettype = bt.bettype
				WHERE
					b.matchid=@matchid AND			
					b.recommend IN (SELECT custid FROM @TempAg)	AND
					((@CurrencyID=0 AND currency IN (SELECT currencyId FROM #currency))  OR (@CurrencyID<>0 AND Currency=@CurrencyID)) AND
					b.ruben=1 AND 			
					b.statusID NOT IN (101, 102, 103)
				ORDER BY
					b.status, b.transid
			END	
	END
	
END

SELECT @fromdate=MIN(winlostdate),@Todate=MAX(winlostdate) 
FROM #Data


CREATE NONCLUSTERED INDEX IDX_Index_Data ON #Data (Currency)

SELECT * INTO #TempExchange 
FROM Lrf_f_GetExchangeDaily(@FromDate,@ToDate)
WHERE exchangeid IN (SELECT DISTINCT Currency FROM #Data)

SELECT A.* 
FROM
(
	SELECT  
			ROW_NUMBER() over(ORDER BY b.transid) AS RowNum,
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
	INNER JOIN  #TempExchange e
	ON e.ExchangeDate = b.winlostdate  AND e.exchangeid = b.currency
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
INSERT INTO @BettransDetail
 SELECT 
	BG.refno, 
	BG.odds, 
	BG.stake,
	BG.status, 
	BG.apositiontaking, 
	BG.bettype,
	BG.betteam,
	BG.stake*e.EUR,
	BG.stake*e.USD	
FROM bettransg BG WITH (NOLOCK)
INNER JOIN #Data B ON BG.refno = B.refno and BG.custid = B.CustID
INNER JOIN #TempExchange e ON e.ExchangeDate = B.winlostdate   AND e.exchangeid = B.currency
WHERE B.Bettype BETWEEN 1101 AND 1199	
END

SELECT * FROM  @BettransDetail
ORDER BY RefNo,Bettype
 
DROP TABLE #Data
DROP TABLE #TempExchange
DROP TABLE #Currency 

GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_SelWinlossByMatch] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_SelWinlossByMatch] TO vnteam

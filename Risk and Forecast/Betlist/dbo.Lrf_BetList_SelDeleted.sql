USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_BetList_SelDeleted_xtest]    Script Date: 11/29/2014 09:42:23 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Lrf_BetList_SelDeleted]
	@LicenseeID	INT ,
	@UserID		INT,
	@CustID		INT,
	@CurrencyID	INT				= 0,
	@Langkey	NVARCHAR(10)	= 'en-US',
	@PageSize	INT				= 1000,
	@PageIndex	INT				= 1,
	@TotalRows	INT				= 0 OUTPUT
AS

/*
	Create: Henry@20101210
	Tas :
	DB: DBEXT.bodb02
	Original: Age_BetList_SelDeleted 

	Revisions:
		- 20110216@Jacob: Add column nickname in the result SET
		- 20110303@Henry: suppport based currency
		- 20110408@Amy: Change function to get Odds value AND odds type
		- 20110714@Henry: remove apositiontaking
		- 20110729@Henry: offer 3 new bettypes for Number Game
		- 20111229@Jim: change the way to get odds/oddstype/betteam to web dev
		- 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily
		- 20120614@Jim: optimize code
		- 20120816@Henry: add ShowLiveCasino
		- 20130411@Jim: support base currency
		- 20130514@Jim:Restrict permission of Licensee Users by currency
		- 20130809@Jim: offer Virtual Horse Racing
		- 20140403@Hannah: offer Keno
		- 20140521@Jim: fix bug not show outright tikect  (bug #16525)
		- 20140925@Jim: restrict Virtual Horse Racing bettype (hot fix #22012)
		- 20141129@Jim: add more param @CurrencyID	
		- 20150128@Winnie: add base currency GBP
		- 20150409@Winnie: Apply spottype bettype matrix & 60 bettypes betradar
		- 20150423@Jim: fix bug 
		- 20150609@Edward : Support BetTrade
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20160201@Kos: Support PH All In One 1.2 [#Redmine: 50897]

	Param's Explanation:
		+ @CustID: AgentID
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @recommend INT
	DECLARE @Fromdate DATETIME
	DECLARE @Todate DATETIME

	DECLARE @SportBettype TABLE(ProductID INT, Bettype INT, EventType INT)

	INSERT INTO @SportBettype
	EXEC bodb02.dbo.Acc_SportBettypeMatrix_Sel @mode = 4

	SELECT currencyID,
		LicenseeID 
	INTO #currency
	FROM dbo.Lrf_f_GetCurrencybyUser(@licenseeID, @userID, 1)-- System is default=1 (LRF) 

	SELECT @recommend = recommend 
	FROM dbo.customer AS c WITH (NOLOCK)
		INNER JOIN 	#currency AS cy ON c.currency = cy.currencyID
	WHERE custid = @custid

	CREATE TABLE #Data 
	(
		Sporttype		SMALLINT,
		username		NVARCHAR(50),
		CustID			INT,
		transid			BIGINT,
		transdate		DATETIME,
		winlostdate		DATETIME,
		refno			NVARCHAR(50),
		homeid			INT, 
		awayid			INT, 
		betteam			NVARCHAR(50),
		bettype			SMALLINT,
		hdp1			SMALLMONEY,
		hdp2			SMALLMONEY,
		Modds			MONEY,
		oddstype		TINYINT,
		odds			MONEY,
		stake			MONEY,
		status			NVARCHAR(50),
		liveindicator	BIT,
		livehomescore	SMALLINT,
		liveawayscore	SMALLINT,
		leagueid		INT,
		matchid			INT,
		matchcode		NVARCHAR(50),
		race			NVARCHAR(50),
		eventdate		DATETIME,
		IP				VARCHAR(30),
		isNeutral		BIT,
		betid			BIGINT,
		currency		SMALLINT,
		showtime		NVARCHAR(50), -- table - shoe - hand of Live Casino
		betcheck		NVARCHAR(50),
		transdesc		NVARCHAR(300)
	)

	-- Keno
	INSERT INTO #Data
	SELECT 
		202 AS Sporttype,
		b.Username,
		b.CustID,
		b.TransID,
		b.Transdate,
		b.winlostdate,
		b.refno,
		0 AS HomeID,
		0 AS AwayID,
		t.ChoiceId AS betteam,
		b.Bettype,
		0 AS Hdp1,
		0 AS Hdp2,
		b.modds,
		b.OddsType,
		b.odds,
		b.Stake,
		b.Status,
		b.Liveindicator,
		b.Livehomescore,
		b.Liveawayscore,
		0 AS LeagueID,
		t.GameId AS matchid,
		'' AS matchcode,
		'' AS Race,
		winlostdate AS eventdate,
		b.IP,
		CONVERT(BIT,0) AS IsNeutral,
		b.betid,
		b.currency,
		'' AS ShowTime,
		'' AS betcheck,
		'' AS transdesc
	FROM 
		dbo.bettrans AS b WITH (NOLOCK)
		CROSS APPLY dbo.[f_ParseTransDesc](b.TransDesc, b.bettype) AS t
		INNER JOIN @SportBettype AS sbt ON sbt.Bettype = b.bettype
	WHERE
		b.custid = @CustID
		AND b.recommend = @recommend
		AND b.statusID IN (101, 102)
		AND b.winlostdate > DATEADD(DAY, -3, CURRENT_TIMESTAMP)
		AND sbt.productId = 8
		AND b.ruben = 1

	-- Others
	INSERT INTO #Data
	SELECT 
		m.Sporttype,
		b.Username,
		b.CustID,
		b.TransID,
		b.Transdate,
		b.winlostdate,
		b.refno,
		m.HomeID,
		m.AwayID,
		b.betteam,
		b.Bettype,
		CONVERT(FLOAT, b.hdp1) AS Hdp1,
		CONVERT(FLOAT, b.hdp2) AS Hdp2,
		modds,
		b.OddsType,
		b.odds,
		b.Stake,
		b.Status,
		b.Liveindicator,
		b.Livehomescore,
		b.Liveawayscore,
		m.LeagueID,
		m.matchid,
		m.matchcode,
		'' AS Race,
		eventdate,
		b.IP,
		ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
		b.betid,
		b.currency,
		'' AS ShowTime,
		b.betcheck,
		ISNULL(b.transdesc, '') AS transdesc
	FROM 
		dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN 
			(	SELECT 
					sporttype,
					homeid,
					awayid,
					leagueid,
					matchid,
					matchcode,
					eventdate,
					isneutral,
					showtime 
				FROM dbo.match WITH (NOLOCK) 
				WHERE eventdate > DATEADD(DAY, -3, CURRENT_TIMESTAMP)
			) AS m ON b.matchid = m.matchid
		INNER JOIN @SportBettype AS sbt ON sbt.Bettype = b.bettype
	WHERE
		b.custid = @CustID
		AND b.recommend = @recommend
		AND b.statusID IN (101, 102)
		AND sbt.ProductID != 8
		AND b.bettype NOT IN (SELECT bettype FROM dbo.f_VSHorseRacingByBettype()) 

	-- Outright/Horse Racing
	UNION ALL
	SELECT 
		l.Sporttype,
		b.Username,
		b.CustID,
		b.TransID,
		b.Transdate,
		b.winlostdate,
		b.refno,
		m.HomeID,
		0 AS AwayID,
		'' AS Betteam,
		b.Bettype,
		0 AS Hdp1,
		0 AS Hdp2,
		modds,
		0 AS OddsType,
		b.odds,
		b.Stake,
		b.status,
		0 AS Liveindicator,
		0 AS Livehomescore,
		0 AS Liveawayscore,
		m.LeagueID,
		b.matchID,
		m.matchcode,
		m.groupmatch AS Race,
		m.eventdate,
		b.IP,
		CONVERT(BIT,0) AS IsNeutral,
		b.betid,
		b.currency,
		'' AS ShowTime,
		'' AS betcheck,
		'' AS transdesc
	FROM 
		dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN 
			(	SELECT 
					teamid AS homeid,
					leagueid,
					orid,
					matchcode,
					groupmatch,
					eventdate
				FROM dbo.outright WITH (NOLOCK)
				WHERE eventdate > DATEADD(DAY, -3, CURRENT_TIMESTAMP)
			) AS m ON b.matchid = m.orid
		INNER JOIN dbo.league AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
		INNER JOIN @SportBettype AS sbt ON sbt.Bettype = b.bettype
	WHERE
		(sbt.ProductID = 2 OR (sbt.ProductID = 1 AND sbt.EventType = 2))
		AND b.recommend = @recommend
		AND b.custid = @CustID
		AND b.statusID IN (101, 102)

	-- Virtual Horse Racing
	UNION ALL
	SELECT 
		vhr.Sporttype,
		b.Username,
		b.CustID,
		b.TransID,
		b.Transdate,
		b.winlostdate,
		b.refno,
		vhr.HomeID,
		0 AS AwayID,
		'' AS Betteam,
		b.Bettype,
		0 AS Hdp1,
		0 AS Hdp2,
		modds,
		0 AS OddsType, 
		b.odds,
		b.Stake,
		b.status,
		0 AS Liveindicator,
		0 AS Livehomescore,
		0 AS Liveawayscore,
		vhr.LeagueID,
		vhr.EventID AS matchid,
		vhr.matchcode ,
		vhr.groupmatch AS Race,
		vhr.eventdate ,
		b.IP,
		CONVERT(BIT,0) AS IsNeutral,
		b.betid,
		b.currency,
		'' AS ShowTime,
		'' AS betcheck,
		'' AS transdesc
	FROM 
		dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN @SportBettype sbt ON sbt.Bettype=b.bettype
		INNER JOIN
			(	SELECT
					vsr.SportType,
					vso.RacerID AS homeid,
					vsr.LeagueID,
					vsr.EventID,
					vso.Orid,
					CONVERT(VARCHAR(20), vso.RacerNum) AS matchcode,
					'' groupmatch,
					vso.EventDate
				FROM dbo.VSOutright AS vso WITH (NOLOCK) 
					INNER JOIN dbo.VSRaceInfo AS vsr WITH (NOLOCK) ON vso.EventID = vsr.EventID
				WHERE vso.eventdate > DATEADD(DAY, -3, CURRENT_TIMESTAMP)
			) AS vhr ON b.oddsid = vhr.Orid
	WHERE
		sbt.ProductID = 5
		AND sbt.EventType = 3
		AND b.recommend = @recommend
		AND b.custid = @CustID
		AND b.statusID IN (101, 102)
	
	UPDATE betList
	SET betList.Odds = originBetList.Odds
		,betList.Stake = originBetList.Stake
		,betList.betid = originBetList.Bettype
	FROM #Data AS betList
		INNER JOIN bettrans AS originBetList WITH (NOLOCK) ON betList.RefNO = originBetList.TransID
	WHERE betList.Sporttype = 1 AND betList.Bettype IN (901, 902)

	DELETE #Data 
	WHERE Sporttype = 1 AND Bettype = 903

	DECLARE @RowStart INT, @RowEnd INT

	SELECT @PageIndex = @PageIndex - 1,
		@RowStart = @PageSize * @PageIndex + 1,
		@RowEnd = @RowStart + @PageSize - 1

	SELECT @FromDate = MIN(winlostdate) FROM #Data
	SELECT @ToDate = MAX(winlostdate) FROM #Data

	IF @TotalRows = 0
	BEGIN 
		 SELECT @TotalRows = COUNT(transid) FROM #Data
	END

	CREATE NONCLUSTERED INDEX IDX_Index_Data ON #Data (Currency)

	IF @CurrencyID <> 0
	BEGIN 
		DELETE #Data
		WHERE Currency <> @CurrencyID
	END

	SELECT * INTO #TempExchange 
	FROM Lrf_f_GetExchangeDaily(@FromDate,@ToDate)
	WHERE exchangeid IN (SELECT DISTINCT Currency FROM #Data)

	SELECT A.* 
	FROM
	(
		SELECT  
			ROW_NUMBER() OVER(ORDER BY eventdate, matchid, b.custid, transid DESC) AS RowNum,
			SUBSTRING(c.username2, CHARINDEX('$',c.username2) + 1, LEN(c.username2)-CHARINDEX('$',c.username2)) AS nickname,
			b.* ,
			stake * e.USD AS stakeUSD,
			stake * e.EUR AS stakeEUR,
			stake * e.GBP AS stakeGBP
		FROM #Data AS b
			INNER JOIN dbo.customer AS c WITH(NOLOCK) ON c.custid = b.custid
			INNER JOIN #TempExchange e
				ON e.ExchangeDate = (CASE WHEN b.winlostdate > @Todate THEN @Todate ELSE b.winlostdate END) AND e.exchangeid = b.currency
	) A WHERE A.RowNum BETWEEN @RowStart AND @RowEnd

	DECLARE @BettransDetail TABLE (
		refno			BIGINT,
		odds			MONEY,
		stake			MONEY,
		status			NVARCHAR(10),
		apositiontaking	SMALLMONEY,
		bettype			SMALLINT,
		Betteam			NVARCHAR(10),
		stakeEUR		MONEY,
		stakeUSD		MONEY,
		stakeGBP		MONEY)

	IF EXISTS (	SELECT TOP 1 1 
				FROM #Data AS b
					INNER JOIN @SportBettype AS sbt ON sbt.Bettype = b.bettype
				WHERE sbt.ProductID = 4)
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
			BG.stake * e.EUR,
			BG.stake * e.USD,
			BG.stake * e.GBP
		FROM dbo.bettransg AS BG WITH (NOLOCK)
			INNER JOIN #Data AS B ON BG.refno = B.refno AND BG.custid = b.custid
			INNER JOIN #TempExchange AS e ON e.ExchangeDate = B.winlostdate AND e.exchangeid = B.currency
			INNER JOIN @SportBettype AS sbt ON sbt.Bettype = b.bettype
		WHERE sbt.ProductID = 4
	END 

	IF EXISTS (SELECT TOP 1 1 FROM #Data WHERE Bettype = 1233)
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
			BG.stake * e.EUR,
			BG.stake * e.USD,
			BG.stake * e.GBP
		FROM dbo.bettransm AS BG WITH (NOLOCK)
			INNER JOIN #Data AS B ON BG.refno = B.refno AND BG.custid = b.custid
			INNER JOIN #TempExchange AS e ON e.ExchangeDate = B.winlostdate AND e.exchangeid = B.currency
		WHERE B.Bettype = 1233
	END 

	SELECT * FROM @BettransDetail
	ORDER BY RefNo, Bettype

	DROP TABLE #Currency
	DROP TABLE #TempExchange
	DROP TABLE #Data
END


GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_SelDeleted] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_SelDeleted] TO [vnteam]
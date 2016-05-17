set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go


ALTER PROCEDURE [dbo].[Lrf_BetList_MatchWL_Parlay]
	@LicenseeID			INT ,
	@UserID				INT,
	@LicenseeType		VARCHAR(100) = NULL ,
	@CurrencyID			INT = 0,
	@Bettype			INT = 9,
	@ShowBA				BIT = 0,
	@ShowSB				BIT = 0,
	@FromDate			SMALLDATETIME,
	@ToDate				SMALLDATETIME,
	@MoveBetsDay		SMALLDATETIME,
	@PageSize			INT=1000,
	@PageIndex			INT=1,
	@TotalRows			INT=0 OUTPUT ,
	@SumWinlost			MONEY=0 OUTPUT,
	@SumLicenseeWL		MONEY=0 OUTPUT,
	@SumComm			MONEY=0 OUTPUT,
	@SumPlayerComm		MONEY=0 OUTPUT,
	@SumWinlostUSD		MONEY=0 OUTPUT,
	@SumLicenseeWLUSD	MONEY=0 OUTPUT,
	@SumCommUSD			MONEY=0 OUTPUT,
	@SumPlayerCommUSD	MONEY=0 OUTPUT,
	@SumWinlostEUR		MONEY=0 OUTPUT,
	@SumLicenseeWLEUR	MONEY=0 OUTPUT,
	@SumCommEUR			MONEY=0 OUTPUT,
	@SumPlayerCommEUR	MONEY=0 OUTPUT,
	@SumWinlostGBP		MONEY=0 OUTPUT,
	@SumLicenseeWLGBP	MONEY=0 OUTPUT,
	@SumCommGBP			MONEY=0 OUTPUT,
	@SumPlayerCommGBP	MONEY=0 OUTPUT,
	@Sort				VARCHAR(100) = 'TransID ASC'
AS

/*
	Created: Henry@20120111
	Task : Betlist for Parlay
	DB: DB052.bodb02
	Original: [Age_BetList_SelWinlossParlay_Ag]
	Revisions:
		- 20120214@Jim: change table ExchangeDaily by function Lrf_f_GetExchangeDaily
		- 20120319@Henry: show main transid for sub-ticket of system parlay 
		- 20120614@Jim: optimize code 
		- 20120724@Jim: add playercomm value 
		- 20121004@Jim: replace @currency input param by @currencyID
		- 20130514@Jim: Restrict permission of Licensee Users by currency
		- 20140428@Hannah: Sort betlist
		- 20140516@Hannah: Fix bug Sort betlist
		- 20141111@Winnie: change from LicenseeCust to f_SelLicenseeCust 
		- 20150128@Winnie: Add base currency GBP
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20160516@Kos: Add sorting function [#Redmine: 57433]

	Param's Explanation: 

*/

BEGIN
	SET NOCOUNT ON

	DECLARE @TempAg AS TABLE (custid INT)

	SELECT  currencyID,LicenseeID into #currency
	FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)
	WHERE (@CurrencyID=0  OR (@CurrencyID<>0 AND CurrencyID=@CurrencyID))

	INSERT INTO @TempAg (CustId)
	SELECT DISTINCT CustID  
	FROM bodb_Licensee.dbo.f_SelLicenseeCust(0) lc --WITH ( NOLOCK )  
		INNER JOIN #Currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID
	WHERE  [Description] = COALESCE(@LicenseeType,[Description])

	CREATE TABLE #Data
	(
		username		NVARCHAR(50),
		Nickname		VARCHAR(50),
		custid			INT,
		bettype			SMALLINT,
		refno			NVARCHAR(50),		
		transid			BIGINT,	
		BetID			BIGINT,
		hdp1			SMALLMONEY,
		hdp2			SMALLMONEY,
		odds			MONEY,
		modds			MONEY,
		status			NVARCHAR(50),
		Stake			MONEY, 
		Actual_Stake	MONEY,
		winlost			MONEY,
		licenseeWL		MONEY,
		comm			MONEY,
		playercomm		MONEY,
		transdate		DATETIME,
		winlostdate		DATETIME,
		betteam			NVARCHAR(25),
		liveindicator	BIT,
		livehomescore	SMALLINT,
		liveawayscore	SMALLINT,
		IP				VARCHAR(30),
		isNeutral		BIT,
		currency		SMALLINT,
		isBA			INT,
		awinlost		MONEY
	)

	IF @Todate > @MoveBetsDay
	BEGIN
		IF @ShowBA = 1
		BEGIN
			INSERT INTO #Data 
			SELECT
				b.username,
				'' AS Nickname,
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
				b.IP,
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				1 AS isBA,
				b.awinlost
			FROM
				dbo.bettrans b WITH (NOLOCK) 
			WHERE
				b.recommend IN (SELECT custid FROM @TempAg)	AND
				((@CurrencyID=0 AND b.currency IN (SELECT currencyId FROM #currency))  OR (@CurrencyID<>0 AND b.Currency=@CurrencyID)) AND
				b.Winlostdate>=@FromDate AND
				b.Winlostdate<=@ToDate AND
				b.Bettype=@BetType AND
				b.matchid = @BetType AND
				b.tpositiontaking=0 AND
				b.statusID IN (111,112,113)
		END

		IF @ShowSB = 1
		BEGIN
			INSERT INTO #Data 
			SELECT
				b.username,
				'' AS Nickname,
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
				b.IP,
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				0 AS isBA,
				b.awinlost
			FROM
				dbo.bettrans b WITH (NOLOCK)
			WHERE
				b.recommend IN (SELECT custid FROM @TempAg)	AND
				((@CurrencyID=0 AND b.currency IN (SELECT currencyId FROM #currency))  OR (@CurrencyID<>0 AND b.Currency=@CurrencyID)) AND
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
			INSERT INTO #Data 
			SELECT
				b.username,
				'' AS Nickname,
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
				b.IP,
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				1 AS IsBA,
				b.awinlost
			FROM
				dbo.bettrans14 b WITH (NOLOCK) 
			WHERE
				b.recommend IN (SELECT custid FROM @TempAg)	AND
				((@CurrencyID=0 AND b.currency IN (SELECT currencyId FROM #currency))  OR (@CurrencyID<>0 AND b.Currency=@CurrencyID)) AND
				b.Winlostdate>=@FromDate AND
				b.Winlostdate<=@ToDate AND
				b.Bettype=@BetType AND
				b.matchid = @BetType AND
				b.tpositiontaking=0 AND
				b.statusID IN (111,112,113)	
		END	

		IF @ShowSB = 1
		BEGIN
			INSERT INTO #Data 
			SELECT
				b.username,
				'' AS Nickname,
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
				b.IP,
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				0 AS IsBA,
				b.awinlost
			FROM
				dbo.bettrans14 b WITH (NOLOCK) 		
			WHERE
				b.recommend IN (SELECT custid FROM @TempAg)	AND
				((@CurrencyID=0 AND b.currency IN (SELECT currencyId FROM #currency))  OR (@CurrencyID<>0 AND b.Currency=@CurrencyID)) AND
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

	CREATE NONCLUSTERED INDEX IDX_Index_Ag ON #Data (Currency)

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
		@SumPlayerCommEUR=SUM(ISNULL(playercomm*e.EUR,0)),	
		--GBP
		@SumWinlostGBP=SUM(ISNULL(winlost*e.GBP,0)),
		@SumLicenseeWLGBP=SUM(ISNULL(LicenseeWL*e.GBP,0)),
		@SumCommGBP=SUM(ISNULL(comm*e.GBP,0)),
		@SumPlayerCommGBP=SUM(ISNULL(playercomm*e.GBP,0))	
	FROM #Data b
	INNER JOIN #TempExchange e ON b.currency=e.exchangeID AND b.winlostdate=e.exchangeDate
	INNER JOIN customer c WITH(NOLOCK) ON c.custid=b.custid

	UPDATE #Data
	SET Nickname = SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2))
	FROM #Data AS b
		INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON b.CustId = c.custid

	CREATE TABLE #PagingData (
		RowNum			INT,
		username		NVARCHAR(50),
		Nickname		VARCHAR(50),
		custid			INT,
		bettype			SMALLINT,
		refno			NVARCHAR(50),		
		transid			BIGINT,	
		BetID			BIGINT,
		hdp1			SMALLMONEY,
		hdp2			SMALLMONEY,
		odds			MONEY,
		modds			MONEY,
		status			NVARCHAR(50),
		Stake			MONEY, 
		Actual_Stake	MONEY,
		winlost			MONEY,
		licenseeWL		MONEY,
		comm			MONEY,
		playercomm		MONEY,
		transdate		DATETIME,
		winlostdate		DATETIME,
		betteam			NVARCHAR(25),
		liveindicator	BIT,
		livehomescore	SMALLINT,
		liveawayscore	SMALLINT,
		IP				VARCHAR(30),
		isNeutral		BIT,
		currency		SMALLINT,
		isBA			INT,
		awinlost		MONEY
	)

	DECLARE @sql NVARCHAR(2000)
	DECLARE @SortTemp VARCHAR(250)

	IF @Sort LIKE '%USD%' OR @Sort LIKE '%EUR%' OR @Sort LIKE '%GBP%'
	BEGIN
		DECLARE @charindex INT

		SELECT @charindex = CHARINDEX( ' ', @Sort, 1)
		SELECT @SortTemp = SUBSTRING (@Sort, 1, @charindex - 4) + '*e.' + SUBSTRING(@Sort, @charindex - 3,4) + SUBSTRING(@Sort, @charindex + 1, LEN(@Sort))
	END
	ELSE
	BEGIN
		SET @SortTemp = @Sort
	END

	SET @Sql = 
		'INSERT INTO #PagingData
		SELECT A.*
		FROM
		(
			SELECT
				ROW_NUMBER() OVER (ORDER BY ' + @SortTemp + ') AS RowNum,
				b.* 
			FROM #Data AS b
		) A 
		WHERE A.RowNum BETWEEN ' + CAST(@RowStart AS VARCHAR(50)) + ' AND ' + CAST(@RowEnd AS VARCHAR(50))
		+ ' ORDER BY A.RowNum'

	EXEC sp_executesql @sql

	DROP TABLE #Data

	SELECT
		b.*,
		'' AS BetStatus,
		'' AS MatchCode,
		0 AS HomeId,
		0 AS AwayId,
		0 AS LeagueId,
		0 AS MatchId,
		0 AS SportType,
		-- USD
		b.Stake			* e.USD AS StakeUSD,
		b.Actual_Stake	* e.USD AS Actual_StakeUSD,
		b.WinLost		* e.USD AS WinLostUSD,
		b.LicenseeWL	* e.USD AS LicenseeWLUSD,
		b.Comm			* e.USD AS CommUSD,
		b.PlayerComm	* e.USD AS PlayerCommUSD,
		-- EUR
		b.Stake			* e.EUR AS StakeEUR,
		b.Actual_Stake	* e.EUR AS Actual_StakeEUR,
		b.WinLost		* e.EUR AS WinLostEUR,
		b.LicenseeWL	* e.EUR AS LicenseeWLEUR,
		b.Comm			* e.EUR AS CommEUR,
		b.PlayerComm	* e.EUR AS PlayerCommEUR,
		-- GBP
		b.Stake			* e.GBP AS StakeGBP,
		b.Actual_Stake	* e.GBP AS Actual_StakeGBP,
		b.WinLost		* e.GBP AS WinLostGBP,
		b.LicenseeWL	* e.GBP AS LicenseeWLGBP,
		b.Comm			* e.GBP AS CommGBP,
		b.PlayerComm	* e.GBP AS PlayerCommGBP
	FROM #PagingData AS b
		INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.WinLostDate AND e.exchangeid = b.Currency

	DROP TABLE #PagingData
	DROP TABLE #TempExchange 
	DROP TABLE #Currency
END


GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_MatchWL_Parlay] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_MatchWL_Parlay] TO [vnteam] 
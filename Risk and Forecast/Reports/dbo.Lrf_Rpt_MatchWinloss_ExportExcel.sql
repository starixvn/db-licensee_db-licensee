/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

 ALTER PROCEDURE [dbo].[Lrf_Rpt_MatchWinLoss_ExportExcel]
    @LicenseeID INT,
    @LicenseeType VARCHAR(100) = NULL,
    @CurrencyID	  INT=0,
    @Date SMALLDATETIME,
    @MoveBetsDay SMALLDATETIME,
    @showSB BIT = 0,
	@showRB BIT = 0,
	@showNG BIT = 0,
	@showBA BIT = 0,    
	@showVS BIT = 0,
	@showCS BIT = 0,
	@showBG BIT =0,
	@showVS2 BIT = 0
AS 
/*
Created: 20120702@Henry
Task : 
DB: DB052.bodb02
Original: Lrf_Rpt_MatchWinLoss
Revisions:
	- 20120815@Henry: add live casino
	- 20120831@Jim: add virtual sport
	- 20121004@Jim: replace @currencyname input param by @currencyID
	- 20121115@Henry: Only Sportsbook needs to exclude BA
	- 20130426@Scott : Add more parameter @showCS,@showBG
	- 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
	- 20150123@Jim: support base on Currency GBP
	- 20150622@Winnie: exclude 3 transactions SOLD/BOUGHT/BetTrade Commission 
	- 20170706@Harper: LRF - Integrate Bet Radar Virtual Sports & Cashout[RedmineID: #78241]
	- 20180129@Harper: Remove LC from product list [RedmineID: #85965]

Param's Explanation: 
	
*/

BEGIN
SET NOCOUNT ON

DECLARE @ExchangeDaily TABLE(ExchangeDate SMALLDATETIME, ExchangeId INT, USD FLOAT, EUR FLOAT,GBP FLOAT, PRIMARY KEY(ExchangeDate,ExchangeId))

DECLARE @bettype		TABLE (bettype INT PRIMARY KEY, ProductCode VARCHAR(10))
DECLARE @ProductList	VARCHAR (500)

DECLARE @_Date AS DATETIME
SET @_Date = @Date

DECLARE @Today SMALLDATETIME 
SELECT @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120) 

DECLARE @IsTest BIT = 0
SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

DECLARE @TempAg AS TABLE ( CustId INT,Currency INT )

INSERT  INTO @TempAg ( CustId, Currency  )
SELECT    CustID 
		,Currency 
FROM bodb_Licensee.dbo.f_SelLicenseeCust(@licenseeID) lc 
WHERE   LicenseeID = @LicenseeID  
	AND  (@CurrencyID=0 OR (@CurrencyID <> 0 AND  Currency = @CurrencyID))
	AND [Description] = COALESCE(@LicenseeType,  
								 [Description]) 

DECLARE @AgMatchWLDetails TABLE
(
	Winlostdate SMALLDATETIME,
	Currency    INT,
	matchid     INT,
	homeid      INT,
	awayid      INT,
	bettype   SMALLINT,
	leagueid        INT,
	turnover        MONEY,
	MemberWinLost   MONEY,
	LicenseeWL		MONEY, --Sportbook and NumberGame
	WinlossRB	MONEY,
	AmtDueToBA	MONEY,   
	AmtDueToRB	MONEY,
	CommBA		MONEY,   
	CommRB		MONEY,   
	race        NVARCHAR(20),
	matchcode   NVARCHAR(50),
	isNeutral   BIT,
	liveindicator BIT,
	showtime 	NVARCHAR(50)
)


CREATE TABLE #TempBetList(
	Winlostdate		DATETIME,
	currency        INT,
	Bettype			INT,
	Stake			MONEY,
	Winlost			MONEY,
	awinlost		MONEY,
	comm			MONEY,
	playercomm		MONEY,
	MatchID         INT,
	Liveawayscore	SMALLINT,
	tpositiontaking	SMALLMONEY,
	liveindicator BIT
)
 
IF @ShowNG = 1
BEGIN
	SELECT @ProductList = COALESCE(@ProductList + ',' + 'NG', 'NG')	
END 
 
IF @ShowVS = 1
BEGIN	
    SELECT @ProductList = COALESCE(@ProductList + ',' + 'VS', 'VS')
END
 
 IF @ShowVS2 = 1 -- Betradar Virtual Sports
BEGIN
	SELECT @ProductList = COALESCE(@ProductList + ',' + 'VS2', 'VS2')
END

IF LEN(ISNULL(@ProductList, '')) > 0 
BEGIN
	-- Insert Bettype
	INSERT INTO @bettype ( bettype, ProductCode )
	SELECT DISTINCT BetType, ProductPrefix
	FROM f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', @ProductList, @IsTest)	
END	

IF @_Date > @MoveBetsDay 
BEGIN
	IF @ShowBA = 1
	BEGIN
		INSERT INTO #TempBetList 
		SELECT  
			b.Winlostdate,
			b.currency,
			b.bettype,
			SUM(stake) as Stake,
			SUM(winlost - actual_stake) as Winlost,
			0 AS awinlost,
			SUM(comm),
			SUM(playercomm),
			b.matchid,
			0 AS Liveawayscore,
			0 AS tpositiontaking,
			0 As liveindicator
		FROM    
			bettrans b WITH(NOLOCK )
			INNER JOIN @TempAg t ON b.recommend = t.CustId AND b.currency = t.Currency
			INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid 	 				
		WHERE
		    b.winlostdate = @_Date
			AND b.statusID IN (111,112,113)
			AND b.bettype NOT IN (901,902,903,904,911,912,913,914)
		GROUP BY
			b.Winlostdate,
			b.currency,
			b.bettype,
			b.matchid,
			b.liveindicator
				
		INSERT INTO @AgMatchWLDetails
		SELECT  
			b.Winlostdate,
			b.currency,
			m.matchid,
			m.homeid,
			m.awayid,
			b.bettype,
			m.leagueid,
			SUM(stake),
			SUM(Winlost),
			0 AS LicenseeWL,
			0 AS WinlossRB,
			-SUM (Winlost +  awinlost + comm) AS AmtDueToBA,
			0 AS AmountDueToRB,
			SUM (comm - playercomm) as CommBA,
			0 as CommRB,
			'',
			m.matchcode,
			ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral,
			b.liveindicator,
			m.showtime 
		FROM    
			#TempBetList b
			INNER JOIN match m WITH ( NOLOCK ) ON m.matchid = b.matchid
		GROUP BY
			b.Winlostdate,
			b.currency,
			m.matchid,
			m.homeid,
			m.awayid,
			b.bettype,
			m.leagueid,
			m.matchcode,
			m.isNeutral	,
			b.liveindicator,
			m.showtime
		
	END
	
	--Get general data
	TRUNCATE TABLE #TempBetList
	
	INSERT INTO #TempBetList
	SELECT  
		b.Winlostdate,
		b.currency,
		b.bettype,
		SUM(stake) as Stake,
		SUM(winlost - actual_stake) as Winlost,
		SUM(b.awinlost) AS awinlost,
		SUM(b.comm) AS comm,
		SUM(b.playercomm) AS playercomm,
		b.matchid,
		b.Liveawayscore,
		b.tpositiontaking,
		CASE WHEN b.bettype BETWEEN 81 AND 120 THEN b.liveindicator ELSE 0 END AS liveindicator
	FROM    
		bettrans b WITH(NOLOCK,INDEX (CIX_recommend_matchid_bettype))
		INNER JOIN @TempAg t ON b.recommend = t.CustId AND b.currency = t.Currency
	WHERE   
		 b.winlostdate = @_Date
		AND b.statusID IN (111,112,113)
		AND b.bettype NOT IN (901,902,903,904,911,912,913,914)
		AND b.matchid>0
	GROUP BY
		b.Winlostdate,
		b.currency,
		b.bettype,
		b.matchid,
		b.Liveawayscore,
		b.tpositiontaking,
		b.liveindicator
	
	IF (@showSB = 1)
	BEGIN
		--exclude BA tickets
		INSERT  INTO @AgMatchWLDetails
		SELECT  
			b.Winlostdate,
			b.currency,
			m.matchid,
			m.homeid,
			m.awayid,
			b.bettype,
			m.leagueid,
			SUM(stake),
			SUM(winlost),
			-SUM(b.winlost) AS LicenseeWL,
			0 AS WinlossRB,
			0 AS AmountDueToBA,
			0 AS AmountDueToRB,
			0 AS CommBA,
			0 as CommRB,
			'',
			m.matchcode,
			ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral,
			b.liveindicator AS liveindicator,
			'' AS ShowTime
		FROM    
			#TempBetList b
			INNER JOIN match m WITH ( NOLOCK ) ON m.matchid = b.matchid
			INNER JOIN @bettype bt ON b.bettype = bt.bettype
		WHERE   
			(b.bettype<31 OR (b.bettype BETWEEN 121 AND 999)) AND
			b.tpositiontaking <> 0
		GROUP BY
			b.Winlostdate,
			b.currency,
			m.matchid,
			m.homeid,
			m.awayid,
			b.bettype,
			m.leagueid,
			m.matchcode,
			m.isNeutral	,
			b.liveindicator
			
	END
	
	IF (@showNG = 1 OR @ShowVS = 1 OR @showVS2 = 1) 
	BEGIN
		--exclude BA tickets
		INSERT  INTO @AgMatchWLDetails
		SELECT  
			b.Winlostdate,
			b.currency,
			m.matchid,
			m.homeid,
			m.awayid,
			b.bettype,
			m.leagueid,
			SUM(stake),
			SUM(winlost),
			-SUM(b.winlost) AS LicenseeWL,
			0 AS WinlossRB,
			0 AS AmountDueToBA,
			0 AS AmountDueToRB,
			0 AS CommBA,
			0 as CommRB,
			'',
			m.matchcode,
			ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral,
			b.liveindicator AS liveindicator,
			'' AS ShowTime
		FROM    
			#TempBetList b
			INNER JOIN match m WITH ( NOLOCK ) ON m.matchid = b.matchid
			INNER JOIN @bettype bt ON b.bettype = bt.bettype
		
		GROUP BY
			b.Winlostdate,
			b.currency,
			m.matchid,
			m.homeid,
			m.awayid,
			b.bettype,
			m.leagueid,
			m.matchcode,
			m.isNeutral	,
			b.liveindicator				
	END
	
	IF @showRB = 1
	BEGIN
		INSERT  INTO @AgMatchWLDetails
		SELECT  
			b.Winlostdate,
			b.currency,
			0 AS matchid,
			0 AS homeid,
			0 AS awayid,
			bettype,
			m.leagueid,
			SUM(CASE WHEN b.liveawayscore = 0 AND b.bettype = 33 THEN b.stake / 2 ELSE b.stake END),
			SUM(b.winlost) ,
			0 AS LicenseeWL,
			SUM(b.awinlost) AS WinlossRB,
			0 AS AmountDueToBA,
			- SUM(b.winlost + awinlost + comm) AS AmountDueToRB,
			0 AS CommBA,
			SUM(comm - playercomm) as CommRB,
			m.groupmatch AS race,
			'ZZZZ' AS matchcode,
			CONVERT(BIT, 0) AS IsNeutral,
			0 as liveindicator,
			'' AS ShowTime 
		FROM    
			#TempBetList b
			INNER JOIN outright m WITH ( NOLOCK ) ON m.orid = b.matchid
			LEFT JOIN league l WITH (NOLOCK) ON m.leagueID=l.leagueID
		WHERE b.bettype IN (31,32,33)
		GROUP BY 
			b.Winlostdate,
			b.currency,
			bettype,
			m.groupmatch,
			m.leagueid,
			b.liveindicator
	END
	
END

IF @_Date <= @MoveBetsDay 
BEGIN
	IF @ShowBA = 1
	BEGIN
		TRUNCATE TABLE #TempBetList
		
		INSERT INTO #TempBetList 
		SELECT  
			b.Winlostdate,
			b.currency,
			b.bettype,
			SUM(stake) as Stake,
			SUM(winlost - actual_stake) as Winlost,
			0 AS awinlost,
			SUM(comm),
			SUM(playercomm),
			b.matchid,
			0 AS Liveawayscore,
			0 AS tpositiontaking,
			0 AS liveindicator
		FROM    
			--bettrans14 b WITH(NOLOCK,INDEX (PK_bettrans14))
			bettrans14 b WITH(NOLOCK)
			INNER JOIN @TempAg ag ON b.recommend = ag.custid AND b.currency = ag.Currency
			--INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid
		WHERE   
			b.winlostdate = @_Date
			AND b.statusID IN (111,112,113)
			 AND b.bettype NOT IN (901,902,903,904,911,912,913,914)
			AND tpositiontaking = 0
			AND (b.bettype < 31 OR (b.Bettype BETWEEN 121 AND 999))
		GROUP BY
			b.Winlostdate,
			b.currency,
			b.bettype,
			b.matchid,
			b.liveindicator

		INSERT  INTO @AgMatchWLDetails
		SELECT  
			b.Winlostdate,
			b.currency,
			m.matchid,
			m.homeid,
			m.awayid,
			b.bettype,
			m.leagueid,
			SUM(stake),
			SUM(Winlost),
			0 AS LicenseeWL,
			0 AS WinlossRB,
			-SUM (Winlost +  awinlost + comm) AS AmtDueToBA,
			0 AS AmountDueToRB,
			SUM (comm - playercomm) as CommBA,
			0 as CommRB,
			'' AS race,
			m.matchcode,
			ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral,
			b.liveindicator,
			'' AS ShowTime
		FROM   
			#TempBetList b
			INNER JOIN match14 m WITH ( NOLOCK ) ON m.matchid = b.matchid
		GROUP BY
			b.Winlostdate,
			b.currency, 
			m.matchid,
			m.homeid,
			m.awayid,
			b.bettype,
			m.leagueid,
			m.matchcode,
			m.isNeutral,
			b.liveindicator
				
	END

	--Get general data
	TRUNCATE TABLE #TempBetList
	
	INSERT INTO #TempBetList
	SELECT  
		b.Winlostdate,
		b.currency,
		b.bettype,
		SUM(stake) as Stake,
		SUM(winlost - actual_stake) as Winlost,
		SUM(b.awinlost) AS awinlost,
		SUM(b.comm) AS comm,
		SUM(b.playercomm) AS playercomm,
		b.matchid,
		b.Liveawayscore,
		b.tpositiontaking,
		CASE WHEN b.bettype BETWEEN 81 AND 120 THEN b.liveindicator ELSE 0 END AS liveindicator
	FROM    
		bettrans14 b WITH(NOLOCK,INDEX (bettrans143))
		INNER JOIN @TempAg ag ON b.recommend = ag.custid AND b.currency = ag.Currency
	WHERE   
		b.winlostdate = @_Date
		AND b.statusID IN (111,112,113)
		AND b.bettype NOT IN (901,902,903,904,911,912,913,914)
		AND b.matchid>0
	GROUP BY
		b.Winlostdate,
		b.currency,
		b.bettype,
		b.matchid,
		b.Liveawayscore,
		b.tpositiontaking,
		b.liveindicator

	IF (@ShowSB=1)
	BEGIN
		INSERT  INTO @AgMatchWLDetails
		SELECT  
			b.Winlostdate,
			b.currency,
			m.matchid,
			m.homeid,
			m.awayid,
			b.bettype,
			m.leagueid,
			SUM(stake),
			SUM(winlost),
			-SUM(b.winlost) AS LicenseeWL,
			0 AS WinlossRB,
			0 AS AmountDueToBA,
			0 AS AmountDueToRB,
			0 AS CommBA,
			0 as CommRB,
			'' AS race,
			m.matchcode,
			ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral,
			b.liveindicator AS liveindicator,
			'' as showtime
		FROM   
			#TempBetList b
			INNER JOIN match14 m WITH ( NOLOCK ) ON m.matchid = b.matchid
		WHERE   
			(b.bettype<31 OR (b.bettype BETWEEN 121 AND 999)) AND
			b.tpositiontaking <> 0
		GROUP BY
			b.Winlostdate,
			b.currency, 
			m.matchid,
			m.homeid,
			m.awayid,
			b.bettype,
			m.leagueid,
			m.matchcode,
			m.isNeutral,
			b.liveindicator
	END

	IF (@showNG = 1 OR @ShowVS = 1 OR @showVS2 = 1)
	BEGIN
		INSERT  INTO @AgMatchWLDetails
		SELECT  
			b.Winlostdate,
			b.currency,
			m.matchid,
			m.homeid,
			m.awayid,
			b.bettype,
			m.leagueid,
			SUM(stake),
			SUM(winlost),
			-SUM(b.winlost) AS LicenseeWL,
			0 AS WinlossRB,
			0 AS AmountDueToBA,
			0 AS AmountDueToRB,
			0 AS CommBA,
			0 as CommRB,
			'' AS race,
			m.matchcode,
			ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral,
			b.liveindicator AS liveindicator,
			'' AS showtime
		FROM   
			#TempBetList b
			INNER JOIN match14 m WITH ( NOLOCK ) ON m.matchid = b.matchid
			INNER JOIN @bettype bt ON b.bettype = bt.bettype
		GROUP BY
			b.Winlostdate,
			b.currency, 
			m.matchid,
			m.homeid,
			m.awayid,
			b.bettype,
			m.leagueid,
			m.matchcode,
			m.isNeutral,
			b.liveindicator				
	END    

	IF @showRB=1
	BEGIN
		INSERT INTO @AgMatchWLDetails
		SELECT  
			b.Winlostdate,
			b.currency,
			0 AS matchid,
			0 AS homeid,
			0 AS awayid,
			bettype,
			m.leagueid,
			SUM(CASE WHEN b.liveawayscore = 0 AND b.bettype = 33 THEN b.stake / 2 ELSE b.stake END),
			SUM(winlost),
			0 AS LicenseeWL,
			SUM(b.awinlost) AS WinlossRB,
			0 AS AmountDueToBA,
			- SUM(b.winlost + awinlost + comm) AS AmountDueToRB,
			0 AS CommBA,
			SUM(b.comm - b.playercomm) AS CommRB,
			m.groupmatch AS race,
			'ZZZZ' AS matchcode,
			CONVERT(BIT, 0) AS IsNeutral,
			0 AS liveindicator,
			'' as showtime
		FROM    
			#TempBetList b
			INNER JOIN outright14 m WITH ( NOLOCK ) ON m.orid = b.matchid
			LEFT  JOIN league l WITH (NOLOCK) ON m.leagueID=l.leagueID
		WHERE b.bettype IN (31,32,33)
		GROUP BY 
			b.Winlostdate,
			b.currency,
			bettype,
			m.groupmatch,
			m.leagueid,
			b.liveindicator
	END
	
END

INSERT INTO @ExchangeDaily
    SELECT ExchangeDate, ExchangeId, USD, EUR,GBP
    FROM Lrf_f_GetExchangeDaily(@_Date,@_Date)
    

-- Result
SELECT    
    matchid,
    homeid,
    awayid,
    bettype,
    leagueid,
    CAST(SUM(turnover) AS MONEY) AS turnover,
    CAST(SUM(turnover * e.USD) AS MONEY) AS turnoverUSD,
    CAST(SUM(turnover * e.EUR) AS MONEY) AS turnoverEUR,
    CAST(SUM(MemberWinLost) AS MONEY) AS MemberWinLost,
    CAST(SUM(MemberWinLost * e.USD) AS MONEY) AS MemberWinLostUSD,
    CAST(SUM(MemberWinLost * e.EUR) AS MONEY) AS MemberWinLostEUR,
	CAST(SUM(MemberWinLost * e.GBP) AS MONEY) AS MemberWinLostGBP,
    --licenseeWL
	CAST(SUM(LicenseeWL) AS MONEY) AS LicenseeWL,
    CAST(SUM(LicenseeWL * e.USD) AS MONEY) AS LicenseeWLUSD,
    CAST(SUM(LicenseeWL * e.EUR) AS MONEY) AS LicenseeWLEUR,
	CAST(SUM(LicenseeWL * e.GBP) AS MONEY) AS LicenseeWLGBP,
	CAST(SUM(WinlossRB) AS MONEY) AS WinlossRB,
    CAST(SUM(WinlossRB * e.USD) AS MONEY) AS WinlossRBUSD,
    CAST(SUM(WinlossRB * e.EUR) AS MONEY) AS WinlossRBEUR,
	CAST(SUM(WinlossRB * e.GBP) AS MONEY) AS WinlossRBGBP,
    CAST(SUM(CommBA) AS MONEY) AS CommBA,
    CAST(SUM(CommBA * e.USD) AS MONEY) AS CommBAUSD,
    CAST(SUM(CommBA * e.EUR) AS MONEY) AS CommBAEUR,
	CAST(SUM(CommBA * e.GBP) AS MONEY) AS CommBAGBP,
    CAST(SUM(commRB) AS MONEY) AS commRB,
    CAST(SUM(commRB * e.USD) AS MONEY) AS commRBUSD,
    CAST(SUM(commRB * E.EUR) AS MONEY) AS commRBEUR,
	CAST(SUM(commRB * E.GBP) AS MONEY) AS commRBGBP,
    CAST(SUM(AmtDuetoBA) AS MONEY) AS AmtDuetoBA,
    CAST(SUM((AmtDuetoBA) * e.USD) AS MONEY) AS AmtDuetoBAUSD,
    CAST(SUM((AmtDuetoBA) * e.EUR) AS MONEY) AS AmtDuetoBAEUR,
	CAST(SUM((AmtDuetoBA) * e.GBP) AS MONEY) AS AmtDuetoBAGBP,
    CAST(SUM(AmtDuetoRB) AS MONEY) AS AmtDuetoRB,
    CAST(SUM((AmtDuetoRB) * e.USD) AS MONEY) AS AmtDuetoRBUSD,
    CAST(SUM((AmtDuetoRB) * e.EUR) AS MONEY) AS AmtDuetoRBEUR,
    race,
    matchcode,
    isNeutral,
    liveindicator,
	showtime 
FROM  
	@AgMatchWLDetails b
	--INNER JOIN (SELECT *  FROM Lrf_f_GetExchangeDaily(@_FromDate,@_ToDate))e 
	INNER JOIN @ExchangeDaily e ON b.winlostdate = e.ExchangeDate AND b.currency = e.ExchangeId
GROUP BY  
    matchid,
    homeid,
    awayid,
    bettype,
    matchcode,
    leagueid,
    isNeutral,
    race,
    liveindicator,
	showtime 
ORDER BY 
    CASE WHEN bettype <31 OR bettype > 120 THEN 0 WHEN bettype BETWEEN 81 and 120 THEN 1 ELSE 2 END

DROP TABLE #TempBetList
/*
	[Lrf_Rpt_MatchWinLoss_ExportExcel]
	@LicenseeID =1,
	@Date ='2012-09-15',
	@MoveBetsDay ='2012-09-05',
	@showSB  = 1,
	@showRB  = 1,
	@showNG  = 1,
	@showBA  = 1,	
	@showVS  = 1

*/
END	
GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_MatchWinLoss_ExportExcel] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_MatchWinLoss_ExportExcel] TO vnteam
GO


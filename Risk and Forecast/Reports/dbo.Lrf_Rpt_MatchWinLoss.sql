ALTER PROCEDURE [dbo].[Lrf_Rpt_MatchWinLoss]
    @LicenseeID INT,
	@UserID		INT,
    @LicenseeType VARCHAR(100) = NULL,
    @CurrencyName VARCHAR(20) = NULL,
    @Date SMALLDATETIME,
    @MoveBetsDay SMALLDATETIME,
    @showSB BIT = 1,
	@showRB BIT = 0,
	@showNG BIT = 0,
	@showBA BIT = 0
    
AS 
/*
Created: 20120529@Don
Task : 
DB: DB052.bodb02
Original: Lrf_Rpt_MatchWinLossDetail
Revisions:
	20130514@Jim: Restrict permission of Licensee Users by currency
Param's Explanation: 
	
*/

/* demo script
exec Lrf_Rpt_MatchWinLoss @LicenseeID=3,@LicenseeType=default,@CurrencyName=default,@Date='May 19 2012 12:00:00:000AM',@MoveBetsDay='May 21 2012 12:00:00:000AM',@showSB=1,@showRB=0,@showNG=0,@showBA=0
*/
SET NOCOUNT ON

DECLARE @ExchangeDaily TABLE(ExchangeDate SMALLDATETIME, ExchangeId INT, USD FLOAT, EUR FLOAT, PRIMARY KEY(ExchangeDate,ExchangeId))

DECLARE @_Date AS DATETIME
SET @_Date = @Date

DECLARE @Today SMALLDATETIME 
SELECT @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120) 

SELECT  currencyID,LicenseeID into #currency
FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)

DECLARE @TempAg AS TABLE ( CustId INT )
INSERT  INTO @TempAg ( CustId)
SELECT  CustID 
FROM    DBLIC.bodb_Licensee.dbo.LicenseeCust lc WITH ( NOLOCK )
	INNER JOIN #Currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID
WHERE CurrencyName = COALESCE(@CurrencyName,
							CurrencyName)
		AND [Description] = COALESCE(@LicenseeType,
									 [Description]) 
		AND RoleId = 2	

---------------------------------
DROP TABLE #Currency
---------------------------------
DECLARE @AgMatchWLDetails TABLE
(
	Winlostdate SMALLDATETIME,
	Currency    INT,
	matchid     INT,
	homeid      INT,
	awayid      INT,
	--bettype   SMALLINT,
	ProductName     VARCHAR(2),
	leagueid        INT,
	turnover        MONEY,
	MemberWinLost   MONEY,
	LicenseeWL	MONEY, --Sportbook and NumberGame
	WinlossRB	MONEY,
	AmtDueToBA	MONEY,   
	AmtDueToRB	MONEY,
	CommBA		MONEY,   
	CommRB		MONEY,   
	race        NVARCHAR(20),
	matchcode   NVARCHAR(50),
	isNeutral   BIT
)

/*DECLARE @TempBetList AS TABLE(
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
	tpositiontaking	SMALLMONEY
)*/
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
	tpositiontaking	SMALLMONEY
)

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
			0 AS tpositiontaking
		FROM    
			bettrans b WITH(NOLOCK,index=PK_bettrans)
			INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid 	 				
		WHERE
		    b.recommend IN (SELECT custid FROM @TempAg)
		    AND b.winlostdate = @_Date
			AND b.statusID IN (111,112,113)
			AND (b.bettype < 31 OR (b.Bettype BETWEEN 121 AND 999))
		GROUP BY
			b.Winlostdate,
			b.currency,
			b.bettype,
			b.matchid
				
		INSERT INTO @AgMatchWLDetails
		SELECT  
			b.Winlostdate,
			b.currency,
			m.matchid,
			m.homeid,
			m.awayid,
			'SB', --b.bettype,
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
			ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral
		FROM    
			#TempBetList b
			INNER JOIN match m WITH ( NOLOCK ) ON m.matchid = b.matchid
		GROUP BY
			b.Winlostdate,
			b.currency,
			m.matchid,
			m.homeid,
			m.awayid,
			--b.bettype,
			m.leagueid,
			m.matchcode,
			m.isNeutral	
		
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
		b.tpositiontaking
	FROM    
		bettrans b WITH(NOLOCK,INDEX (CIX_recommend_matchid_bettype))
	WHERE   
	    b.recommend IN (SELECT custid FROM @TempAg)
		AND b.winlostdate = @_Date
		AND b.statusID IN (111,112,113)
	GROUP BY
		b.Winlostdate,
		b.currency,
		b.bettype,
		b.matchid,
		b.Liveawayscore,
		b.tpositiontaking
	
	IF @showSB=1 
	BEGIN
		--exclude BA tickets
		INSERT  INTO @AgMatchWLDetails
		SELECT  
			b.Winlostdate,
			b.currency,
			m.matchid,
			m.homeid,
			m.awayid,
			'SB', --b.bettype,
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
			ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral
		FROM    
			#TempBetList b
			INNER JOIN match m WITH ( NOLOCK ) ON m.matchid = b.matchid
		WHERE   
			(b.bettype < 31 OR (b.Bettype BETWEEN 121 AND 999))
			AND b.tpositiontaking <> 0
		GROUP BY
			b.Winlostdate,
			b.currency,
			m.matchid,
			m.homeid,
			m.awayid,
			--b.bettype,
			m.leagueid,
			m.matchcode,
			m.isNeutral	
				
	END
	
	IF @showRB=1
	BEGIN
		INSERT  INTO @AgMatchWLDetails
		SELECT  
			b.Winlostdate,
			b.currency,
			0 AS matchid,
			0 AS homeid,
			0 AS awayid,
			'RB', --bettype,
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
			CONVERT(BIT, 0) AS IsNeutral
		FROM    
			#TempBetList b
			INNER JOIN outright m WITH ( NOLOCK ) ON m.orid = b.matchid
		WHERE b.bettype IN (31,32,33)
		GROUP BY 
			b.Winlostdate,
			b.currency,
			--bettype,
			m.groupmatch,
			m.leagueid
	END
	
	IF @showNG=1
	BEGIN
		INSERT  INTO @AgMatchWLDetails
		SELECT  
			b.Winlostdate,
			b.currency,
			m.matchid,
			m.homeid,
			m.awayid,
			'NG', --b.bettype,
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
			ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral
		FROM    
			#TempBetList b
			INNER JOIN match m WITH ( NOLOCK ) ON m.matchid = b.matchid
		WHERE   
			b.bettype BETWEEN 81 AND 120
		GROUP BY
			b.Winlostdate,
			b.currency,
			m.matchid,
			m.homeid,
			m.awayid,
			--b.bettype,
			m.leagueid,
			m.matchcode,
			m.isNeutral

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
			0 AS tpositiontaking
		FROM    
			--bettrans14 b WITH(NOLOCK,INDEX (PK_bettrans14))
			bettrans14 b WITH(NOLOCK)
			INNER JOIN @TempAg ag ON b.recommend = ag.custid
			--INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid
		WHERE   
			b.winlostdate = @_Date
			AND b.statusID IN (111,112,113)
			AND tpositiontaking = 0
			AND (b.bettype < 31 OR (b.Bettype BETWEEN 121 AND 999))
		GROUP BY
			b.Winlostdate,
			b.currency,
			b.bettype,
			b.matchid

		INSERT  INTO @AgMatchWLDetails
		SELECT  
			b.Winlostdate,
			b.currency,
			m.matchid,
			m.homeid,
			m.awayid,
			'SB', --b.bettype,
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
			ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral
		FROM   
			#TempBetList b
			INNER JOIN match14 m WITH ( NOLOCK ) ON m.matchid = b.matchid
		GROUP BY
			b.Winlostdate,
			b.currency, 
			m.matchid,
			m.homeid,
			m.awayid,
			--b.bettype,
			m.leagueid,
			m.matchcode,
			m.isNeutral
				
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
		b.tpositiontaking
	FROM    
		bettrans14 b WITH(NOLOCK,INDEX (bettrans143))
		INNER JOIN @TempAg ag ON b.recommend = ag.custid
	WHERE   
		b.winlostdate = @_Date
		AND b.statusID NOT IN ( 101, 102, 103 )
	GROUP BY
		b.Winlostdate,
		b.currency,
		b.bettype,
		b.matchid,
		b.Liveawayscore,
		b.tpositiontaking

	IF @showSB=1
	BEGIN
		INSERT  INTO @AgMatchWLDetails
		SELECT  
			b.Winlostdate,
			b.currency,
			m.matchid,
			m.homeid,
			m.awayid,
			'SB', --b.bettype,
			m.leagueid,
			SUM(stake),
			SUM(winlost),
			-SUM(b.winlost),
			0 AS WinlossRB,
			0 AS AmountDueToBA,
			0 AS AmountDueToRB,
			0 AS CommBA,
			0 as CommRB,
			'' AS race,
			m.matchcode,
			ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral
		FROM   
			#TempBetList b
			INNER JOIN match14 m WITH ( NOLOCK ) ON m.matchid = b.matchid
		WHERE   
			(b.bettype < 31 OR (b.Bettype BETWEEN 121 AND 999))
			AND b.tpositiontaking <> 0
		GROUP BY
			b.Winlostdate,
			b.currency, 
			m.matchid,
			m.homeid,
			m.awayid,
			--b.bettype,
			m.leagueid,
			m.matchcode,
			m.isNeutral
				
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
			'RB', --bettype,
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
			CONVERT(BIT, 0) AS IsNeutral
		FROM    
			#TempBetList b
			INNER JOIN outright14 m WITH ( NOLOCK ) ON m.orid = b.matchid
		WHERE b.bettype IN (31,32,33)
		GROUP BY 
			b.Winlostdate,
			b.currency,
			--bettype,
			m.groupmatch,
			m.leagueid 
	END
	
	IF @showNG=1
	BEGIN
		INSERT  INTO @AgMatchWLDetails
		SELECT  
			b.Winlostdate,
			b.currency,
			m.matchid,
			m.homeid,
			m.awayid,
			'NG', --b.bettype,
			m.leagueid,
			SUM(stake),
			SUM(winlost),
			-SUM(b.winlost),
			0 AS WinlossRB,
			0 AS AmountDueToBA,
			0 AS AmountDueToRB,
			0 AS CommBA,
			0 as CommRB,
			'' AS race,
			m.matchcode,
			ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral
		FROM   
			#TempBetList b
			INNER JOIN match14 m WITH ( NOLOCK ) ON m.matchid = b.matchid
		WHERE   
			b.bettype BETWEEN 81 AND 120
		GROUP BY
			b.Winlostdate,
			b.currency, 
			m.matchid,
			m.homeid,
			m.awayid,
			--b.bettype,
			m.leagueid,
			m.matchcode,
			m.isNeutral
				
	END
END

INSERT INTO @ExchangeDaily
    SELECT ExchangeDate, ExchangeId, USD, EUR
    FROM Lrf_f_GetExchangeDaily(@_Date,@_Date)
    

-- Result
SELECT    
    matchid,
    homeid,
    awayid,
    ProductName, --bettype,
    leagueid,
    CAST(SUM(turnover) AS MONEY) AS turnover,
    CAST(SUM(turnover * e.USD) AS MONEY) AS turnoverUSD,
    CAST(SUM(turnover * e.EUR) AS MONEY) AS turnoverEUR,
    CAST(SUM(MemberWinLost) AS MONEY) AS MemberWinLost,
    CAST(SUM(MemberWinLost * e.USD) AS MONEY) AS MemberWinLostUSD,
    CAST(SUM(MemberWinLost * e.EUR) AS MONEY) AS MemberWinLostEUR,
    CAST(SUM(LicenseeWL) AS MONEY) AS LicenseeWL,
    CAST(SUM(LicenseeWL * e.USD) AS MONEY) AS LicenseeWLUSD,
    CAST(SUM(LicenseeWL * e.EUR) AS MONEY) AS LicenseeWLEUR,
    CAST(SUM(WinlossRB) AS MONEY) AS WinlossRB,
    CAST(SUM(WinlossRB * e.USD) AS MONEY) AS WinlossRBUSD,
    CAST(SUM(WinlossRB * e.EUR) AS MONEY) AS WinlossRBEUR,
    CAST(SUM(CommBA) AS MONEY) AS CommBA,
    CAST(SUM(CommBA * e.USD) AS MONEY) AS CommBAUSD,
    CAST(SUM(CommBA * e.EUR) AS MONEY) AS CommBAEUR,
    CAST(SUM(commRB) AS MONEY) AS commRB,
    CAST(SUM(commRB * e.USD) AS MONEY) AS commRBUSD,
    CAST(SUM(commRB * E.EUR) AS MONEY) AS commRBEUR,
    CAST(SUM(AmtDuetoBA) AS MONEY) AS AmtDuetoBA,
    CAST(SUM((AmtDuetoBA) * e.USD) AS MONEY) AS AmtDuetoBAUSD,
    CAST(SUM((AmtDuetoBA) * e.EUR) AS MONEY) AS AmtDuetoBAEUR,
    CAST(SUM(AmtDuetoRB) AS MONEY) AS AmtDuetoRB,
    CAST(SUM((AmtDuetoRB) * e.USD) AS MONEY) AS AmtDuetoRBUSD,
    CAST(SUM((AmtDuetoRB) * e.EUR) AS MONEY) AS AmtDuetoRBEUR,
    race,
    matchcode,
    isNeutral
FROM  
	@AgMatchWLDetails b
	--INNER JOIN (SELECT *  FROM Lrf_f_GetExchangeDaily(@_FromDate,@_ToDate))e 
	INNER JOIN @ExchangeDaily e ON b.winlostdate = e.ExchangeDate AND b.currency = e.ExchangeId
GROUP BY  
    matchid,
    homeid,
    awayid,
    ProductName, --bettype,
    matchcode,
    leagueid,
    isNeutral,
    race
ORDER BY 
    CASE ProductName WHEN 'SB' THEN 0 WHEN 'NG' THEN 1 ELSE 2 END

DROP TABLE #TempBetList
	
GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_MatchWinLoss] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_MatchWinLoss] TO vnteam

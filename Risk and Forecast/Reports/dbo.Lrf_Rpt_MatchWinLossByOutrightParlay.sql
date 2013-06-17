ALTER PROCEDURE [dbo].[Lrf_Rpt_MatchWinLossByOutrightParlay]
    @LicenseeID INT,
	@UserID		INT,
    @LicenseeType VARCHAR(100) = NULL,
    @CurrencyID INT=0,
    @Date SMALLDATETIME,
    @MoveBetsDay SMALLDATETIME,
    @showSB BIT = 0,
	@showBA BIT = 0
    
AS 
/*
Created: 20120529@don
Task : 
DB: DB052.bodb02
Original: Lrf_Rpt_MatchWinLossDetail
Revisions:
    20120725@Henry: if bettype 29 then show actual_stake else stake
	20120803@Jim: add PlayerComm value ( for give commission to member)
	20120913@Jim: Split column LicenseeWL to separate product
	20121004@Jim: replace @currencyname input param by @currencyID
	20130404@Jim: set default @ShowSB=0
	20130514@Jim: Restrict permission of Licensee Users by currency
	
Param's Explanation: 
	
*/

/* demo script
exec [Lrf_Rpt_MatchWinLossByOutrightParlay] @LicenseeID=3,@LicenseeType=default,@CurrencyID=4,@Date='May 19 2012 12:00:00:000AM',@MoveBetsDay='May 21 2012 12:00:00:000AM',@showSB=1,@showBA=0
*/
SET NOCOUNT ON

DECLARE @ExchangeDaily TABLE(ExchangeDate SMALLDATETIME, ExchangeId INT, USD FLOAT, EUR FLOAT, PRIMARY KEY(ExchangeDate,ExchangeId))
	   
   
DECLARE @_Date AS DATETIME
SET @_Date = @Date

DECLARE @Today SMALLDATETIME 
SELECT @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120) 

SELECT  currencyID,LicenseeID into #currency
FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)
WHERE (@CurrencyID=0  OR (@CurrencyID<>0 AND CurrencyID=@CurrencyID))

DECLARE @TempAg AS TABLE ( CustId INT )
INSERT  INTO @TempAg ( CustId)
SELECT  CustID  
                FROM    bodb_Licensee.dbo.LicenseeCust lc WITH ( NOLOCK )  
						INNER JOIN #Currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID 	
                WHERE  [Description] = COALESCE(@LicenseeType,  
                                                     [Description]) 
-----------------------
DROP TABLE #Currency
-----------------------

DECLARE @AgMatchWLDetails TABLE
(
	Winlostdate SMALLDATETIME,
	Currency INT,
	matchid INT,
	homeid INT,
	awayid INT,
	bettype SMALLINT,
	leagueid INT,
	turnover MONEY,
	MemberWinLost MONEY,
	LicenseeWL		MONEY, --Sportbook and NumberGame
	WinlossRB		MONEY,
	AmtDueToBA	MONEY,   
	AmtDueToRB	MONEY,
	CommBA			MONEY,   
	CommRB		MONEY,  
	PlayerComm  MONEY,	
	race NVARCHAR(20),
	matchcode NVARCHAR(50),
	isNeutral BIT
)

DECLARE @TempBetList AS TABLE(
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
		INSERT INTO @TempBetList 
		SELECT  
			b.Winlostdate,
			b.currency,
			b.bettype,
			SUM(case when b.bettype <> 29 then stake else actual_stake end) as Stake,
			SUM(winlost - actual_stake) as Winlost,
			0 AS awinlost,
			SUM(comm),
			SUM(playercomm  ) AS PlayerComm,
			b.matchid,
			0 AS Liveawayscore,
			0 AS tpositiontaking
		FROM    
			bettrans b WITH(NOLOCK)
			INNER JOIN @TempAg ag ON b.recommend = ag.custid
			--INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid 	 		
		WHERE
             b.winlostdate = @_Date
			AND b.statusID IN (111,112,113)
			AND b.bettype IN (9,10,29)
			AND (b.bettype<31 OR (b.bettype BETWEEN 121 AND 999))
			AND b.tpositiontaking=0
		GROUP BY
			b.Winlostdate,
			b.currency,
			b.bettype,
			b.matchid
		
		--Mix Parlay and Combination Mix Parlay
		INSERT INTO @AgMatchWLDetails
		SELECT  
			b.Winlostdate,
			b.currency,
			0 AS matchid,
			0 AS homeid,
			0 AS awayid,
			b.bettype,
			0 AS leagueid,
			SUM(stake),
			SUM(Winlost),
			0 AS LicenseeWL,
			0 AS WinlossRB,
			-SUM (Winlost +  awinlost + comm) AS AmtDueToBA,
			0 AS AmountDueToRB,
			SUM (comm ) as CommBA,
			0 as CommRB,
			SUM(playercomm) AS PlayerComm,
			'' AS race,
			'' AS matchcode,
			CONVERT(BIT, 0) AS IsNeutral
		FROM @TempBetList b
		WHERE   
			b.bettype IN (9,29) --AND b.matchid IN (9,29)
        GROUP BY 
			b.Winlostdate,
			b.currency,
			b.bettype
		
		--Outright
		INSERT INTO @AgMatchWLDetails
		SELECT  
			b.Winlostdate,
			b.currency,
			0 AS matchid,
			0 AS homeid,
			0 AS awayid,
			10 AS bettype,
			0 AS leagueid,
			SUM(stake),
			SUM(Winlost),
			0 AS LicenseeWL,
			0 AS WinlossRB,
			-SUM (Winlost +  awinlost + comm) AS AmtDueToBA,
			0 AS AmountDueToRB,
			SUM (comm ) as CommBA,
			0 as CommRB,
			SUM(playercomm) AS PlayerComm,
			m.groupmatch AS race,
			'ZZZZ' AS matchcode,
			CONVERT(BIT, 0) AS IsNeutral
		FROM    
			@TempBetList b
			INNER JOIN outright m WITH ( NOLOCK ) ON m.orid = b.matchid
		WHERE b.bettype = 10
		GROUP BY 
			b.Winlostdate,
			b.currency,
			m.groupmatch 
		
	END
	
	--Get general data
	DELETE FROM @TempBetList
	
	INSERT INTO @TempBetList
	SELECT  
		b.Winlostdate,
		b.currency,
		b.bettype,
		SUM(case when b.bettype <> 29 then stake else actual_stake end) as Stake,
		SUM(winlost - actual_stake) as Winlost,
		SUM(b.awinlost) AS awinlost,
		SUM(b.comm) AS comm,
		SUM(b.playercomm  ) AS playercomm,
		b.matchid,
		b.Liveawayscore,
		b.tpositiontaking
	FROM    
		bettrans b WITH(NOLOCK)
		INNER JOIN @TempAg ag ON b.recommend = ag.custid
	WHERE   
		b.winlostdate = @_Date
		AND b.statusID IN (111,112,113)
		AND b.bettype IN (9,10,29)
		AND b.matchid>0
	GROUP BY
		b.Winlostdate,
		b.currency,
		b.bettype,
		b.matchid,
		b.Liveawayscore,
		b.tpositiontaking
				
	IF @showSB=1 
	BEGIN		
		--MixParlay and Combination MixParlay
		INSERT  INTO @AgMatchWLDetails
		SELECT  
			b.Winlostdate,
			b.currency,
			0 AS matchid,
			0 AS homeid,
			0 AS awayid,
			b.bettype,
			0 AS leagueid,
			SUM(stake),
			SUM(winlost),
			-SUM(b.winlost) AS LicenseeWL,
			0 AS WinlossRB,
			0 AS AmountDueToBA,
			0 AS AmountDueToRB,
			0 AS CommBA,
			0 as CommRB,
			SUM(playercomm) AS PlayerComm,
			'' AS race,
			'' AS matchcode ,
			CONVERT(BIT, 0) AS IsNeutral
		FROM    
			@TempBetList b
		WHERE   
			b.bettype IN (9,29) --AND b.matchid IN (9,29) 
			AND b.tpositiontaking<>0
        GROUP BY 
			b.Winlostdate,
			b.currency,
			b.bettype
				
		-- Outright
		INSERT INTO @AgMatchWLDetails
		SELECT  
			b.Winlostdate,
			b.currency,
			0 AS matchid,
			0 AS homeid,
			0 AS awayid,
			10 AS bettype,
			0 AS leagueid,
			SUM(b.stake),
			SUM(b.winlost),
			- SUM(b.winlost) AS LicenseeWL,
			0 AS WinlossRB,
			0 AS AmountDueToBA,
			0 AS AmountDueToRB,
			0 AS CommBA,
			0 as CommRB,
			SUM(playercomm) AS PlayerComm,
			m.groupmatch AS race,
			'ZZZZ' AS matchcode,
			CONVERT(BIT, 0) AS IsNeutral
		FROM    
			@TempBetList b
			INNER JOIN outright m WITH ( NOLOCK ) ON m.orid = b.matchid
		WHERE b.bettype = 10 AND b.tpositiontaking<>0
		GROUP BY 
			b.Winlostdate,
			b.currency,
			--bettype,
			m.groupmatch
	END
	
END
IF @_Date <= @MoveBetsDay 
BEGIN
	
	IF @ShowBA = 1
	BEGIN
		DELETE FROM @TempBetList
		
		INSERT INTO @TempBetList 
		SELECT  
			b.Winlostdate,
			b.currency,
			b.bettype,
			SUM(stake) as Stake,
			SUM(winlost - actual_stake) as Winlost,
			0 AS awinlost,
			SUM(comm),
			SUM( b.playercomm) AS PlayerComm,
			b.matchid,
			0 AS Liveawayscore,
			0 as tpositiontaking
		FROM    
			bettrans14 b WITH(NOLOCK)
			INNER JOIN @TempAg ag ON b.recommend = ag.custid
		--	INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid 
		WHERE   
			 b.winlostdate = @_Date
			AND b.statusID IN (111,112,113)
			AND b.bettype IN (9,10,29)
			AND b.tpositiontaking=0
		GROUP BY
			b.Winlostdate,
			b.currency,
			b.bettype,
			b.matchid
				
		--Mix Parlay and Mix Parlay Combination
		INSERT INTO @AgMatchWLDetails
		SELECT  
			b.Winlostdate,
			b.currency,
			0 AS matchid,
			0 AS homeid,
			0 AS awayid,
			b.bettype,
			0 AS leagueid,
			SUM(stake),
			SUM(Winlost),
			0 AS LicenseeWL,
			0 AS WinlossRB,
			-SUM (Winlost +  awinlost + comm) AS AmtDueToBA,
			0 AS AmountDueToRB,
			SUM (comm ) as CommBA,
			0 as CommRB,
			SUM(playercomm) AS PlayerComm,
			'' AS race,
			'' AS matchcode,
			CONVERT(BIT, 0) AS IsNeutral
		FROM @TempBetList b	
		WHERE b.bettype IN (9,29) --AND b.matchid IN (9,29)
		GROUP BY
			b.Winlostdate,
			b.currency,
			b.bettype
		
		--outright
		INSERT INTO @AgMatchWLDetails
		SELECT  
			b.Winlostdate,
			b.currency,
			0 AS matchid,
			0 AS homeid,
			0 AS awayid,
			10 AS bettype,
			0 AS leagueid,
			SUM(stake),
			SUM(Winlost),
			0 AS LicenseeWL,
			0 AS WinlossRB,
			-SUM (Winlost +  awinlost + comm) AS AmtDueToBA,
			0 AS AmountDueToRB,
			SUM (comm ) as CommBA,
			0 as CommRB,
			SUM(playercomm) AS PlayerComm,
			m.groupmatch AS race,
			'ZZZZ' AS matchcode,
			CONVERT(BIT, 0) AS IsNeutral
		FROM    
			@TempBetList b
			INNER JOIN outright14 m WITH ( NOLOCK ) ON m.orid = b.matchid
		WHERE b.bettype = 10
		GROUP BY 
			b.Winlostdate,
			b.currency,
			--bettype,
			m.groupmatch
	END

	--Get general data
	DELETE FROM @TempBetList
	
	INSERT INTO @TempBetList
	SELECT  
		b.Winlostdate,
		b.currency,
		b.bettype,
		SUM(stake) as Stake,
		SUM(winlost - actual_stake) as Winlost,
		SUM(b.awinlost) AS awinlost,
		SUM(b.comm) AS comm,
		SUM(b.playercomm ) AS playercomm,
		b.matchid,
		b.Liveawayscore,
		b.tpositiontaking
	FROM    
		bettrans14 b WITH(NOLOCK)
		INNER JOIN @TempAg ag ON b.recommend = ag.custid
	WHERE
		b.winlostdate = @_Date
		AND b.statusID NOT IN ( 101, 102, 103 )
		AND b.bettype IN (9,10,29)
	GROUP BY
		b.Winlostdate,
		b.currency,
		b.bettype,
		b.matchid,
		b.Liveawayscore,
		b.tpositiontaking

	IF @showSB=1
	BEGIN		
		-- Mix parlay (14) and Combination Mix parlay (14)
		INSERT INTO @AgMatchWLDetails
		SELECT  
			b.Winlostdate,
			b.currency,
			0 AS matchid,
			0 AS homeid,
			0 AS awayid,
			b.bettype,
			0 AS leagueid,
			SUM(stake) AS stake,
			SUM(b.winlost),
			-SUM(b.winlost) AS LicenseeWL,
			0 AS WinlossRB,
			0 AS AmountDueToBA,
			0 AS AmountDueToRB,
			0 AS CommBA,
			0 AS CommRB,
			SUM(playercomm) AS PlayerComm,
			'' AS race,
			'' AS matchcode,
			CONVERT(BIT, 0) AS IsNeutral
		FROM    
			@TempBetList b
		WHERE   
			b.bettype IN (9,29) -- AND b.matchid IN (9,29)
			AND b.tpositiontaking <> 0
		GROUP BY
			b.Winlostdate,
			b.currency,
			b.bettype
				
		-- Outright (14)
		INSERT  INTO @AgMatchWLDetails
		SELECT  
			b.Winlostdate,
			b.currency,
			0 AS matchid,
			0 AS homeid,
			0 AS awayid,
			10 AS bettype,
			0 AS leagueid,
			SUM(b.stake),
			SUM(winlost),
			- SUM(b.winlost) AS LicenseeWL,
			0 AS WinlossRB,
			0 AS AmountDueToBA,
			0 AS AmountDueToRB,
			0 AS CommBA,
			0 AS CommRB,
			SUM(playercomm) AS PlayerComm,
			m.groupmatch AS race,
			'ZZZZ' AS matchcode,
			CONVERT(BIT, 0) AS IsNeutral
		FROM    
			@TempBetList b
			INNER JOIN outright14 m WITH ( NOLOCK ) ON m.orid = b.matchid
		WHERE b.bettype = 10 AND b.tpositiontaking <> 0
		GROUP BY 
			b.Winlostdate,
			b.currency,
			--bettype,
			m.groupmatch
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
    bettype,
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
	CAST(SUM(playercomm) AS MONEY) AS PlayerComm,
	CAST(SUM(playercomm*e.USD) AS MONEY) AS PlayerCommUSD,
	CAST(SUM(playercomm*e.EUR) AS MONEY) AS PlayerCommEUR,
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
    bettype,
    matchcode,
    leagueid,
    isNeutral,
    race
	
GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_MatchWinLossByOutrightParlay] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_MatchWinLossByOutrightParlay] TO vnteam

/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
 

ALTER PROCEDURE [dbo].[Lrf_Rpt_MatchWinLossByOutrightParlay]    
    @Date SMALLDATETIME,
    @MoveBetsDay SMALLDATETIME,
    @showSB		BIT = 0,
	@showBA		BIT = 0,
	@showVS2	BIT = 0,
	@AgentList	VARCHAR(MAX)
    
AS 
/*
Created: 20120529@don
Task : 
DB: DB052.bodb02
Original: Lrf_Rpt_MatchWinLossDetail
Revisions:
    - 20120725@Henry: if bettype 29 then show actual_stake else stake
	- 20120803@Jim: add PlayerComm value ( for give commission to member)
	- 20120913@Jim: Split column LicenseeWL to separate product
	- 20121004@Jim: replace @currencyname input param by @currencyID
	- 20130404@Jim: set default @ShowSB=0
	- 20130514@Jim: Restrict permission of Licensee Users by currency
	- 20140620@Florent: add column betcount
   - 20141111@Jim: changing currency for KeenOcean member  (#Redmine 25673)
   - 20150123@Jim: support base on Currency GBP
   - 20170227@Harper: LRF - Get data by @AgentList instead of @UserID [RedmineID: #71679]
   - 20170704@Harper: LRF - Integrate Bet Radar Virtual Sports [RedmineID: #78241]

Param's Explanation: 
	+ @AgentList: xml structure
					  <ROOT>
					   <Agent AgentId="12345" Currency="3"/>  
					   <Agent AgentId="12345" Currency="5"/>  
					  </ROOT> 
*/

/* demo script
exec [Lrf_Rpt_MatchWinLossByOutrightParlay] @LicenseeID=3,@LicenseeType=default,@CurrencyID=4,@Date='May 19 2012 12:00:00:000AM',@MoveBetsDay='May 21 2012 12:00:00:000AM',@showSB=1,@showBA=0
*/
SET NOCOUNT ON

DECLARE @ExchangeDaily TABLE(ExchangeDate SMALLDATETIME, ExchangeId INT, USD FLOAT, EUR FLOAT,GBP FLOAT, PRIMARY KEY(ExchangeDate,ExchangeId))
	   
   
DECLARE @_Date AS DATETIME
SET @_Date = @Date

DECLARE @Today SMALLDATETIME 
SELECT @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120) 

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
	isNeutral BIT,
	betcount INT
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
	tpositiontaking	SMALLMONEY,
	betcount int
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
			0 AS tpositiontaking,
			count(1) betcount
		FROM    
			bettrans b WITH(NOLOCK)
			INNER JOIN @TempAg ag ON b.recommend = ag.custid AND b.Currency = ag.Currency
			--INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid 	 		
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
			CONVERT(BIT, 0) AS IsNeutral,
			sum(b.betcount) betcount
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
			CONVERT(BIT, 0) AS IsNeutral,
			sum(b.betcount) betcount
		FROM    
			@TempBetList b
			INNER JOIN outright m WITH ( NOLOCK ) ON m.orid = b.matchid
		WHERE b.bettype = 10
		GROUP BY 
			b.Winlostdate,
			b.currency,
			m.groupmatch 
		
	END
				
	IF @showSB=1 
	BEGIN		
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
			b.tpositiontaking,
			count(1) betcount
		FROM    
			bettrans b WITH(NOLOCK)
			INNER JOIN @TempAg ag ON b.recommend = ag.custid AND b.Currency = ag.Currency
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
			CONVERT(BIT, 0) AS IsNeutral,
			sum(b.betcount) betcount
		FROM    
			@TempBetList b
		WHERE   
			b.bettype IN (9,29)
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
			CONVERT(BIT, 0) AS IsNeutral,
			sum(b.betcount) betcount
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

	IF @showVS2 = 1 
	BEGIN	

		INSERT INTO @AgMatchWLDetails ( Winlostdate, Currency, matchid,	homeid,	awayid,
										bettype, leagueid, turnover, MemberWinLost, LicenseeWL, WinlossRB,
										AmtDueToBA, AmtDueToRB,	CommBA,	CommRB, PlayerComm,	race, matchcode, isNeutral, betcount
					)
		SELECT  
			b.Winlostdate,
			b.currency,
			0 AS matchid,
			0 AS homeid,
			0 AS awayid,
			b.bettype,
			0 AS leagueid,
			SUM(b.stake) AS TurnOver,
			SUM(winlost - actual_stake) AS MemberWinLost,
			-SUM(winlost - actual_stake) AS LicenseeWL,
			0 AS WinlossRB,
			0 AS AmtDueToBA,
			0 AS AmtDueToRB,
			0 AS CommBA,
			0 as CommRB,			
			SUM(b.playercomm) AS playercomm,
			'' AS race,
			'' AS matchcode,
			CONVERT(BIT, 0) AS IsNeutral,			
			count(1) betcount
		FROM    
			dbo.bettrans b WITH(NOLOCK)
			INNER JOIN @TempAg ag ON b.recommend = ag.custid AND b.Currency = ag.Currency
		WHERE   
			b.winlostdate = @_Date
			AND b.statusID IN (111,112,113)
			AND b.bettype = 2799
			AND b.matchid > 0
		GROUP BY
			b.Winlostdate,
			b.currency,
			b.bettype			
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
			0 as tpositiontaking,
			count(1) betcount
		FROM    
			bettrans14 b WITH(NOLOCK)
			INNER JOIN @TempAg ag ON b.recommend = ag.custid AND b.Currency = ag.Currency
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
			CONVERT(BIT, 0) AS IsNeutral,
			sum(b.betcount) betcount
		FROM @TempBetList b	
		WHERE b.bettype IN (9,29) 
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
			CONVERT(BIT, 0) AS IsNeutral,
			sum(b.betcount) betcount
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

	IF @showSB=1
	BEGIN		
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
			b.tpositiontaking,
			count(1) betcount
		FROM    
			bettrans14 b WITH(NOLOCK)
			INNER JOIN @TempAg ag ON b.recommend = ag.custid AND b.Currency = ag.Currency
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
			CONVERT(BIT, 0) AS IsNeutral,
			sum(b.betcount) betcount
		FROM    
			@TempBetList b
		WHERE   
			b.bettype IN (9,29)
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
			CONVERT(BIT, 0) AS IsNeutral,
			sum(b.betcount) betcount
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

	IF @showVS2 = 1 
	BEGIN	

		INSERT INTO @AgMatchWLDetails ( Winlostdate, Currency, matchid,	homeid,	awayid,
										bettype, leagueid, turnover, MemberWinLost, LicenseeWL, WinlossRB,
										AmtDueToBA, AmtDueToRB,	CommBA,	CommRB, PlayerComm,	race, matchcode, isNeutral, betcount
					)
		SELECT  
			b.Winlostdate,
			b.currency,
			0 AS matchid,
			0 AS homeid,
			0 AS awayid,
			b.bettype,
			0 AS leagueid,
			SUM(b.stake) AS TurnOver,
			SUM(winlost - actual_stake) AS MemberWinLost,
			-SUM(winlost - actual_stake) AS LicenseeWL,
			0 AS WinlossRB,
			0 AS AmtDueToBA,
			0 AS AmtDueToRB,
			0 AS CommBA,
			0 as CommRB,			
			SUM(b.playercomm) AS playercomm,
			'' AS race,
			'' AS matchcode,
			CONVERT(BIT, 0) AS IsNeutral,			
			count(1) betcount
		FROM    
			dbo.bettrans14 b WITH(NOLOCK)
			INNER JOIN @TempAg ag ON b.recommend = ag.custid AND b.Currency = ag.Currency
		WHERE   
			b.winlostdate = @_Date
			AND b.statusID IN (111,112,113)
			AND b.bettype = 2799
			AND b.matchid > 0
		GROUP BY
			b.Winlostdate,
			b.currency,
			b.bettype			
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
	CAST(SUM(turnover * e.GBP) AS MONEY) AS turnoverGBP,
    CAST(SUM(MemberWinLost) AS MONEY) AS MemberWinLost,
    CAST(SUM(MemberWinLost * e.USD) AS MONEY) AS MemberWinLostUSD,
    CAST(SUM(MemberWinLost * e.EUR) AS MONEY) AS MemberWinLostEUR,
	CAST(SUM(MemberWinLost * e.GBP) AS MONEY) AS MemberWinLostGBP,
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
	CAST(SUM(playercomm) AS MONEY) AS PlayerComm,
	CAST(SUM(playercomm*e.USD) AS MONEY) AS PlayerCommUSD,
	CAST(SUM(playercomm*e.EUR) AS MONEY) AS PlayerCommEUR,
	CAST(SUM(playercomm*e.GBP) AS MONEY) AS PlayerCommGBP,
    CAST(SUM(AmtDuetoBA) AS MONEY) AS AmtDuetoBA,
    CAST(SUM((AmtDuetoBA) * e.USD) AS MONEY) AS AmtDuetoBAUSD,
    CAST(SUM((AmtDuetoBA) * e.EUR) AS MONEY) AS AmtDuetoBAEUR,
	CAST(SUM((AmtDuetoBA) * e.GBP) AS MONEY) AS AmtDuetoBAGBP,
    CAST(SUM(AmtDuetoRB) AS MONEY) AS AmtDuetoRB,
    CAST(SUM((AmtDuetoRB) * e.USD) AS MONEY) AS AmtDuetoRBUSD,
    CAST(SUM((AmtDuetoRB) * e.EUR) AS MONEY) AS AmtDuetoRBEUR,
	CAST(SUM((AmtDuetoRB) * e.GBP) AS MONEY) AS AmtDuetoRBGBP,
    race,
    matchcode,
    isNeutral,
	sum(b.betcount) betcount
FROM  
	@AgMatchWLDetails b
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
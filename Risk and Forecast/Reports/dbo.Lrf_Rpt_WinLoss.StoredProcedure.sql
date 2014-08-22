USE [bodb02]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Lrf_Rpt_WinLoss]
    @LicenseeID INT ,
	@UserID		INT,    
	@DrawFilter	SMALLINT =1,
    @CurrencyID INT = 0 ,
    @FromDate DATETIME,
    @ToDate DATETIME ,
    @showSB BIT = 0,
    @ShowRB BIT = 0,
    @showNG BIT = 0, 
    @ShowBA BIT = 0,
	@ShowLC BIT = 0,
	@ShowVS BIT = 0,
	@ShowCS BIT = 0,-- RNG Casino
	@ShowBG BIT = 0,-- Bingo
	@ShowKN BIT = 0,
    @MoveBetsDay DATETIME ,
    @PageSize INT = 1000 ,
    @PageIndex INT = 1,
    @IsOld BIT = 0
    
    
AS /*
    Created: 20101201@Jacob
    TASk : 
    DB: DB052.bodb02
    Original SP:Age_Rpt_WinLoss_Ag
    Param's Explanation:
		+ @IsOld: 0 - query IN table rptLicWinloss, 1 - query IN table rptLicWinloss_old. 
		+ @DrawFilter :  1 - Filter Nomal (Win, Lose, Draw)
					 2 - Filter bets No Draw (Win,Draw)
					 3 - Filter No Draw For turnover only: include betcount, exclude stake 
	  
    Revisions:
        - 20101201@Jacob: Copy code FROM Age_Rpt_WinLoss, remove redundant column
        - 2011216@Alex:Add UserName2
        - 20110303@Jacob: Allow to choose all type of licensee AND all currency + suppport bASed currency
        - 20110519@Henry: Allow number game
        - 20110609@Henry: change rptLicWinlost to rptLicWinloss
        - 20110616@Henry: Add column Comm, add param @BAFilter
        - 20110707@Henry: show Comm, Amt Due to for each 3rd party product: BA, Racing
        - 20110729@Henry: offer 3 new bettypes for Number Game
        - 20111013@Henry: change to use rptLicWinloss2
        - 20111208@Jim: change bettype condition
        - 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily 
        - 20120403@Henry: enhance performance
        - 20120731@Jim: add playercomm value 
        - 20120815@Jim: add live casino 
		- 20120905@Jim: add virtual sport 
		- 20121004@Jim: replace @CurrencyName input param by @CurrencyID
		- 20121115@Henry: Only Sportsbook needs to exclude BA
		- 20121128@Henry: use new table LicenseeBATransaction_active to get bettrans BA tickets
		- 20130225@Jim: support RNG Casino, Bingo 
		- 20130618@Jim: Restrict permission of Licensee Users by currency
		- 20130729@Viet: enhance sp
		- 20130809@Jim: offer Virtual Horse Racing
		- 20131007@Jim: offer Virtual Tennis
		- 20140225@Florent: add filter Show Draw for betcount, stake
		- 20140326@Jim: offer Keno
		- 20140604@Victor: Enhance performance
		- 20140620@Florent: offer 14 new bettypes and Sporting Solution (36 new bettypes)
		- 20140819@Jim: add more column BetEffective in the result
*/
    

SET NOCOUNT ON

DECLARE @_FromDate SMALLDATETIME
		,@_ToDate SMALLDATETIME
		,@BetEffectiveDate SMALLDATETIME
		,@RowStart INT 
		,@RowEnd INT 
		,@Today SMALLDATETIME 
		,@TempFromDate DATETIME 
		,@TempToDate DATETIME
DECLARE @TempAg AS TABLE ( CustId INT,Currency INT )
DECLARE @TempSAg AS TABLE ( CustId INT,Currency INT )
DECLARE @LicenseeName VARCHAR(50)
DECLARE @bettype AS TABLE (bettype INT PRIMARY KEY)
DECLARE @sporttype TABLE(sporttype INT)
DECLARE @Exchange AS TABLE (
							ExchangeDate SMALLDATETIME
							,ExchangeId INT
							,MYR FLOAT
							,USD FLOAT
							,EUR FLOAT
							,PRIMARY KEY(ExchangeDate,ExchangeId)
							)
						
SELECT @LicenseeName = LicenseeName FROM bodb_Licensee.dbo.Licensees (NOLOCK) WHERE LicenseeID = @LicenseeID
SELECT @_FromDate = @FromDate
	   ,@_ToDate = @ToDate
	   ,@BetEffectiveDate = '2014-08-01'
SELECT  @PageIndex = @PageIndex - 1 
        ,@RowStart = @PageSize * @PageIndex + 1 
        ,@RowEnd = @RowStart + @PageSize - 1
SELECT @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120) 
SELECT  currencyID,LicenseeID 
	    INTO #currency
FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)
WHERE (@CurrencyID=0  OR (@CurrencyID<>0 AND CurrencyID=@CurrencyID))

INSERT  INTO @TempAg(CustId,Currency)
SELECT CustID,Currency 
FROM bodb_Licensee.dbo.LicenseeCust lc WITH ( NOLOCK )
	INNER JOIN #Currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID

INSERT  INTO @TempSAg(CustId,Currency)
SELECT CustID,Currency 
FROM dbo.Dep_CustSuper lc WITH ( NOLOCK )
	INNER JOIN #Currency c ON lc.Currency=c.CurrencyID
WHERE lc.site = @LicenseeName

DROP TABLE #Currency 

INSERT INTO @Exchange (ExchangeDate,ExchangeId,MYR,USD,EUR)
SELECT 
	ExchangeDate
	,ExchangeId
	,MYR
	,USD
	,EUR
FROM Lrf_f_GetExchangeDaily(@_FromDate,@_ToDate)
WHERE exchangeid IN (SELECT DISTINCT Currency FROM @TempAg)

IF @ShowSB = 1 
BEGIN
    INSERT  INTO @sporttype( Sporttype)
    VALUES  (0)
END
IF @ShowRB = 1 
BEGIN
    INSERT  INTO @sporttype( Sporttype)
    VALUES  (151)
    
    INSERT INTO @bettype(bettype)
	SELECT typeid FROM bettype (NOLOCK)
	WHERE typeid BETWEEN 31 AND 33
END
IF @ShowNG = 1  
BEGIN  
	INSERT INTO @sporttype(Sporttype)  
	VALUES(161)  
	
	INSERT INTO @bettype(bettype)
	SELECT typeid FROM bettype (NOLOCK)
	WHERE (typeid BETWEEN 81 AND 120)
END 
IF @ShowLC = 1
BEGIN
	INSERT  INTO @sporttype( Sporttype)
    VALUES  (162)
    
    INSERT INTO @bettype(bettype)
	SELECT typeid FROM bettype (NOLOCK)
	WHERE (typeid BETWEEN 1101 AND 1199)
END
IF @ShowVS = 1
BEGIN
	INSERT  INTO @sporttype( Sporttype)
    SELECT 180
    
	INSERT INTO @bettype(bettype)
	SELECT typeid FROM bettype (NOLOCK)
	WHERE (typeid BETWEEN 1201 AND 1299)
END

IF @ShowCS = 1
BEGIN
	INSERT  INTO @sporttype( Sporttype)
    VALUES  (251)
    
    INSERT INTO @bettype(bettype)
	SELECT typeid FROM bettype (NOLOCK)
	WHERE typeid=71
END

IF @ShowBG = 1
BEGIN
	INSERT  INTO @sporttype( Sporttype)
    VALUES  (252)
    
    INSERT INTO @bettype(bettype)
	SELECT typeid FROM bettype (NOLOCK)
	WHERE typeid=73
END

IF @ShowKN=1 -- keno
BEGIN 
	INSERT INTO @sporttype (sporttype)
	VALUES(202)

	INSERT INTO @bettype(bettype)
	SELECT typeid FROM bettype (NOLOCK)
	WHERE (typeid BETWEEN 1501 AND 1599)
END

CREATE TABLE #TempData
(
	CustID INT 
	,rptDate DATETIME
	,StatusId INT
	,TurnOver MONEY 
	,TurnOverUSD MONEY
	,TurnOverEUR MONEY
	
	,MemberWinLost MONEY 
	,MemberWinLostUSD MONEY
	,MemberWinLostEUR MONEY
	
	,BetEffective	 MONEY
	,BetEffectiveUSD  MONEY
	,BetEffectiveEUR	 MONEY
	
	,LicenseeWL		MONEY
	,LicenseeWLUSD MONEY
	,LicenseeWLEUR MONEY
	
	,WinlossRB		MONEY
	,WinlossRBUSD	MONEY
	,WinlossRBEUR MONEY
	
	,AmtDueToBA	MONEY
	,AmtDuetoBAUSD MONEY
	,AmtDuetoBAEUR MONEY
	  
	,AmtDueToRB	MONEY
	,AmtDuetoRBUSD MONEY
	,AmtDuetoRBEUR MONEY
	
	,CommBA		MONEY
	,CommBAUSD MONEY
	,CommBAEUR MONEY
	 
	,CommRB		MONEY
	,commRBUSD MONEY
	,commRBEUR MONEY
	
	,PlayerComm  MONEY 
	,PlayerCommUSD MONEY
	,PlayerCommEUR MONEY

	,betcount int		
)
CREATE TABLE #TempCustID
(
	CustID INT PRIMARY KEY
)
CREATE TABLE #TempCustIDFull
(
	CustID INT PRIMARY KEY
)

IF @_Todate > @MoveBetsDay 
BEGIN 
	IF @_FromDate <= @MoveBetsDay 
		SET @TempFromDate =  DATEADD(DAY,1,@MoveBetsDay)
	ELSE
		SET @TempFromDate = @_FromDate
	
	IF @ShowBA=1 
	BEGIN	
		INSERT  INTO #TempData
		SELECT  
			b.CustID ,
			b.winlostdate AS rptDate,
			b.statusId,
			SUM(CASE WHEN (@DrawFilter IN (2,3) AND b.statusid=111) THEN 0
					 ELSE stake
				END
			) AS Turnover ,
			SUM(CASE WHEN(@DrawFilter IN (2,3) AND b.statusid=111) THEN 0
					 ELSE b.stake*e.USD
				END
			) AS TurnoverUSD ,
			SUM(CASE WHEN (@DrawFilter in (2,3) AND b.statusid=111) THEN 0
					 ELSE stake*e.EUR
				END
			) AS TurnoverEUR ,
			
			SUM(winlost - actual_stake) AS MemberWinlost ,
			SUM((winlost - actual_stake)*e.USD) MemberWinlostUSD ,
			SUM((winlost - actual_stake)*e.EUR) MemberWinlostEUR ,
			SUM(ABS(winlost - actual_stake)) AS BetEffective ,
			SUM(ABS(winlost - actual_stake)*e.USD) AS BetEffectiveUSD ,
			SUM(ABS(winlost - actual_stake)*e.EUR) AS BetEffectiveEUR ,
			0 AS LicenseeWL,
			0 AS LicenseeWLUSD,
			0 AS LicenseeWLEUR,
			0 AS WinlossRB,
			0 AS WinlossRBUSD,
			0 AS WinlossRBEUR,
			- SUM (b.winlost - b.actual_stake + awinlost + comm ) AS AmountDueToBA,
			- SUM ((b.winlost - b.actual_stake + awinlost + comm )*e.USD) AS AmountDueToBAUSD,
			- SUM ((b.winlost - b.actual_stake + awinlost + comm )*e.EUR) AS AmountDueToBAEUR,
			0 AS AmountDueToRB,
			0 AS AmountDueToRBUSD,
			0 AS AmountDueToRBEUR,
			SUM (comm) AS CommBA,
			SUM (comm*e.USD) AS CommBAUSD,
			SUM (comm*e.EUR) AS CommBAEUR,
			0 AS CommRB,
			0 AS CommRBUSD,
			0 AS CommRBEUR,
			SUM(PlayerComm  ) AS PlayerComm ,
			SUM(PlayerComm *e.USD ) AS PlayerCommUSD ,
			SUM(PlayerComm *e.EUR ) AS PlayerCommEUR,
			SUM(CASE WHEN (@DrawFilter =2 AND b.statusid=111) THEN 0
					 ELSE 1
				END) AS betcount
		FROM    
			bettrans b WITH ( NOLOCK)   
			LEFT JOIN @Exchange e  ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
		WHERE transid IN (SELECT transid FROM bodb_Licensee.dbo.LicenseeBATransaction_active WITH (NOLOCK) WHERE recommend IN (SELECT custid FROM @TempAg))
			AND winlostdate BETWEEN @TempFromDate AND @_ToDate
			AND b.statusID  IN (111, 112, 113)
			and bettype < 19999
		GROUP BY b.CustID,b.winlostdate,b.statusId 
	END

	IF (@ShowSB=1)
	BEGIN
		INSERT INTO #TempData
		SELECT  
			b.CustID ,
			b.winlostdate,
			b.statusId,
			SUM(CASE WHEN (@DrawFilter IN (2,3) AND b.statusid=111) THEN 0
					 ELSE stake
				END
			) AS Turnover,
			SUM(CASE WHEN (@DrawFilter IN (2,3) AND b.statusid=111) THEN 0
					 ELSE stake*e.USD
				END
			) AS TurnoverUSD,
			SUM(CASE WHEN (@DrawFilter IN (2,3) AND b.statusid=111) THEN 0
					 ELSE stake*e.EUR
				END
			) AS TurnoverEUR,
			SUM(winlost - actual_stake) AS MemberWinlost ,
			SUM((winlost - actual_stake)*e.USD) MemberWinlostUSD ,
			SUM((winlost - actual_stake)*e.EUR) MemberWinlostEUR ,
			SUM(ABS(winlost - actual_stake)) AS BetEffective,
			SUM(ABS(winlost - actual_stake)*e.USD) AS BetEffectiveUSD,
			SUM(ABS(winlost - actual_stake)*e.EUR) AS BetEffectiveEUR,
			- SUM(b.winlost - b.actual_stake) AS LicenseeWL,
			- SUM((b.winlost - b.actual_stake)*e.USD) AS LicenseeWLUSD,
			- SUM((b.winlost - b.actual_stake)*e.EUR) AS LicenseeWLEUR,
			0 AS WinlossRB,
			0 AS WinlossRBUSD,
			0 AS WinlossRBEUR,
			0 AS AmountDueToBA,
			0 AS AmountDueToBAUSD,
			0 AS AmountDueToBAEUR,
			0 AS AmountDueToRB,
			0 AS AmountDueToRBUSD,
			0 AS AmountDueToRBEUR,
			0 AS CommBA,
			0 AS CommBAUSD,
			0 AS CommBAEUR,
			0 AS CommRB,
			0 AS CommRBUSD,
			0 AS CommRBEUR,
			SUM( b.PlayerComm )  AS PlayerComm ,
			SUM(PlayerComm *e.USD ) AS PlayerCommUSD ,
			SUM(PlayerComm *e.EUR ) AS PlayerCommEUR,
			SUM(CASE WHEN (@DrawFilter =2 AND b.statusid=111) THEN 0					 
				ELSE 1
				END) AS betcount
		FROM    
			Bettrans b WITH ( NOLOCK, INDEX = IX_srecommend)
			INNER JOIN @TempSAg a ON b.srecommend = a.custid
			LEFT JOIN @Exchange e  ON e.ExchangeDate = b.winlostdate AND e.exchangeid = a.currency
		WHERE   
			winlostdate BETWEEN @TempFromDate AND @_ToDate
			AND (b.bettype<31 OR (b.bettype BETWEEN 121 AND 999)
							  OR (b.Bettype BETWEEN 1301 AND 1399) 
			)
			AND b.statusID  IN (111, 112, 113)
			AND b.tpositiontaking <>0
		GROUP BY b.CustID,b.winlostdate,b.StatusId 
	END

	IF (@ShowNG = 1 OR @ShowLC=1 OR @ShowVS=1 OR @ShowRB=1 OR @ShowCS=1 OR @ShowBG=1 OR @ShowKN=1)
	BEGIN
		INSERT INTO #TempData
		SELECT  
			b.CustID ,
			b.winlostdate,
			b.statusId,
			SUM(CASE WHEN (@DrawFilter IN (2,3) AND b.statusid=111) THEN 0
					 ELSE 
					 CASE WHEN b.liveawayscore = 0 AND b.bettype IN ( 33, 43 ) THEN b.stake / 2 ELSE b.stake END
				END
			) AS Turnover ,
			SUM(CASE WHEN (@DrawFilter IN (2,3) AND b.statusid=111) THEN 0
					 ELSE 
					 CASE WHEN b.liveawayscore = 0 AND b.bettype IN ( 33, 43 ) THEN b.stake / 2 ELSE b.stake END
				END * e.USD
			) AS TurnoverUSD ,
			SUM(CASE WHEN (@DrawFilter IN (2,3) AND b.statusid=111) THEN 0
					 ELSE 
					 CASE WHEN b.liveawayscore = 0 AND b.bettype IN ( 33, 43 ) THEN b.stake / 2 ELSE b.stake END
				END* e.EUR
			) AS TurnoverEUR ,
			SUM(winlost - actual_stake) AS MemberWinlost ,
			SUM((winlost - actual_stake)*e.USD) MemberWinlostUSD ,
			SUM((winlost - actual_stake)*e.EUR) MemberWinlostEUR ,
			SUM(ABS(winlost - actual_stake)) AS BetEffective,
			SUM(ABS(winlost - actual_stake)*e.USD) AS BetEffectiveUSD,
			SUM(ABS(winlost - actual_stake)*e.EUR) AS BetEffectiveEUR,
			- SUM(CASE WHEN b.bettype NOT BETWEEN 31 AND 33 THEN b.winlost - b.actual_stake ELSE 0 END) AS LicenseeWL,
			- SUM(CASE WHEN b.bettype NOT BETWEEN 31 AND 33 THEN b.winlost - b.actual_stake ELSE 0 END * e.USD) AS LicenseeWLUSD,
			- SUM(CASE WHEN b.bettype NOT BETWEEN 31 AND 33 THEN b.winlost - b.actual_stake ELSE 0 END * e.EUR) AS LicenseeWLEUR,
			SUM (CASE WHEN b.bettype BETWEEN 31 AND 33 THEN b.awinlost ELSE 0 END) AS WinlossRB,
			SUM (CASE WHEN b.bettype BETWEEN 31 AND 33 THEN b.awinlost ELSE 0 END * e.USD) AS WinlossRBUSD,
			SUM (CASE WHEN b.bettype BETWEEN 31 AND 33 THEN b.awinlost ELSE 0 END * e.EUR) AS WinlossRBEUR,
			0 AS AmountDueToBA,
			0 AS AmountDueToBAUSD,
			0 AS AmountDueToBAEUR,
			- SUM (CASE WHEN b.bettype BETWEEN 31 AND 33 THEN b.winlost - b.actual_stake + awinlost + comm ELSE 0 END) AS AmountDueToRB,
			- SUM (CASE WHEN b.bettype BETWEEN 31 AND 33 THEN b.winlost - b.actual_stake + awinlost + comm ELSE 0 END * e.USD) AS AmountDueToRBUSD,
			- SUM (CASE WHEN b.bettype BETWEEN 31 AND 33 THEN b.winlost - b.actual_stake + awinlost + comm ELSE 0 END * e.EUR) AS AmountDueToRBEUR,
			0 AS CommBA,
			0 AS CommBAUSD,
			0 AS CommBAEUR,
			SUM (CASE WHEN b.bettype BETWEEN 31 AND 33 THEN b.comm ELSE 0 END ) AS CommRB,
			SUM (CASE WHEN b.bettype BETWEEN 31 AND 33 THEN b.comm ELSE 0 END * e.USD) AS CommRBUSD,
			SUM (CASE WHEN b.bettype BETWEEN 31 AND 33 THEN b.comm ELSE 0 END * e.EUR) AS CommRBEUR,
			SUM( b.PlayerComm )  AS PlayerComm ,
			SUM(PlayerComm *e.USD ) AS PlayerCommUSD ,
			SUM(PlayerComm *e.EUR ) AS PlayerCommEUR,
			SUM(CASE WHEN (@DrawFilter=2 AND b.statusid=111) THEN 0
				ELSE 1
				END) AS betcount
		FROM    
			Bettrans b WITH ( NOLOCK, INDEX = IX_srecommend)
			INNER JOIN @TempSAg a  ON b.srecommend = a.custid
			INNER JOIN @bettype bt ON b.bettype = bt.bettype
			LEFT JOIN  @Exchange e  ON e.ExchangeDate = b.winlostdate AND e.exchangeid = a.currency
		WHERE   
			winlostdate BETWEEN @TempFromDate AND @_ToDate
			AND b.statusID  IN (111, 112, 113)
		GROUP BY b.CustID,b.winlostdate,b.statusId
	END
	
	
END
IF @_FromDate <= @MoveBetsDay AND @IsOld = 0
BEGIN
	IF @_ToDate >= @MoveBetsDay
		SET @TempToDate = @MoveBetsDay
	ELSE
		SET  @TempToDate = @_ToDate
	
	IF @ShowBA = 1
	BEGIN
		INSERT  INTO #TempData
		SELECT  
			b.CustID ,
			b.winlostdate AS rptDate,
			b.statusId,
			SUM(CASE WHEN (@DrawFilter IN (2,3) AND b.statusid=111) THEN 0
				    ELSE b.turnover
					END
			) AS Turnover,
			SUM(CASE WHEN (@DrawFilter IN (2,3) AND b.statusid=111) THEN 0
					 ELSE b.turnover
					 END* e.USD
			) AS TurnoverUSD,
			SUM(CASE WHEN  (@DrawFilter in (2,3) AND b.statusid=111) THEN 0
					 ELSE b.turnover
					 END* e.EUR
			) AS TurnoverEUR,
			SUM(winlost) MemberWinlost,
			SUM(winlost * e.USD) MemberWinlostUSD,
			SUM(winlost * e.EUR) MemberWinlostEUR,
			SUM(ISNULL(BetEffective,0))  		AS BetEffective,
			SUM(ISNULL(BetEffective* e.USD,0))  AS BetEffectiveUSD,
			SUM(ISNULL(BetEffective* e.EUR,0))  AS BetEffectiveEUR,
			0 AS LicenseeWL,
			0 AS LicenseeWLUSD,
			0 AS LicenseeWLEUR,
			0 AS WinlossRB,
			0 AS WinlossRBUSD,
			0 AS WinlossRBEUR,
			- SUM (b.winlost+b.awinlost+b.comm) AS AmountDueToBA,
			- SUM ((b.winlost+b.awinlost+b.comm)*e.USD) AS AmountDueToBAUSD,
			- SUM ((b.winlost+b.awinlost+b.comm)*e.EUR) AS AmountDueToBAEUR,
			0 AS AmountDueToRB,
			0 AS AmountDueToRBUSD,
			0 AS AmountDueToRBEUR,
			SUM (comm ) AS CommBA,
			SUM (comm * e.USD) AS CommBAUSD,
			SUM (comm * e.EUR) AS CommBAEUR,
			0 AS CommRB,
			0 AS CommRBUSD,
			0 AS CommRBEUR,
			SUM( b.PlayerComm )  AS PlayerComm ,
			SUM(PlayerComm *e.USD ) AS PlayerCommUSD ,
			SUM(PlayerComm *e.EUR ) AS PlayerCommEUR,
			SUM(CASE WHEN (@DrawFilter IN (2) AND b.statusid=111) THEN 0
					 ELSE b.BetCount
					 END) AS betcount
		FROM    
			bodb_Licensee.dbo.rptLicWinloss2 b WITH ( NOLOCK )
			INNER JOIN @TempAg ag ON ag.custid = b.recommend
			LEFT JOIN @Exchange e  ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
		WHERE   
			Winlostdate BETWEEN @_FromDate AND @TempToDate
			AND roleID = 1
			AND b.statusID <> 101
			AND ISNULL(b.isBA,0) = 1
		GROUP BY b.CustID,b.winlostdate,b.statusId
	END
	
	
	--exclude BA tickets
	IF (@ShowSB=1 OR @ShowRB = 1 OR @ShowNG = 1 OR @ShowLC=1 OR @ShowVS=1 OR @ShowCS=1 OR @ShowBG=1 OR @ShowKN=1)
	BEGIN
		
		INSERT  INTO #TempData
		SELECT
			b.CustID ,
			b.winlostdate AS rptdate,
			b.statusId,
			SUM(CASE WHEN (@DrawFilter IN (2,3) AND b.statusid=111) THEN 0
					 ELSE b.turnover
					 END
			) AS Turnover,
			SUM(CASE WHEN (@DrawFilter IN (2,3) AND b.statusid=111) THEN 0
					 ELSE b.turnover
					 END* e.USD
			) AS TurnoverUSD,
			SUM(CASE WHEN (@DrawFilter IN (2,3) AND b.statusid=111) THEN 0
					ELSE b.turnover
					END* e.EUR
			) AS TurnoverEUR,
			SUM(winlost) MemberWinlost,
			SUM(winlost * e.USD) MemberWinlostUSD,
			SUM(winlost * e.EUR) MemberWinlostEUR,
			SUM(ISNULL(BetEffective,0))         AS BetEffective,
			SUM(ISNULL(BetEffective* e.USD,0))  AS BetEffectiveUSD,
			SUM(ISNULL(BetEffective* e.EUR,0))  AS BetEffectiveEUR,
			- SUM(CASE WHEN (b.sporttype <> 151)  THEN b.winlost ELSE 0 END) AS LicenseeWL ,
			- SUM((CASE WHEN (b.sporttype <> 151)  THEN b.winlost ELSE 0 END) * e.USD) AS LicenseeWLUSD ,
			- SUM((CASE WHEN (b.sporttype <> 151)  THEN b.winlost ELSE 0 END) * e.EUR) AS LicenseeWLEUR ,
			SUM(CASE WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END) AS WinlossRB,
			SUM((CASE WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END)*e.USD) AS WinlossRBUSD,
			SUM((CASE WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END)*e.EUR) AS WinlossRBEUR,
			0 AS AmountDueToBA,
			0 AS AmountDueToBAUSD,
			0 AS AmountDueToBAEUR,
			- SUM ( CASE WHEN b.sporttype = 151 THEN (b.winlost+b.awinlost+b.comm) ELSE 0 END) AS AmountDueToRB,
			- SUM (( CASE WHEN b.sporttype = 151 THEN (b.winlost+b.awinlost+b.comm) ELSE 0 END)*e.USD) AS AmountDueToRBUSD,
			- SUM (( CASE WHEN b.sporttype = 151 THEN (b.winlost+b.awinlost+b.comm) ELSE 0 END)*e.EUR) AS AmountDueToRBEUR,
			0 AS CommBA,
			0 AS CommBAUSD,
			0 AS CommBAEUR,
			SUM ( CASE WHEN b.sporttype = 151 THEN b.comm   ELSE 0 END) AS CommRB,
			SUM (( CASE WHEN b.sporttype = 151 THEN b.comm  ELSE 0 END)* e.USD) AS CommRBUSD,
			SUM (( CASE WHEN b.sporttype = 151 THEN b.comm  ELSE 0 END)* e.EUR) AS CommRBEUR,
			SUM( b.PlayerComm )  AS PlayerComm ,
			SUM(PlayerComm *e.USD ) AS PlayerCommUSD ,
			SUM(PlayerComm *e.EUR ) AS PlayerCommEUR,
			SUM(CASE WHEN (@DrawFilter IN (2) AND b.statusid=111) THEN 0
					 ELSE b.BetCount
					 END) as betcount
		FROM    
			bodb_Licensee.dbo.rptLicWinloss2 b WITH (NOLOCK)
			INNER JOIN @TempAg ag ON ag.custid = b.recommend
			INNER JOIN @sporttype t ON b.sporttype = t.sporttype
			LEFT JOIN @Exchange e  ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
		WHERE   
			Winlostdate BETWEEN @_FromDate AND @TempToDate
			AND roleID = 1
			AND ISNULL(b.isBA,0) = 0
			AND b.statusID <> 101 
		GROUP BY b.CustID,b.winlostdate,b.statusId
	END 
              
END    
ELSE IF @IsOld = 1
BEGIN
	IF @ShowBA = 1
	BEGIN
		INSERT  INTO #TempData
		SELECT  
			b.CustID ,
			b.winlostdate AS rptdate,
			b.statusId,
			SUM(CASE WHEN (@DrawFilter IN (2,3) AND b.statusid=111) THEN 0
					 ELSE b.turnover
					 END
			) AS Turnover,
			SUM(CASE WHEN (@DrawFilter IN (2,3) AND b.statusid=111) THEN 0
				ELSE b.turnover
				END*e.USD
			) AS TurnoverUSD,
			SUM(CASE WHEN (@DrawFilter IN (2,3) AND b.statusid=111) THEN 0
				ELSE b.turnover
				END*e.EUR
			) AS TurnoverEUR,
			SUM(winlost) MemberWinlost,
			SUM(winlost * e.USD) MemberWinlostUSD,
			SUM(winlost * e.EUR) MemberWinlostEUR,
			0 AS BetEffective,
			0 AS BetEffectiveUSD,
			0 AS BetEffectiveEUR,
			0 AS LicenseeWL,
			0 AS LicenseeWLUSD,
			0 AS LicenseeWLEUR,
			0 AS WinlossRB,
			0 AS WinlossRBUSD,
			0 AS WinlossRBEUR,
			- SUM (b.winlost+b.awinlost+b.comm) AS AmountDueToBA,
			- SUM ((b.winlost+b.awinlost+b.comm)*e.USD) AS AmountDueToBAUSD,
			- SUM ((b.winlost+b.awinlost+b.comm)*e.EUR) AS AmountDueToBAEUR,
			0 AS AmountDueToRB,
			0 AS AmountDueToRBUSD,
			0 AS AmountDueToRBEUR,
			SUM (comm ) AS CommBA,
			SUM (comm * e.USD) AS CommBAUSD,
			SUM (comm * e.EUR) AS CommBAEUR,
			0 AS CommRB,
			0 AS CommRBUSD,
			0 AS CommRBEUR,
			SUM( b.PlayerComm )  AS PlayerComm ,
			SUM(PlayerComm *e.USD ) AS PlayerCommUSD ,
			SUM(PlayerComm *e.EUR ) AS PlayerCommEUR,
			SUM(CASE WHEN (@DrawFilter IN (2) AND b.statusid=111) THEN 0
					 ELSE b.BetCount
					 END) AS betcount
		FROM    
			bodb_Licensee.dbo.rptLicWinloss_Old b WITH ( NOLOCK )
			INNER JOIN @TempAg ag ON ag.custid = b.recommend
			LEFT JOIN @Exchange e  ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
		WHERE   
			b.Winlostdate BETWEEN @_FromDate AND @_ToDate
			AND roleID = 1
			AND b.statusID <> 101 
			AND ISNULL(b.isBA,0) = 1
		GROUP BY b.CustID,b.winlostdate,b.statusId
	END
	
	IF (@showSB = 1 OR @ShowRB = 1 OR @ShowNG = 1 OR @ShowLC=1 OR @ShowVS=1 OR @ShowCS=1 OR @ShowBG=1 OR @ShowKN=1)
	BEGIN
		INSERT  INTO #TempData
		SELECT  
			b.CustID ,
			b.winlostdate AS rptdate,
			b.statusId,
			SUM(CASE WHEN (@DrawFilter IN (2,3) AND b.statusid=111) THEN  0
					 ELSE b.turnover
					END
			) AS Turnover,
			SUM(CASE WHEN (@DrawFilter IN (2,3) AND b.statusid=111) THEN 0
					 ELSE b.turnover
					END*e.USD
			) AS TurnoverUSD,
			SUM(CASE WHEN (@DrawFilter IN (2,3) AND b.statusid=111) THEN 0
					 ELSE b.turnover
					 END*e.EUR
			) AS TurnoverEUR,
			SUM(winlost) MemberWinlost,
			SUM(winlost * e.USD) MemberWinlostUSD,
			SUM(winlost * e.EUR) MemberWinlostEUR,
			0 AS BetEffective,
			0 AS BetEffectiveUSD,
			0 AS BetEffectiveEUR,
			- SUM(CASE WHEN (b.sporttype <> 151)   THEN b.winlost ELSE 0 END) AS LicenseeWL ,
			- SUM((CASE WHEN (b.sporttype <> 151)  THEN b.winlost ELSE 0 END) * e.USD) AS LicenseeWLUSD ,
			- SUM((CASE WHEN (b.sporttype <> 151)  THEN b.winlost ELSE 0 END) * e.EUR) AS LicenseeWLEUR ,
			SUM(CASE WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END) AS WinlossRB,
			SUM((CASE WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END)*e.USD) AS WinlossRBUSD,
			SUM((CASE WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END)*e.EUR) AS WinlossRBEUR,
			0 AS AmountDueToBA,
			0 AS AmountDueToBAUSD,
			0 AS AmountDueToBAEUR,
			- SUM ( CASE WHEN b.sporttype = 151 THEN (b.winlost+b.awinlost+b.comm) ELSE 0 END) AS AmountDueToRB,
			- SUM (( CASE WHEN b.sporttype = 151 THEN (b.winlost+b.awinlost+b.comm) ELSE 0 END)*e.USD) AS AmountDueToRBUSD,
			- SUM (( CASE WHEN b.sporttype = 151 THEN (b.winlost+b.awinlost+b.comm) ELSE 0 END)*e.EUR) AS AmountDueToRBEUR,
			0 AS CommBA,
			0 AS CommBAUSD,
			0 AS CommBAEUR,
			SUM ( CASE WHEN b.sporttype = 151 THEN b.comm  ELSE 0 END) AS CommRB,
			SUM (( CASE WHEN b.sporttype = 151 THEN b.comm  ELSE 0 END)* e.USD) AS CommRBUSD,
			SUM (( CASE WHEN b.sporttype = 151 THEN b.comm  ELSE 0 END)* e.EUR) AS CommRBEUR,
			SUM( b.PlayerComm )  AS PlayerComm ,
			SUM(PlayerComm *e.USD ) AS PlayerCommUSD ,
			SUM(PlayerComm *e.EUR ) AS PlayerCommEUR,
			SUM(CASE WHEN (@DrawFilter IN (2) AND b.statusid=111) THEN 0
					ELSE b.BetCount
				    END) AS betcount
		FROM    
			bodb_Licensee.dbo.rptLicWinloss_Old b WITH ( NOLOCK )
			INNER JOIN @TempAg ag ON ag.custid = b.recommend
			INNER JOIN @sporttype t ON b.sporttype = t.sporttype
			LEFT JOIN @Exchange e  ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
		WHERE   
			Winlostdate BETWEEN @_FromDate AND @_ToDate
			AND roleID = 1
			AND ISNULL(b.isBA,0) = 0
			AND b.statusID <> 101 
		GROUP BY b.CustID,b.winlostdate,b.statusId
	END
END

UPDATE #TempData
SET BetEffective = 0
	,BetEffectiveUSD = 0
	,BetEffectiveEUR = 0
WHERE (rptDate < @BetEffectiveDate 
	  OR statusID NOT IN (112,113,114,115)
	  )

INSERT INTO #TempCustIDFull (CustID)
SELECT DISTINCT b.CustID FROM #TempData b
INNER JOIN bodb_Licensee.dbo.licenseecustinfo c WITH ( NOLOCK ) ON b.CustID = c.CustID

INSERT INTO #TempCustID(CustID)
SELECT wl.CustID
FROM
(
		SELECT    
			w.CustID ,
			ROW_NUMBER() OVER ( ORDER BY w.CustID ) AS RowNum
		FROM      
			#TempCustIDFull w
		
) wl
WHERE wl.RowNum 	BETWEEN @RowStart AND @RowEnd 		


SELECT 
		w.CustID, 
		c.username,
		SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2)) AS nickname ,
		SUM(TurnOver)         AS TurnOver ,  
        SUM(TurnOverUSD)      AS TurnOverUSD ,  
        SUM(TurnOverEUR)      AS TurnOverEUR ,  
        SUM(MemberWinLost)    AS MemberWinLost ,
		SUM(MemberWinLostUSD) AS MemberWinLostUSD ,  
        SUM(MemberWinLostEUR) AS MemberWinLostEUR , 
		SUM(BetEffective)	  AS BetEffective,
		SUM(BetEffectiveUSD)  AS BetEffectiveUSD,
		SUM(BetEffectiveEUR)  AS BetEffectiveEUR,
        SUM(LicenseeWL)       AS LicenseeWL,  
        SUM(LicenseeWLUSD) 	  AS LicenseeWLUSD,  
        SUM(LicenseeWLEUR)    AS LicenseeWLEUR,  
        SUM(WinlossRB)        AS WinlossRB,  
        SUM(WinlossRBUSD)     AS WinlossRBUSD,  
        SUM(WinlossRBEUR)     AS WinlossRBEUR,  
        SUM(CommBA)           AS CommBA,  
        SUM(CommBAUSD)        AS CommBAUSD,  
        SUM(CommBAEUR)        AS CommBAEUR,  
        SUM(commRB)           AS commRB,  
        SUM(commRBUSD)        AS commRBUSD,  
        SUM(commRBEUR)        AS commRBEUR,  
		SUM(playerComm)       AS PlayerComm,  
		SUM(playerCommUSD)    AS PlayerCommUSD,  
		SUM(playerCommEUR)    AS PlayerCommEUR,  
        SUM(AmtDuetoBA)       AS AmtDuetoBA,  
        SUM(AmtDuetoBAUSD)    AS AmtDuetoBAUSD,  
        SUM(AmtDuetoBAEUR)    AS AmtDuetoBAEUR,  
        SUM(AmtDuetoRB)       AS AmtDuetoRB,  
        SUM(AmtDuetoRBUSD)    AS AmtDuetoRBUSD,  
        SUM(AmtDuetoRBEUR)    AS AmtDuetoRBEUR,
		SUM(w.betcount)       AS BetCount
FROM		
		#TempData w
		INNER JOIN #TempCustID t ON w.CustID = t.CustID
		INNER JOIN bodb_Licensee.dbo.licenseecustinfo c WITH ( NOLOCK ) ON t.CustID = c.CustID
GROUP BY w.CustID, c.username, c.username2  
		
DECLARE @TotalRow  INT 
SELECT @TotalRow= COUNT(DISTINCT b.custid)
FROM #TempData b
INNER JOIN bodb_Licensee.dbo.licenseecustinfo c WITH ( NOLOCK ) ON b.CustID = c.CustID

--- return data
SELECT  
	SUM(TurnOver) 								 AS SumTurnOver ,
    CAST(SUM(TurnOverUSD)		    AS MONEY)	 AS SumTurnOverUSD ,
    CAST(SUM(TurnOverEUR)           AS MONEY)	 AS SumTurnOverEUR ,
    SUM(MemberWinLost) 							 AS SumMemberWinLost ,
	SUM(BetEffective)						     AS SumBetEffective,
    CAST(SUM(MemberWinLostUSD)      AS MONEY)	 AS SumMemberWinLostUSD ,
	CAST(SUM(BetEffectiveUSD)       AS MONEY)	 AS SumBetEffectiveUSD ,
	CAST(SUM(MemberWinLostEUR)      AS MONEY)	 AS SumMemberWinLostEUR,
	CAST(SUM(BetEffectiveEUR) 		AS MONEY)	 AS SumBetEffectiveEUR  ,
    SUM(LicenseeWL) 							 AS SumLicenseeWL,
    CAST(SUM(LicenseeWLUSD) 	    AS MONEY)	 AS SumLicenseeWLUSD,
    CAST(SUM(LicenseeWLEUR)         AS MONEY)	 AS SumLicenseeWLEUR,
	SUM(WinlossRB) 								 AS SumWinlossRB,
    CAST(SUM(WinlossRBUSD) 	        AS MONEY)	 AS SumWinlossRBUSD,
    CAST(SUM(WinlossRBEUR)          AS MONEY)	 AS SumWinlossRBEUR,
    SUM(CommBA) 								 AS SumCommBA,
    CAST(SUM(CommBAUSD) 		    AS MONEY)	 AS SumCommBAUSD,
    CAST(SUM(CommBAEUR) 		    AS MONEY)	 AS SumCommBAEUR,
    SUM(commRB) 								 AS SumcommRB,
    CAST(SUM(commRBUSD) 		    AS MONEY)	 AS SumcommRBUSD,
    CAST(SUM(commRBEUR) 		    AS MONEY)	 AS SumcommRBEUR,
	SUM(PlayerComm)       						 AS SumPlayerComm,
	CAST(SUM(PlayerCommUSD)         AS MONEY)	 AS SumPlayerCommUSD,
	CAST(SUM(PlayerCommEUR)      	AS MONEY)	 AS SumPlayerCommEUR,
    SUM(AmtDuetoBA) 				    		 AS SumAmtDuetoBA,
    CAST(SUM(AmtDuetoBAUSD)         AS MONEY)	 AS SumAmtDuetoBAUSD,
    CAST(SUM(AmtDuetoBAEUR)         AS MONEY)	 AS SumAmtDuetoBAEUR,
    SUM(AmtDuetoRB)		 						 AS SumAmtDuetoRB,
    CAST(SUM(AmtDuetoRBUSD)         AS MONEY)	 AS SumAmtDuetoRBUSD,
    CAST(SUM(AmtDuetoRBEUR)         AS MONEY)	 AS SumAmtDuetoRBEUR,
    @TotalRow 									 AS TotalRows,
	SUM(b.betcount) 							 AS SumBetCount
	
FROM  #TempData b
	INNER JOIN bodb_Licensee.dbo.licenseecustinfo c WITH ( NOLOCK ) ON b.CustID = c.CustID
--DROP TABLE #tmpreturn
DROP TABLE #TempData    
DROP TABLE #TempCustID
DROP TABLE #TempCustIDFull
GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_WinLoss] TO [bodbLicenseeNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_WinLoss] TO [vnteam] AS [dbo]

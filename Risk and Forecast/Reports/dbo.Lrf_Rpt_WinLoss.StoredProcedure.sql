
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
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
	@ShowMGC BIT=0,
	@ShowBT BIT=0,
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
		- 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
		- 20141225@Jim: improve performance
		- 20150129@Jim : add base on curreny GBP
		- 20150612@Jim: support MicroGaming
		- 20150625@Winnie: support BetTrade
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
DECLARE @TempAg AS TABLE ( CustId INT,Currency INT)
 
DECLARE @bettype AS TABLE (bettype INT PRIMARY KEY)
DECLARE @sporttype TABLE(sporttype INT)
DECLARE @Exchange AS TABLE (
							ExchangeDate SMALLDATETIME
							,ExchangeId INT
							,MYR FLOAT
							,USD FLOAT
							,EUR FLOAT
							,GBP FLOAT
							,PRIMARY KEY(ExchangeDate,ExchangeId)
							)
						
 
SELECT @_FromDate = @FromDate
	   ,@_ToDate = @ToDate
	   ,@BetEffectiveDate = '2014-09-01'
SELECT  @PageIndex = @PageIndex - 1 
        ,@RowStart = @PageSize * @PageIndex + 1 
        ,@RowEnd = @RowStart + @PageSize - 1
SELECT @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120) 
SELECT  currencyID,LicenseeID 
	    INTO #currency
FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)
WHERE (@CurrencyID=0  OR (@CurrencyID<>0 AND CurrencyID=@CurrencyID))

INSERT  INTO @TempAg(CustId,Currency)
SELECT  CustID
		,Currency
FROM bodb_licensee.dbo.f_SelLicenseeCust (@LicenseeID) lc  
	INNER JOIN #Currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID

INSERT INTO @Exchange (ExchangeDate,ExchangeId,MYR,USD,EUR,GBP)
SELECT 
	ExchangeDate
	,ExchangeId
	,MYR
	,USD
	,EUR
	,GBP
FROM Lrf_f_GetExchangeDaily(@_FromDate,@_ToDate)
WHERE exchangeid IN (SELECT DISTINCT CurrencyID FROM #Currency)

DROP TABLE #Currency 

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

IF @ShowMGC=1 -- MicroGamming
BEGIN 
	INSERT INTO @sporttype (sporttype)
	VALUES(203)

	INSERT INTO @bettype(bettype)
	SELECT typeid FROM bettype (NOLOCK)
	WHERE (typeid BETWEEN 2001 AND 2007)
END


CREATE TABLE #TempData
(
	CustID INT 
	,rptDate DATETIME
	,TurnOver MONEY 
	,MemberWinLost MONEY 
	,BetEffective	 MONEY
	,LicenseeWL		MONEY
	,WinlossRB		MONEY
	,AmtDueToBA	MONEY
	,AmtDueToRB	MONEY
	,CommBA		MONEY
	,CommRB		MONEY
	,PlayerComm  MONEY 
	,betcount int	
	,currency int	
)
CREATE TABLE #TempCustID
(
	CustID INT PRIMARY KEY
	,UserName VARCHAR(50)
	,UserName2 VARCHAR(50)
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
			SUM(CASE WHEN (@DrawFilter IN (2,3) AND b.statusid=111) THEN 0
					 ELSE stake
				END
			) AS Turnover ,
			SUM(winlost - actual_stake) AS MemberWinlost ,
			SUM(ABS(winlost - actual_stake)) AS BetEffective ,
			0 AS LicenseeWL,
			0 AS WinlossRB,
			- SUM (b.winlost - b.actual_stake + awinlost + comm ) AS AmountDueToBA,
			0 AS AmountDueToRB,
			SUM (comm) AS CommBA,
			0 AS CommRB,
			SUM(PlayerComm  ) AS PlayerComm ,
			SUM(CASE WHEN (@DrawFilter =2 AND b.statusid=111) THEN 0
					 ELSE 1
				END) AS betcount,
			b.currency	
		FROM    
			bettrans b WITH (NOLOCK)   
			INNER JOIN  @TempAg ag ON  b.recommend = ag.CustId 
		WHERE transid IN (SELECT transid FROM bodb_Licensee.dbo.LicenseeBATransaction_active WITH (NOLOCK) )
			AND winlostdate BETWEEN @TempFromDate AND @_ToDate
			AND b.currency IN (SELECT Currency FROM @TempAg)
			AND b.statusID  IN (111, 112, 113)
			and bettype < 19999
			AND ((@ShowBT=1 AND b.bettype<>903) OR (@ShowBT=0 AND b.bettype NOT IN (901,902,903)))
		GROUP BY b.CustID,b.winlostdate,b.currency	
	END

	IF (@ShowSB=1)
	BEGIN
		INSERT INTO #TempData
		SELECT  
			b.CustID ,
			b.winlostdate,
			SUM(CASE WHEN (@DrawFilter IN (2,3) AND b.statusid=111) THEN 0
					 ELSE stake
				END
			) AS Turnover,
			SUM(winlost - actual_stake) AS MemberWinlost ,
			SUM(ABS(winlost - actual_stake)) AS BetEffective,
			- SUM(b.winlost - b.actual_stake) AS LicenseeWL,
			0 AS WinlossRB,
			0 AS AmountDueToBA,
			0 AS AmountDueToRB,
			0 AS CommBA,
			0 AS CommRB,
			SUM( b.PlayerComm )  AS PlayerComm ,
			SUM(CASE WHEN (@DrawFilter =2 AND b.statusid=111) THEN 0					 
				ELSE 1
				END) AS betcount,
			b.currency	
		FROM    
			Bettrans b WITH ( NOLOCK)
			INNER JOIN @TempAg a ON b.recommend = a.custid  
		WHERE   
			winlostdate BETWEEN @TempFromDate AND @_ToDate
			AND (b.bettype<31 OR (b.bettype BETWEEN 121 AND 999)
							  OR (b.Bettype BETWEEN 1301 AND 1399) 
			)
			AND b.currency IN (SELECT Currency FROM @TempAg)
			AND b.statusID  IN (111, 112, 113)
			AND b.tpositiontaking <>0
			AND ((@ShowBT=1 AND b.bettype<>903) OR (@ShowBT=0 AND b.bettype NOT IN (901,902,903)))
		GROUP BY b.CustID,b.winlostdate,b.currency	 
	END

	IF (@ShowNG = 1 OR @ShowLC=1 OR @ShowVS=1 OR @ShowRB=1 OR @ShowCS=1 OR @ShowBG=1 OR @ShowKN=1 OR @ShowMGC=1)
	BEGIN
		INSERT INTO #TempData
		SELECT  
			b.CustID ,
			b.winlostdate,
			SUM(CASE WHEN (@DrawFilter IN (2,3) AND b.statusid=111) THEN 0
					 ELSE 
					 CASE WHEN b.liveawayscore = 0 AND b.bettype IN ( 33, 43 ) THEN b.stake / 2 ELSE b.stake END
				END
			) AS Turnover ,
			SUM(winlost - actual_stake) AS MemberWinlost ,
			SUM(ABS(winlost - actual_stake)) AS BetEffective,
			- SUM(CASE WHEN b.bettype NOT BETWEEN 31 AND 33 THEN b.winlost - b.actual_stake ELSE 0 END) AS LicenseeWL,
			SUM (CASE WHEN b.bettype BETWEEN 31 AND 33 THEN b.awinlost ELSE 0 END) AS WinlossRB,
			0 AS AmountDueToBA,
			- SUM (CASE WHEN b.bettype BETWEEN 31 AND 33 THEN b.winlost - b.actual_stake + awinlost + comm ELSE 0 END) AS AmountDueToRB,
			0 AS CommBA,
			SUM (CASE WHEN b.bettype BETWEEN 31 AND 33 THEN b.comm ELSE 0 END ) AS CommRB,
			SUM( b.PlayerComm )  AS PlayerComm ,
			SUM(CASE WHEN (@DrawFilter=2 AND b.statusid=111) THEN 0
				ELSE 1
				END) AS betcount,
			b.currency	
		FROM    
			Bettrans b WITH ( NOLOCK )
			INNER JOIN @TempAg a  ON b.recommend = a.custid  
			INNER JOIN @bettype bt ON b.bettype = bt.bettype
			 
		WHERE   
			winlostdate BETWEEN @TempFromDate AND @_ToDate
			AND b.currency IN (SELECT Currency FROM @TempAg)
			AND b.statusID  IN (111, 112, 113)			
		GROUP BY b.CustID,b.winlostdate,b.currency	
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
			SUM(CASE WHEN (@DrawFilter IN (2,3) AND b.statusid=111) THEN 0
				    ELSE b.turnover
					END
			) AS Turnover,
			SUM(winlost) MemberWinlost,
			CASE WHEN winlostdate < @BetEffectiveDate  THEN  0 ELSE SUM(ISNULL(BetEffective,0))  END    AS BetEffective,
			0 AS LicenseeWL,
			0 AS WinlossRB,
			- SUM (b.winlost+b.awinlost+b.comm) AS AmountDueToBA,
			0 AS AmountDueToRB,
			SUM (comm ) AS CommBA,
			0 AS CommRB,
			SUM( b.PlayerComm )  AS PlayerComm ,
			SUM(CASE WHEN (@DrawFilter IN (2) AND b.statusid=111) THEN 0
					 ELSE b.BetCount
					 END) AS betcount,
			b.currency		 
		FROM    
			bodb_Licensee.dbo.rptLicWinloss2 b WITH ( NOLOCK)
			INNER JOIN @TempAg ag ON ag.custid = b.recommend   AND b.Currency = ag.Currency
		WHERE   
			Winlostdate BETWEEN @_FromDate AND @TempToDate
			AND roleID = 1
			AND b.statusID <> 101
			AND ISNULL(b.isBA,0) = 1
			AND ((@ShowBT=1 AND b.bettype<>903) OR (@ShowBT=0 AND b.bettype NOT IN (901,902,903)))
		GROUP BY b.CustID,b.winlostdate,b.currency	
	END
	
	
	--exclude BA tickets
	IF (@ShowSB=1 OR @ShowRB = 1 OR @ShowNG = 1 OR @ShowLC=1 OR @ShowVS=1 OR @ShowCS=1 OR @ShowBG=1 OR @ShowKN=1 OR @ShowMGC=1)
	BEGIN
		
		INSERT  INTO #TempData
		SELECT
			b.CustID ,
			b.winlostdate AS rptdate,
			SUM(CASE WHEN (@DrawFilter IN (2,3) AND b.statusid=111) THEN 0
					 ELSE b.turnover
					 END
			) AS Turnover,
			SUM(winlost) MemberWinlost,
			CASE WHEN winlostdate < @BetEffectiveDate  THEN 0 ELSE  SUM(ISNULL(BetEffective,0)) END    AS BetEffective,
			- SUM(CASE WHEN (b.sporttype <> 151)  THEN b.winlost ELSE 0 END) AS LicenseeWL ,
			SUM(CASE WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END) AS WinlossRB,
			0 AS AmountDueToBA,
			- SUM ( CASE WHEN b.sporttype = 151 THEN (b.winlost+b.awinlost+b.comm) ELSE 0 END) AS AmountDueToRB,
			0 AS CommBA,
			SUM ( CASE WHEN b.sporttype = 151 THEN b.comm   ELSE 0 END) AS CommRB,
			SUM( b.PlayerComm )  AS PlayerComm ,
			SUM(CASE WHEN (@DrawFilter IN (2) AND b.statusid=111) THEN 0
					 ELSE b.BetCount
					 END) as betcount,
			b.currency		 
		FROM    
			bodb_Licensee.dbo.rptLicWinloss2 b WITH (NOLOCK)
			INNER JOIN @TempAg ag ON ag.custid = b.recommend  AND b.Currency = ag.Currency
			INNER JOIN @sporttype t ON b.sporttype = t.sporttype
		WHERE   
			Winlostdate BETWEEN @_FromDate AND @TempToDate
			AND roleID = 1
			AND ISNULL(b.isBA,0) = 0
			AND b.statusID <> 101 
			AND ((@ShowBT=1 AND b.bettype<>903) OR (@ShowBT=0 AND b.bettype NOT IN (901,902,903)))
		GROUP BY b.CustID,b.winlostdate,b.currency	
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
			SUM(CASE WHEN (@DrawFilter IN (2,3) AND b.statusid=111) THEN 0
					 ELSE b.turnover
					 END
			) AS Turnover,
			SUM(winlost) MemberWinlost,
			0 AS BetEffective,
			0 AS LicenseeWL,
			0 AS WinlossRB,
			- SUM (b.winlost+b.awinlost+b.comm) AS AmountDueToBA,
			0 AS AmountDueToRB,
			SUM (comm ) AS CommBA,
			0 AS CommRB,
			SUM( b.PlayerComm )  AS PlayerComm ,
			SUM(CASE WHEN (@DrawFilter IN (2) AND b.statusid=111) THEN 0
					 ELSE b.BetCount
					 END) AS betcount,
			b.currency			 
		FROM    
			bodb_Licensee.dbo.rptLicWinloss_Old b WITH ( NOLOCK )
			INNER JOIN @TempAg ag ON ag.custid = b.recommend  
			 
		WHERE   
			b.Winlostdate BETWEEN @_FromDate AND @_ToDate
			AND roleID = 1
			AND b.statusID <> 101 
			AND ISNULL(b.isBA,0) = 1
			AND b.currency IN (SELECT Currency FROM @TempAg)
			AND ((@ShowBT=1 AND b.bettype<>903) OR (@ShowBT=0 AND b.bettype NOT IN (901,902,903)))
		GROUP BY b.CustID,b.winlostdate,b.currency	
	END
	
	IF (@showSB = 1 OR @ShowRB = 1 OR @ShowNG = 1 OR @ShowLC=1 OR @ShowVS=1 OR @ShowCS=1 OR @ShowBG=1 OR @ShowKN=1 OR @ShowMGC=1)
	BEGIN
		INSERT  INTO #TempData
		SELECT  
			b.CustID ,
			b.winlostdate AS rptdate,
			SUM(CASE WHEN (@DrawFilter IN (2,3) AND b.statusid=111) THEN  0
					 ELSE b.turnover
					END
			) AS Turnover,
			SUM(winlost) MemberWinlost,
			0 AS BetEffective,
			- SUM(CASE WHEN (b.sporttype <> 151)   THEN b.winlost ELSE 0 END) AS LicenseeWL ,
			SUM(CASE WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END) AS WinlossRB,
			0 AS AmountDueToBA,
			- SUM ( CASE WHEN b.sporttype = 151 THEN (b.winlost+b.awinlost+b.comm) ELSE 0 END) AS AmountDueToRB,
			0 AS CommBA,
			SUM ( CASE WHEN b.sporttype = 151 THEN b.comm  ELSE 0 END) AS CommRB,
			SUM( b.PlayerComm )  AS PlayerComm ,
			SUM(CASE WHEN (@DrawFilter IN (2) AND b.statusid=111) THEN 0
					ELSE b.BetCount
				    END) AS betcount,
			b.currency			
		FROM    
			bodb_Licensee.dbo.rptLicWinloss_Old b WITH ( NOLOCK )
			INNER JOIN @TempAg ag ON ag.custid = b.recommend AND b.Currency = ag.Currency
			INNER JOIN @sporttype t ON b.sporttype = t.sporttype
		WHERE   
			Winlostdate BETWEEN @_FromDate AND @_ToDate
			AND roleID = 1
			AND ISNULL(b.isBA,0) = 0
			AND b.statusID <> 101 
			AND ((@ShowBT=1 AND b.bettype<>903) OR (@ShowBT=0 AND b.bettype NOT IN (901,902,903)))
		GROUP BY b.CustID,b.winlostdate,b.currency	
	END
END

INSERT INTO #TempCustIDFull (CustID)
SELECT DISTINCT b.CustID 
FROM #TempData b

INSERT INTO #TempCustID(CustID,UserName,UserName2)
SELECT wl.CustID,
	  wl.username,
      wl.nickname
FROM
(
		SELECT    
			w.CustID ,
			c.username,
			SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2)) AS nickname ,
			ROW_NUMBER() OVER ( ORDER BY w.CustID ) AS RowNum
		FROM      
			#TempCustIDFull w
			INNER JOIN bodb_Licensee.dbo.licenseecustinfo c WITH ( NOLOCK ) ON w.CustID = c.CustID
		
) wl
WHERE wl.RowNum 	BETWEEN @RowStart AND @RowEnd 
		
 SELECT w.*
		,t.username
		,t.UserName2
 INTO #tmpDataDetail
 FROM #TempData w
	  INNER JOIN #TempCustID t ON w.CustID = t.CustID
 
CREATE NONCLUSTERED INDEX IDX_Index_Data ON #tmpDataDetail(rptdate,currency)
SELECT 
		w.CustID, 
		w.username,
		w.UserName2 as nickname ,
		SUM(TurnOver)         AS TurnOver ,  
        SUM(TurnOver*e.USD)      AS TurnOverUSD ,  
        SUM(TurnOver*e.EUR)      AS TurnOverEUR ,  
		SUM(TurnOver*e.GBP)      AS TurnOverGBP , 
        SUM(MemberWinLost)    AS MemberWinLost ,
		SUM(MemberWinLost*e.USD) AS MemberWinLostUSD ,  
        SUM(MemberWinLost*e.EUR) AS MemberWinLostEUR , 
		SUM(MemberWinLost*e.GBP) AS MemberWinLostGBP , 
		SUM(BetEffective)	  AS BetEffective,
		SUM(BetEffective*e.USD)  AS BetEffectiveUSD,
		SUM(BetEffective*e.EUR)  AS BetEffectiveEUR,
		SUM(BetEffective*e.GBP)  AS BetEffectiveGBP,
        SUM(LicenseeWL)       AS LicenseeWL,  
        SUM(LicenseeWL*e.USD) 	  AS LicenseeWLUSD,  
        SUM(LicenseeWL*e.EUR)    AS LicenseeWLEUR,  
		SUM(LicenseeWL*e.GBP)    AS LicenseeWLGBP,  
        SUM(WinlossRB)        AS WinlossRB,  
        SUM(WinlossRB*e.USD)     AS WinlossRBUSD,  
        SUM(WinlossRB*e.EUR)     AS WinlossRBEUR,  
		SUM(WinlossRB*e.GBP)     AS WinlossRBGBP,
        SUM(CommBA)           AS CommBA,  
        SUM(CommBA*e.USD)        AS CommBAUSD,  
        SUM(CommBA*e.EUR)        AS CommBAEUR,  
		SUM(CommBA*e.GBP)        AS CommBAGBP,
        SUM(commRB)           AS commRB,  
        SUM(commRB*e.USD)        AS commRBUSD,  
        SUM(commRB*e.EUR)        AS commRBEUR,  
		SUM(commRB*e.GBP)        AS commRBGBP,
		SUM(playerComm)       AS PlayerComm,  
		SUM(playerComm*e.USD)    AS PlayerCommUSD,  
		SUM(playerComm*e.EUR)    AS PlayerCommEUR,  
		SUM(playerComm*e.GBP)    AS PlayerCommGBP,
        SUM(AmtDuetoBA)       AS AmtDuetoBA,  
        SUM(AmtDuetoBA*e.USD)    AS AmtDuetoBAUSD,  
        SUM(AmtDuetoBA*e.EUR)    AS AmtDuetoBAEUR,  
		SUM(AmtDuetoBA*e.GBP)    AS AmtDuetoBAGBP,
        SUM(AmtDuetoRB)       AS AmtDuetoRB,  
        SUM(AmtDuetoRB*e.USD)    AS AmtDuetoRBUSD,  
        SUM(AmtDuetoRB*e.EUR)    AS AmtDuetoRBEUR,
		SUM(AmtDuetoRB*e.GBP)    AS AmtDuetoRBGBP,
		SUM(w.betcount)       AS BetCount
FROM		
		#tmpDataDetail w
		LEFT JOIN @Exchange e  ON e.ExchangeDate = w.rptdate AND e.exchangeid = w.currency
GROUP BY w.CustID,w.username,w.UserName2
		
DECLARE @TotalRow  INT 
SELECT @TotalRow= COUNT(DISTINCT b.custid)
FROM #TempData b
 
--- return data
SELECT  
	SUM(TurnOver) 								 AS SumTurnOver ,
    CAST(SUM(TurnOver*e.USD)		    AS MONEY)	 AS SumTurnOverUSD ,
    CAST(SUM(TurnOver*e.EUR)           AS MONEY)	 AS SumTurnOverEUR ,
	CAST(SUM(TurnOver*e.GBP)           AS MONEY)	 AS SumTurnOverGBP ,
    SUM(MemberWinLost) 							 AS SumMemberWinLost ,
	SUM(BetEffective)						     AS SumBetEffective,
    CAST(SUM(MemberWinLost*e.USD)      AS MONEY)	 AS SumMemberWinLostUSD ,
	CAST(SUM(BetEffective*e.USD)       AS MONEY)	 AS SumBetEffectiveUSD ,
	CAST(SUM(MemberWinLost*e.EUR)      AS MONEY)	 AS SumMemberWinLostEUR,
	CAST(SUM(BetEffective*e.EUR) 		AS MONEY)	 AS SumBetEffectiveEUR  ,
	CAST(SUM(MemberWinLost*e.GBP)      AS MONEY)	 AS SumMemberWinLostGBP,
	CAST(SUM(BetEffective*e.GBP) 		AS MONEY)	 AS SumBetEffectiveGBP,
	SUM(LicenseeWL) 							 AS SumLicenseeWL,
    CAST(SUM(LicenseeWL*e.USD) 	    AS MONEY)	 AS SumLicenseeWLUSD,
    CAST(SUM(LicenseeWL*e.EUR)         AS MONEY)	 AS SumLicenseeWLEUR,
	CAST(SUM(LicenseeWL*e.GBP)         AS MONEY)	 AS SumLicenseeWLGBP,
	SUM(WinlossRB) 								 AS SumWinlossRB,
    CAST(SUM(WinlossRB*e.USD) 	        AS MONEY)	 AS SumWinlossRBUSD,
    CAST(SUM(WinlossRB*e.EUR)          AS MONEY)	 AS SumWinlossRBEUR,
	CAST(SUM(WinlossRB*e.GBP)          AS MONEY)	 AS SumWinlossRBGBP,
    SUM(CommBA) 								 AS SumCommBA,
    CAST(SUM(CommBA*e.USD) 		    AS MONEY)	 AS SumCommBAUSD,
    CAST(SUM(CommBA*e.EUR) 		    AS MONEY)	 AS SumCommBAEUR,
	CAST(SUM(CommBA*e.GBP) 		    AS MONEY)	 AS SumCommBAGBP,
    SUM(commRB) 								 AS SumcommRB,
    CAST(SUM(commRB*e.USD) 		    AS MONEY)	 AS SumcommRBUSD,
    CAST(SUM(commRB*e.EUR) 		    AS MONEY)	 AS SumcommRBEUR,
	CAST(SUM(commRB*e.GBP) 		    AS MONEY)	 AS SumcommRBGBP,
	SUM(PlayerComm)       						 AS SumPlayerComm,
	CAST(SUM(PlayerComm*e.USD)         AS MONEY)	 AS SumPlayerCommUSD,
	CAST(SUM(PlayerComm*e.EUR)      	AS MONEY)	 AS SumPlayerCommEUR,
	CAST(SUM(PlayerComm*e.GBP)      	AS MONEY)	 AS SumPlayerCommGBP,
    SUM(AmtDuetoBA) 				    		 AS SumAmtDuetoBA,
    CAST(SUM(AmtDuetoBA*e.USD)         AS MONEY)	 AS SumAmtDuetoBAUSD,
    CAST(SUM(AmtDuetoBA*e.EUR)         AS MONEY)	 AS SumAmtDuetoBAEUR,
	CAST(SUM(AmtDuetoBA*e.GBP)         AS MONEY)	 AS SumAmtDuetoBAGBP,
    SUM(AmtDuetoRB)		 						 AS SumAmtDuetoRB,
    CAST(SUM(AmtDuetoRB*e.USD)         AS MONEY)	 AS SumAmtDuetoRBUSD,
    CAST(SUM(AmtDuetoRB*e.EUR)         AS MONEY)	 AS SumAmtDuetoRBEUR,
	CAST(SUM(AmtDuetoRB*e.GBP)         AS MONEY)	 AS SumAmtDuetoRBGBP,
    @TotalRow 									 AS TotalRows,
	SUM(b.betcount) 							 AS SumBetCount
	
FROM  #TempData b
	LEFT JOIN @Exchange e  ON e.ExchangeDate = b.rptdate AND e.exchangeid = b.currency
--DROP TABLE #tmpreturn
DROP TABLE #TempData    
DROP TABLE #tmpDataDetail
DROP TABLE #TempCustID
DROP TABLE #TempCustIDFull
GO 
 GRANT EXECUTE ON [dbo].[Lrf_Rpt_WinLoss] TO [vnteam]
GO 
 GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_WinLoss] TO [vnteam]
GO 
 GRANT EXECUTE ON [dbo].[Lrf_Rpt_WinLoss] TO [bodbLicenseeNet]
GO 

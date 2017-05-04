USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_Rpt_WinlossByProduct_xpre]    Script Date: 01/31/2015 09:25:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Lrf_Rpt_WinlossByProduct]  
 @UserName		VARCHAR(50) = NULL,
 @FromDate		SMALLDATETIME,  
 @ToDate		SMALLDATETIME,   
 @showSB		BIT=0,  
 @ShowRB		BIT=0,  
 @ShowNG		BIT=0, 
 @ShowBA		BIT=0,
 @ShowLC		BIT=0,
 @ShowVS		BIT=0,
 @ShowCS  		BIT=0, -- RNG Casino
 @ShowBG   		BIT=0, -- Bingo 
 @ShowKN   		BIT=0, -- Keno
 @ShowMGCLC 	BIT=0,-- MicroGamming
 @ShowMGCRnG 	BIT=0,-- MicroGamming
 @ShowVB		BIT=0,-- Voidbridge
 @ReportType	TINYINT=1,  
 @MoveBetsDay	SMALLDATETIME,
 @IsOld			BIT = 0,
 @drawfilter	SMALLINT = 1  ,
 @CustID		INT =0 OUTPUT,
 @AgentList		VARCHAR(MAX),
 @SystemName	VARCHAR(50)='' OUTPUT,
 @ErrCode		TINYINT = 0OUTPUT,
 @ErrMsg		VARCHAR(400)='' OUTPUT
 WITH RECOMPILE
AS    
/*  Created: Henry  
	Date: 2011-07-06
	Task : Winloss By Product Report for Licensee 
	DB: DB052.bodb02  
   
	Revisions:  
	- 20111013@Henry: change to use rptLicWinloss2
	- 20111208@Jim: change bettype condition
	- 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily  	
	- 20120529@henry: enhance performance
	- 20120730@Jim: Add Playercomm Value 
	- 20120814@Henry: add live casino
	- 20120905@Jim:add virtual sport	
	- 20121004@Jim: replace @currency input param by @currencyID
	- 20121115@Henry: Only Sportsbook needs to exclude BA
	- 20121128@Henry: use new table LicenseeBATransaction_active to get bettrans BA tickets
	- 20130222@Jim: support RNG Casino ,Bingo
	- 20130417@Jim: add more product code value in the result 
	- 20130514@Jim: Restrict permission of Licensee Users by currency
	- 20130809@Jim: offer Virtual Horse Racing
	- 20131007@Jim: offer Virtual Tennis	
	- 20131213@Jim: support to Display win loss of individual sports with Virtual Sports
	- 20140304@Florent: offer Keno
	- 20140620@Florent: offer 14 new bettypes and Sporting Solution (36 new bettypes)
	- 20140915@Florent: hotfix duplicated VS bettype
	- 20141111@Jim: changing currency for KeenOcean member  (#Redmine 25673)
	- 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
	- 20141229@Winnie: optimize performance 
	- 20150106@Jim: add more UserName filter
	- 20150123@Jim: support base on Currency GBP
	- 20150612@Jim: support MicroGaming
	- 20150623@Winnie: exclude 3 transactions SOLD/BOUGHT/BetTrade Commission
	- 20151001@Jim: remove MicroGaming
	- 20151228@Bobby: Support MBC RNG Casino sporttype(208,209,210)	
	- 20160331@Walter: Support Voidbridge single wallet [Redmine: #55057]
	- 20160413@Victor: support MKK currency code [Redmine: #55745]
	- 20160727@Jim:  LRF - Commercial terms changed for Bet Trade [Redmine: #61342]
	- 20161022@Jim:move table to bodb_licenseereport [RedmineID :#60449]
	- 20170227@Harper: LRF - Get data by @AgentList instead of @UserID [RedmineID: #71679]
	- 20170327@Paul: Implement Cash Out [RedmineID :#71727]

	Param's Explanation:  
	  + @ReportType: 1-Daily; 2-Monthly;  
	  +	@drawfilter: 'No Draw' filter is supportted (1:Normal 2:No Draw 3:No Draw for Turnover only)
	  + @IsOld: 0 - query in table rptLicWinloss, 1 - query in table rptLicWinloss_old. 
	  + @excludeTest: remove currency UUS
	  + @showSB: Show SportsBook bets
	  + @ShowRB: Show RB bets
	  + @ShowNG: Show Number game bets
	  + @ShowBA: Show Bet Aggregator bets (combined with Sportsbook or Number Game)
	  + @ShowLC: Show Live Casino bets
	  +	@ShowVS: Show Virual Sport bets	
	  + @MoveBetsDay: The day we move tickets to bettrans14
	  + @AgentList: xml structure
					  <ROOT>
					   <Agent AgentId="12345" Currency="3"/>  
					   <Agent AgentId="12345" Currency="5"/>  
					  </ROOT> 
*/  
BEGIN  
SET NOCOUNT ON  

CREATE TABLE #SAgWinLoss (  
	winlostdate		DATETIME,  
	Currency		INT,
	ProductCode		VARCHAR(10),
	TurnOver		MONEY,   	
	Winlost			MONEY,  
	LicenseeWL		MONEY, 
	Comm			MONEY,  
	PlayerComm 		MONEY, 	
	AmtDueTo3rd		MONEY,
	Betcount		BIGINT
)  

DECLARE @VNDCurrencyName VARCHAR(20)
DECLARE @bettype AS TABLE (bettype INT PRIMARY KEY)
DECLARE @sporttype TABLE(sporttype INT)
DECLARE @sumTurnOver BIT
DECLARE @sumBetCount BIT
DECLARE  @RCount INT
		
SET @sumTurnOver=1
SET @sumBetCount=1
IF(@drawfilter=2)
BEGIN
SET @sumTurnOver=0
SET @sumBetCount=0
END
IF(@drawfilter=3)
BEGIN
SET @sumTurnOver=0
END

SELECT @VNDCurrencyName = Currency FROM exchange (NOLOCK) WHERE ExchangeId = 51

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

SET @UserName = ISNULL(@UserName,'')
IF LEN(@UserName) = 0
	SET @CustID = 0
ELSE 
	BEGIN 
		SET @UserName = LTRIM(RTRIM(@UserName))
		
		SELECT c.CustID
			   ,c.username		
			INTO #tblCust
		FROM bodb_Licensee.dbo.LicenseeCustinfo c WITH (NOLOCK) 
			INNER JOIN @TempAg t ON c.recommend = t.custid
		WHERE 
			(c.username2 LIKE + '%$' + @Username  OR c.username = @Username)
		SELECT @RCount = @@ROWCOUNT
		
		IF @RCount < 1
			BEGIN
				SELECT @ErrCode = 100
						   ,@ErrMsg = 'No customer found'	
					RETURN;	   
			END
		ELSE IF	@RCount > 1
				BEGIN
				IF (SELECT COUNT(1) FROM #tblCust) <> 1	
					SELECT @ErrCode = 101
						   ,@ErrMsg = 'More than 1 customer found. Please search for 1 customer only'	
					RETURN;	   
				END
			ELSE 
				SELECT @CustID = CustID
					   ,@SystemName = username
				FROM #tblCust
		DROP TABLE 	#tblCust	
	END

IF @ShowSB = 1  
BEGIN  
	INSERT  INTO @sporttype( sporttype)
	VALUES  (0)	
	
END  

IF @ShowLC = 1
BEGIN
	INSERT  INTO @sporttype( Sporttype)
	VALUES  (162)
	
	INSERT INTO @bettype(bettype)
	SELECT typeid FROM bettype (NOLOCK)
	WHERE (typeid BETWEEN 1101 AND 1199)
END

IF @ShowRB = 1  
BEGIN  
	INSERT  INTO @sporttype( Sporttype)
	VALUES  (151)
END  

IF @ShowNG = 1
BEGIN
	INSERT INTO @sporttype(Sporttype)  
	VALUES(161)  
	
	INSERT INTO @bettype(bettype)
	SELECT typeid FROM bettype (NOLOCK)
	WHERE (typeid BETWEEN 81 AND 120)
END  
IF @ShowVS = 1
BEGIN
	INSERT  INTO @sporttype( Sporttype)
	SELECT  180
	
	INSERT INTO @bettype(bettype)
	SELECT typeid FROM bettype (NOLOCK)
	WHERE (typeid BETWEEN 1201 AND 1299)
END

IF @ShowCS=1 -- RNG Casino
BEGIN
	INSERT INTO @sporttype(sporttype)
	VALUES (251)
	INSERT INTO @bettype(bettype)
	VALUES(71)
	
	-- MBC - RNG Casino
	INSERT INTO @sporttype(sporttype)
	VALUES (208),(209),(210)
	INSERT INTO @bettype(bettype)
	SELECT DISTINCT bettype
	FROM dbo.SportBettypeMatrix with(nolock)
	WHERE sporttype IN (208, 209, 210)
END 

IF @ShowBG=1 -- Bingo
BEGIN 
	INSERT INTO @sporttype (sporttype)
	VALUES(252)
	INSERT INTO @bettype(bettype)
	VALUES(73)
END 

IF @ShowKN=1 -- keno
BEGIN 
	INSERT INTO @sporttype (sporttype)
	VALUES(202)

	INSERT INTO @bettype(bettype)
	SELECT typeid FROM bettype (NOLOCK)
	WHERE (typeid BETWEEN 1501 AND 1599)
END 
IF @ShowMGCLC=1 -- MicroGamming
BEGIN 
	INSERT INTO @sporttype (sporttype)
	VALUES(203)

	INSERT INTO @bettype(bettype)
	SELECT typeid FROM bettype (NOLOCK)
	WHERE (typeid BETWEEN 2001 AND 2007)
END 
IF @ShowMGCRnG=1 -- MicroGamming
BEGIN 
	INSERT INTO @sporttype (sporttype)
	VALUES(205)

	INSERT INTO @bettype(bettype)
	SELECT typeid FROM bettype (NOLOCK)
	WHERE (typeid BETWEEN 2008 AND 2009)
END
IF @ShowVB=1 -- Voidbridge
BEGIN 
	INSERT INTO @sporttype (sporttype)
	VALUES(212)

	INSERT INTO @bettype(bettype)
	SELECT typeid FROM bettype (NOLOCK)
	WHERE (typeid BETWEEN 4001 AND 7999)
END

DECLARE @TempFromDate DATETIME 
DECLARE @TempToDate DATETIME 
DECLARE @MaxOldDate DATETIME
DECLARE @FDate DATETIME 
DECLARE @TDate DATETIME 
--to Deal With Parameter Sniffing
SELECT @FDate=@FromDate,@TDate=@ToDate 

IF @TDate > @MoveBetsDay
BEGIN
	IF @FDate <= @MoveBetsDay 
		SET @TempFromDate =  DATEADD(DAY,1,@MoveBetsDay)
	ELSE
		SET @TempFromDate = @FDate
	
	
	IF @ShowBA=1 
	BEGIN
		INSERT INTO #SAgWinLoss  
		SELECT   
			b.winlostdate,  
			tma.currency,
			'BA' ProductCode,
			--'BA' AS ProductName,   
			SUM( stake
				*
				
				CASE WHEN b.statusID = 111 THEN 0|@sumTurnOver
					WHEN (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN (1|@sumTurnOver)/(~@sumTurnOver+1.0)
					ELSE 1 END
			) turnover, 
			SUM(b.winlost - b.actual_stake) AS Winlost,  
			0 as LicenseeWL,
			SUM (comm ) as Comm,
			SUM(PlayerComm ) AS PlayerComm,
			- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd  ,
			COUNT(b.transid)
			* 
				CASE WHEN b.statusID = 111 THEN 0|@sumBetCount
					ELSE 1 END
			   BetCount	
		FROM 
			dbo.bettrans b WITH ( NOLOCK)
			INNER JOIN @TempAg tma ON tma.CustID = b.recommend  AND b.Currency = tma.Currency
			INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction_active BA WITH (NOLOCK) ON tma.custid=BA.recommend and b.transid = BA.transid 	 	
		WHERE 
			b.winlostdate BETWEEN @TempFromDate AND @TDate AND  
			b.statusID IN (111, 112, 113) 
			AND (b.bettype < 901 OR b.bettype > 904)
			AND (b.bettype < 911 OR b.bettype > 914)
			AND (@CustId = 0 OR (@CustId <> 0 AND b.CustId = @CustID))
		GROUP BY   
			b.winlostdate,tma.currency, b.statusID
	END
	
	IF (@ShowSB=1)
	BEGIN
		INSERT INTO #SAgWinLoss
		SELECT   
			b.winlostdate,  
			a.currency,
			'SB' AS ProductCode,
			--'Sportsbook' AS ProductName,
			SUM(stake
				*
		
					CASE WHEN b.statusID = 111 THEN 0|@sumTurnOver
					WHEN (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN (1|@sumTurnOver)/(~@sumTurnOver+1.0)
					ELSE 1 END
				
			) turnover, 
			SUM(b.winlost - b.actual_stake) AS Winlost,  
			- SUM(b.winlost - b.actual_stake) AS LicenseeWL,
			SUM (comm) as Comm,
			SUM( PlayerComm ) AS PlayerComm,
			- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd  ,
			COUNT(b.transid)
			* 
				CASE WHEN b.statusID = 111 THEN 0|@sumBetCount
					ELSE 1 END
			   BetCount	
		FROM 
			dbo.bettrans b WITH ( NOLOCK)
			INNER JOIN @TempAg a ON b.recommend = a.custid AND b.Currency = a.Currency 
		WHERE 
			b.winlostdate BETWEEN @TempFromDate AND @TDate AND  
			(@CustId = 0 OR (@CustId <> 0 AND b.CustId = @CustID)) AND
			(b.bettype<31 OR (b.bettype BETWEEN 121 AND 999)
						  OR (b.Bettype BETWEEN 1301 and 1399) --new tennis's bettypes
			) AND
			b.statusID  IN (111, 112, 113) 
			AND (b.bettype < 901 OR b.bettype > 904)
			AND (b.bettype < 911 OR b.bettype > 914)
			AND
			b.tpositiontaking<>0
			
		GROUP BY   
			b.winlostdate,a.currency,b.statusID
	END
	
	--SB + RB + LC + VB
	IF 1 IN (@ShowNG, @ShowLC, @ShowVS, @ShowCS, @ShowBG, @ShowKN, @ShowMGCLC, @showMGCRnG, @ShowVB )
	BEGIN
		SELECT 
			DISTINCT
			o.Orid,	
			r.SportType
		INTO #tmpVS	
		FROM VSOutright o with (nolock)
		INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
		WHERE EventDate BETWEEN @TempFromDate AND @TDate 
			
		 
		INSERT INTO #SAgWinLoss
		SELECT   
			b.winlostdate,  
			a.currency,
			CASE 
				WHEN b.bettype BETWEEN 1101 AND 1199 THEN 'LC'
				WHEN b.Bettype BETWEEN 81 AND 120 THEN 'NG' 
				WHEN b.bettype BETWEEN 1201 AND 1299 THEN
							 CASE WHEN ISNULL(vs.sporttype,0)=0  THEN 'VS'+convert(varchar(10),ISNULL(m.sporttype,0))
											 ELSE   'VS' +convert(varchar(10),vs.sporttype)
											 END
				WHEN (b.bettype = 71 OR b.bettype BETWEEN 2101 AND 2399) THEN 'CS'
				WHEN b.bettype =73 THEN 'BG'
				WHEN b.bettype BETWEEN 1501 AND 1599  THEN 'KN'
				WHEN b.bettype BETWEEN 2001 AND 2007 THEN 'MGCLC'
				WHEN b.bettype BETWEEN 2008 AND 2009 THEN 'MGCRNG'
				WHEN b.bettype BETWEEN 4001 AND 7999 THEN 'VB'
				
			END AS ProductCode,
			SUM(stake
				*
			
				CASE WHEN b.statusID = 111 THEN 0|@sumTurnOver
					ELSE 1 END
			) turnover, 
			SUM(b.winlost - b.actual_stake) AS Winlost,  
			- SUM(b.winlost - b.actual_stake) AS LicenseeWL,
			SUM (comm) as Comm,
			SUM( PlayerComm ) AS PlayerComm,
			- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd  ,
			COUNT(b.transid)
			*
				CASE WHEN b.statusID = 111 THEN 0|@sumBetCount
					ELSE 1 END
			   BetCount	
		FROM 
			dbo.bettrans b WITH ( NOLOCK)--,INDEX=IX_srecommend )  
			INNER JOIN @TempAg a ON b.recommend = a.custid AND b.Currency = a.Currency 
			INNER JOIN @bettype bt ON b.bettype = bt.bettype
			LEFT JOIN [match] m with(nolock) ON b.matchid = m.matchid AND b.bettype NOT IN (SELECT bettype FROM dbo.f_VSHorseRacingByBettype())
			LEFT JOIN #tmpVS vs ON b.oddsid=vs.Orid AND b.bettype IN (1231,1232,1233,1237,1238,1220,1235,1236)	
		WHERE 
			b.winlostdate BETWEEN @TempFromDate AND @TDate AND  
			(@CustId = 0 OR (@CustId <> 0 AND b.CustId = @CustID)) AND
			b.statusID  IN (111, 112, 113)
		GROUP BY   
			b.winlostdate
			,a.currency
			,CASE 
				WHEN b.bettype BETWEEN 1101 AND 1199 THEN 'LC'
				WHEN b.Bettype BETWEEN 81 AND 120 THEN 'NG' 
				WHEN b.bettype BETWEEN 1201 AND 1299 THEN
													 CASE WHEN ISNULL(vs.sporttype,0)=0  THEN 'VS'+convert(varchar(10),ISNULL(m.sporttype,0))
																	   ELSE   'VS' +convert(varchar(10),vs.sporttype)
																	   END 
				WHEN (b.bettype = 71 OR b.bettype BETWEEN 2101 AND 2399) THEN 'CS'
				WHEN b.bettype =73 THEN 'BG'
				WHEN b.bettype BETWEEN 1501 AND 1599  THEN 'KN'
				WHEN b.bettype BETWEEN 2001 AND 2007 THEN 'MGCLC'
				WHEN b.bettype BETWEEN 2008 AND 2009 THEN 'MGCRNG'
				WHEN b.bettype BETWEEN 4001 AND 7999 THEN 'VB'
			END 
			,b.statusID
		DROP TABLE #tmpVS	
	END
	
	
	IF @ShowRB = 1
	BEGIN
		INSERT INTO #SAgWinLoss
		SELECT   
			b.winlostdate,  
			a.currency,
			'RB' AS ProductCode,
			SUM(CASE WHEN b.bettype in (33, 43) AND liveawayscore = 0 THEN stake/2 ELSE stake END 
				*
			
				CASE WHEN b.statusID = 111 THEN 0|@sumTurnOver
					ELSE 1 END
			) turnover, 
			SUM(b.winlost - b.actual_stake) AS Winlost,  
			SUM (b.awinlost) AS LicenseeWL,
			SUM (comm ) as Comm,
			SUM( playercomm  ) AS PlayerComm,
			- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) as AmountDueTo3rd,
			COUNT(b.transid)
			* 
				CASE WHEN b.statusID = 111 THEN 0|@sumBetCount
					ELSE 1 END
			   BetCount	
		FROM 
			dbo.bettrans b WITH  ( NOLOCK)--,INDEX=IX_srecommend )  
			INNER JOIN @TempAg a ON b.recommend = a.custid AND b.Currency = a.Currency
		WHERE 
			b.winlostdate BETWEEN @TempFromDate AND @TDate AND  
			(@CustId = 0 OR (@CustId <> 0 AND b.CustId = @CustID)) AND
			(bettype BETWEEN 31 AND 33) AND 
			b.statusID  IN (111, 112, 113)
		GROUP BY   
			b.winlostdate,a.currency,b.statusID
	END
	
	
	
END  

IF @FDate <= @MoveBetsDay 
BEGIN
	IF @TDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET  @TempToDate = @TDate
	
	IF @ShowBA=1 
	BEGIN
		INSERT INTO #SAgWinLoss  
		SELECT 
			b.winlostdate,  
			b.currency,
			'BA' AS ProductCode,
			SUM(b.turnover
			*			
				CASE WHEN b.statusID = 111  THEN 0|@sumTurnOver
					WHEN b.statusID IN (114,115) THEN (1|@sumTurnOver)/(~@sumTurnOver+1.0)
					ELSE 1 END
			),     
			SUM(b.winlost),  
			0 as LicenseeWL,
			SUM (comm) as Comm,
			SUM( PlayerComm ) AS PlayerComm,
			- SUM (b.awinlost + b.winlost + b.comm) as AmountDueTo3rd,
			SUM(b.betcount)
			* 
				CASE WHEN b.statusID = 111 THEN 0|@sumBetCount
					ELSE 1 END
		FROM 
			bodb_licenseereport.dbo.rptLicWinloss2 b WITH ( NOLOCK )  
			INNER JOIN @TempAg ag ON b.Currency = ag.Currency AND b.recommend= ag.custID
		WHERE  
			  b.Winlostdate BETWEEN @FDate AND @TempToDate  
			AND (@CustId = 0 OR (@CustId <> 0 AND b.CustId = @CustID))  
			AND b.roleid = 1   
			AND b.statusID <> 101 --exclude REJECT bets
			AND (b.bettype < 901 OR b.bettype > 904)
			AND (b.bettype < 911 OR b.bettype > 914)
			AND ISNULL(b.isBA,0) = 1
		GROUP BY  b.winlostdate,  b.currency, b.statusID
	END
	
	IF 1 IN (@showSB, @ShowRB, @ShowNG, @ShowLC, @ShowCS, @ShowBG, @ShowKN, @ShowMGCLC, @showMGCRnG, @ShowVB )
	BEGIN
		INSERT INTO #SAgWinLoss  
		SELECT 
			b.winlostdate,  
			b.currency,
			CASE  
				WHEN b.sporttype = 0   THEN 'SB'
				WHEN b.sporttype = 151 THEN 'RB'
				WHEN b.sporttype = 161 THEN 'NG'
				WHEN b.sporttype = 162 THEN 'LC'
				WHEN b.sporttype IN (251,208,209,210) THEN 'CS'
				WHEN b.sporttype = 252 THEN 'BG'
				WHEN b.sporttype = 202 THEN 'KN'
				WHEN b.sporttype = 203 THEN 'MGCLC'
				WHEN b.sporttype = 205 THEN 'MGCRNG'
				WHEN b.sporttype = 212 THEN 'VB'
			END AS ProductCode,
			SUM(b.turnover
			*
				
				CASE WHEN b.statusID = 111  THEN 0|@sumTurnOver
					WHEN b.statusID IN (114,115) THEN (1|@sumTurnOver)/(~@sumTurnOver+1.0)
					ELSE 1 END
			),     
			SUM(b.winlost),  
			SUM(CASE WHEN (b.sporttype in(0,161,162,251,252,202,203,205,208,209,210,212 ))  THEN -1 * b.winlost 
					WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END
				) AS LicenseeWL,
			SUM(comm ) as Comm,
			SUM( PlayerComm  ) AS PlayerComm, 
			- SUM (b.awinlost + b.winlost + b.comm) as AmountDueTo3rd,
			SUM(b.betcount)
			* 
				CASE WHEN b.statusID = 111 THEN 0|@sumBetCount
					ELSE 1 END
		FROM 
			bodb_licenseereport.dbo.rptLicWinloss2 b WITH ( NOLOCK )  
			INNER JOIN @sporttype t ON b.sporttype = t.sporttype
			INNER JOIN @TempAg ag ON b.recommend = ag.custID AND b.Currency = ag.Currency
		WHERE  
			 b.Winlostdate BETWEEN @FDate AND @TempToDate  
			 AND (@CustId = 0 OR (@CustId <> 0 AND b.CustId = @CustID))
			AND b.roleid = 1   
			AND b.statusID <> 101 --exclude REJECT bets
			AND (b.bettype < 901 OR b.bettype > 904)
			AND (b.bettype < 911 OR b.bettype > 914)
			AND ISNULL(b.isBA,0) = 0
			and t.sporttype <>180
		GROUP BY  
			b.winlostdate,   
			b.currency,
			CASE 
				WHEN b.sporttype = 0   THEN 'SB'
				WHEN b.sporttype = 151 THEN 'RB'
				WHEN b.sporttype = 161 THEN 'NG'
				WHEN b.sporttype = 162 THEN 'LC'
				WHEN b.sporttype IN (251,208,209,210) THEN 'CS'
				WHEN b.sporttype = 252 THEN 'BG'
				WHEN b.sporttype = 202 THEN 'KN'
				WHEN b.sporttype = 203 THEN 'MGCLC'
				WHEN b.sporttype = 205 THEN 'MGCRNG'
				WHEN b.sporttype = 212 THEN 'VB'
				 
			END
			, b.statusID
	END		
	IF (@ShowVS=1)
	BEGIN
		
		DECLARE  @tblVS AS TABLE 
			(rptdate    datetime
			,sportID	 int
			,recommend   int
			,currency	 int
			,status 	 MONEY
			,turnover MONEY
			,winloss  MONEY
			,commissionA MONEY
			,commissionP MONEY
			,WinlossA  	MONEY
			,betcount INT )
		INSERT INTO @tblVS 
			(rptdate    
			,sportID	
			,recommend   
			,currency	 
			,status 	 
			,turnover 
			,winloss  
			,commissionA 
			,commissionP 
			,WinlossA  	
			,betcount)
		SELECT 
			 rptdate    
			,sportID	
			,recommend   
			,currency	 
			,status 	 
			,SUM(stake) 
			,SUM(winlossp)  
			,SUM(commissionA) 
			,SUM(commissionP) 
			,SUM(WinlossA)  	
			,SUM(betcount)  
		FROM DBDW2.bodb_Account.dbo.mcCustVirtualSport  WITH ( NOLOCK )   	
		WHERE rptdate BETWEEN @FDate AND @TempToDate  
			 AND status=8 --  in (8,3,4)
			 AND (@CustId = 0 OR (@CustId <> 0 AND CustId = @CustID))
		GROUP BY 
		rptdate    
		,sportID	
		,recommend   
		,currency	 
		,status
	INSERT INTO @tblVS 
			(rptdate    
			,sportID	
			,recommend   
			,currency	 
			,status 	 
			,turnover 
			,winloss  
			,commissionA 
			,commissionP 
			,WinlossA  	
			,betcount)
		SELECT 
			 rptdate    
			,sportID	
			,recommend   
			,currency	 
			,status 	 
			,SUM(stake) 
			,SUM(winlossp)  
			,SUM(commissionA) 
			,SUM(commissionP) 
			,SUM(WinlossA)  	
			,SUM(betcount)  
		FROM DBDW2.bodb_Account.dbo.mcCustVirtualSport  WITH ( NOLOCK )   	
		WHERE rptdate BETWEEN @FDate AND @TempToDate  
			AND (@CustId = 0 OR (@CustId <> 0 AND CustId = @CustID))
			 AND status=3  
		GROUP BY 
		rptdate    
		,sportID	
		,recommend   
		,currency	 
		,status
		INSERT INTO @tblVS 
			(rptdate    
			,sportID	
			,recommend   
			,currency	 
			,status 	 
			,turnover 
			,winloss  
			,commissionA 
			,commissionP 
			,WinlossA  	
			,betcount)
		SELECT 
			 rptdate    
			,sportID	
			,recommend   
			,currency	 
			,status 	 
			,SUM(stake) 
			,SUM(winlossp)  
			,SUM(commissionA) 
			,SUM(commissionP) 
			,SUM(WinlossA)  	
			,SUM(betcount)  
		FROM DBDW2.bodb_Account.dbo.mcCustVirtualSport  WITH ( NOLOCK )   	
		WHERE rptdate BETWEEN @FDate AND @TempToDate  
			 AND status=4
			 AND (@CustId = 0 OR (@CustId <> 0 AND CustId = @CustID))
		GROUP BY 
		rptdate    
		,sportID	
		,recommend   
		,currency	 
		,status
	

		INSERT INTO #SAgWinLoss  
		SELECT 	b.rptdate
				,b.currency
				,'VS'+convert(varchar(10),ISNULL(b.sportID,0)) AS ProductCode
				,SUM(b.turnover
					*
						
						CASE WHEN b.[status] = 3  THEN 0|@sumTurnOver
							WHEN b.[Status] IN (13,12) THEN (1|@sumTurnOver)/(~@sumTurnOver+1.0)
							ELSE 1 END
					)
				,SUM(b.winloss)
				,-SUM(b.winloss) AS LicenseeWL
				,SUM(commissionA) AS Comm
				,SUM( commissionP ) AS PlayerComm,
				- SUM (b.WinlossA + b.Winloss + b.commissionA) as AmountDueTo3rd,
				SUM(b.betcount)
				* 
				CASE WHEN b.status = 3 THEN 0|@sumBetCount
					ELSE 1 END
		FROM @tblVS b
			INNER JOIN @tempAg t ON  t.CustID = b.recommend	AND b.Currency = t.Currency 
		GROUP BY 
				b.rptdate
				,b.currency
				,b.status
				,'VS'+convert(varchar(10),ISNULL(b.sportID,0))	
	END	
END 
IF @IsOld = 1 
BEGIN
	SELECT @MaxOldDate = MAX(winlostdate) FROM bodb_Licenseereport.dbo.rptLicWinloss_old (NOLOCK)
	IF @TDate >= @MaxOldDate
			SET @TempToDate = @MaxOldDate
		ELSE
			SET  @TempToDate = @TDate

	IF @ShowBA=1 
	BEGIN
		INSERT INTO #SAgWinLoss  
		SELECT
			b.winlostdate,  
			b.currency,
			'BA' ProductCode,
			SUM(b.turnover
			*
				
				CASE WHEN b.statusID = 111  THEN 0|@sumTurnOver
					WHEN b.statusID IN (114,115) THEN (1|@sumTurnOver)/(~@sumTurnOver+1.0)
					ELSE 1 END
				
			),     
			SUM(b.winlost),  
			0 as LicenseeWL,
			SUM (comm) as Comm,
			SUM( PlayerComm  ) AS PlayerComm, 
			- SUM (b.awinlost + b.winlost + b.comm) as AmountDueTo3rd,
			SUM(b.betcount)
			* 
				CASE WHEN b.statusID = 111 THEN 0|@sumBetCount
					ELSE 1 END
		FROM 
			bodb_licenseereport.dbo.rptLicWinloss_old b WITH ( NOLOCK )  
			INNER JOIN @TempAg ag ON b.recommend = ag.custID AND ag.Currency = b.Currency
		WHERE  
			b.Winlostdate BETWEEN @FDate AND @TempToDate  
			AND (@CustId = 0 OR (@CustId <> 0 AND b.CustId = @CustID))
			AND b.roleid = 1   
			AND b.statusID <> 101 --exclude REJECT bets
			AND b.bettype NOT IN (901,902,903,904)
			AND ISNULL(b.isBA,0) = 1
		GROUP BY  b.winlostdate,  b.currency, b.statusID
	END

	--exclude BA tickets
	IF 1 IN (@showSB, @ShowRB, @ShowNG, @ShowLC, @ShowVS, @ShowCS, @ShowBG, @ShowKN, @ShowVB )
	BEGIN
		INSERT INTO #SAgWinLoss  
		SELECT 
			b.winlostdate,  
			b.currency,
			CASE 
				WHEN b.sporttype = 0 THEN 'SB'
				WHEN b.sporttype = 151 THEN 'RB'
				WHEN b.sporttype = 161 THEN 'NG'
				WHEN b.sporttype = 162 THEN 'LC'
				WHEN b.sporttype = 180 THEN 'VS'
				WHEN b.sporttype IN (251, 208, 209, 210) THEN 'CS'
				WHEN b.sporttype = 252 THEN 'BG'
				WHEN b.sporttype = 202 THEN 'KN'
				WHEN b.sporttype = 203 THEN 'MGCLC'
				WHEN b.sporttype = 205 THEN 'MGCRNG'
				WHEN b.sporttype = 212 THEN 'VB'
				 
			END AS ProductCode,
			SUM(b.turnover
			*
				
				CASE WHEN b.statusID = 111  THEN 0|@sumTurnOver
					WHEN b.statusID IN (114,115) THEN (1|@sumTurnOver)/(~@sumTurnOver+1.0)
					ELSE 1 END
				
			),     
			SUM(b.winlost),  
			SUM(CASE WHEN (b.sporttype in(0,161,162,180,251,252,202,203,205,208,209,210,212 ))  THEN -1 * b.winlost WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END) AS LicenseeWL ,
			SUM(comm) as Comm,
			SUM( playerComm  ) AS PlayerComm,
			- SUM (b.awinlost + b.winlost + b.comm) as AmountDueTo3rd,
			SUM(b.betcount)
			* 
				CASE WHEN b.statusID = 111 THEN 0|@sumBetCount
					ELSE 1 END
		FROM 
			bodb_licenseereport.dbo.rptLicWinloss_old b WITH ( NOLOCK )  
			INNER JOIN @TempAg ag  ON b.recommend = ag.custID AND b.Currency = ag.Currency
			INNER JOIN @sporttype t ON b.sporttype = t.sporttype
		WHERE  
			  b.Winlostdate BETWEEN @FDate AND @TempToDate  
			AND (@CustId = 0 OR (@CustId <> 0 AND b.CustId = @CustID))  
			AND b.roleid = 1   
			AND b.statusID <> 101 --exclude REJECT bets
			AND b.bettype NOT IN (901,902,903,904)
			AND ISNULL(b.isBA,0) = 0
		GROUP BY  
			b.winlostdate,  
			b.currency, 
			CASE 
				WHEN b.sporttype = 0 THEN 'SB'
				WHEN b.sporttype = 151 THEN 'RB'
				WHEN b.sporttype = 161 THEN 'NG'
				WHEN b.sporttype = 162 THEN 'LC'
				WHEN b.sporttype = 180 THEN 'VS'
				WHEN b.sporttype IN (251, 208, 209, 210) THEN 'CS'
				WHEN b.sporttype = 252 THEN 'BG'
				WHEN b.sporttype = 202 THEN 'KN'
				WHEN b.sporttype = 203 THEN 'MGCLC'
				WHEN b.sporttype = 205 THEN 'MGCRNG'
				WHEN b.sporttype = 212 THEN 'VB'
								 
			END,
			b.statusID
	END
END


SELECT * INTO #TempExchange 
FROM Lrf_f_GetExchangeDaily(@FDate,@TDate)
WHERE exchangeid IN (SELECT DISTINCT Currency FROM #SAgWinLoss)


SELECT   
   CASE WHEN @ReportType = 1 THEN CONVERT(VARCHAR(8),w.winlostdate,112)  
		WHEN @ReportType = 2 THEN CONVERT(VARCHAR(6),w.winlostdate,112)  
		ELSE '0' END ReportType,  
   Currency ,   
		CASE WHEN Currency = 51 THEN @VNDCurrencyName 
			 WHEN Currency = 70 THEN 'MKK'
			ELSE e.Code END currencyName,
   ProductCode,			
   SUM(TurnOver)	AS Turnover,   
   SUM(Winlost)		AS Winlost,  
   SUM(LicenseeWL) AS LicenseeWL,
   SUM(Comm) AS Comm,
   SUM(PlayerComm) AS PlayerComm,
   SUM(AmtDueto3rd) AS AmtDueto3rd,
   SUM(Betcount)	AS Betcount,
   
   --BaseRM  
   CAST(SUM(TurnOver*e.MYR)				AS MONEY)	AS TurnoverMYR,   
   CAST(SUM(Winlost*e.MYR)				AS MONEY)	AS WinlostMYR,  
   CAST(SUM(LicenseeWL*e.MYR) 			AS MONEY)	AS LicenseeWLMYR,
   CAST(SUM(Comm * e.MYR) 				AS MONEY)	AS CommMYR,
   CAST(SUM(PlayerComm* e.MYR) 			AS MONEY)	AS PlayerCommMYR,
   CAST(SUM(AmtDueto3rd*e.MYR) 			AS MONEY)	AS AmtDueto3rdMYR,
   
   
   --BaseUSD  
   CAST(SUM(TurnOver*e.USD)				AS MONEY)	AS TurnoverUSD,   
   CAST(SUM(Winlost*e.USD)				AS MONEY)	AS WinlostUSD,  
   CAST(SUM(LicenseeWL*e.USD)			AS MONEY)	AS LicenseeWLUSD,
   CAST(SUM(Comm * e.USD) 				AS MONEY)	AS CommUSD,
   CAST(SUM(PlayerComm*e.USD)  			AS MONEY)	AS PlayerCommUSD,
   CAST(SUM(AmtDueto3rd*e.USD) 			AS MONEY)	AS AmtDueto3rdUSD,
   
	--BaseEUR  
   CAST(SUM(TurnOver*e.EUR)				AS MONEY)	AS TurnoverEUR,   
   CAST(SUM(Winlost*e.EUR)				AS MONEY)	AS WinlostEUR,  
   CAST(SUM(LicenseeWL*e.EUR) 			AS MONEY)	AS LicenseeWLEUR,
   CAST(SUM(Comm * e.EUR) 				AS MONEY)	AS CommEUR,
   CAST(SUM(PlayerComm*e.EUR) 			AS MONEY)	AS PlayerCommEUR,
   CAST(SUM(AmtDueto3rd*e.EUR) 			AS MONEY)	AS AmtDueto3rdEUR,
	--BaseGBP  
   CAST(SUM(TurnOver*e.GBP)				AS MONEY)	AS TurnoverGBP,   
   CAST(SUM(Winlost*e.GBP)				AS MONEY)	AS WinlostGBP,  
   CAST(SUM(LicenseeWL*e.GBP) 			AS MONEY)	AS LicenseeWLGBP,
   CAST(SUM(Comm * e.GBP) 				AS MONEY)	AS CommGBP,
   CAST(SUM(PlayerComm*e.GBP) 			AS MONEY)	AS PlayerCommGBP,
   CAST(SUM(AmtDueto3rd*e.GBP) 			AS MONEY)	AS AmtDueto3rdGBP
FROM	
	#SAgWinLoss w   
	INNER JOIN #TempExchange e 
	ON w.winlostdate = e.ExchangeDate AND w.currency = e.ExchangeId
GROUP BY   
	Currency,
	Productcode,
	CASE WHEN @ReportType = 1 THEN CONVERT(VARCHAR(8),w.winlostdate,112)  
		  WHEN @ReportType = 2 THEN CONVERT(VARCHAR(6),w.winlostdate,112)  
		  ELSE '0' END   ,
	CASE WHEN Currency = 51 THEN @VNDCurrencyName 
		 WHEN Currency = 70 THEN 'MKK'
			ELSE e.Code END
ORDER BY ReportType,  Currency,ProductCode

DROP TABLE #SAgWinLoss
DROP TABLE #TempExchange
 
END


GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_WinlossByProduct] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_WinlossByProduct] TO [vnteam] 
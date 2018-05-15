/*<info serverAlias="DBEXT-bodb02" executers="" viewers="" isFunction="0" isNested="0"></info>*/

/****** Object:  Stored Procedure dbo.Lrf_Rpt_WinlossByProductDetail    Script Date: 7/21/2017 1:48:26 PM ******/

ALTER PROCEDURE [dbo].[Lrf_Rpt_WinlossByProductDetail]  
 @CustID		INT = 0, --AgentID
 @MemberID		INT = 0, --memberID
 @FromDate		SMALLDATETIME,  
 @ToDate		SMALLDATETIME,   
 @showSB		BIT=0,  
 @ShowRB		BIT=0,  
 @ShowNG		BIT=0, 
 @ShowBA		BIT=0,  
 @ShowVS		BIT=0,
 @ShowCS 		BIT=0,-- RNG Casino
 @ShowBG		BIT=0,-- Bingo
 @ShowKN   		BIT=0, -- Keno
 @ShowMGCLC 	BIT=0,-- MicroGamming
 @ShowMGCRnG 	BIT=0,-- MicroGamming  
 @ShowVB		BIT=0,-- Voidbridge
 @ShowVS2		BIT=0,-- BetRadar VS 
 @ShowLT		BIT=0,-- Lottery
 @MoveBetsDay	SMALLDATETIME,
 @IsOld			BIT = 0,
 @drawfilter	SMALLINT = 1  ,
 @AgentList		VARCHAR(MAX)
 WITH RECOMPILE
AS  
/*  Created: Henry  
	Date: 2011-07-06
	Task : Winloss By Product Detail Report for Licensee Member Level 
	DB: DB052.bodb02  
   
	Revisions:  
	-20111013@Henry: change to use rptLicWinloss2
	-20111208@Jim: change bettype condition
	-20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily  
	-20120529@Henry: enhance performance
	-20120731@Jim: add playercomm value 
	-20120815@Jim: add live casino
	-20120905@Jim: add virtual sport
	-20121004@Jim: replace @currency input param by @currencyID
	-20121022@Jim:  re-calculate AmountDueTo3rd's value 
	- 20121115@Henry: Only Sportsbook needs to exclude BA
	- 20121128@Henry: use new table LicenseeBATransaction_active to get bettrans BA tickets
	- 20130222@Jim: support RNG Casino,Bingo
	- 20130402@Jim: support base currency USD 
	- 20130514@Jim: Restrict permission of Licensee Users by currency
	- 20130809@Jim: offer Virtual Horse Racing
	- 20131007@Jim: offer Virtual Tennis
	- 20131213@Jim: support to Display win loss of individual sports with Virtual Sports
	- 20140304@Florent: offer Keno
	- 20140620@Florent: offer 14 new bettypes and Sporting Solution (36 new bettypes)
	- 20140915@Florent: hotfix duplicated VS bettype
	- 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
	- 20150107@Jim: add more input param @CustID
	- 20150123@Jim: support base on Currency GBP
	- 20150211@Don: remove index hint
	- 20150612@Jim: support MicroGaming
	- 20150623@Winnie: exclude 3 transactions SOLD/BOUGHT/BetTrade Commission
	- 201508215@Winnie: Revever KeenOcean currency
	- 20151001@Jim: remove MicroGaming
	- 20151228@Bobby: Support MBC RNG Casino sporttype(208,209,210)
	- 20160331@Walter: Support Voidbridge single wallet [Redmine: #55057]
	- 20160413@Victor: support MKK currency code [Redmine: #55745]
	- 20160727@Jim:  LRF - Commercial terms changed for Bet Trade [Redmine: #61342]
	- 20161022@Jim:move table to bodb_licenseereport [RedmineID :#60449]
	- 20170227@Harper: LRF - Get data by @AgentList instead of @UserID [RedmineID: #71679]
	- 20170327@Paul: Implement Cash Out [RedmineID :#71727]
	- 20170704@Harper: LRF - Integrate Bet Radar Virtual Sports [RedmineID: #78241]
	- 20170721@Sophia: Change to call Alias DBWH instead of DBDW2 
	- 20170731@Harper: LRF - Integrate Lottery [RedmineID: #79997]
	- 20180129@Harper: Remove LC from product list [RedmineID: #85965]
	- 20180409@Joseph: Implement new sports for VS2: BasketBall - Virual Soccer World Cup [Redmine: #90881]
	- 20180515@Joseph: Remove cheat currency name for special currencies [RedmineID: #94845]

	Param's Explanation:  
	  +	@drawfilter: 'No Draw' filter is supportted (1:Normal 2:No Draw 3:No Draw for Turnover only)
	  + @IsOld: 0 - query in table rptLicWinloss, 1 - query in table rptLicWinloss_old. 
	  + @excludeTest: remove currency UUS
	  + @showSB: Show SportsBook bets
	  + @ShowRB: Show RB bets
	  + @ShowNG: Show Number game bets
	  + @ShowBA: Show Bet Aggregator bets (combined with Sportsbook or Number Game)
	  +	@ShowVS: Show Virtual Sport
	  + @MoveBetsDay: The day we move tickets to bettrans14
	  + @AgentList: xml structure
					  <ROOT>
					   <Agent AgentId="12345" Currency="3"/>  
					   <Agent AgentId="12345" Currency="5"/>  
					  </ROOT> 
*/  
BEGIN  
SET NOCOUNT ON  

CREATE TABLE #SAgWinLoss  (  
	--winlostdate		DATETIME,  
	CustID			INT,   
	Currency		INT,
	ProductCode 	VARCHAR(10),
	TurnOver		MONEY,   	
	Winlost			MONEY,  
	LicenseeWL		MONEY, 
	Comm			MONEY, 
	PlayerComm 		MONEY,	
	AmtDueTo3rd		MONEY,
	
	TurnOverEUR		MONEY,   	
	WinlostEUR		MONEY,  
	LicenseeWLEUR	MONEY, 
	CommEUR			MONEY, 
	PlayerCommEUR 	MONEY,	
	AmtDueTo3rdEUR	MONEY,
	
	TurnOverUSD		MONEY,   	
	WinlostUSD		MONEY,  
	LicenseeWLUSD	MONEY, 
	CommUSD			MONEY, 
	PlayerCommUSD 	MONEY,	
	AmtDueTo3rdUSD	MONEY,
	
	TurnOverGBP		MONEY,   	
	WinlostGBP		MONEY,  
	LicenseeWLGBP	MONEY, 
	CommGBP			MONEY, 
	PlayerCommGBP 	MONEY,	
	AmtDueTo3rdGBP	MONEY,
	
	Betcount		BIGINT
)  

DECLARE @bettype		TABLE (bettype INT PRIMARY KEY, ProductCode VARCHAR(10))
DECLARE @sporttype		TABLE (sporttype INT, ProductCode VARCHAR(10))
DECLARE @Exchange		TABLE(ExchangeDate SMALLDATETIME, ExchangeId INT,  EUR FLOAT,USD FLOAT,GBP FLOAT,Code VARCHAR(10), PRIMARY KEY(ExchangeDate,ExchangeId))
DECLARE @ProductList	VARCHAR (500)

DECLARE @IsTest BIT = 0
SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

DECLARE @TempAg AS TABLE ( CustId INT,Currency INT )
DECLARE @DocHandler INT

BEGIN TRY
	EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@AgentList
	INSERT INTO @TempAg (custID, currency)
	SELECT AgentId, Currency
	FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency INT) AS Data
	WHERE @CustID = 0 OR (@CustID <> 0 AND AgentId = @CustID)

	EXEC sp_xml_removedocument @DocHandler
END TRY

BEGIN CATCH
	SELECT ErrCode = 100
			,ErrMsg = N'Paramter invalid.'

	RETURN
END CATCH;
	
IF @ShowSB = 1  
BEGIN  
	SELECT @ProductList = COALESCE(@ProductList + ',' + 'SB', 'SB')	
END  

IF @ShowRB = 1  
BEGIN  
	SELECT @ProductList = COALESCE(@ProductList + ',' + 'RB', 'RB')
END  

IF @ShowNG = 1
BEGIN
	SELECT @ProductList = COALESCE(@ProductList + ',' + 'NG', 'NG')
END  

IF @ShowVS = 1
BEGIN
	SELECT @ProductList = COALESCE(@ProductList + ',' + 'VS', 'VS')
END

IF @ShowCS = 1 -- RNG Casino
BEGIN
	SELECT @ProductList = COALESCE(@ProductList + ',' + 'CS', 'CS')
END 

IF @ShowBG = 1 -- Bingo
BEGIN 
	SELECT @ProductList = COALESCE(@ProductList + ',' + 'BG', 'BG')
END 


IF @ShowKN = 1 -- Keno
BEGIN 
	SELECT @ProductList = COALESCE(@ProductList + ',' + 'KN', 'KN')
END 

IF @ShowMGCLC = 1 -- MicroGamming
BEGIN 
	SELECT @ProductList = COALESCE(@ProductList + ',' + 'MGCLC', 'MGCLC')
END 

IF @ShowMGCRnG = 1 -- MicroGamming
BEGIN 
	SELECT @ProductList = COALESCE(@ProductList + ',' + 'MGCRNG', 'MGCRNG')
END

IF @ShowVB=1 -- Macau Game
BEGIN 
	SELECT @ProductList = COALESCE(@ProductList + ',' + 'VB', 'VB')
END

IF @ShowVS2 = 1 -- Betradar Virtual Sports
BEGIN
	SELECT @ProductList = COALESCE(@ProductList + ',' + 'VS2', 'VS2')
END

IF @ShowLT = 1 -- Lottery
BEGIN
	SELECT @ProductList = COALESCE(@ProductList + ',' + 'LT', 'LT')
END

IF LEN(ISNULL(@ProductList, '')) > 0 
BEGIN
	-- Insert Bettype
	INSERT INTO @bettype ( bettype, ProductCode )
	SELECT DISTINCT BetType, ProductPrefix
	FROM f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', @ProductList, @IsTest)

	IF CHARINDEX('CS', @ProductList) > 0
		DELETE @bettype
		WHERE bettype = 72 AND ProductCode = 'CS'

	IF CHARINDEX('SB', @ProductList) > 0 OR CHARINDEX('RB', @ProductList) > 0
		DELETE @bettype
		WHERE ProductCode IN ('SB', 'RB')
		
	-- Insert Sport Type
	INSERT INTO @sporttype ( sporttype, ProductCode )
	SELECT DISTINCT sporttype, ProductCode
	FROM dbo.f_LicWinLoss_ProductSportType_Sel(@ProductList)
END	

DECLARE @TempFromDate DATETIME 
DECLARE @TempToDate DATETIME 
DECLARE @MaxOldDate DATETIME
DECLARE @FDate DATETIME 
DECLARE @TDate DATETIME 
--to Deal With Parameter Sniffing
SELECT @FDate=@FromDate,@TDate=@ToDate 

INSERT INTO @Exchange (exchangedate,exchangeid,eur,usd,GBP,code)
SELECT exchangedate,exchangeid,eur,usd,GBP,code
FROM Lrf_f_GetExchangeDaily(@FDate,@TDate)
WHERE exchangeid IN (SELECT Currency FROM @TempAg)	

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
			b.custid,
			tma.currency,
			'BA' AS ProductCode,
			SUM( stake
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111 THEN 0
					WHEN (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN 0.5
					ELSE 1 END
				ELSE 1 END
			) turnover, 
			SUM(b.winlost - b.actual_stake) AS Winlost,  
			0 as LicenseeWL,
			SUM (comm ) as Comm,
			SUM ( PlayerComm ) AS PlayerComm,
			- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd  ,
			
			--EUR
			SUM( stake
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111 THEN 0
					WHEN (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN 0.5
					ELSE 1 END
				ELSE 1 END
				* e.EUR
			) turnoverEUR, 
			SUM((b.winlost - b.actual_stake) * e.EUR) AS WinlostEUR,  
			0 as LicenseeWLEUR,
			SUM (comm * e.EUR) as CommEUR,
			SUM ( PlayerComm * e.EUR ) AS PlayerCommEUR,
			- SUM((b.awinlost + b.winlost - b.actual_stake + b.comm) * e.EUR) AmountDueTo3rdEUR  ,
			------------USD
			SUM( stake
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111 THEN 0
					WHEN (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN 0.5
					ELSE 1 END
				ELSE 1 END
				* e.USD
			) turnoverUSD, 
			SUM((b.winlost - b.actual_stake) * e.USD) AS WinlostUSD,  
			0 as LicenseeWLUSD,
			SUM (comm * e.USD) as CommUSD,
			SUM ( PlayerComm * e.USD ) AS PlayerCommUSD,
			- SUM((b.awinlost + b.winlost - b.actual_stake + b.comm) * e.USD) AmountDueTo3rdUSD  ,
			------------GBP
			SUM( stake
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111 THEN 0
					WHEN (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN 0.5
					ELSE 1 END
				ELSE 1 END
				* e.GBP
			) turnoverGBP, 
			SUM((b.winlost - b.actual_stake) * e.GBP) AS WinlostGBP,  
			0 as LicenseeWLGBP,
			SUM (comm * e.GBP) as CommGBP,
			SUM ( PlayerComm * e.GBP ) AS PlayerCommGBP,
			- SUM((b.awinlost + b.winlost - b.actual_stake + b.comm) * e.GBP) AmountDueTo3rdGBP  ,
			
			COUNT(b.transid)
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
			   BetCount	
		FROM 
			--dbo.bettrans b WITH ( NOLOCK,INDEX=IX_srecommend) 
			dbo.bettrans b WITH (NOLOCK) 
			INNER JOIN @TempAg tma ON tma.CustID=b.recommend AND b.currency = tma.currency
			INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction_active BA WITH (NOLOCK) ON tma.custid=BA.recommend and b.transid = BA.transid 	 	
			LEFT JOIN @Exchange e  ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
		WHERE 
			b.winlostdate BETWEEN @TempFromDate AND @TDate AND  
			(@MemberID = 0 OR (@MemberID <> 0 AND b.CustId = @MemberID)) AND
			b.statusID IN (111, 112, 113) 
			AND (b.bettype < 901 OR b.bettype > 904)
			AND (b.bettype < 911 OR b.bettype > 914) 
		GROUP BY   
			b.custid,tma.currency, b.statusID
	END
	
	IF (@ShowSB=1)
	BEGIN
		INSERT INTO #SAgWinLoss
		SELECT   
			b.custid,
			--b.username,
			a.currency,
			'SB' AS ProductCode,
			SUM(stake
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111 THEN 0
					WHEN (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN 0.5
					ELSE 1 END
				ELSE 1 END
			) turnover, 
			SUM(b.winlost - b.actual_stake) AS Winlost,  
			- SUM(b.winlost - b.actual_stake) AS LicenseeWL,
			SUM (comm ) as Comm,
			SUM( PlayerComm  ) AS PlayerComm, 
			- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd  ,
			
			--EUR
			SUM(stake
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111 THEN 0
					WHEN (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN 0.5
					ELSE 1 END
				ELSE 1 END
				* e.EUR
			) turnoverEUR, 
			SUM((b.winlost - b.actual_stake)*e.EUR) AS WinlostEUR,  
			- SUM((b.winlost - b.actual_stake)*e.EUR) AS LicenseeWLEUR,
			SUM (comm * e.EUR) as CommEUR,
			SUM( PlayerComm  * e.EUR) AS PlayerCommEUR, 
			- SUM((b.awinlost + b.winlost - b.actual_stake + b.comm)*e.EUR) AmountDueTo3rdEUR  ,
			------USD
			SUM(stake
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111 THEN 0
					WHEN (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN 0.5
					ELSE 1 END
				ELSE 1 END
				* e.USD
			) turnoverUSD, 
			SUM((b.winlost - b.actual_stake)*e.USD) AS WinlostUSD,  
			- SUM((b.winlost - b.actual_stake)*e.USD) AS LicenseeWLUSD,
			SUM (comm * e.USD) as CommUSD,
			SUM( PlayerComm  * e.USD) AS PlayerCommUSD, 
			- SUM((b.awinlost + b.winlost - b.actual_stake + b.comm)*e.USD) AmountDueTo3rdUSD  ,
			
			------GBP
			SUM(stake
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111 THEN 0
					WHEN (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN 0.5
					ELSE 1 END
				ELSE 1 END
				* e.GBP
			) turnoverGBP, 
			SUM((b.winlost - b.actual_stake)*e.GBP) AS WinlostGBP,  
			- SUM((b.winlost - b.actual_stake)*e.GBP) AS LicenseeWLGBP,
			SUM (comm * e.GBP) as CommGBP,
			SUM( PlayerComm  * e.GBP) AS PlayerCommGBP, 
			- SUM((b.awinlost + b.winlost - b.actual_stake + b.comm)*e.GBP) AmountDueTo3rdGBP  ,
			
			
			COUNT(b.transid)
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
			   BetCount	
		FROM 			
			dbo.bettrans b WITH (NOLOCK)
			INNER JOIN @TempAg a ON b.recommend = a.custid AND b.currency = a.currency
			LEFT JOIN @Exchange e  ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
		WHERE 
			b.winlostdate BETWEEN @TempFromDate AND @TDate AND  
			(@MemberID = 0 OR (@MemberID <> 0 AND b.CustId = @MemberID)) AND
			(b.bettype<31 OR (b.bettype BETWEEN 121 AND 999)
						  OR (b.Bettype BETWEEN 1301 and 1399) --new tennis's bettypes
			) AND
			b.statusID  IN (111, 112, 113)
			AND (b.bettype < 901 OR b.bettype > 904)
			AND (b.bettype < 911 OR b.bettype > 914)
			AND b.tpositiontaking <> 0
			
		GROUP BY   
			b.custid,
			a.currency,
			statusID
	END
	
	--NG+VS+RB + KN + VB
	IF 1 IN (@ShowNG, @ShowVS, @ShowRB, @ShowCS, @ShowBG, @ShowKN, @ShowMGCLC, @showMGCRnG, @ShowVB, @ShowVS2, @ShowLT)
	BEGIN
		SELECT 
			DISTINCT
			o.Orid,	
			r.SportType
		INTO #tmpVS	
		FROM VSOutright o with (nolock)
		INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
		WHERE EventDate BETWEEN @TempFromDate AND @TDate 

		DECLARE @tmpParlay TABLE (transid BIGINT PRIMARY KEY, sporttype SMALLINT)

		IF (@ShowVS2 = 1)
		BEGIN
			INSERT INTO @tmpParlay( transid, sporttype )		
			SELECT DISTINCT b.transid, s.sporttype
			FROM bodb02.dbo.bettrans b WITH (NOLOCK)
				CROSS APPLY (	SELECT TOP 1 m.sporttype
								FROM bodb02.dbo.bettransm bm WITH (NOLOCK)
									INNER JOIN bodb02.dbo.match m WITH (NOLOCK) ON bm.matchid = m.matchid
								WHERE b.refno = bm.refno AND b.custid = bm.custid
							) AS s
				INNER JOIN @TempAg a ON b.recommend = a.custid AND b.Currency = a.Currency 							
			WHERE b.bettype = 2799 -- Betradar VS Parlay
				AND b.winlostdate BETWEEN @TempFromDate AND @TDate  
				AND (@MemberID = 0 OR (@MemberID <> 0 AND b.CustId = @MemberID))
				AND b.statusID  IN (111, 112, 113)
				AND b.matchid = 2799
		END
		
		INSERT INTO #SAgWinLoss
		SELECT   
			b.custid,
			--b.username,
			a.currency,
			CASE WHEN b.bettype BETWEEN 1201 AND 1299 THEN
				CASE WHEN ISNULL(vs.sporttype, 0) = 0  
					THEN 'VS' + CONVERT(varchar(10),ISNULL(m.sporttype,0))
					ELSE 'VS' + CONVERT(varchar(10),vs.sporttype)
				END
			WHEN b.bettype = 2799 THEN 'VS2' + CONVERT(varchar(10), p.sporttype)
			WHEN (b.bettype BETWEEN 2701 AND 2798) OR (b.bettype BETWEEN 2800 AND 2829) THEN
				CASE 
				     WHEN ISNULL(vs.sporttype, 0) = 0 THEN 'VS2'+ CONVERT(varchar(10), ISNULL(m.sporttype,0))
					 ELSE 'VS2' + CONVERT(varchar(10), vs.sporttype)
				END					
			ELSE bt.ProductCode END AS ProductCode,
			SUM(
				CASE WHEN b.bettype = 33 AND b.liveawayscore = 0 THEN stake/2 ELSE stake END 
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
			) turnover, 
			SUM(b.winlost - b.actual_stake) AS Winlost,  
			SUM(CASE WHEN b.bettype NOT BETWEEN 31 AND 33 THEN -1 * (b.winlost - b.actual_stake) ELSE b.awinlost END ) AS LicenseeWL,
			SUM (comm ) as Comm,
			SUM( PlayerComm  ) AS PlayerComm, 
			- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd  ,
			
			--EUR			
			SUM(
				CASE WHEN b.bettype = 33 AND b.liveawayscore = 0 THEN stake/2 ELSE stake END 
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
				* e.EUR
			) turnoverEUR, 
			SUM((b.winlost - b.actual_stake)*e.EUR) AS WinlostEUR,  
			SUM(CASE WHEN b.bettype NOT BETWEEN 31 AND 33 THEN -1 * (b.winlost - b.actual_stake) ELSE b.awinlost END * e.EUR) AS LicenseeWLEUR,
			SUM (comm * e.EUR) as CommEUR,
			SUM( PlayerComm * e.EUR ) AS PlayerCommEUR, 
			- SUM((b.awinlost + b.winlost - b.actual_stake + b.comm) * e.EUR) AmountDueTo3rdEUR  ,

			--- USD
			SUM(
				CASE WHEN b.bettype = 33 AND b.liveawayscore = 0 THEN stake/2 ELSE stake END 
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
				* e.USD
			) turnoverUSD, 
			SUM((b.winlost - b.actual_stake)*e.USD) AS WinlostUSD,  
			SUM(CASE WHEN b.bettype NOT BETWEEN 31 AND 33 THEN -1 * (b.winlost - b.actual_stake) ELSE b.awinlost END * e.USD) AS LicenseeWLUSD,
			SUM (comm * e.USD) as CommUSD,
			SUM( PlayerComm * e.USD ) AS PlayerCommUSD, 
			- SUM((b.awinlost + b.winlost - b.actual_stake + b.comm) * e.USD) AmountDueTo3rdUSD  ,
			
			--- GBP
			SUM(
				CASE WHEN b.bettype = 33 AND b.liveawayscore = 0 THEN stake/2 ELSE stake END 
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
				* e.GBP
			) turnoverGBP, 
			SUM((b.winlost - b.actual_stake)*e.GBP) AS WinlostGBP,  
			SUM(CASE WHEN b.bettype NOT BETWEEN 31 AND 33 THEN -1 * (b.winlost - b.actual_stake) ELSE b.awinlost END * e.GBP) AS LicenseeWLGBP,
			SUM (comm * e.GBP) as CommGBP,
			SUM( PlayerComm * e.GBP ) AS PlayerCommGBP, 
			- SUM((b.awinlost + b.winlost - b.actual_stake + b.comm) * e.GBP) AmountDueTo3rdGBP  ,
			
			COUNT(b.transid)
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
			   BetCount	
		FROM 			
			dbo.bettrans b WITH (NOLOCK)
			INNER JOIN @TempAg a ON b.recommend = a.custid AND a.currency = b.currency 
			INNER JOIN @bettype bt ON b.bettype = bt.bettype
			LEFT JOIN @Exchange e  ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
			LEFT JOIN [match] m with(nolock) ON b.matchid = m.matchid AND b.bettype NOT IN (SELECT bettype FROM dbo.f_VSHorseRacingByBettype())
			LEFT JOIN #tmpVS vs ON b.oddsid=vs.Orid AND b.bettype IN (1231,1232,1233,1237,1238,1220,1235,1236)	
			LEFT JOIN @tmpParlay p ON b.transid = p.transid AND b.bettype = 2799
		WHERE 
			b.winlostdate BETWEEN @TempFromDate AND @TDate AND  
			(@MemberID = 0 OR (@MemberID <> 0 AND b.CustId = @MemberID)) AND
			b.statusID  IN (111, 112, 113)
		GROUP BY   
			b.custid,
			a.currency ,
			CASE WHEN b.bettype BETWEEN 1201 AND 1299 THEN
				CASE WHEN ISNULL(vs.sporttype, 0) = 0  
					THEN 'VS' + CONVERT(varchar(10),ISNULL(m.sporttype,0))
					ELSE 'VS' + CONVERT(varchar(10),vs.sporttype)
				END
			WHEN b.bettype = 2799 THEN 'VS2' + CONVERT(varchar(10), p.sporttype)
			WHEN (b.bettype BETWEEN 2701 AND 2798) OR (b.bettype BETWEEN 2800 AND 2829) THEN
				CASE 
				     WHEN ISNULL(vs.sporttype, 0) = 0 THEN 'VS2'+ CONVERT(varchar(10), ISNULL(m.sporttype,0))
					 ELSE 'VS2' + CONVERT(varchar(10), vs.sporttype)
				END			
			ELSE bt.ProductCode END
			, statusID

	DROP TABLE #tmpVS		
	
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
			b.custid,
			b.currency,
			'BA' AS ProductCode,
			SUM(b.turnover
			*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111  THEN 0
					WHEN b.statusID IN (114,115) THEN 0.5
					ELSE 1 END
				ELSE 1 END
			),     
			SUM(b.winlost),  
			0 as LicenseeWL,
			SUM (comm ) as Comm,
			SUM( PlayerComm  ) AS PlayerComm,
			- SUM (b.awinlost + b.winlost + b.comm) as AmountDueTo3rd,
			
			--EUR
			SUM(b.turnover
			*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111  THEN 0
					WHEN b.statusID IN (114,115) THEN 0.5
					ELSE 1 END
				ELSE 1 END
				* e.EUR
			),     
			SUM(b.winlost * e.EUR),  
			0 as LicenseeWLEUR,
			SUM (comm * e.EUR ) as CommEUR,
			SUM( PlayerComm * e.EUR  ) AS PlayerCommEUR,
			- SUM ((b.awinlost + b.winlost + b.comm)* e.EUR) as AmountDueTo3rdEUR,
			---- USD
			SUM(b.turnover
			*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111  THEN 0
					WHEN b.statusID IN (114,115) THEN 0.5
					ELSE 1 END
				ELSE 1 END
				* e.USD
			),     
			SUM(b.winlost * e.USD),  
			0 as LicenseeWLUSD,
			SUM (comm * e.USD ) as CommUSD,
			SUM( PlayerComm * e.USD  ) AS PlayerCommUSD,
			- SUM ((b.awinlost + b.winlost + b.comm)* e.USD) as AmountDueTo3rdUSD,
			---- GBP
			SUM(b.turnover
			*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111  THEN 0
					WHEN b.statusID IN (114,115) THEN 0.5
					ELSE 1 END
				ELSE 1 END
				* e.GBP
			),     
			SUM(b.winlost * e.GBP),  
			0 as LicenseeWLGBP,
			SUM (comm * e.GBP ) as CommGBP,
			SUM( PlayerComm * e.GBP  ) AS PlayerCommGBP,
			- SUM ((b.awinlost + b.winlost + b.comm)* e.GBP) as AmountDueTo3rdGBP,
			
			SUM(b.betcount)
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
		FROM 
			bodb_licenseereport.dbo.rptLicWinloss2 b WITH ( NOLOCK )  
			INNER JOIN @TempAg ag ON b.recommend = ag.custID AND b.Currency = ag.currency
			LEFT JOIN @Exchange e  ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
		WHERE  
			b.Winlostdate BETWEEN @FDate AND @TempToDate  
			AND (@MemberID = 0 OR (@MemberID <> 0 AND b.CustId = @MemberID)) 
			AND b.roleid = 1   
			AND b.statusID <> 101 --exclude REJECT bets
			AND (b.bettype < 901 OR b.bettype > 904)
			AND (b.bettype < 911 OR b.bettype > 914)
			AND ISNULL(b.isBA,0) = 1

		GROUP BY   b.custid,
			b.currency, b.statusID
	END
	
	--exclude BA tickets
	IF 1 IN (@showSB, @ShowRB, @ShowNG, @ShowCS, @ShowBG, @ShowKN, @ShowMGCLC, @showMGCRnG, @ShowVB, @ShowLT)
	BEGIN
		INSERT INTO #SAgWinLoss  
		SELECT 
			b.custid,
			b.currency,
			t.ProductCode,
			SUM(b.turnover
			*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111  THEN 0
					WHEN b.statusID IN (114,115) THEN 0.5
					ELSE 1 END
				ELSE 1 END
			),     
			SUM(b.winlost),  
			SUM(CASE WHEN ( b.sporttype <> 151)  THEN -1 * b.winlost WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END) AS LicenseeWL ,
			SUM(comm ) as Comm,
			SUM( PlayerComm  ) AS PlayerComm,
			- SUM (b.awinlost + b.winlost + b.comm) as AmountDueTo3rd,
			
			--EUR
			SUM(b.turnover
			*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111  THEN 0
					WHEN b.statusID IN (114,115) THEN 0.5
					ELSE 1 END
				ELSE 1 END
				* e.EUR
			),     
			SUM(b.winlost * e.EUR),  
			SUM(CASE WHEN ( b.sporttype <> 151)  THEN -1 * b.winlost WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END * e.EUR) AS LicenseeWLEUR ,
			SUM(comm * e.EUR) as CommEUR,
			SUM( PlayerComm * e.EUR ) AS PlayerCommEUR,
			- SUM ((b.awinlost + b.winlost + b.comm) * e.EUR) as AmountDueTo3rdEUR,
			---USD
			SUM(b.turnover
			*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111  THEN 0
					WHEN b.statusID IN (114,115) THEN 0.5
					ELSE 1 END
				ELSE 1 END
				* e.USD
			),     
			SUM(b.winlost * e.USD),  
			SUM(CASE WHEN ( b.sporttype <> 151)  THEN -1 * b.winlost WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END * e.USD) AS LicenseeWLUSD ,
			SUM(comm * e.USD) as CommUSD,
			SUM( PlayerComm * e.USD ) AS PlayerCommUSD,
			- SUM ((b.awinlost + b.winlost + b.comm) * e.USD) as AmountDueTo3rdUSD,
			---GBP
			SUM(b.turnover
			*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111  THEN 0
					WHEN b.statusID IN (114,115) THEN 0.5
					ELSE 1 END
				ELSE 1 END
				* e.GBP
			),     
			SUM(b.winlost * e.GBP),  
			SUM(CASE WHEN ( b.sporttype <> 151)  THEN -1 * b.winlost WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END * e.GBP) AS LicenseeWLGBP ,
			SUM(comm * e.GBP) as CommGBP,
			SUM( PlayerComm * e.GBP ) AS PlayerCommGBP,
			- SUM ((b.awinlost + b.winlost + b.comm) * e.GBP) as AmountDueTo3rdGBP,
			
			SUM(b.betcount)
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
		FROM 
			bodb_licenseereport.dbo.rptLicWinloss2 b WITH ( NOLOCK )  
			INNER JOIN @sporttype t ON b.sporttype = t.sporttype
			INNER JOIN @TempAg ag ON b.recommend = ag.custID AND b.Currency = ag.currency
			LEFT JOIN @Exchange e  ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
		WHERE  
			  b.Winlostdate BETWEEN @FDate AND @TempToDate  
			AND (@MemberID = 0 OR (@MemberID <> 0 AND b.CustId = @MemberID))  
			AND b.roleid = 1
			AND b.statusID <> 101 --exclude REJECT bets
			AND t.sporttype NOT IN (180, 190,193)
			AND (b.bettype < 901 OR b.bettype > 904)
			AND (b.bettype < 911 OR b.bettype > 914)
			AND ISNULL(b.isBA,0) = 0
		GROUP BY  
			b.custid,
			b.currency, 
			t.ProductCode,
			b.statusID
	END
END 

IF 1 IN (@showVS, @ShowVS2)
BEGIN
	SELECT s.SportType, s.ProductPrefix
	INTO #tmpSport
	FROM 
	(
		SELECT DISTINCT m.SportType, p.ProductPrefix		
		FROM dbo.SportBettypeMatrix m WITH (NOLOCK)
			INNER JOIN dbo.Products p WITH (NOLOCK) ON m.ProductID = p.ProductID
		WHERE p.ProductPrefix IN (SELECT val FROM strSplit(@ProductList, ','))
	) s
	WHERE s.ProductPrefix IN ('VS', 'VS2')

	DECLARE  @tblVS AS TABLE 
				(rptdate    datetime
				,CustID		 int
				,recommend int
				,sportID	 int
				,currency	 int
				,status 	 MONEY
				,turnoverIBC MONEY
				,winlossIBC  MONEY
				,commissionA MONEY
				,commissionP MONEY
				,WinlossA  	MONEY
				,betcount INT )
				
	INSERT INTO  @tblVS 
				(rptdate    
				,CustID
				,recommend 		
				,sportID	
				,currency	
				,status 	
				,turnoverIBC 
				,winlossIBC  
				,commissionA 
				,commissionP 
				,WinlossA  	
				,betcount )
					
	SELECT 
		 rptdate    
		,CustID	
		,recommend 	
		,sportID	
		,currency	
		,status 	
		,SUM(stake) 
		,SUM(winlossp)
		,SUM(commissionA) 
		,SUM(commissionP)
		,SUM(WinlossA)
		,SUM(betcount)
	FROM DBWH.bodb_Account.dbo.mcCustVirtualSport  WITH ( NOLOCK )   
			INNER JOIN #tmpSport s ON SportID = s.sporttype	
	WHERE rptdate BETWEEN @FDate AND @TempToDate  			
		 AND status in (8,3,4)
		 AND (@MemberID = 0 OR (@MemberID <> 0 AND CustId = @MemberID))	 
	GROUP BY 
		 rptdate    
		,CustID	
		,recommend 	
		,sportID	
		,currency	
		,status 	
		
	INSERT INTO #SAgWinLoss  
		SELECT 
			b.custid,
			b.currency,
			CASE WHEN b.sportID BETWEEN 180 AND 186 
				THEN 'VS' + CONVERT(varchar(10),ISNULL(b.sportID,0))
				WHEN b.sportID BETWEEN 190 AND 199					
				THEN 'VS2' + CONVERT(varchar(10),ISNULL(b.sportID,0))			
				ELSE '' 
			END AS ProductCode,
			SUM(b.turnoverIBC
			*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.status = 3  THEN 0
					WHEN b.status IN (12,13) THEN 0.5
					ELSE 1 END
				ELSE 1 END
			),     
			SUM(b.winlossIBC),  
			-SUM(b.winlossIBC) AS LicenseeWL ,
			SUM(commissionA ) as Comm,
			SUM( commissionP  ) AS PlayerComm,
			- SUM (b.WinlossA + b.WinlossIBC + b.commissionA) as AmountDueTo3rd,
			
			--EUR
			SUM(b.turnoverIBC
			*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.status = 3  THEN 0
					WHEN b.status IN (12,13) THEN 0.5
					ELSE 1 END
				ELSE 1 END
				* e.EUR
			),     
			SUM(b.winlossIBC * e.EUR),  
			-SUM(b.winlossIBC* e.EUR) AS LicenseeWLEUR ,
			SUM(commissionA * e.EUR) as CommEUR,
			SUM( commissionP * e.EUR ) AS PlayerCommEUR,
			- SUM ((b.WinlossA + b.WinlossIBC + b.commissionA) * e.EUR) as AmountDueTo3rdEUR,
			---USD
			SUM(b.turnoverIBC
			*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.status = 3  THEN 0
					WHEN b.status IN (12,13) THEN 0.5
					ELSE 1 END
				ELSE 1 END
				* e.USD
			),     
			SUM(b.winlossIBC * e.USD),  
			-SUM(b.winlossIBC* e.USD) AS LicenseeWLUSD ,
			SUM(commissionA * e.USD) as CommUSD,
			SUM( commissionP * e.USD ) AS PlayerCommUSD,
			- SUM ((b.WinlossA + b.WinlossIBC + b.commissionA) * e.USD) as AmountDueTo3rdUSD,
			
			---GBP
			SUM(b.turnoverIBC
			*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.status = 3  THEN 0
					WHEN b.status IN (12,13) THEN 0.5
					ELSE 1 END
				ELSE 1 END
				* e.GBP
			),     
			SUM(b.winlossIBC * e.GBP),  
			-SUM(b.winlossIBC* e.GBP) AS LicenseeWLGBP ,
			SUM(commissionA * e.GBP) as CommGBP,
			SUM( commissionP * e.GBP ) AS PlayerCommGBP,
			- SUM ((b.WinlossA + b.WinlossIBC + b.commissionA) * e.GBP) as AmountDueTo3rdGBP,
			
			SUM(b.betcount)
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.status = 3 THEN 0
					ELSE 1 END
				ELSE 1 END
		FROM 
			@tblVS b
			INNER JOIN @TempAg ag ON ag.custid = b.recommend AND b.currency = ag.currency 
			LEFT JOIN @Exchange e  ON e.ExchangeDate = b.rptdate AND e.exchangeid = b.currency
		GROUP BY  
			b.custid,
			b.currency,
			CASE WHEN b.sportID BETWEEN 180 AND 186 
				THEN 'VS' + CONVERT(varchar(10),ISNULL(b.sportID,0))
				WHEN b.sportID BETWEEN 190 AND 199					
				THEN 'VS2' + CONVERT(varchar(10),ISNULL(b.sportID,0))			
				ELSE '' 
			END
			, b.status
	DROP TABLE #tmpSport
END	

IF @IsOld = 1 
BEGIN

	SELECT @MaxOldDate = MAX(winlostdate) FROM bodb_licenseereport.dbo.rptLicWinloss_old (NOLOCK)
	IF @TDate >= @MaxOldDate
			SET @TempToDate = @MaxOldDate
		ELSE
			SET  @TempToDate = @TDate

	IF @ShowBA=1 
	BEGIN
		INSERT INTO #SAgWinLoss  
		SELECT 
			b.custid,
			b.currency,
			'BA' ProductCode,
			SUM(b.turnover
			*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111  THEN 0
					WHEN b.statusID IN (114,115) THEN 0.5
					ELSE 1 END
				ELSE 1 END
			),     
			SUM(b.winlost),  
			0 as LicenseeWL,
			SUM (comm ) as Comm,
			SUM( PlayerComm  ) AS PlayerComm,
			- SUM (b.awinlost + b.winlost + b.comm) as AmountDueTo3rd,
			
			--EUR
			SUM(b.turnover
			*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111  THEN 0
					WHEN b.statusID IN (114,115) THEN 0.5
					ELSE 1 END
				ELSE 1 END
				* e.EUR
			),     
			SUM(b.winlost * e.EUR),  
			0 as LicenseeWLEUR,
			SUM (comm * e.EUR ) as CommEUR,
			SUM( PlayerComm * e.EUR  ) AS PlayerCommEUR,
			- SUM ((b.awinlost + b.winlost + b.comm)* e.EUR) as AmountDueTo3rdEUR,
			----USD 
			SUM(b.turnover
			*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111  THEN 0
					WHEN b.statusID IN (114,115) THEN 0.5
					ELSE 1 END
				ELSE 1 END
				* e.USD
			),     
			SUM(b.winlost * e.USD),  
			0 as LicenseeWLUSD,
			SUM (comm * e.USD ) as CommUSD,
			SUM( PlayerComm * e.USD  ) AS PlayerCommUSD,
			- SUM ((b.awinlost + b.winlost + b.comm)* e.USD) as AmountDueTo3rdUSD,
			----GBP 
			SUM(b.turnover
			*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111  THEN 0
					WHEN b.statusID IN (114,115) THEN 0.5
					ELSE 1 END
				ELSE 1 END
				* e.GBP
			),     
			SUM(b.winlost * e.GBP),  
			0 as LicenseeWLGBP,
			SUM (comm * e.GBP ) as CommGBP,
			SUM( PlayerComm * e.GBP  ) AS PlayerCommGBP,
			- SUM ((b.awinlost + b.winlost + b.comm)* e.GBP) as AmountDueTo3rdGBP,
			
			SUM(b.betcount)
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
		FROM 
			bodb_licenseereport.dbo.rptLicWinloss_old b WITH ( NOLOCK )  
			INNER JOIN @TempAg ag ON b.recommend = ag.custID AND b.Currency = ag.currency
			LEFT JOIN @Exchange e  ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
		WHERE  
			b.Winlostdate BETWEEN @FDate AND @TempToDate  
			AND (@MemberID = 0 OR (@MemberID <> 0 AND b.CustId = @MemberID))
			AND b.roleid = 1  
			AND b.statusID <> 101 --exclude REJECT bets
			AND b.bettype NOT IN (901,902,903,904)
			AND ISNULL(b.isBA,0) = 1
		GROUP BY  b.custid,
		b.currency, b.statusID
	END

	--exclude BA tickets
	IF 1 IN (@showSB, @ShowRB, @ShowNG, @ShowVS, @ShowCS, @ShowBG, @ShowKN, @ShowMGCLC, @showMGCRnG, @ShowVB, @ShowVS2)
	BEGIN
		INSERT INTO #SAgWinLoss  
		SELECT 
			b.custid,
			b.currency,
			t.ProductCode,
			SUM(b.turnover
			*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111  THEN 0
					WHEN b.statusID IN (114,115) THEN 0.5
					ELSE 1 END
				ELSE 1 END
			),     
			SUM(b.winlost),  
			SUM(CASE WHEN ( b.sporttype <> 151)  THEN -1 * b.winlost WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END) AS LicenseeWL ,
			SUM(comm ) as Comm,
			SUM( PlayerComm  ) AS PlayerComm,
			- SUM (b.awinlost + b.winlost + b.comm) as AmountDueTo3rd,
			
			--EUR
			SUM(b.turnover
			*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111  THEN 0
					WHEN b.statusID IN (114,115) THEN 0.5
					ELSE 1 END
				ELSE 1 END
				* e.EUR
			),     
			SUM(b.winlost * e.EUR),  
			SUM(CASE WHEN ( b.sporttype <> 151)  THEN -1 * b.winlost WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END * e.EUR) AS LicenseeWLEUR ,
			SUM(comm * e.EUR) as CommEUR,
			SUM( PlayerComm * e.EUR ) AS PlayerCommEUR,
			- SUM ((b.awinlost + b.winlost + b.comm) * e.EUR) as AmountDueTo3rdEUR,
			-------------USD
			SUM(b.turnover
			*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111  THEN 0
					WHEN b.statusID IN (114,115) THEN 0.5
					ELSE 1 END
				ELSE 1 END
				* e.USD
			),     
			SUM(b.winlost * e.USD),  
			SUM(CASE WHEN ( b.sporttype <> 151)  THEN -1 * b.winlost WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END * e.USD) AS LicenseeWLUSD ,
			SUM(comm * e.USD) as CommUSD,
			SUM( PlayerComm * e.USD ) AS PlayerCommUSD,
			- SUM ((b.awinlost + b.winlost + b.comm) * e.USD) as AmountDueTo3rdUSD,
			
			-------------GBP
			SUM(b.turnover
			*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111  THEN 0
					WHEN b.statusID IN (114,115) THEN 0.5
					ELSE 1 END
				ELSE 1 END
				* e.GBP
			),     
			SUM(b.winlost * e.GBP),  
			SUM(CASE WHEN ( b.sporttype <> 151)  THEN -1 * b.winlost WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END * e.GBP) AS LicenseeWLGBP ,
			SUM(comm * e.GBP) as CommGBP,
			SUM( PlayerComm * e.GBP ) AS PlayerCommGBP,
			- SUM ((b.awinlost + b.winlost + b.comm) * e.GBP) as AmountDueTo3rdGBP,
			
			SUM(b.betcount)
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
		FROM 
			 bodb_licenseereport.dbo.rptLicWinloss_old b WITH ( NOLOCK )  
			INNER JOIN @TempAg ag ON b.recommend = ag.custID AND b.Currency= ag.currency
			INNER JOIN @sporttype t ON b.sporttype = t.sporttype
			LEFT JOIN @Exchange e  ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
		WHERE  
			b.Winlostdate BETWEEN @FDate AND @TempToDate  
			AND (@MemberID = 0 OR (@MemberID <> 0 AND b.CustId = @MemberID))
			AND b.roleid = 1  
			AND b.statusID <> 101 --exclude REJECT bets
			AND b.bettype NOT IN (901,902,903,904)
			AND ISNULL(b.isBA,0) = 0
		GROUP BY  
			b.custid,
			b.currency, 
			t.ProductCode
			, b.statusID
	END
END


SELECT   
	c.username,  
	SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2)) AS nickname,	   w.custid, 
	w.Currency ,
	ProductCode, 
	SUM(TurnOver)	  AS Turnover,   
	SUM(Winlost)	  AS Winlost,  
	SUM(LicenseeWL)   AS LicenseeWL,
	SUM(Comm) 		  AS Comm,
	SUM(PlayerComm)   AS PlayerComm, 
	SUM(AmtDueto3rd)  AS AmtDueto3rd,
	SUM(Betcount)	  AS Betcount,
	
	--BaseEUR  
	CAST(SUM(TurnOverEUR)			AS MONEY)	AS TurnoverEUR,   
	CAST(SUM(WinlostEUR)			AS MONEY)	AS WinlostEUR,  
	CAST(SUM(LicenseeWLEUR) 		AS MONEY)	AS LicenseeWLEUR,
	CAST(SUM(CommEUR) 				AS MONEY)	AS CommEUR,
	CAST(SUM(PlayerCommEUR) 		AS MONEY)	AS PlayerCommEUR,
	CAST(SUM(AmtDueto3rdEUR) 		AS MONEY)	AS AmtDueto3rdEUR,
	--BaseUSD  
	CAST(SUM(TurnOverUSD)			AS MONEY)	AS TurnoverUSD,   
	CAST(SUM(WinlostUSD)			AS MONEY)	AS WinlostUSD,  
	CAST(SUM(LicenseeWLUSD) 		AS MONEY)	AS LicenseeWLUSD,
	CAST(SUM(CommUSD) 				AS MONEY)	AS CommUSD,
	CAST(SUM(PlayerCommUSD) 		AS MONEY)	AS PlayerCommUSD,
	CAST(SUM(AmtDueto3rdUSD) 		AS MONEY)	AS AmtDueto3rdUSD,
	--BaseGBP
	CAST(SUM(TurnOverGBP)			AS MONEY)	AS TurnoverGBP,   
	CAST(SUM(WinlostGBP)			AS MONEY)	AS WinlostGBP,  
	CAST(SUM(LicenseeWLGBP) 		AS MONEY)	AS LicenseeWLGBP,
	CAST(SUM(CommGBP) 				AS MONEY)	AS CommGBP,
	CAST(SUM(PlayerCommGBP) 		AS MONEY)	AS PlayerCommGBP,
	CAST(SUM(AmtDueto3rdGBP) 		AS MONEY)	AS AmtDueto3rdGBP
FROM	
	#SAgWinLoss w   
	INNER JOIN bodb_licensee.dbo.licenseecustinfo c WITH (NOLOCK) ON w.custid = c.custid	
GROUP BY   
	w.custid, c.username,c.username2  , 
	w.Currency,
	Productcode
	
ORDER BY c.username

DROP TABLE #SAgWinLoss
 
END
GO
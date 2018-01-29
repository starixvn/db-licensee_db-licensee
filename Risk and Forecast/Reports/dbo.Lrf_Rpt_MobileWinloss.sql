/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_MobileWinloss]   
	@LicenseeID		INT,
	@UserID			INT,
	@CurrencyID		INT = 0,
	@FromDate		SMALLDATETIME,  
	@ToDate			SMALLDATETIME,   
	@showSB			BIT = 0,  
	@ShowRB			BIT = 0,  
	@ShowNG			BIT = 0, 
	@ShowBA			BIT = 0,
	@ShowVS			BIT = 0,
	@ShowBG			BIT = 0,
	@ShowVB			BIT = 0,
	@PlatformType	TINYINT = 1, 
	@MoveBetsDay	SMALLDATETIME,
	@drawfilter		SMALLINT = 1  ,
	@excludeTest	BIT = 0,
	@Debug			BIT = 0
AS

/*  Created: Jim
	Date: 2012-02-02
    Task : Mobile WinLoss Report 
    DB: DBEXT.bodb02  
   
    Revisions:  
		- 20120214@Jim: change to use table ExchangeDaily by use function Lrf_f_GetExchangeDaily 
		- 20120529@Henry: enhance performance
		- 20120730@Jim: add playercomm value 
		- 20120814@Henry: add ShowLiveCasino 
		- 20120816@Henry: include betfrom "l" for smartphone
		- 20120905@Jim: add virtual sport
		- 20121004@Jim: replace @currency input param by @currencyID
		- 20121128@Henry: use new table LicenseeBATransaction_active to get bettrans BA tickets
		- 20130109@Henry: Split Mobile to WAP & Smartphone
		- 20130225@Jim: support RNG Casino, Bingo 
		- 20130414@Jim: support USD base currency 
		- 20130516@Tom.Vo: Allow viewing customer list
		- 20130618@Jim: Restrict permission of Licensee Users by currency
		- 20130809@Jim: offer Virtual Horse Racing
		- 20131007@Jim: offer Virtual Tennis
		- 20140620@Florent: offer 14 new bettypes and Sporting Solution (36 new bettypes)
		- 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
		- 20150127@Jim: support base on GBP Currency
		- 20150204@Don: remove index hint
		- 20150612@Jim: support MicroGaming
		- 20150623@Winnie: exclude 3 transactions SOLD/BOUGHT/BetTrade Commission
		- 20150814@Winnie: Keenocean reverse currency 
		- 20151001@Jim: remove MicroGaming
		- 20151228@Bobby: Remove RNG Casino
		- 20160219@Joseph: Implement @PlatformType param (#50939)
		- 20160331@Percy: Support Voidbridge single wallet [Redmine: #55057]
		- 20160413@Victor: support MKK currency code [Redmine: #55745]
		- 20180129@Harper: Remove LC from product list [RedmineID: #85965]

	Param's Explanation:  
	  + @PlatformType: 0: All  
					   1: Asia (d)  
					   2: New Asia (a)
					   3: Euro (e) (and Euro 12bet (u))
					   4: WAP (m)    
					   5: SMARTPHONE (s,l)  
	  +	@drawfilter: 'No Draw' filter is supportted (1:Normal 2:No Draw 3:No Draw for Turnover only)
	  + @IsOld: 0 - query in table rptLicWinloss2, 1 - query in table rptLicWinloss_old
	  + @excludeTest: remove currency UUS
	  + @showSB: Show SportsBook bets
	  + @ShowRB: Show RB bets
	  + @ShowNG: Show Number game bets
	  + @ShowBA: Show Bet Aggregator bets (combined WITH Sportsbook or Number Game)	 
	  + @ShowVS: Show Virtual Sports
	  + @ShowBG: Show Bingo
	  + @ShowVB: Show Voidbridge
	  + @MoveBetsDay: The day we move tickets to bettrans14
*/
    
BEGIN      

	SET NOCOUNT ON

	IF DATEDIFF(MONTH, @FromDate, @ToDate) > 1
		RETURN

	CREATE TABLE #WinLoss
	(
		CustID			INT,  
		Currency		INT ,
		Turnover		MONEY, 
		Winlost			MONEY, 
		LicenseeWL		MONEY,
		WinlossRB		MONEY,
		AmtDueToBA		MONEY,
		AmtDueToRB		MONEY,
		CommBA			MONEY,
		CommRB			MONEY,
		playercomm		MONEY,
		Company			MONEY,
	
		TurnOverEUR		MONEY,   	
		WinlostEUR		MONEY,  
		LicenseeWLEUR	MONEY,
		WinlossRBEUR	MONEY,
		AmtDueToBAEUR	MONEY,
		AmtDueToRBEUR	MONEY,
		CommBAEUR		MONEY,
		CommRBEUR		MONEY,
		PlayerCommEUR 	MONEY,	
		CompanyEUR		MONEY,
	
		TurnOverUSD		MONEY,   	
		WinlostUSD		MONEY,  
		LicenseeWLUSD	MONEY,
		WinlossRBUSD	MONEY,
		AmtDueToBAUSD	MONEY,
		AmtDueToRBUSD	MONEY,
		CommBAUSD		MONEY,
		CommRBUSD		MONEY,
		PlayerCommUSD 	MONEY,	
		CompanyUSD		MONEY,
	
		TurnOverGBP		MONEY,   	
		WinlostGBP		MONEY,  
		LicenseeWLGBP	MONEY,
		WinlossRBGBP	MONEY,
		AmtDueToBAGBP	MONEY,
		AmtDueToRBGBP	MONEY,
		CommBAGBP		MONEY,
		CommRBGBP		MONEY,
		PlayerCommGBP 	MONEY,	
		CompanyGBP		MONEY,

		BetCount		BIGINT
	)
	DECLARE @sporttype	TABLE (sporttype INT)
	DECLARE @bettype	TABLE (bettype INT PRIMARY KEY)
	DECLARE @tempAg		TABLE (custID INT, Currency INT)
	DECLARE @TempFromDate	DATETIME 
	DECLARE @TempToDate		DATETIME 
	DECLARE @MaxOldDate		DATETIME
	DECLARE @VNDCurrencyName	VARCHAR(20)
	DECLARE @FDate DATETIME, @TDate DATETIME

	--to Deal WITH Parameter Sniffing
	SELECT	@FDate = @FromDate,
			@TDate = @ToDate
	 
	SELECT	@VNDCurrencyName = currency
	FROM	exchange (NOLOCK)
	WHERE	ExchangeId = 51

	SELECT	currencyID, LicenseeID
	INTO	#currency
	FROM	dbo.Lrf_f_GetCurrencybyUser(@licenseeID, @userID, 1) -- System is default=1 (LRF)
	WHERE	(@CurrencyID = 0  OR (@CurrencyID <> 0 AND CurrencyID = @CurrencyID))

	INSERT INTO @tempAg(custID, currency) 
	SELECT custID, currency 
	FROM 
		bodb_Licensee.dbo.f_SelLicenseeCust(@licenseeID) lc
		INNER JOIN #Currency c ON lc.LicenseeID = c.LicenseeID AND lc.Currency = c.CurrencyID
	WHERE	(@excludeTest = 0 OR (@excludeTest = 1 AND Currency <> 20))	
	
	DROP TABLE #Currency 

	DECLARE @Exchange TABLE
	(
		ExchangeDate	SMALLDATETIME,
		ExchangeId		INT,
		EUR				FLOAT,
		USD				FLOAT,
		GBP				FLOAT,
		Code			VARCHAR(10),
		PRIMARY KEY (ExchangeDate, ExchangeId)
	)

	IF @ShowSB = 1  
		INSERT INTO @sporttype(sporttype) VALUES (0)	

	IF @ShowRB = 1  
	BEGIN
		INSERT INTO @sporttype(Sporttype) VALUES (151)

		INSERT INTO @bettype(bettype)
		SELECT	typeid FROM bettype (NOLOCK)
		WHERE	typeid BETWEEN 31 AND 33
	END

	IF @ShowNG = 1	
	BEGIN
		INSERT INTO @sporttype(Sporttype) VALUES (161)  
	
		INSERT INTO @bettype(bettype)
		SELECT	typeid FROM bettype (NOLOCK)
		WHERE	typeid BETWEEN 81 AND 120
	END	

	IF @ShowVS = 1	
	BEGIN
		INSERT INTO @sporttype(Sporttype) VALUES (180)
	
		INSERT INTO @bettype(bettype)
		SELECT	typeid FROM bettype (NOLOCK)
		WHERE	typeid BETWEEN 1201 AND 1299
	END

	IF @ShowBG = 1	
	BEGIN
		INSERT INTO @sporttype(Sporttype) VALUES (252)
	
		INSERT INTO @bettype(bettype)
		SELECT	typeid FROM bettype (NOLOCK)
		WHERE	typeid = 73
	END

	IF @showVB = 1
	BEGIN
		INSERT INTO @sporttype(Sporttype) VALUES (212)
	
		INSERT INTO @bettype(bettype)
		SELECT	typeid FROM bettype (NOLOCK)
		WHERE	typeid BETWEEN 4001 AND 7999
	END

	INSERT INTO @Exchange (exchangedate, exchangeid, eur, usd, gbp, code)
	SELECT	exchangedate, exchangeid, eur, usd, gbp, code
	FROM	Lrf_f_GetExchangeDaily(@FDate, @TDate)
	WHERE	exchangeid IN (SELECT Currency FROM @TempAg)	

	IF @TDate > @MoveBetsDay
	BEGIN
		IF @FDate <= @MoveBetsDay 
			SET @TempFromDate =  DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @FDate
	
		IF @ShowBA = 1
		BEGIN
			INSERT INTO #WinLoss 
			(	
				CustID, Currency, 
				Turnover, Winlost, LicenseeWL, WinlossRB, AmtDueToBA, AmtDueToRB, CommBA, CommRB, playercomm, Company, 
				TurnOverEUR, WinlostEUR, LicenseeWLEUR, WinlossRBEUR, AmtDueToBAEUR, AmtDueToRBEUR, CommBAEUR, CommRBEUR, PlayerCommEUR, CompanyEUR, 
				TurnOverUSD, WinlostUSD, LicenseeWLUSD, WinlossRBUSD, AmtDueToBAUSD, AmtDueToRBUSD, CommBAUSD, CommRBUSD, PlayerCommUSD, CompanyUSD, 
				TurnOverGBP, WinlostGBP, LicenseeWLGBP, WinlossRBGBP, AmtDueToBAGBP, AmtDueToRBGBP, CommBAGBP, CommRBGBP, PlayerCommGBP, CompanyGBP, 
				BetCount
			)

			SELECT 
				b.custid,
				b.currency,

				SUM(stake
						*
						CASE WHEN @drawfilter IN (2,3) THEN
							CASE
								WHEN b.statusID = 111 THEN 0
								WHEN (b.statusID = 112 OR b.statusID = 113) AND ABS(modds) = 0.25 AND b.bettype IN (1,3,7,8,17,18) THEN 0.5
								ELSE 1 END
						ELSE 1 END
					) AS turnover,
				SUM(b.winlost - b.actual_stake) AS Winlost,	
				0 AS LicenseeWL,
				0 AS WinlossRB,
				- SUM (b.winlost - b.actual_stake + b.awinlost + b.comm) AS AmountDueToBA,
				0 AS AmountDueToRB,
				SUM (b.comm) AS CommBA,
				0 AS CommRB,
				SUM(b.playercomm) AS PlayerComm,
				0 AS Company,
				--EUR
				SUM(stake
						*
						CASE WHEN @drawfilter IN (2,3) THEN
							CASE
								WHEN b.statusID = 111 THEN 0
								WHEN (b.statusID = 112 OR b.statusID = 113) AND ABS(modds) = 0.25 AND b.bettype IN (1,3,7,8,17,18) THEN 0.5
								ELSE 1 END
						ELSE 1 END
						* e.EUR
					) AS turnoverEUR,
				SUM((b.winlost - b.actual_stake)*e.EUR) AS WinlostEUR,		
				0 AS LicenseeWLEUR,
				0 AS WinlossRBEUR,
				- SUM ((b.winlost - b.actual_stake + b.awinlost + b.comm ) * e.EUR) AS AmountDueToBAEUR,
				0 AS AmountDueToRBEUR,
				SUM (b.comm * e.EUR) AS CommBAEUR,
				0 AS CommRBEUR,
				SUM(b.playercomm * e.EUR) AS PlayerCommEUR,
				0 AS CompanyEUR,
				--USD
				SUM(stake
						*
						CASE WHEN @drawfilter IN (2,3) THEN
							CASE
								WHEN b.statusID = 111 THEN 0
								WHEN (b.statusID = 112 OR b.statusID = 113) AND ABS(modds) = 0.25 AND b.bettype IN (1,3,7,8,17,18) THEN 0.5
								ELSE 1 END
						ELSE 1 END
						* e.USD
					) AS turnoverUSD,
				SUM((b.winlost - b.actual_stake)*e.USD) AS WinlostUSD,		
				0 AS LicenseeWLUSD,
				0 AS WinlossRBUSD,
				- SUM ((b.winlost - b.actual_stake + b.awinlost + b.comm) * e.USD) AS AmountDueToBAUSD,
				0 AS AmountDueToRBUSD,
				SUM (b.comm * e.USD) AS CommBAUSD,
				0 AS CommRBUSD,
				SUM(b.playercomm * e.USD) AS PlayerCommUSD,
				0 AS CompanyUSD,
				--GBP
				SUM(stake
						*
						CASE WHEN @drawfilter IN (2,3) THEN
							CASE
								WHEN b.statusID = 111 THEN 0
								WHEN (b.statusID = 112 OR b.statusID = 113) AND ABS(modds) = 0.25 AND b.bettype IN (1,3,7,8,17,18) THEN 0.5
								ELSE 1 END
						ELSE 1 END
						* e.GBP
					) turnoverGBP,
				SUM((b.winlost - b.actual_stake)*e.GBP) AS WinlostGBP,		
				0 AS LicenseeWLGBP,
				0 AS WinlossRBGBP,
				- SUM ((b.winlost - b.actual_stake + b.awinlost + b.comm) * e.GBP) AS AmountDueToBAGBP,
				0 AS AmountDueToRBGBP,
				SUM (b.comm * e.GBP) AS CommBAGBP,
				0 AS CommRBGBP,
				SUM(b.playercomm * e.GBP ) AS PlayerCommGBP,
				0 AS CompanyGBP,
			
				COUNT(CASE WHEN @drawfilter = 2 AND b.statusID = 111 THEN NULL ELSE b.transid END) AS BetCount
				/*
				COUNT(b.transid)
					* CASE WHEN @drawfilter = 2 THEN
							CASE WHEN b.statusID = 111 THEN 0
							ELSE 1 END
						ELSE 1 END
					   BetCount
				*/
			FROM
				dbo.bettrans b WITH (NOLOCK)
				INNER JOIN @TempAg tma ON tma.CustID = b.recommend AND b.currency = tma.currency
				INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction_active BA WITH (NOLOCK) ON tma.custid = BA.recommend AND b.transid = BA.transid 	 	
				LEFT JOIN @Exchange e ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
			WHERE
				b.statusID  IN (111, 112, 113)
				AND b.bettype NOT IN (901,902,903)
				AND b.winlostdate BETWEEN @TempFromDate AND @TDate
				AND 1 = CASE @PlatformType 
							WHEN 1 THEN CASE WHEN b.betfrom = 'd' THEN 1 ELSE 0 END
							WHEN 2 THEN CASE WHEN b.betfrom = 'a' THEN 1 ELSE 0 END
							WHEN 3 THEN CASE WHEN b.betfrom IN ('e','u') THEN 1 ELSE 0 END
							WHEN 4 THEN CASE WHEN b.betfrom = 'm' THEN 1 ELSE 0 END
							WHEN 5 THEN CASE WHEN b.betfrom IN ('s','l') THEN 1 ELSE 0 END
							ELSE 1 END
			GROUP BY b.currency, b.statusID, b.custid	
		END
	
		IF @ShowSB = 1
		BEGIN
			INSERT INTO #WinLoss
			(
				CustID, Currency, 
				Turnover, Winlost, LicenseeWL, WinlossRB, AmtDueToBA, AmtDueToRB, CommBA, CommRB, playercomm, Company, 
				TurnOverEUR, WinlostEUR, LicenseeWLEUR, WinlossRBEUR, AmtDueToBAEUR, AmtDueToRBEUR, CommBAEUR, CommRBEUR, PlayerCommEUR, CompanyEUR, 
				TurnOverUSD, WinlostUSD, LicenseeWLUSD, WinlossRBUSD, AmtDueToBAUSD, AmtDueToRBUSD, CommBAUSD, CommRBUSD, PlayerCommUSD, CompanyUSD, 
				TurnOverGBP, WinlostGBP, LicenseeWLGBP, WinlossRBGBP, AmtDueToBAGBP, AmtDueToRBGBP, CommBAGBP, CommRBGBP, PlayerCommGBP, CompanyGBP,
				BetCount
			)
			SELECT 
				b.custid,
				tma.currency,
			
				SUM(CASE WHEN b.bettype IN (33,34) AND b.liveawayscore = 0 THEN b.stake/2 ELSE b.stake END
						*
						CASE WHEN @drawfilter IN (2,3) THEN
							CASE
								WHEN b.statusID = 111 THEN 0
								WHEN (b.statusID = 112 OR b.statusID = 113) AND ABS(modds) = 0.25 AND b.bettype IN (1,3,7,8,17,18) THEN 0.5
								ELSE 1 END
						ELSE 1 END
					) AS turnover,
				SUM(b.winlost-b.actual_stake) AS Winlost,	
				- SUM(CASE WHEN (b.bettype NOT BETWEEN 31 AND 33) THEN (b.winlost - b.actual_stake) ELSE 0 END) AS LicenseeWL,
				SUM(CASE WHEN b.bettype BETWEEN 31 AND 33 THEN b.awinlost ELSE 0 END) AS WinlossRB,
				0 AS AmountDueToBA,
				- SUM(CASE WHEN b.bettype BETWEEN 31 AND 33 THEN (b.winlost - b.actual_stake + awinlost + comm) ELSE 0 END) AS AmountDueToRB,
				0 AS CommBA,
				SUM(CASE WHEN b.bettype BETWEEN 31 AND 33 THEN comm ELSE 0 END) AS CommRB,
				SUM(b.playercomm) AS PlayerComm,
				- SUM(CASE WHEN b.bettype NOT BETWEEN 31 AND 33 THEN (b.awinlost + b.winlost - b.actual_stake + b.comm) ELSE 0 END) AS Company,
				--EUR
				SUM(CASE WHEN b.bettype IN (33,34) AND b.liveawayscore = 0 THEN b.stake/2 ELSE b.stake END
						*
						CASE WHEN @drawfilter IN (2,3) THEN
							CASE
								WHEN b.statusID = 111 THEN 0
								WHEN (b.statusID = 112 OR b.statusID = 113) AND ABS(modds) = 0.25 AND b.bettype IN (1,3,7,8,17,18) THEN 0.5
								ELSE 1 END
						ELSE 1 END
						* e.EUR
					) AS turnoverEUR,
				SUM((b.winlost-b.actual_stake)*e.EUR) AS WinlostEUR,	
				- SUM(CASE WHEN (b.bettype NOT BETWEEN 31 AND 33) THEN (b.winlost - b.actual_stake) ELSE 0 END * e.EUR) AS LicenseeWLEUR,
				SUM(CASE WHEN b.bettype BETWEEN 31 AND 33 THEN b.awinlost ELSE 0 END * e.EUR) AS WinlossRBEUR,
				0 AS AmountDueToBAEUR,
				- SUM(CASE WHEN b.bettype BETWEEN 31 AND 33 THEN (b.winlost - b.actual_stake + awinlost + comm) ELSE 0 END * e.EUR) AS AmountDueToRBEUR,
				0 AS CommBAEUR,
				SUM(CASE WHEN b.bettype BETWEEN 31 AND 33 THEN comm ELSE 0 END * e.EUR) AS CommRBEUR,
				SUM(b.playercomm * e.EUR) AS PlayerCommEUR,
				- SUM(CASE WHEN b.bettype NOT BETWEEN 31 AND 33 THEN (b.awinlost + b.winlost - b.actual_stake + b.comm) ELSE 0 END * e.EUR) AS CompanyEUR,
				--USD
				SUM(CASE WHEN b.bettype IN (33,34) AND b.liveawayscore = 0 THEN b.stake/2 ELSE b.stake END
						*
						CASE WHEN @drawfilter IN (2,3) THEN
							CASE
								WHEN b.statusID = 111 THEN 0
								WHEN (b.statusID = 112 OR b.statusID = 113) AND ABS(modds) = 0.25 AND b.bettype IN (1,3,7,8,17,18) THEN 0.5
								ELSE 1 END
						ELSE 1 END
						* e.USD
					) AS turnoverUSD,
				SUM((b.winlost-b.actual_stake)*e.USD) AS WinlostUSD,	
				- SUM(CASE WHEN (b.bettype NOT BETWEEN 31 AND 33)  THEN (b.winlost - b.actual_stake) ELSE 0 END * e.USD) AS LicenseeWLUSD ,
				SUM(CASE WHEN b.bettype BETWEEN 31 AND 33 THEN b.awinlost ELSE 0 END * e.USD) AS WinlossRBUSD,
				0 AS AmountDueToBAUSD,
				- SUM(CASE WHEN b.bettype BETWEEN 31 AND 33 THEN (b.winlost - b.actual_stake + awinlost + comm) ELSE 0 END * e.USD) AS AmountDueToRBUSD,
				0 AS CommBAUSD,
				SUM(CASE WHEN b.bettype BETWEEN 31 AND 33 THEN comm ELSE 0 END * e.USD) AS CommRBUSD,
				SUM(b.playercomm * e.USD) AS PlayerCommUSD,
				- SUM(CASE WHEN b.bettype NOT BETWEEN 31 AND 33 THEN (b.awinlost + b.winlost - b.actual_stake + b.comm) ELSE 0 END * e.USD) AS CompanyUSD ,
				--GBP
				SUM(CASE WHEN b.bettype IN (33,34) AND b.liveawayscore = 0 THEN b.stake/2 ELSE b.stake END
						*
						CASE WHEN @drawfilter IN (2,3) THEN
							CASE
								WHEN b.statusID = 111 THEN 0
								WHEN (b.statusID = 112 OR b.statusID = 113) AND ABS(modds) = 0.25 AND b.bettype IN (1,3,7,8,17,18) THEN 0.5
								ELSE 1 END
						ELSE 1 END
						* e.GBP
					) AS turnoverGBP,
				SUM((b.winlost-b.actual_stake)*e.GBP) AS WinlostGBP,	
				- SUM(CASE WHEN (b.bettype NOT BETWEEN 31 AND 33)  THEN (b.winlost - b.actual_stake) ELSE 0 END * e.GBP) AS LicenseeWLGBP ,
				SUM(CASE WHEN b.bettype BETWEEN 31 AND 33 THEN b.awinlost ELSE 0 END * e.GBP) AS WinlossRBGBP,
				0 AS AmountDueToBAGBP,
				- SUM(CASE WHEN b.bettype BETWEEN 31 AND 33 THEN (b.winlost - b.actual_stake + awinlost + comm) ELSE 0 END * e.GBP) AS AmountDueToRBGBP,
				0 AS CommBAGBP,
				SUM(CASE WHEN b.bettype BETWEEN 31 AND 33 THEN comm ELSE 0 END * e.GBP) AS CommRBGBP,
				SUM(b.playercomm * e.GBP) AS PlayerCommGBP,
				- SUM(CASE WHEN b.bettype NOT BETWEEN 31 AND 33 THEN (b.awinlost + b.winlost - b.actual_stake + b.comm) ELSE 0 END * e.GBP) AS CompanyGBP ,
				
				COUNT(CASE WHEN @drawfilter = 2 AND b.statusID = 111 THEN NULL ELSE b.transid END) AS BetCount
				/*
				COUNT(b.transid) 
				* CASE WHEN @drawfilter = 2 THEN
						CASE WHEN b.statusID = 111 THEN 0
						ELSE 1 END
					ELSE 1 END
				   BetCount
				*/
			FROM
				dbo.bettrans b WITH (NOLOCK)
				INNER JOIN @tempAg tma ON tma.CustID = b.recommend AND b.currency = tma.currency
				LEFT JOIN @Exchange e  ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
			WHERE
				b.statusID IN (111, 112, 113)
				AND b.winlostdate BETWEEN @TempFromDate AND @TDate
				AND
				(
					b.bettype < 31
					OR b.bettype BETWEEN 121 AND 999
					OR b.Bettype BETWEEN 1301 and 1399 --new tennis's bettypes
				) 
				AND b.bettype NOT IN (901, 902, 903)
				AND b.tpositiontaking <> 0
				AND 1 = CASE @PlatformType 
							WHEN 1 THEN CASE WHEN b.betfrom = 'd' THEN 1 ELSE 0 END
							WHEN 2 THEN CASE WHEN b.betfrom = 'a' THEN 1 ELSE 0 END
							WHEN 3 THEN CASE WHEN b.betfrom IN ('e','u') THEN 1 ELSE 0 END
							WHEN 4 THEN CASE WHEN b.betfrom = 'm' THEN 1 ELSE 0 END
							WHEN 5 THEN CASE WHEN b.betfrom IN ('s','l') THEN 1 ELSE 0 END
							ELSE 1 END
			GROUP BY tma.currency, b.statusID, b.custid	   
		END

		IF (@ShowRB = 1 OR @ShowNG = 1 OR @ShowVS = 1 OR @ShowBG = 1 OR @ShowVB = 1)
		BEGIN
			INSERT INTO #WinLoss
			(
				CustID, Currency, 
				Turnover, Winlost, LicenseeWL, WinlossRB, AmtDueToBA, AmtDueToRB, CommBA, CommRB, playercomm, Company, 
				TurnOverEUR, WinlostEUR, LicenseeWLEUR, WinlossRBEUR, AmtDueToBAEUR, AmtDueToRBEUR, CommBAEUR, CommRBEUR, PlayerCommEUR, CompanyEUR, 
				TurnOverUSD, WinlostUSD, LicenseeWLUSD, WinlossRBUSD, AmtDueToBAUSD, AmtDueToRBUSD, CommBAUSD, CommRBUSD, PlayerCommUSD, CompanyUSD,
				TurnOverGBP, WinlostGBP, LicenseeWLGBP, WinlossRBGBP, AmtDueToBAGBP, AmtDueToRBGBP, CommBAGBP, CommRBGBP, PlayerCommGBP, CompanyGBP,	
				BetCount
			)
			SELECT 
				b.custid,
				tma.currency,

				SUM(CASE WHEN b.bettype IN (33, 34) AND b.liveawayscore = 0 THEN b.stake/2 ELSE b.stake END
						*
						CASE WHEN @drawfilter IN (2,3) THEN
							CASE
								WHEN b.statusID = 111 THEN 0
								WHEN (b.statusID = 112 OR b.statusID = 113) AND ABS(modds) = 0.25 AND b.bettype IN (1,3,7,8,17,18) THEN 0.5
								ELSE 1 END
						ELSE 1 END
					) AS turnover,
				SUM(b.winlost-b.actual_stake) AS Winlost,	
				- SUM(CASE WHEN (b.bettype NOT BETWEEN 31 AND 33) THEN (b.winlost - b.actual_stake) ELSE 0 END) AS LicenseeWL,
				SUM(CASE WHEN b.bettype BETWEEN 31 AND 33 THEN b.awinlost ELSE 0 END) AS WinlossRB,
				0 AS AmountDueToBA,
				- SUM(CASE WHEN b.bettype BETWEEN 31 AND 33 THEN (b.winlost - b.actual_stake + awinlost + comm) ELSE 0 END) AS AmountDueToRB,
				0 AS CommBA,
				SUM(CASE WHEN b.bettype BETWEEN 31 AND 33 THEN comm ELSE 0 END) AS CommRB,
				SUM(b.playercomm) AS PlayerComm,
				- SUM(CASE WHEN b.bettype NOT BETWEEN 31 AND 33 THEN (b.awinlost + b.winlost - b.actual_stake + b.comm) ELSE 0 END) AS Company,
				--EUR
				SUM(CASE WHEN b.bettype IN (33,34) AND b.liveawayscore = 0 THEN b.stake/2 ELSE b.stake END
						*
						CASE WHEN @drawfilter IN (2,3) THEN
							CASE
								WHEN b.statusID = 111 THEN 0
								WHEN (b.statusID = 112 OR b.statusID = 113) AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN 0.5
								ELSE 1 END
						ELSE 1 END
						* e.EUR
					) AS turnoverEUR,
				SUM((b.winlost-b.actual_stake) * e.EUR) AS WinlostEUR,	
				- SUM(CASE WHEN (b.bettype NOT BETWEEN 31 AND 33) THEN (b.winlost - b.actual_stake) ELSE 0 END * e.EUR) AS LicenseeWLEUR,
				SUM(CASE WHEN b.bettype BETWEEN 31 AND 33 THEN b.awinlost ELSE 0 END * e.EUR) AS WinlossRBEUR,
				0 AS AmountDueToBAEUR,
				- SUM(CASE WHEN b.bettype BETWEEN 31 AND 33 THEN (b.winlost - b.actual_stake + awinlost + comm) ELSE 0 END * e.EUR) AS AmountDueToRBEUR,
				0 AS CommBAEUR,
				SUM(CASE WHEN b.bettype BETWEEN 31 AND 33 THEN comm ELSE 0 END * e.EUR) AS CommRBEUR,
				SUM(b.playercomm * e.EUR) AS PlayerCommEUR,
				- SUM(CASE WHEN b.bettype NOT BETWEEN 31 AND 33 THEN (b.awinlost + b.winlost - b.actual_stake + b.comm) ELSE 0 END * e.EUR) AS CompanyEUR,
				--USD
				SUM(CASE WHEN b.bettype IN (33,34) AND b.liveawayscore = 0 THEN b.stake/2 ELSE b.stake END
						*
						CASE WHEN @drawfilter IN (2,3) THEN
							CASE
								WHEN b.statusID = 111 THEN 0
								WHEN (b.statusID = 112 OR b.statusID = 113) AND ABS(modds) = 0.25 AND b.bettype IN (1,3,7,8,17,18) THEN 0.5
								ELSE 1 END
						ELSE 1 END
						* e.USD
					) AS turnoverUSD,
				SUM((b.winlost-b.actual_stake) * e.USD) AS WinlostUSD,	
				- SUM(CASE WHEN (b.bettype NOT BETWEEN 31 AND 33) THEN (b.winlost - b.actual_stake) ELSE 0 END * e.USD) AS LicenseeWLUSD ,
				SUM(CASE WHEN b.bettype BETWEEN 31 AND 33 THEN b.awinlost ELSE 0 END * e.USD) AS WinlossRBUSD,
				0 AS AmountDueToBAUSD,
				- SUM(CASE WHEN b.bettype BETWEEN 31 AND 33 THEN (b.winlost - b.actual_stake + awinlost + comm) ELSE 0 END * e.USD) AS AmountDueToRBUSD,
				0 AS CommBAUSD,
				SUM(CASE WHEN b.bettype BETWEEN 31 AND 33 THEN comm  ELSE 0 END * e.USD) AS CommRBUSD,
				SUM(b.playercomm * e.USD) AS PlayerCommUSD,
				- SUM(CASE WHEN b.bettype NOT BETWEEN 31 AND 33 THEN (b.awinlost + b.winlost - b.actual_stake + b.comm) ELSE 0 END * e.USD) AS CompanyUSD ,
				--GBP
				SUM(CASE WHEN b.bettype IN (33,34) AND b.liveawayscore=0 THEN b.stake/2 ELSE b.stake END
						*
						CASE WHEN @drawfilter IN (2,3) THEN
							CASE
								WHEN b.statusID = 111 THEN 0
								WHEN (b.statusID = 112 OR b.statusID = 113) AND ABS(modds) = 0.25 AND b.bettype IN (1,3,7,8,17,18) THEN 0.5
								ELSE 1 END
						ELSE 1 END
						* e.GBP
					) turnoverGBP,
				SUM((b.winlost-b.actual_stake) * e.GBP) AS WinlostGBP,	
				- SUM(CASE WHEN (b.bettype NOT BETWEEN 31 AND 33) THEN (b.winlost - b.actual_stake) ELSE 0 END * e.GBP) AS LicenseeWLGBP ,
				SUM(CASE WHEN b.bettype BETWEEN 31 AND 33 THEN b.awinlost ELSE 0 END * e.GBP) AS WinlossRBGBP,
				0 AS AmountDueToBAGBP,
				- SUM ( CASE WHEN b.bettype BETWEEN 31 AND 33 THEN (b.winlost - b.actual_stake + awinlost + comm) ELSE 0 END * e.GBP) AS AmountDueToRBGBP,
				0 AS CommBAGBP,
				SUM(CASE WHEN b.bettype BETWEEN 31 AND 33 THEN comm  ELSE 0 END * e.GBP) AS CommRBGBP,
				SUM(b.playercomm * e.GBP) AS PlayerCommGBP,
				- SUM(CASE WHEN b.bettype NOT BETWEEN 31 AND 33 THEN (b.awinlost + b.winlost - b.actual_stake + b.comm) ELSE 0 END * e.GBP) AS CompanyGBP ,
				
				COUNT(CASE WHEN @drawfilter = 2 AND b.statusID = 111 THEN NULL ELSE b.transid END) AS BetCount
				/*
				COUNT(b.transid) 
				* CASE WHEN @drawfilter = 2 THEN
						CASE WHEN b.statusID = 111 THEN 0
						ELSE 1 END
					ELSE 1 END
				   BetCount
				*/
			FROM
				dbo.bettrans b WITH (NOLOCK)
				INNER JOIN @tempAg tma ON tma.CustID = b.recommend AND b.currency = tma.currency
				INNER JOIN @bettype bt ON b.bettype = bt.bettype
				LEFT JOIN  @Exchange e ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
			WHERE
				b.statusID IN (111, 112, 113)
				AND b.winlostdate BETWEEN @TempFromDate AND @TDate
				AND 1 = CASE @PlatformType 
							WHEN 1 THEN CASE WHEN b.betfrom = 'd' THEN 1 ELSE 0 END
							WHEN 2 THEN CASE WHEN b.betfrom = 'a' THEN 1 ELSE 0 END
							WHEN 3 THEN CASE WHEN b.betfrom IN ('e','u') THEN 1 ELSE 0 END
							WHEN 4 THEN CASE WHEN b.betfrom = 'm' THEN 1 ELSE 0 END
							WHEN 5 THEN CASE WHEN b.betfrom IN ('s','l') THEN 1 ELSE 0 END
							ELSE 1 END
			GROUP BY tma.currency, b.statusID, b.custid
		END
	END		
				
	IF @FDate <= @MoveBetsDay 
	BEGIN
		IF @TDate >= @MoveBetsDay
				SET @TempToDate = @MoveBetsDay
			ELSE
				SET @TempToDate = @TDate
		IF @ShowBA = 1 
		BEGIN
			INSERT INTO #WinLoss
			(
				CustID, Currency, 
				Turnover, Winlost, LicenseeWL, WinlossRB, AmtDueToBA, AmtDueToRB, CommBA, CommRB, playercomm, Company, 
				TurnOverEUR, WinlostEUR, LicenseeWLEUR, WinlossRBEUR, AmtDueToBAEUR, AmtDueToRBEUR, CommBAEUR, CommRBEUR, PlayerCommEUR, CompanyEUR, 
				TurnOverUSD, WinlostUSD, LicenseeWLUSD, WinlossRBUSD, AmtDueToBAUSD, AmtDueToRBUSD, CommBAUSD, CommRBUSD, PlayerCommUSD, CompanyUSD, 
				TurnOverGBP, WinlostGBP, LicenseeWLGBP, WinlossRBGBP, AmtDueToBAGBP, AmtDueToRBGBP, CommBAGBP, CommRBGBP, PlayerCommGBP, CompanyGBP,
				BetCount
			)
			SELECT 
				b.custid,
				b.currency,
				SUM(b.turnover
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111  THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
					ELSE 1 END
					) AS turnover,     
				SUM(b.winlost) AS Winlost,  
				0 AS LicenseeWL,
				0 AS WinlossRB,
				- SUM(b.winlost+b.awinlost+b.comm) AS AmountDueToBA,
				0 AS AmountDueToRB,
				SUM(comm) AS CommBA,
				0 AS CommRB,
				SUM(b.playercomm) AS PlayerComm, 
				0 AS Company,
				--EUR
				SUM(b.turnover
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111  THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
					ELSE 1 END
					* e.EUR
				) AS TurnOverEUR,     
				SUM(b.winlost * e.EUR) AS WinlostEUR,  
				0 AS LicenseeWLEUR,
				0 AS WinlossRBEUR,
				- SUM((b.winlost+b.awinlost+b.comm) * e.EUR) AS AmountDueToBAEUR,
				0 AS AmountDueToRBEUR,
				SUM(comm * e.EUR) AS CommBAEUR,
				0 AS CommRBEUR,
				SUM(b.playercomm * e.EUR) AS PlayerCommEUR, 
				0 AS CompanyEUR,
				--USD
				SUM(b.turnover
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111  THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
					ELSE 1 END
					* e.USD
				) AS TurnOverUSD,     
				SUM(b.winlost * e.USD) AS WinlostUSD,  
				0 AS LicenseeWLUSD,
				0 AS WinlossRBUSD,
				- SUM((b.winlost+b.awinlost+b.comm) * e.USD) AS AmountDueToBAUSD,
				0 AS AmountDueToRBUSD,
				SUM(comm * e.USD) AS CommBAUSD,
				0 AS CommRBUSD,
				SUM(b.playercomm * e.USD) AS PlayerCommUSD, 
				0 AS CompanyUSD,
				--GBP
				SUM(b.turnover
				*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111  THEN 0
						WHEN b.statusID IN (114,115) THEN 0.5
						ELSE 1 END
					ELSE 1 END
					* e.GBP
				) AS TurnOverGBP,     
				SUM(b.winlost * e.GBP) AS WinlostGBP,  
				0 AS LicenseeWLGBP,
				0 AS WinlossRBGBP,
				- SUM((b.winlost+b.awinlost+b.comm) * e.GBP) AS AmountDueToBAGBP,
				0 AS AmountDueToRBGBP,
				SUM(comm * e.GBP) AS CommBAGBP,
				0 AS CommRBGBP,
				SUM(b.playercomm * e.GBP ) AS PlayerCommGBP, 
				0 AS CompanyGBP,
				
				SUM(b.betcount)
				* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0 ELSE 1 END
				  ELSE 1 END
			FROM
				bodb_Licensee.dbo.rptLicWinloss2 b WITH ( NOLOCK )
				INNER JOIN @TempAg ag  ON b.recommend = ag.CustId AND b.Currency = ag.Currency
				LEFT JOIN  @Exchange e ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
			WHERE 
				b.Winlostdate BETWEEN @FDate AND @TempToDate  
				AND b.roleid = 1   
				AND b.statusID <> 101
				AND b.bettype NOT IN (901,902,903)
				AND ISNULL(b.isBA, 0) = 1
				AND 1 = CASE @PlatformType 
							WHEN 1 THEN CASE WHEN b.betfrom = 'd' THEN 1 ELSE 0 END
							WHEN 2 THEN CASE WHEN b.betfrom = 'a' THEN 1 ELSE 0 END
							WHEN 3 THEN CASE WHEN b.betfrom IN ('e','u') THEN 1 ELSE 0 END
							WHEN 4 THEN CASE WHEN b.betfrom = 'm' THEN 1 ELSE 0 END
							WHEN 5 THEN CASE WHEN b.betfrom IN ('s','l') THEN 1 ELSE 0 END
							ELSE 1 END		
			GROUP BY b.custid, b.currency, b.statusID	
			
		END
		IF (@showSB = 1 OR @ShowRB = 1 OR @ShowNG = 1 OR @ShowVS = 1 OR @ShowBG = 1 OR @ShowVB = 1)
		BEGIN
			INSERT INTO #WinLoss
			(
				CustID, Currency, 
				Turnover, Winlost, LicenseeWL, WinlossRB, AmtDueToBA, AmtDueToRB, CommBA, CommRB, playercomm, Company, 
				TurnOverEUR, WinlostEUR, LicenseeWLEUR, WinlossRBEUR, AmtDueToBAEUR, AmtDueToRBEUR, CommBAEUR, CommRBEUR, PlayerCommEUR, CompanyEUR, 
				TurnOverUSD, WinlostUSD, LicenseeWLUSD, WinlossRBUSD, AmtDueToBAUSD, AmtDueToRBUSD, CommBAUSD, CommRBUSD, PlayerCommUSD, CompanyUSD, 
				TurnOverGBP, WinlostGBP, LicenseeWLGBP, WinlossRBGBP, AmtDueToBAGBP, AmtDueToRBGBP, CommBAGBP, CommRBGBP, PlayerCommGBP, CompanyGBP,
				BetCount
			)
			SELECT 
				b.custid,
				b.currency,

				SUM(b.turnover
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111  THEN 0
							WHEN b.statusID IN (114, 115) THEN 0.5
							ELSE 1 END
					ELSE 1 END
				) AS Turnover,
				SUM(b.winlost) AS Winlost,
				- SUM(CASE WHEN b.sporttype <> 151 THEN b.winlost ELSE 0 END) AS LicenseeWL ,
				SUM(CASE WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END) AS WinlossRB,
				0 AS AmtDueToBA,
				- SUM(CASE WHEN b.sporttype = 151 THEN (b.winlost+b.awinlost+b.comm) ELSE 0 END) AS AmtDueToRB,
				0 AS CommBA,
				SUM(CASE WHEN b.sporttype = 151 THEN b.comm ELSE 0 END) AS CommRB,
				SUM(b.playercomm) AS PlayerComm,
				- SUM(CASE WHEN b.sporttype <> 151 THEN b.awinlost + b.winlost + b.comm ELSE 0 END) AS Company,
				--EUR
				SUM(b.turnover
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111  THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
					ELSE 1 END
					* e.EUR
				) AS TurnOverEUR,     
				SUM(b.winlost * e.EUR) AS WinlostEUR,
				- SUM(CASE WHEN b.sporttype <> 151 THEN b.winlost ELSE 0 END * e.EUR) AS LicenseeWLEUR,
				SUM(CASE WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END * e.EUR) AS WinlossRBEUR,
				0 AS AmtDueToBAEUR,
				- SUM(CASE WHEN b.sporttype = 151 THEN (b.winlost+b.awinlost+b.comm) ELSE 0 END * e.EUR) AS AmtDueToRBEUR,
				0 AS CommBAEUR,
				SUM(CASE WHEN b.sporttype = 151 THEN b.comm ELSE 0 END * e.EUR) AS CommRBEUR,
				SUM(b.playercomm * e.EUR) AS PlayerCommEUR,
				- SUM(CASE WHEN b.sporttype <> 151 THEN b.awinlost + b.winlost + b.comm ELSE 0 END * e.EUR) AS CompanyEUR,
				--USD
				SUM(b.turnover
						*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111  THEN 0
							WHEN b.statusID IN (114, 115) THEN 0.5
							ELSE 1 END
					ELSE 1 END
					* e.USD
				) AS TurnOverUSD,     
				SUM(b.winlost * e.USD) AS WinlostUSD,
				- SUM(CASE WHEN b.sporttype <> 151 THEN b.winlost ELSE 0 END * e.USD) AS LicenseeWLUSD ,
				SUM(CASE WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END * e.USD) AS WinlossRBUSD,
				0 AS AmtDueToBAUSD,
				- SUM(CASE WHEN b.sporttype = 151 THEN (b.winlost+b.awinlost+b.comm) ELSE 0 END * e.USD) AS AmtDueToRBUSD,
				0 AS CommBAUSD,
				SUM(CASE WHEN b.sporttype = 151 THEN b.comm ELSE 0 END * e.USD) AS CommRBUSD,
				SUM(b.playercomm * e.USD) AS PlayerCommUSD,
				- SUM(CASE WHEN b.sporttype <> 151 THEN b.awinlost + b.winlost + b.comm ELSE 0 END * e.USD) AS CompanyUSD,
				--GBP
				SUM(b.turnover
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111  THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
					ELSE 1 END
					* e.GBP
				) AS TurnOverGBP,     
				SUM(b.winlost * e.GBP) AS WinlostGBP,
				- SUM(CASE WHEN b.sporttype <> 151 THEN b.winlost ELSE 0 END * e.GBP) AS LicenseeWLGBP ,
				SUM(CASE WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END * e.GBP) AS WinlossRBGBP,
				0 AS AmtDueToBAGBP,
				- SUM(CASE WHEN b.sporttype = 151 THEN (b.winlost+b.awinlost+b.comm) ELSE 0 END * e.GBP) AS AmtDueToRBGBP,
				0 AS CommBAGBP,
				SUM(CASE WHEN b.sporttype = 151 THEN b.comm ELSE 0 END * e.GBP) AS CommRBGBP,
				SUM(b.playercomm * e.GBP) AS PlayerCommGBP,
				- SUM(CASE WHEN b.sporttype <> 151 THEN b.awinlost + b.winlost + b.comm ELSE 0 END * e.GBP) AS CompanyGBP,
				
				SUM(b.betcount)
				* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0 ELSE 1 END
				  ELSE 1 END
			FROM
				bodb_Licensee.dbo.rptLicWinloss2 b WITH (NOLOCK)
				INNER JOIN @TempAg ag   ON b.recommend = ag.CustId AND b.Currency = ag.Currency
				INNER JOIN @sporttype t ON b.sporttype = t.sporttype
				LEFT JOIN  @Exchange e  ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
			WHERE 		
				b.Winlostdate BETWEEN @FDate AND @TempToDate  
				AND b.roleid = 1   
				AND b.statusID <> 101 --exclude REJECT bets
				AND b.bettype NOT IN (901, 902, 903)
				AND ISNULL(b.isBA, 0) = 0
				AND 1 = CASE @PlatformType 
							WHEN 1 THEN CASE WHEN b.betfrom = 'd' THEN 1 ELSE 0 END
							WHEN 2 THEN CASE WHEN b.betfrom = 'a' THEN 1 ELSE 0 END
							WHEN 3 THEN CASE WHEN b.betfrom IN ('e','u') THEN 1 ELSE 0 END
							WHEN 4 THEN CASE WHEN b.betfrom = 'm' THEN 1 ELSE 0 END
							WHEN 5 THEN CASE WHEN b.betfrom IN ('s','l') THEN 1 ELSE 0 END
							ELSE 1 END	
			GROUP BY b.custid, b.currency, b.statusID			
		END
	END			


SELECT 
	c.Custid, 
	c.username, 
	SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2)) AS nickname,
	w.Currency ,   
	--case WHEN w.Currency IN (20,51) THEN e.currency ELSE e.Code END as CurrencyName,
	case 
		WHEN w.Currency =51 THEN @VNDCurrencyName 
		WHEN w.Currency =70 THEN 'MKK' 
		ELSE e.Code 
	END as CurrencyName,
	
		SUM(TurnOver)		AS Turnover,
		SUM(Winlost)		AS Winlost,
		SUM(LicenseeWL)		AS LicenseeWL,
		SUM(WinlossRB)		AS WinlossRB,

		SUM(CommBA)			AS CommBA,
		SUM(CommRB)			AS CommRB,	
		SUM(PlayerComm)		AS PlayerComm,
		SUM(AmtDuetoBA)		AS AmtDuetoBA,
		SUM(AmtDuetoRB)		AS AmtDuetoRB,
		SUM(Company)		AS Company,
	
		SUM(Betcount)		AS Betcount,
			
		--BASE EUR
		SUM(TurnOverEUR)	AS TurnoverEUR,
		SUM(WinlostEUR)		AS WinlostEUR,
		SUM(LicenseeWLEUR)	AS LicenseeWLEUR,
		SUM(WinlossRBEUR)	AS WinlossRBEUR,
		SUM(CommBAEUR)		AS CommBAEUR,
		SUM(CommRBEUR)		AS CommRBEUR,	
		SUM(PlayerCommEUR)	AS PlayerCommEUR,
		SUM(AmtDuetoBAEUR)	AS AmtDuetoBAEUR,
		SUM(AmtDuetoRBEUR)	AS AmtDuetoRBEUR,
		SUM(CompanyEUR)		AS CompanyEUR,
	
		--BASE USD
		SUM(TurnOverUSD)	AS TurnoverUSD,
		SUM(WinlostUSD)		AS WinlostUSD,
		SUM(LicenseeWLUSD)	AS LicenseeWLUSD,
		SUM(WinlossRBUSD)	AS WinlossRBUSD,
		SUM(CommBAUSD)		AS CommBAUSD,
		SUM(CommRBUSD)		AS CommRBUSD,	
		SUM(PlayerCommUSD)	AS PlayerCommUSD,
		SUM(AmtDuetoBAUSD)	AS AmtDuetoBAUSD,
		SUM(AmtDuetoRBUSD)	AS AmtDuetoRBUSD,
		SUM(CompanyUSD)		AS CompanyUSD,
		--BASE GBP
		SUM(TurnOverGBP)	AS TurnoverGBP,
		SUM(WinlostGBP)		AS WinlostGBP,
		SUM(LicenseeWLGBP)	AS LicenseeWLGBP,
		SUM(WinlossRBGBP)	AS WinlossRBGBP,
		SUM(CommBAGBP)		AS CommBAGBP,
		SUM(CommRBGBP)		AS CommRBGBP,	
		SUM(PlayerCommGBP)	AS PlayerCommGBP,
		SUM(AmtDuetoBAGBP)	AS AmtDuetoBAGBP,
		SUM(AmtDuetoRBGBP)	AS AmtDuetoRBGBP,
		SUM(CompanyGBP)		AS CompanyGBP
	FROM
		#WinLoss w 
		INNER JOIN bodb_licensee.dbo.licenseecustinfo c WITH (NOLOCK)  ON w.custid = c.custid
		INNER JOIN (SELECT DISTINCT ExchangeId, Code FROM @Exchange) e ON w.Currency = e.exchangeid
	GROUP BY
		c.Custid, w.Currency ,c.username, c.username2,
	CASE 
		WHEN w.Currency =51 THEN @VNDCurrencyName 
		WHEN w.Currency =70 THEN 'MKK' 
		ELSE e.Code 
	END 
	ORDER BY 5, 2

	DROP TABLE #WinLoss

END
GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_MobileWinloss] TO [bodbLicenseeNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_MobileWinloss] TO [vnteam] AS [dbo]
GO
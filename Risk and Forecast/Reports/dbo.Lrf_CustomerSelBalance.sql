/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet,bodbDownlineNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_CustomerSelBalance]
	@LicenseeID INT,
	@MoveBetsDay SMALLDATETIME,
	@FromDate SMALLDATETIME,
	@ToDate SMALLDATETIME,
	@AgentList	VARCHAR(MAX)
AS
/*
Created: 20101203@Henry
Task: Get Agent Balance
DB: DB052.bodb02
Original: Age_CustomerSelBalance_Ag
Param's Explanation:  
	+ @IsOld: 0 - query IN table rptLicWinloss, 1 - query IN table rptLicWinloss_old. 
Revisions:
	- 20110225@Henry: Allow to choose all type of licensee AND all currency + suppport based currency
	- 20110513@Henry: change bettype to new range
	- 20110609@Henry: change rptLicWinlost to rptLicWinloss
	- 20110711@Henry: show Comm, Amt Due to for each 3rd party product: BA, Racing. Show Licensee W/L (remove PT)
	- 20110729@Henry: offer 3 new bettypes for Number Game
	- 20111013@Henry: Change to use rptLicWinloss2
	- 20111212@Jim:   Change condition bettype<19000
	- 20120214@Jim: change table ExchangeDaily by function Lrf_f_GetExchangeDaily  
	- 20120305@Henry: enhance performance
	- 20120319@Don: reduce IO by using covering index
	- 20120724@Jim: add player commission value 
	- 20121004@Jim: replace @currencyname input param by @currencyID
	- 20130417@Scott: Support RNG Casino and Bingo  
	- 20130529@Daniel: Fix bug regconize BA tickets caused by "Support RNG Casino and Bingo"
	- 20130514@Jim: Restrict permission of Licensee Users by currency
	- 20130619@Daniel: Fix more bug regconize BA tickets
	- 20130620@Jim: fix bug wrong value Licensee Winloss of Racing
	- 20130718@Jim: remove status Suspended
	- 20130809@Jim: offer Virtual Horse Racing
	- 20131007@Jim: offer Virtual Tennis
	- 20140207@Florent: Offer Keno
	- 20140509@Florent: Fix bug get wrong currency rate
	- 20140530@Francis: Enhance performance
	- 20140620@Florent: offer 14 new bettypes and Sporting Solution (36 new bettypes)
	- 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
	- 20150128@JIm: base on GBP
	- 20150612@Jim: support MicroGaming
	- 20150626@Winnie: support bettrade
	- 20151001@Jim: remove MicroGaming
	- 20151228@Bobby: Remove RNG Casino
	- 20160118@Victor: Exclude Bettrade tickets on AmountDueToBA column [Redmine: 51053]
	- 20160125@Victor: Fix incorrect formula of AmountDueToBettrade column [Redmine: 51053]
	- 20160331@Walter: Support Voidbridge single wallet [Redmine: #55057]
	- 20160727@Jim:  LRF - Commercial terms changed for Bet Trade [Redmine: #61342]
	- 20161022@Jim:move table to bodb_licenseereport [RedmineID :#60449]
	- 20161115@Jim: LRF - Integrate new product Fishing World [RedmineID : #66737]
	- 20170228@Paul: Get @AgentList by web instead of @UserId, @CurrencyID, @LicenseeID, Remove @LicenseeType [Redmine: #71679]
	- 20170329@Paul: Implement Cash Out [RedmineID: #71727]
	- 20180205@Harper: Remove LC from product list [RedmineID: #85965]
	- 20180418@Amanda: LAP - Update VB bet type range and integrate PP [RedmineID: #92318]
	- 20180808@Amanda: Remove Racing, Bingo and Old(@IsOld) data [RedmineID: #99378]
*/

BEGIN
	SET NOCOUNT ON


	DECLARE @UserName VARCHAR(50),
			@SelectedMonthLicenseeWL MONEY,
			@SelectedMonthLicenseeWLUSD MONEY,
			@SelectedMonthLicenseeWLEUR MONEY,
			@SelectedMonthLicenseeWLGBP MONEY,
			@SelectedMonthAmtDuetoBA MONEY,
			@SelectedMonthAmtDuetoBAUSD MONEY,
			@SelectedMonthAmtDuetoBAEUR MONEY,
			@SelectedMonthAmtDuetoBAGBP MONEY,
			@SelectedMonthCommBA MONEY,
			@SelectedMonthCommBAUSD MONEY,
			@SelectedMonthCommBAEUR MONEY,
			@SelectedMonthCommBAGBP MONEY,
			@SelectedMonthPlayerComm MONEY,
			@SelectedMonthPlayerCommUSD MONEY,
			@SelectedMonthPlayerCommEUR MONEY,
			@SelectedMonthPlayerCommGBP MONEY,
			@SelectedMonthBetTradeComm  MONEY,
			@SelectedMonthBetTradeCommUSD MONEY,
			@SelectedMonthBetTradeCommEUR MONEY,
			@SelectedMonthBetTradeCommGBP MONEY,
			@SelectedMonthAmtDueToBT	MONEY,
			@SelectedMonthAmtDueToBTUSD MONEY,
			@SelectedMonthAmtDueToBTEUR MONEY,
			@SelectedMonthAmtDueToBTGBP MONEY,
	
			@TodayLicenseeWL MONEY,
			@TodayLicenseeWLUSD MONEY,
			@TodayLicenseeWLEUR MONEY,
			@TodayLicenseeWLGBP MONEY,
			@TodayAmtDuetoBA MONEY,
			@TodayAmtDuetoBAUSD MONEY,
			@TodayAmtDuetoBAEUR MONEY,
			@TodayAmtDuetoBAGBP MONEY,
			@TodayCommBA  MONEY,
			@TodayCommBAUSD MONEY,
			@TodayCommBAEUR MONEY,
			@TodayCommBAGBP MONEY,
			@TodayPlayerComm 	  MONEY,
			@TodayPlayerCommUSD MONEY,
			@TodayPlayerCommEUR MONEY,
			@TodayPlayerCommGBP MONEY,
			@TodayBetTradeComm    MONEY,
			@TodayBetTradeCommUSD MONEY,
			@TodayBetTradeCommEUR MONEY,
			@TodayBetTradeCommGBP MONEY,
			@TodayAmtDueToBT    MONEY,
			@TodayAmtDueToBTUSD MONEY,
			@TodayAmtDueToBTEUR MONEY,
			@TodayAmtDueToBTGBP MONEY,	
		
			@YesterdayLicenseeWL MONEY,
			@YesterdayLicenseeWLUSD MONEY,
			@YesterdayLicenseeWLEUR MONEY,
			@YesterdayLicenseeWLGBP MONEY,
			@YesterdayAmtDuetoBA MONEY,
			@YesterdayAmtDuetoBAUSD MONEY,
			@YesterdayAmtDuetoBAEUR MONEY,
			@YesterdayAmtDuetoBAGBP MONEY,
			@YesterdayCommBA  MONEY,
			@YesterdayCommBAUSD MONEY,
			@YesterdayCommBAEUR MONEY,
			@YesterdayCommBAGBP MONEY,
			@YesterdayPlayerComm    MONEY,
			@YesterdayPlayerCommUSD MONEY,
			@YesterdayPlayerCommEUR MONEY,
			@YesterdayPlayerCommGBP MONEY,
			@YesterdayBetTradeComm    MONEY,
			@YesterdayBetTradeCommUSD MONEY,
			@YesterdayBetTradeCommEUR MONEY,
			@YesterdayBetTradeCommGBP MONEY,
			@YesterdayAmtDueToBT    MONEY,
			@YesterdayAmtDueToBTUSD MONEY,
			@YesterdayAmtDueToBTEUR MONEY,
			@YesterdayAmtDueToBTGBP MONEY,
	
			@MemberOutstanding MONEY,
			@MemberOutstandingUSD MONEY,
			@MemberOutstandingEUR MONEY,
			@MemberOutstandingGBP MONEY,
	
			@TotalMemberActive INT,
			@TotalMemberClosed INT,
			@TotalMemberSuspended INT,
			@_FromDate SMALLDATETIME,
			@_ToDate SMALLDATETIME
	
	SELECT 	@_FromDate = @FromDate,
			@_ToDate = @ToDate

	DECLARE @SumTemp AS TABLE
	(
		currency INT,
		SelectedMonthLicenseeWL MONEY,
		SelectedMonthAmtDuetoBA MONEY,
		SelectedMonthCommBA MONEY,
		SelectedMonthPlayerComm MONEY,
		SelectedMonthBetTradeComm MONEY,
		SelectedMonthWLBetTicket MONEY ,	
		SelectedMonthWLBoughtTicket MONEY
	)

	DECLARE @SumOutstanding AS TABLE
	(
		currency INT,
		outstanding MONEY
	)

	DECLARE @LicenseeWL AS TABLE
	(
		winlostdate SMALLDATETIME,
		currency INT,
		LicenseeWL MONEY,
		AmtDuetoBA MONEY,
		CommBA MONEY,
		PlayerComm MONEY,
		WLBetTicket MONEY,
		BetTradeComm MONEY,
		WLBoughtTicket	 MONEY
	)


	DECLARE @Today SMALLDATETIME, @Yesterday SMALLDATETIME
	DECLARE @Exchange TABLE(ExchangeDate SMALLDATETIME, ExchangeId INT, USD FLOAT, EUR FLOAT,MYR FLOAT,GBP FLOAT,Code VARCHAR(10), PRIMARY KEY(ExchangeDate,ExchangeId))
	DECLARE @LicenseeName VARCHAR(50)

	SELECT @LicenseeName = LicenseeName
	FROM bodb_Licensee.dbo.Licensees (NOLOCK)
	WHERE LicenseeID = @LicenseeID

	SET @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120) 
	SET @Yesterday = CONVERT(VARCHAR(10), DATEADD(DAY,-1,@Today), 120) 

	DECLARE @TempAg AS TABLE (CustId INT,Currency INT)

	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@AgentList
	
		INSERT INTO @TempAg(CustId, Currency)
		SELECT AgentId, Currency 
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [INT], Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
			,ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH;

	INSERT INTO @Exchange (exchangedate,exchangeid,usd,eur,myr,gbp,code)
	SELECT exchangedate,exchangeid,usd,eur,myr,gbp,code
	FROM Lrf_f_GetExchangeDaily(@Today,@Today)
	WHERE exchangeid IN (SELECT Currency FROM @TempAg)

	IF (SELECT COUNT(*) FROM @TempAg) = 1
	BEGIN
		SELECT TOP 1 @UserName = username
		FROM CustInfo c WITH (NOLOCK)
		WHERE roleid = 2 
			AND custid IN (select custid from @TempAg)
	END

	SELECT	@TotalMemberActive = ISNULL(SUM(CASE WHEN Closed = 0 AND ISNULL(reject,0) = 0 THEN 1 ELSE 0 END), 0),
			@TotalMemberClosed = ISNULL(SUM(CASE WHEN Closed = 1 THEN 1 ELSE 0 END), 0),
			@TotalMemberSuspended = ISNULL(SUM(CASE WHEN ISNULL(reject,0) = 1 AND closed = 0 THEN 1 ELSE 0 END), 0)
	FROM CustInfo WITH (NOLOCK)
	WHERE Recommend IN (SELECT DISTINCT CustID FROM @TempAg)
		AND RoleID=1

	--outstanding then get today rate
	INSERT INTO @SumOutstanding (currency, outstanding)
	SELECT a.currency,ISNULL(SUM(b.actual_stake), 0)
	FROM dbo.bettrans b WITH(NOLOCK) 
		INNER JOIN @TempAg a ON b.recommend = a.custid AND b.currency = a.currency
	WHERE b.bettype <= 1399 
		AND b.statusid IN (0,1)
		AND b.bettype NOT BETWEEN 1101 AND 1199 --Remove LC
	GROUP BY a.currency

	--Keno sport
	INSERT INTO @SumOutstanding (currency, outstanding)
	SELECT a.currency,ISNULL(SUM(b.actual_stake), 0)
	FROM bodb02.dbo.Translog b WITH(NOLOCK) 
		INNER JOIN @TempAg a ON b.recommend = a.custid AND b.currency = a.currency
	WHERE b.statusid = 0 -- running
	GROUP BY a.currency

	-- Voidbridge(4001-4100) & PP(4101-4300)
	INSERT INTO @SumOutstanding (currency, outstanding)
	SELECT a.currency,ISNULL(SUM(b.actual_stake),0)
	FROM dbo.bettransRnG b WITH(NOLOCK) 
		INNER JOIN @TempAg a ON b.recommend = a.custid AND b.currency = a.currency
	WHERE b.gameID BETWEEN 4001 AND 4300
		AND b.statusid IN (0,1)
	GROUP BY a.currency
	
	SELECT  @MemberOutstanding=ISNULL(SUM(outstanding),0),
			@MemberOutstandingUSD=ISNULL(SUM(outstanding*e.USD),0),
			@MemberOutstandingEUR=ISNULL(SUM(outstanding*e.EUR),0),
			@MemberOutstandingGBP=ISNULL(SUM(outstanding*e.GBP),0)
	FROM @SumOutstanding b 
		INNER JOIN @Exchange e ON e.exchangeid = b.currency	
	
	
	--****Begin For Yesterday and Today Winloss Part***	
	--Yesterday/Today Licensee WL
	CREATE TABLE #Temp_Bettrans
	(
		srecommend INT,
		winlostdate SMALLDATETIME,
		bettype SMALLINT,
		currency INT,
		statusID TINYINT,
		recommend INT,
		winlost MONEY,
		tpositiontaking SMALLMONEY,
		comm MONEY,
		playercomm MONEY,
		awinlost MONEY,
		actual_stake MONEY,
		betdaqid BIGINT
	)

	INSERT INTO #Temp_Bettrans 
	(	
		srecommend,
		winlostdate,
		bettype,
		currency,
		statusID,
		recommend,
		winlost,
		tpositiontaking,
		comm,
		playercomm,
		awinlost,
		actual_stake,
		betdaqid
	)
	SELECT	srecommend,
			winlostdate,
			bettype,
			ag.currency,
			statusID,
			recommend,
			winlost,
			tpositiontaking,
			comm,
			playercomm,
			awinlost,
			actual_stake,
			betdaqid
	FROM dbo.bettrans b WITH(NOLOCK) 
		INNER JOIN 	@TempAg ag ON b.recommend = ag.CustId AND b.Currency = ag.Currency
	WHERE b.winlostdate BETWEEN @MoveBetsDay AND @Today 
		AND (b.bettype <= 1599 
			OR b.bettype BETWEEN 4001 AND 4300) -- Voidbridge & PP
		AND b.bettype NOT BETWEEN 1011 AND 1020
		AND b.bettype NOT BETWEEN 1101 AND 1199 -- Remove LC
		AND b.statusID IN (111,112,113)

	INSERT INTO @LicenseeWL(winlostdate, currency, LicenseeWL, AmtDuetoBA, CommBA, PlayerComm, WLBetTicket, BetTradeComm, WLBoughtTicket)
	SELECT  b.winlostdate,a.currency,
			ISNULL(-SUM(
					CASE WHEN (
						(
							(bettype <= 30 OR bettype BETWEEN 121 AND 999 OR (bettype BETWEEN 1301 AND 1399)) 
							AND b.tpositiontaking <> 0 AND bettype NOT IN (901, 902, 903, 904)
							AND (b.bettype < 911 OR b.bettype > 914)
						) 
						OR 
						(
							b.bettype BETWEEN 81 AND 120 
							OR b.bettype BETWEEN 1201 AND 1299 
							OR b.bettype BETWEEN 1501 AND 1599 --Keno
							OR b.bettype BETWEEN 4001 AND 4300 -- Voidbridge & PP
						)
						) THEN (b.winlost - b.actual_stake)  
						ELSE 0 
					END), 0) AS LicenseeWL,	--20130619@Daniel: Fix more bug regconize BA tickets
		ISNULL(-SUM(CASE WHEN b.tpositiontaking = 0 
							AND (
								((b.bettype <= 30 OR b.bettype >= 121) AND b.bettype <= 999 AND b.bettype NOT IN (901, 902, 903, 904) AND (b.bettype < 911 OR b.bettype > 914)) 
								OR (b.bettype BETWEEN 1301 and 1399)
							) THEN (b.winlost - b.actual_stake + awinlost + comm)
						ELSE 0 
					END), 0) AS AmtDuetoBA,
		ISNULL(SUM(CASE WHEN b.tpositiontaking = 0 
							AND (
								((b.bettype <= 30 OR b.bettype >= 121) AND b.bettype <= 999 AND b.bettype NOT IN (901, 902, 903, 904) AND (b.bettype < 911 OR b.bettype > 914)) 
								OR (b.bettype BETWEEN 1301 AND 1399)
							) THEN  comm  
						ELSE 0 
					END), 0) AS CommBA,
		ISNULL(SUM(playercomm), 0) AS PlayerComm,
		SUM(CASE WHEN (bettype <= 30 OR bettype BETWEEN 121 AND 999 OR (bettype BETWEEN 1301 AND 1399)) 
					AND bettype NOT IN (901, 902, 903, 904) AND (b.bettype < 911 OR b.bettype > 914)
					AND betdaqid = 0 THEN (b.winlost - b.actual_stake)
				ELSE 0 END) AS WLBetTicket,
		SUM(CASE WHEN b.bettype = 903 THEN b.awinlost
				ELSE 0 END) AS BetTradeComm,		
		SUM(CASE WHEN b.bettype = 902 THEN (b.winlost - b.actual_stake)
				ELSE 0 END) AS WLBoughtTicket
	FROM #Temp_Bettrans b 
		INNER JOIN @TempAg a ON b.recommend = a.custid AND b.currency = a.currency
	GROUP BY b.winlostdate,a.currency

	SELECT  @YesterdayLicenseeWL = SUM(LicenseeWL),
			@YesterdayLicenseeWLUSD = SUM(LicenseeWL * e.USD),
			@YesterdayLicenseeWLEUR = SUM(LicenseeWL * e.EUR),
			@YesterdayLicenseeWLGBP = SUM(LicenseeWL * e.GBP),
			@YesterdayAmtDuetoBA = SUM(AmtDuetoBA),
			@YesterdayAmtDuetoBAUSD = SUM(AmtDuetoBA * e.USD),
			@YesterdayAmtDuetoBAEUR = SUM(AmtDuetoBA * e.EUR),
			@YesterdayAmtDuetoBAGBP = SUM(AmtDuetoBA * e.GBP),
			@YesterdayCommBA = SUM(CommBA),
			@YesterdayCommBAUSD = SUM(CommBA * e.USD),
			@YesterdayCommBAEUR = SUM(CommBA * e.EUR),
			@YesterdayCommBAGBP = SUM(CommBA * e.GBP),
			@YesterdayPlayerComm    = SUM(PlayerComm),
			@YesterdayPlayerCommUSD = SUM(PlayerComm * e.USD),
			@YesterdayPlayerCommEUR = SUM(PlayerComm * e.EUR), -- yesterday
			@YesterdayPlayerCommGBP = SUM(PlayerComm * e.GBP), -- yesterday
			@YesterdayBetTradeComm  = SUM(BetTradeComm),
			@YesterdayBetTradeCommUSD = SUM(BetTradeComm * e.USD),
			@YesterdayBetTradeCommEUR = SUM(BetTradeComm * e.EUR),
			@YesterdayBetTradeCommGBP = SUM(BetTradeComm * e.GBP),
			@YesterdayAmtDueToBT	  =  SUM(b.WLBetTicket + b.WLBoughtTicket - b.BetTradeComm),
			@YesterdayAmtDueToBTUSD	  =  SUM((b.WLBetTicket + b.WLBoughtTicket - b.BetTradeComm) * e.USD),
			@YesterdayAmtDueToBTEUR	  =  SUM((b.WLBetTicket + b.WLBoughtTicket - b.BetTradeComm) * e.EUR),
			@YesterdayAmtDueToBTGBP	  =  SUM((b.WLBetTicket + b.WLBoughtTicket - b.BetTradeComm) * e.GBP)
	FROM @LicenseeWL b 
		INNER JOIN (SELECT * FROM Lrf_f_GetExchangeDaily(@Yesterday, @Yesterday)) e 	
			ON e.exchangeid = b.currency AND b.winlostdate = @Yesterday


	SELECT  @TodayLicenseeWL = SUM(LicenseeWL),
			@TodayLicenseeWLUSD = SUM(LicenseeWL * e.USD),
			@TodayLicenseeWLEUR = SUM(LicenseeWL * e.EUR),
			@TodayLicenseeWLGBP = SUM(LicenseeWL * e.GBP),
			@TodayAmtDuetoBA = SUM(AmtDuetoBA),
			@TodayAmtDuetoBAUSD = SUM(AmtDuetoBA * e.USD),
			@TodayAmtDuetoBAEUR = SUM(AmtDuetoBA * e.EUR),
			@TodayAmtDuetoBAGBP = SUM(AmtDuetoBA * e.GBP),
	
			@TodayCommBA = SUM(CommBA),
			@TodayCommBAUSD = SUM(CommBA * e.USD),
			@TodayCommBAEUR = SUM(CommBA * e.EUR),
			@TodayCommBAGBP = SUM(CommBA * e.GBP),
			@TodayPlayerComm=ISNULL(SUM(playercomm),0),
			@TodayPlayerCommUSD=ISNULL(SUM(Playercomm * e.USD),0),
			@TodayPlayerCommEUR=ISNULL(SUM((Playercomm) * e.EUR),0),
			@TodayPlayerCommGBP=ISNULL(SUM((Playercomm) * e.GBP),0),
			@TodayBetTradeComm  = SUM(BetTradeComm),
			@TodayBetTradeCommUSD = SUM(BetTradeComm * e.USD),
			@TodayBetTradeCommEUR = SUM(BetTradeComm * e.EUR),
			@TodayBetTradeCommGBP = SUM(BetTradeComm * e.GBP),
			@TodayAmtDueToBT	  =  SUM(b.WLBetTicket + b.WLBoughtTicket - b.BetTradeComm),
			@TodayAmtDueToBTUSD	  =  SUM((b.WLBetTicket + b.WLBoughtTicket - b.BetTradeComm) * e.USD),
			@TodayAmtDueToBTEUR	  =  SUM((b.WLBetTicket + b.WLBoughtTicket - b.BetTradeComm) * e.EUR),
			@TodayAmtDueToBTGBP	  =  SUM((b.WLBetTicket + b.WLBoughtTicket - b.BetTradeComm) * e.GBP)
	
	FROM @LicenseeWL b 
		INNER JOIN (SELECT * FROM Lrf_f_GetExchangeDaily(@Today, @Today))e 	
			ON  e.exchangeid = b.currency AND b.winlostdate = @Today
			
	 --****End For Yesterday and Today Winloss Part***	

			
	--****Begin for Selected Month Winloss part*******			
	DECLARE @TempFromDate SMALLDATETIME 
	DECLARE @TempToDate SMALLDATETIME

	IF @_ToDate > @MoveBetsDay
	BEGIN
		IF @_FromDate <= @MoveBetsDay 
			SET @TempFromDate =  DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @_FromDate
	
		INSERT INTO @SumTemp
		(
			currency,
			SelectedMonthLicenseeWL,
			SelectedMonthAmtDuetoBA,
			SelectedMonthCommBA,
			SelectedMonthPlayerComm,
			SelectedMonthBetTradeComm,
			SelectedMonthWLBetTicket,
			SelectedMonthWLBoughtTicket
		)						
		SELECT  b.currency,
				ISNULL(SUM(LicenseeWL), 0),
				ISNULL(SUM(AmtDuetoBA), 0),
				ISNULL(SUM (CommBA), 0),
				ISNULL(SUM (playercomm), 0),
				ISNULL(SUM (BetTradeComm), 0),
				ISNULL(SUM (b.WLBetTicket), 0),
				ISNULL(SUM (b.WLBoughtTicket), 0)
		FROM @LicenseeWL b
		WHERE b.winlostdate BETWEEN @TempFromDate AND @_ToDate 
		GROUP by b.currency
	END

	IF @_FromDate <= @MoveBetsDay
	BEGIN
		IF @_ToDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET  @TempToDate = @_ToDate

		INSERT INTO @SumTemp 
		(
			currency,
			SelectedMonthLicenseeWL,
			SelectedMonthAmtDuetoBA,
			SelectedMonthCommBA,
			SelectedMonthPlayerComm,
			SelectedMonthBetTradeComm,
			SelectedMonthWLBetTicket,
			SelectedMonthWLBoughtTicket
		)
		SELECT  ag.currency,
				ISNULL(-SUM(CASE WHEN ISNULL(b.isBA, 0) = 0 AND (b.sporttype IN (0, 161, 180, 251, 202)) THEN b.winlost 
								ELSE 0 END), 0) AS SelectedMonthLicenseeWL,
				ISNULL(-SUM(CASE WHEN ISNULL(b.isBA, 0) = 1 THEN (b.winlost + b.awinlost + b.comm) ELSE 0 END), 0) AS SelectedMonthAmtDuetoBA,
				ISNULL(SUM(CASE WHEN ISNULL(b.isBA,0) = 1 THEN  comm  ELSE 0 END), 0) AS SelectedMonthCommBA,
				ISNULL(SUM(playercomm), 0) AS SelectedMonthPlayerComm,
				SUM(CASE WHEN b.bettype = 903 THEN b.awinlost
						ELSE 0 END) AS SelectedMonthBetTradeComm,
				ISNULL(SUM(CASE WHEN (b.sporttype = 0 AND b.bettype NOT IN (901, 902, 903, 904) AND (b.bettype < 911 OR b.bettype > 914)) 
									AND bt.Custid IS NOT NULL THEN b.winlost 
								ELSE 0 
							END), 0) AS SelectedMonthWLBetTicket,			
				SUM(CASE WHEN b.bettype = 902 THEN (b.winlost)
						ELSE 0 END) AS SelectedMonthWLBoughtTicket
		FROM bodb_Licenseereport.dbo.rptLicWinloss2 b WITH(NOLOCK) 
			INNER JOIN 	@TempAg ag ON b.recommend = ag.CustId AND b.Currency = ag.Currency
			LEFT JOIN f_GetBetTradeCustList(@LicenseeName) bt ON b.custid=bt.Custid AND b.Currency = bt.currency
		WHERE b.Winlostdate BETWEEN @_FromDate AND @TempToDate
			AND	roleID = 1
			AND b.statusID <> 101 --exclude REJECT bets
		GROUP BY ag.currency	
	END


	SELECT  @SelectedMonthLicenseeWL = SUM(SelectedMonthLicenseeWL),
			@SelectedMonthLicenseeWLUSD = SUM(SelectedMonthLicenseeWL * e.USD),
			@SelectedMonthLicenseeWLEUR = SUM(SelectedMonthLicenseeWL * e.EUR),
			@SelectedMonthLicenseeWLGBP = SUM(SelectedMonthLicenseeWL * e.GBP),
			@SelectedMonthAmtDuetoBA =  SUM(SelectedMonthAmtDuetoBA),
			@SelectedMonthAmtDuetoBAUSD = SUM(SelectedMonthAmtDuetoBA * e.USD),
			@SelectedMonthAmtDuetoBAEUR = SUM(SelectedMonthAmtDuetoBA * e.EUR),
			@SelectedMonthAmtDuetoBAGBP = SUM(SelectedMonthAmtDuetoBA * e.GBP),
			@SelectedMonthCommBA = SUM(SelectedMonthCommBA),
			@SelectedMonthCommBAUSD = SUM(SelectedMonthCommBA * e.USD),
			@SelectedMonthCommBAEUR =  SUM(SelectedMonthCommBA * e.EUR),
			@SelectedMonthCommBAGBP =  SUM(SelectedMonthCommBA * e.GBP),
			@SelectedMonthPlayerComm = SUM(SelectedMonthPLayerComm),
			@SelectedMonthPlayerCommUSD = SUM(SelectedMonthPlayerComm * e.USD),
			@SelectedMonthPlayerCommEUR =  SUM(SelectedMonthPlayerComm * e.EUR),
			@SelectedMonthPlayerCommGBP =  SUM(SelectedMonthPlayerComm * e.GBP),
			@SelectedMonthBetTradeComm = SUM(SelectedMonthBetTradeComm),
			@SelectedMonthBetTradeCommUSD = SUM(SelectedMonthBetTradeComm * e.USD),
			@SelectedMonthBetTradeCommEUR =  SUM(SelectedMonthBetTradeComm * e.EUR),
			@SelectedMonthBetTradeCommGBP =  SUM(SelectedMonthBetTradeComm * e.GBP),
			@SelectedMonthAmtDueToBT	  = SUM(SelectedMonthWLBetTicket + SelectedMonthWLBoughtTicket - SelectedMonthBetTradeComm),
			@SelectedMonthAmtDueToBTUSD = SUM((SelectedMonthWLBetTicket + SelectedMonthWLBoughtTicket - SelectedMonthBetTradeComm) * e.USD),
			@SelectedMonthAmtDueToBTEUR =  SUM((SelectedMonthWLBetTicket + SelectedMonthWLBoughtTicket - SelectedMonthBetTradeComm) * e.EUR),
			@SelectedMonthAmtDueToBTGBP =  SUM((SelectedMonthWLBetTicket + SelectedMonthWLBoughtTicket - SelectedMonthBetTradeComm) * e.GBP)
	FROM @SumTemp b 
		INNER JOIN (SELECT * FROM Lrf_f_GetExchangeDaily(@_FromDate,@_FromDate))e 	
		ON e.exchangeid = b.currency
	--****End for Selected Month Winloss part*******			


	SELECT  ISNULL(@UserName,'') AS UserName,
			ISNULL(@SelectedMonthLicenseeWL, 0) AS SelectedMonthLicenseeWL,
			ISNULL(@SelectedMonthLicenseeWLUSD, 0) AS SelectedMonthLicenseeWLUSD,
			ISNULL(@SelectedMonthLicenseeWLEUR, 0) AS SelectedMonthLicenseeWLEUR,
			ISNULL(@SelectedMonthLicenseeWLGBP,0) AS SelectedMonthLicenseeWLGBP,
			--Month Comm
			ISNULL(@SelectedMonthCommBA, 0) AS SelectedMonthCommBA,
			ISNULL(@SelectedMonthCommBAUSD, 0) AS SelectedMonthCommBAUSD,
			ISNULL(@SelectedMonthCommBAEUR, 0) AS SelectedMonthCommBAEUR,
			ISNULL(@SelectedMonthCommBAGBP, 0) AS SelectedMonthCommBAGBP,
			ISNULL(@SelectedMonthPlayerComm, 0) AS SelectedMonthPlayerComm,
			ISNULL(@SelectedMonthPlayerCommUSD, 0) AS SelectedMonthPlayerCommUSD,
			ISNULL(@SelectedMonthPlayerCommEUR, 0) AS SelectedMonthPlayerCommEUR,
			ISNULL(@SelectedMonthPlayerCommGBP, 0) AS SelectedMonthPlayerCommGBP,

			--Month Amount Due To BA
			ISNULL(@SelectedMonthAmtDuetoBA, 0) AS SelectedMonthAmtDuetoBA,
			ISNULL(@SelectedMonthAmtDuetoBAUSD, 0) AS SelectedMonthAmtDuetoBAUSD,
			ISNULL(@SelectedMonthAmtDuetoBAEUR, 0) AS SelectedMonthAmtDuetoBAEUR,
			ISNULL(@SelectedMonthAmtDuetoBAGBP, 0) AS SelectedMonthAmtDuetoBAGBP,
			-- Month Bettrade 
			ISNULL(@SelectedMonthBetTradeComm, 0) AS SelectedMonthBetTradeComm,
			ISNULL(@SelectedMonthBetTradeCommUSD, 0) AS SelectedMonthBetTradeCommUSD,
			ISNULL(@SelectedMonthBetTradeCommEUR, 0) AS SelectedMonthBetTradeCommEUR,
			ISNULL(@SelectedMonthBetTradeCommGBP, 0) AS SelectedMonthBetTradeCommGBP,
			ISNULL(@SelectedMonthAmtDueToBT, 0) AS SelectedMonthAmtDueToBT,
			ISNULL(@SelectedMonthAmtDueToBTUSD, 0) AS SelectedMonthAmtDueToBTUSD,
			ISNULL(@SelectedMonthAmtDueToBTEUR, 0) AS SelectedMonthAmtDueToBTEUR,
			ISNULL(@SelectedMonthAmtDueToBTGBP, 0) AS SelectedMonthAmtDueToBTGBP,
	
			--Yesterday WL
			ISNULL(@YesterdayLicenseeWL, 0) AS YesterdayLicenseeWL,
			ISNULL(@YesterdayLicenseeWLUSD, 0) AS YesterdayLicenseeWLUSD,
			ISNULL(@YesterdayLicenseeWLEUR, 0) AS YesterdayLicenseeWLEUR,
			ISNULL(@YesterdayLicenseeWLGBP, 0) AS YesterdayLicenseeWLGBP,
			--Yesterday Comm
			ISNULL(@YesterdayCommBA, 0) AS YesterdayCommBA,
			ISNULL(@YesterdayCommBAUSD, 0) AS YesterdayCommBAUSD,
			ISNULL(@YesterdayCommBAEUR, 0) AS YesterdayCommBAEUR,
			ISNULL(@YesterdayCommBAGBP, 0) AS YesterdayCommBAGBP,
			ISNULL(@YesterdayPlayerComm, 0) AS YesterdayPlayerComm,
			ISNULL(@YesterdayPlayerCommUSD, 0) AS YesterdayPlayerCommUSD,
			ISNULL(@YesterdayPlayerCommEUR, 0) AS YesterdayPlayerCommEUR,
			ISNULL(@YesterdayPlayerCommGBP, 0) AS YesterdayPlayerCommGBP,
	
			--YesterdayAmtDue
			ISNULL(@YesterdayAmtDuetoBA, 0) AS YesterdayAmtDuetoBA,
			ISNULL(@YesterdayAmtDuetoBAUSD, 0) AS YesterdayAmtDuetoBAUSD,
			ISNULL(@YesterdayAmtDuetoBAEUR, 0) AS YesterdayAmtDuetoBAEUR,
			ISNULL(@YesterdayAmtDuetoBAGBP, 0) AS YesterdayAmtDuetoBAGBP,

			-- yesterday bettrade
			ISNULL(@YesterdayBetTradeComm, 0) AS YesterdayBetTradeComm,
			ISNULL(@YesterdayBetTradeCommUSD, 0) AS YesterdayBetTradeCommUSD,
			ISNULL(@YesterdayBetTradeCommEUR, 0) AS YesterdayBetTradeCommEUR,
			ISNULL(@YesterdayBetTradeCommGBP, 0) AS YesterdayBetTradeCommGBP,
			ISNULL(@YesterdayAmtDueToBT, 0) AS YesterdayAmtDueToBT,
			ISNULL(@YesterdayAmtDueToBTUSD, 0) AS YesterdayAmtDueToBTUSD,
			ISNULL(@YesterdayAmtDueToBTEUR, 0) AS YesterdayAmtDueToBTEUR,
			ISNULL(@YesterdayAmtDueToBTGBP, 0) AS YesterdayAmtDueToBTGBP,

			--TodayLicenseeWL
			ISNULL(@TodayLicenseeWL, 0) AS TodayLicenseeWL,
			ISNULL(@TodayLicenseeWLUSD, 0) AS TodayLicenseeWLUSD,
			ISNULL(@TodayLicenseeWLEUR, 0) AS TodayLicenseeWLEUR,
			ISNULL(@TodayLicenseeWLGBP, 0) AS TodayLicenseeWLGBP,
			--TodayComm
			ISNULL(@TodayCommBA, 0) AS TodayCommBA,
			ISNULL(@TodayCommBAUSD, 0) AS TodayCommBAUSD,
			ISNULL(@TodayCommBAEUR, 0) AS TodayCommBAEUR,
			ISNULL(@TodayCommBAGBP, 0) AS TodayCommBAGBP,
			ISNULL(@TodayPlayerComm, 0) AS TodayPlayerComm,
			ISNULL(@TodayPlayerCommUSD, 0) AS TodayPlayerCommUSD,
			ISNULL(@TodayPlayerCommEUR, 0) AS TodayPlayerCommEUR,
			ISNULL(@TodayPlayerCommGBP, 0) AS TodayPlayerCommGBP,
	
			--TodayAmtDueToBA
			ISNULL(@TodayAmtDuetoBA, 0) AS TodayAmtDuetoBA,
			ISNULL(@TodayAmtDuetoBAUSD, 0) AS TodayAmtDuetoBAUSD,
			ISNULL(@TodayAmtDuetoBAEUR, 0) AS TodayAmtDuetoBAEUR,
			ISNULL(@TodayAmtDuetoBAGBP, 0) AS TodayAmtDuetoBAGBP,

			-- Today bettrade
			ISNULL(@TodayBetTradeComm, 0)	AS TodayBetTradeComm,
			ISNULL(@TodayBetTradeCommUSD, 0) AS TodayBetTradeCommUSD,
			ISNULL(@TodayBetTradeCommEUR, 0) AS TodayBetTradeCommEUR,
			ISNULL(@TodayBetTradeCommGBP, 0) AS TodayBetTradeCommGBP,
			ISNULL(@TodayAmtDueToBT, 0)		AS TodayAmtDueToBT,
			ISNULL(@TodayAmtDueToBTUSD, 0) AS TodayAmtDueToBTUSD,
			ISNULL(@TodayAmtDueToBTEUR, 0) AS TodayAmtDueToBTEUR,
			ISNULL(@TodayAmtDueToBTGBP, 0) AS TodayAmtDueToBTGBP,
			--
			ISNULL(@MemberOutstanding, 0) MemberOutstanding,
			ISNULL(@MemberOutstandingUSD, 0) MemberOutstandingUSD,
			ISNULL(@MemberOutstandingEUR, 0) MemberOutstandingEUR, 
			ISNULL(@MemberOutstandingGBP, 0) MemberOutstandingGBP,
	
			ISNULL(@TotalMemberActive,0) TotalMemberActive,
			ISNULL(@TotalMemberClosed,0) TotalMemberClosed,
			ISNULL(@TotalMemberSuspended,0) TotalMemberSuspended

	DROP TABLE #Temp_Bettrans
END
GO
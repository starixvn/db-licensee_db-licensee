USE [bodb02]
 
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Lrf_CustomerSelBalance]
	@LicenseeID INT,
	@UserID	INT,
	@CurrencyID INT=0,
	@LicenseeType VARCHAR(100) = NULL,
	@MoveBetsDay SMALLDATETIME,
	@FromDate SMALLDATETIME,
	@ToDate SMALLDATETIME,
	@IsOld BIT = 0
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
*/
SET NOCOUNT ON


DECLARE 
	@UserName VARCHAR(50),
	@SelectedMonthLicenseeWL MONEY,
	@SelectedMonthLicenseeWLUSD MONEY,
	@SelectedMonthLicenseeWLEUR MONEY,
	@SelectedMonthLicenseeWLGBP MONEY,
	@SelectedMonthWinlossRB MONEY,
	@SelectedMonthWinlossRBUSD MONEY,
	@SelectedMonthWinlossRBEUR MONEY,
	@SelectedMonthWinlossRBGBP MONEY,
	@SelectedMonthAmtDuetoBA MONEY,
	@SelectedMonthAmtDuetoBAUSD MONEY,
	@SelectedMonthAmtDuetoBAEUR MONEY,
	@SelectedMonthAmtDuetoBAGBP MONEY,
	@SelectedMonthAmtDuetoRB MONEY,
	@SelectedMonthAmtDuetoRBUSD MONEY,
	@SelectedMonthAmtDuetoRBEUR MONEY,
	@SelectedMonthAmtDuetoRBGBP MONEY,
	@SelectedMonthCommBA MONEY,
	@SelectedMonthCommRB MONEY,
	@SelectedMonthCommBAUSD MONEY,
	@SelectedMonthCommBAEUR MONEY,
	@SelectedMonthCommBAGBP MONEY,
	@SelectedMonthPlayerComm MONEY,
	@SelectedMonthCommRBUSD MONEY,
	@SelectedMonthCommRBEUR MONEY,
	@SelectedMonthCommRBGBP MONEY,
	@SelectedMonthPlayerCommUSD MONEY,
	@SelectedMonthPlayerCommEUR MONEY,
	@SelectedMonthPlayerCommGBP MONEY,
	@SelectedMonthBetTradeComm    MONEY,
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
	@TodayWinlossRB MONEY,
	@TodayWinlossRBUSD MONEY,
	@TodayWinlossRBEUR MONEY,
	@TodayWinlossRBGBP MONEY,
	@TodayAmtDuetoBA MONEY,
	@TodayAmtDuetoBAUSD MONEY,
	@TodayAmtDuetoBAEUR MONEY,
	@TodayAmtDuetoBAGBP MONEY,
	@TodayAmtDuetoRB MONEY,
	@TodayAmtDuetoRBUSD MONEY,
	@TodayAmtDuetoRBEUR MONEY,
	@TodayAmtDuetoRBGBP MONEY,
	@TodayCommBA  MONEY,
	@TodayCommBAUSD MONEY,
	@TodayCommBAEUR MONEY,
	@TodayCommBAGBP MONEY,
	@TodayCommRB  MONEY,
	@TodayCommRBUSD MONEY,
	@TodayCommRBEUR MONEY,
	@TodayCommRBGBP MONEY,
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
	@YesterdayWinlossRB MONEY,
	@YesterdayWinlossRBUSD MONEY,
	@YesterdayWinlossRBEUR MONEY,
	@YesterdayWinlossRBGBP MONEY,
	@YesterdayAmtDuetoBA MONEY,
	@YesterdayAmtDuetoBAUSD MONEY,
	@YesterdayAmtDuetoBAEUR MONEY,
	@YesterdayAmtDuetoBAGBP MONEY,
	@YesterdayAmtDuetoRB MONEY,
	@YesterdayAmtDuetoRBUSD MONEY,
	@YesterdayAmtDuetoRBEUR MONEY,
	@YesterdayAmtDuetoRBGBP MONEY,--
	@YesterdayCommBA  MONEY,
	@YesterdayCommBAUSD MONEY,
	@YesterdayCommBAEUR MONEY,
	@YesterdayCommBAGBP MONEY,
	@YesterdayCommRB  MONEY,
	@YesterdayCommRBUSD MONEY,
	@YesterdayCommRBEUR MONEY,
	@YesterdayCommRBGBP MONEY,
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
	
SELECT 	@_FromDate=@FromDate, @_ToDate=@ToDate

DECLARE @SumTemp as table
(
	currency INT,
	SelectedMonthLicenseeWL MONEY,
	SelectedMonthAmtDuetoBA MONEY,
	SelectedMonthAmtDuetoRB MONEY,
	SelectedMonthWinlossRB MONEY,
	SelectedMonthCommBA MONEY,
	SelectedMonthCommRB MONEY,
	SelectedMonthPlayerComm MONEY,
	SelectedMonthBetTradeComm MONEY,
	SelectedMonthWLBetTicket MONEY ,	
	SelectedMonthWLBoughtTicket MONEY
)
DECLARE @SumOutstanding as table
(
	currency INT,
	outstanding MONEY
)
DECLARE @LicenseeWL as table
(
	winlostdate smalldatetime,
	currency INT,
	LicenseeWL money,
	AmtDuetoBA money,
	AmtDuetoRB money,
	WinlossRB money,
	CommBA money,
	CommRB money,
	PlayerComm MONEY,
	WLBetTicket MONEY,
	BetTradeComm MONEY,
	WLBoughtTicket	 MONEY
)


DECLARE @Today SMALLDATETIME, @Yesterday SMALLDATETIME
DECLARE @Exchange TABLE(ExchangeDate SMALLDATETIME, ExchangeId INT, USD FLOAT, EUR FLOAT,MYR FLOAT,GBP FLOAT,Code VARCHAR(10), PRIMARY KEY(ExchangeDate,ExchangeId))
DECLARE @LicenseeName VARCHAR(50)
SELECT @LicenseeName = LicenseeName FROM bodb_Licensee.dbo.Licensees (NOLOCK) WHERE LicenseeID = @LicenseeID

SET @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120) 
SET @Yesterday = CONVERT(VARCHAR(10), DATEADD(DAY,-1,@Today), 120) 

SELECT  currencyID,LicenseeID into #currency
FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)
WHERE (@CurrencyID=0  OR (@CurrencyID<>0 AND CurrencyID=@CurrencyID))

DECLARE @TempAg AS TABLE (custid INT ,Currency int)
INSERT INTO @TempAg (custid,currency)
SELECT CustID ,lc.Currency
		FROM bodb_Licensee.dbo.f_SelLicenseeCust(@licenseeID) lc
		INNER JOIN #Currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID 
		WHERE [Description] = COALESCE(@LicenseeType,[Description])

INSERT INTO @Exchange (exchangedate,exchangeid,usd,eur,myr,gbp,code)
SELECT exchangedate,exchangeid,usd,eur,myr,gbp,code
FROM Lrf_f_GetExchangeDaily(@Today,@Today)
WHERE exchangeid IN (SELECT Currency FROM @TempAg)

IF (SELECT COUNT(*) FROM @TempAg) = 1
BEGIN
	SELECT TOP 1 @UserName = username FROM CustInfo c WITH (NOLOCK)
	WHERE roleid = 2 and custid IN (select custid from @TempAg)
END

SELECT 
	@TotalMemberActive = ISNULL(SUM(CASE WHEN Closed = 0 AND ISNULL(reject,0) = 0 THEN 1 ELSE 0 END), 0),
	@TotalMemberClosed = ISNULL(SUM(CASE WHEN Closed = 1 THEN 1 ELSE 0 END), 0)
	,@TotalMemberSuspended = ISNULL(SUM(CASE WHEN ISNULL(reject,0) = 1 AND closed = 0 THEN 1 ELSE 0 END), 0)
FROM CustInfo WITH (NOLOCK)
WHERE 
	Recommend IN (SELECT DISTINCT CustID FROM @TempAg)
AND RoleID=1
/*
DECLARE @Super AS TABLE (custid int primary key, currency int)

INSERT INTO @Super (Custid,currency)
SELECT custid,currency
FROM Dep_Custsuper dc(NOLOCK)
	INNER JOIN #Currency c ON dc.Currency=c.CurrencyID
WHERE
dc.site = @LicenseeName 
*/
-----------------------
DROP TABLE #Currency
-----------------------

--outstanding then get today rate
INSERT INTO @SumOutstanding (currency,outstanding)
	SELECT a.currency,ISNULL(SUM(b.actual_stake),0)
	FROM 
		dbo.bettrans b WITH(NOLOCK) 
		INNER JOIN @TempAg a ON b.recommend = a.custid AND b.currency = a.currency
	WHERE 
		--b.bettype <= 1299 
		b.bettype <= 1399 
		AND b.statusid IN (0,1)
	GROUP BY a.currency

--Keno sport
INSERT INTO @SumOutstanding (currency,outstanding)
	SELECT a.currency,ISNULL(SUM(b.actual_stake),0)
	FROM 
		bodb02.dbo.Translog b WITH(NOLOCK) 
		INNER JOIN @TempAg a ON b.recommend = a.custid AND b.currency = a.currency
	WHERE 
		--b.productid =202--Keno 
		--AND 
		b.statusid = 0 -- running
	GROUP BY a.currency

--Voidbridge
INSERT INTO @SumOutstanding (currency,outstanding)
	SELECT a.currency,ISNULL(SUM(b.actual_stake),0)
	FROM 
		dbo.bettransRnG b WITH(NOLOCK) 
		INNER JOIN @TempAg a ON b.recommend = a.custid AND b.currency = a.currency
	WHERE 
		b.gameID BETWEEN 4001 AND 7999
		AND b.statusid IN (0,1)
	GROUP BY a.currency
	
SELECT 
	@MemberOutstanding=ISNULL(SUM(outstanding),0),
	@MemberOutstandingUSD=ISNULL(SUM(outstanding*e.USD),0),
	@MemberOutstandingEUR=ISNULL(SUM(outstanding*e.EUR),0),
	@MemberOutstandingGBP=ISNULL(SUM(outstanding*e.GBP),0)
FROM 
	@SumOutstanding b 
	--INNER JOIN (SELECT * FROM Lrf_f_GetExchangeDaily(@Today,@Today))e 
	INNER JOIN @Exchange e
	ON e.exchangeid = b.currency	
	
	
--****Begin For Yesterday and Today Winloss Part***	
--Yesterday/Today Licensee WL
CREATE TABLE #Temp_Bettrans
			 ( srecommend int
			   ,winlostdate smalldatetime
			   ,bettype smallint
			   ,currency int
			   ,statusID tinyint
			   ,recommend int
			   ,winlost money
			   ,tpositiontaking smallmoney
			   ,comm money
			   ,playercomm money
			   ,awinlost money
			   ,actual_stake money
			   ,betdaqid bigint
			 )

INSERT INTO #Temp_Bettrans (srecommend
							,winlostdate
							,bettype
							,currency 
							,statusID
							,recommend
							,winlost
							,tpositiontaking
							,comm
							,playercomm
							,awinlost
							,actual_stake
							,betdaqid
							)
SELECT srecommend
	  ,winlostdate
	  ,bettype
	  ,ag.currency
	  ,statusID
	  ,recommend
	  ,winlost
	  ,tpositiontaking
	  ,comm
	  ,playercomm
	  ,awinlost
	  ,actual_stake
	  ,betdaqid
FROM dbo.bettrans b WITH(NOLOCK) 
	INNER JOIN 	@TempAg ag ON b.recommend = ag.CustId AND b.Currency = ag.Currency
WHERE 
	 b.winlostdate BETWEEN @MoveBetsDay AND @Today 
	AND (b.bettype <= 1599 OR b.bettype BETWEEN 4001 AND 7999)
	AND b.statusID IN (111,112,113)

INSERT INTO @LicenseeWL (winlostdate,currency,LicenseeWL,AmtDuetoBA,AmtDuetoRB,WinlossRB,CommBA,CommRB,PlayerComm,WLBetTicket,BetTradeComm,WLBoughtTicket)
SELECT
	b.winlostdate,a.currency,
	
	ISNULL(- SUM(
			CASE WHEN (
			(
				(bettype < 31 OR bettype BETWEEN 121 AND 999 OR (bettype BETWEEN 1301 AND 1399)) 
				AND b.tpositiontaking<>0 AND bettype NOT IN(901,902,903,904)
			) 
			OR 
			(
				b.bettype BETWEEN 81 AND 120 
				OR b.bettype BETWEEN 1101 AND 1199 
				OR b.bettype BETWEEN 1201 AND 1299 
				OR b.bettype BETWEEN 1501 AND 1599 --Keno
				OR b.bettype BETWEEN 4001 AND 7999
			 
				OR b.bettype IN (73)
			)
		  )  
			THEN (b.winlost - b.actual_stake)  
			WHEN b.bettype BETWEEN 31 AND 33 THEN awinlost
			ELSE 0 END),0) as LicenseeWL,	--20130619@Daniel: Fix more bug regconize BA tickets
	ISNULL(- SUM ( CASE WHEN b.tpositiontaking=0 AND ((b.bettype NOT BETWEEN 31 AND 120 AND b.bettype<=999 AND b.bettype NOT IN (901,902,903,904)) OR (b.bettype BETWEEN 1301 and 1399)) THEN (b.winlost - b.actual_stake + awinlost + comm) ELSE 0 END),0) AS AmtDuetoBA,
	ISNULL(- SUM ( CASE WHEN b.bettype IN (31,32,33) THEN (b.winlost - b.actual_stake + awinlost + comm) ELSE 0 END),0)AS AmtDuetoRB,
	ISNULL(SUM (CASE WHEN b.bettype IN (31,32,33) THEN b.awinlost ELSE 0 END),0) AS WinlossRB,
	ISNULL(SUM ( CASE WHEN b.tpositiontaking=0 AND ((b.bettype NOT BETWEEN 31 AND 120 AND b.bettype<=999 AND b.bettype NOT IN (901,902,903,904)) OR (b.bettype BETWEEN 1301 and 1399)) THEN  comm  ELSE 0 END),0) AS CommBA,
	ISNULL(SUM ( CASE WHEN b.bettype IN (31,32,33) THEN comm  ELSE 0 END),0) AS CommRB,
	ISNULL(SUM (  playercomm ),0) AS PlayerComm,
	SUM(CASE WHEN (bettype < 31 OR bettype BETWEEN 121 AND 999 OR (bettype BETWEEN 1301 AND 1399)) AND bettype NOT IN(901,902,903,904)
					AND betdaqid =0 THEN (b.winlost-b.actual_stake)
				ELSE 0 END) AS WLBetTicket,
	SUM(CASE WHEN b.bettype =903 THEN b.awinlost
				ELSE 0 END) AS BetTradeComm,		
			SUM(CASE WHEN b.bettype =902 THEN (b.winlost-b.actual_stake)
				ELSE 0 END) AS WLBoughtTicket
	
FROM #Temp_Bettrans b 
	INNER JOIN @TempAg a ON b.recommend = a.custid AND b.currency = a.currency
GROUP BY b.winlostdate,a.currency


SELECT   
	@YesterdayLicenseeWL = sum(LicenseeWL),
	@YesterdayLicenseeWLUSD = sum(LicenseeWL*e.USD),
	@YesterdayLicenseeWLEUR = sum(LicenseeWL*e.EUR),
	@YesterdayLicenseeWLGBP = sum(LicenseeWL*e.GBP),
	@YesterdayAmtDuetoBA = sum(AmtDuetoBA),
	@YesterdayAmtDuetoBAUSD = sum(AmtDuetoBA*e.USD),
	@YesterdayAmtDuetoBAEUR = sum(AmtDuetoBA*e.EUR),
	@YesterdayAmtDuetoBAGBP = sum(AmtDuetoBA*e.GBP),
	@YesterdayAmtDuetoRB = sum(AmtDuetoRB),
	@YesterdayAmtDuetoRBUSD = sum(AmtDuetoRB*e.USD),
	@YesterdayAmtDuetoRBEUR = sum(AmtDuetoRB*e.EUR),
	@YesterdayAmtDuetoRBGBP = sum(AmtDuetoRB*e.GBP),
	@YesterdayWinlossRB = sum(WinlossRB),
	@YesterdayWinlossRBUSD = sum(WinlossRB*e.USD),
	@YesterdayWinlossRBEUR = sum(WinlossRB*e.EUR),
	@YesterdayWinlossRBGBP = sum(WinlossRB*e.GBP),
	@YesterdayCommBA = sum(CommBA),
	@YesterdayCommBAUSD = sum(CommBA*e.USD),
	@YesterdayCommBAEUR = sum(CommBA*e.EUR),
	@YesterdayCommBAGBP = sum(CommBA*e.GBP),
	@YesterdayCommRB = sum(CommRB),
	@YesterdayCommRBUSD = sum(CommRB*e.USD),
	@YesterdayCommRBEUR = sum(CommRB*e.EUR),--
	@YesterdayCommRBGBP = sum(CommRB*e.GBP),--
	@YesterdayPlayerComm    = sum(PlayerComm),
	@YesterdayPlayerCommUSD = sum(PlayerComm*e.USD),
	@YesterdayPlayerCommEUR = sum(PlayerComm*e.EUR), -- yesterday
	@YesterdayPlayerCommGBP = sum(PlayerComm*e.GBP), -- yesterday
	@YesterdayBetTradeComm  = sum(BetTradeComm),
	@YesterdayBetTradeCommUSD = sum(BetTradeComm*e.USD),
	@YesterdayBetTradeCommEUR = sum(BetTradeComm*e.EUR),
	@YesterdayBetTradeCommGBP = sum(BetTradeComm*e.GBP),
	@YesterdayAmtDueToBT	  =  sum(b.WLBetTicket+b.WLBoughtTicket-b.BetTradeComm),
	@YesterdayAmtDueToBTUSD	  =  sum((b.WLBetTicket+b.WLBoughtTicket-b.BetTradeComm)*e.USD),
	@YesterdayAmtDueToBTEUR	  =  sum((b.WLBetTicket+b.WLBoughtTicket-b.BetTradeComm)*e.EUR),
	@YesterdayAmtDueToBTGBP	  =  sum((b.WLBetTicket+b.WLBoughtTicket-b.BetTradeComm)*e.GBP)
	
FROM 
	@LicenseeWL b 
	INNER JOIN (SELECT * FROM Lrf_f_GetExchangeDaily(@Yesterday,@Yesterday))e 	
		ON e.exchangeid = b.currency AND b.winlostdate = @Yesterday


SELECT   
	@TodayLicenseeWL = sum(LicenseeWL),
	@TodayLicenseeWLUSD = sum(LicenseeWL*e.USD),
	@TodayLicenseeWLEUR = sum(LicenseeWL*e.EUR),
	@TodayLicenseeWLGBP = sum(LicenseeWL*e.GBP),
	@TodayAmtDuetoBA = sum(AmtDuetoBA),
	@TodayAmtDuetoBAUSD = sum(AmtDuetoBA*e.USD),
	@TodayAmtDuetoBAEUR = sum(AmtDuetoBA*e.EUR),
	@TodayAmtDuetoBAGBP = sum(AmtDuetoBA*e.GBP),
	@TodayAmtDuetoRB = sum(AmtDuetoRB),
	@TodayAmtDuetoRBUSD = sum(AmtDuetoRB*e.USD),
	@TodayAmtDuetoRBEUR = sum(AmtDuetoRB*e.EUR),
	@TodayAmtDuetoRBGBP = sum(AmtDuetoRB*e.GBP),
	@TodayWinlossRB = sum(WinlossRB),
	@TodayWinlossRBUSD = sum(WinlossRB*e.USD),
	@TodayWinlossRBEUR = sum(WinlossRB*e.EUR),
	@TodayWinlossRBGBP = sum(WinlossRB*e.GBP),
	
	@TodayCommBA = sum(CommBA),
	@TodayCommBAUSD = sum(CommBA*e.USD),
	@TodayCommBAEUR = sum(CommBA*e.EUR),
	@TodayCommBAGBP = sum(CommBA*e.GBP),
	@TodayCommRB = sum(CommRB),
	@TodayCommRBUSD = sum(CommRB*e.USD),
	@TodayCommRBEUR = sum(CommRB*e.EUR),
	@TodayCommRBGBP = sum(CommRB*e.GBP),
	@TodayPlayerComm=ISNULL(SUM(playercomm),0),
	@TodayPlayerCommUSD=ISNULL(SUM(Playercomm*e.USD),0),
	@TodayPlayerCommEUR=ISNULL(SUM((Playercomm)*e.EUR),0),
	@TodayPlayerCommGBP=ISNULL(SUM((Playercomm)*e.GBP),0),
	@TodayBetTradeComm  = sum(BetTradeComm),
	@TodayBetTradeCommUSD = sum(BetTradeComm*e.USD),
	@TodayBetTradeCommEUR = sum(BetTradeComm*e.EUR),
	@TodayBetTradeCommGBP = sum(BetTradeComm*e.GBP),
	@TodayAmtDueToBT	  =  sum(b.WLBetTicket+b.WLBoughtTicket-b.BetTradeComm),
	@TodayAmtDueToBTUSD	  =  sum((b.WLBetTicket+b.WLBoughtTicket-b.BetTradeComm)*e.USD),
	@TodayAmtDueToBTEUR	  =  sum((b.WLBetTicket+b.WLBoughtTicket-b.BetTradeComm)*e.EUR),
	@TodayAmtDueToBTGBP	  =  sum((b.WLBetTicket+b.WLBoughtTicket-b.BetTradeComm)*e.GBP)
	
FROM 
	@LicenseeWL b 
	INNER JOIN (SELECT * FROM Lrf_f_GetExchangeDaily(@Today,@Today))e 	
		ON  e.exchangeid = b.currency AND b.winlostdate = @Today
			
 --****End For Yesterday and Today Winloss Part***	

			
--****Begin for Selected Month Winloss part*******			
DECLARE @TempFromDate DATETIME 
DECLARE @TempToDate DATETIME

IF @_ToDate > @MoveBetsDay
BEGIN
	IF @_FromDate <= @MoveBetsDay 
		SET @TempFromDate =  DATEADD(DAY,1,@MoveBetsDay)
	ELSE
		SET @TempFromDate = @_FromDate
	
	INSERT INTO @SumTemp(currency,
						SelectedMonthLicenseeWL,
						SelectedMonthAmtDuetoBA,
						SelectedMonthAmtDuetoRB,
						SelectedMonthWinlossRB,
						SelectedMonthCommBA,
						SelectedMonthCommRB,
						SelectedMonthPlayerComm,
						SelectedMonthBetTradeComm,
						SelectedMonthWLBetTicket,
						SelectedMonthWLBoughtTicket
						)
						
	SELECT 
		b.currency,
		ISNULL(SUM(LicenseeWL),0),
		ISNULL(SUM(AmtDuetoBA),0),
		ISNULL(SUM(AmtDuetoRB),0),
		ISNULL(SUM (WinlossRB),0),
		ISNULL(SUM (CommBA),0),
		ISNULL(SUM (CommRB),0),
		ISNULL(SUM (playercomm),0),
		ISNULL(SUM (BetTradeComm),0),
		ISNULL(SUM (b.WLBetTicket),0),
		ISNULL(SUM (b.WLBoughtTicket),0)
	FROM 
		@LicenseeWL b
	WHERE 
		b.winlostdate BETWEEN @TempFromDate AND @_ToDate 
	GROUP by b.currency
	
	
END
IF @_FromDate <= @MoveBetsDay AND @IsOld = 0
BEGIN
	IF @_ToDate >= @MoveBetsDay
		SET @TempToDate = @MoveBetsDay
	ELSE
		SET  @TempToDate = @_ToDate

	INSERT INTO @SumTemp 
	SELECT 
		ag.currency,
		ISNULL(- SUM(CASE WHEN ISNULL(b.isBA,0) = 0 AND (b.sporttype IN (0,161,162,180,251,252,202 ))  THEN b.winlost ELSE 0 END),0) AS SelectedMonthLicenseeWL,
		ISNULL(- SUM ( CASE WHEN ISNULL(b.isBA,0) = 1 THEN  (b.winlost+b.awinlost+b.comm) ELSE 0 END),0) AS SelectedMonthAmtDuetoBA,
		ISNULL(- SUM ( CASE WHEN b.sporttype = 151 THEN (b.winlost+b.awinlost+b.comm) ELSE 0 END),0) AS SelectedMonthAmtDuetoRB,
		ISNULL(SUM (CASE WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END),0) AS SelectedMonthWinlossRB,
		ISNULL(SUM ( CASE WHEN ISNULL(b.isBA,0) = 1 THEN  comm  ELSE 0 END),0) AS SelectedMonthCommBA,
		ISNULL(SUM ( CASE WHEN b.sporttype = 151 THEN comm ELSE 0 END),0)  AS SelectedMonthCommRB,
		ISNULL(SUM ( playercomm),0) AS SelectedMonthPlayerComm,
		SUM(CASE WHEN b.bettype =903 THEN b.awinlost
				ELSE 0 END) AS SelectedMonthBetTradeComm,
		ISNULL(SUM(CASE WHEN (b.sporttype =0 AND b.bettype NOT IN (901,902,903,904)) AND bt.Custid IS NOT NULL THEN b.winlost ELSE 0 END),0) AS SelectedMonthWLBetTicket,			
		SUM(CASE WHEN b.bettype =902 THEN (b.winlost)
				ELSE 0 END) AS SelectedMonthWLBoughtTicket
	FROM 
		bodb_Licensee.dbo.rptLicWinloss2 b WITH(NOLOCK) 
		INNER JOIN 	@TempAg ag ON b.recommend = ag.CustId AND b.Currency = ag.Currency
		LEFT JOIN f_GetBetTradeCustList(@LicenseeName) bt ON b.custid=bt.Custid AND b.Currency = bt.currency
	WHERE
		b.Winlostdate BETWEEN @_FromDate AND @TempToDate AND	
		roleID = 1 AND 
		b.statusID <> 101 --exclude REJECT bets
	GROUP BY ag.currency
	
END	
ELSE IF @IsOld = 1
BEGIN
	INSERT INTO @SumTemp
	SELECT 
		ag.currency,
		ISNULL(- SUM(CASE WHEN ISNULL(b.isBA,0) = 0 AND ( b.sporttype IN (0,161,162,180,251,252,202 ))  THEN b.winlost ELSE 0 END),0) AS SelectedMonthLicenseeWL,
		ISNULL(- SUM ( CASE WHEN ISNULL(b.isBA,0) = 1 THEN  (b.winlost+b.awinlost+b.comm) ELSE 0 END),0) AS SelectedMonthAmtDuetoBA,
		ISNULL(- SUM ( CASE WHEN b.sporttype = 151 THEN (b.winlost+b.awinlost+b.comm) ELSE 0 END),0) AS SelectedMonthAmtDuetoRB,
		ISNULL(SUM (CASE WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END),0) AS SelectedMonthWinlossRB,
		ISNULL(SUM ( CASE WHEN ISNULL(b.isBA,0) = 1 THEN  comm  ELSE 0 END),0) AS SelectedMonthCommBA,
		ISNULL(SUM ( CASE WHEN b.sporttype = 151 THEN comm  ELSE 0 END),0)  AS SelectedMonthCommRB,
		ISNULL(SUM ( playercomm ),0) AS SelectedMonthPlayerComm,
		SUM(CASE WHEN b.bettype =903 THEN b.awinlost
				ELSE 0 END) AS SelectedMonthBetTradeComm,
		ISNULL(SUM(CASE WHEN (b.sporttype =0 AND b.bettype NOT IN (901,902,903,904)) AND bt.Custid IS NOT NULL THEN b.winlost ELSE 0 END),0) AS SelectedMonthWLBetTicket,			
		SUM(CASE WHEN b.bettype =902 THEN (b.winlost)
				ELSE 0 END) AS SelectedMonthWLBoughtTicket
	FROM 
		bodb_Licensee.dbo.rptLicWinloss_old b WITH(NOLOCK)
		INNER JOIN 	@TempAg ag ON b.recommend = ag.CustId AND b.Currency = ag.Currency	
		LEFT JOIN f_GetBetTradeCustList(@LicenseeName) bt ON b.custid=bt.Custid AND b.Currency = bt.currency
	WHERE
		b.Winlostdate BETWEEN @_FromDate AND @_ToDate AND	
		roleID = 1 AND 
		b.statusID <> 101 --exclude REJECT bets
	--GROUP BY winlostdate,currency
	GROUP BY ag.currency
END


SELECT 
	@SelectedMonthLicenseeWL = SUM(SelectedMonthLicenseeWL),
	@SelectedMonthLicenseeWLUSD = SUM(SelectedMonthLicenseeWL * e.USD),
	@SelectedMonthLicenseeWLEUR = SUM(SelectedMonthLicenseeWL * e.EUR),
	@SelectedMonthLicenseeWLGBP = SUM(SelectedMonthLicenseeWL * e.GBP),
	@SelectedMonthAmtDuetoBA =  SUM(SelectedMonthAmtDuetoBA),
	@SelectedMonthAmtDuetoBAUSD = SUM(SelectedMonthAmtDuetoBA * e.USD),
	@SelectedMonthAmtDuetoBAEUR = SUM(SelectedMonthAmtDuetoBA * e.EUR),
	@SelectedMonthAmtDuetoBAGBP = SUM(SelectedMonthAmtDuetoBA * e.GBP),
	@SelectedMonthAmtDuetoRB = SUM(SelectedMonthAmtDuetoRB),
	@SelectedMonthAmtDuetoRBUSD =  SUM(SelectedMonthAmtDuetoRB * e.USD),
	@SelectedMonthAmtDuetoRBEUR = SUM(SelectedMonthAmtDuetoRB * e.EUR),
	@SelectedMonthAmtDuetoRBGBP = SUM(SelectedMonthAmtDuetoRB * e.GBP),
	@SelectedMonthWinlossRB = SUM(SelectedMonthWinlossRB),
	@SelectedMonthWinlossRBUSD = SUM(SelectedMonthWinlossRB * e.USD),
	@SelectedMonthWinlossRBEUR = SUM(SelectedMonthWinlossRB * e.EUR),
	@SelectedMonthWinlossRBGBP = SUM(SelectedMonthWinlossRB * e.GBP),
	@SelectedMonthCommBA = SUM(SelectedMonthCommBA),
	@SelectedMonthCommBAUSD = SUM(SelectedMonthCommBA * e.USD),
	@SelectedMonthCommBAEUR =  SUM(SelectedMonthCommBA * e.EUR),
	@SelectedMonthCommBAGBP =  SUM(SelectedMonthCommBA * e.GBP),
	@SelectedMonthCommRB = SUM(SelectedMonthCommRB),
	@SelectedMonthCommRBUSD = SUM(SelectedMonthCommRB * e.USD),
	@SelectedMonthCommRBEUR = SUM(SelectedMonthCommRB * e.EUR),----
	@SelectedMonthCommRBGBP = SUM(SelectedMonthCommRB * e.GBP),----
	@SelectedMonthPlayerComm = SUM(SelectedMonthPLayerComm),
	@SelectedMonthPlayerCommUSD = SUM(SelectedMonthPlayerComm * e.USD),
	@SelectedMonthPlayerCommEUR =  SUM(SelectedMonthPlayerComm * e.EUR),
	@SelectedMonthPlayerCommGBP =  SUM(SelectedMonthPlayerComm * e.GBP),
	@SelectedMonthBetTradeComm = SUM(SelectedMonthBetTradeComm),
	@SelectedMonthBetTradeCommUSD = SUM(SelectedMonthBetTradeComm * e.USD),
	@SelectedMonthBetTradeCommEUR =  SUM(SelectedMonthBetTradeComm * e.EUR),
	@SelectedMonthBetTradeCommGBP =  SUM(SelectedMonthBetTradeComm * e.GBP),
	@SelectedMonthAmtDueToBT	  = SUM(SelectedMonthWLBetTicket+SelectedMonthWLBoughtTicket-SelectedMonthBetTradeComm),
	@SelectedMonthAmtDueToBTUSD = SUM((SelectedMonthWLBetTicket+SelectedMonthWLBoughtTicket-SelectedMonthBetTradeComm) * e.USD),
	@SelectedMonthAmtDueToBTEUR =  SUM((SelectedMonthWLBetTicket+SelectedMonthWLBoughtTicket-SelectedMonthBetTradeComm) * e.EUR),
	@SelectedMonthAmtDueToBTGBP =  SUM((SelectedMonthWLBetTicket+SelectedMonthWLBoughtTicket-SelectedMonthBetTradeComm) * e.GBP)
	

FROM 
	@SumTemp b 
	INNER JOIN (SELECT * FROM Lrf_f_GetExchangeDaily(@_FromDate,@_FromDate))e 	
	ON e.exchangeid = b.currency
--****End for Selected Month Winloss part*******			


SELECT
	ISNULL(@UserName,'') AS UserName,
	ISNULL(@SelectedMonthLicenseeWL,0) AS SelectedMonthLicenseeWL,
	ISNULL(@SelectedMonthLicenseeWLUSD,0) AS SelectedMonthLicenseeWLUSD,
	ISNULL(@SelectedMonthLicenseeWLEUR,0) AS SelectedMonthLicenseeWLEUR,
	ISNULL(@SelectedMonthLicenseeWLGBP,0) AS SelectedMonthLicenseeWLGBP,
	ISNULL(@SelectedMonthWinlossRB,0) AS SelectedMonthWinlossRB,
	ISNULL(@SelectedMonthWinlossRBUSD,0) AS SelectedMonthWinlossRBUSD,
	ISNULL(@SelectedMonthWinlossRBEUR,0) AS SelectedMonthWinlossRBEUR,
	ISNULL(@SelectedMonthWinlossRBGBP,0) AS SelectedMonthWinlossRBGBP,
	--Month Comm
	ISNULL(@SelectedMonthCommBA,0) AS SelectedMonthCommBA,
	ISNULL(@SelectedMonthCommBAUSD,0) AS SelectedMonthCommBAUSD,
	ISNULL(@SelectedMonthCommBAEUR,0) AS SelectedMonthCommBAEUR,
	ISNULL(@SelectedMonthCommBAGBP,0) AS SelectedMonthCommBAGBP,
	ISNULL(@SelectedMonthCommRB,0) AS SelectedMonthCommRB,
	ISNULL(@SelectedMonthCommRBUSD,0) AS SelectedMonthCommRBUSD,
	ISNULL(@SelectedMonthCommRBEUR,0) AS SelectedMonthCommRBEUR,---
	ISNULL(@SelectedMonthCommRBGBP,0) AS SelectedMonthCommRBGBP,---
	ISNULL(@SelectedMonthPlayerComm,0) AS SelectedMonthPlayerComm,
	ISNULL(@SelectedMonthPlayerCommUSD,0) AS SelectedMonthPlayerCommUSD,
	ISNULL(@SelectedMonthPlayerCommEUR,0) AS SelectedMonthPlayerCommEUR,
	ISNULL(@SelectedMonthPlayerCommGBP,0) AS SelectedMonthPlayerCommGBP,

	--Month Amount Due To BA
	ISNULL(@SelectedMonthAmtDuetoBA,0) AS SelectedMonthAmtDuetoBA,
	ISNULL(@SelectedMonthAmtDuetoBAUSD,0) AS SelectedMonthAmtDuetoBAUSD,
	ISNULL(@SelectedMonthAmtDuetoBAEUR,0) AS SelectedMonthAmtDuetoBAEUR,
	ISNULL(@SelectedMonthAmtDuetoBAGBP,0) AS SelectedMonthAmtDuetoBAGBP,
	ISNULL(@SelectedMonthAmtDuetoRB,0) AS SelectedMonthAmtDuetoRB,
	ISNULL(@SelectedMonthAmtDuetoRBUSD,0) AS SelectedMonthAmtDuetoRBUSD,
	ISNULL(@SelectedMonthAmtDuetoRBEUR,0) AS SelectedMonthAmtDuetoRBEUR,
	ISNULL(@SelectedMonthAmtDuetoRBGBP,0) AS SelectedMonthAmtDuetoRBGBP,
	-- Month Bettrade 
	ISNULL(@SelectedMonthBetTradeComm,0) AS SelectedMonthBetTradeComm,
	ISNULL(@SelectedMonthBetTradeCommUSD,0) AS SelectedMonthBetTradeCommUSD,
	ISNULL(@SelectedMonthBetTradeCommEUR,0) AS SelectedMonthBetTradeCommEUR,
	ISNULL(@SelectedMonthBetTradeCommGBP,0) AS SelectedMonthBetTradeCommGBP,
	ISNULL(@SelectedMonthAmtDueToBT,0) AS SelectedMonthAmtDueToBT,
	ISNULL(@SelectedMonthAmtDueToBTUSD,0) AS SelectedMonthAmtDueToBTUSD,
	ISNULL(@SelectedMonthAmtDueToBTEUR,0) AS SelectedMonthAmtDueToBTEUR,
	ISNULL(@SelectedMonthAmtDueToBTGBP,0) AS SelectedMonthAmtDueToBTGBP,
	
	--Yesterday WL
	ISNULL(@YesterdayLicenseeWL,0) AS YesterdayLicenseeWL,
	ISNULL(@YesterdayLicenseeWLUSD,0) AS YesterdayLicenseeWLUSD,
	ISNULL(@YesterdayLicenseeWLEUR,0) AS YesterdayLicenseeWLEUR,
	ISNULL(@YesterdayLicenseeWLGBP,0) AS YesterdayLicenseeWLGBP,
	ISNULL(@YesterdayWinlossRB,0) AS YesterdayWinlossRB,
	ISNULL(@YesterdayWinlossRBUSD,0) AS YesterdayWinlossRBUSD,
	ISNULL(@YesterdayWinlossRBEUR,0) AS YesterdayWinlossRBEUR,
	ISNULL(@YesterdayWinlossRBGBP,0) AS YesterdayWinlossRBGBP,
	--Yesterday Comm
	ISNULL(@YesterdayCommBA,0) AS YesterdayCommBA,
	ISNULL(@YesterdayCommBAUSD,0) AS YesterdayCommBAUSD,
	ISNULL(@YesterdayCommBAEUR,0) AS YesterdayCommBAEUR,
	ISNULL(@YesterdayCommBAGBP,0) AS YesterdayCommBAGBP,
	ISNULL(@YesterdayCommRB,0) AS YesterdayCommRB,
	ISNULL(@YesterdayCommRBUSD,0) AS YesterdayCommRBUSD,
	ISNULL(@YesterdayCommRBEUR,0) AS YesterdayCommRBEUR,--
	ISNULL(@YesterdayCommRBGBP,0) AS YesterdayCommRBGBP,--
	ISNULL(@YesterdayPlayerComm,0) AS YesterdayPlayerComm,
	ISNULL(@YesterdayPlayerCommUSD,0) AS YesterdayPlayerCommUSD,
	ISNULL(@YesterdayPlayerCommEUR,0) AS YesterdayPlayerCommEUR,
	ISNULL(@YesterdayPlayerCommGBP,0) AS YesterdayPlayerCommGBP,
	
	--YesterdayAmtDue
	ISNULL(@YesterdayAmtDuetoBA,0) AS YesterdayAmtDuetoBA,
	ISNULL(@YesterdayAmtDuetoBAUSD,0) AS YesterdayAmtDuetoBAUSD,
	ISNULL(@YesterdayAmtDuetoBAEUR,0) AS YesterdayAmtDuetoBAEUR,
	ISNULL(@YesterdayAmtDuetoBAGBP,0) AS YesterdayAmtDuetoBAGBP,
	ISNULL(@YesterdayAmtDuetoRB,0) AS YesterdayAmtDuetoRB,
	ISNULL(@YesterdayAmtDuetoRBUSD,0) AS YesterdayAmtDuetoRBUSD,
	ISNULL(@YesterdayAmtDuetoRBEUR,0) AS YesterdayAmtDuetoRBEUR,
	ISNULL(@YesterdayAmtDuetoRBGBP,0) AS YesterdayAmtDuetoRBGBP,

	-- yesterday bettrade
	ISNULL(@YesterdayBetTradeComm,0) AS YesterdayBetTradeComm,
	ISNULL(@YesterdayBetTradeCommUSD,0) AS YesterdayBetTradeCommUSD,
	ISNULL(@YesterdayBetTradeCommEUR,0) AS YesterdayBetTradeCommEUR,
	ISNULL(@YesterdayBetTradeCommGBP,0) AS YesterdayBetTradeCommGBP,
	ISNULL(@YesterdayAmtDueToBT,0) AS YesterdayAmtDueToBT,
	ISNULL(@YesterdayAmtDueToBTUSD,0) AS YesterdayAmtDueToBTUSD,
	ISNULL(@YesterdayAmtDueToBTEUR,0) AS YesterdayAmtDueToBTEUR,
	ISNULL(@YesterdayAmtDueToBTGBP,0) AS YesterdayAmtDueToBTGBP,

	--TodayLicenseeWL
	ISNULL(@TodayLicenseeWL,0) AS TodayLicenseeWL,
	ISNULL(@TodayLicenseeWLUSD,0) AS TodayLicenseeWLUSD,
	ISNULL(@TodayLicenseeWLEUR,0) AS TodayLicenseeWLEUR,
	ISNULL(@TodayLicenseeWLGBP,0) AS TodayLicenseeWLGBP,
	ISNULL(@TodayWinlossRB,0) AS TodayWinlossRB,
	ISNULL(@TodayWinlossRBUSD,0) AS TodayWinlossRBUSD,
	ISNULL(@TodayWinlossRBEUR,0) AS TodayWinlossRBEUR,
	ISNULL(@TodayWinlossRBGBP,0) AS TodayWinlossRBGBP,
	--TodayComm
	ISNULL(@TodayCommBA,0) AS TodayCommBA,
	ISNULL(@TodayCommBAUSD,0) AS TodayCommBAUSD,
	ISNULL(@TodayCommBAEUR,0) AS TodayCommBAEUR,
	ISNULL(@TodayCommBAGBP,0) AS TodayCommBAGBP,
	ISNULL(@TodayCommRB,0) AS TodayCommRB,
	ISNULL(@TodayCommRBUSD,0) AS TodayCommRBUSD,
	ISNULL(@TodayCommRBEUR,0) AS TodayCommRBEUR,---
	ISNULL(@TodayCommRBGBP,0) AS TodayCommRBGBP,---
	ISNULL(@TodayPlayerComm,0) AS TodayPlayerComm,
	ISNULL(@TodayPlayerCommUSD,0) AS TodayPlayerCommUSD,
	ISNULL(@TodayPlayerCommEUR,0) AS TodayPlayerCommEUR,
	ISNULL(@TodayPlayerCommGBP,0) AS TodayPlayerCommGBP,
	
	--TodayAmtDueToBA
	ISNULL(@TodayAmtDuetoBA,0) AS TodayAmtDuetoBA,
	ISNULL(@TodayAmtDuetoBAUSD,0) AS TodayAmtDuetoBAUSD,
	ISNULL(@TodayAmtDuetoBAEUR,0) AS TodayAmtDuetoBAEUR,
	ISNULL(@TodayAmtDuetoBAGBP,0) AS TodayAmtDuetoBAGBP,
	ISNULL(@TodayAmtDuetoRB,0) AS TodayAmtDuetoRB,
	ISNULL(@TodayAmtDuetoRBUSD,0) AS TodayAmtDuetoRBUSD,
	ISNULL(@TodayAmtDuetoRBEUR,0) AS TodayAmtDuetoRBEUR,
	ISNULL(@TodayAmtDuetoRBGBP,0) AS TodayAmtDuetoRBGBP,

	-- Today bettrade
	ISNULL(@TodayBetTradeComm,0)	AS TodayBetTradeComm,
	ISNULL(@TodayBetTradeCommUSD,0) AS TodayBetTradeCommUSD,
	ISNULL(@TodayBetTradeCommEUR,0) AS TodayBetTradeCommEUR,
	ISNULL(@TodayBetTradeCommGBP,0) AS TodayBetTradeCommGBP,
	ISNULL(@TodayAmtDueToBT,0)		AS TodayAmtDueToBT,
	ISNULL(@TodayAmtDueToBTUSD,0) AS TodayAmtDueToBTUSD,
	ISNULL(@TodayAmtDueToBTEUR,0) AS TodayAmtDueToBTEUR,
	ISNULL(@TodayAmtDueToBTGBP,0) AS TodayAmtDueToBTGBP,
	--
	ISNULL(@MemberOutstanding,0) MemberOutstanding,
	ISNULL(@MemberOutstandingUSD,0) MemberOutstandingUSD,
	ISNULL(@MemberOutstandingEUR,0) MemberOutstandingEUR, 
	ISNULL(@MemberOutstandingGBP,0) MemberOutstandingGBP,
	
	ISNULL(@TotalMemberActive,0) TotalMemberActive,
	ISNULL(@TotalMemberClosed,0) TotalMemberClosed
	,ISNULL(@TotalMemberSuspended,0) TotalMemberSuspended

DROP TABLE #Temp_Bettrans
GO
GRANT EXECUTE ON [dbo].[Lrf_CustomerSelBalance] TO [bodbDownlineNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Lrf_CustomerSelBalance] TO [bodbLicenseeNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_CustomerSelBalance] TO [vnteam] AS [dbo]
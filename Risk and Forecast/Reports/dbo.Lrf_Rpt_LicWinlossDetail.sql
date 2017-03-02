USE [bodb02]
GO
ALTER PROCEDURE [dbo].[Lrf_Rpt_LicWinlossDetail_xpre]  
	@LicenseeID		INT,		
	@CustID			INT = 0, --AgentID		
	@FromDate		SMALLDATETIME,  
	@ToDate			SMALLDATETIME,   
	@showSB			BIT = 0,  
	@ShowRB			BIT = 0,  
	@ShowNG			BIT = 0,
	@ShowBA			BIT = 0,
	@ShowLC			BIT = 0,
	@ShowVS			BIT = 0,
	@ShowCS			BIT = 0, -- RNG Casino
	@ShowBG			BIT = 0, -- Bingo 
	@ShowKN			BIT = 0, -- Keno 
	@ShowMGCLC 		BIT = 0, -- MicroGamming
	@ShowMGCRnG 	BIT = 0, -- MicroGamming
	@ShowBT 		BIT = 0, -- licenseeWLBT
	@ShowAGC		BIT = 0, -- AGCasino
	@ShowVB			BIT = 0, -- Voidbridge
	@ShowAB			BIT = 0, -- Allbet
	@ShowFW			BIT = 0, -- Fishing World
	@MoveBetsDay	SMALLDATETIME,
	@IsOld			BIT = 0,
	@drawfilter		SMALLINT = 1,
	@AgentList		VARCHAR(MAX)

AS  
/*  Created: Henry  
	Date: 2012-01-09  
    Task : Winloss Report for Licensee Member Level
    DB: DB052.bodb02  
   
    Revisions:  
		- 20120214@Jim: change table ExchangeDaily by function Lrf_f_GetExchangeDaily  
		- 20120529@Henry: enhance performance
		- 20120726@Jim: add playercomm value 
		- 20120814@Jim: add ShowLiveCasino 
		- 20120830@Jim : add virtual Sport
		- 20121004@Jim : replace @Currency input param by @CurrencyID  
		- 20121115@Henry:  Only Sportsbook needs to exclude BA
		- 20121128@Henry: use new table LicenseeBATransaction_active to get bettrans BA tickets
		- 20130204@Jim: support RNG Casino and Bingo product
		- 20130414@Jim: support USD base currency 
		- 20130514@Jim: Restrict permission of Licensee Users by currency
		- 20130809@Jim: offer Virtual Horse Racing
		- 20130916@Jim: offer Virtual Tennis
		- 20131120@Victor: Enhance performance
		- 20140305@Florent: support Keno
		- 20140620@Florent: offer 14 new bettypes and Sporting Solution (36 new bettypes)
		- 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
		- 20141225@Jim: improve performance
		- 20150123@Jim: support base on Currency GBP
		- 20150612@Jim: support MicroGaming
		- 20150624@Winnie: support licenseeWLBT
		- 201508215@Winnie: Revever KeenOcean currency
		- 20150624@Winnie: fix bug bettrade dont count refund tickets.
		- 20150903@Winnie: fix bug bettrade #42874
		- 20150910@Jim: Integrate Microgaming RNG games (feature #43078)	
		- 20150921@Jim: Implement the changes on reports for AG Casino (#43172)
		- 20151108@Jim: Separated MicroGaming into 2 product
		- 20151230@Patrick: Add more output BuyBackAmt & BABuyBackAmt
		- 20151228@Bobby: Support MBC RNG Casino sporttype(208,209,210)
		- 20160216@Victor: Add Bettrade Actual Stake amount [Redmine: #51264]
		- 20160331@Percy: Support Voidbridge single wallet [Redmine: #55057]
		- 20160413@Victor: support MKK currency code [Redmine: #55745]
		- 20160718@Jim: Allbet - Live Casino Integration for Licensees (#59624)
		- 20160727@Jim:  LRF - Commercial terms changed for Bet Trade [Redmine: #61342]
		- 20161022@Jim:move table to bodb_licenseereport [RedmineID :#60449]
		- 20161115@Jim: LRF - Integrate new product Fishing World [RedmineID : #66737]
		- 20170227@Harper: LRF - Get data by @AgentList instead of @UserID [RedmineID: #71679]

	Param's Explanation:  
	  + @CustID: SuperID  
	  + @BaseCurrency (input currencyID): 2-MYR ; 3-USD; 6-EUR
	  +	@drawfilter: 'No Draw' filter is supportted (1:Normal 2:No Draw 3:No Draw for Turnover only)
	  + @IsOld: 0 - query IN table rptLicWinloss, 1 - query IN table rptLicWinloss_old. 
	  + @excludeTest: remove currency UUS
	  + @MoveBetsDay: The day we move tickets to bettrans14
	  + @AgentList: xml structure
					  <ROOT>
					   <Agent AgentId="12345" Currency="3"/>  
					   <Agent AgentId="12345" Currency="5"/>  
					  </ROOT>
*/  
/*
exec Lrf_Rpt_LicWinlossDetail_Ag_xpre  @licenseeid=1,@fromdate='2016-07-13 00:00:00',@todate='2016-07-13 00:00:00',@isold=0,@drawfilter=1,@excludetest=1,@movebetsday='2016-07-11 00:00:00',@showSB=1,@showRB=1,@showNG=1,@showBA=1,@showLC=1,@showVS=1,@showCS=1,@showKN=1,@showAGC=1,@showMGCLC=1,@showMGCRNG=1,@showVB=1

*/
BEGIN  
	SET NOCOUNT ON  

	CREATE TABLE #SAgWinLoss
	( 
		CustID				INT,
		Currency			INT,
		TurnoverSB			MONEY,
		TurnoverBA			MONEY,
		TurnoverNG			MONEY,
		TurnoverRB			MONEY,
		TurnoverLC			MONEY,
		TurnoverVS			MONEY,
		TurnoverCS 			MONEY,
		TurnoverBG			MONEY,
		TurnoverKN			MONEY,
		TurnoverMGCLC		MONEY,
		TurnoverMGCRnG		MONEY,
		TurnoverAGC			MONEY,
		TurnoverVB			MONEY,
		TurnoverAB			MONEY,
		TurnoverFW			MONEY,
		BTActualStake		MONEY,
		Winlost				MONEY,
		LicenseeWLSB		MONEY,
		LicenseeWLBA		MONEY,
		LicenseeWLNG		MONEY,
		LicenseeWLRB		MONEY,
		LicenseeWLLC		MONEY,
		LicenseeWLVS		MONEY,
		LicenseeWLCS		MONEY,
		LicenseeWLBG		MONEY,
		LicenseeWLKN		MONEY,
		LicenseeWLMGCLC		MONEY,
		LicenseeWLMGCRnG	MONEY,
		LicenseeWLAGC		MONEY,
		LicenseeWLVB		MONEY,
		LicenseeWLAB		MONEY,
		LicenseeWLFW		MONEY,
		AmtDueToBA			MONEY,   
		AmtDueToRB			MONEY,
		CommBA				MONEY,   
		CommRB				MONEY,
		PlayerComm  		MONEY,
		Betcount			BIGINT,
		licenseeWLBT		MONEY,   
		BetTradeComm		MONEY,  
		WLBetTicket			MONEY, 	
		WLBoughtTicket		MONEY,
		BuyBackAmtSB		MONEY,
		BuyBackAmtBA		MONEY,
	)

	DECLARE @tempAg			TABLE (custID INT, Currency INT)
	DECLARE @Code			VARCHAR(20)
	DECLARE @bettype		TABLE (bettype INT PRIMARY KEY)
	DECLARE @sporttype		TABLE (sporttype INT)
	DECLARE @LicenseeName	VARCHAR(50)

	SELECT	@LicenseeName = LicenseeName FROM bodb_Licensee.dbo.Licensees (NOLOCK) WHERE LicenseeID = @LicenseeID	

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
		INSERT INTO @sporttype(sporttype)
		VALUES (0)		
	END  

	IF @ShowRB = 1  
	BEGIN  
		INSERT INTO @sporttype(Sporttype)
		VALUES (151)
    
		INSERT INTO @bettype(bettype)
		SELECT	typeid FROM bettype (NOLOCK)
		WHERE	typeid BETWEEN 31 AND 33
	END  

	IF @ShowNG = 1
	BEGIN
		INSERT INTO @sporttype(Sporttype)  
		VALUES (161)  
	
		INSERT INTO @bettype(bettype)
		SELECT	typeid FROM bettype (NOLOCK)
		WHERE	typeid BETWEEN 81 AND 120
	END
 
	IF @ShowLC = 1
	BEGIN
		INSERT INTO @sporttype( Sporttype)
		VALUES (162)
    
		INSERT INTO @bettype(bettype)
		SELECT	typeid FROM bettype (NOLOCK)
		WHERE	typeid BETWEEN 1101 AND 1199
	END

	IF @ShowVS = 1
	BEGIN
		INSERT INTO @sporttype(Sporttype)
		SELECT 180

		INSERT INTO @bettype(bettype)
		SELECT	typeid FROM bettype (NOLOCK)
		WHERE	typeid BETWEEN 1201 AND 1299
	END

	IF @ShowCS = 1 -- RNG Casino
	BEGIN
		INSERT INTO @sporttype(sporttype)
		VALUES (251), (208), (209), (210)

		INSERT INTO @bettype(bettype)
		SELECT DISTINCT bettype
		FROM dbo.SportBettypeMatrix (NOLOCK)
		WHERE sporttype IN (208, 209, 210)
		UNION
		SELECT 71 AS bettype
	END

	IF @ShowBG = 1 -- Bingo
	BEGIN 
		INSERT INTO @sporttype(sporttype)
		VALUES (252)
		INSERT INTO @bettype(bettype)
		VALUES (73)
	END 

	IF @ShowKN = 1 -- Keno
	BEGIN 
		INSERT INTO @sporttype(sporttype)
		VALUES (202)
		INSERT INTO @bettype(bettype)
		SELECT	typeid FROM bettype (NOLOCK)
		WHERE	typeid BETWEEN 1501 AND 1599
	END

	IF @ShowMGCLC = 1 -- MicroGamming
	BEGIN 
		INSERT INTO @sporttype (sporttype)
		VALUES (203)

		INSERT INTO @bettype(bettype)
		SELECT	typeid FROM bettype (NOLOCK)
		WHERE	typeid BETWEEN 2001 AND 2007
	END

	IF @ShowMGCRnG = 1 -- MicroGamming
	BEGIN 
		INSERT INTO @sporttype (sporttype)
		VALUES (205)

		INSERT INTO @bettype(bettype)
		SELECT	typeid FROM bettype (NOLOCK)
		WHERE	typeid BETWEEN 2008 AND 2009
	END

	IF @ShowAGC = 1 -- AGCasino
	BEGIN
		INSERT INTO @sporttype (sporttype)
		VALUES (250)

		INSERT INTO @bettype(bettype)
		SELECT	typeid FROM bettype (NOLOCK)
		WHERE	typeid BETWEEN 1800 AND 1899
	END

	IF @ShowVB = 1
	BEGIN
		INSERT INTO @sporttype (sporttype)
		VALUES (212)

		INSERT INTO @bettype(bettype)
		SELECT	typeid FROM bettype (NOLOCK)
		WHERE	typeid BETWEEN 4001 AND 7999
	END
	
	IF @ShowAB = 1
	BEGIN
		INSERT INTO @sporttype (sporttype)
		VALUES (211)

		INSERT INTO @bettype(bettype)
		SELECT	typeid FROM bettype (NOLOCK)
		WHERE	typeid BETWEEN 2401 AND 2499
	END
	IF @ShowFW = 1
	BEGIN 
		INSERT INTO @sporttype (sporttype)
		VALUES (219)

		INSERT INTO @bettype(bettype)
		SELECT	typeid FROM bettype (NOLOCK)
		WHERE	typeid BETWEEN 1011 AND 1020
	END

	DECLARE @TempFromDate	DATETIME,
			@TempToDate		DATETIME,
			@MaxOldDate		DATETIME,
			@FDate			DATETIME,
			@TDate			DATETIME

	--to Deal With Parameter Sniffing
	SELECT @FDate = @FromDate, @TDate = @ToDate 
	
	DECLARE @Exchange TABLE (eEUR FLOAT, eUSD FLOAT, eGBP FLOAT, CodeKeenOcean VARCHAR(30), Code VARCHAR(30), CurrencyID INT)

	INSERT INTO @Exchange ( eEUR, eUSD, eGBP, CodeKeenOcean, CurrencyID)	
	SELECT DISTINCT eur, usd, GBP, Code, ExchangeId		
	FROM Lrf_f_GetExchangeDaily(@FDate, @TDate)
		INNER JOIN (SELECT DISTINCT Currency FROM @tempAg) c ON ExchangeId = c.Currency
	
	UPDATE ex
	SET Code = CASE WHEN CurrencyID IN (51, 20, 70) THEN e.currency
					WHEN CurrencyID = 66 THEN ex.CodeKeenOcean
					ELSE e.Code END
	FROM @Exchange ex
		INNER JOIN dbo.Exchange e ON ex.CurrencyID = e.exchangeid	

	IF @TDate > @MoveBetsDay
	BEGIN
		IF @FDate <= @MoveBetsDay 
			SET @TempFromDate =  DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @FDate

		IF @ShowBA = 1
		BEGIN
			INSERT INTO #SAgWinLoss  
			SELECT   
				b.custid,
				tma.Currency, 
				0 AS turnoverSB,
				SUM(stake
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN (b.statusID = 112 OR b.statusID = 113) AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN 0.5
							ELSE 1 END
						ELSE 1 END
				) AS turnoverBA, 
				0 AS turnoverNG,
				0 AS turnoverRB,
				0 AS turnoverLC,
				0 AS turnoverVS,
				0 AS turnoverCS,
				0 AS turnoverBG,
				0 AS turnoverKN,
				0 AS turnoverMGCLC,
				0 AS turnoverMGCRnG,
				0 AS turnoverAGC,
				0 AS turnoverVB,
				0 AS turnoverAB,
				0 AS turnoverFW,
				0 AS BTActualStake,
				SUM(b.winlost-b.actual_stake) AS Winlost,  
				0 AS LicenseeWLSB,
				0 AS LicenseeWLBA,
				0 AS LicenseeWLNG,
				0 AS LicenseeWLRB,
				0 AS LicenseeWLLC,
				0 AS LicenseeWLVS,
				0 AS LicenseeWLCS,
				0 AS LicenseeWLBG,
				0 AS LicenseeWLKN,
				0 AS LicenseeWLMGCLC,
				0 AS LicenseeWLMGCRnG,
				0 AS LicenseeWLAGC,
				0 AS LicenseeWLVB,
				0 AS LicenseeWLAB,
				0 AS LicenseeWLFW,
				-SUM(b.winlost-b.actual_stake+awinlost+comm ) AS AmountDueToBA,
				0 AS AmountDueToRB,
				SUM(comm) AS CommBA,
				0 AS CommRB,
				SUM(playercomm) AS PlayerComm,
				COUNT(b.transid)
					* CASE WHEN @drawfilter = 2 AND b.statusID = 111 THEN 0 ELSE 1 END BetCount,
					-- * CASE WHEN @drawfilter = 2 THEN CASE WHEN b.statusID = 111 THEN 0 ELSE 1 END ELSE 1 END BetCount,
				0 AS licenseeWLBT,
				0 AS BetTradeComm,
				SUM(CASE WHEN b.betdaqid = 0 THEN (b.winlost-b.actual_stake) ELSE 0 END) AS WLBetTicket,
				0 AS WLBoughtTicket,
				0 AS BuyBackAmtSB,
				0 AS BuyBackAmtBA
			FROM 
				dbo.bettrans b WITH ( NOLOCK) 
				INNER JOIN @TempAg tma ON tma.CustID = b.recommend AND tma.Currency = b.currency
				INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction_active BA WITH (NOLOCK) ON tma.custid = BA.recommend AND b.transid = BA.transid 	 	
			WHERE 
				b.winlostdate BETWEEN @TempFromDate AND @TDate 
				AND b.bettype NOT IN (901, 902, 903,904)
				AND b.statusID IN (111, 112, 113)				
			GROUP BY b.custid, b.statusID, tma.Currency
		END		

		IF @ShowSB = 1
		BEGIN
			INSERT INTO #SAgWinLoss
			SELECT   
				b.custid,
				a.Currency,
				SUM(stake
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN (b.statusID = 112 OR b.statusID = 113) AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN 0.5
							ELSE 1 END
						ELSE 1 END
				) AS turnoverSB, 
				0 AS turnoverBA,
				0 AS turnoverNG, 
				0 AS turnoverRB,
				0 AS turnoverLC, 
				0 AS turnoverVS, 
				0 AS turnoverCS, 
				0 AS turnoverNG, 
				0 AS turnoverKN, 
				0 AS turnoverMGCLC,
				0 AS turnoverMGCRnG,
				0 AS turnoverAGC,
				0 AS turnoverVB,
				0 AS turnoverAB,
				0 AS turnoverFW,
				0 AS BTActualStake,
				SUM(b.winlost-b.actual_stake) AS Winlost,  
				-SUM(b.winlost-b.actual_stake) AS LicenseeWLSB,
				0 AS LicenseeWLBA,
				0 AS LicenseeWLNG,
				0 AS LicenseeWLRB,
				0 AS LicenseeWLLC,
				0 AS LicenseeWLVS,
				0 AS LicenseeWLCS,
				0 AS LicenseeWLBG,
				0 AS LicenseeWLKN,
				0 AS LicenseeWLMGCLC,
				0 AS LicenseeWLMGCRnG,
				0 AS LicenseeWLAGC,
				0 AS LicenseeWLVB,
				0 AS LicenseeWLAB,
				0 AS LicenseeWLFW,
				0 AS AmountDueToBA,
				0 AS AmountDueToRB,
				0 AS CommBA,
				0 AS CommRB,
				SUM(b.playercomm) AS PlayerComm,
				COUNT(b.transid)
					* CASE WHEN @drawfilter = 2 AND b.statusID = 111 THEN 0 ELSE 1 END BetCount,
					-- * CASE WHEN @drawfilter = 2 THEN CASE WHEN b.statusID = 111 THEN 0 ELSE 1 END ELSE 1 END BetCount,
				0 AS licenseeWLBT,
				0 AS BetTradeComm,	
				SUM(CASE WHEN b.betdaqid = 0 THEN (b.winlost-b.actual_stake) ELSE 0 END) AS WLBetTicket,
				0 AS WLBoughtTicket,
				0 AS BuyBackAmtSB,
				0 AS BuyBackAmtBA
			FROM 	
				bettrans b WITH ( NOLOCK)
				INNER JOIN @TempAg a ON b.recommend = a.custid AND b.currency = a.currency 
			WHERE 
				b.winlostdate BETWEEN @TempFromDate AND @TDate
				AND  
				(
					b.bettype < 31
					OR b.bettype BETWEEN 121 AND 999
					OR b.Bettype BETWEEN 1301 and 1399 --new tennis's bettypes
				) 
				AND b.bettype NOT IN (901, 902, 903,904)
				AND	b.statusID IN (111, 112, 113) 
				AND	b.tpositiontaking <> 0
			GROUP BY b.custid, b.statusID, a.Currency
		END

		IF @ShowBT = 1
		BEGIN
			INSERT INTO #SAgWinLoss
			SELECT   
				b.custid,
				a.Currency, 			
				0 AS turnoverSB, 
				0 AS turnoverBA,
				0 AS turnoverNG, 
				0 AS turnoverRB,
				0 AS turnoverLC, 
				0 AS turnoverVS, 
				0 AS turnoverCS, 
				0 AS turnoverBG, 
				0 AS turnoverKN, 
				0 AS turnoverMGCLC,
				0 AS turnoverMGCRnG,
				0 AS turnoverAGC,
				0 AS turnoverVB,
				0 AS turnoverAB,
				0 AS turnoverFW,
				SUM(CASE WHEN b.bettype = 902 THEN b.winlost ELSE 0 END) AS BTAtualStake,
				SUM(CASE WHEN b.bettype = 903 THEN 0 ELSE b.winlost-b.actual_stake END) AS Winlost,  
				0 AS LicenseeWLSB,
				0 AS LicenseeWLBA,
				0 AS LicenseeWLNG,
				0 AS LicenseeWLRB,
				0 AS LicenseeWLLC,
				0 AS LicenseeWLVS,
				0 AS LicenseeWLCS,
				0 AS LicenseeWLBG,
				0 AS LicenseeWLKN,
				0 AS LicenseeWLMGCLC,
				0 AS LicenseeWLMGCRnG,
				0 AS LicenseeWLAGC,
				0 AS LicenseeWLVB,
				0 AS LicenseeWLAB,
				0 AS LicenseeWLFW, 
				0 AS AmountDueToBA,
				0 AS AmountDueToRB,
				0 AS CommBA,
				0 AS CommRB,
				0 AS PlayerComm,		
				COUNT(CASE WHEN b.bettype = 903 THEN NULL ELSE b.transid END)
					* CASE WHEN @drawfilter = 2 AND b.statusID = 111 THEN 0 ELSE 1 END BetCount,
					-- * CASE WHEN @drawfilter = 2 THEN CASE WHEN b.statusID = 111 THEN 0 ELSE 1 END ELSE 1 END BetCount,
				-SUM(CASE WHEN b.bettype IN (901, 902) THEN b.winlost-b.actual_stake ELSE 0 END) AS licenseeWLBT,
				SUM(CASE WHEN b.bettype = 903 THEN b.awinlost ELSE 0 END) AS BetTradeComm,
				0 WLBetTicket,
				SUM(CASE WHEN b.bettype = 902 THEN b.winlost-b.actual_stake ELSE 0 END) AS WLBoughtTicket,
				SUM(CASE WHEN b.bettype = 902 AND transid2 = 0 THEN b.actual_stake ELSE 0 END) AS BuyBackAmtSB,
				SUM(CASE WHEN b.bettype = 902 AND transid2 = 1 THEN b.actual_stake ELSE 0 END) AS BuyBackAmtBA
			FROM 	
				Bettrans b WITH (NOLOCK)
				INNER JOIN @TempAg a ON b.recommend = a.custid AND b.currency = a.currency 
			WHERE 
				b.winlostdate BETWEEN @TempFromDate AND @TDate  			
				AND b.bettype IN (901, 902, 903)
				AND	b.statusID IN (111, 112, 113)
			GROUP BY b.custid, b.statusID, a.Currency
		END

		IF 1 IN (@ShowNG, @ShowLC, @ShowVS, @ShowRB, @ShowCS, @ShowBG, @showKN, @ShowMGCLC, @ShowMGCRnG, @ShowAGC, @ShowVB,@ShowAB,@ShowFW)
		BEGIN
			INSERT INTO #SAgWinLoss
			SELECT   
				b.custid,
				a.Currency,
				0 AS turnoverSB, 
				0 AS turnoverBA,
				SUM(CASE WHEN b.bettype BETWEEN 81 AND 120 THEN
						stake * CASE WHEN @drawfilter IN (2,3) AND b.statusID = 111 THEN 0 ELSE 1 END

						 
					ELSE 0 END	
				) AS turnoverNG, 
				SUM(CASE WHEN b.bettype BETWEEN 31 AND 33 THEN CASE WHEN b.bettype = 33 AND liveawayscore = 0 THEN stake/2 ELSE stake END ELSE 0 END	
					* CASE WHEN @drawfilter IN (2,3) AND b.statusID = 111 THEN 0 ELSE 1 END

					 
				) AS turnoverRB, 
				SUM(CASE WHEN b.bettype BETWEEN 1101 AND 1199 THEN
					stake * CASE WHEN @drawfilter IN (2,3) AND b.statusID = 111 THEN 0 ELSE 1 END

					 
					ELSE 0 END	
				) AS turnoverLC, 
				SUM(CASE WHEN b.bettype BETWEEN 1201 AND 1299 THEN
					stake * CASE WHEN @drawfilter IN (2,3) AND b.statusID = 111 THEN 0 ELSE 1 END

						 
					ELSE 0 END	
				) AS turnoverVS, 
				SUM(CASE WHEN b.bettype = 71 OR b.bettype BETWEEN 2101 AND 2399 THEN
					stake * CASE WHEN @drawfilter IN (2,3) AND b.statusID = 111 THEN 0 ELSE 1 END

						 
					ELSE 0 END	
				) AS turnoverCS,
				SUM(CASE WHEN b.bettype = 73 THEN
					stake * CASE WHEN @drawfilter IN (2,3) AND b.statusID = 111 THEN 0 ELSE 1 END

						 
					ELSE 0 END	
				) AS turnoverBG,
				SUM(CASE WHEN b.bettype BETWEEN 1501 AND 1599 THEN
					stake * CASE WHEN @drawfilter IN (2,3) AND b.statusID = 111 THEN 0 ELSE 1 END

					 
					ELSE 0 END	
				) AS turnoverKN,
				SUM(CASE WHEN b.bettype BETWEEN 2001 AND 2007 THEN
					stake * CASE WHEN @drawfilter IN (2,3) AND b.statusID = 111 THEN 0 ELSE 1 END

						 
					ELSE 0 END	
				) AS turnoverMGCLC,
				SUM(CASE WHEN b.bettype BETWEEN 2008 AND 2009 THEN
					stake * CASE WHEN @drawfilter IN (2,3) AND b.statusID = 111 THEN 0 ELSE 1 END

						 
					ELSE 0 END	
				) AS turnoverMGCRnG,
				SUM(CASE WHEN b.bettype BETWEEN 1800 AND 1899 THEN
					stake * CASE WHEN @drawfilter IN (2,3) AND b.statusID = 111 THEN 0 ELSE 1 END

						 
					ELSE 0 END	
				) AS turnoverAGC,
				SUM(CASE WHEN b.bettype BETWEEN 4001 AND 7999 THEN
					stake * CASE WHEN @drawfilter IN (2,3) AND b.statusID = 111 THEN 0 ELSE 1 END

					 
					ELSE 0 END	
				) AS turnoverVB,
				SUM(CASE WHEN b.bettype BETWEEN 2401 AND 2499 THEN
					stake * CASE WHEN @drawfilter IN (2,3) AND b.statusID = 111 THEN 0 ELSE 1 END
					 
					ELSE 0 END	
				) AS turnoverAB,
				
				SUM(CASE WHEN b.bettype BETWEEN 1011 AND 1020  THEN
					stake * CASE WHEN @drawfilter IN (2,3) AND b.statusID = 111 THEN 0 ELSE 1 END
					 
					ELSE 0 END	
				) AS turnoverFW,
				
				0 AS BTActualStake,
				SUM(b.winlost-b.actual_stake) AS Winlost,  
				0 AS LicenseeWLSB,
				0 AS LicenseeWLBA,
				-SUM(CASE WHEN b.bettype BETWEEN 81 AND 120
					THEN b.winlost-b.actual_stake ELSE 0 END) AS LicenseeWLNG,
				SUM(CASE WHEN b.bettype BETWEEN 31 AND 33
					THEN b.awinlost ELSE 0 END) AS LicenseeWLRB,
				-SUM(CASE WHEN b.bettype BETWEEN 1101 AND 1199
					THEN b.winlost-b.actual_stake ELSE 0 END) AS LicenseeWLLC,
				-SUM(CASE WHEN b.bettype BETWEEN 1201 AND 1299
					THEN b.winlost-b.actual_stake ELSE 0 END) AS LicenseeWLVS,
				-SUM(CASE WHEN b.bettype = 71 OR b.bettype BETWEEN 2101 AND 2399
					THEN b.winlost-b.actual_stake ELSE 0 END) AS LicenseeWLCS,
				-SUM(CASE WHEN b.bettype = 73
					THEN b.winlost-b.actual_stake ELSE 0 END) AS LicenseeWLBG,
				-SUM(CASE WHEN b.bettype BETWEEN 1501 AND 1599
					THEN b.winlost-b.actual_stake ELSE 0 END) AS LicenseeWLKN,
				-SUM(CASE WHEN b.bettype BETWEEN 2001 AND 2007
					THEN b.winlost-b.actual_stake ELSE 0 END) AS LicenseeWLMGCLC,
				-SUM(CASE WHEN b.bettype BETWEEN 2008 AND 2009
					THEN b.winlost-b.actual_stake ELSE 0 END) AS LicenseeWLMGCRnG,
				-SUM(CASE WHEN b.bettype BETWEEN 1800 AND 1899
					THEN b.winlost-b.actual_stake ELSE 0 END) AS LicenseeWLAGC,
				-SUM(CASE WHEN b.bettype BETWEEN 4001 AND 7999
					THEN b.winlost-b.actual_stake ELSE 0 END) AS LicenseeWLVB,
				-SUM(CASE WHEN b.bettype BETWEEN 2401  AND 2499
					THEN b.winlost-b.actual_stake ELSE 0 END) AS LicenseeWLAB,
				-SUM(CASE WHEN b.bettype BETWEEN  1011 AND 1020
					THEN b.winlost-b.actual_stake ELSE 0 END) AS LicenseeWLFW,
					
				0 as AmountDueToBA,
				- SUM (CASE WHEN b.bettype BETWEEN 31 AND 33 THEN b.winlost - b.actual_stake + awinlost + comm ELSE 0 END) as AmountDueToRB,
				0 AS CommBA,
				SUM (CASE WHEN b.bettype BETWEEN 31 AND 33 THEN comm ELSE 0 END) AS CommRB,
				SUM(b.playercomm) AS PlayerComm,
				COUNT(b.transid)
					* CASE WHEN @drawfilter = 2 AND b.statusID = 111 THEN 0 ELSE 1 END AS BetCount,
					-- * CASE WHEN @drawfilter = 2 THEN CASE WHEN b.statusID = 111 THEN 0 ELSE 1 END ELSE 1 END BetCount,
				0 AS licenseeWLBT,
				0 AS BetTradeComm,	
				0 AS WLBetTicket,
				0 AS WLBoughtTicket,
				0 AS BuyBackAmtSB,
				0 AS BuyBackAmtBA
			FROM 	
				Bettrans b WITH ( NOLOCK)
				INNER JOIN @TempAg a   ON b.recommend = a.custid AND a.Currency = b.currency
				INNER JOIN @bettype bt ON b.bettype = bt.bettype
			WHERE 
				b.winlostdate BETWEEN @TempFromDate AND @TDate
				AND b.statusID  IN (111, 112, 113)
			GROUP BY b.custid, b.statusID, a.Currency
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
			INSERT INTO #SAgWinLoss  
			SELECT 
				b.custid,
				a.Currency,
				0 AS turnoverSB,
				SUM(b.turnover
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
						ELSE 1 END
				) AS turnoverBA,     
				0 AS turnoverNG,
				0 AS turnoverRB,
				0 AS turnoverLC,
				0 AS turnoverVS,
				0 AS turnoverCS,
				0 AS turnoverBG,
				0 AS turnoverKN,
				0 AS turnoverMGCLC,
				0 AS turnoverMGCRnG,
				0 AS turnoverAGC,
				0 AS turnoverVB,
				0 AS turnoverAB,
				0 AS turnoverFW,
				0 AS BTActualStake,
				SUM(b.winlost),  
				0 AS LicenseeWLSB,
				0 AS LicenseeWLBA,
				0 AS LicenseeWLNG,
				0 AS LicenseeWLRB,
				0 AS LicenseeWLLC,
				0 AS LicenseeWLVS,
				0 AS LicenseeWLCS,
				0 AS LicenseeWLBG,
				0 AS LicenseeWLKN,
				0 AS LicenseeWLMGCLC,
				0 AS LicenseeWLMGCRnG,
				0 AS LicenseeWLAGC,
				0 AS LicenseeWLVB,
				0 AS LicenseeWLAB,
				0 AS LicenseeWLFW,
				-SUM(b.winlost+b.awinlost+b.comm) AS AmountDueToBA,
				0 AS AmountDueToRB,
				SUM(comm) AS CommBA,
				0 AS CommRB,
				SUM(playercomm) AS PlayerComm,
				SUM(b.betcount)
					* CASE WHEN @drawfilter = 2 AND b.statusID = 111 THEN 0 ELSE 1 END AS BetCount,
					-- * CASE WHEN @drawfilter = 2 THEN CASE WHEN b.statusID = 111 THEN 0 ELSE 1 END ELSE 1 END,
				0 AS licenseeWLBT,
				0 AS BetTradeComm,	
				SUM(CASE WHEN bt.CustId IS NOT NULL THEN b.winlost ELSE 0 END) AS WLBetTicket,
				0 AS WLBoughtTicket,
				0 AS BuyBackAmtSB,
				0 AS BuyBackAmtBA
			FROM 
				bodb_licenseereport.dbo.rptLicWinloss2 b WITH ( NOLOCK )  
				INNER JOIN @TempAg a ON b.recommend = a.custID AND b.Currency = a.Currency 
				LEFT JOIN f_GetBetTradeCustList(@LicenseeName) bt ON b.custid = bt.Custid AND b.Currency = bt.currency
			WHERE  
				b.Winlostdate BETWEEN @FDate AND @TempToDate  
				AND b.bettype NOT IN (901, 902, 903,904)
				AND b.roleid = 1
				AND b.statusID <> 101 --exclude REJECT bets
				AND ISNULL(b.isBA, 0) = 1
			GROUP BY b.custid, b.statusID, a.Currency
		END
	
		--exclude BA tickets
		IF 1 IN (@showSB, @ShowRB, @ShowNG, @ShowLC, @ShowVS, @ShowCS, @ShowBG, @ShowKN, @ShowMGCLC, @ShowMGCRnG, @ShowAGC, @ShowVB,@ShowAB ,@ShowFW)
		BEGIN
			INSERT INTO #SAgWinLoss  
			SELECT 
				b.custid,
				a.Currency,
				SUM(CASE WHEN b.sporttype = 0 THEN 
					b.turnover
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
						ELSE 1 END
					ELSE 0 END
				) AS turnoverSB,
				0 AS turnoverBA,
				SUM(CASE WHEN b.sporttype = 161 THEN 
					b.turnover
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
						ELSE 1 END
					ELSE 0 END
				) AS turnoverNG,
				SUM(CASE WHEN b.sporttype = 151 THEN 
					b.turnover
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
						ELSE 1 END
					ELSE 0 END
				) AS turnoverRB,
				SUM(CASE WHEN b.sporttype = 162 THEN 
					b.turnover
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
						ELSE 1 END
					ELSE 0 END
				) AS turnoverLC,
				SUM(CASE WHEN b.sporttype IN (180, 181, 186) THEN 
					b.turnover
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
						ELSE 1 END
					ELSE 0 END
				) AS turnoverVS,
				SUM(CASE WHEN b.sporttype IN (251, 208, 209, 210) THEN 
					b.turnover
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
						ELSE 1 END
					ELSE 0 END
				) AS turnoverCS,
				SUM(CASE WHEN b.sporttype = 252 THEN 
					b.turnover
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
						ELSE 1 END
					ELSE 0 END
				) AS turnoverBG,
				SUM(CASE WHEN b.sporttype = 202 THEN 
					b.turnover
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
						ELSE 1 END
					ELSE 0 END
				) AS turnoverKN,
				SUM(CASE WHEN b.sporttype = 203 THEN 
					b.turnover
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
						ELSE 1 END
					ELSE 0 END
				) AS turnoverMGCLC,
				SUM(CASE WHEN b.sporttype = 205 THEN 
					b.turnover
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
						ELSE 1 END
					ELSE 0 END
				) AS turnoverMGCRnG,
				SUM(CASE WHEN b.sporttype = 250 THEN 
					b.turnover
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
						ELSE 1 END
					ELSE 0 END
				) AS turnoverAGC,
				SUM(CASE WHEN b.sporttype = 212 THEN 
					b.turnover
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
						ELSE 1 END
					ELSE 0 END
				) AS turnoverVB,
				SUM(CASE WHEN b.sporttype = 211 THEN 
					b.turnover
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
						ELSE 1 END
					ELSE 0 END
				) AS turnoverAB,
				SUM(CASE WHEN b.sporttype = 219 THEN 
					b.turnover
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
						ELSE 1 END
					ELSE 0 END
				) AS turnoverFW,
				
				0 AS BTActualStake,
				SUM(b.winlost),
				-SUM(CASE WHEN b.sporttype = 0 THEN b.winlost ELSE 0 END) AS LicenseeWLSB,
				0 AS LicenseeWLBA,
				-SUM(CASE WHEN b.sporttype = 161 THEN b.winlost ELSE 0 END) AS LicenseeWLNG,
				SUM(CASE WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END) AS LicenseeWLRB,
				-SUM(CASE WHEN b.sporttype = 162 THEN b.winlost ELSE 0 END) AS LicenseeWLLC,
				-SUM(CASE WHEN b.sporttype IN (180, 181, 186) THEN b.winlost ELSE 0 END) AS LicenseeWLVS,
				-SUM(CASE WHEN b.sporttype IN (251, 208, 209, 210) THEN b.winlost ELSE 0 END) AS LicenseeWLCS,
				-SUM(CASE WHEN b.sporttype = 252 THEN b.winlost ELSE 0 END) AS LicenseeWLBG,
				-SUM(CASE WHEN b.sporttype = 202 THEN b.winlost ELSE 0 END) AS LicenseeWLKN,
				-SUM(CASE WHEN b.sporttype = 203 THEN b.winlost ELSE 0 END) AS LicenseeWLMGCLC,
				-SUM(CASE WHEN b.sporttype = 205 THEN b.winlost ELSE 0 END) AS LicenseeWLMGCRnG,
				-SUM(CASE WHEN b.sporttype = 250 THEN b.winlost ELSE 0 END) AS LicenseeWLAGC,
				-SUM(CASE WHEN b.sporttype = 212 THEN b.winlost ELSE 0 END) AS LicenseeWLVB,
				-SUM(CASE WHEN b.sporttype = 211 THEN b.winlost ELSE 0 END) AS LicenseeWLAB,
				-SUM(CASE WHEN b.sporttype = 219 THEN b.winlost ELSE 0 END) AS LicenseeWLFW,
				0 AS AmountDueToBA,
				-SUM(CASE WHEN b.sporttype = 151 THEN b.winlost+b.awinlost+b.comm ELSE 0 END) AS AmountDueToRB,
				0 AS CommBA,
				SUM(CASE WHEN b.sporttype = 151 THEN comm ELSE 0 END) AS CommRB,
				SUM(playercomm) AS PlayerComm,
				SUM(b.betcount)
					* CASE WHEN @drawfilter = 2 AND b.statusID = 111 THEN 0 ELSE 1 END AS BetCount,
					-- * CASE WHEN @drawfilter = 2 THEN CASE WHEN b.statusID = 111 THEN 0 ELSE 1 END ELSE 1 END,
				0 AS licenseeWLBT,
				0 AS BetTradeComm,	
				SUM(CASE WHEN (bt.CustId IS NOT NULL) AND t.sporttype = 0 THEN b.winlost ELSE 0 END) AS WLBetTicket,
				0 AS WLBoughtTicket,
				0 AS BuyBackAmtSB,
				0 AS BuyBackAmtBA
			FROM
				bodb_licenseereport.dbo.rptLicWinloss2 b WITH ( NOLOCK )  
				INNER JOIN @TempAg a    ON b.recommend = a.custID AND b.Currency = a.Currency 
				INNER JOIN @sporttype t ON b.sporttype = t.sporttype
				LEFT JOIN  f_GetBetTradeCustList(@LicenseeName) bt ON b.custid = bt.Custid AND b.Currency = bt.currency
			WHERE  
				b.Winlostdate BETWEEN @FDate AND @TempToDate  
				AND b.bettype NOT IN (901,902,903,904)
				AND b.roleid = 1
				AND b.statusID <> 101 --exclude REJECT bets
				AND ISNULL(b.isBA, 0) = 0
			GROUP BY b.custid, b.statusID, a.Currency
		END
	
		IF @ShowBT = 1
		BEGIN
			INSERT INTO #SAgWinLoss
			SELECT   
				b.custid,
				ag.Currency,
				0 AS turnoverSB, 
				0 AS turnoverBA,
				0 AS turnoverNG, 
				0 AS turnoverRB,
				0 AS turnoverLC, 
				0 AS turnoverVS, 
				0 AS turnoverCS,
				0 AS tunroverBG,
				0 AS tunroverKN,
				0 AS turnoverMGCLC,
				0 AS turnoverMGCRnG,
				0 AS turnoverAGC,
				0 AS turnoverVB,
				0 AS turnoverAB,
				0 AS turnoverFW,
				SUM(CASE WHEN b.bettype = 902 THEN b.winlost + BuyBackAmt + BABuyBackAmt ELSE 0 END) AS BTActualStake,
				SUM(CASE WHEN b.bettype = 903 THEN 0 ELSE b.winlost END) AS Winlost,   
				0 AS LicenseeWLSB,
				0 AS LicenseeWLBA,
				0 AS LicenseeWLNG,
				0 AS LicenseeWLRB,
				0 AS LicenseeWLLC,
				0 AS LicenseeWLVS,
				0 AS LicenseeWLCS,
				0 AS LicenseeWLBG,
				0 AS LicenseeWLKN,
				0 AS LicenseeWLMGCLC,			
				0 AS LicenseeWLMGCRnG,
				0 AS LicenseeWLAGC,
				0 AS LicenseeWLVB,
				0 AS LicenseeWLAB,
				0 AS LicenseeWLFW,
				0 AS AmountDueToBA,
				0 AS AmountDueToRB,
				0 AS CommBA,
				0 AS CommRB,
				0 AS PlayerComm,
				SUM(CASE WHEN b.bettype = 903 THEN NULL ELSE b.BetCount END)
					* CASE WHEN @drawfilter = 2 AND b.statusID = 111 THEN 0 ELSE 1 END BetCount,
					-- * CASE WHEN @drawfilter = 2 THEN CASE WHEN b.statusID = 111 THEN 0 ELSE 1 END ELSE 1 END BetCount,
				-SUM(CASE WHEN b.bettype IN (901, 902) THEN b.winlost ELSE 0 END) AS licenseeWLBT,
				SUM(CASE WHEN b.bettype = 903 THEN b.awinlost ELSE 0 END) AS BetTradeComm,
				0 WLBetTicket,
				SUM(CASE WHEN b.bettype = 902 THEN b.winlost ELSE 0 END) AS WLBoughtTicket,
				SUM(CASE WHEN b.bettype = 902 THEN BuyBackAmt ELSE 0 END) AS BuyBackAmtSB,
				SUM(CASE WHEN b.bettype = 902 THEN BABuyBackAmt ELSE 0 END) AS BuyBackAmtBA
			FROM 
				bodb_licenseereport.dbo.rptLicWinloss2 b WITH ( NOLOCK )  
				INNER JOIN @TempAg ag ON b.recommend = ag.custID AND ag.currency = b.Currency
			WHERE 
				b.Winlostdate BETWEEN @FDate AND @TempToDate  
				AND b.bettype IN (901,902,903)	
				AND	b.statusID IN (111, 112, 113) 
				AND b.roleid = 1
				GROUP BY b.custid, b.statusID, ag.Currency
		END		
	END 
 
	IF @IsOld = 1 
	BEGIN
		SELECT @MaxOldDate = MAX(winlostdate) FROM bodb_licenseereport.dbo.rptLicWinloss_old (nolock)
		IF @TDate >= @MaxOldDate
			SET @TempToDate = @MaxOldDate
		ELSE
			SET @TempToDate = @TDate
 
		IF @ShowBA = 1
		BEGIN
			INSERT INTO #SAgWinLoss  
			SELECT
				b.custid,
				a.Currency,
				0 AS turnoverSB,
				SUM(b.turnover
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
					ELSE 1 END
				) AS turnoverBA,     
				0 AS turnoverNG,
				0 AS turnoverRB,
				0 AS turnoverLC,
				0 AS turnoverVS,
				0 AS turnoverCS,
				0 AS turnoverBG,
				0 AS turnoverKN,
				0 AS turnoverMGCLC,
				0 AS turnoverMGCRnG,
				0 AS turnoverAGC,
				0 AS turnoverVB,
				0 AS turnoverAB,
				0 AS turnoverFW,
				0 AS BTActualStake,
				SUM(b.winlost),  
				0 AS LicenseeWLSB,
				0 AS LicenseeWLBA,
				0 AS LicenseeWLNG,
				0 AS LicenseeWLRB,
				0 AS LicenseeWLLC,
				0 AS LicenseeWLVS,
				0 AS LicenseeWLCS,
				0 AS LicenseeWLBG,
				0 AS LicenseeWLKN,
				0 AS LicenseeWLMGCLC,
				0 AS LicenseeWLMGCRnG,
				0 AS LicenseeWLAGC,
				0 AS LicenseeWLVB,
				0 AS LicenseeWLAB,
				0 AS LicenseeWLFW,
				-SUM(b.winlost+b.awinlost+b.comm) AS AmountDueToBA,
				0 AS AmountDueToRB,
				SUM(comm) AS CommBA,
				0 AS CommRB,
				SUM(playercomm) AS PlayerComm,
				SUM(b.betcount)
					* CASE WHEN @drawfilter = 2 AND b.statusID = 111 THEN 0 ELSE 1 END,
					-- * CASE WHEN @drawfilter = 2 THEN CASE WHEN b.statusID = 111 THEN 0 ELSE 1 END ELSE 1 END,
				0 AS licenseeWLBT,
				0 AS BetTradeComm,	
				SUM(CASE WHEN bt.CustId IS NOT NULL THEN b.winlost ELSE 0 END) AS WLBetTicket,
				0 AS WLBoughtTicket,
				0 AS BuyBackAmtSB,
				0 AS BuyBackAmtBA
			FROM
				bodb_licenseereport.dbo.rptLicWinloss_old b WITH ( NOLOCK )  
				INNER JOIN @TempAg a ON b.recommend = a.custID AND b.Currency = a.Currency 
				LEFT JOIN f_GetBetTradeCustList(@LicenseeName) bt ON b.custid = bt.Custid AND b.Currency = bt.currency
			WHERE  
				b.Winlostdate BETWEEN @FDate AND @TempToDate  			
				AND b.bettype NOT IN (901,902,903,904)
				AND b.roleid = 1   
				AND b.statusID <> 101 --exclude REJECT bets
				AND ISNULL(b.isBA, 0) = 1
			GROUP BY b.custid, b.statusID, a.Currency
		END
	
		--exclude BA tickets
		IF 1 IN (@showSB, @ShowRB, @ShowNG, @ShowLC, @ShowVS, @ShowCS, @ShowBG, @showKN, @ShowMGCLC, @ShowMGCRnG, @ShowAGC, @ShowVB,@ShowAB,@ShowFW)
		BEGIN
			INSERT INTO #SAgWinLoss
			SELECT 
				b.custid,
				a.Currency,
				SUM(CASE WHEN b.sporttype = 0 THEN 
					b.turnover
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
						ELSE 1 END
					ELSE 0 END
				) AS turnoverSB,
				0 AS turnoverBA,
				SUM(CASE WHEN b.sporttype = 161 THEN 
					b.turnover
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
						ELSE 1 END
					ELSE 0 END
				) AS turnoverNG,
				SUM(CASE WHEN b.sporttype = 151 THEN 
					b.turnover
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
						ELSE 1 END
					ELSE 0 END
				) AS turnoverRB,
				SUM(CASE WHEN b.sporttype = 162 THEN 
					b.turnover
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
						ELSE 1 END
					ELSE 0 END
				) AS turnoverLC,
				SUM(CASE WHEN b.sporttype IN (180, 181, 186) THEN 
					b.turnover
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
						ELSE 1 END
					ELSE 0 END
				) AS turnoverVS,
				SUM(CASE WHEN b.sporttype IN (251, 208, 209, 210) THEN 
					b.turnover
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
						ELSE 1 END
					ELSE 0 END
				) AS turnoverCS,
				SUM(CASE WHEN b.sporttype = 252 THEN 
					b.turnover
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
						ELSE 1 END
					ELSE 0 END
				) AS turnoverBG,
				SUM(CASE WHEN b.sporttype = 202 THEN 
					b.turnover
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
						ELSE 1 END
					ELSE 0 END
				) AS turnoverKN,
				SUM(CASE WHEN b.sporttype = 203 THEN 
					b.turnover
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
						ELSE 1 END
					ELSE 0 END
				) AS turnoverMGCLC,
				SUM(CASE WHEN b.sporttype = 205 THEN 
					b.turnover
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
						ELSE 1 END
					ELSE 0 END
				) AS turnoverMGCRnG,
				SUM(CASE WHEN b.sporttype = 250 THEN 
					b.turnover
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
						ELSE 1 END
					ELSE 0 END
				) AS turnoverAGC,
				SUM(CASE WHEN b.sporttype = 212 THEN 
					b.turnover
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
						ELSE 1 END
					ELSE 0 END
				) AS turnoverVB,
				SUM(CASE WHEN b.sporttype = 211 THEN 
					b.turnover
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
						ELSE 1 END
					ELSE 0 END
				) AS turnoverAB,
				SUM(CASE WHEN b.sporttype = 219 THEN 
					b.turnover
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
						ELSE 1 END
					ELSE 0 END
				) AS turnoverFW,
				
				0 AS BTActualStake,
				SUM(b.winlost),  
				-SUM(CASE WHEN b.sporttype =0 THEN b.winlost ELSE 0 END) AS LicenseeWLSB,
				0 AS LicenseeWLBA,
				-SUM(CASE WHEN b.sporttype = 161 THEN b.winlost ELSE 0 END) AS LicenseeWLNG,
				SUM(CASE WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END) AS LicenseeWLRB,
				-SUM(CASE WHEN b.sporttype = 162 THEN b.winlost ELSE 0 END) AS LicenseeWLLC,
				-SUM(CASE WHEN b.sporttype IN (180,181,186) THEN b.winlost ELSE 0 END) AS LicenseeWLVS,
				-SUM(CASE WHEN b.sporttype IN (251, 208, 209, 210) THEN b.winlost ELSE 0 END) AS LicenseeWLCS,
				-SUM(CASE WHEN b.sporttype = 252 THEN b.winlost ELSE 0 END) AS LicenseeWLBG,
				-SUM(CASE WHEN b.sporttype = 202 THEN b.winlost ELSE 0 END) AS LicenseeWLKN,
				-SUM(CASE WHEN b.sporttype = 203 THEN b.winlost ELSE 0 END) AS LicenseeWLMGCLC,
				-SUM(CASE WHEN b.sporttype = 205 THEN b.winlost ELSE 0 END) AS LicenseeWLMGCRnG,
				-SUM(CASE WHEN b.sporttype = 250 THEN b.winlost ELSE 0 END) AS LicenseeWLAGC,
				-SUM(CASE WHEN b.sporttype = 212 THEN b.winlost ELSE 0 END) AS LicenseeWLVB,
				-SUM(CASE WHEN b.sporttype = 211 THEN b.winlost ELSE 0 END) AS LicenseeWLAB,
				-SUM(CASE WHEN b.sporttype = 219 THEN b.winlost ELSE 0 END) AS LicenseeWLFW,
				0 AS AmountDueToBA,
				-SUM(CASE WHEN b.sporttype = 151 THEN b.winlost+b.awinlost+b.comm ELSE 0 END) AS AmountDueToRB,
				0 AS CommBA,
				SUM(CASE WHEN b.sporttype = 151 THEN comm ELSE 0 END) AS CommRB,
				SUM(playercomm) AS PlayerComm,
				SUM(b.betcount)
					* CASE WHEN @drawfilter = 2 AND b.statusID = 111 THEN 0 ELSE 1 END AS BetCount,
					-- * CASE WHEN @drawfilter = 2 THEN CASE WHEN b.statusID = 111 THEN 0 ELSE 1 END ELSE 1 END,
				0 AS licenseeWLBT,
				0 AS BetTradeComm,	
				SUM(CASE WHEN (bt.CustId IS NOT NULL) AND t.sporttype = 0 THEN b.winlost ELSE 0 END) AS WLBetTicket,
				0 AS WLBoughtTicket,
				0 AS BuyBackAmtSB,
				0 AS BuyBackAmtBA
			FROM
				bodb_licenseereport.dbo.rptLicWinloss_old b WITH ( NOLOCK )  
				INNER JOIN @TempAg a    ON b.recommend = a.custID AND b.Currency = a.Currency 
				INNER JOIN @sporttype t ON b.sporttype = t.sporttype
				LEFT JOIN  f_GetBetTradeCustList(@LicenseeName) bt ON b.custid = bt.Custid AND b.Currency = bt.currency
			WHERE  
				b.Winlostdate BETWEEN @FDate AND @TempToDate  
				AND b.bettype NOT IN (901,902,903,904) 
				AND b.roleid = 1   
				AND b.statusID <> 101 --exclude REJECT bets
				AND ISNULL(b.isBA, 0) = 0
			GROUP BY b.custid, b.statusID, a.Currency	
		END

		IF @ShowBT = 1
		BEGIN
			INSERT INTO #SAgWinLoss
			SELECT   
				b.custid,
				ag.Currency,
				0 AS turnoverSB, 
				0 AS turnoverBA,
				0 AS turnoverNG, 
				0 AS turnoverRB,
				0 AS turnoverLC, 
				0 AS turnoverVS, 
				0 AS turnoverCS,
				0 AS tunroverBG,
				0 AS tunroverKN,
				0 AS turnoverMGCLC,
				0 AS turnoverMGCRnG,
				0 AS turnoverAGC,
				0 AS turnoverVB,
				0 AS turnoverAB,
				0 AS turnoverFW,
				0 AS BTActualStake,
				SUM(CASE WHEN b.bettype = 903 THEN 0 ELSE b.winlost END) AS Winlost,   
				0 AS LicenseeWLSB,
				0 AS LicenseeWLBA,
				0 AS LicenseeWLNG,
				0 AS LicenseeWLRB,
				0 AS LicenseeWLLC,
				0 AS LicenseeWLVS,
				0 AS LicenseeWLCS,
				0 AS LicenseeWLBG,
				0 AS LicenseeWLKN,
				0 AS LicenseeWLMGCLC,			
				0 AS LicenseeWLMGCRnG,
				0 AS LicenseeWLAGC,
				0 AS LicenseeWLVB,
				0 AS LicenseeWLAB,
				0 AS LicenseeWLFW,
				0 AS AmountDueToBA,
				0 AS AmountDueToRB,
				0 AS CommBA,
				0 AS CommRB,
				0 AS PlayerComm,
				SUM(CASE WHEN b.bettype = 903 THEN NULL	ELSE b.BetCount END)
					* CASE WHEN @drawfilter = 2 AND b.statusID = 111 THEN 0 ELSE 1 END AS BetCount,
					-- * CASE WHEN @drawfilter = 2 THEN CASE WHEN b.statusID = 111 THEN 0 ELSE 1 END ELSE 1 END BetCount,
				-SUM(CASE WHEN b.bettype IN (901, 902) THEN b.winlost ELSE 0 END) AS licenseeWLBT,
				SUM(CASE WHEN b.bettype = 903 THEN b.awinlost ELSE 0 END) AS BetTradeComm,
				0 WLBetTicket,
				SUM(CASE WHEN b.bettype = 902 THEN b.winlost ELSE 0 END) AS WLBoughtTicket,
				0 AS BuyBackAmtSB,
				0 AS BuyBackAmtBA
			FROM 
				bodb_licenseereport.dbo.rptLicWinloss_old b WITH ( NOLOCK )  
				INNER JOIN @TempAg ag ON b.recommend = ag.custID AND ag.currency = b.Currency
			WHERE 
				b.Winlostdate BETWEEN @FDate AND @TempToDate   
				AND b.bettype IN (901, 902, 903)
				AND	b.statusID IN (111, 112, 113) 
				AND b.roleid = 1
				GROUP BY b.custid, b.statusID, ag.Currency
		END
	 END


 
	 SELECT 
		c.username,  
		SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2)) AS nickname,
		w.custid, 
		w.currency,
		e.Code AS CurrencyName,
		SUM(TurnoverSB)			AS TurnoverSB,   
		SUM(TurnoverBA)			AS TurnoverBA,   
		SUM(TurnoverNG)			AS TurnoverNG,   
		SUM(TurnoverRB)			AS TurnoverRB,   
		SUM(TurnoverLC)			AS TurnoverLC,   
		SUM(TurnoverVS)			AS TurnoverVS,   
		SUM(TurnoverCS)			AS TurnoverCS,
		SUM(TurnoverBG)			AS TurnoverBG,
		SUM(TurnoverKN)			AS TurnoverKN,
		SUM(TurnoverMGCLC)      AS TurnoverMGCLC,
		SUM(TurnoverMGCRnG)     AS TurnoverMGCRnG,
		SUM(TurnoverAGC)		AS TurnoverAGC,
		SUM(TurnoverVB)			AS TurnoverVB,
		SUM(TurnoverAB)			AS TurnoverAB,
		SUM(TurnoverFW)			AS TurnoverFW,
		SUM(BTActualStake)		AS BTActualStake,
		SUM(Winlost)			AS Winlost,  
		SUM(LicenseeWLSB)		AS LicenseeWLSB,
		SUM(LicenseeWLBA)		AS LicenseeWLBA,
		SUM(LicenseeWLNG)		AS LicenseeWLNG,
		SUM(LicenseeWLRB)		AS LicenseeWLRB,	
		SUM(LicenseeWLLC)		AS LicenseeWLLC,
		SUM(LicenseeWLVS)		AS LicenseeWLVS,
		SUM(LicenseeWLCS)		AS LicenseeWLCS,
		SUM(LicenseeWLBG)		AS LicenseeWLBG,
		SUM(LicenseeWLKN)		AS LicenseeWLKN,
		SUM(LicenseeWLMGCLC)	AS LicenseeWLMGCLC,
		SUM(LicenseeWLMGCRnG)	AS LicenseeWLMGCRnG,
		SUM(LicenseeWLAGC)		AS LicenseeWLAGC,
		SUM(LicenseeWLVB)		AS LicenseeWLVB,
		SUM(LicenseeWLAB)		AS LicenseeWLAB,
		SUM(LicenseeWLFW)		AS LicenseeWLFW,
		SUM(CommBA)				AS CommBA,
		SUM(CommRB)				AS CommRB,
		SUM(PlayerComm)			AS PlayerComm,
		SUM(AmtDuetoBA)			AS AmtDuetoBA,
		SUM(AmtDuetoRB)			AS AmtDuetoRB,
		SUM(Betcount)			AS Betcount,	 
		SUM(licenseeWLBT)		AS licenseeWLBT,
		SUM(BetTradeComm)		AS BetTradeComm,
		SUM(WLBetTicket+WLBoughtTicket-BetTradeComm)	AS AmtDueToBT,
		SUM(BuyBackAmtSB)		AS BuyBackAmtSB,
		SUM(BuyBackAmtBA)		AS BuyBackAmtBA,
		CAST(SUM(TurnoverSB)*e.eEUR			AS MONEY)   AS TurnoverSBEUR,   
		CAST(SUM(TurnoverBA)*e.eEUR			AS MONEY)   AS TurnoverBAEUR,   
		CAST(SUM(TurnoverNG)*e.eEUR			AS MONEY)   AS TurnoverNGEUR,   
		CAST(SUM(TurnoverRB)*e.eEUR			AS MONEY)   AS TurnoverRBEUR,
		CAST(SUM(TurnoverLC)*e.eEUR			AS MONEY)   AS TurnoverLCEUR,
		CAST(SUM(TurnoverVS)*e.eEUR			AS MONEY)   AS TurnoverVSEUR,  
		CAST(SUM(TurnoverCS)*e.eEUR			AS MONEY)   AS TurnoverCSEUR,
		CAST(SUM(TurnoverBG)*e.eEUR			AS MONEY)   AS TurnoverBGEUR,
		CAST(SUM(TurnoverKN)*e.eEUR			AS MONEY)   AS TurnoverKNEUR,
		CAST(SUM(TurnoverMGCLC)*e.eEUR		AS MONEY)   AS TurnoverMGCLCEUR,
		CAST(SUM(TurnoverMGCRnG)*e.eEUR		AS MONEY)   AS TurnoverMGCRnGEUR,
		CAST(SUM(TurnoverAGC)*e.eEUR		AS MONEY)   AS TurnoverAGCEUR,
		CAST(SUM(TurnoverVB)*e.eEUR			AS MONEY)   AS TurnoverVBEUR,
		CAST(SUM(TurnoverAB)*e.eEUR			AS MONEY)   AS TurnoverABEUR,
		CAST(SUM(TurnoverFW)*e.eEUR			AS MONEY)   AS TurnoverFWEUR,
		CAST(SUM(BTActualStake)*e.eEUR		AS MONEY)   AS BTActualStakeEUR,
		CAST(SUM(Winlost)*e.eEUR			AS MONEY)   AS WinlostEUR,  
		CAST(SUM(LicenseeWLSB)*e.eEUR		AS MONEY)   AS LicenseeWLSBEUR,
		CAST(SUM(LicenseeWLBA)*e.eEUR		AS MONEY)   AS LicenseeWLBAEUR,
		CAST(SUM(LicenseeWLNG)*e.eEUR		AS MONEY)   AS LicenseeWLNGEUR,
		CAST(SUM(LicenseeWLRB)*e.eEUR		AS MONEY)   AS LicenseeWLRBEUR,
		CAST(SUM(LicenseeWLLC)*e.eEUR		AS MONEY)   AS LicenseeWLLCEUR,
		CAST(SUM(LicenseeWLVS)*e.eEUR		AS MONEY)   AS LicenseeWLVSEUR,
		CAST(SUM(LicenseeWLCS)*e.eEUR		AS MONEY)   AS LicenseeWLCSEUR,
		CAST(SUM(LicenseeWLBG)*e.eEUR		AS MONEY)   AS LicenseeWLBGEUR,
		CAST(SUM(LicenseeWLKN)*e.eEUR		AS MONEY)   AS LicenseeWLKNEUR,
		CAST(SUM(LicenseeWLMGCLC)*e.eEUR	AS MONEY)   AS LicenseeWLMGCLCEUR,
		CAST(SUM(LicenseeWLMGCRnG)*e.eEUR	AS MONEY)	AS LicenseeWLMGCRnGEUR,
		CAST(SUM(LicenseeWLAGC)*e.eEUR		AS MONEY)   AS LicenseeWLAGCEUR,
		CAST(SUM(LicenseeWLVB)*e.eEUR		AS MONEY)   AS LicenseeWLVBEUR,
		CAST(SUM(LicenseeWLAB)*e.eEUR		AS MONEY)   AS LicenseeWLABEUR,
		CAST(SUM(LicenseeWLFW)*e.eEUR		AS MONEY)   AS LicenseeWLFWEUR,
		CAST(SUM(CommBA)*e.eEUR				AS MONEY)   AS CommBAEUR,
		CAST(SUM(CommRB)*e.eEUR				AS MONEY)   AS CommRBEUR,
		CAST(SUM(PlayerComm)*e.eEUR			AS MONEY)   AS PlayerCommEUR,
		CAST(SUM(AmtDuetoBA)*e.eEUR			AS MONEY)   AS AmtDuetoBAEUR,
		CAST(SUM(AmtDuetoRB)*e.eEUR			AS MONEY)   AS AmtDuetoRBEUR,
		CAST(SUM(licenseeWLBT)*e.eEUR 		AS MONEY)	AS licenseeWLBTEUR,
		CAST(SUM(BetTradeComm)*e.eEUR		AS MONEY)	AS BetTradeCommEUR,
		CAST(SUM(WLBetTicket+WLBoughtTicket-BetTradeComm)*e.eEUR AS MONEY)	AS AmtDueToBTEUR,
		CAST(SUM(BuyBackAmtSB*e.eEUR)		AS MONEY)	AS BuyBackAmtSBEUR,
		CAST(SUM(BuyBackAmtBA*e.eEUR)		AS MONEY)	AS BuyBackAmtBAEUR,
		CAST(SUM(TurnoverSB)*e.eUSD			AS MONEY)   AS TurnoverSBUSD,   
		CAST(SUM(TurnoverBA)*e.eUSD			AS MONEY)   AS TurnoverBAUSD,   
		CAST(SUM(TurnoverNG)*e.eUSD			AS MONEY)   AS TurnoverNGUSD,   
		CAST(SUM(TurnoverRB)*e.eUSD			AS MONEY)   AS TurnoverRBUSD,
		CAST(SUM(TurnoverLC)*e.eUSD			AS MONEY)   AS TurnoverLCUSD,
		CAST(SUM(TurnoverVS)*e.eUSD			AS MONEY)   AS TurnoverVSUSD,  
		CAST(SUM(TurnoverCS)*e.eUSD			AS MONEY)   AS TurnoverCSUSD,
		CAST(SUM(TurnoverBG)*e.eUSD			AS MONEY)   AS TurnoverBGUSD,
		CAST(SUM(TurnoverKN)*e.eUSD			AS MONEY)   AS TurnoverKNUSD,
		CAST(SUM(TurnoverMGCLC)*e.eUSD		AS MONEY)   AS TurnoverMGCLCUSD,
		CAST(SUM(TurnoverMGCRnG)*e.eUSD		AS MONEY)   AS TurnoverMGCRnGUSD,
		CAST(SUM(TurnoverAGC)*e.eUSD		AS MONEY)   AS TurnoverAGCUSD,
		CAST(SUM(TurnoverVB)*e.eUSD			AS MONEY)   AS TurnoverVBUSD,
		CAST(SUM(TurnoverAB)*e.eUSD			AS MONEY)   AS TurnoverABUSD,
		CAST(SUM(TurnoverFW)*e.eUSD			AS MONEY)   AS TurnoverFWUSD,
		CAST(SUM(BTActualStake)*e.eUSD		AS MONEY)   AS BTActualStakeUSD,
		CAST(SUM(Winlost)*e.eUSD			AS MONEY)   AS WinlostUSD,  
		CAST(SUM(LicenseeWLSB)*e.eUSD		AS MONEY)   AS LicenseeWLSBUSD,
		CAST(SUM(LicenseeWLBA)*e.eUSD		AS MONEY)   AS LicenseeWLBAUSD,
		CAST(SUM(LicenseeWLNG)*e.eUSD		AS MONEY)   AS LicenseeWLNGUSD,
		CAST(SUM(LicenseeWLRB)*e.eUSD		AS MONEY)   AS LicenseeWLRBUSD,
		CAST(SUM(LicenseeWLLC)*e.eUSD		AS MONEY)   AS LicenseeWLLCUSD,
		CAST(SUM(LicenseeWLVS)*e.eUSD		AS MONEY)   AS LicenseeWLVSUSD,
		CAST(SUM(LicenseeWLCS)*e.eUSD		AS MONEY)   AS LicenseeWLCSUSD,
		CAST(SUM(LicenseeWLBG)*e.eUSD		AS MONEY)   AS LicenseeWLBGUSD,
		CAST(SUM(LicenseeWLKN)*e.eUSD		AS MONEY)   AS LicenseeWLKNUSD,
		CAST(SUM(LicenseeWLMGCLC)*e.eUSD	AS MONEY)   AS LicenseeWLMGCLCUSD,
		CAST(SUM(LicenseeWLMGCRnG)*e.eUSD	AS MONEY)	AS LicenseeWLMGCRnGUSD,
		CAST(SUM(LicenseeWLAGC)*e.eUSD		AS MONEY)   AS LicenseeWLAGCUSD,
		CAST(SUM(LicenseeWLVB)*e.eUSD		AS MONEY)   AS LicenseeWLVBUSD,
		CAST(SUM(LicenseeWLAB)*e.eUSD		AS MONEY)   AS LicenseeWLABUSD,
		CAST(SUM(LicenseeWLFW)*e.eUSD		AS MONEY)   AS LicenseeWLFWUSD,
		CAST(SUM(CommBA)*e.eUSD				AS MONEY)   AS CommBAUSD,
		CAST(SUM(CommRB)*e.eUSD				AS MONEY)   AS CommRBUSD,
		CAST(SUM(PlayerComm)*e.eUSD			AS MONEY)   AS PlayerCommUSD,
		CAST(SUM(AmtDuetoBA)*e.eUSD			AS MONEY)	AS AmtDuetoBAUSD,
		CAST(SUM(AmtDuetoRB)*e.eUSD			AS MONEY)	AS AmtDuetoRBUSD,
		CAST(SUM(licenseeWLBT)*e.eUSD 		AS MONEY)	AS licenseeWLBTUSD,
		CAST(SUM(BetTradeComm)*e.eUSD		AS MONEY)	AS BetTradeCommUSD,
		CAST(SUM(WLBetTicket+WLBoughtTicket-BetTradeComm)*e.eUSD AS MONEY)	AS AmtDueToBTUSD,
		CAST(SUM(BuyBackAmtSB * e.eUSD)		AS MONEY)	AS BuyBackAmtSBUSD,
		CAST(SUM(BuyBackAmtBA * e.eUSD)		AS MONEY)	AS BuyBackAmtBAUSD,
		CAST(SUM(TurnoverSB)*e.eGBP			AS MONEY)   AS TurnoverSBGBP,   
		CAST(SUM(TurnoverBA)*e.eGBP			AS MONEY)   AS TurnoverBAGBP,   
		CAST(SUM(TurnoverNG)*e.eGBP			AS MONEY)   AS TurnoverNGGBP,   
		CAST(SUM(TurnoverRB)*e.eGBP			AS MONEY)   AS TurnoverRBGBP,
		CAST(SUM(TurnoverLC)*e.eGBP			AS MONEY)   AS TurnoverLCGBP,
		CAST(SUM(TurnoverVS)*e.eGBP			AS MONEY)   AS TurnoverVSGBP,  
		CAST(SUM(TurnoverCS)*e.eGBP			AS MONEY)   AS TurnoverCSGBP,
		CAST(SUM(TurnoverBG)*e.eGBP			AS MONEY)   AS TurnoverBGGBP,
		CAST(SUM(TurnoverKN)*e.eGBP			AS MONEY)   AS TurnoverKNGBP,
		CAST(SUM(TurnoverMGCLC)*e.eGBP		AS MONEY)   AS TurnoverMGCLCGBP,
		CAST(SUM(TurnoverMGCRnG)*e.eGBP		AS MONEY)   AS TurnoverMGCRnGGBP,
		CAST(SUM(TurnoverAGC)*e.eGBP		AS MONEY)   AS TurnoverAGCGBP,
		CAST(SUM(TurnoverVB)*e.eGBP			AS MONEY)   AS TurnoverVBGBP,
		CAST(SUM(TurnoverAB)*e.eGBP			AS MONEY)   AS TurnoverABGBP,
		CAST(SUM(TurnoverFW)*e.eGBP			AS MONEY)   AS TurnoverFWGBP,
		CAST(SUM(BTActualStake)*e.eGBP		AS MONEY)   AS BTActualStakeGBP,
		CAST(SUM(Winlost)*e.eGBP			AS MONEY)   AS WinlostGBP,  
		CAST(SUM(LicenseeWLSB)*e.eGBP		AS MONEY)   AS LicenseeWLSBGBP,
		CAST(SUM(LicenseeWLBA)*e.eGBP		AS MONEY)   AS LicenseeWLBAGBP,
		CAST(SUM(LicenseeWLNG)*e.eGBP		AS MONEY)   AS LicenseeWLNGGBP,
		CAST(SUM(LicenseeWLRB)*e.eGBP		AS MONEY)   AS LicenseeWLRBGBP,
		CAST(SUM(LicenseeWLLC)*e.eGBP		AS MONEY)   AS LicenseeWLLCGBP,
		CAST(SUM(LicenseeWLVS)*e.eGBP		AS MONEY)   AS LicenseeWLVSGBP,
		CAST(SUM(LicenseeWLCS)*e.eGBP		AS MONEY)   AS LicenseeWLCSGBP,
		CAST(SUM(LicenseeWLBG)*e.eGBP		AS MONEY)   AS LicenseeWLBGGBP,
		CAST(SUM(LicenseeWLKN)*e.eGBP		AS MONEY)   AS LicenseeWLKNGBP,
		CAST(SUM(LicenseeWLMGCLC)*e.eGBP	AS MONEY)   AS LicenseeWLMGCLCGBP,
		CAST(SUM(LicenseeWLMGCRnG)*e.eGBP	AS MONEY)   AS LicenseeWLMGCRnGGBP,
		CAST(SUM(LicenseeWLAGC)*e.eGBP		AS MONEY)   AS LicenseeWLAGCGBP,
		CAST(SUM(LicenseeWLVB)*e.eGBP		AS MONEY)   AS LicenseeWLVBGBP,
		CAST(SUM(LicenseeWLAB)*e.eGBP		AS MONEY)   AS LicenseeWLABGBP,
		CAST(SUM(LicenseeWLFW)*e.eGBP		AS MONEY)   AS LicenseeWLFWGBP,
		CAST(SUM(CommBA)*e.eGBP				AS MONEY)   AS CommBAGBP,
		CAST(SUM(CommRB)*e.eGBP				AS MONEY)   AS CommRBGBP,
		CAST(SUM(PlayerComm)*e.eGBP			AS MONEY)   AS PlayerCommGBP,
		CAST(SUM(AmtDuetoBA)*e.eGBP			AS MONEY)   AS AmtDuetoBAGBP,
		CAST(SUM(AmtDuetoRB)*e.eGBP			AS MONEY)   AS AmtDuetoRBGBP,
		CAST(SUM(licenseeWLBT)*e.eGBP 		AS MONEY)	AS licenseeWLBTGBP,
		CAST(SUM(BetTradeComm)*e.eGBP		AS MONEY)	AS BetTradeCommGBP,
		CAST(SUM(WLBetTicket+WLBoughtTicket-BetTradeComm)*e.eGBP AS MONEY)	AS AmtDueToBTGBP,  
		CAST(SUM(BuyBackAmtSB*e.eGBP)		AS MONEY)	AS BuyBackAmtSBGBP,
		CAST(SUM(BuyBackAmtBA*e.eGBP)		AS MONEY)	AS BuyBackAmtBAGBP
	FROM
		#SAgWinLoss w   
		INNER JOIN bodb_licensee.dbo.licenseecustinfo c WITH (NOLOCK) ON w.custid = c.custid		
		INNER JOIN @Exchange e ON w.Currency = e.CurrencyID
	GROUP BY w.custid, c.username, c.username2, w.currency

	DROP TABLE #SAgWinLoss

END
GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_LicWinlossDetail] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_LicWinlossDetail] TO [vnteam]
GO
USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Lrf_Rpt_LicWinloss]  	
	@LicenseeID		INT,
	@FromDate		SMALLDATETIME,  
	@ToDate			SMALLDATETIME,   
	@showSB			BIT = 0,  
	@ShowRB			BIT = 0,  
	@ShowNG			BIT = 0, 
	@ShowBA			BIT = 0,
	@ShowLC			BIT = 0,
	@ShowVS			BIT = 0,
	@ShowCS   		BIT = 0, -- RNG Casino
	@ShowBG   		BIT = 0, -- Bingo 
	@ShowKN			BIT = 0, -- Keno
	@showMGCLC		BIT = 0, -- MicroGamming
	@showMGCRnG		BIT = 0, -- MicroGamming
	@ShowBT 		BIT = 0, -- licenseeWLBT
	@ShowAGC		BIT = 0, -- AGCasino
	@ShowVB			BIT = 0, -- Voidbridge
	@ShowAB			BIT = 0, -- Allbet
	@ShowFW			BIT = 0, -- Fishing World
	@ShowCO			BIT = 0, -- Cash Out
	@ReportType		TINYINT = 1,  
	@MoveBetsDay	SMALLDATETIME,
	@IsOld			BIT = 0,
	@drawfilter		SMALLINT = 1,
	@AgentList		VARCHAR(MAX)
AS 
/*  Created: Henry  
	Date: 2012-01-09
    Task : Winloss Report for Licensee 
    DB: DB052.bodb02  
   
    Revisions:  
    - 20120213@Henry: using exchange rate from function [Lrf_f_GetExchangeDaily]
    - 20120528@Henry: enhance performance
	- 20120723@Jim: add playercomm value 
	- 20120814@Henry: add ShowLiveCasino
	- 20120830@Jim : add virtual sport 
	- 20121004@Jim: replace @currency input param by @currencyID
	- 20121115@Henry: Only Sportsbook needs to exclude BA
	- 20121128@Henry: use new table LicenseeBATransaction_active to get bettrans BA tickets
	- 20130204@Jim: support RNG Casino and Bingo product
	- 20130514@Jim: Restrict permission of Licensee Users by currency
	- 20130809@Jim: offer Virtual Horse Racing
	- 20130916@Jim: offer Virtual Tennis
	- 20140620@Florent: offer 14 new bettypes and Sporting Solution (36 new bettypes)
	- 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
	- 20150123@Jim: support base on Currency GBP
	- 20150612@Jim: support MicroGaming
	- 20150624@Winnie: support licenseeWLBT
	- 20150624@Winnie: fix bug bettrade dont count refund tickets.
	- 20150903@Winnie: fix bug bettrade #42874
	- 20150910@Jim: Integrate Microgaming RNG games (feature #43078)
	- 20150921@Jim: Implement the changes on reports for AG Casino (#43172)
	- 20151108@Jim: Separated MicroGaming into 2 product
	- 20151230@Patrick: Add more output BuyBackAmt & BABuyBackAmt
	- 20151228@Bobby: Support MBC RNG Casino sporttype(208,209,210)
	- 20160215@Victor: Add Bettrade Actual Stake amount [Redmine: #51264]
	- 20160331@Percy: Support Voidbridge single wallet [Redmine: #55057]
	- 20160413@Victor: support MKK currency code [Redmine: #55745]
	- 20160718@Jim: Allbet - Live Casino Integration for Licensees [Redmine : #59624]
	- 20160727@Jim:  LRF - Commercial terms changed for Bet Trade [Redmine: #61342]
	- 20160804@Percy: Enhance Performance - using faster index on bettrans [RedmineID: #60770]
	- 20161022@Jim:move table to bodb_licenseereport [RedmineID :#60449]
	- 20161115@Jim: LRF - Integrate new product Fishing World [RedmineID : #66737]
	- 20170227@Harper: LRF - Get data by @AgentList instead of @UserID [RedmineID: #71679]

	Param's Explanation:  
	  + @ReportType: 1-Daily; 2-Monthly;  
	  +	@drawfilter: 'No Draw' filter is supportted (1:Normal 2:No Draw 3:No Draw for Turnover only)
	  + @IsOld: 0 - query in table rptLicWinloss, 1 - query in table rptLicWinloss_old. 
	  + @excludeTest: remove currency UUS
	  + @MoveBetsDay: The day we move tickets to bettrans14
	  + @AgentList: xml structure
					  <ROOT>
					   <Agent AgentId="12345" Currency="3"/>  
					   <Agent AgentId="12345" Currency="5"/>  
					  </ROOT>
*/  
BEGIN  

	SET NOCOUNT ON  

	CREATE TABLE #SAgWinLoss
	(  
		winlostdate			DATETIME,  
		Currency			INT,
		ProductCode			VARCHAR(10),
		Turnover			MONEY,
		BTActualStake		MONEY,
		Winlost				MONEY,
		LicenseeWL			MONEY,
		AmtDueToBA			MONEY,   
		AmtDueToRB			MONEY,
		CommBA				MONEY,   
		CommRB				MONEY,  
		PlayerComm			MONEY,
		Betcount			BIGINT,
		licenseeWLBT		MONEY,   
		BetTradeComm		MONEY,  
		WLBetTicket			MONEY, 	
		WLBoughtTicket		MONEY,
		BuyBackAmtSB		MONEY,
		BuyBackAmtBA		MONEY,
		CashOutComm			MONEY
	) 
 

	DECLARE @tempAg				TABLE(custID INT, currency INT)  
	DECLARE @VNDCurrencyName	VARCHAR(20)
	DECLARE @bettype			TABLE (bettype INT PRIMARY KEY)
	DECLARE @sporttype			TABLE (sporttype INT)
DECLARE @LicenseeName		VARCHAR(50)
DECLARE @WLBetTicket		TABLE (winlostdate DATETIME, currency INT, WLBetTicket MONEY)

	DECLARE @_FromDate SMALLDATETIME, @_ToDate SMALLDATETIME
	SELECT @_FromDate = @FromDate, @_ToDate = @ToDate

	SELECT @VNDCurrencyName = currency FROM exchange (NOLOCK) WHERE ExchangeId = 51

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

SELECT @LicenseeName = LicenseeName FROM bodb_Licensee.dbo.Licensees (NOLOCK) WHERE LicenseeID = @LicenseeID 

	IF @ShowSB = 1  
	BEGIN  
		INSERT INTO @sporttype(Sporttype)
		VALUES (0)	
	END  

	IF @ShowRB = 1  
	BEGIN  
		INSERT INTO @sporttype(Sporttype)
		VALUES (151)
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
		INSERT INTO @sporttype(Sporttype)
		VALUES (162)
    
		INSERT INTO @bettype(bettype)
		SELECT	typeid FROM bettype (NOLOCK)
		WHERE	typeid BETWEEN 1101 AND 1199
	END

	IF @ShowVS = 1
	BEGIN
		INSERT INTO @sporttype(Sporttype)
		VALUES (180)
	
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
		FROM dbo.SportBettypeMatrix WITH (NOLOCK)
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

	IF @showMGCLC = 1 -- MicroGamming
	BEGIN 
		INSERT INTO @sporttype(sporttype)
		VALUES (203)

		INSERT INTO @bettype(bettype)
		SELECT	typeid FROM bettype (NOLOCK)
		WHERE	typeid BETWEEN 2001 AND 2007
	END 

	IF @showMGCRnG = 1 -- MicroGamming
	BEGIN 
		INSERT INTO @sporttype(sporttype)
		VALUES(205)

		INSERT INTO @bettype(bettype)
		SELECT	typeid FROM bettype (NOLOCK)
		WHERE	typeid BETWEEN 2008 AND 2009
	END

	IF @ShowAGC = 1 -- AGCasino
	BEGIN
		INSERT INTO @sporttype (sporttype)
		VALUES(250)

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
		WHERE	typeid BETWEEN 2401  AND 2499
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
			@MaxOldDate		DATETIME

	IF @_ToDate > @MoveBetsDay
	BEGIN
		IF @_FromDate <= @MoveBetsDay 
			SET @TempFromDate = DATEADD(DAY,1,@MoveBetsDay)
		ELSE
			SET @TempFromDate = @_FromDate
	
		DECLARE @transid BIGINT
		SELECT TOP 1 @transid = transid FROM dbo.bettrans WITH(NOLOCK) WHERE matchid > 0 ORDER BY transid

		IF @ShowBA = 1 
		BEGIN
			;WITH CTE AS
			(
				SELECT DISTINCT transid
				FROM
					bodb_licensee.dbo.LicenseeBATransaction_active BA WITH(NOLOCK)
					INNER JOIN @tempAg r ON BA.recommend = r.custID
				UNION
				SELECT NULL
			)
			INSERT INTO #SAgWinLoss  
			SELECT   
				b.winlostdate,  
				tma.currency,
				'BA',
				SUM(CASE WHEN RAND() + 1 > 0 THEN stake ELSE 0 END
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN (b.statusID = 112 OR b.statusID = 113) AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN 0.5
							ELSE 1 END
					ELSE 1 END
				) AS turnover, 
				0 AS BTActualStake,
				SUM(CASE WHEN RAND() + 1 > 0 THEN b.winlost-b.actual_stake ELSE 0 END) AS Winlost,
				0 AS LicenseeWL,
				-SUM(CASE WHEN RAND() + 1 > 0 THEN b.winlost-b.actual_stake+awinlost+comm ELSE 0 END) AS AmountDueToBA,
				0 AS AmountDueToRB,
				SUM(CASE WHEN RAND() + 1 > 0 THEN comm ELSE 0 END) AS CommBA,
				0 AS CommRB,
				SUM(ISNULL(CASE WHEN RAND() + 1 > 0 THEN b.playercomm ELSE 0 END,0)) AS PlayerComm,
				COUNT(CASE WHEN RAND() + 1 > 0 AND @drawfilter = 2 AND b.statusID = 111 THEN NULL ELSE b.transid END)AS BetCount,
				0 AS licenseeWLBT,
				0 AS BetTradeComm,			
				SUM(CASE WHEN RAND() + 1 > 0 AND b.betdaqid = 0 THEN (b.winlost-b.actual_stake) ELSE 0 END) AS WLBetTicket,
				0 AS WLBoughtTicket,
				0 AS BuyBackAmtSB,
				0 AS BuyBackAmtBA,
				0 AS CashOutComm
			FROM
				CTE
				INNER JOIN dbo.bettrans b WITH (NOLOCK) ON CTE.transid = b.transid
				INNER JOIN @tempAg tma ON tma.custID = b.recommend AND b.currency = tma.currency
			WHERE 
				b.winlostdate BETWEEN @TempFromDate AND @_ToDate
				AND b.statusID  IN (111, 112, 113)
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
			GROUP BY b.winlostdate, tma.currency 
		END
	
		IF @ShowSB = 1
		BEGIN
			INSERT INTO #SAgWinLoss
			SELECT   
				b.winlostdate,  
				a.currency,
				'SB',
				SUM(CASE WHEN RAND() + 1 > 0 THEN stake ELSE 0 END
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN (b.statusID = 112 OR b.statusID = 113) AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN 0.5
							ELSE 1 END
					ELSE 1 END
				) AS turnover,
				0 AS BTActualStake,
				SUM(CASE WHEN RAND() + 1 > 0 THEN b.winlost-b.actual_stake ELSE 0 END) AS Winlost,
				-SUM(CASE WHEN RAND() + 1 > 0 THEN b.winlost-b.actual_stake ELSE 0 END) AS LicenseeWL,
				0 AS AmountDueToBA,
				0 AS AmountDueToRB,
				0 AS CommBA,
				0 AS CommRB,
				SUM(CASE WHEN RAND() + 1 > 0 THEN b.playerComm ELSE 0 END) AS PlayerComm,
				COUNT(CASE WHEN RAND() + 1 > 0 AND @drawfilter = 2 AND b.statusID = 111 THEN NULL ELSE b.transid END)AS BetCount,
				0 AS licenseeWLBT,
				0 AS BetTradeComm,	
				SUM(CASE WHEN RAND() + 1 > 0 AND b.betdaqid = 0 THEN b.winlost-b.actual_stake ELSE 0 END) AS WLBetTicket,
				0 AS WLBoughtTicket,
				0 AS BuyBackAmtSB,
				0 AS BuyBackAmtBA,
				0 AS CashOutComm
			FROM 
				Bettrans b WITH (NOLOCK)
				INNER JOIN @tempAg a ON b.recommend = a.custID AND b.currency = a.currency
			WHERE 
				b.winlostdate BETWEEN @TempFromDate AND @_ToDate
				AND  
				(
					b.bettype < 31
					OR b.bettype BETWEEN 121 AND 999
					OR b.Bettype BETWEEN 1301 and 1399 --new tennis's bettypes
				)
				AND b.statusID IN (111, 112, 113)
				AND b.tpositiontaking <> 0
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
				AND b.transid >= @transid
			GROUP BY b.winlostdate, a.currency --, statusID, b.bettype
		END

		IF @ShowBT = 1
		BEGIN
			INSERT INTO #SAgWinLoss
			SELECT   
				b.winlostdate,  
				a.currency,
				'BT',
				0 turnover,
				SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 902 THEN b.winlost ELSE 0 END) AS BTActualStake,
				SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 903 THEN 0 ELSE b.winlost-b.actual_stake END) AS Winlost,
				0 AS LicenseeWL,
				0 AS AmountDueToBA,
				0 AS AmountDueToRB,
				0 AS CommBA,
				0 AS CommRB,
				0 AS PlayerComm,
				COUNT(CASE WHEN RAND() + 1 > 0 AND ((b.bettype = 903) OR (@drawfilter = 2 AND b.statusID = 111)) THEN NULL ELSE b.transid END) AS BetCount,
				-SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype IN (901, 902) THEN b.winlost-b.actual_stake ELSE 0 END) AS licenseeWLBT,
				SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 903 THEN b.awinlost ELSE 0 END) AS BetTradeComm,
				0 WLBetTicket,
				SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 902 THEN b.winlost-b.actual_stake ELSE 0 END) AS WLBoughtTicket,
				SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 902 AND transid2 = 0 THEN b.actual_stake ELSE 0 END) AS BuyBackAmtSB,
				SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 902 AND transid2 = 1 THEN b.actual_stake ELSE 0 END) AS BuyBackAmtBA,
				0 AS CashOutComm
			FROM 
				Bettrans b WITH (NOLOCK)
				INNER JOIN @tempAg a ON b.recommend = a.custID AND b.currency = a.currency
			WHERE 
				b.winlostdate BETWEEN @TempFromDate AND @_ToDate
				AND b.bettype IN (901, 902, 903)
				AND b.statusID IN (111, 112, 113)
				AND b.transid >= @transid
			GROUP BY b.winlostdate, a.currency  
		END

		IF @ShowCO = 1
		BEGIN
			INSERT INTO #SAgWinLoss
			SELECT   
				b.winlostdate,  
				a.currency,
				'CO',
				0 AS turnover,
				0 AS BTActualStake,
				0 AS Winlost,
				0 AS LicenseeWL,
				0 AS AmountDueToBA,
				0 AS AmountDueToRB,
				0 AS CommBA,
				0 AS CommRB,
				0 AS PlayerComm,
				COUNT(b.transid) AS BetCount,
				0 AS licenseeWLBT,
				0 AS BetTradeComm,
				0 WLBetTicket,
				0 AS WLBoughtTicket,
				0 AS BuyBackAmtSB,
				0 AS BuyBackAmtBA,
				SUM(awinlost) AS CashOutComm
			FROM 
				Bettrans b WITH (NOLOCK)
				INNER JOIN @tempAg a ON b.recommend = a.custID AND b.currency = a.currency
			WHERE 
				b.winlostdate BETWEEN @TempFromDate AND @_ToDate
				AND b.bettype = 913
				AND b.statusID IN (111, 112, 113)
				AND b.transid >= @transid
			GROUP BY b.winlostdate, a.currency  
		END

		IF 1 IN (@ShowNG, @ShowLC, @ShowVS, @ShowCS, @ShowBG, @ShowKN, @showMGCLC, @showMGCRnG, @ShowAGC, @ShowVB,@ShowAB,@ShowFW)
		BEGIN
			INSERT INTO #SAgWinLoss
			SELECT   
				b.winlostdate,  
				a.currency,
				CASE
					WHEN RAND() + 1 > 0 AND b.bettype BETWEEN 81 AND 120 THEN 'NG'
					WHEN RAND() + 1 > 0 AND b.bettype BETWEEN 1101 AND 1199 THEN 'LC'
					WHEN RAND() + 1 > 0 AND b.bettype BETWEEN 1201 AND 1299 THEN 'VS'
					WHEN RAND() + 1 > 0 AND b.bettype = 71 OR b.bettype BETWEEN 2101 AND 2399 THEN 'CS'
					WHEN RAND() + 1 > 0 AND b.bettype = 73 THEN 'BG'
					WHEN RAND() + 1 > 0 AND b.bettype BETWEEN 1501 AND 1599 THEN 'KN'
					WHEN RAND() + 1 > 0 AND b.bettype BETWEEN 2001 AND 2007 THEN 'MGCLC'
					WHEN RAND() + 1 > 0 AND b.bettype BETWEEN 2008 AND 2009 THEN 'MGCRnG'
					WHEN RAND() + 1 > 0 AND b.bettype BETWEEN 1800 AND 1899 THEN 'AGC'
					WHEN RAND() + 1 > 0 AND b.bettype BETWEEN 4001 AND 7999 THEN 'VB'
					WHEN RAND() + 1 > 0 AND b.bettype BETWEEN 2401 AND 2499 THEN 'AB'
					WHEN RAND() + 1 > 0 AND b.bettype BETWEEN 1011 AND 1020 THEN 'FW'
					ELSE ''
				END,
				SUM(CASE WHEN RAND() + 1 > 0 AND @drawfilter IN (2,3) AND b.statusID = 111 THEN 0 ELSE stake END) AS turnover,
				0 AS BTActualStake,
				SUM(CASE WHEN RAND() + 1 > 0 THEN b.winlost-b.actual_stake ELSE 0 END) AS Winlost,
				-SUM(CASE WHEN RAND() + 1 > 0 THEN b.winlost - b.actual_stake ELSE 0 END) AS LicenseeWL,
				0 AS AmountDueToBA,
				0 AS AmountDueToRB,
				0 AS CommBA,
				0 AS CommRB,
				SUM(CASE WHEN RAND() + 1 > 0 THEN b.playerComm ELSE 0 END) AS PlayerComm,
				COUNT(CASE WHEN RAND() + 1 > 0 AND @drawfilter = 2 AND b.statusID = 111 THEN NULL ELSE b.transid END) AS BetCount,
				0 AS licenseeWLBT,
				0 AS BetTradeComm,	
				0 AS WLBetTicket,
				0 AS WLBoughtTicket,
				0 AS BuyBackAmtSB,
				0 AS BuyBackAmtBA,
				0 AS CashOutComm
			FROM 
				Bettrans b WITH (NOLOCK)
				INNER JOIN @tempAg a   ON b.recommend = a.custID AND b.Currency = a.Currency
				INNER JOIN @bettype bt ON b.bettype = bt.bettype
			WHERE 
				b.winlostdate BETWEEN @TempFromDate AND @_ToDate
				AND b.statusID IN (111, 112, 113)
				AND b.transid >= @transid
			GROUP BY   
				b.winlostdate, a.currency,  
				CASE
					WHEN RAND() + 1 > 0 AND b.bettype BETWEEN 81 AND 120 THEN 'NG'
					WHEN RAND() + 1 > 0 AND b.bettype BETWEEN 1101 AND 1199 THEN 'LC'
					WHEN RAND() + 1 > 0 AND b.bettype BETWEEN 1201 AND 1299 THEN 'VS'
					WHEN RAND() + 1 > 0 AND b.bettype = 71 OR b.bettype BETWEEN 2101 AND 2399 THEN 'CS'
					WHEN RAND() + 1 > 0 AND b.bettype = 73 THEN 'BG'
					WHEN RAND() + 1 > 0 AND b.bettype BETWEEN 1501 AND 1599 THEN 'KN'
					WHEN RAND() + 1 > 0 AND b.bettype BETWEEN 2001 AND 2007 THEN 'MGCLC'
					WHEN RAND() + 1 > 0 AND b.bettype BETWEEN 2008 AND 2009 THEN 'MGCRnG'
					WHEN RAND() + 1 > 0 AND b.bettype BETWEEN 1800 AND 1899 THEN 'AGC'
					WHEN RAND() + 1 > 0 AND b.bettype BETWEEN 4001 AND 7999 THEN 'VB'
					WHEN RAND() + 1 > 0 AND b.bettype BETWEEN 2401 AND 2499 THEN 'AB'
					WHEN RAND() + 1 > 0 AND b.bettype BETWEEN 1011 AND 1020 THEN 'FW'
					ELSE ''
				END
		END
	
		IF @ShowRB = 1
		BEGIN
			INSERT INTO #SAgWinLoss
			SELECT   
				b.winlostdate,  
				a.currency,
				'RB',
				SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype IN (33, 43) AND liveawayscore = 0 THEN stake/2 ELSE stake END 
					* CASE WHEN RAND() + 1 > 0 AND @drawfilter IN (2,3) AND b.statusID = 111 THEN 0 ELSE 1 END
				) AS turnover,
				0 AS BTActualStake,
				SUM(CASE WHEN RAND() + 1 > 0 THEN b.winlost-b.actual_stake ELSE 0 END) AS Winlost,
				SUM(CASE WHEN RAND() + 1 > 0 THEN b.awinlost ELSE 0 END) AS LicenseeWL,
				0 AS AmountDueToBA,
				-SUM((CASE WHEN RAND() + 1 > 0 THEN b.winlost-b.actual_stake+awinlost+comm ELSE 0 END)) AS AmountDueToRB,
				0 AS CommBA,
				SUM(CASE WHEN RAND() + 1 > 0 THEN b.comm ELSE 0 END) AS CommRB,
				SUM(ISNULL(CASE WHEN RAND() + 1 > 0 THEN b.PlayerComm ELSE 0 END,0)) AS PlayerComm,
				COUNT(CASE WHEN RAND() + 1 > 0 AND @drawfilter = 2 AND b.statusID = 111 THEN NULL ELSE b.transid END) AS BetCount,
				0 AS licenseeWLBT,
				0 AS BetTradeComm,	
				0 AS WLBetTicket,
				0 AS WLBoughtTicket,
				0 AS BuyBackAmtSB,
				0 AS BuyBackAmtBA,
				0 AS CashOutComm
			FROM 
				dbo.Bettrans b WITH (NOLOCK)
			INNER JOIN @tempAg a ON b.recommend = a.custID AND b.currency = a.currency
			WHERE 
				b.winlostdate BETWEEN @TempFromDate AND @_ToDate
				AND bettype BETWEEN 31 AND 33
				AND b.statusID IN (111, 112, 113)
				AND b.transid >= @transid
			GROUP BY b.winlostdate, a.currency
		END
	END  

	IF @_FromDate <= @MoveBetsDay 
	BEGIN
		IF @_ToDate >= @MoveBetsDay
				SET @TempToDate = @MoveBetsDay
			ELSE
				SET @TempToDate = @_ToDate
	
		DECLARE @CustBettrade TABLE (recommend INT, custid INT, currency INT)
		INSERT INTO @CustBettrade
	SELECT c.recommend, bt.custID, bt.currency 
	FROM f_GetBetTradeCustList(@LicenseeName) bt
		INNER JOIN dbo.Customer c WITH(NOLOCK) ON bt.custID = c.custid AND c.roleid = 1

		IF @ShowBA = 1 
		BEGIN
			INSERT INTO #SAgWinLoss  
			SELECT 
				b.winlostdate,  
				b.currency,
				'BA',
				SUM(CASE WHEN RAND() + 1 > 0 THEN b.turnover ELSE 0 END
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
					ELSE 1 END
				) AS turnover,
				0 AS BTActualStake,
				SUM(CASE WHEN RAND() + 1 > 0 THEN b.winlost ELSE 0 END),
				0 AS LicenseeWL,
				-SUM(CASE WHEN RAND() + 1 > 0 THEN b.winlost+b.awinlost+b.comm ELSE 0 END) AS AmountDueToBA,
				0 AS AmountDueToRB,
				SUM (CASE WHEN RAND() + 1 > 0 THEN b.comm ELSE 0 END) AS CommBA,
				0 AS CommRB,
				SUM(ISNULL(CASE WHEN RAND() + 1 > 0 THEN b.playercomm ELSE 0 END,0)) AS PlayerComm,
				SUM(CASE WHEN RAND() + 1 > 0 AND @drawfilter = 2 AND b.statusID = 111 THEN 0 ELSE b.betcount END) AS BetCount,
				0 AS licenseeWLBT,
				0 AS BetTradeComm,	
				0 AS WLBetTicket,
				0 AS WLBoughtTicket,
				0 AS BuyBackAmtSB,
				0 AS BuyBackAmtBA,
				0 AS CashOutComm
			FROM 
				  bodb_licenseereport.dbo.rptLicWinloss2 b WITH ( NOLOCK )  
				  INNER JOIN @TempAg ag ON b.recommend = ag.custID AND b.Currency = ag.currency
			WHERE  
				 b.Winlostdate BETWEEN @_FromDate AND @TempToDate  
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
				AND b.roleid = 1   
				AND b.statusID <> 101 --exclude REJECT bets
				AND b.isBA = 1 
			GROUP BY b.winlostdate, b.currency

			INSERT INTO @WLBetTicket
			SELECT 
				b.winlostdate,  
				b.currency,
				SUM(b.winlost)
			FROM 
				  bodb_licenseereport.dbo.rptLicWinloss2 b WITH ( NOLOCK )  
				  INNER JOIN @CustBettrade ag ON b.recommend = ag.recommend AND b.custid = ag.custid AND b.Currency = ag.currency
			WHERE  
				 b.Winlostdate BETWEEN @_FromDate AND @TempToDate  
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
				AND b.roleid = 1   
				AND b.statusID <> 101 --exclude REJECT bets
				AND b.isBA = 1
			GROUP BY b.winlostdate, b.currency
		END
	
		--exclude BA tickets
		IF 1 IN (@showSB, @ShowRB, @ShowNG, @ShowLC, @ShowVS, @ShowCS, @ShowBG, @ShowKN, @ShowMGCLC, @ShowMGCRnG, @ShowAGC, @ShowVB,@ShowAB,@ShowFW)
		BEGIN
			INSERT INTO #SAgWinLoss  
			SELECT 
				b.winlostdate,  
				b.currency,
				CASE
					WHEN RAND() + 1 > 0 AND b.sporttype = 0 THEN 'SB'
					WHEN RAND() + 1 > 0 AND b.sporttype = 161 THEN 'NG'
					WHEN RAND() + 1 > 0 AND b.sporttype = 151 THEN 'RB'
					WHEN RAND() + 1 > 0 AND b.sporttype = 162 THEN 'LC'
					WHEN RAND() + 1 > 0 AND b.sporttype = 180 THEN 'VS'
					WHEN RAND() + 1 > 0 AND b.sporttype IN (251, 208, 209, 210) THEN 'CS'
					WHEN RAND() + 1 > 0 AND b.sporttype = 252 THEN 'BG'
					WHEN RAND() + 1 > 0 AND b.sporttype = 202 THEN 'KN'
					WHEN RAND() + 1 > 0 AND b.sporttype = 203 THEN 'MGCLC'
					WHEN RAND() + 1 > 0 AND b.sporttype = 205 THEN 'MGCRnG'
					WHEN RAND() + 1 > 0 AND b.sporttype = 250 THEN 'AGC'
					WHEN RAND() + 1 > 0 AND b.sporttype = 212 THEN 'VB'
					WHEN RAND() + 1 > 0 AND b.sporttype = 211 THEN 'AB'
					WHEN RAND() + 1 > 0 AND b.sporttype = 219 THEN 'FW'
					ELSE ''
					END,
				SUM(CASE WHEN RAND() + 1 > 0 THEN b.turnover ELSE 0 END
					*
					CASE WHEN RAND() + 1 > 0 AND @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
						ELSE 1 END
				) AS turnover,
				0 AS BTActualStake,
				SUM(CASE WHEN RAND() + 1 > 0 THEN b.winlost ELSE 0 END),
				-SUM(CASE WHEN RAND() + 1 > 0 THEN b.winlost ELSE 0 END) AS LicenseeWL,
				0 AS AmountDueToBA,
				-SUM(CASE WHEN RAND() + 1 > 0 AND b.sporttype = 151 THEN b.winlost+b.awinlost+b.comm ELSE 0 END) AS AmountDueToRB,
				0 AS CommBA,
				SUM(CASE WHEN RAND() + 1 > 0 AND b.sporttype = 151 THEN comm ELSE 0 END) AS CommRB,
				SUM(ISNULL(CASE WHEN RAND() + 1 > 0 THEN playercomm ELSE 0 END, 0)) AS PlayerComm,
				SUM(CASE WHEN RAND() + 1 > 0 AND @drawfilter = 2 AND b.statusID = 111 THEN 0 ELSE b.betcount END) AS BetCount,
				0 AS licenseeWLBT,
				0 AS BetTradeComm,	
				0 AS WLBetTicket,
				0 AS WLBoughtTicket,
				0 AS BuyBackAmtSB,
				0 AS BuyBackAmtBA,
				0 AS CashOutComm
			FROM
				bodb_licenseereport.dbo.rptLicWinloss2 b WITH ( NOLOCK )  
				INNER JOIN @TempAg ag   ON b.recommend = ag.custID AND ag.currency = b.Currency
				INNER JOIN @sporttype t ON b.sporttype = t.sporttype
			WHERE  
				b.Winlostdate BETWEEN @_FromDate AND @TempToDate
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
				AND b.roleid = 1   
				AND b.statusID <> 101 --exclude REJECT bets
				AND b.isBA = 0 
			GROUP BY b.winlostdate, b.currency, 
				CASE
					WHEN RAND() + 1 > 0 AND b.sporttype = 0 THEN 'SB'
					WHEN RAND() + 1 > 0 AND b.sporttype = 161 THEN 'NG'
					WHEN RAND() + 1 > 0 AND b.sporttype = 151 THEN 'RB'
					WHEN RAND() + 1 > 0 AND b.sporttype = 162 THEN 'LC'
					WHEN RAND() + 1 > 0 AND b.sporttype = 180 THEN 'VS'
					WHEN RAND() + 1 > 0 AND b.sporttype IN (251, 208, 209, 210) THEN 'CS'
					WHEN RAND() + 1 > 0 AND b.sporttype = 252 THEN 'BG'
					WHEN RAND() + 1 > 0 AND b.sporttype = 202 THEN 'KN'
					WHEN RAND() + 1 > 0 AND b.sporttype = 203 THEN 'MGCLC'
					WHEN RAND() + 1 > 0 AND b.sporttype = 205 THEN 'MGCRnG'
					WHEN RAND() + 1 > 0 AND b.sporttype = 250 THEN 'AGC'
					WHEN RAND() + 1 > 0 AND b.sporttype = 212 THEN 'VB'
					WHEN RAND() + 1 > 0 AND b.sporttype = 211 THEN 'AB'
					WHEN RAND() + 1 > 0 AND b.sporttype = 219 THEN 'FW'
					ELSE ''
					END

			INSERT INTO @WLBetTicket
			SELECT 
				b.winlostdate,  
				b.currency,
				SUM(b.winlost)
			FROM 
				bodb_licenseereport.dbo.rptLicWinloss2 b WITH ( NOLOCK )  
				INNER JOIN @CustBettrade ag ON b.recommend = ag.recommend AND b.custid = ag.custid AND b.Currency = ag.currency
			WHERE  
				b.Winlostdate BETWEEN @_FromDate AND @TempToDate
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914) 
				AND b.roleid = 1   
				AND b.statusID <> 101 --exclude REJECT bets
				AND b.isBA = 0 
				AND b.sporttype = 0
			GROUP BY b.winlostdate, b.currency
		END

		IF @ShowBT = 1
		BEGIN
			INSERT INTO #SAgWinLoss
			SELECT   
				b.winlostdate,  
				ag.currency,
				'BT',
				0 AS turnover,
				SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 902 THEN b.winlost + BuyBackAmt + BABuyBackAmt ELSE 0 END) AS BTActualStake,
				SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 903 THEN 0 ELSE b.winlost END) AS Winlost,    
				0 AS LicenseeWL,
				0 as AmountDueToBA,
				0 as AmountDueToRB,
				0 as CommBA,
				0 as CommRB,
				0 as PlayerComm,
				SUM(CASE WHEN RAND() + 1 > 0 AND ((b.bettype = 903) OR (@drawfilter = 2 AND b.statusID = 111)) THEN 0 ELSE b.BetCount END) AS BetCount,
				-SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype IN (901, 902) THEN b.winlost ELSE 0 END) AS licenseeWLBT,
				SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 903 THEN b.awinlost ELSE 0 END) AS BetTradeComm,
				0 WLBetTicket,
				SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 902 THEN b.winlost ELSE 0 END) AS WLBoughtTicket,
				SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 902 THEN BuyBackAmt ELSE 0 END) AS BuyBackAmtSB,
				SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 902 THEN BABuyBackAmt ELSE 0 END) AS BuyBackAmtBA,
				0 AS CashOutComm
			FROM 
				bodb_licenseereport.dbo.rptLicWinloss2 b WITH ( NOLOCK )  
				INNER JOIN @TempAg ag ON b.recommend = ag.custID AND ag.currency = b.Currency
			WHERE 
				b.Winlostdate BETWEEN @_FromDate AND @TempToDate
				AND b.bettype IN (901, 902, 903)
				AND b.statusID  IN (111, 112, 113)
				AND b.roleid = 1 
			GROUP BY b.winlostdate, ag.currency, b.bettype
		END
	END

	IF @IsOld = 1 
	BEGIN
		SELECT @MaxOldDate = MAX(winlostdate) FROM bodb_licenseereport.dbo.rptLicWinloss_old (NOLOCK)
		IF @_ToDate >= @MaxOldDate
			SET @TempToDate = @MaxOldDate
		ELSE
			SET  @TempToDate = @_ToDate

		IF @ShowBA = 1 
		BEGIN
			INSERT INTO #SAgWinLoss  
			SELECT 
				b.winlostdate,  
				b.currency,
				'BA',
				SUM(CASE WHEN RAND() + 1 > 0 THEN b.turnover ELSE 0 END
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
					ELSE 1 END
				) AS turnover,
				0 AS BTActualStake,
				SUM(CASE WHEN RAND() + 1 > 0 THEN b.winlost ELSE 0 END),
				0 AS LicenseeWL,
				-SUM(CASE WHEN RAND() + 1 > 0 THEN b.winlost+b.awinlost+b.comm ELSE 0 END) AS AmountDueToBA,
				0 AS AmountDueToRB,
				SUM(CASE WHEN RAND() + 1 > 0 THEN b.comm ELSE 0 END) AS CommBA,
				0 AS CommRB,
				SUM(ISNULL(CASE WHEN RAND() + 1 > 0 THEN b.playercomm ELSE 0 END,0)) AS PlayerComm,
				SUM(CASE WHEN RAND() + 1 > 0 AND @drawfilter = 2 AND b.statusID = 111 THEN 0 ELSE b.betcount END) AS BetCount,
				0 AS licenseeWLBT,
				0 AS BetTradeComm,	
				0 AS WLBetTicket,
				0 AS WLBoughtTicket,
				0 AS BuyBackAmtSB,
				0 AS BuyBackAmtBA,
				0 AS CashOutComm
			FROM  
				bodb_licenseereport.dbo.rptLicWinloss_old b WITH ( NOLOCK )  
				INNER JOIN @TempAg ag ON b.recommend = ag.custID AND b.Currency = ag.currency
			WHERE  
				b.Winlostdate BETWEEN @_FromDate AND @TempToDate  
				AND b.bettype NOT IN (901, 902, 903,904) 
				AND b.roleid = 1   
				AND b.statusID <> 101 --exclude REJECT bets
				AND ISNULL(b.isBA, 0) = 1
			GROUP BY b.winlostdate, b.currency

			INSERT INTO @WLBetTicket
			SELECT 
				b.winlostdate,  
				b.currency,
				SUM(b.winlost)
			FROM  
				bodb_licenseereport.dbo.rptLicWinloss_old b WITH ( NOLOCK )  
				INNER JOIN @CustBettrade ag ON b.recommend = ag.recommend AND b.custid = ag.custid AND b.Currency = ag.currency
			WHERE  
				b.Winlostdate BETWEEN @_FromDate AND @TempToDate  
				AND b.bettype NOT IN (901, 902, 903,904) 
				AND b.roleid = 1   
				AND b.statusID <> 101 --exclude REJECT bets
				AND ISNULL(b.isBA, 0) = 1
			GROUP BY b.winlostdate, b.currency
		END

		--exclude BA tickets
		IF 1 IN (@showSB, @ShowRB, @ShowNG, @ShowLC, @ShowVS, @ShowCS, @ShowBG, @ShowKN, @ShowMGCLC, @ShowMGCRnG, @ShowAGC, @ShowVB,@ShowAB,@ShowFW)
		BEGIN
			INSERT INTO #SAgWinLoss  
			SELECT 
				b.winlostdate,  
				b.currency,
				CASE
					WHEN b.sporttype = 0 THEN 'SB'
					WHEN b.sporttype = 161 THEN 'NG'
					WHEN b.sporttype = 151 THEN 'RB'
					WHEN b.sporttype = 162 THEN 'LC'
					WHEN b.sporttype = 180 THEN 'VS'
					WHEN b.sporttype IN (251, 208, 209, 210) THEN 'CS'
					WHEN b.sporttype = 252 THEN 'BG'
					WHEN b.sporttype = 202 THEN 'KN'
					WHEN b.sporttype = 203 THEN 'MGCLC'
					WHEN b.sporttype = 205 THEN 'MGCRnG'
					WHEN b.sporttype = 250 THEN 'AGC'
					WHEN b.sporttype = 212 THEN 'VB'
					WHEN b.sporttype = 211 THEN 'AB'
					WHEN b.sporttype = 219 THEN 'FW'
					ELSE ''
					END,
				SUM(CASE WHEN RAND() + 1 > 0 THEN b.turnover ELSE 0 END
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
						ELSE 1 END
				) AS turnover,
				0 AS BTActualStake,
				SUM(CASE WHEN RAND() + 1 > 0 THEN b.winlost ELSE 0 END),  
				-SUM(CASE WHEN RAND() + 1 > 0 THEN b.winlost ELSE 0 END) AS LicenseeWL,
				0 AS AmountDueToBA,
				- SUM ( CASE WHEN RAND() + 1 > 0 AND b.sporttype = 151 THEN (b.winlost+b.awinlost+b.comm) ELSE 0 END) AS AmountDueToRB,
				0 AS CommBA,
				SUM ( CASE WHEN RAND() + 1 > 0 AND b.sporttype = 151 THEN (comm) ELSE 0 END) AS CommRB,
				SUM (ISNULL(CASE WHEN RAND() + 1 > 0 THEN playercomm ELSE 0 END,0)) AS PlayerComm,
				SUM(CASE WHEN RAND() + 1 > 0 AND @drawfilter = 2 AND b.statusID = 111 THEN 0 ELSE b.betcount END) AS BetCount,
				0 AS licenseeWLBT,
				0 AS BetTradeComm,	
				0 AS WLBetTicket,
				0 AS WLBoughtTicket,
				0 AS BuyBackAmtSB,
				0 AS BuyBackAmtBA,
				0 AS CashOutComm
			FROM 
				bodb_licenseereport.dbo.rptLicWinloss_old b WITH (NOLOCK)  
				INNER JOIN @TempAg ag   ON b.recommend = ag.custID AND b.Currency = ag.currency
				INNER JOIN @sporttype t ON b.sporttype = t.sporttype
			WHERE  
				b.Winlostdate BETWEEN @_FromDate AND @TempToDate  
				AND b.bettype NOT IN (901, 902, 903,904) 
				AND b.roleid = 1   
				AND b.statusID <> 101 --exclude REJECT bets
				AND ISNULL(b.isBA, 0) = 0
			GROUP BY b.winlostdate, b.currency, 
				CASE
					WHEN b.sporttype = 0 THEN 'SB'
					WHEN b.sporttype = 161 THEN 'NG'
					WHEN b.sporttype = 151 THEN 'RB'
					WHEN b.sporttype = 162 THEN 'LC'
					WHEN b.sporttype = 180 THEN 'VS'
					WHEN b.sporttype IN (251, 208, 209, 210) THEN 'CS'
					WHEN b.sporttype = 252 THEN 'BG'
					WHEN b.sporttype = 202 THEN 'KN'
					WHEN b.sporttype = 203 THEN 'MGCLC'
					WHEN b.sporttype = 205 THEN 'MGCRnG'
					WHEN b.sporttype = 250 THEN 'AGC'
					WHEN b.sporttype = 212 THEN 'VB'
					WHEN b.sporttype = 211 THEN 'AB'
					WHEN b.sporttype = 219 THEN 'FW'
					ELSE ''
					END

			INSERT INTO @WLBetTicket
			SELECT 
				b.winlostdate,  
				b.currency,
				SUM(b.winlost)
			FROM  
				bodb_licenseereport.dbo.rptLicWinloss_old b WITH ( NOLOCK )  
				INNER JOIN @CustBettrade ag ON b.recommend = ag.recommend AND b.custid = ag.custid AND b.Currency = ag.currency
			WHERE  
				b.Winlostdate BETWEEN @_FromDate AND @TempToDate  
				AND b.bettype NOT IN (901, 902, 903,904) 
				AND b.roleid = 1   
				AND b.statusID <> 101 --exclude REJECT bets
				AND ISNULL(b.isBA, 0) = 0
				AND b.sporttype = 0
			GROUP BY b.winlostdate, b.currency
		END

		IF @ShowBT = 1
		BEGIN
			INSERT INTO #SAgWinLoss
			SELECT   
				b.winlostdate,  
				ag.currency,
				'BT',
				0 AS turnover,
				0 BTActualStake,
				SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 903 THEN 0 ELSE b.winlost END) AS Winlost,    
				0 AS LicenseeWL,
				0 AS AmountDueToBA,
				0 AS AmountDueToRB,
				0 AS CommBA,
				0 AS CommRB,
				0 AS PlayerComm,
				SUM(CASE WHEN RAND() + 1 > 0 AND ((b.bettype = 903) OR (@drawfilter = 2 AND b.statusID = 111)) THEN 0 ELSE b.BetCount END) AS BetCount,
				-SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype IN (901, 902) THEN (b.winlost) ELSE 0 END) AS licenseeWLBT,
				SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 903 THEN b.awinlost ELSE 0 END) AS BetTradeComm,
				0 WLBetTicket,
				SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 902 THEN b.winlost ELSE 0 END) AS WLBoughtTicket,
				0 AS BuyBackAmtSB,
				0 AS BuyBackAmtBA,
				0 AS CashOutComm
			FROM 
				bodb_licenseereport.dbo.rptLicWinloss_old b WITH (NOLOCK)  
				INNER JOIN @TempAg ag ON b.recommend = ag.custID AND ag.currency = b.Currency
			WHERE 
				b.Winlostdate BETWEEN @_FromDate AND @TempToDate
				AND b.bettype IN (901, 902, 903)
				AND b.statusID IN (111, 112, 113)
				AND b.roleid = 1 
			GROUP BY b.winlostdate, ag.currency
		END
	END

	DECLARE @SAgWL TABLE
	(  
		winlostdate			DATETIME,  
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
		turnoverMGCLC		MONEY, 
		turnoverMGCRnG		MONEY, 
		turnoverAGC			MONEY,
		turnoverVB			MONEY, 
		turnoverAB			MONEY,
		turnoverFW			MONEY, 
		BTActualStake		MONEY,
		Winlost				MONEY,
		LicenseeWLSB 		MONEY,
		LicenseeWLBA		MONEY,
		LicenseeWLNG		MONEY,
		LicenseeWLRB		MONEY,
		LicenseeWLLC		MONEY,
		LicenseeWLVS		MONEY,
		LicenseeWLCS		MONEY,
		LicenseeWLBG		MONEY,
		LicenseeWLKN		MONEY,
		LicenseeWLMGCLC	    MONEY,
		LicenseeWLMGCRnG	MONEY,
		LicenseeWLAGC		MONEY,
		LicenseeWLVB		MONEY,
		LicenseeWLAB		MONEY,
		LicenseeWLFW		MONEY,
		AmtDueToBA			MONEY,   
		AmtDueToRB			MONEY,
		CommBA				MONEY,   
		CommRB				MONEY,  
		PlayerComm			MONEY,
		Betcount			BIGINT,
		licenseeWLBT		MONEY,   
		BetTradeComm		MONEY,  
		WLBetTicket			MONEY, 	
		WLBoughtTicket		MONEY,
		BuyBackAmtSB		MONEY,
		BuyBackAmtBA		MONEY,
		CashOutComm			MONEY,
		UNIQUE CLUSTERED (winlostdate, currency)
	)  

	INSERT INTO @SAgWL
	SELECT
		winlostdate,
		Currency,
		SUM(CASE ProductCode WHEN 'SB'		THEN Turnover ELSE 0 END)	AS TurnoverSB,   
		SUM(CASE ProductCode WHEN 'BA'		THEN Turnover ELSE 0 END)	AS TurnoverBA,   
		SUM(CASE ProductCode WHEN 'NG'		THEN Turnover ELSE 0 END)	AS TurnoverNG,   
		SUM(CASE ProductCode WHEN 'RB'		THEN Turnover ELSE 0 END)	AS TurnoverRB,   
		SUM(CASE ProductCode WHEN 'LC'		THEN Turnover ELSE 0 END)	AS TurnoverLC,   
		SUM(CASE ProductCode WHEN 'VS'		THEN Turnover ELSE 0 END)	AS TurnoverVS,   
		SUM(CASE ProductCode WHEN 'CS'		THEN Turnover ELSE 0 END)	AS TurnoverCS,
		SUM(CASE ProductCode WHEN 'BG'		THEN Turnover ELSE 0 END)	AS TurnoverBG,
		SUM(CASE ProductCode WHEN 'KN'		THEN Turnover ELSE 0 END)	AS TurnoverKN,
		SUM(CASE ProductCode WHEN 'MGCLC'	THEN Turnover ELSE 0 END)   AS TurnoverMGCLC,
		SUM(CASE ProductCode WHEN 'MGCRnG'	THEN Turnover ELSE 0 END)   AS TurnoverMGCRnG,
		SUM(CASE ProductCode WHEN 'AGC'		THEN Turnover ELSE 0 END)	AS TurnoverAGC,
		SUM(CASE ProductCode WHEN 'VB'		THEN Turnover ELSE 0 END)	AS TurnoverVB,
		SUM(CASE ProductCode WHEN 'AB'		THEN Turnover ELSE 0 END)	AS TurnoverAB,
		SUM(CASE ProductCode WHEN 'FW'		THEN Turnover ELSE 0 END)	AS TurnoverFW,
		SUM(BTActualStake)		AS BTActualStake,
		SUM(Winlost)			AS Winlost,
		SUM(CASE ProductCode WHEN 'SB'		THEN LicenseeWL ELSE 0 END)	AS LicenseeWLSB,   
		SUM(CASE ProductCode WHEN 'BA'		THEN LicenseeWL ELSE 0 END)	AS LicenseeWLBA,   
		SUM(CASE ProductCode WHEN 'NG'		THEN LicenseeWL ELSE 0 END)	AS LicenseeWLNG,   
		SUM(CASE ProductCode WHEN 'RB'		THEN LicenseeWL ELSE 0 END)	AS LicenseeWLRB,   
		SUM(CASE ProductCode WHEN 'LC'		THEN LicenseeWL ELSE 0 END)	AS LicenseeWLLC,   
		SUM(CASE ProductCode WHEN 'VS'		THEN LicenseeWL ELSE 0 END)	AS LicenseeWLVS,   
		SUM(CASE ProductCode WHEN 'CS'		THEN LicenseeWL ELSE 0 END)	AS LicenseeWLCS,
		SUM(CASE ProductCode WHEN 'BG'		THEN LicenseeWL ELSE 0 END)	AS LicenseeWLBG,
		SUM(CASE ProductCode WHEN 'KN'		THEN LicenseeWL ELSE 0 END)	AS LicenseeWLKN,
		SUM(CASE ProductCode WHEN 'MGCLC'	THEN LicenseeWL ELSE 0 END) AS LicenseeWLMGCLC,
		SUM(CASE ProductCode WHEN 'MGCRnG'	THEN LicenseeWL ELSE 0 END) AS LicenseeWLMGCRnG,
		SUM(CASE ProductCode WHEN 'AGC'		THEN LicenseeWL ELSE 0 END)	AS LicenseeWLAGC,
		SUM(CASE ProductCode WHEN 'VB'		THEN LicenseeWL ELSE 0 END)	AS LicenseeWLVB,
		SUM(CASE ProductCode WHEN 'AB'		THEN LicenseeWL ELSE 0 END)	AS LicenseeWLAB,
		SUM(CASE ProductCode WHEN 'FW'		THEN LicenseeWL ELSE 0 END)	AS LicenseeWLFW,
		SUM(AmtDuetoBA)			AS AmtDuetoBA,
		SUM(AmtDuetoRB)			AS AmtDuetoRB,
		SUM(CommBA)				AS CommBA,
		SUM(CommRB)				AS CommRB,
		SUM(playerComm)			AS PlayerComm,
		SUM(Betcount)			AS Betcount,
		SUM(licenseeWLBT)		AS licenseeWLBT,
		SUM(BetTradeComm)		AS BetTradeComm,
		SUM(WLBetTicket)		AS WLBetTicket,
		SUM(WLBoughtTicket)		AS WLBoughtTicket,
		SUM(BuyBackAmtSB)		AS BuyBackAmtSB,
		SUM(BuyBackAmtBA)		AS BuyBackAmtBA,
		SUM(CashOutComm)		AS CashOutComm
	FROM #SAgWinLoss
	GROUP BY winlostdate, Currency

	UPDATE s
	SET s.WLBetTicket = s.WLBetTicket + w.WLBetTicket
	FROM
		@SAgWL s
		INNER JOIN (SELECT SUM(WLBetTicket) WLBetTicket, winlostdate, currency FROM @WLBetTicket GROUP BY winlostdate, currency ) w
			ON s.winlostdate = w.winlostdate AND s.currency = w.currency-- AND s.statusID = w.statusID

	SELECT * INTO #TempExchange 
	FROM Lrf_f_GetExchangeDaily(@_FromDate,@_ToDate)

	SELECT   
		CASE WHEN @ReportType = 1 THEN CONVERT(VARCHAR(8),w.winlostdate,112)  
			WHEN @ReportType = 2 THEN CONVERT(VARCHAR(6),w.winlostdate,112)  
			ELSE '0' END ReportType,  
		Currency,   
		CASE	WHEN Currency = 51 THEN @VNDCurrencyName 
				WHEN Currency = 70 THEN 'MKK'
		  ELSE e.Code END AS currencyName,
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
		SUM(playerComm)			AS PlayerComm,
		SUM(AmtDuetoBA)			AS AmtDuetoBA,
		SUM(AmtDuetoRB)			AS AmtDuetoRB,
		SUM(Betcount)			AS Betcount,
		SUM(licenseeWLBT)		AS licenseeWLBT,
		SUM(BetTradeComm)		AS BetTradeComm,
		SUM(WLBetTicket+WLBoughtTicket-BetTradeComm)	AS AmtDueToBT,
		SUM(BuyBackAmtSB)		AS BuyBackAmtSB,
		SUM(BuyBackAmtBA)		AS BuyBackAmtBA,
		SUM(CashOutComm)		AS CashOutComm,
		CAST(SUM(TurnoverSB*e.USD)			AS MONEY)   AS TurnoverSBUSD,   
		CAST(SUM(TurnoverBA*e.USD)			AS MONEY)   AS TurnoverBAUSD,   
		CAST(SUM(TurnoverNG*e.USD)			AS MONEY)   AS TurnoverNGUSD,   
		CAST(SUM(TurnoverRB*e.USD)			AS MONEY)   AS TurnoverRBUSD,
		CAST(SUM(TurnoverLC*e.USD)			AS MONEY)	AS TurnoverLCUSD,
		CAST(SUM(TurnoverVS*e.USD)			AS MONEY)	AS TurnoverVSUSD,
		CAST(SUM(TurnoverCS*e.USD)			AS MONEY)   AS TurnoverCSUSD,
		CAST(SUM(TurnoverBG*e.USD)			AS MONEY)   AS TurnoverBGUSD,
		CAST(SUM(TurnoverKN*e.USD)			AS MONEY)   AS TurnoverKNUSD,
		CAST(SUM(TurnoverMGCLC*e.USD)		AS MONEY)   AS TurnoverMGCLCUSD,
		CAST(SUM(TurnoverMGCRnG*e.USD)		AS MONEY)   AS TurnoverMGCRnGUSD,
		CAST(SUM(TurnoverAGC*e.USD)			AS MONEY)   AS TurnoverAGCUSD,
		CAST(SUM(TurnoverVB*e.USD)			AS MONEY)   AS TurnoverVBUSD,
		CAST(SUM(TurnoverAB*e.USD)			AS MONEY)   AS TurnoverABUSD,
		CAST(SUM(TurnoverFW*e.USD)			AS MONEY)   AS TurnoverFWUSD,
		CAST(SUM(BTActualStake*e.USD)		AS MONEY)   AS BTActualStakeUSD,
		CAST(SUM(Winlost*e.USD)				AS MONEY)	AS WinlostUSD,
		CAST(SUM(LicenseeWLSB*e.USD)		AS MONEY)	AS LicenseeWLSBUSD,
		CAST(SUM(LicenseeWLBA*e.USD)		AS MONEY)	AS LicenseeWLBAUSD,
		CAST(SUM(LicenseeWLNG*e.USD)		AS MONEY) 	AS LicenseeWLNGUSD,
		CAST(SUM(LicenseeWLRB*e.USD)		AS MONEY)	AS LicenseeWLRBUSD,
		CAST(SUM(LicenseeWLLC*e.USD)		AS MONEY)	AS LicenseeWLLCUSD,
		CAST(SUM(LicenseeWLVS*e.USD)		AS MONEY)	AS LicenseeWLVSUSD,
		CAST(SUM(LicenseeWLCS*e.USD)		AS MONEY)	AS LicenseeWLCSUSD,
		CAST(SUM(LicenseeWLBG*e.USD)		AS MONEY)	AS LicenseeWLBGUSD,
		CAST(SUM(LicenseeWLKN*e.USD)		AS MONEY)	AS LicenseeWLKNUSD,
		CAST(SUM(LicenseeWLMGCLC*e.USD)		AS MONEY)	AS LicenseeWLMGCLCUSD,
		CAST(SUM(LicenseeWLMGCRnG*e.USD)	AS MONEY)	AS LicenseeWLMGCRnGUSD,
		CAST(SUM(LicenseeWLAGC*e.USD)		AS MONEY)	AS LicenseeWLAGCUSD,
		CAST(SUM(LicenseeWLVB*e.USD)		AS MONEY)	AS LicenseeWLVBUSD,
		CAST(SUM(LicenseeWLAB*e.USD)		AS MONEY)	AS LicenseeWLABUSD,
		CAST(SUM(LicenseeWLFW*e.USD)		AS MONEY)	AS LicenseeWLFWUSD,
		CAST(SUM(CommBA * e.USD)			AS MONEY)	AS CommBAUSD,
		CAST(SUM(CommRB * e.USD)			AS MONEY)	AS CommRBUSD,
		CAST(SUM(PlayerComm*e.USD)			AS MONEY)	AS PlayerCommUSD,
		CAST(SUM(AmtDuetoBA*e.USD)			AS MONEY)	AS AmtDuetoBAUSD,
		CAST(SUM(AmtDuetoRB*e.USD)			AS MONEY)	AS AmtDuetoRBUSD,
		CAST(SUM(licenseeWLBT* e.USD)		AS MONEY)   AS licenseeWLBTUSD,
		CAST(SUM(BetTradeComm* e.USD)		AS MONEY)	AS BetTradeCommUSD,
		CAST(SUM((WLBetTicket+WLBoughtTicket-BetTradeComm)* e.USD) AS MONEY)	AS AmtDueToBTUSD,
		CAST(SUM(BuyBackAmtSB * e.USD)		AS MONEY)	AS BuyBackAmtSBUSD,
		CAST(SUM(BuyBackAmtBA * e.USD)		AS MONEY)	AS BuyBackAmtBAUSD,
		CAST(SUM(CashOutComm * e.USD)		AS MONEY)	AS CashOutCommUSD,
		CAST(SUM(TurnoverSB*e.EUR)			AS MONEY)   AS TurnoverSBEUR,   
		CAST(SUM(TurnoverBA*e.EUR)			AS MONEY)   AS TurnoverBAEUR,   
		CAST(SUM(TurnoverNG*e.EUR)			AS MONEY)   AS TurnoverNGEUR,   
		CAST(SUM(TurnoverRB*e.EUR)			AS MONEY)   AS TurnoverRBEUR,
		CAST(SUM(TurnoverLC*e.EUR)			AS MONEY)   AS TurnoverLCEUR,
		CAST(SUM(TurnoverVS*e.EUR)			AS MONEY)   AS TurnoverVSEUR,  
		CAST(SUM(TurnoverCS*e.EUR)			AS MONEY)   AS TurnoverCSEUR,
		CAST(SUM(TurnoverBG*e.EUR)			AS MONEY)   AS TurnoverBGEUR,
		CAST(SUM(TurnoverKN*e.EUR)			AS MONEY)   AS TurnoverKNEUR,
		CAST(SUM(TurnoverMGCLC*e.EUR)		AS MONEY)   AS TurnoverMGCLCEUR,
		CAST(SUM(TurnoverMGCRnG*e.EUR)		AS MONEY)   AS TurnoverMGCRnGEUR,
		CAST(SUM(TurnoverAGC*e.EUR)			AS MONEY)   AS TurnoverAGCEUR,
		CAST(SUM(TurnoverVB*e.EUR)			AS MONEY)   AS TurnoverVBEUR,
		CAST(SUM(TurnoverAB*e.EUR)			AS MONEY)   AS TurnoverABEUR,
		CAST(SUM(TurnoverFW*e.EUR)			AS MONEY)   AS TurnoverFWEUR,
		CAST(SUM(BTActualStake*e.EUR)		AS MONEY)   AS BTActualStakeEUR,
		CAST(SUM(Winlost*e.EUR)				AS MONEY)	AS WinlostEUR,
		CAST(SUM(LicenseeWLSB*e.EUR)		AS MONEY)	AS LicenseeWLSBEUR,
		CAST(SUM(LicenseeWLBA*e.EUR)		AS MONEY)	AS LicenseeWLBAEUR,
		CAST(SUM(LicenseeWLNG*e.EUR)		AS MONEY)	AS LicenseeWLNGEUR,
		CAST(SUM(LicenseeWLRB*e.EUR)		AS MONEY) 	AS LicenseeWLRBEUR,
		CAST(SUM(LicenseeWLLC*e.EUR)		AS MONEY)	AS LicenseeWLLCEUR,
		CAST(SUM(LicenseeWLVS*e.EUR)		AS MONEY)	AS LicenseeWLVSEUR,
		CAST(SUM(LicenseeWLCS*e.EUR)		AS MONEY)	AS LicenseeWLCSEUR,
		CAST(SUM(LicenseeWLBG*e.EUR)		AS MONEY)	AS LicenseeWLBGEUR,
		CAST(SUM(LicenseeWLKN*e.EUR)		AS MONEY)	AS LicenseeWLKNEUR,
		CAST(SUM(LicenseeWLMGCLC*e.EUR)		AS MONEY)	AS LicenseeWLMGCLCEUR,
		CAST(SUM(LicenseeWLMGCRnG*e.EUR)	AS MONEY)	AS LicenseeWLMGCRnGEUR,
		CAST(SUM(LicenseeWLAGC*e.EUR)		AS MONEY)	AS LicenseeWLAGCEUR,
		CAST(SUM(LicenseeWLVB*e.EUR)		AS MONEY)	AS LicenseeWLVBEUR,
		CAST(SUM(LicenseeWLAB*e.EUR)		AS MONEY)	AS LicenseeWLABEUR,
		CAST(SUM(LicenseeWLFW*e.EUR)		AS MONEY)	AS LicenseeWLFWEUR,
		CAST(SUM(CommBA * e.EUR)			AS MONEY)	AS CommBAEUR,
		CAST(SUM(CommRB * e.EUR)			AS MONEY)	AS CommRBEUR,
		CAST(SUM(PlayerComm*e.EUR)			AS MONEY)	AS PlayerCommEUR,
		CAST(SUM(AmtDuetoBA*e.EUR)			AS MONEY)	AS AmtDuetoBAEUR,
		CAST(SUM(AmtDuetoRB*e.EUR)			AS MONEY)	AS AmtDuetoRBEUR,
		CAST(SUM(licenseeWLBT* e.EUR)		AS MONEY)   AS licenseeWLBTEUR,
		CAST(SUM(BetTradeComm* e.EUR)		AS MONEY)	AS BetTradeCommEUR,
		CAST(SUM((WLBetTicket+WLBoughtTicket-BetTradeComm)* e.EUR) AS MONEY)	AS AmtDueToBTEUR,
		CAST(SUM(BuyBackAmtSB * e.EUR)		AS MONEY)	AS BuyBackAmtSBEUR,
		CAST(SUM(BuyBackAmtBA * e.EUR)		AS MONEY)	AS BuyBackAmtBAEUR,
		CAST(SUM(CashOutComm * e.EUR)		AS MONEY)	AS CashOutCommEUR,
		CAST(SUM(TurnoverSB*e.GBP)			AS MONEY)   AS TurnoverSBGBP,   
		CAST(SUM(TurnoverBA*e.GBP)			AS MONEY)   AS TurnoverBAGBP,   
		CAST(SUM(TurnoverNG*e.GBP)			AS MONEY)   AS TurnoverNGGBP,   
		CAST(SUM(TurnoverRB*e.GBP)			AS MONEY)   AS TurnoverRBGBP,
		CAST(SUM(TurnoverLC*e.GBP)			AS MONEY)   AS TurnoverLCGBP,
		CAST(SUM(TurnoverVS*e.GBP)			AS MONEY)   AS TurnoverVSGBP,  
		CAST(SUM(TurnoverCS*e.GBP)			AS MONEY)   AS TurnoverCSGBP,
		CAST(SUM(TurnoverBG*e.GBP)			AS MONEY)   AS TurnoverBGGBP,
		CAST(SUM(TurnoverKN*e.GBP)			AS MONEY)   AS TurnoverKNGBP,
		CAST(SUM(TurnoverMGCLC*e.GBP)		AS MONEY)   AS TurnoverMGCLCGBP,
		CAST(SUM(TurnoverMGCRnG*e.GBP)		AS MONEY)   AS TurnoverMGCRnGGBP,
		CAST(SUM(TurnoverAGC*e.GBP)			AS MONEY)   AS TurnoverAGCGBP,
		CAST(SUM(TurnoverVB*e.GBP)			AS MONEY)   AS TurnoverVBGBP,
		CAST(SUM(TurnoverAB*e.GBP)			AS MONEY)   AS TurnoverABGBP,
		CAST(SUM(TurnoverFW*e.GBP)			AS MONEY)   AS TurnoverFWGBP,
		CAST(SUM(BTActualStake*e.GBP)		AS MONEY)   AS BTActualStakeGBP,
		CAST(SUM(Winlost*e.GBP)				AS MONEY)	AS WinlostGBP,
		CAST(SUM(LicenseeWLSB*e.GBP)		AS MONEY)	AS LicenseeWLSBGBP,
		CAST(SUM(LicenseeWLBA*e.GBP)		AS MONEY)	AS LicenseeWLBAGBP,
		CAST(SUM(LicenseeWLNG*e.GBP)		AS MONEY)	AS LicenseeWLNGGBP,
		CAST(SUM(LicenseeWLRB*e.GBP)		AS MONEY) 	AS LicenseeWLRBGBP,
		CAST(SUM(LicenseeWLLC*e.GBP)		AS MONEY)	AS LicenseeWLLCGBP,
		CAST(SUM(LicenseeWLVS*e.GBP)		AS MONEY)	AS LicenseeWLVSGBP,
		CAST(SUM(LicenseeWLCS*e.GBP)		AS MONEY)	AS LicenseeWLCSGBP,
		CAST(SUM(LicenseeWLBG*e.GBP)		AS MONEY)	AS LicenseeWLBGGBP,
		CAST(SUM(LicenseeWLKN*e.GBP)		AS MONEY)	AS LicenseeWLKNGBP,
		CAST(SUM(LicenseeWLMGCLC*e.GBP)		AS MONEY)	AS LicenseeWLMGCLCGBP,
		CAST(SUM(LicenseeWLMGCRnG*e.GBP)	AS MONEY)	AS LicenseeWLMGCRnGGBP,
		CAST(SUM(LicenseeWLAGC*e.GBP)		AS MONEY)	AS LicenseeWLAGCGBP,
		CAST(SUM(LicenseeWLVB*e.GBP)		AS MONEY)	AS LicenseeWLVBGBP,
		CAST(SUM(LicenseeWLAB*e.GBP)		AS MONEY)	AS LicenseeWLABGBP,
		CAST(SUM(LicenseeWLFW*e.GBP)		AS MONEY)	AS LicenseeWLFWGBP,
		CAST(SUM(CommBA*e.GBP)				AS MONEY)	AS CommBAGBP,
		CAST(SUM(CommRB*e.GBP)				AS MONEY)	AS CommRBGBP,
		CAST(SUM(PlayerComm*e.GBP)			AS MONEY)	AS PlayerCommGBP,
		CAST(SUM(AmtDuetoBA*e.GBP)			AS MONEY)	AS AmtDuetoBAGBP,
		CAST(SUM(AmtDuetoRB*e.GBP)			AS MONEY)	AS AmtDuetoRBGBP,
		CAST(SUM(licenseeWLBT*e.GBP)		AS MONEY)   AS licenseeWLBTGBP,
		CAST(SUM(BetTradeComm*e.GBP)		AS MONEY)	AS BetTradeCommGBP,
		CAST(SUM((WLBetTicket+WLBoughtTicket-BetTradeComm)* e.GBP) AS MONEY)	AS AmtDueToBTGBP,
		CAST(SUM(BuyBackAmtSB*e.GBP)		AS MONEY)	AS BuyBackAmtSBGBP,
		CAST(SUM(BuyBackAmtBA*e.GBP)		AS MONEY)	AS BuyBackAmtBAGBP,
		CAST(SUM(CashOutComm*e.GBP)		AS MONEY)	AS CashOutCommGBP
	FROM	
		@SAgWL w   
		INNER JOIN #TempExchange e ON w.winlostdate = e.ExchangeDate AND w.currency = e.ExchangeId
	GROUP BY   
		Currency,
		CASE	WHEN @ReportType = 1 THEN CONVERT(VARCHAR(8),w.winlostdate,112)  
				WHEN @ReportType = 2 THEN CONVERT(VARCHAR(6),w.winlostdate,112)  
				ELSE '0' END,  
		CASE	WHEN Currency = 51 THEN @VNDCurrencyName 
				WHEN Currency = 70 THEN 'MKK'
		  ELSE e.Code END
	ORDER BY ReportType

	DROP TABLE #SAgWinLoss

	DROP TABLE #TempExchange

END
GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_LicWinloss] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_LicWinloss] TO [vnteam]
GO
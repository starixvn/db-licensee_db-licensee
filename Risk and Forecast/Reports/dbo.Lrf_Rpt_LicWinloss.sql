/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
USE bodb02
GO

ALTER PROCEDURE [dbo].[Lrf_Rpt_LicWinloss]  	
	@LicenseeID		INT,
	@FromDate		SMALLDATETIME,  
	@ToDate			SMALLDATETIME,   
	@showSB			BIT = 0,  
	@ShowNG			BIT = 0, 
	@ShowBA			BIT = 0,	
	@ShowVS			BIT = 0,
	@ShowCS   		BIT = 0, -- RNG Casino
	@ShowKN			BIT = 0, -- Keno
	@ShowBT 		BIT = 0, -- licenseeWLBT
	@ShowAGC		BIT = 0, -- AGCasino
	@ShowVB			BIT = 0, -- Voidbridge
	@ShowAB			BIT = 0, -- Allbet
	@ShowFW			BIT = 0, -- Fishing World
	@ShowCO			BIT = 0, -- Cash Out
	@ShowVS2		BIT = 0, -- Bet Radar Virtual Sports
	@ShowLT			BIT = 0, -- Lottery
	@ShowPP			BIT = 0, -- PP
	@ReportType		TINYINT = 1,  
	@MoveBetsDay	SMALLDATETIME,
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
	- 20170320@Paul: Implement Cash Out [RedmineID :#71727]
	- 20170710@Harper: LRF - Integrate Bet Radar Virtual Sports [RedmineID: #78241]
	- 20170711@Harper: Fix Racing Revenue of Licensee Winloss [RedmineID :#79748]
	- 20170731@Harper: LRF - Integrate Lottery [RedmineID: #79997]
	- 20180129@Harper: Remove LC from product list [RedmineID: #85965]
	- 20180418@Amanda: LAP - Integrate PP [RedmineID: #92318]
	- 20180420@Amanda: Include more cash out tickets [RedmineID: #93919]
	- 20180509@Joseph: Remove cheat currency name for special currencies [RedmineID: #94845]
	- 20180807@Amanda: Remove Racing, Bingo and Old(@IsOld) data [RedmineID: #99378]
	- 20181126@Paul: Add OPTION(RECOMPILE) [RedmineID: #105304]
	- 20181019@Amanda: Add new bet types for E-Sports 2.0 [RedmineID: #100721]
	- 20190304@Amanda: Integrate PP Promotion Prize [RedmineID: #109471]
	- 20190322@Amanda: Remove MGCLC & MGRnG [RedmineID: #107704]

	Param's Explanation:  
	  + @ReportType: 1-Daily; 2-Monthly;  
	  +	@drawfilter: 'No Draw' filter is supportted (1:Normal 2:No Draw 3:No Draw for Turnover only)
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
		CommBA				MONEY,
		PlayerComm			MONEY,
		Betcount			BIGINT,
		licenseeWLBT		MONEY,   
		BetTradeComm		MONEY,  
		WLBetTicket			MONEY, 	
		WLBoughtTicket		MONEY,
		BuyBackAmtSB		MONEY,
		BuyBackAmtBA		MONEY,
		CashOutComm			MONEY,
		PromotionPrize		INT
	) 
 

	DECLARE @tempAg				TABLE(custID INT, currency INT)  

	DECLARE @bettype			TABLE (bettype INT PRIMARY KEY, ProductCode VARCHAR(10))
	DECLARE @sporttype			TABLE (sporttype INT, ProductCode VARCHAR(10))
	DECLARE @LicenseeName		VARCHAR(50)
	DECLARE @WLBetTicket		TABLE (winlostdate DATETIME, currency INT, WLBetTicket MONEY)
	DECLARE @ProductList		VARCHAR (500)

	DECLARE @_FromDate SMALLDATETIME, @_ToDate SMALLDATETIME
	SELECT @_FromDate = @FromDate, @_ToDate = @ToDate

	DECLARE @IsTest BIT = 0
	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

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
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'SB', 'SB')		
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

	IF @ShowKN = 1 -- Keno
	BEGIN 
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'KN', 'KN')
	END

	IF @ShowAGC = 1 -- AGCasino
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'AGC', 'AGC')
	END

	IF @ShowVB = 1
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'VB', 'VB')
	END
	IF @ShowAB = 1
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'AB', 'AB')
	END

	IF @ShowFW = 1
	BEGIN 
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'FW', 'FW')
	END

	IF @ShowVS2 = 1 -- Betradar Virtual Sports
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'VS2', 'VS2')
	END
	
	IF @ShowLT = 1 -- Lottery
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'LT', 'LT')
	END
	
	IF @ShowPP = 1 -- PP
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'PP', 'PP')
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

		IF CHARINDEX('SB', @ProductList) > 0
			DELETE @bettype
			WHERE ProductCode = 'SB'
		
		-- Insert Sport Type
		INSERT INTO @sporttype ( sporttype, ProductCode )
		SELECT DISTINCT sporttype, ProductCode
		FROM f_LicWinLoss_ProductSportType_Sel(@ProductList)

	END	

	DECLARE @TempFromDate	DATETIME,
			@TempToDate		DATETIME

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
			(  
				winlostdate, Currency, ProductCode, Turnover, BTActualStake,
				Winlost, LicenseeWL, AmtDueToBA, CommBA,
				PlayerComm, Betcount, licenseeWLBT, BetTradeComm,  
				WLBetTicket, WLBoughtTicket, BuyBackAmtSB, BuyBackAmtBA, CashOutComm, PromotionPrize
			)
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
				SUM(CASE WHEN RAND() + 1 > 0 THEN comm ELSE 0 END) AS CommBA,
				SUM(ISNULL(CASE WHEN RAND() + 1 > 0 THEN b.playercomm ELSE 0 END,0)) AS PlayerComm,
				COUNT(CASE WHEN RAND() + 1 > 0 AND @drawfilter = 2 AND b.statusID = 111 THEN NULL ELSE b.transid END)AS BetCount,
				0 AS licenseeWLBT,
				0 AS BetTradeComm,			
				SUM(CASE WHEN RAND() + 1 > 0 AND b.betdaqid = 0 THEN (b.winlost-b.actual_stake) ELSE 0 END) AS WLBetTicket,
				0 AS WLBoughtTicket,
				0 AS BuyBackAmtSB,
				0 AS BuyBackAmtBA,
				0 AS CashOutComm,
				0 AS PromotionPrize
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
			OPTION(RECOMPILE)
		END
	
		IF @ShowSB = 1
		BEGIN
			INSERT INTO #SAgWinLoss
			(  
				winlostdate, Currency, ProductCode, Turnover, BTActualStake,
				Winlost, LicenseeWL, AmtDueToBA, CommBA,
				PlayerComm, Betcount, licenseeWLBT, BetTradeComm,  
				WLBetTicket, WLBoughtTicket, BuyBackAmtSB, BuyBackAmtBA, CashOutComm, PromotionPrize
			)
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
				0 AS CommBA,
				SUM(CASE WHEN RAND() + 1 > 0 THEN b.playerComm ELSE 0 END) AS PlayerComm,
				COUNT(CASE WHEN RAND() + 1 > 0 AND @drawfilter = 2 AND b.statusID = 111 THEN NULL ELSE b.transid END)AS BetCount,
				0 AS licenseeWLBT,
				0 AS BetTradeComm,	
				SUM(CASE WHEN RAND() + 1 > 0 AND b.betdaqid = 0 THEN b.winlost-b.actual_stake ELSE 0 END) AS WLBetTicket,
				0 AS WLBoughtTicket,
				0 AS BuyBackAmtSB,
				0 AS BuyBackAmtBA,
				0 AS CashOutComm,
				0 AS PromotionPrize
			FROM 
				Bettrans b WITH (NOLOCK)
				INNER JOIN @tempAg a ON b.recommend = a.custID AND b.currency = a.currency
			WHERE 
				b.winlostdate BETWEEN @TempFromDate AND @_ToDate
				AND  
				(
					b.bettype <= 30
					OR b.bettype BETWEEN 121 AND 999
					OR b.Bettype BETWEEN 1301 and 1399 --new tennis's bettypes
					OR b.Bettype BETWEEN 9001 and 9086 -- E-Sports 2.0
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
			(  
				winlostdate, Currency, ProductCode, Turnover, BTActualStake,
				Winlost, LicenseeWL, AmtDueToBA, CommBA,
				PlayerComm, Betcount, licenseeWLBT, BetTradeComm,  
				WLBetTicket, WLBoughtTicket, BuyBackAmtSB, BuyBackAmtBA, CashOutComm, PromotionPrize
			)
			SELECT   
				b.winlostdate,  
				a.currency,
				'BT',
				0 turnover,
				SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 902 THEN b.winlost ELSE 0 END) AS BTActualStake,
				SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 903 THEN 0 ELSE b.winlost-b.actual_stake END) AS Winlost,
				0 AS LicenseeWL,
				0 AS AmountDueToBA,
				0 AS CommBA,
				0 AS PlayerComm,
				COUNT(CASE WHEN RAND() + 1 > 0 AND ((b.bettype = 903) OR (@drawfilter = 2 AND b.statusID = 111)) THEN NULL ELSE b.transid END) AS BetCount,
				-SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype IN (901, 902) THEN b.winlost-b.actual_stake ELSE 0 END) AS licenseeWLBT,
				SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 903 THEN b.awinlost ELSE 0 END) AS BetTradeComm,
				0 WLBetTicket,
				SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 902 THEN b.winlost-b.actual_stake ELSE 0 END) AS WLBoughtTicket,
				SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 902 AND transid2 = 0 THEN b.actual_stake ELSE 0 END) AS BuyBackAmtSB,
				SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 902 AND transid2 = 1 THEN b.actual_stake ELSE 0 END) AS BuyBackAmtBA,
				0 AS CashOutComm,
				0 AS PromotionPrize
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
			(  
				winlostdate, Currency, ProductCode, Turnover, BTActualStake,
				Winlost, LicenseeWL, AmtDueToBA, CommBA,
				PlayerComm, Betcount, licenseeWLBT, BetTradeComm,  
				WLBetTicket, WLBoughtTicket, BuyBackAmtSB, BuyBackAmtBA, CashOutComm, PromotionPrize
			)
			SELECT   
				b.winlostdate,  
				a.currency,
				'CO',
				0 AS turnover,
				0 AS BTActualStake,
				SUM(CASE WHEN b.bettype = 913 THEN 0 ELSE b.winlost - b.actual_stake END) AS Winlost,
				- SUM(CASE WHEN b.bettype = 913 THEN 0 ELSE b.winlost - b.actual_stake END) AS LicenseeWL,
				0 AS AmountDueToBA,
				0 AS CommBA,
				0 AS PlayerComm,
				SUM(CASE WHEN b.bettype = 913 THEN 0 ELSE 1 END) AS BetCount,
				0 AS licenseeWLBT,
				0 AS BetTradeComm,
				0 WLBetTicket,
				0 AS WLBoughtTicket,
				0 AS BuyBackAmtSB,
				0 AS BuyBackAmtBA,
				SUM(CASE WHEN b.bettype = 913 THEN b.awinlost ELSE 0 END) AS CashOutComm,
				0 AS PromotionPrize
			FROM 
				Bettrans b WITH (NOLOCK)
				INNER JOIN @tempAg a ON b.recommend = a.custID AND b.currency = a.currency
			WHERE 
				b.winlostdate BETWEEN @TempFromDate AND @_ToDate
				AND b.bettype IN (911, 912, 913)
				AND b.statusID IN (111, 112, 113)
				AND b.transid >= @transid
			GROUP BY b.winlostdate, a.currency  
		END

		IF 1 IN (@ShowNG, @ShowVS, @ShowCS, @ShowKN, @ShowAGC, @ShowVB, @ShowAB, @ShowFW, @ShowVS2, @ShowLT, @ShowPP)
		BEGIN
			INSERT INTO #SAgWinLoss
			(  
				winlostdate, Currency, ProductCode, Turnover, BTActualStake,
				Winlost, LicenseeWL, AmtDueToBA, CommBA,
				PlayerComm, Betcount, licenseeWLBT, BetTradeComm,  
				WLBetTicket, WLBoughtTicket, BuyBackAmtSB, BuyBackAmtBA, CashOutComm, PromotionPrize
			)
			SELECT   
				b.winlostdate,  
				a.currency,
				bt.ProductCode,
				SUM(CASE WHEN RAND() + 1 > 0 AND @drawfilter IN (2,3) AND b.statusID = 111 THEN 0 ELSE stake END) AS turnover,
				0 AS BTActualStake,
				SUM(CASE WHEN RAND() + 1 > 0 THEN b.winlost-b.actual_stake ELSE 0 END) AS Winlost,
				-SUM(CASE WHEN RAND() + 1 > 0 THEN b.winlost - b.actual_stake ELSE 0 END) AS LicenseeWL,
				0 AS AmountDueToBA,
				0 AS CommBA,
				SUM(CASE WHEN RAND() + 1 > 0 THEN b.playerComm ELSE 0 END) AS PlayerComm,
				COUNT(CASE WHEN RAND() + 1 > 0 AND @drawfilter = 2 AND b.statusID = 111 THEN NULL ELSE b.transid END) AS BetCount,
				0 AS licenseeWLBT,
				0 AS BetTradeComm,	
				0 AS WLBetTicket,
				0 AS WLBoughtTicket,
				0 AS BuyBackAmtSB,
				0 AS BuyBackAmtBA,
				0 AS CashOutComm,
				SUM (CASE WHEN b.bettype = 4300 THEN 1 ELSE 0 END) AS PromotionPrize
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
				bt.ProductCode
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
			(  
				winlostdate, Currency, ProductCode, Turnover, BTActualStake,
				Winlost, LicenseeWL, AmtDueToBA, CommBA,
				PlayerComm, Betcount, licenseeWLBT, BetTradeComm,  
				WLBetTicket, WLBoughtTicket, BuyBackAmtSB, BuyBackAmtBA, CashOutComm, PromotionPrize
			)
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
				SUM (CASE WHEN RAND() + 1 > 0 THEN b.comm ELSE 0 END) AS CommBA,
				SUM(ISNULL(CASE WHEN RAND() + 1 > 0 THEN b.playercomm ELSE 0 END,0)) AS PlayerComm,
				SUM(CASE WHEN RAND() + 1 > 0 AND @drawfilter = 2 AND b.statusID = 111 THEN 0 ELSE b.betcount END) AS BetCount,
				0 AS licenseeWLBT,
				0 AS BetTradeComm,	
				0 AS WLBetTicket,
				0 AS WLBoughtTicket,
				0 AS BuyBackAmtSB,
				0 AS BuyBackAmtBA,
				0 AS CashOutComm,
				0 AS PromotionPrize
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

			INSERT INTO @WLBetTicket(winlostdate, currency, WLBetTicket)
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
		IF 1 IN (@showSB, @ShowNG, @ShowVS, @ShowCS, @ShowKN, @ShowAGC, @ShowVB, @ShowAB, @ShowFW, @ShowVS2, @ShowLT, @ShowPP)
		BEGIN
			INSERT INTO #SAgWinLoss 
			(  
				winlostdate, Currency, ProductCode, Turnover, BTActualStake,
				Winlost, LicenseeWL, AmtDueToBA, CommBA,
				PlayerComm, Betcount, licenseeWLBT, BetTradeComm,  
				WLBetTicket, WLBoughtTicket, BuyBackAmtSB, BuyBackAmtBA, CashOutComm, PromotionPrize
			) 
			SELECT 
				b.winlostdate,  
				b.currency,
				t.ProductCode,
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
				0 AS CommBA,
				SUM(ISNULL(CASE WHEN RAND() + 1 > 0 THEN playercomm ELSE 0 END, 0)) AS PlayerComm,
				SUM(CASE WHEN RAND() + 1 > 0 AND @drawfilter = 2 AND b.statusID = 111 THEN 0 ELSE b.betcount END) AS BetCount,
				0 AS licenseeWLBT,
				0 AS BetTradeComm,	
				0 AS WLBetTicket,
				0 AS WLBoughtTicket,
				0 AS BuyBackAmtSB,
				0 AS BuyBackAmtBA,
				0 AS CashOutComm,
				SUM(CASE WHEN b.bettype = 4300 THEN 1 ELSE 0 END) AS PromotionPrize
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
				t.ProductCode

			INSERT INTO @WLBetTicket(winlostdate, currency, WLBetTicket)
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
			(  
				winlostdate, Currency, ProductCode, Turnover, BTActualStake,
				Winlost, LicenseeWL, AmtDueToBA, CommBA,
				PlayerComm, Betcount, licenseeWLBT, BetTradeComm,  
				WLBetTicket, WLBoughtTicket, BuyBackAmtSB, BuyBackAmtBA, CashOutComm, PromotionPrize
			)
			SELECT   
				b.winlostdate,  
				ag.currency,
				'BT',
				0 AS turnover,
				SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 902 THEN b.winlost + BuyBackAmt + BABuyBackAmt ELSE 0 END) AS BTActualStake,
				SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 903 THEN 0 ELSE b.winlost END) AS Winlost,    
				0 AS LicenseeWL,
				0 as AmountDueToBA,
				0 as CommBA,
				0 as PlayerComm,
				SUM(CASE WHEN RAND() + 1 > 0 AND ((b.bettype = 903) OR (@drawfilter = 2 AND b.statusID = 111)) THEN 0 ELSE b.BetCount END) AS BetCount,
				-SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype IN (901, 902) THEN b.winlost ELSE 0 END) AS licenseeWLBT,
				SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 903 THEN b.awinlost ELSE 0 END) AS BetTradeComm,
				0 WLBetTicket,
				SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 902 THEN b.winlost ELSE 0 END) AS WLBoughtTicket,
				SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 902 THEN BuyBackAmt ELSE 0 END) AS BuyBackAmtSB,
				SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 902 THEN BABuyBackAmt ELSE 0 END) AS BuyBackAmtBA,
				0 AS CashOutComm,
				0 AS PromotionPrize
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

		IF @ShowCO = 1
		BEGIN
			INSERT INTO #SAgWinLoss
			(  
				winlostdate, Currency, ProductCode, Turnover, BTActualStake,
				Winlost, LicenseeWL, AmtDueToBA, CommBA,
				PlayerComm, Betcount, licenseeWLBT, BetTradeComm,  
				WLBetTicket, WLBoughtTicket, BuyBackAmtSB, BuyBackAmtBA, CashOutComm, PromotionPrize
			)
			SELECT   
				b.winlostdate,  
				ag.currency,
				'CO',
				0 AS turnover,
				0 AS BTActualStake,
				SUM(CASE WHEN b.bettype = 913 THEN 0 ELSE b.winlost END) AS Winlost,    
				- SUM(CASE WHEN b.bettype = 913 THEN 0 ELSE b.winlost END) AS LicenseeWL,
				0 as AmountDueToBA,
				0 as CommBA,
				0 as PlayerComm,
				SUM(CASE WHEN b.bettype = 913 THEN 0 ELSE b.BetCount END) AS BetCount,
				0 AS licenseeWLBT,
				0 AS BetTradeComm,
				0 WLBetTicket,
				0 AS WLBoughtTicket,
				0 AS BuyBackAmtSB,
				0 AS BuyBackAmtBA,
				SUM(CASE WHEN b.bettype = 913 THEN b.awinlost ELSE 0 END) AS CashOutComm,
				0 AS PromotionPrize
			FROM 
				bodb_licenseereport.dbo.rptLicWinloss2 b WITH ( NOLOCK )  
				INNER JOIN @TempAg ag ON b.recommend = ag.custID AND ag.currency = b.Currency
			WHERE 
				b.Winlostdate BETWEEN @_FromDate AND @TempToDate
				AND b.bettype IN (911, 912, 913) 
				AND b.statusID  IN (111, 112, 113)
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
		TurnoverVS			MONEY,
		TurnoverCS 			MONEY,
		TurnoverKN			MONEY,
		turnoverAGC			MONEY,
		turnoverVB			MONEY, 
		turnoverAB			MONEY,
		turnoverFW			MONEY, 
		turnoverCO			MONEY,
		TurnoverVS2			MONEY,
		TurnoverLT			MONEY,
		TurnoverPP			MONEY,
		BTActualStake		MONEY,
		Winlost				MONEY,
		LicenseeWLSB 		MONEY,
		LicenseeWLBA		MONEY,
		LicenseeWLNG		MONEY,
		LicenseeWLVS		MONEY,
		LicenseeWLCS		MONEY,
		LicenseeWLKN		MONEY,
		LicenseeWLAGC		MONEY,
		LicenseeWLVB		MONEY,
		LicenseeWLAB		MONEY,
		LicenseeWLFW		MONEY,
		LicenseeWLCO		MONEY,
		LicenseeWLVS2		MONEY,
		LicenseeWLLT		MONEY,
		LicenseeWLPP		MONEY,
		AmtDueToBA			MONEY,
		CommBA				MONEY,
		PlayerComm			MONEY,
		Betcount			BIGINT,
		licenseeWLBT		MONEY,   
		BetTradeComm		MONEY,  
		WLBetTicket			MONEY, 	
		WLBoughtTicket		MONEY,
		BuyBackAmtSB		MONEY,
		BuyBackAmtBA		MONEY,
		CashOutComm			MONEY,
		PromotionPrize		INT,
		UNIQUE CLUSTERED (winlostdate, currency)
	)  

	INSERT INTO @SAgWL
	(  
		winlostdate, Currency,
		TurnoverSB, TurnoverBA, TurnoverNG, TurnoverVS, TurnoverCS,
		TurnoverKN, turnoverAGC, turnoverVB, turnoverAB, turnoverFW, turnoverCO, TurnoverVS2, TurnoverLT, TurnoverPP,
		BTActualStake, Winlost,
		LicenseeWLSB, LicenseeWLBA, LicenseeWLNG, LicenseeWLVS, LicenseeWLCS,
		LicenseeWLKN, LicenseeWLAGC, LicenseeWLVB, LicenseeWLAB, LicenseeWLFW, LicenseeWLCO, LicenseeWLVS2, LicenseeWLLT, LicenseeWLPP,
		AmtDueToBA,
		CommBA,
		PlayerComm,
		Betcount,
		licenseeWLBT,   
		BetTradeComm,  
		WLBetTicket, WLBoughtTicket,
		BuyBackAmtSB, BuyBackAmtBA,
		CashOutComm,
		PromotionPrize
	)
	SELECT
		winlostdate,
		Currency,
		SUM(CASE ProductCode WHEN 'SB'		THEN Turnover ELSE 0 END)	AS TurnoverSB,   
		SUM(CASE ProductCode WHEN 'BA'		THEN Turnover ELSE 0 END)	AS TurnoverBA,   
		SUM(CASE ProductCode WHEN 'NG'		THEN Turnover ELSE 0 END)	AS TurnoverNG,   
		SUM(CASE ProductCode WHEN 'VS'		THEN Turnover ELSE 0 END)	AS TurnoverVS,   
		SUM(CASE ProductCode WHEN 'CS'		THEN Turnover ELSE 0 END)	AS TurnoverCS,
		SUM(CASE ProductCode WHEN 'KN'		THEN Turnover ELSE 0 END)	AS TurnoverKN,
		SUM(CASE ProductCode WHEN 'AGC'		THEN Turnover ELSE 0 END)	AS TurnoverAGC,
		SUM(CASE ProductCode WHEN 'VB'		THEN Turnover ELSE 0 END)	AS TurnoverVB,
		SUM(CASE ProductCode WHEN 'AB'		THEN Turnover ELSE 0 END)	AS TurnoverAB,
		SUM(CASE ProductCode WHEN 'FW'		THEN Turnover ELSE 0 END)	AS TurnoverFW,
		SUM(CASE ProductCode WHEN 'CO'		THEN Turnover ELSE 0 END)	AS TurnoverCO,
		SUM(CASE ProductCode WHEN 'VS2'	THEN Turnover ELSE 0 END)	AS TurnoverVS2,
		SUM(CASE ProductCode WHEN 'LT'		THEN Turnover ELSE 0 END)	AS TurnoverLT,
		SUM(CASE ProductCode WHEN 'PP'		THEN Turnover ELSE 0 END)	AS TurnoverPP,
		SUM(BTActualStake)		AS BTActualStake,
		SUM(Winlost)			AS Winlost,
		SUM(CASE ProductCode WHEN 'SB'		THEN LicenseeWL ELSE 0 END)	AS LicenseeWLSB,   
		SUM(CASE ProductCode WHEN 'BA'		THEN LicenseeWL ELSE 0 END)	AS LicenseeWLBA,   
		SUM(CASE ProductCode WHEN 'NG'		THEN LicenseeWL ELSE 0 END)	AS LicenseeWLNG,   
		SUM(CASE ProductCode WHEN 'VS'		THEN LicenseeWL ELSE 0 END)	AS LicenseeWLVS,   
		SUM(CASE ProductCode WHEN 'CS'		THEN LicenseeWL ELSE 0 END)	AS LicenseeWLCS,
		SUM(CASE ProductCode WHEN 'KN'		THEN LicenseeWL ELSE 0 END)	AS LicenseeWLKN,
		SUM(CASE ProductCode WHEN 'AGC'		THEN LicenseeWL ELSE 0 END)	AS LicenseeWLAGC,
		SUM(CASE ProductCode WHEN 'VB'		THEN LicenseeWL ELSE 0 END)	AS LicenseeWLVB,
		SUM(CASE ProductCode WHEN 'AB'		THEN LicenseeWL ELSE 0 END)	AS LicenseeWLAB,
		SUM(CASE ProductCode WHEN 'FW'		THEN LicenseeWL ELSE 0 END)	AS LicenseeWLFW,
		SUM(CASE ProductCode WHEN 'CO'		THEN LicenseeWL ELSE 0 END)	AS LicenseeWLCO,
		SUM(CASE ProductCode WHEN 'VS2'	THEN LicenseeWL ELSE 0 END)	AS LicenseeWLVS2,
		SUM(CASE ProductCode WHEN 'LT'		THEN LicenseeWL ELSE 0 END)	AS LicenseeWLLT,
		SUM(CASE ProductCode WHEN 'PP'		THEN LicenseeWL ELSE 0 END)	AS LicenseeWLPP,
		SUM(AmtDuetoBA)			AS AmtDuetoBA,
		SUM(CommBA)				AS CommBA,
		SUM(playerComm)			AS PlayerComm,
		SUM(Betcount)			AS Betcount,
		SUM(licenseeWLBT)		AS licenseeWLBT,
		SUM(BetTradeComm)		AS BetTradeComm,
		SUM(WLBetTicket)		AS WLBetTicket,
		SUM(WLBoughtTicket)		AS WLBoughtTicket,
		SUM(BuyBackAmtSB)		AS BuyBackAmtSB,
		SUM(BuyBackAmtBA)		AS BuyBackAmtBA,
		SUM(CashOutComm)		AS CashOutComm,
		SUM(PromotionPrize)		AS PromotionPrize
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
		SUM(TurnoverSB)			AS TurnoverSB,   
		SUM(TurnoverBA)			AS TurnoverBA,   
		SUM(TurnoverNG)			AS TurnoverNG,
		SUM(TurnoverVS)			AS TurnoverVS,   
		SUM(TurnoverCS)			AS TurnoverCS,
		SUM(TurnoverKN)			AS TurnoverKN,
		SUM(TurnoverAGC)		AS TurnoverAGC,
		SUM(TurnoverVB)			AS TurnoverVB,
		SUM(TurnoverAB)			AS TurnoverAB,
		SUM(TurnoverFW)			AS TurnoverFW,
		SUM(TurnoverCO)			AS TurnoverCO,
		SUM(TurnoverVS2)		AS TurnoverVS2,
		SUM(TurnoverLT)			AS TurnoverLT,
		SUM(TurnoverPP)			AS TurnoverPP,
		SUM(BTActualStake)		AS BTActualStake,
		SUM(Winlost)			AS Winlost,
		SUM(LicenseeWLSB)		AS LicenseeWLSB,
		SUM(LicenseeWLBA)		AS LicenseeWLBA,
		SUM(LicenseeWLNG)		AS LicenseeWLNG,
		SUM(LicenseeWLVS)		AS LicenseeWLVS,   
		SUM(LicenseeWLCS)		AS LicenseeWLCS,
		SUM(LicenseeWLKN)		AS LicenseeWLKN,
		SUM(LicenseeWLAGC)		AS LicenseeWLAGC,
		SUM(LicenseeWLVB)		AS LicenseeWLVB,
		SUM(LicenseeWLAB)		AS LicenseeWLAB,
		SUM(LicenseeWLFW)		AS LicenseeWLFW,
		SUM(LicenseeWLCO)		AS LicenseeWLCO,
		SUM(LicenseeWLVS2)		AS LicenseeWLVS2,
		SUM(LicenseeWLLT)		AS LicenseeWLLT,
		SUM(LicenseeWLPP)		AS LicenseeWLPP,
		SUM(CommBA)				AS CommBA,
		SUM(playerComm)			AS PlayerComm,
		SUM(AmtDuetoBA)			AS AmtDuetoBA,
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
		CAST(SUM(TurnoverVS*e.USD)			AS MONEY)	AS TurnoverVSUSD,
		CAST(SUM(TurnoverCS*e.USD)			AS MONEY)   AS TurnoverCSUSD,
		CAST(SUM(TurnoverKN*e.USD)			AS MONEY)   AS TurnoverKNUSD,
		CAST(SUM(TurnoverAGC*e.USD)			AS MONEY)   AS TurnoverAGCUSD,
		CAST(SUM(TurnoverVB*e.USD)			AS MONEY)   AS TurnoverVBUSD,
		CAST(SUM(TurnoverAB*e.USD)			AS MONEY)   AS TurnoverABUSD,
		CAST(SUM(TurnoverFW*e.USD)			AS MONEY)   AS TurnoverFWUSD,
		CAST(SUM(TurnoverCO*e.USD)			AS MONEY)   AS TurnoverCOUSD,
		CAST(SUM(TurnoverVS2*e.USD)		AS MONEY)   AS TurnoverVS2USD,
		CAST(SUM(TurnoverLT*e.USD)			AS MONEY)   AS TurnoverLTUSD,
		CAST(SUM(TurnoverPP*e.USD)			AS MONEY)   AS TurnoverPPUSD,
		CAST(SUM(BTActualStake*e.USD)		AS MONEY)   AS BTActualStakeUSD,
		CAST(SUM(Winlost*e.USD)				AS MONEY)	AS WinlostUSD,
		CAST(SUM(LicenseeWLSB*e.USD)		AS MONEY)	AS LicenseeWLSBUSD,
		CAST(SUM(LicenseeWLBA*e.USD)		AS MONEY)	AS LicenseeWLBAUSD,
		CAST(SUM(LicenseeWLNG*e.USD)		AS MONEY) 	AS LicenseeWLNGUSD,
		CAST(SUM(LicenseeWLVS*e.USD)		AS MONEY)	AS LicenseeWLVSUSD,
		CAST(SUM(LicenseeWLCS*e.USD)		AS MONEY)	AS LicenseeWLCSUSD,
		CAST(SUM(LicenseeWLKN*e.USD)		AS MONEY)	AS LicenseeWLKNUSD,
		CAST(SUM(LicenseeWLAGC*e.USD)		AS MONEY)	AS LicenseeWLAGCUSD,
		CAST(SUM(LicenseeWLVB*e.USD)		AS MONEY)	AS LicenseeWLVBUSD,
		CAST(SUM(LicenseeWLAB*e.USD)		AS MONEY)	AS LicenseeWLABUSD,
		CAST(SUM(LicenseeWLFW*e.USD)		AS MONEY)	AS LicenseeWLFWUSD,
		CAST(SUM(LicenseeWLCO*e.USD)		AS MONEY)	AS LicenseeWLCOUSD,
		CAST(SUM(LicenseeWLVS2*e.USD)		AS MONEY)	AS LicenseeWLVS2USD,
		CAST(SUM(LicenseeWLLT*e.USD)		AS MONEY)	AS LicenseeWLLTUSD,
		CAST(SUM(LicenseeWLPP*e.USD)		AS MONEY)	AS LicenseeWLPPUSD,
		CAST(SUM(CommBA * e.USD)			AS MONEY)	AS CommBAUSD,
		CAST(SUM(PlayerComm*e.USD)			AS MONEY)	AS PlayerCommUSD,
		CAST(SUM(AmtDuetoBA*e.USD)			AS MONEY)	AS AmtDuetoBAUSD,
		CAST(SUM(licenseeWLBT* e.USD)		AS MONEY)   AS licenseeWLBTUSD,
		CAST(SUM(BetTradeComm* e.USD)		AS MONEY)	AS BetTradeCommUSD,
		CAST(SUM((WLBetTicket+WLBoughtTicket-BetTradeComm)* e.USD) AS MONEY)	AS AmtDueToBTUSD,
		CAST(SUM(BuyBackAmtSB * e.USD)		AS MONEY)	AS BuyBackAmtSBUSD,
		CAST(SUM(BuyBackAmtBA * e.USD)		AS MONEY)	AS BuyBackAmtBAUSD,
		CAST(SUM(CashOutComm * e.USD)		AS MONEY)	AS CashOutCommUSD,
		CAST(SUM(TurnoverSB*e.EUR)			AS MONEY)   AS TurnoverSBEUR,   
		CAST(SUM(TurnoverBA*e.EUR)			AS MONEY)   AS TurnoverBAEUR,   
		CAST(SUM(TurnoverNG*e.EUR)			AS MONEY)   AS TurnoverNGEUR,   
		CAST(SUM(TurnoverVS*e.EUR)			AS MONEY)   AS TurnoverVSEUR,  
		CAST(SUM(TurnoverCS*e.EUR)			AS MONEY)   AS TurnoverCSEUR,
		CAST(SUM(TurnoverKN*e.EUR)			AS MONEY)   AS TurnoverKNEUR,
		CAST(SUM(TurnoverAGC*e.EUR)			AS MONEY)   AS TurnoverAGCEUR,
		CAST(SUM(TurnoverVB*e.EUR)			AS MONEY)   AS TurnoverVBEUR,
		CAST(SUM(TurnoverAB*e.EUR)			AS MONEY)   AS TurnoverABEUR,
		CAST(SUM(TurnoverFW*e.EUR)			AS MONEY)   AS TurnoverFWEUR,
		CAST(SUM(TurnoverCO*e.EUR)			AS MONEY)   AS TurnoverCOEUR,
		CAST(SUM(TurnoverVS2*e.EUR)		AS MONEY)   AS TurnoverVS2EUR,
		CAST(SUM(TurnoverLT*e.EUR)			AS MONEY)   AS TurnoverLTEUR,
		CAST(SUM(TurnoverPP*e.EUR)			AS MONEY)   AS TurnoverPPEUR,
		CAST(SUM(BTActualStake*e.EUR)		AS MONEY)   AS BTActualStakeEUR,
		CAST(SUM(Winlost*e.EUR)				AS MONEY)	AS WinlostEUR,
		CAST(SUM(LicenseeWLSB*e.EUR)		AS MONEY)	AS LicenseeWLSBEUR,
		CAST(SUM(LicenseeWLBA*e.EUR)		AS MONEY)	AS LicenseeWLBAEUR,
		CAST(SUM(LicenseeWLNG*e.EUR)		AS MONEY)	AS LicenseeWLNGEUR,
		CAST(SUM(LicenseeWLVS*e.EUR)		AS MONEY)	AS LicenseeWLVSEUR,
		CAST(SUM(LicenseeWLCS*e.EUR)		AS MONEY)	AS LicenseeWLCSEUR,
		CAST(SUM(LicenseeWLKN*e.EUR)		AS MONEY)	AS LicenseeWLKNEUR,
		CAST(SUM(LicenseeWLAGC*e.EUR)		AS MONEY)	AS LicenseeWLAGCEUR,
		CAST(SUM(LicenseeWLVB*e.EUR)		AS MONEY)	AS LicenseeWLVBEUR,
		CAST(SUM(LicenseeWLAB*e.EUR)		AS MONEY)	AS LicenseeWLABEUR,
		CAST(SUM(LicenseeWLFW*e.EUR)		AS MONEY)	AS LicenseeWLFWEUR,
		CAST(SUM(LicenseeWLCO*e.EUR)		AS MONEY)	AS LicenseeWLCOEUR,
		CAST(SUM(LicenseeWLVS2*e.EUR)		AS MONEY)	AS LicenseeWLVS2EUR,
		CAST(SUM(LicenseeWLLT*e.EUR)		AS MONEY)	AS LicenseeWLLTEUR,
		CAST(SUM(LicenseeWLPP*e.EUR)		AS MONEY)	AS LicenseeWLPPEUR,
		CAST(SUM(CommBA * e.EUR)			AS MONEY)	AS CommBAEUR,
		CAST(SUM(PlayerComm*e.EUR)			AS MONEY)	AS PlayerCommEUR,
		CAST(SUM(AmtDuetoBA*e.EUR)			AS MONEY)	AS AmtDuetoBAEUR,
		CAST(SUM(licenseeWLBT* e.EUR)		AS MONEY)   AS licenseeWLBTEUR,
		CAST(SUM(BetTradeComm* e.EUR)		AS MONEY)	AS BetTradeCommEUR,
		CAST(SUM((WLBetTicket+WLBoughtTicket-BetTradeComm)* e.EUR) AS MONEY)	AS AmtDueToBTEUR,
		CAST(SUM(BuyBackAmtSB * e.EUR)		AS MONEY)	AS BuyBackAmtSBEUR,
		CAST(SUM(BuyBackAmtBA * e.EUR)		AS MONEY)	AS BuyBackAmtBAEUR,
		CAST(SUM(CashOutComm * e.EUR)		AS MONEY)	AS CashOutCommEUR,
		CAST(SUM(TurnoverSB*e.GBP)			AS MONEY)   AS TurnoverSBGBP,   
		CAST(SUM(TurnoverBA*e.GBP)			AS MONEY)   AS TurnoverBAGBP,   
		CAST(SUM(TurnoverNG*e.GBP)			AS MONEY)   AS TurnoverNGGBP,   
		CAST(SUM(TurnoverVS*e.GBP)			AS MONEY)   AS TurnoverVSGBP,  
		CAST(SUM(TurnoverCS*e.GBP)			AS MONEY)   AS TurnoverCSGBP,
		CAST(SUM(TurnoverKN*e.GBP)			AS MONEY)   AS TurnoverKNGBP,
		CAST(SUM(TurnoverAGC*e.GBP)			AS MONEY)   AS TurnoverAGCGBP,
		CAST(SUM(TurnoverVB*e.GBP)			AS MONEY)   AS TurnoverVBGBP,
		CAST(SUM(TurnoverAB*e.GBP)			AS MONEY)   AS TurnoverABGBP,
		CAST(SUM(TurnoverFW*e.GBP)			AS MONEY)   AS TurnoverFWGBP,
		CAST(SUM(TurnoverCO*e.GBP)			AS MONEY)   AS TurnoverCOGBP,
		CAST(SUM(TurnoverVS2*e.GBP)		AS MONEY)   AS TurnoverVS2GBP,
		CAST(SUM(TurnoverLT*e.GBP)			AS MONEY)   AS TurnoverLTGBP,
		CAST(SUM(TurnoverPP*e.GBP)			AS MONEY)   AS TurnoverPPGBP,
		CAST(SUM(BTActualStake*e.GBP)		AS MONEY)   AS BTActualStakeGBP,
		CAST(SUM(Winlost*e.GBP)				AS MONEY)	AS WinlostGBP,
		CAST(SUM(LicenseeWLSB*e.GBP)		AS MONEY)	AS LicenseeWLSBGBP,
		CAST(SUM(LicenseeWLBA*e.GBP)		AS MONEY)	AS LicenseeWLBAGBP,
		CAST(SUM(LicenseeWLNG*e.GBP)		AS MONEY)	AS LicenseeWLNGGBP,
		CAST(SUM(LicenseeWLVS*e.GBP)		AS MONEY)	AS LicenseeWLVSGBP,
		CAST(SUM(LicenseeWLCS*e.GBP)		AS MONEY)	AS LicenseeWLCSGBP,
		CAST(SUM(LicenseeWLKN*e.GBP)		AS MONEY)	AS LicenseeWLKNGBP,
		CAST(SUM(LicenseeWLAGC*e.GBP)		AS MONEY)	AS LicenseeWLAGCGBP,
		CAST(SUM(LicenseeWLVB*e.GBP)		AS MONEY)	AS LicenseeWLVBGBP,
		CAST(SUM(LicenseeWLAB*e.GBP)		AS MONEY)	AS LicenseeWLABGBP,
		CAST(SUM(LicenseeWLFW*e.GBP)		AS MONEY)	AS LicenseeWLFWGBP,
		CAST(SUM(LicenseeWLCO*e.GBP)		AS MONEY)	AS LicenseeWLCOGBP,
		CAST(SUM(LicenseeWLVS2*e.GBP)		AS MONEY)	AS LicenseeWLVS2GBP,
		CAST(SUM(LicenseeWLLT*e.GBP)		AS MONEY)	AS LicenseeWLLTGBP,
		CAST(SUM(LicenseeWLPP*e.GBP)		AS MONEY)	AS LicenseeWLPPGBP,
		CAST(SUM(CommBA*e.GBP)				AS MONEY)	AS CommBAGBP,
		CAST(SUM(PlayerComm*e.GBP)			AS MONEY)	AS PlayerCommGBP,
		CAST(SUM(AmtDuetoBA*e.GBP)			AS MONEY)	AS AmtDuetoBAGBP,
		CAST(SUM(licenseeWLBT*e.GBP)		AS MONEY)   AS licenseeWLBTGBP,
		CAST(SUM(BetTradeComm*e.GBP)		AS MONEY)	AS BetTradeCommGBP,
		CAST(SUM((WLBetTicket+WLBoughtTicket-BetTradeComm)* e.GBP) AS MONEY)	AS AmtDueToBTGBP,
		CAST(SUM(BuyBackAmtSB*e.GBP)		AS MONEY)	AS BuyBackAmtSBGBP,
		CAST(SUM(BuyBackAmtBA*e.GBP)		AS MONEY)	AS BuyBackAmtBAGBP,
		CAST(SUM(CashOutComm*e.GBP)		AS MONEY)	AS CashOutCommGBP,
		
		SUM(PromotionPrize)								AS PromotionPrize
	FROM	
		@SAgWL w   
		INNER JOIN #TempExchange e ON w.winlostdate = e.ExchangeDate AND w.currency = e.ExchangeId
	GROUP BY   
		Currency,
		CASE	WHEN @ReportType = 1 THEN CONVERT(VARCHAR(8),w.winlostdate,112)  
				WHEN @ReportType = 2 THEN CONVERT(VARCHAR(6),w.winlostdate,112)  
				ELSE '0' END
	ORDER BY ReportType

	DROP TABLE #SAgWinLoss

	DROP TABLE #TempExchange

END
GO
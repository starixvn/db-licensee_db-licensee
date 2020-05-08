/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_LicWinlossDetail_Ag]
	@LicenseeID		INT,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@showSB			BIT = 0,
	@ShowNG			BIT = 0,
	@ShowBA			BIT = 0,
	@ShowVS			BIT = 0,
	@ShowCS			BIT = 0, -- RNG Casino
	@ShowKN			BIT = 0, -- keno
	@ShowBT 		BIT = 0, -- licenseeWLBT
	@ShowAGC		BIT = 0, -- AGCasino
	@ShowVB			BIT = 0, -- Voidbridge
	@ShowAB			BIT = 0, -- Allbet
	@ShowFW			BIT = 0, -- Fishing World
	@ShowCO			BIT = 0, -- Cash Out
	@ShowVS2		BIT = 0, -- Bet Radar Virtual Sports
	@ShowLT			BIT = 0, -- Lottery
	@ShowPP			BIT = 0, -- PP
	@ShowCC			BIT = 0, -- Card club
	@ShowSG			BIT = 0, -- Spadegaming
	@ShowVRG		BIT = 0, -- Virtual Games
	@ShowTG			BIT = 0, -- Table Games
	@ShowI4D		BIT = 0, -- Indo 4D
	@ShowSXG		BIT = 0, -- Sexy Gaming
	@ShowSBC		BIT = 0, -- Saba club
	@MoveBetsDay	SMALLDATETIME,
	@drawfilter		SMALLINT = 1,
	@AgentList		VARCHAR(MAX),
	@BaseCurrency	VARCHAR(3) = '',
	@DefaultBaseCurrency	VARCHAR(3) = '',
	@CheckPromotionPrize	BIT = 0
AS

/*
	Created: Henry
	Date: 2012-01-09
	Task : Winloss Report for Licensee Agent Level
	DB: DBEXT.bodb02

	Revisions:
		- 20120214@Jim: change table ExchangeDaily by function Lrf_f_GetExchangeDaily  
		- 20120528@Henry: enhance performance
		- 20120725@Jim: add playercomm value
		- 20120814@Jim: add ShowLiveCasino + Virtual Sport
		- 20121004@Jim: replace @currency input param by @currencyID
		- 20121115@Henry: Only Sportsbook needs to exclude BA
		- 20121128@Henry: use new table LicenseeBATransaction_active to get bettrans BA tickets
		- 20130204@Jim: support RNG Casino and Bingo product
		- 20130514@Jim: Restrict permission of Licensee Users by currency
		- 20130809@Jim: offer Virtual Horse Racing
		- 20131007@Jim: offer Virtual Tennis
		- 20140305@Florent: support Keno
		- 20140620@Florent: offer 14 new bettypes and Sporting Solution (36 new bettypes)
		- 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
		- 20150123@Jim: support base on Currency GBP
		- 20150612@Jim: support MicroGaming
		- 20150624@Winnie: support licenseeWLBT
		- 20150709@Jim: fix bug #39374 
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
		- 20170320@Paul: Implement Cash Out [RedmineID :#71727]
		- 20170710@Harper: LRF - Integrate Bet Radar Virtual Sports [RedmineID: #78241]
		- 20170731@Harper: LRF - Integrate Lottery [RedmineID: #79997]
		- 20170814@Harper: One RNG - Offer New Tablet Games [RedmineID: #78424]
		- 20180129@Harper: Remove LC from product list [RedmineID: #85965]
		- 20180409@Joseph: Implement new sports for VS2: BasketBall - Virual Soccer World Cup [Redmine: #90881]
		- 20180418@Amanda: LAP - Update VB bet type range and integrate PP [RedmineID: #92318]
		- 20180420@Amanda: Include more cash out tickets [RedmineID: #93919]
		- 20180509@Joseph: Remove cheat currency name for special currencies [RedmineID: #94845]
		- 20180807@Amanda: Remove Racing, Bingo and Old(@IsOld) data [RedmineID: #99378]
		- 20181019@Amanda: Add new bet types for E-Sports 2.0 [RedmineID: #100721]
		- 20181210@Joseph: Integrate Happy 5 for NumberGame [RedmineID: #103698]
		- 20190304@Amanda: Integrate PP Promotion Prize [RedmineID: #109471]
		- 20190322@Amanda: Remove MGCLC & MGRnG [RedmineID: #107704]
		- 20190605@Amanda: Add Base currency param [RedmineID: #112531]
		- 20190708@Amanda: Add new product Card Club [RedmineID: #115449]
		- 20190910@Amanda: Add bet types that support Half Won/ Half Lose [RedmineID: #118300]
		- 20190923@Amanda: Change the way to handle Half Won/ Half Lose bet types [RedmineID: #119879]
		- 20191022@Amanda: Integrate NPH Promotion [RedmineID: #120333]
		- 20191121@Amanda: Integrate PP Tournament Prize and exclude PP Promotion, Tournament Prize from result [RedmineID: #123804]
		- 20190312@Amanda: Add new bet types Single Match Parlay (ID: 38) [RedmineID: #108298]
		- 20191212@Vickie: Integrate SpadeGaming [RedmineID: #124103]
		- 20200108@Vickie: Add new product Virtual Games [RedmineID: #124911]
		- 20200323@Vickie: Hotfix miss TurnoverVRGUSD [RedmineID: #130896]
		- 20200406@Hogan: Add new product Table Games [RedmineID: #131447]
		- 20200323@Vickie: Add new product Indo 4D [RedmineID: #130859]
		- 20200423@Hogan: Add new product Sexy Gaming [RedmineID: #132829]
		- 20200423@Vickie: Integrate Saba Club [RedmineID: #132702]
		- 20200508@Vickie: Add new bet types for E-Sports 2.0 [RedmineID: #132548]

	Param's Explanation:
		+ @CustID: SuperID
		+	@drawfilter: 'No Draw' filter is supportted (1:Normal 2:No Draw 3:No Draw for Turnover only)
		+ @excludeTest: remove currency UUS
		+ @MoveBetsDay: The day we move tickets to bettrans14
		+ @CheckPromotionPrize: = 1 if want to check whether have promotion prize ticket or not
		+ @AgentList: xml structure
						<ROOT>
						<Agent AgentId="12345" Currency="3"/>
						<Agent AgentId="12345" Currency="5"/>
						</ROOT>

	exec Lrf_Rpt_LicWinlossDetail_Ag 
	 @licenseeid=1,@userid=10,@currencyid=6,@fromdate='2016-07-14 00:00:00',@todate='2016-07-14 00:00:00',@isold=0,@drawfilter=1,@excludetest=1,@movebetsday='2016-07-11 00:00:00'
	 ,@showSB=1,showNG=1,@showBA=1,@showVS=1,@showCS=1,@showKN=1,@showAGC=1,@showVB=1
	 ,@ShowAB=1
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #SAgWinLoss
	(
		winlostdate			SMALLDATETIME,
		CustID				INT,
		Currency			INT,
		TurnoverSB			MONEY,
		TurnoverBA			MONEY,
		TurnoverNG			MONEY,
		TurnoverVS			MONEY,
		TurnoverCS 			MONEY,
		TurnoverKN			MONEY,
		TurnoverAGC			MONEY,
		TurnoverVB			MONEY,
		TurnoverAB			MONEY,
		TurnoverFW			MONEY,
		TurnoverCO			MONEY,
		TurnoverVS2			MONEY,
		TurnoverLT			MONEY,
		TurnoverPP			MONEY,
		TurnoverCC			MONEY,
		TurnoverSG			MONEY,
		TurnoverVRG			MONEY,
		TurnoverTG			MONEY,
		TurnoverI4D			MONEY,
		TurnoverSXG			MONEY,
		TurnoverSBC			MONEY,
		BTActualStake		MONEY,
		Winlost				MONEY,
		LicenseeWLSB		MONEY,
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
		LicenseeWLCC		MONEY,
		LicenseeWLSG		MONEY,
		LicenseeWLVRG		MONEY,
		LicenseeWLI4D		MONEY,
		LicenseeWLTG		MONEY,
		LicenseeWLSXG		MONEY,
		LicenseeWLSBC		MONEY,
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
		CashOutComm			MONEY
	)  

	DECLARE @TempAg				TABLE (custID INT, currency INT)
	DECLARE @ExchangeRate		TABLE (FromDate SMALLDATETIME, ToDate SMALLDATETIME, ExchangeId INT, Rate FLOAT, USD FLOAT, EUR FLOAT, GBP FLOAT, DefaultRate FLOAT)
	DECLARE @LicenseeName		VARCHAR(50)
	DECLARE @bettype			TABLE (bettype INT PRIMARY KEY, ProductCode VARCHAR(10))
	DECLARE @sporttype			TABLE (sporttype INT, ProductCode VARCHAR(10))
	DECLARE @ProductList		VARCHAR (500)
	DECLARE	@PromotionPrize		INT = 0

	SELECT	@LicenseeName = LicenseeName
	FROM bodb_Licensee.dbo.Licensees (NOLOCK)
	WHERE LicenseeID = @LicenseeID

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
	
	IF @ShowCC = 1 -- Card club
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'CC', 'CC')
	END

	IF @ShowSG = 1 -- Spadegaming
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'SG', 'SG')
	END

	IF @ShowVRG = 1 -- Virtual Games
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'VRG', 'VRG')
	END

	IF @ShowTG = 1 -- Table Games
	BEGIN 
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'TG', 'TG')
	END

	IF @ShowI4D = 1 -- Indo 4D
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'I4D', 'I4D')
	END

	IF @ShowSXG = 1 -- Sexy Gaming
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'SXG', 'SXG')
	END

	IF @ShowSBC = 1 -- Saba Club
	BEGIN 
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'SBC', 'SBC')
	END

	IF LEN(ISNULL(@ProductList, '')) > 0 
	BEGIN
		-- Insert Bettype
		INSERT INTO @bettype ( bettype, ProductCode )
		SELECT DISTINCT BetType, ProductPrefix
		FROM f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', @ProductList, @IsTest)

		IF @ShowCS = 1
			DELETE @bettype
			WHERE bettype = 72 AND ProductCode = 'CS'

		IF @showSB = 1
			DELETE @bettype
			WHERE ProductCode = 'SB'
			
		IF @showPP = 1
			DELETE @bettype
			WHERE ProductCode = 'PP' AND bettype IN (4300,4299)
		
		-- Insert Sport Type
		INSERT INTO @sporttype ( sporttype, ProductCode )
		SELECT DISTINCT sporttype, ProductCode
		FROM f_LicWinLoss_ProductSportType_Sel(@ProductList)
	END
	
	DECLARE @TempFromDate	SMALLDATETIME, 
			@TempToDate		SMALLDATETIME,
			@FDate			SMALLDATETIME,
			@TDate			SMALLDATETIME

	--to Deal With Parameter Sniffing
	SELECT @FDate = @FromDate, @TDate = @ToDate 

	IF @TDate > @MoveBetsDay
	BEGIN
		IF @FDate <= @MoveBetsDay 
			SET @TempFromDate =  DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @FDate

		DECLARE @HWHLCutDate SMALLDATETIME = '2019-10-01' -- half won/ half lose cut date

		IF @ShowBA = 1
		BEGIN
		INSERT INTO #SAgWinLoss
		SELECT
			b.winlostdate,
			b.recommend,
			tma.currency, 
			0 AS turnoverSB,
			SUM(stake
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE
						WHEN b.statusID = 111 THEN 0
						WHEN b.winlostdate >= @HWHLCutDate AND b.statusID IN (112, 113) AND b.modds IN (-0.25, 0.25) AND b.bettype NOT IN (29,38) THEN 0.5 -- exclude parlay, bet builder
						WHEN b.winlostdate < @HWHLCutDate AND (b.statusID = 112 OR b.statusID = 113) AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18,124,125,482,483,484,485) THEN 0.5
						ELSE 1 END
				ELSE 1 END
			) AS turnoverBA, 
			0 AS turnoverNG,
			0 AS turnoverVS,
			0 AS tunroverCS,
			0 AS tunroverKN,
			0 AS tunroverAGC,
			0 AS tunroverVB,
			0 AS tunroverAB,
			0 AS tunroverFW,
			0 AS tunroverCO,
			0 AS tunroverVS2,
			0 AS tunroverLT,
			0 AS tunroverPP,
			0 AS tunroverCC,
			0 AS tunroverSG,
			0 AS tunroverVRG,
			0 AS tunroverTG,
			0 AS tunroverI4D,
			0 AS tunroverSXG,
			0 AS tunroverSBC,
			0 AS BTActualStake,
			SUM(b.winlost - b.actual_stake) AS Winlost,
			0 AS LicenseeWLSB,
			0 AS LicenseeWLBA,
			0 AS LicenseeWLNG,
			0 AS LicenseeWLVS,
			0 AS LicenseeWLCS,
			0 AS LicenseeWLKN,
			0 AS LicenseeWLAGC,
			0 AS LicenseeWLVB,
			0 AS LicenseeWLAB,
			0 AS LicenseeWLFW,
			0 AS LicenseeWLCO,
			0 AS LicenseeWLVS2,
			0 AS LicenseeWLLT,
			0 AS LicenseeWLPP,
			0 AS LicenseeWLCC,
			0 AS LicenseeWLSG,
			0 AS LicenseeWLVRG,
			0 AS LicenseeWLTG,
			0 AS LicenseeWLI4D,
			0 AS LicenseeWLSXG,
			0 AS LicenseeWLSBC,
			- SUM(b.winlost - b.actual_stake + awinlost + comm) AS AmountDueToBA,
			SUM(comm) AS CommBA,
			CASE WHEN b.StatusID=111 THEN 0 ELSE SUM(playercomm) END  AS PlayerComm,
			COUNT(CASE WHEN @drawfilter = 2 AND b.statusID = 111 THEN NULL ELSE b.transid END) AS BetCount,
			0 AS licenseeWLBT,
			0 AS BetTradeComm,			
			SUM(CASE WHEN b.betdaqid = 0 THEN (b.winlost-b.actual_stake) ELSE 0 END) AS WLBetTicket,
			0 AS WLBoughtTicket,
			0 AS BuyBackAmtSB,
			0 AS BuyBackAmtBA,
			0 AS CashOutComm
		FROM 
			dbo.bettrans b WITH ( NOLOCK) 
			INNER JOIN @TempAg tma ON tma.CustID = b.recommend AND tma.currency = b.currency
			INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction_active BA WITH (NOLOCK) ON tma.custid = BA.recommend and b.transid = BA.transid 	 	
		WHERE b.winlostdate BETWEEN @TempFromDate AND @TDate   
			AND (b.bettype < 901 OR b.bettype > 904)
			AND (b.bettype < 911 OR b.bettype > 914)
			AND b.statusID IN (111, 112, 113) 
		GROUP BY
			b.winlostdate, tma.currency, b.recommend, b.statusID	
		END

		IF @ShowSB = 1
		BEGIN
			INSERT INTO #SAgWinLoss
			SELECT   
				b.winlostdate,  
				b.recommend,
				a.currency, 
				SUM(stake
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.winlostdate >= @HWHLCutDate AND b.statusID IN (112, 113) AND b.modds IN (-0.25, 0.25) AND b.bettype NOT IN (29,38) THEN 0.5 -- exclude parlay, bet builder
							WHEN b.winlostdate < @HWHLCutDate AND (b.statusID = 112 OR b.statusID = 113) AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18,124,125,482,483,484,485) THEN 0.5
							ELSE 1 END
					ELSE 1 END
				) AS turnoverSB, 
				0 AS turnoverBA,
				0 AS turnoverNG, 
				0 AS turnoverVS, 
				0 AS turnoverCS,
				0 AS tunroverKN,
				0 AS tunroverAGC,
				0 AS tunroverVB,
				0 AS tunroverAB,
				0 AS tunroverFW,
				0 AS tunroverCO,
				0 AS turnoverVS2, 
				0 AS tunroverLT,
				0 AS tunroverPP,
				0 AS tunroverCC,
				0 AS tunroverSG,
				0 AS tunroverVRG,
				0 AS tunroverTG,
				0 AS tunroverI4D,
				0 AS tunroverSXG,
				0 AS tunroverSBC,
				0 AS BTActualStake,
				SUM(b.winlost-b.actual_stake) AS Winlost,
				-SUM(b.winlost-b.actual_stake) AS LicenseeWLSB,
				0 AS LicenseeWLBA,
				0 AS LicenseeWLNG,
				0 AS LicenseeWLVS,
				0 AS LicenseeWLCS,
				0 AS LicenseeWLKN,
				0 AS LicenseeWLAGC,
				0 AS LicenseeWLVB,
				0 AS LicenseeWLAB,
				0 AS LicenseeWLFW,
				0 AS LicenseeWLCO,
				0 AS LicenseeWLVS2,
				0 AS LicenseeWLLT,
				0 AS LicenseeWLPP,
				0 AS LicenseeWLCC,
				0 AS LicenseeWLSG,
				0 AS LicenseeWLVRG,
				0 AS LicenseeWLTG,
				0 AS LicenseeWLI4D,
				0 AS LicenseeWLSXG,
				0 AS LicenseeWLSBC,
				0 AS AmountDueToBA,
				0 AS CommBA,
				SUM(b.playercomm) AS PlayerComm,
				COUNT(CASE WHEN @drawfilter = 2 AND b.statusID = 111 THEN NULL ELSE b.transid END) AS BetCount,
				0 AS licenseeWLBT,
				0 AS BetTradeComm,
				SUM(CASE WHEN b.betdaqid = 0 THEN b.winlost-b.actual_stake ELSE 0 END) AS WLBetTicket,
				0 AS WLBoughtTicket,
				0 AS BuyBackAmtSB,
				0 AS BuyBackAmtBA,
				0 AS CashOutComm
			FROM
				dbo.bettrans b WITH ( NOLOCK) 
				INNER JOIN @TempAg a ON b.recommend = a.custid AND a.currency = b.currency
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @TDate
				AND
				(
					b.bettype <= 30
					OR b.bettype BETWEEN 121 AND 999
					OR b.Bettype BETWEEN 1301 AND 1399 --new tennis's bettypes
					OR b.Bettype BETWEEN 9001 and 9399 -- E-Sports 2.0
					OR b.Bettype = 38				   -- Single Match Parlay
				) 
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
				AND b.statusID IN (111, 112, 113)
				AND b.tpositiontaking <> 0
			GROUP BY
				b.winlostdate,
				a.currency,
				b.recommend,
				b.statusID
		END
	
		IF @ShowBT = 1
		BEGIN
			INSERT INTO #SAgWinLoss
			SELECT
				b.winlostdate,
				b.recommend,
				a.currency, 
				0 AS turnoverSB, 
				0 AS turnoverBA,
				0 AS turnoverNG, 
				0 AS turnoverVS, 
				0 AS turnoverCS,
				0 AS tunroverKN,
				0 AS tunroverAGC,
				0 AS tunroverVB,
				0 AS tunroverAB,
				0 AS tunroverFW,
				0 AS tunroverCO,
				0 AS turnoverVS2,
				0 AS tunroverLT,
				0 AS tunroverPP,
				0 AS tunroverCC,
				0 AS tunroverSG,
				0 AS tunroverVRG,
				0 AS tunroverTG,
				0 AS tunroverI4D,
				0 AS tunroverSXG,
				0 AS tunroverSBC,
				SUM(CASE WHEN b.bettype = 902 THEN b.winlost ELSE 0 END) AS BTActualStake,
				SUM(CASE WHEN b.bettype = 903 THEN 0 ELSE b.winlost-b.actual_stake END) AS Winlost,
				0 AS LicenseeWLSB,
				0 AS LicenseeWLBA,
				0 AS LicenseeWLNG,
				0 AS LicenseeWLVS,
				0 AS LicenseeWLCS,
				0 AS LicenseeWLKN,
				0 AS LicenseeWLAGC,
				0 AS LicenseeWLVB,
				0 AS LicenseeWLAB,
				0 AS LicenseeWLFW,
				0 AS LicenseeWLCO,
				0 AS LicenseeWLVS2,
				0 AS LicenseeWLLT,
				0 AS LicenseeWLPP,
				0 AS LicenseeWLCC,
				0 AS LicenseeWLSG,
				0 AS LicenseeWLVRG,
				0 AS LicenseeWLTG,
				0 AS LicenseeWLI4D,
				0 AS LicenseeWLSXG,
				0 AS LicenseeWLSBC,
				0 AS AmountDueToBA,
				0 AS CommBA,
				0 AS PlayerComm,
				COUNT(CASE WHEN b.bettype = 903 THEN NULL ELSE b.transid END)
					* CASE WHEN @drawfilter = 2 THEN CASE WHEN b.statusID = 111 THEN 0 ELSE 1 END ELSE 1 END BetCount,
				- SUM(CASE WHEN b.bettype IN (901, 902) THEN b.winlost-b.actual_stake ELSE 0 END) AS licenseeWLBT,
				SUM(CASE WHEN b.bettype = 903 THEN b.awinlost ELSE 0 END) AS BetTradeComm,
				0 WLBetTicket,
				SUM(CASE WHEN b.bettype = 902 THEN b.winlost-b.actual_stake ELSE 0 END) AS WLBoughtTicket,
				SUM(CASE WHEN b.bettype = 902 AND transid2 = 0 THEN b.actual_stake ELSE 0 END) AS BuyBackAmtSB,
				SUM(CASE WHEN b.bettype = 902 AND transid2 = 1 THEN b.actual_stake ELSE 0 END) AS BuyBackAmtBA,
				0 AS CashOutComm
			FROM 
				dbo.bettrans b WITH ( NOLOCK) 
				INNER JOIN @TempAg a ON b.recommend = a.custid AND a.currency = b.currency
			WHERE 
				b.winlostdate BETWEEN @TempFromDate AND @TDate
				AND b.bettype IN (901, 902, 903)
				AND b.statusID IN (111, 112, 113)
			GROUP BY
				b.winlostdate,
				a.currency,
				b.recommend,
				b.statusID
		END

		IF 1 IN (@ShowNG, @ShowVS, @ShowCS, @ShowKN, @ShowAGC, @ShowVB, @ShowAB, @ShowFW, @ShowVS2, @ShowLT, @ShowPP, @ShowCC, @ShowSG, @ShowVRG, @ShowTG, @ShowI4D, @ShowSXG, @ShowSBC)
		BEGIN
			INSERT INTO #SAgWinLoss
			SELECT
				b.winlostdate,
				b.recommend,
				a.currency, 
				0 AS turnoverSB,
				0 AS turnoverBA,
				SUM(CASE WHEN (b.bettype BETWEEN 81 AND 120) OR (b.bettype BETWEEN 8101 AND 8120) THEN
						stake * (CASE WHEN @drawfilter IN (2,3) AND b.statusID = 111 THEN 0 ELSE 1 END)
					ELSE 0 END
				) AS turnoverNG,
				SUM(CASE WHEN b.bettype BETWEEN 1201 AND 1299 THEN
					stake * (CASE WHEN @drawfilter IN (2,3) AND b.statusID = 111 THEN 0 ELSE 1 END)
					ELSE 0 END
				) AS turnoverVS, 
				SUM(CASE WHEN b.bettype = 71 OR b.bettype BETWEEN 2101 AND 2399 OR b.bettype BETWEEN 2901 AND 2999 THEN
					stake * (CASE WHEN @drawfilter IN (2,3) AND b.statusID = 111 THEN 0 ELSE 1 END)
					ELSE 0 END
				) AS turnoverCS,
				SUM(CASE WHEN b.bettype BETWEEN 1501 AND 1599 THEN
					stake * (CASE WHEN @drawfilter IN (2,3) AND b.statusID = 111 THEN 0 ELSE 1 END)
					ELSE 0 END
				) AS turnoverKN,
				SUM(CASE WHEN b.bettype BETWEEN 1800 AND 1899 THEN
					stake * (CASE WHEN @drawfilter IN (2,3) AND b.statusID = 111 THEN 0 ELSE 1 END)
					ELSE 0 END
				) AS turnoverAGC,
				SUM(CASE WHEN b.bettype BETWEEN 4001 AND 4100 THEN
					stake * (CASE WHEN @drawfilter IN (2,3) AND b.statusID = 111 THEN 0 ELSE 1 END)
					ELSE 0 END
				) AS turnoverVB,
				SUM(CASE WHEN b.bettype BETWEEN 2401 AND 2499 THEN
					stake * (CASE WHEN @drawfilter IN (2,3) AND b.statusID = 111 THEN 0 ELSE 1 END)
					ELSE 0 END
				) AS turnoverAB,
				SUM(CASE WHEN b.bettype BETWEEN 1011 AND 1020 THEN
					stake * (CASE WHEN @drawfilter IN (2,3) AND b.statusID = 111 THEN 0 ELSE 1 END)
					ELSE 0 END
				) AS turnoverFW,
				0 AS turnoverCO,
				SUM(CASE WHEN b.bettype BETWEEN 2701 AND 2829 THEN
					stake * (CASE WHEN @drawfilter IN (2,3) AND b.statusID = 111 THEN 0 ELSE 1 END)
					ELSE 0 END
				) AS turnoverVS2,
				SUM(CASE WHEN b.bettype BETWEEN 1021 AND 1049 THEN
					stake * (CASE WHEN @drawfilter IN (2,3) AND b.statusID = 111 THEN 0 ELSE 1 END)
					ELSE 0 END
				) AS turnoverLT,
				SUM(CASE WHEN b.bettype BETWEEN 4101 AND 4300 THEN
					stake * (CASE WHEN @drawfilter IN (2,3) AND b.statusID = 111 THEN 0 ELSE 1 END)
					ELSE 0 END
				) AS turnoverPP,
				SUM(CASE WHEN b.bettype BETWEEN 1901 AND 1999 THEN
					stake * (CASE WHEN @drawfilter IN (2,3) AND b.statusID = 111 THEN 0 ELSE 1 END)
					ELSE 0 END
				) AS turnoverCC,
				SUM(CASE WHEN b.bettype BETWEEN 4301 AND 4600 THEN
					stake * (CASE WHEN @drawfilter IN (2,3) AND b.statusID = 111 THEN 0 ELSE 1 END)
					ELSE 0 END
				) AS turnoverSG,
				SUM(CASE WHEN b.bettype BETWEEN 4601 AND 4900 THEN
					stake * (CASE WHEN @drawfilter IN (2,3) AND b.statusID = 111 THEN 0 ELSE 1 END)
					ELSE 0 END
				) AS turnoverVRG,
				SUM(CASE WHEN b.bettype BETWEEN 4901 AND 5000 THEN
					stake * (CASE WHEN @drawfilter IN (2,3) AND b.statusID = 111 THEN 0 ELSE 1 END)
						
					ELSE 0 END
				) AS turnoverTG,
				SUM(CASE WHEN b.bettype BETWEEN 5001 AND 5099 THEN
					stake * (CASE WHEN @drawfilter IN (2,3) AND b.statusID = 111 THEN 0 ELSE 1 END)
					ELSE 0 END
				) AS TurnoverI4D,
				SUM(CASE WHEN b.bettype BETWEEN 3101 AND 3199 THEN
					stake * (CASE WHEN @drawfilter IN (2,3) AND b.statusID = 111 THEN 0 ELSE 1 END)
					ELSE 0 END
				) AS TurnoverSXG,
				SUM(CASE WHEN b.bettype BETWEEN 1611 AND 1699 THEN
					stake * (CASE WHEN @drawfilter IN (2,3) AND b.statusID = 111 THEN 0 ELSE 1 END)
						
					ELSE 0 END
				) AS turnoverSBC,
				0 AS BTActualStake,
				SUM(b.winlost - b.actual_stake) AS Winlost,
				0 AS LicenseeWLSB,
				0 AS LicenseeWLBA,
				-SUM(CASE WHEN (b.bettype BETWEEN 81 AND 120) OR (b.bettype BETWEEN 8101 AND 8120)
					THEN b.winlost-b.actual_stake ELSE 0 END) AS LicenseeWLNG,
				-SUM(CASE WHEN b.bettype BETWEEN 1201 AND 1299
					THEN b.winlost-b.actual_stake ELSE 0 END) AS LicenseeWLVS,
				-SUM(CASE WHEN b.bettype =71 OR b.bettype BETWEEN 2101 AND 2399 OR b.bettype BETWEEN 2901 AND 2999
					THEN b.winlost-b.actual_stake ELSE 0 END) AS LicenseeWLCS,
				-SUM(CASE WHEN b.bettype BETWEEN 1501 AND 1599
					THEN b.winlost-b.actual_stake ELSE 0 END) AS LicenseeWLKN,
				-SUM(CASE WHEN b.bettype BETWEEN 1800 AND 1899
					THEN b.winlost-b.actual_stake ELSE 0 END) AS LicenseeWLAGC,
				-SUM(CASE WHEN b.bettype BETWEEN 4001 AND 4100
					THEN b.winlost-b.actual_stake ELSE 0 END) AS LicenseeWLVB,
				-SUM(CASE WHEN b.bettype BETWEEN 2401 AND 2499
					THEN b.winlost-b.actual_stake ELSE 0 END) AS LicenseeWLAB,
				-SUM(CASE WHEN b.bettype = 219
				THEN b.winlost-b.actual_stake ELSE 0 END) AS LicenseeWLFW,
				0 AS LicenseeWLCO,
				-SUM(CASE WHEN b.bettype BETWEEN 2701 AND 2829
					THEN b.winlost-b.actual_stake ELSE 0 END) AS LicenseeWLVS2,	
				-SUM(CASE WHEN b.bettype BETWEEN 1021 AND 1049
					THEN b.winlost-b.actual_stake ELSE 0 END) AS LicenseeWLLT,
				-SUM(CASE WHEN b.bettype BETWEEN 4101 AND 4300
					THEN b.winlost-b.actual_stake ELSE 0 END) AS LicenseeWLPP,	
				-SUM(CASE WHEN b.bettype BETWEEN 1901 AND 1999
					THEN b.winlost-b.actual_stake ELSE 0 END) AS LicenseeWLCC,
				-SUM(CASE WHEN b.bettype BETWEEN 4301 AND 4600
					THEN b.winlost-b.actual_stake ELSE 0 END) AS LicenseeWLSG,
				-SUM(CASE WHEN b.bettype BETWEEN 4601 AND 4900
					THEN b.winlost-b.actual_stake ELSE 0 END) AS LicenseeWLVRG,
				-SUM(CASE WHEN b.bettype BETWEEN 4901 AND 5000
					THEN b.winlost-b.actual_stake ELSE 0 END) AS LicenseeWLTG,
				-SUM(CASE WHEN b.bettype BETWEEN 5001 AND 5099
					THEN b.winlost-b.actual_stake ELSE 0 END) AS LicenseeWLI4D,
				-SUM(CASE WHEN b.bettype BETWEEN 3101 AND 3199
					THEN b.winlost-b.actual_stake ELSE 0 END) AS LicenseeWLSXG,
				-SUM(CASE WHEN b.bettype BETWEEN 1611 AND 1699
					THEN b.winlost-b.actual_stake ELSE 0 END) AS LicenseeWLSBC,
				0 AS AmountDueToBA,
				0 AS CommBA,
				SUM(b.playercomm) AS PlayerComm,
				COUNT(CASE WHEN @drawfilter = 2 AND b.statusID = 111 THEN NULL ELSE b.transid END) AS BetCount,
				0 AS licenseeWLBT,
				0 AS BetTradeComm,
				0 AS WLBetTicket,
				0 AS WLBoughtTicket,
				0 AS BuyBackAmtSB,
				0 AS BuyBackAmtBA,
				0 AS CashOutComm
			FROM 
				dbo.bettrans b WITH (NOLOCK)
				INNER JOIN @TempAg a ON b.recommend = a.custid AND b.currency = a.currency
				INNER JOIN @bettype bt ON b.bettype = bt.bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @TDate AND
				b.statusID IN (111, 112, 113)
			GROUP BY
				b.winlostdate,
				a.currency,
				b.recommend,
				b.statusID
		END

		IF @ShowCO = 1
		BEGIN
			INSERT INTO #SAgWinLoss
			SELECT   
				b.winlostdate,  
				b.recommend,
				a.currency, 
				0 AS turnoverSB, 
				0 AS turnoverBA,
				0 AS turnoverNG,
				0 AS turnoverVS, 
				0 AS turnoverCS,
				0 AS tunroverKN,
				0 AS tunroverAGC,
				0 AS tunroverVB,
				0 AS tunroverAB,
				0 AS tunroverFW,
				0 AS tunroverCO,
				0 AS turnoverVS2,
				0 AS tunroverLT,
				0 AS tunroverPP,
				0 AS tunroverCC,
				0 AS tunroverSG,
				0 AS tunroverVRG,
				0 AS tunroverTG,
				0 AS tunroverI4D,
				0 AS tunroverSXG,
				0 AS tunroverSBC,
				0 AS BTActualStake,
				SUM(CASE WHEN b.bettype = 913 THEN 0 ELSE b.winlost - b.actual_stake END) AS Winlost,
				0 AS LicenseeWLSB,
				0 AS LicenseeWLBA,
				0 AS LicenseeWLNG,
				0 AS LicenseeWLVS,
				0 AS LicenseeWLCS,
				0 AS LicenseeWLKN,
				0 AS LicenseeWLAGC,
				0 AS LicenseeWLVB,
				0 AS LicenseeWLAB,
				0 AS LicenseeWLFW,
				- SUM(CASE WHEN b.bettype = 913 THEN 0 ELSE b.winlost - b.actual_stake END) AS LicenseeWLCO,
				0 AS LicenseeWLVS2,
				0 AS LicenseeWLLT,
				0 AS LicenseeWLPP,
				0 AS LicenseeWLCC,
				0 AS LicenseeWLSG,
				0 AS LicenseeWLVRG,
				0 AS LicenseeWLTG,
				0 AS LicenseeWLI4D,
				0 AS LicenseeWLSXG,
				0 AS LicenseeWLSBC,
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
				SUM(CASE WHEN b.bettype = 913 THEN b.awinlost ELSE 0 END) AS CashOutComm
			FROM 
				dbo.bettrans b WITH ( NOLOCK) 
				INNER JOIN @TempAg a ON b.recommend = a.custid AND a.currency = b.currency
			WHERE 
				b.winlostdate BETWEEN @TempFromDate AND @TDate
				AND b.bettype IN (911, 912, 913)
				AND b.statusID IN (111, 112, 113)
			GROUP BY
				b.winlostdate, a.currency, b.recommend, b.statusID
		END

		-- check promotion prize - PP promotion prize and NPH Promotion prize --
		IF @CheckPromotionPrize = 1 AND EXISTS (
			SELECT 1
			FROM dbo.bettrans b WITH (NOLOCK)
			INNER JOIN @TempAg a ON b.recommend = a.custid AND b.currency = a.currency
			WHERE b.winlostdate BETWEEN @TempFromDate AND @TDate AND b.bettype IN (4300, 17000, 4299) AND b.statusID = 112)
		BEGIN
			SET @PromotionPrize = 1
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
				b.winlostdate,
				b.recommend,
				b.currency,
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
				0 AS turnoverVS,
				0 AS turnoverCS,
				0 AS turnoverKN,
				0 AS turnoverAGC,
				0 AS turnoverVB,
				0 AS turnoverAB,
				0 AS turnoverFW,
				0 AS turnoverCO,
				0 AS turnoverVS2,
				0 AS turnoverLT,
				0 AS turnoverPP,
				0 AS turnoverCC,
				0 AS turnoverSG,
				0 AS turnoverVRG,
				0 AS turnoverTG,
				0 AS turnoverI4D,
				0 AS turnoverSXG,
				0 AS turnoverSBC,
				0 AS BTActualStake,
				SUM(b.winlost),
				0 AS LicenseeWLSB,
				0 AS LicenseeWLBA,
				0 AS LicenseeWLNG,
				0 AS LicenseeWLVS,
				0 AS LicenseeWLCS,
				0 AS LicenseeWLKN,
				0 AS LicenseeWLAGC,
				0 AS LicenseeWLVB,
				0 AS LicenseeWLAB,
				0 AS LicenseeWLFW,
				0 AS LicenseeWLCO,
				0 AS LicenseeWLVS2,
				0 AS LicenseeWLLT,
				0 AS LicenseeWLPP,
				0 AS LicenseeWLCC,
				0 AS LicenseeWLSG,
				0 AS LicenseeWLVRG,
				0 AS LicenseeWLTG,
				0 AS LicenseeWLI4D,
				0 AS LicenseeWLSXG,
				0 AS LicenseeWLSBC,
				-SUM(b.winlost+b.awinlost+b.comm) AS AmountDueToBA,
				SUM(comm) AS CommBA,
				CASE WHEN b.StatusID IN (112,113) THEN SUM (playercomm) ELSE 0 END  AS PlayerComm,
				SUM(b.betcount)	* CASE WHEN @drawfilter = 2 AND b.statusID = 111 THEN 0 ELSE 1 END AS BetCount,
				0 AS licenseeWLBT,
				0 AS BetTradeComm,
				SUM(CASE WHEN bt.CustId IS NOT NULL THEN b.winlost ELSE 0 END) AS WLBetTicket,
				0 AS WLBoughtTicket,
				0 AS BuyBackAmtSB,
				0 AS BuyBackAmtBA,
				0 AS CashOutComm
			FROM
				bodb_licenseereport.dbo.rptLicWinloss2 b WITH ( NOLOCK )  
				INNER JOIN @TempAg a ON b.recommend = a.custID AND b.Currency = a.currency
				LEFT JOIN f_GetBetTradeCustList(@LicenseeName) bt ON b.custid = bt.Custid AND b.Currency = bt.currency
			WHERE  
				b.Winlostdate BETWEEN @FDate AND @TempToDate  
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
				AND b.roleid = 1   
				AND b.statusID <> 101 --exclude REJECT bets
				AND ISNULL(b.isBA, 0) = 1
			GROUP BY b.winlostdate, b.currency, b.recommend, b.statusID
		END
	
		--exclude BA tickets
		IF 1 IN (@showSB, @ShowNG, @ShowVS, @ShowCS, @ShowKN, @ShowAGC, @ShowVB, @ShowAB, @ShowFW, @ShowVS2, @ShowLT, @ShowPP, @ShowCC, @ShowSG, @ShowVRG, @ShowTG, @ShowI4D, @ShowSXG, @ShowSBC)
		BEGIN
			INSERT INTO #SAgWinLoss  
			SELECT 
				b.winlostdate,
				b.recommend,
				b.currency,
				SUM(CASE WHEN b.sporttype = 0 THEN
					b.turnover
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
						ELSE 1 END
					ELSE 0 END) AS turnoverSB,
				0 AS turnoverBA,
				SUM(CASE WHEN b.sporttype IN (161, 164) THEN
					b.turnover
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
						ELSE 1 END
					ELSE 0 END) AS turnoverNG,
				SUM(CASE WHEN b.sporttype = 180 THEN
					b.turnover
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
						ELSE 1 END
					ELSE 0 END) AS turnoverVS,
				SUM(CASE WHEN b.sporttype IN (251, 208, 209, 210) THEN
					b.turnover
					*
						CASE WHEN @drawfilter IN (2,3) THEN
							CASE WHEN b.statusID = 111  THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
						ELSE 1 END
				ELSE 0 END) AS turnoverCS,
				SUM(CASE WHEN b.sporttype = 202 THEN 
					b.turnover
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
						ELSE 1 END
					ELSE 0 END) AS turnoverKN,
				SUM(CASE WHEN b.sporttype = 250 THEN 
					b.turnover
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
						ELSE 1 END
					ELSE 0 END) AS turnoverAGC,
				SUM(CASE WHEN b.sporttype = 212 THEN 
					b.turnover
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
						ELSE 1 END
					ELSE 0 END) AS turnoverVB,
					SUM(CASE WHEN b.sporttype = 211 THEN 
					b.turnover
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
						ELSE 1 END
					ELSE 0 END) AS turnoverAB,
					SUM(CASE WHEN b.sporttype = 219 THEN 
					b.turnover
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
						ELSE 1 END
					ELSE 0 END) AS turnoverFW,
				0 AS turnoverCO,
				SUM(CASE WHEN b.sporttype IN (190,193)  THEN
					b.turnover
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
						ELSE 1 END
					ELSE 0 END) AS turnoverVS2,	
				SUM(CASE WHEN b.sporttype = 220 THEN
					b.turnover
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
						ELSE 1 END
					ELSE 0 END) AS turnoverLT,
				SUM(CASE WHEN b.sporttype = 248 THEN
					b.turnover
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
						ELSE 1 END
					ELSE 0 END) AS turnoverPP,
				SUM(CASE WHEN b.sporttype = 165 THEN
					b.turnover
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
						ELSE 1 END
					ELSE 0 END) AS turnoverCC,
				SUM(CASE WHEN b.sporttype = 247 THEN
					b.turnover
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
						ELSE 1 END
					ELSE 0 END) AS turnoverSG,
				SUM(CASE WHEN b.sporttype = 245 THEN
					b.turnover
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
						ELSE 1 END
					ELSE 0 END) AS turnoverVRG,
				SUM(CASE WHEN b.sporttype = 222 THEN
					b.turnover
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
						ELSE 1 END
					ELSE 0 END) AS turnoverTG,
				SUM(CASE WHEN b.sporttype = 223 THEN
					b.turnover
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
						ELSE 1 END
					ELSE 0 END) AS turnoverI4D,
				SUM(CASE WHEN b.sporttype = 243 THEN
					b.turnover
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
						ELSE 1 END
					ELSE 0 END) AS turnoverSXG,
				SUM(CASE WHEN b.sporttype = 200 THEN
					b.turnover
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
						ELSE 1 END
					ELSE 0 END) AS turnoverSBC,
				0 AS BTActualStake,
				SUM(b.winlost),
				-SUM(CASE WHEN b.sporttype =   0 THEN b.winlost ELSE 0 END) AS LicenseeWLSB,
				0 AS LicenseeWLBA,
				-SUM(CASE WHEN b.sporttype IN (161, 164) THEN b.winlost ELSE 0 END) AS LicenseeWLNG,
				-SUM(CASE WHEN b.sporttype = 180 THEN b.winlost ELSE 0 END) AS LicenseeWLVS,
				-SUM(CASE WHEN b.sporttype IN (251, 208, 209, 210) THEN b.winlost ELSE 0 END) AS LicenseeWLCS,
				-SUM(CASE WHEN b.sporttype = 202 THEN b.winlost ELSE 0 END) AS LicenseeWLKN,
				-SUM(CASE WHEN b.sporttype = 250 THEN b.winlost ELSE 0 END) AS LicenseeWLAGC,
				-SUM(CASE WHEN b.sporttype = 212 THEN b.winlost ELSE 0 END) AS LicenseeWLVB,
				-SUM(CASE WHEN b.sporttype = 211 THEN b.winlost ELSE 0 END) AS LicenseeWLAB,
				-SUM(CASE WHEN b.sporttype = 219 THEN b.winlost ELSE 0 END) AS LicenseeWLFW,
				0 AS LicenseeWLCO,
				-SUM(CASE WHEN b.sporttype IN (190,193) THEN b.winlost ELSE 0 END) AS LicenseeWLVS2,
				-SUM(CASE WHEN b.sporttype = 220 THEN b.winlost ELSE 0 END) AS LicenseeWLLT,
				-SUM(CASE WHEN b.sporttype = 248 THEN b.winlost ELSE 0 END) AS LicenseeWLPP,
				-SUM(CASE WHEN b.sporttype = 165 THEN b.winlost ELSE 0 END) AS LicenseeWLCC,
				-SUM(CASE WHEN b.sporttype = 247 THEN b.winlost ELSE 0 END) AS LicenseeWLSG,
				-SUM(CASE WHEN b.sporttype = 245 THEN b.winlost ELSE 0 END) AS LicenseeWLVRG,
				-SUM(CASE WHEN b.sporttype = 222 THEN b.winlost ELSE 0 END) AS LicenseeWLTG,
				-SUM(CASE WHEN b.sporttype = 223 THEN b.winlost ELSE 0 END) AS LicenseeWLI4D,
				-SUM(CASE WHEN b.sporttype = 243 THEN b.winlost ELSE 0 END) AS LicenseeWLSXG,
				-SUM(CASE WHEN b.sporttype = 200 THEN b.winlost ELSE 0 END) AS LicenseeWLSBC,
				0 AS AmountDueToBA,
				0 AS CommBA,
				SUM(CASE WHEN b.StatusID IN (112,113) THEN playercomm ELSE 0 END) AS PlayerComm,
				SUM(b.betcount) * CASE WHEN @drawfilter = 2 AND b.statusID = 111 THEN 0 ELSE 1 END AS BetCount,
				0 AS licenseeWLBT,
				0 AS BetTradeComm,	
				SUM(CASE WHEN (bt.CustId IS NOT NULL) AND t.sporttype = 0 THEN b.winlost ELSE 0 END) AS WLBetTicket,
				0 AS WLBoughtTicket,
				0 AS BuyBackAmtSB,
				0 AS BuyBackAmtBA,
				0 AS CashOutComm
			FROM 
				bodb_licenseereport.dbo.rptLicWinloss2 b WITH (NOLOCK)  
				INNER JOIN @TempAg a    ON b.recommend = a.custID AND b.Currency = a.currency
				INNER JOIN @sporttype t ON b.sporttype = t.sporttype
				LEFT JOIN f_GetBetTradeCustList(@LicenseeName) bt ON b.custid = bt.Custid AND b.Currency = bt.currency
			WHERE  
				b.Winlostdate BETWEEN @FDate AND @TempToDate  
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
				AND b.bettype NOT IN (4300, 4299) -- PP Promotion Prize, Tournamemt Prize
				AND b.roleid = 1   
				AND b.statusID <> 101 --exclude REJECT bets
				AND ISNULL(b.isBA, 0) = 0
			GROUP BY b.winlostdate, b.currency, b.recommend, b.statusID
		END

		IF @ShowBT = 1
		BEGIN
			INSERT INTO #SAgWinLoss
			SELECT
				b.winlostdate,
				b.recommend,
				b.currency,
				0 AS turnoverSB, 
				0 AS turnoverBA,
				0 AS turnoverNG,
				0 AS turnoverVS, 
				0 AS turnoverCS,
				0 AS tunroverKN,
				0 AS turnoverAGC,
				0 AS turnoverVB,
				0 AS turnoverAB,
				0 AS turnoverFW,
				0 AS turnoverCO,
				0 AS turnoverVS2,
				0 AS turnoverLT,
				0 AS turnoverPP,
				0 AS turnoverCC,
				0 AS turnoverSG,
				0 AS turnoverVRG,
				0 AS turnoverTG,
				0 AS turnoverI4D,
				0 AS turnoverSXG,
				0 AS turnoverSBC,
				SUM(CASE WHEN b.bettype = 902 THEN b.winlost + BuyBackAmt + BABuyBackAmt ELSE 0 END) AS BTActualStake,
				SUM(CASE WHEN b.bettype = 903 THEN 0 ELSE b.winlost END) AS Winlost,  
				0 AS LicenseeWLSB,
				0 AS LicenseeWLBA,
				0 AS LicenseeWLNG,
				0 AS LicenseeWLVS,
				0 AS LicenseeWLCS,
				0 AS LicenseeWLKN,
				0 AS LicenseeWLAGC,
				0 AS LicenseeWLVB,
				0 AS LicenseeWLAB,
				0 AS LicenseeWLFW,
				0 AS LicenseeWLCO,
				0 AS LicenseeWLVS2,
				0 AS LicenseeWLLT,
				0 AS LicenseeWLPP,
				0 AS LicenseeWLCC,
				0 AS LicenseeWLSG,
				0 AS LicenseeWLTG,
				0 AS LicenseeWLVRG,
				0 AS LicenseeWLI4D,
				0 AS LicenseeWLSXG,
				0 AS LicenseeWLSBC,
				0 AS AmountDueToBA,
				0 AS CommBA,
				0 AS PlayerComm,
				SUM(CASE WHEN b.bettype = 903 THEN NULL	ELSE b.BetCount END)
					* CASE WHEN @drawfilter = 2 AND b.statusID = 111 THEN 0 ELSE 1 END AS BetCount,
				-SUM(CASE WHEN b.bettype IN (901, 902) THEN (b.winlost) ELSE 0 END) AS licenseeWLBT,
				SUM(CASE WHEN b.bettype = 903 THEN b.awinlost ELSE 0 END) AS BetTradeComm,
				0 WLBetTicket,
				SUM(CASE WHEN b.bettype = 902 THEN b.winlost ELSE 0 END) AS WLBoughtTicket,
				SUM(CASE WHEN b.bettype = 902 THEN BuyBackAmt ELSE 0 END) AS BuyBackAmtSB,
				SUM(CASE WHEN b.bettype = 902 THEN BABuyBackAmt ELSE 0 END) AS BuyBackAmtBA,
				0 AS CashOutComm
			FROM 
				bodb_licenseereport.dbo.rptLicWinloss2 b WITH ( NOLOCK )
				INNER JOIN @TempAg ag ON b.recommend = ag.custID AND ag.currency = b.Currency
			WHERE 
				b.Winlostdate BETWEEN @FDate AND @TempToDate
				AND b.bettype IN (901, 902, 903)	
				AND b.statusID IN (111, 112, 113)
				AND b.roleid = 1 
				GROUP BY b.winlostdate, b.currency, b.recommend, b.statusID
		END

		IF @ShowCO = 1
		BEGIN
			INSERT INTO #SAgWinLoss
			SELECT   
				b.winlostdate,  
				b.recommend,
				b.currency,
				0 AS turnoverSB, 
				0 AS turnoverBA,
				0 AS turnoverNG, 
				0 AS turnoverVS, 
				0 AS turnoverCS,
				0 AS tunroverKN,
				0 AS turnoverAGC,
				0 AS turnoverVB,
				0 AS turnoverAB,
				0 AS turnoverFW,
				0 AS turnoverCO,
				0 AS turnoverVS2,
				0 AS turnoverLT,
				0 AS turnoverPP,
				0 AS turnoverCC,
				0 AS turnoverSG,
				0 AS turnoverVRG,
				0 AS turnoverTG,
				0 AS turnoverI4D,
				0 AS turnoverSXG,
				0 AS turnoverSBC,
				0 AS BTActualStake,
				SUM(CASE WHEN b.bettype = 913 THEN 0 ELSE b.winlost END) AS Winlost,  
				0 AS LicenseeWLSB,
				0 AS LicenseeWLBA,
				0 AS LicenseeWLNG,
				0 AS LicenseeWLVS,
				0 AS LicenseeWLCS,
				0 AS LicenseeWLKN,
				0 AS LicenseeWLAGC,
				0 AS LicenseeWLVB,
				0 AS LicenseeWLAB,
				0 AS LicenseeWLFW,
				- SUM(CASE WHEN b.bettype = 913 THEN 0 ELSE b.winlost END) AS LicenseeWLCO,
				0 AS LicenseeWLVS2,
				0 AS LicenseeWLLT,
				0 AS LicenseeWLPP,
				0 AS LicenseeWLCC,
				0 AS LicenseeWLSG,
				0 AS LicenseeWLVRG,
				0 AS LicenseeWLTG,
				0 AS LicenseeWLI4D,
				0 AS LicenseeWLSXG,
				0 AS LicenseeWLSBC,
				0 AS AmountDueToBA,
				0 AS CommBA,
				0 AS PlayerComm,
				SUM(CASE WHEN b.bettype = 913 THEN 0 ELSE b.BetCount END) AS BetCount,
				0 AS licenseeWLBT,
				0 AS BetTradeComm,
				0 WLBetTicket,
				0 AS WLBoughtTicket,
				0 AS BuyBackAmtSB,
				0 AS BuyBackAmtBA,
				SUM(CASE WHEN b.bettype = 913 THEN b.awinlost ELSE 0 END) AS CashOutComm
			FROM 
				bodb_licenseereport.dbo.rptLicWinloss2 b WITH ( NOLOCK )  
				INNER JOIN @TempAg ag ON b.recommend = ag.custID AND ag.currency = b.Currency
			WHERE 
				b.Winlostdate BETWEEN @FDate AND @TempToDate  
				AND b.bettype IN (911, 912, 913)
				AND b.statusID IN (111, 112, 113)
				AND b.roleid = 1 
				GROUP BY b.winlostdate, b.currency, b.recommend, b.statusID
		END
		
		-- check promotion prize - PP promotion prize and NPH Promotion prize --
		IF @CheckPromotionPrize = 1 AND @PromotionPrize = 0 AND EXISTS (
			SELECT TOP(1) 1
			FROM bodb_licenseereport.dbo.rptLicWinloss2 b WITH ( NOLOCK )
			INNER JOIN @TempAg ag ON b.recommend = ag.custID AND ag.currency = b.Currency
			WHERE b.Winlostdate BETWEEN @FDate AND @TempToDate AND b.bettype IN (4300, 17000, 4299) AND b.statusID = 112 AND b.roleid = 2)
		BEGIN
			SET @PromotionPrize = 1
		END
	 END

	CREATE NONCLUSTERED INDEX IDX_Index_SA ON #SAgWinLoss(Currency)

	IF EXISTS (SELECT TOP (1) 1 FROM #SAgWinLoss)
	BEGIN
		INSERT INTO @ExchangeRate(FromDate, ToDate, ExchangeID, USD, EUR, GBP, Rate, DefaultRate)
		SELECT FromDate, ToDate, ExchangeID, USD, EUR, GBP, Rate, DefaultRate
		FROM dbo.Lrf_f_GetExchangeRate(@FDate, @TDate, @BaseCurrency, @DefaultBaseCurrency) e
		WHERE EXISTS (SELECT 1 FROM #SAgWinLoss s WHERE e.ExchangeID = s.Currency)
	END
 
	SELECT
		c.username,
		w.custid, 
		w.currency,
		CAST(SUM(TurnoverSB		*e.Rate)	AS MONEY)		AS TurnoverSB,   
		CAST(SUM(TurnoverBA		*e.Rate)	AS MONEY)		AS TurnoverBA,   
		CAST(SUM(TurnoverNG		*e.Rate)	AS MONEY)		AS TurnoverNG,   
		CAST(SUM(TurnoverVS		*e.Rate)	AS MONEY)		AS TurnoverVS,
		CAST(SUM(TurnoverCS		*e.Rate)	AS MONEY)		AS TurnoverCS,
		CAST(SUM(TurnoverKN		*e.Rate)	AS MONEY)		AS TurnoverKN,
		CAST(SUM(TurnoverAGC	*e.Rate)	AS MONEY)		AS TurnoverAGC,
		CAST(SUM(TurnoverVB		*e.Rate)	AS MONEY)		AS TurnoverVB,
		CAST(SUM(TurnoverAB		*e.Rate)	AS MONEY)		AS TurnoverAB,
		CAST(SUM(TurnoverFW		*e.Rate)	AS MONEY)		AS TurnoverFW,
		CAST(SUM(TurnoverCO		*e.Rate)	AS MONEY)		AS TurnoverCO,
		CAST(SUM(TurnoverVS2	*e.Rate)	AS MONEY)		AS TurnoverVS2,
		CAST(SUM(TurnoverLT		*e.Rate)	AS MONEY)		AS TurnoverLT,
		CAST(SUM(TurnoverPP		*e.Rate)	AS MONEY)		AS TurnoverPP,
		CAST(SUM(TurnoverCC		*e.Rate)	AS MONEY)		AS TurnoverCC,
		CAST(SUM(TurnoverSG		*e.Rate)	AS MONEY)		AS TurnoverSG,
		CAST(SUM(TurnoverVRG	*e.Rate)	AS MONEY)		AS TurnoverVRG,
		CAST(SUM(TurnoverTG		*e.Rate)	AS MONEY)		AS TurnoverTG,
		CAST(SUM(TurnoverI4D	*e.Rate)	AS MONEY)		AS TurnoverI4D,
		CAST(SUM(TurnoverSXG	*e.Rate)	AS MONEY)		AS TurnoverSXG,
		CAST(SUM(TurnoverSBC	*e.Rate)	AS MONEY)		AS TurnoverSBC,
		CAST(SUM(BTActualStake	*e.Rate)	AS MONEY)		AS BTActualStake,
		CAST(SUM(Winlost		*e.Rate)	AS MONEY)       AS Winlost,
		CAST(SUM(LicenseeWLSB	*e.Rate)	AS MONEY)		AS LicenseeWLSB,
		CAST(SUM(LicenseeWLBA	*e.Rate)	AS MONEY)       AS LicenseeWLBA,
		CAST(SUM(LicenseeWLNG	*e.Rate)	AS MONEY)       AS LicenseeWLNG,
		CAST(SUM(LicenseeWLVS	*e.Rate)	AS MONEY)       AS LicenseeWLVS,
		CAST(SUM(LicenseeWLCS	*e.Rate)	AS MONEY)	 	AS LicenseeWLCS,
		CAST(SUM(LicenseeWLKN	*e.Rate)	AS MONEY)		AS LicenseeWLKN,
		CAST(SUM(LicenseeWLAGC	*e.Rate)	AS MONEY)		AS LicenseeWLAGC,
		CAST(SUM(LicenseeWLVB	*e.Rate)	AS MONEY)		AS LicenseeWLVB,
		CAST(SUM(LicenseeWLAB	*e.Rate)	AS MONEY)		AS LicenseeWLAB,
		CAST(SUM(LicenseeWLFW	*e.Rate)	AS MONEY)		AS LicenseeWLFW,
		CAST(SUM(LicenseeWLCO	*e.Rate)	AS MONEY)		AS LicenseeWLCO,
		CAST(SUM(LicenseeWLVS2	*e.Rate)	AS MONEY)       AS LicenseeWLVS2,
		CAST(SUM(LicenseeWLLT	*e.Rate)	AS MONEY)		AS LicenseeWLLT,
		CAST(SUM(LicenseeWLPP	*e.Rate)	AS MONEY)		AS LicenseeWLPP,
		CAST(SUM(LicenseeWLCC	*e.Rate)	AS MONEY)		AS LicenseeWLCC,
		CAST(SUM(LicenseeWLSG	*e.Rate)	AS MONEY)		AS LicenseeWLSG,
		CAST(SUM(LicenseeWLVRG	*e.Rate)	AS MONEY)		AS LicenseeWLVRG,
		CAST(SUM(LicenseeWLTG	*e.Rate)	AS MONEY)		AS LicenseeWLTG,
		CAST(SUM(LicenseeWLI4D	*e.Rate)	AS MONEY)		AS LicenseeWLI4D,
		CAST(SUM(LicenseeWLSXG	*e.Rate)	AS MONEY)		AS LicenseeWLSXG,
		CAST(SUM(LicenseeWLSBC	*e.Rate)	AS MONEY)		AS LicenseeWLSBC,
		CAST(SUM(CommBA			*e.Rate)	AS MONEY)       AS CommBA,
		CAST(SUM(PlayerComm		*e.Rate)	AS MONEY)       AS PlayerComm,
		CAST(SUM(AmtDuetoBA		*e.Rate)	AS MONEY)       AS AmtDuetoBA,
		CAST(SUM(licenseeWLBT	*e.Rate)	AS MONEY)		AS licenseeWLBT,
		CAST(SUM(BetTradeComm	*e.Rate)	AS MONEY)		AS BetTradeComm,
		CAST(SUM((WLBetTicket+WLBoughtTicket-BetTradeComm)* e.Rate)  AS MONEY)	AS AmtDueToBT,
		CAST(SUM(BuyBackAmtSB	*e.Rate)	AS MONEY)		AS BuyBackAmtSB,
		CAST(SUM(BuyBackAmtBA	*e.Rate)	AS MONEY)		AS BuyBackAmtBA,
		CAST(SUM(CashOutComm	*e.Rate)	AS MONEY)		AS CashOutComm,
		SUM(Betcount)										AS Betcount
	FROM
		#SAgWinLoss w
		INNER JOIN Customer c WITH(NOLOCK) ON w.custid = c.custid
		INNER JOIN @ExchangeRate e ON w.winlostdate BETWEEN e.FromDate AND e.ToDate AND w.currency = e.ExchangeId
	GROUP BY
		w.currency, w.custid, c.username
	ORDER BY w.currency

	SELECT
		CAST(SUM(TurnoverSB		*e.USD)	AS MONEY)		AS TurnoverSBUSD,
		CAST(SUM(TurnoverBA		*e.USD)	AS MONEY)		AS TurnoverBAUSD,
		CAST(SUM(TurnoverNG		*e.USD)	AS MONEY)		AS TurnoverNGUSD,
		CAST(SUM(TurnoverVS		*e.USD)	AS MONEY)		AS TurnoverVSUSD,
		CAST(SUM(TurnoverCS		*e.USD)	AS MONEY)		AS TurnoverCSUSD,
		CAST(SUM(TurnoverKN		*e.USD)	AS MONEY)		AS TurnoverKNUSD,
		CAST(SUM(TurnoverAGC	*e.USD)	AS MONEY)		AS TurnoverAGCUSD,
		CAST(SUM(TurnoverVB		*e.USD)	AS MONEY)		AS TurnoverVBUSD,
		CAST(SUM(TurnoverAB		*e.USD)	AS MONEY)		AS TurnoverABUSD,
		CAST(SUM(TurnoverFW		*e.USD)	AS MONEY)		AS TurnoverFWUSD,
		CAST(SUM(TurnoverCO		*e.USD)	AS MONEY)		AS TurnoverCOUSD,
		CAST(SUM(TurnoverVS2	*e.USD)	AS MONEY)		AS TurnoverVS2USD,
		CAST(SUM(TurnoverLT		*e.USD)	AS MONEY)		AS TurnoverLTUSD,
		CAST(SUM(TurnoverPP		*e.USD)	AS MONEY)		AS TurnoverPPUSD,
		CAST(SUM(TurnoverCC		*e.USD)	AS MONEY)		AS TurnoverCCUSD,
		CAST(SUM(TurnoverSG		*e.USD)	AS MONEY)		AS TurnoverSGUSD,
		CAST(SUM(TurnoverVRG	*e.USD)	AS MONEY)		AS TurnoverVRGUSD,
		CAST(SUM(TurnoverTG		*e.USD)	AS MONEY)		AS TurnoverTGUSD,
		CAST(SUM(TurnoverI4D	*e.USD)	AS MONEY)		AS TurnoverI4DUSD,
		CAST(SUM(TurnoverSXG	*e.USD)	AS MONEY)		AS TurnoverSXGUSD,
		CAST(SUM(TurnoverSBC	*e.USD)	AS MONEY)		AS TurnoverSBCUSD,
		CAST(SUM(BTActualStake	*e.USD)	AS MONEY)		AS BTActualStakeUSD,
		CAST(SUM(Winlost		*e.USD)	AS MONEY)       AS WinlostUSD,
		CAST(SUM(LicenseeWLSB	*e.USD)	AS MONEY)		AS LicenseeWLSBUSD,
		CAST(SUM(LicenseeWLBA	*e.USD)	AS MONEY)       AS LicenseeWLBAUSD,
		CAST(SUM(LicenseeWLNG	*e.USD)	AS MONEY)       AS LicenseeWLNGUSD,
		CAST(SUM(LicenseeWLVS	*e.USD)	AS MONEY)       AS LicenseeWLVSUSD,
		CAST(SUM(LicenseeWLCS	*e.USD)	AS MONEY)	 	AS LicenseeWLCSUSD,
		CAST(SUM(LicenseeWLKN	*e.USD)	AS MONEY)		AS LicenseeWLKNUSD,
		CAST(SUM(LicenseeWLAGC	*e.USD)	AS MONEY)		AS LicenseeWLAGCUSD,
		CAST(SUM(LicenseeWLVB	*e.USD)	AS MONEY)		AS LicenseeWLVBUSD,
		CAST(SUM(LicenseeWLAB	*e.USD)	AS MONEY)		AS LicenseeWLABUSD,
		CAST(SUM(LicenseeWLFW	*e.USD)	AS MONEY)		AS LicenseeWLFWUSD,
		CAST(SUM(LicenseeWLCO	*e.USD)	AS MONEY)		AS LicenseeWLCOUSD,
		CAST(SUM(LicenseeWLVS2	*e.USD)	AS MONEY)       AS LicenseeWLVS2USD,
		CAST(SUM(LicenseeWLLT	*e.USD)	AS MONEY)		AS LicenseeWLLTUSD,
		CAST(SUM(LicenseeWLPP	*e.USD)	AS MONEY)		AS LicenseeWLPPUSD,
		CAST(SUM(LicenseeWLCC	*e.USD)	AS MONEY)		AS LicenseeWLCCUSD,
		CAST(SUM(LicenseeWLSG	*e.USD)	AS MONEY)		AS LicenseeWLSGUSD,
		CAST(SUM(LicenseeWLVRG	*e.USD)	AS MONEY)		AS LicenseeWLVRGUSD,
		CAST(SUM(LicenseeWLTG	*e.USD)	AS MONEY)		AS LicenseeWLTGUSD,
		CAST(SUM(LicenseeWLI4D	*e.USD)	AS MONEY)		AS LicenseeWLI4DUSD,
		CAST(SUM(LicenseeWLSXG	*e.USD)	AS MONEY)		AS LicenseeWLSXGUSD,
		CAST(SUM(LicenseeWLSBC	*e.USD)	AS MONEY)		AS LicenseeWLSBCUSD,
		CAST(SUM(CommBA			*e.USD)	AS MONEY)       AS CommBAUSD,
		CAST(SUM(PlayerComm		*e.USD)	AS MONEY)       AS PlayerCommUSD,
		CAST(SUM(AmtDuetoBA		*e.USD)	AS MONEY)       AS AmtDuetoBAUSD,
		CAST(SUM(licenseeWLBT	*e.USD)	AS MONEY)		AS licenseeWLBTUSD,
		CAST(SUM(BetTradeComm	*e.USD)	AS MONEY)		AS BetTradeCommUSD,
		CAST(SUM((WLBetTicket+WLBoughtTicket-BetTradeComm) *e.USD)  AS MONEY)	AS AmtDueToBTUSD,
		CAST(SUM(BuyBackAmtSB	*e.USD)	AS MONEY)		AS BuyBackAmtSBUSD,
		CAST(SUM(BuyBackAmtBA	*e.USD)	AS MONEY)		AS BuyBackAmtBAUSD,
		CAST(SUM(CashOutComm	*e.USD)	AS MONEY)		AS CashOutCommUSD,
		
		CAST(SUM(TurnoverSB		*e.EUR)	AS MONEY)		AS TurnoverSBEUR,   
		CAST(SUM(TurnoverBA		*e.EUR)	AS MONEY)		AS TurnoverBAEUR,   
		CAST(SUM(TurnoverNG		*e.EUR)	AS MONEY)		AS TurnoverNGEUR,   
		CAST(SUM(TurnoverVS		*e.EUR)	AS MONEY)		AS TurnoverVSEUR,
		CAST(SUM(TurnoverCS		*e.EUR)	AS MONEY)		AS TurnoverCSEUR,
		CAST(SUM(TurnoverKN		*e.EUR)	AS MONEY)		AS TurnoverKNEUR,
		CAST(SUM(TurnoverAGC	*e.EUR)	AS MONEY)		AS TurnoverAGCEUR,
		CAST(SUM(TurnoverVB		*e.EUR)	AS MONEY)		AS TurnoverVBEUR,
		CAST(SUM(TurnoverAB		*e.EUR)	AS MONEY)		AS TurnoverABEUR,
		CAST(SUM(TurnoverFW		*e.EUR)	AS MONEY)		AS TurnoverFWEUR,
		CAST(SUM(TurnoverCO		*e.EUR)	AS MONEY)		AS TurnoverCOEUR,
		CAST(SUM(TurnoverVS2	*e.EUR)	AS MONEY)		AS TurnoverVS2EUR,
		CAST(SUM(TurnoverLT		*e.EUR)	AS MONEY)		AS TurnoverLTEUR,
		CAST(SUM(TurnoverPP		*e.EUR)	AS MONEY)		AS TurnoverPPEUR,
		CAST(SUM(TurnoverCC		*e.EUR)	AS MONEY)		AS TurnoverCCEUR,
		CAST(SUM(TurnoverSG		*e.EUR)	AS MONEY)		AS TurnoverSGEUR,
		CAST(SUM(TurnoverVRG	*e.EUR)	AS MONEY)		AS TurnoverVRGEUR,
		CAST(SUM(TurnoverTG		*e.EUR)	AS MONEY)		AS TurnoverTGEUR,
		CAST(SUM(TurnoverI4D	*e.EUR)	AS MONEY)		AS TurnoverI4DEUR,
		CAST(SUM(TurnoverSXG	*e.EUR)	AS MONEY)		AS TurnoverSXGEUR,
		CAST(SUM(TurnoverSBC	*e.EUR)	AS MONEY)		AS TurnoverSBCEUR,
		CAST(SUM(BTActualStake	*e.EUR)	AS MONEY)		AS BTActualStakeEUR,
		CAST(SUM(Winlost		*e.EUR)	AS MONEY)       AS WinlostEUR,
		CAST(SUM(LicenseeWLSB	*e.EUR)	AS MONEY)		AS LicenseeWLSBEUR,
		CAST(SUM(LicenseeWLBA	*e.EUR)	AS MONEY)       AS LicenseeWLBAEUR,
		CAST(SUM(LicenseeWLNG	*e.EUR)	AS MONEY)       AS LicenseeWLNGEUR,
		CAST(SUM(LicenseeWLVS	*e.EUR)	AS MONEY)       AS LicenseeWLVSEUR,
		CAST(SUM(LicenseeWLCS	*e.EUR)	AS MONEY)	 	AS LicenseeWLCSEUR,
		CAST(SUM(LicenseeWLKN	*e.EUR)	AS MONEY)		AS LicenseeWLKNEUR,
		CAST(SUM(LicenseeWLAGC	*e.EUR)	AS MONEY)		AS LicenseeWLAGCEUR,
		CAST(SUM(LicenseeWLVB	*e.EUR)	AS MONEY)		AS LicenseeWLVBEUR,
		CAST(SUM(LicenseeWLAB	*e.EUR)	AS MONEY)		AS LicenseeWLABEUR,
		CAST(SUM(LicenseeWLFW	*e.EUR)	AS MONEY)		AS LicenseeWLFWEUR,
		CAST(SUM(LicenseeWLCO	*e.EUR)	AS MONEY)		AS LicenseeWLCOEUR,
		CAST(SUM(LicenseeWLVS2	*e.EUR)	AS MONEY)       AS LicenseeWLVS2EUR,
		CAST(SUM(LicenseeWLLT	*e.EUR)	AS MONEY)		AS LicenseeWLLTEUR,
		CAST(SUM(LicenseeWLPP	*e.EUR)	AS MONEY)		AS LicenseeWLPPEUR,
		CAST(SUM(LicenseeWLCC	*e.EUR)	AS MONEY)		AS LicenseeWLCCEUR,
		CAST(SUM(LicenseeWLSG	*e.EUR)	AS MONEY)		AS LicenseeWLSGEUR,
		CAST(SUM(LicenseeWLVRG	*e.EUR)	AS MONEY)		AS LicenseeWLVRGEUR,
		CAST(SUM(LicenseeWLTG	*e.EUR)	AS MONEY)		AS LicenseeWLTGEUR,
		CAST(SUM(LicenseeWLI4D	*e.EUR)	AS MONEY)		AS LicenseeWLI4DEUR,
		CAST(SUM(LicenseeWLSXG	*e.EUR)	AS MONEY)		AS LicenseeWLSXGEUR,
		CAST(SUM(LicenseeWLSBC	*e.EUR)	AS MONEY)		AS LicenseeWLSBCEUR,
		CAST(SUM(CommBA			*e.EUR)	AS MONEY)       AS CommBAEUR,
		CAST(SUM(PlayerComm		*e.EUR)	AS MONEY)       AS PlayerCommEUR,
		CAST(SUM(AmtDuetoBA		*e.EUR)	AS MONEY)       AS AmtDuetoBAEUR,
		CAST(SUM(licenseeWLBT	*e.EUR)	AS MONEY)		AS licenseeWLBTEUR,
		CAST(SUM(BetTradeComm	*e.EUR)	AS MONEY)		AS BetTradeCommEUR,
		CAST(SUM((WLBetTicket+WLBoughtTicket-BetTradeComm) *e.EUR)  AS MONEY)	AS AmtDueToBTEUR,
		CAST(SUM(BuyBackAmtSB	*e.EUR)	AS MONEY)		AS BuyBackAmtSBEUR,
		CAST(SUM(BuyBackAmtBA	*e.EUR)	AS MONEY)		AS BuyBackAmtBAEUR,
		CAST(SUM(CashOutComm	*e.EUR)	AS MONEY)		AS CashOutCommEUR,
		
		CAST(SUM(TurnoverSB		*e.GBP)	AS MONEY)		AS TurnoverSBGBP,   
		CAST(SUM(TurnoverBA		*e.GBP)	AS MONEY)		AS TurnoverBAGBP,   
		CAST(SUM(TurnoverNG		*e.GBP)	AS MONEY)		AS TurnoverNGGBP,   
		CAST(SUM(TurnoverVS		*e.GBP)	AS MONEY)		AS TurnoverVSGBP,
		CAST(SUM(TurnoverCS		*e.GBP)	AS MONEY)		AS TurnoverCSGBP,
		CAST(SUM(TurnoverKN		*e.GBP)	AS MONEY)		AS TurnoverKNGBP,
		CAST(SUM(TurnoverAGC	*e.GBP)	AS MONEY)		AS TurnoverAGCGBP,
		CAST(SUM(TurnoverVB		*e.GBP)	AS MONEY)		AS TurnoverVBGBP,
		CAST(SUM(TurnoverAB		*e.GBP)	AS MONEY)		AS TurnoverABGBP,
		CAST(SUM(TurnoverFW		*e.GBP)	AS MONEY)		AS TurnoverFWGBP,
		CAST(SUM(TurnoverCO		*e.GBP)	AS MONEY)		AS TurnoverCOGBP,
		CAST(SUM(TurnoverVS2	*e.GBP)	AS MONEY)		AS TurnoverVS2GBP,
		CAST(SUM(TurnoverLT		*e.GBP)	AS MONEY)		AS TurnoverLTGBP,
		CAST(SUM(TurnoverPP		*e.GBP)	AS MONEY)		AS TurnoverPPGBP,
		CAST(SUM(TurnoverCC		*e.GBP)	AS MONEY)		AS TurnoverCCGBP,
		CAST(SUM(TurnoverSG		*e.GBP)	AS MONEY)		AS TurnoverSGGBP,
		CAST(SUM(TurnoverVRG	*e.GBP)	AS MONEY)		AS TurnoverVRGGBP,
		CAST(SUM(TurnoverTG		*e.GBP)	AS MONEY)		AS TurnoverTGGBP,
		CAST(SUM(TurnoverI4D	*e.GBP)	AS MONEY)		AS TurnoverI4DGBP,
		CAST(SUM(TurnoverSXG	*e.GBP)	AS MONEY)		AS TurnoverSXGGBP,
		CAST(SUM(TurnoverSBC	*e.GBP)	AS MONEY)		AS TurnoverSBCGBP,
		CAST(SUM(BTActualStake	*e.GBP)	AS MONEY)		AS BTActualStakeGBP,
		CAST(SUM(Winlost		*e.GBP)	AS MONEY)       AS WinlostGBP,
		CAST(SUM(LicenseeWLSB	*e.GBP)	AS MONEY)		AS LicenseeWLSBGBP,
		CAST(SUM(LicenseeWLBA	*e.GBP)	AS MONEY)       AS LicenseeWLBAGBP,
		CAST(SUM(LicenseeWLNG	*e.GBP)	AS MONEY)       AS LicenseeWLNGGBP,
		CAST(SUM(LicenseeWLVS	*e.GBP)	AS MONEY)       AS LicenseeWLVSGBP,
		CAST(SUM(LicenseeWLCS	*e.GBP)	AS MONEY)	 	AS LicenseeWLCSGBP,
		CAST(SUM(LicenseeWLKN	*e.GBP)	AS MONEY)		AS LicenseeWLKNGBP,
		CAST(SUM(LicenseeWLAGC	*e.GBP)	AS MONEY)		AS LicenseeWLAGCGBP,
		CAST(SUM(LicenseeWLVB	*e.GBP)	AS MONEY)		AS LicenseeWLVBGBP,
		CAST(SUM(LicenseeWLAB	*e.GBP)	AS MONEY)		AS LicenseeWLABGBP,
		CAST(SUM(LicenseeWLFW	*e.GBP)	AS MONEY)		AS LicenseeWLFWGBP,
		CAST(SUM(LicenseeWLCO	*e.GBP)	AS MONEY)		AS LicenseeWLCOGBP,
		CAST(SUM(LicenseeWLVS2	*e.GBP)	AS MONEY)       AS LicenseeWLVS2GBP,
		CAST(SUM(LicenseeWLLT	*e.GBP)	AS MONEY)		AS LicenseeWLLTGBP,
		CAST(SUM(LicenseeWLPP	*e.GBP)	AS MONEY)		AS LicenseeWLPPGBP,
		CAST(SUM(LicenseeWLCC	*e.GBP)	AS MONEY)		AS LicenseeWLCCGBP,
		CAST(SUM(LicenseeWLSG	*e.GBP)	AS MONEY)		AS LicenseeWLSGGBP,
		CAST(SUM(LicenseeWLVRG	*e.GBP)	AS MONEY)		AS LicenseeWLVRGGBP,
		CAST(SUM(LicenseeWLTG	*e.GBP)	AS MONEY)		AS LicenseeWLTGGBP,
		CAST(SUM(LicenseeWLI4D	*e.GBP)	AS MONEY)		AS LicenseeWLI4DGBP,
		CAST(SUM(LicenseeWLSXG	*e.GBP)	AS MONEY)		AS LicenseeWLSXGGBP,
		CAST(SUM(LicenseeWLSBC	*e.GBP)	AS MONEY)		AS LicenseeWLSBCGBP,
		CAST(SUM(CommBA			*e.GBP)	AS MONEY)       AS CommBAGBP,
		CAST(SUM(PlayerComm		*e.GBP)	AS MONEY)       AS PlayerCommGBP,
		CAST(SUM(AmtDuetoBA		*e.GBP)	AS MONEY)       AS AmtDuetoBAGBP,
		CAST(SUM(licenseeWLBT	*e.GBP)	AS MONEY)		AS licenseeWLBTGBP,
		CAST(SUM(BetTradeComm	*e.GBP)	AS MONEY)		AS BetTradeCommGBP,
		CAST(SUM((WLBetTicket+WLBoughtTicket-BetTradeComm) *e.GBP)  AS MONEY)	AS AmtDueToBTGBP,
		CAST(SUM(BuyBackAmtSB	*e.GBP)	AS MONEY)		AS BuyBackAmtSBGBP,
		CAST(SUM(BuyBackAmtBA	*e.GBP)	AS MONEY)		AS BuyBackAmtBAGBP,
		CAST(SUM(CashOutComm	*e.GBP)	AS MONEY)		AS CashOutCommGBP,
		
		CAST(SUM(TurnoverSB		*e.DefaultRate)	AS MONEY)		AS TurnoverSB,   
		CAST(SUM(TurnoverBA		*e.DefaultRate)	AS MONEY)		AS TurnoverBA,   
		CAST(SUM(TurnoverNG		*e.DefaultRate)	AS MONEY)		AS TurnoverNG,   
		CAST(SUM(TurnoverVS		*e.DefaultRate)	AS MONEY)		AS TurnoverVS,
		CAST(SUM(TurnoverCS		*e.DefaultRate)	AS MONEY)		AS TurnoverCS,
		CAST(SUM(TurnoverKN		*e.DefaultRate)	AS MONEY)		AS TurnoverKN,
		CAST(SUM(TurnoverAGC	*e.DefaultRate)	AS MONEY)		AS TurnoverAGC,
		CAST(SUM(TurnoverVB		*e.DefaultRate)	AS MONEY)		AS TurnoverVB,
		CAST(SUM(TurnoverAB		*e.DefaultRate)	AS MONEY)		AS TurnoverAB,
		CAST(SUM(TurnoverFW		*e.DefaultRate)	AS MONEY)		AS TurnoverFW,
		CAST(SUM(TurnoverCO		*e.DefaultRate)	AS MONEY)		AS TurnoverCO,
		CAST(SUM(TurnoverVS2	*e.DefaultRate)	AS MONEY)		AS TurnoverVS2,
		CAST(SUM(TurnoverLT		*e.DefaultRate)	AS MONEY)		AS TurnoverLT,
		CAST(SUM(TurnoverPP		*e.DefaultRate)	AS MONEY)		AS TurnoverPP,
		CAST(SUM(TurnoverCC		*e.DefaultRate)	AS MONEY)		AS TurnoverCC,
		CAST(SUM(TurnoverSG		*e.DefaultRate)	AS MONEY)		AS TurnoverSG,
		CAST(SUM(TurnoverVRG	*e.DefaultRate)	AS MONEY)		AS TurnoverVRG,
		CAST(SUM(TurnoverTG		*e.DefaultRate)	AS MONEY)		AS TurnoverTG,
		CAST(SUM(TurnoverI4D	*e.DefaultRate)	AS MONEY)		AS TurnoverI4D,
		CAST(SUM(TurnoverSXG	*e.DefaultRate)	AS MONEY)		AS TurnoverSXG,
		CAST(SUM(TurnoverSBC	*e.DefaultRate)	AS MONEY)		AS TurnoverSBC,
		CAST(SUM(BTActualStake	*e.DefaultRate)	AS MONEY)		AS BTActualStake,
		CAST(SUM(Winlost		*e.DefaultRate)	AS MONEY)       AS Winlost,
		CAST(SUM(LicenseeWLSB	*e.DefaultRate)	AS MONEY)		AS LicenseeWLSB,
		CAST(SUM(LicenseeWLBA	*e.DefaultRate)	AS MONEY)       AS LicenseeWLBA,
		CAST(SUM(LicenseeWLNG	*e.DefaultRate)	AS MONEY)       AS LicenseeWLNG,
		CAST(SUM(LicenseeWLVS	*e.DefaultRate)	AS MONEY)       AS LicenseeWLVS,
		CAST(SUM(LicenseeWLCS	*e.DefaultRate)	AS MONEY)	 	AS LicenseeWLCS,
		CAST(SUM(LicenseeWLKN	*e.DefaultRate)	AS MONEY)		AS LicenseeWLKN,
		CAST(SUM(LicenseeWLAGC	*e.DefaultRate)	AS MONEY)		AS LicenseeWLAGC,
		CAST(SUM(LicenseeWLVB	*e.DefaultRate)	AS MONEY)		AS LicenseeWLVB,
		CAST(SUM(LicenseeWLAB	*e.DefaultRate)	AS MONEY)		AS LicenseeWLAB,
		CAST(SUM(LicenseeWLFW	*e.DefaultRate)	AS MONEY)		AS LicenseeWLFW,
		CAST(SUM(LicenseeWLCO	*e.DefaultRate)	AS MONEY)		AS LicenseeWLCO,
		CAST(SUM(LicenseeWLVS2	*e.DefaultRate)	AS MONEY)       AS LicenseeWLVS2,
		CAST(SUM(LicenseeWLLT	*e.DefaultRate)	AS MONEY)		AS LicenseeWLLT,
		CAST(SUM(LicenseeWLPP	*e.DefaultRate)	AS MONEY)		AS LicenseeWLPP,
		CAST(SUM(LicenseeWLCC	*e.DefaultRate)	AS MONEY)		AS LicenseeWLCC,
		CAST(SUM(LicenseeWLSG	*e.DefaultRate)	AS MONEY)		AS LicenseeWLSG,
		CAST(SUM(LicenseeWLVRG	*e.DefaultRate)	AS MONEY)		AS LicenseeWLVRG,
		CAST(SUM(LicenseeWLTG	*e.DefaultRate)	AS MONEY)		AS LicenseeWLTG,
		CAST(SUM(LicenseeWLI4D	*e.DefaultRate)	AS MONEY)		AS LicenseeWLI4D,
		CAST(SUM(LicenseeWLSXG	*e.DefaultRate)	AS MONEY)		AS LicenseeWLSXG,
		CAST(SUM(LicenseeWLSBC	*e.DefaultRate)	AS MONEY)		AS LicenseeWLSBC,
		CAST(SUM(CommBA			*e.DefaultRate)	AS MONEY)       AS CommBA,
		CAST(SUM(PlayerComm		*e.DefaultRate)	AS MONEY)       AS PlayerComm,
		CAST(SUM(AmtDuetoBA		*e.DefaultRate)	AS MONEY)       AS AmtDuetoBA,
		CAST(SUM(licenseeWLBT	*e.DefaultRate)	AS MONEY)		AS licenseeWLBT,
		CAST(SUM(BetTradeComm	*e.DefaultRate)	AS MONEY)		AS BetTradeComm,
		CAST(SUM((WLBetTicket+WLBoughtTicket-BetTradeComm) *e.DefaultRate)  AS MONEY)	AS AmtDueToBT,
		CAST(SUM(BuyBackAmtSB	*e.DefaultRate)	AS MONEY)		AS BuyBackAmtSB,
		CAST(SUM(BuyBackAmtBA	*e.DefaultRate)	AS MONEY)		AS BuyBackAmtBA,
		CAST(SUM(CashOutComm	*e.DefaultRate)	AS MONEY)		AS CashOutComm,
		@PromotionPrize											AS PromotionPrize,
		SUM(Betcount)											AS Betcount
	FROM
		#SAgWinLoss w
		INNER JOIN @ExchangeRate e ON w.winlostdate BETWEEN e.FromDate AND e.ToDate AND w.currency = e.ExchangeId

	DROP TABLE #SAgWinLoss
END
GO
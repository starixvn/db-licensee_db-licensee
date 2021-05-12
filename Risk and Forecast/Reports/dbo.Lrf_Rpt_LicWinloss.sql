/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_LicWinloss]
	@LicenseeID		INT,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@showSB			BIT = 0,
	@ShowNG			BIT = 0,
	@ShowBA			BIT = 0,
	@ShowVS			BIT = 0,
	@ShowCS			BIT = 0, -- RNG Casino
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
	@ShowCC			BIT = 0, -- Card club
	@ShowSG			BIT = 0, -- Spadegaming
	@ShowVRG		BIT = 0, -- Virtual Games
	@ShowTG			BIT = 0, -- Table Games
	@ShowI4D		BIT = 0, -- Indo 4D
	@ShowSXG		BIT = 0, -- Sexy Gaming
	@ShowSBC		BIT = 0, -- Saba club
	@ShowSAG		BIT = 0, -- SA Gaming
	@ShowPGS		BIT = 0, -- PG Soft
	@ShowJK			BIT = 0, -- Joker
	@ShowGDG		BIT = 0, -- GDG
	@ShowSLT		BIT = 0, -- Sports Lottery
	@ShowHB			BIT = 0, -- Habanero
	@ShowWM			BIT = 0, -- WM Live Casino
	@ReportType		TINYINT = 1,
	@MoveBetsDay	SMALLDATETIME,
	@drawfilter		SMALLINT = 1,
	@AgentList		VARCHAR(MAX),
	@BaseCurrency	VARCHAR(3) = '',
	@DefaultBaseCurrency	VARCHAR(3) = '',
	@CheckPromotionPrize	BIT = 0,
	@VIPPlayerOnly	BIT = 0
AS

/*
	Created: Henry
	Date: 2012-01-09
	Task: Winloss Report for Licensee
	DB: DBEXT.bodb02

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
		- 20190605@Amanda: Add Base currency param [RedmineID: #112531]
		- 20190708@Amanda: Add new product Card Club [RedmineID: #115449]
		- 20190910@Amanda: Add bet types that support Half Won/ Half Lose [RedmineID: #118300]
		- 20190923@Amanda: Change the way to handle Half Won/ Half Lose bet types [RedmineID: #119879]
		- 20191017@Amanda: Integrate NPH Promotion [RedmineID: #120333]
		- 20191121@Amanda: Integrate PP Tournament Prize and exclude PP Promotion, Tournament Prize from result [RedmineID: #123804]
		- 20190312@Amanda: Add new bet types Single Match Parlay (ID: 38) [RedmineID: #108298]
		- 20191212@Vickie: Integrate SpadeGaming [RedmineID: #124103]
		- 20200108@Vickie: Add new product Virtual Games [RedmineID: #124911]
		- 20200331@Hogan: Add new product Table Games [RedmineID: #131447]
		- 20200323@Vickie: Add new product Indo 4D [RedmineID: #130859]
		- 20200423@Hogan: Add new product Sexy Gaming [RedmineID: #132829]
		- 20200423@Vickie: Integrate Saba Club [RedmineID: #132702]
		- 20200508@Vickie: Add new bet types for E-Sports 2.0 [RedmineID: #132548]
		- 20200714@Hogan: Add 7 games for Jackpot and 2 bettype for Contribution (4297) and Jackpot Prize (4298) [RedmineID: #137290]
		- 20200724@Hogan: Get correct status for bettype Contribution (4297) [RedmineID: #138271]
		- 20200803@Kos: Support Saba Loyalty [RedmineID: #138493]
		- 20200820@Hogan: Support filter by VIP player [RedmineID: #138371]
		- 20200831@Kos: Enhance performance [RedmineID: #140174]
		- 20201013@Hogan: Integrate SA Gaming [RedmineID: #128493
		- 20201016@Hogan: Integrate Arcadia Gaming Bonus [RedmineID: #143648]
		- 20201022@Louis: Integrate PG Soft [RedmineID: #139182]
		- 20201126@Hogan: Integrate Joker [RedmineID: #141408]
		- 20201202@Louis: Licensee Spread Setting [RedmineID: #142532]	
		- 20201202@Hogan: Add new sport Saba.club Free Bets [RedmineID: #142369]
		- 20201224@Hogan: Integrate GDG [RedmineID: #147267]
		- 20210203@Louis: Saba Red Envelope [RedmineID: #149923]
		- 20210208@Hogan: Integrate Four Guardians [RedmineID: #148100]
		- 20210305@Hogan: Integrate Sport Lottery [RedmineID: #150872]
		- 20210330@Hogan: Integrate Cricket AIO [RedmineID: #150386]
		- 20210416@Hogan: Integrate Habanero RNG Games [RedmineID: #150843]
		- 20210428@Hogan: Integrate WM Live Casino [RedmineID: #140944]

	Param's Explanation:
		+ @ReportType: 1-Daily; 2-Monthly;
		+ @drawfilter: 'No Draw' filter is supportted (1:Normal 2:No Draw 3:No Draw for Turnover only)
		+ @excludeTest: remove currency UUS
		+ @MoveBetsDay: The day we move tickets to bettrans14
		+ @CheckPromotionPrize: = 1 if want to check whether have promotion prize ticket or not
		+ @AgentList: xml structure
						<ROOT>
							<Agent AgentId="12345" Currency="3"/>
							<Agent AgentId="12345" Currency="5"/>
						</ROOT>
		+ @VIPPlayerOnly: = 1 if want to generate data of VIP players only
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #SAgWinLoss
	(
		WinLostDate		SMALLDATETIME,
		Currency		INT,
		ProductCode		VARCHAR(10),
		Turnover		MONEY,
		BTActualStake	MONEY,
		Winlost			MONEY,
		LicenseeWL		MONEY,
		AmtDueToBA		MONEY,
		CommBA			MONEY,
		PlayerComm		MONEY,
		Betcount		BIGINT,
		licenseeWLBT	MONEY,
		BetTradeComm	MONEY,
		WLBetTicket		MONEY,
		WLBoughtTicket	MONEY,
		BuyBackAmtSB	MONEY,
		BuyBackAmtBA	MONEY,
		CashOutComm		MONEY
	)

	DECLARE @tempAg TABLE (CustId INT, Currency INT)

	DECLARE @ExchangeRate TABLE (
		FromDate	SMALLDATETIME,
		ToDate		SMALLDATETIME,
		ExchangeId	INT,
		Rate		FLOAT,
		USD			FLOAT,
		EUR			FLOAT,
		GBP			FLOAT,
		DefaultRate	FLOAT)

	DECLARE @BetType TABLE (BetType INT PRIMARY KEY, ProductCode VARCHAR(10))
	DECLARE @SportType TABLE (SportType INT, ProductCode VARCHAR(10))
	DECLARE @WLBetTicket TABLE (WinLostDate SMALLDATETIME, Currency INT, WLBetTicket MONEY)
	DECLARE @VIPCust TABLE (CustId INT)

	DECLARE @LicenseeName	VARCHAR(50),
		@ProductList		VARCHAR (500),
		@PromotionPrize		INT = 0,
		@_FromDate			SMALLDATETIME,
		@_ToDate			SMALLDATETIME

	SELECT @_FromDate = @FromDate,
		@_ToDate = @ToDate

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
				,@AgentList
		INSERT INTO @tempAg (custID, currency)
		SELECT AgentId, Currency
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
			,ErrMsg = N'Parameter invalid.'

		RETURN
	END CATCH;

	SELECT @LicenseeName = LicenseeName
	FROM bodb_Licensee.dbo.Licensees WITH (NOLOCK)
	WHERE LicenseeID = @LicenseeID
	
	DECLARE @ExcludedBetType TABLE (ProductCode VARCHAR (10), BetType INT)
	-- Insert Excluded BetType
	INSERT INTO @ExcludedBetType (ProductCode, BetType)
	SELECT ProductCode, BetType FROM Lrf_f_SelExcludedBetType()

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

	IF @ShowSG = 1
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

	IF @ShowSBC = 1 -- Saba club
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'SBC', 'SBC')
	END

	IF @ShowSAG = 1
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'SAG', 'SAG')
	END
	
	IF @ShowPGS = 1 -- PG Soft
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'PGS', 'PGS')
	END

	IF @ShowJK = 1 -- Joker
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'JK', 'JK')
	END

	IF @ShowGDG = 1 -- GDG
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'GDG', 'GDG')
	END

	IF @ShowSLT = 1 --  Sports Lottery
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'SLT', 'SLT')
	END

	IF @ShowHB = 1 --  Habanero
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'HB', 'HB')
	END

	IF @ShowWM = 1 --  WM Live Casino
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'WM', 'WM')
	END

	IF LEN(ISNULL(@ProductList, '')) > 0 
	BEGIN
		-- Insert Bettype
		INSERT INTO @BetType (BetType, ProductCode)
		SELECT DISTINCT BetType, ProductPrefix
		FROM f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', @ProductList, @IsTest)
		WHERE BetType NOT IN (SELECT BetType FROM @ExcludedBetType e WHERE e.ProductCode = ProductPrefix)

		-- Insert VIPCust
		IF @VIPPlayerOnly = 1
		BEGIN
			INSERT INTO @VIPCust (CustId)
			SELECT c.custid
			FROM dbo.customer c WITH(NOLOCK)
				INNER JOIN @tempAg tma ON tma.CustID = c.recommend
				INNER JOIN Dep_CustVIP d WITH(NOLOCK) ON c.custid = d.custid
			WHERE c.roleid = 1
		END

		IF @ShowCS = 1
			DELETE @BetType
			WHERE BetType = 72 AND ProductCode = 'CS'

		IF @ShowSB = 1
			DELETE @BetType
			WHERE ProductCode = 'SB'

		-- Insert Sport Type
		INSERT INTO @SportType ( SportType, ProductCode )
		SELECT DISTINCT sporttype, ProductCode
		FROM f_LicWinLoss_ProductSportType_Sel(@ProductList)
		WHERE sporttype <> 150
	END

	DECLARE @TempFromDate	SMALLDATETIME,
			@TempToDate		SMALLDATETIME

	IF @_ToDate > @MoveBetsDay
	BEGIN
		IF @_FromDate <= @MoveBetsDay 
			SET @TempFromDate = DATEADD(DAY,1,@MoveBetsDay)
		ELSE
			SET @TempFromDate = @_FromDate
	
		DECLARE @transid BIGINT

		SELECT TOP (1) @transid = transid
		FROM dbo.bettrans WITH(NOLOCK)
		WHERE matchid > 0
		ORDER BY transid

		DECLARE @HWHLCutDate SMALLDATETIME = '2019-10-01' -- half won/ half lose cut date

		IF @VIPPlayerOnly = 0
		BEGIN
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
					WLBetTicket, WLBoughtTicket, BuyBackAmtSB, BuyBackAmtBA, CashOutComm
				)
				SELECT
					b.winlostdate,
					tma.currency,
					'BA',
					SUM(CASE WHEN RAND() + 1 > 0 THEN stake ELSE 0 END
						*
						CASE WHEN @drawfilter IN (2, 3) THEN
							CASE
								WHEN b.statusID = 111 THEN 0
								WHEN b.winlostdate >= @HWHLCutDate AND b.statusID IN (112, 113) AND b.modds IN (-0.25, 0.25) AND b.bettype NOT IN (29,38) THEN 0.5 -- exclude parlay, bet builder
								WHEN b.winlostdate < @HWHLCutDate AND (b.statusID = 112 OR b.statusID = 113) AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18,124,125,482,483,484,485) THEN 0.5
								ELSE 1 END
						ELSE 1 END
					) AS turnover, 
					0 AS BTActualStake,
					SUM(CASE WHEN RAND() + 1 > 0 THEN b.winlost-b.actual_stake ELSE 0 END) AS Winlost,
					0 AS LicenseeWL,
					-SUM(CASE WHEN RAND() + 1 > 0 THEN b.winlost-b.actual_stake+awinlost+comm ELSE 0 END) AS AmountDueToBA,
					SUM(CASE WHEN RAND() + 1 > 0 THEN comm ELSE 0 END) AS CommBA,
					SUM(ISNULL(CASE WHEN RAND() + 1 > 0 THEN b.playercomm ELSE 0 END,0)) AS PlayerComm,
					COUNT(CASE WHEN RAND() + 1 > 0 AND @drawfilter = 2 AND b.statusID = 111 THEN NULL ELSE b.transid END) AS BetCount,
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
					AND b.statusID IN (111, 112, 113)
					AND (b.bettype < 901 OR b.bettype > 904)
					AND (b.bettype < 911 OR b.bettype > 914)
					AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.BetType = b.BetType)
				GROUP BY
					b.winlostdate,
					tma.currency 
				OPTION(RECOMPILE)
			END
	
			IF @ShowSB = 1
			BEGIN
				INSERT INTO #SAgWinLoss
				(
					winlostdate, Currency, ProductCode, Turnover, BTActualStake,
					Winlost, LicenseeWL, AmtDueToBA, CommBA,
					PlayerComm, Betcount, licenseeWLBT, BetTradeComm,  
					WLBetTicket, WLBoughtTicket, BuyBackAmtSB, BuyBackAmtBA, CashOutComm
				)
				SELECT
					b.winlostdate,
					a.currency,
					'SB',
					SUM(CASE WHEN RAND() + 1 > 0 THEN stake ELSE 0 END
						*
						CASE WHEN @drawfilter IN (2, 3) THEN
							CASE
								WHEN b.statusID = 111 THEN 0
								WHEN b.winlostdate >= @HWHLCutDate AND b.statusID IN (112, 113) AND b.modds IN (-0.25, 0.25) AND b.bettype NOT IN (29,38) THEN 0.5 -- exclude parlay, bet builder
								WHEN b.winlostdate < @HWHLCutDate AND (b.statusID = 112 OR b.statusID = 113) AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18,124,125,482,483,484,485) THEN 0.5
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
					0 AS CashOutComm
				FROM
					dbo.bettrans b WITH (NOLOCK)
					INNER JOIN @tempAg a ON b.recommend = a.CustId AND b.currency = a.Currency
				WHERE 
					b.winlostdate BETWEEN @TempFromDate AND @_ToDate
					AND
					(
						b.bettype <= 30
						OR b.bettype BETWEEN 121 AND 999
						OR b.Bettype BETWEEN 1301 AND 1399 --new tennis's bettypes
						OR b.Bettype BETWEEN 9001 AND 9399 -- E-Sports 2.0
						OR b.Bettype BETWEEN 9400 AND 9699 -- Cricket AIO
						OR b.Bettype = 38				   -- Single Match Parlay
					)
					AND b.statusID IN (111, 112, 113)
					AND b.tpositiontaking <> 0
					AND (b.bettype < 901 OR b.bettype > 904)
					AND (b.bettype < 911 OR b.bettype > 914)
					AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.ProductCode = 'SB' AND e.BetType = b.BetType)
					AND b.transid >= @transid
				GROUP BY
					b.winlostdate,
					a.currency --, statusID, b.bettype
			END

			IF @ShowBT = 1
			BEGIN
				INSERT INTO #SAgWinLoss
				(
					winlostdate, Currency, ProductCode, Turnover, BTActualStake,
					Winlost, LicenseeWL, AmtDueToBA, CommBA,
					PlayerComm, Betcount, licenseeWLBT, BetTradeComm,
					WLBetTicket, WLBoughtTicket, BuyBackAmtSB, BuyBackAmtBA, CashOutComm
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
					0 AS CashOutComm
				FROM
					dbo.bettrans b WITH (NOLOCK)
					INNER JOIN @tempAg a ON b.recommend = a.custID AND b.currency = a.currency
				WHERE
					b.winlostdate BETWEEN @TempFromDate AND @_ToDate
					AND b.bettype IN (901, 902, 903)
					AND b.statusID IN (111, 112, 113)
					AND b.transid >= @transid
				GROUP BY
					b.winlostdate,
					a.currency
			END

			IF @ShowCO = 1
			BEGIN
				INSERT INTO #SAgWinLoss
				(
					winlostdate, Currency, ProductCode, Turnover, BTActualStake,
					Winlost, LicenseeWL, AmtDueToBA, CommBA,
					PlayerComm, Betcount, licenseeWLBT, BetTradeComm,
					WLBetTicket, WLBoughtTicket, BuyBackAmtSB, BuyBackAmtBA, CashOutComm
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
					0 AS WLBetTicket,
					0 AS WLBoughtTicket,
					0 AS BuyBackAmtSB,
					0 AS BuyBackAmtBA,
					SUM(CASE WHEN b.bettype = 913 THEN b.awinlost ELSE 0 END) AS CashOutComm
				FROM
					dbo.bettrans b WITH (NOLOCK)
					INNER JOIN @tempAg a ON b.recommend = a.custID AND b.currency = a.currency
				WHERE
					b.winlostdate BETWEEN @TempFromDate AND @_ToDate
					AND b.bettype IN (911, 912, 913)
					AND b.statusID IN (111, 112, 113)
					AND b.transid >= @transid
				GROUP BY
					b.winlostdate,
					a.currency
			END

			IF 1 IN (@ShowNG, @ShowVS, @ShowCS, @ShowKN, @ShowAGC, @ShowVB, @ShowAB, @ShowFW, @ShowVS2, @ShowLT, @ShowPP, @ShowCC, @ShowSG, @ShowVRG, @ShowTG, @ShowI4D, 
				@ShowSXG, @ShowSBC, @ShowSAG, @ShowPGS, @ShowJK, @ShowGDG, @ShowSLT, @ShowHB, @ShowWM)
			BEGIN
				INSERT INTO #SAgWinLoss
				(
					winlostdate, Currency, ProductCode, Turnover, BTActualStake,
					Winlost, LicenseeWL, AmtDueToBA, CommBA,
					PlayerComm, Betcount, licenseeWLBT, BetTradeComm,
					WLBetTicket, WLBoughtTicket, BuyBackAmtSB, BuyBackAmtBA, CashOutComm
				)
				SELECT
					b.winlostdate,
					a.currency,
					bt.ProductCode,
					SUM(CASE WHEN RAND() + 1 > 0 AND @drawfilter IN (2, 3) AND b.statusID = 111 THEN 0 ELSE stake END) AS turnover,
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
					0 AS CashOutComm
				FROM
					dbo.bettrans b WITH (NOLOCK)
					INNER JOIN @tempAg a ON b.recommend = a.custID AND b.Currency = a.Currency
					INNER JOIN @bettype bt ON b.bettype = bt.bettype
				WHERE 
					b.winlostdate BETWEEN @TempFromDate AND @_ToDate
					AND b.statusID IN (111, 112, 113)
					AND b.transid >= @transid
					AND (b.bettype NOT BETWEEN 1611 AND 1699 OR b.matchid <> 150)
				GROUP BY
					b.winlostdate,
					a.currency,
					bt.ProductCode
			END

			-- check promotion prize - PP promotion prize and NPH Promotion prize and Tips --
			IF @CheckPromotionPrize = 1 AND EXISTS (
				SELECT TOP(1) 1
				FROM dbo.bettrans b WITH (NOLOCK)
					INNER JOIN @tempAg a ON b.recommend = a.custID AND b.currency = a.currency
				WHERE b.winlostdate BETWEEN @TempFromDate AND @_ToDate
					AND ((b.bettype IN (SELECT Bettype FROM @ExcludedBetType WHERE ProductCode <> 'SB') OR (b.bettype BETWEEN 1611 AND 1699 AND b.matchid = 150)) AND b.statusID IN (111,112,113)))
			BEGIN
				SET @PromotionPrize = 1
			END
		END
		ELSE
		BEGIN
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
					WLBetTicket, WLBoughtTicket, BuyBackAmtSB, BuyBackAmtBA, CashOutComm
				)
				SELECT
					b.winlostdate,
					b.currency,
					'BA',
					SUM(CASE WHEN RAND() + 1 > 0 THEN stake ELSE 0 END
						*
						CASE WHEN @drawfilter IN (2, 3) THEN
							CASE
								WHEN b.statusID = 111 THEN 0
								WHEN b.winlostdate >= @HWHLCutDate AND b.statusID IN (112, 113) AND b.modds IN (-0.25, 0.25) AND b.bettype NOT IN (29,38) THEN 0.5 -- exclude parlay, bet builder
								WHEN b.winlostdate < @HWHLCutDate AND (b.statusID = 112 OR b.statusID = 113) AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18,124,125,482,483,484,485) THEN 0.5
								ELSE 1 END
						ELSE 1 END
					) AS turnover, 
					0 AS BTActualStake,
					SUM(CASE WHEN RAND() + 1 > 0 THEN b.winlost-b.actual_stake ELSE 0 END) AS Winlost,
					0 AS LicenseeWL,
					-SUM(CASE WHEN RAND() + 1 > 0 THEN b.winlost-b.actual_stake+awinlost+comm ELSE 0 END) AS AmountDueToBA,
					SUM(CASE WHEN RAND() + 1 > 0 THEN comm ELSE 0 END) AS CommBA,
					SUM(ISNULL(CASE WHEN RAND() + 1 > 0 THEN b.playercomm ELSE 0 END,0)) AS PlayerComm,
					COUNT(CASE WHEN RAND() + 1 > 0 AND @drawfilter = 2 AND b.statusID = 111 THEN NULL ELSE b.transid END) AS BetCount,
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
					INNER JOIN @VIPCust v ON b.custid = v.CustID
				WHERE 
					b.winlostdate BETWEEN @TempFromDate AND @_ToDate
					AND b.statusID IN (111, 112, 113)
					AND (b.bettype < 901 OR b.bettype > 904)
					AND (b.bettype < 911 OR b.bettype > 914)
					AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.BetType = b.BetType)
				GROUP BY
					b.winlostdate,
					b.currency 
				OPTION(RECOMPILE)
			END
	
			IF @ShowSB = 1
			BEGIN
				INSERT INTO #SAgWinLoss
				(
					winlostdate, Currency, ProductCode, Turnover, BTActualStake,
					Winlost, LicenseeWL, AmtDueToBA, CommBA,
					PlayerComm, Betcount, licenseeWLBT, BetTradeComm,  
					WLBetTicket, WLBoughtTicket, BuyBackAmtSB, BuyBackAmtBA, CashOutComm
				)
				SELECT
					b.winlostdate,
					b.currency,
					'SB',
					SUM(CASE WHEN RAND() + 1 > 0 THEN stake ELSE 0 END
						*
						CASE WHEN @drawfilter IN (2, 3) THEN
							CASE
								WHEN b.statusID = 111 THEN 0
								WHEN b.winlostdate >= @HWHLCutDate AND b.statusID IN (112, 113) AND b.modds IN (-0.25, 0.25) AND b.bettype NOT IN (29,38) THEN 0.5 -- exclude parlay, bet builder
								WHEN b.winlostdate < @HWHLCutDate AND (b.statusID = 112 OR b.statusID = 113) AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18,124,125,482,483,484,485) THEN 0.5
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
					0 AS CashOutComm
				FROM
					dbo.bettrans b WITH (NOLOCK)
					INNER JOIN @VIPCust v ON b.custid = v.CustID
				WHERE 
					b.winlostdate BETWEEN @TempFromDate AND @_ToDate
					AND
					(
						b.bettype <= 30
						OR b.bettype BETWEEN 121 AND 999
						OR b.Bettype BETWEEN 1301 AND 1399 --new tennis's bettypes
						OR b.Bettype BETWEEN 9001 AND 9399 -- E-Sports 2.0
						OR b.Bettype BETWEEN 9400 AND 9699 -- Cricket AIO
						OR b.Bettype = 38				   -- Single Match Parlay
					)
					AND b.statusID IN (111, 112, 113)
					AND b.tpositiontaking <> 0
					AND (b.bettype < 901 OR b.bettype > 904)
					AND (b.bettype < 911 OR b.bettype > 914)
					AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE  e.ProductCode = 'SB' AND e.BetType = b.BetType)
					AND b.transid >= @transid
				GROUP BY
					b.winlostdate,
					b.currency --, statusID, b.bettype
			END

			IF @ShowBT = 1
			BEGIN
				INSERT INTO #SAgWinLoss
				(
					winlostdate, Currency, ProductCode, Turnover, BTActualStake,
					Winlost, LicenseeWL, AmtDueToBA, CommBA,
					PlayerComm, Betcount, licenseeWLBT, BetTradeComm,
					WLBetTicket, WLBoughtTicket, BuyBackAmtSB, BuyBackAmtBA, CashOutComm
				)
				SELECT
					b.winlostdate,
					b.currency,
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
					0 AS CashOutComm
				FROM
					dbo.bettrans b WITH (NOLOCK)
					INNER JOIN @VIPCust v ON b.custid = v.CustID
				WHERE
					b.winlostdate BETWEEN @TempFromDate AND @_ToDate
					AND b.bettype IN (901, 902, 903)
					AND b.statusID IN (111, 112, 113)
					AND b.transid >= @transid
				GROUP BY
					b.winlostdate,
					b.currency
			END

			IF @ShowCO = 1
			BEGIN
				INSERT INTO #SAgWinLoss
				(
					winlostdate, Currency, ProductCode, Turnover, BTActualStake,
					Winlost, LicenseeWL, AmtDueToBA, CommBA,
					PlayerComm, Betcount, licenseeWLBT, BetTradeComm,
					WLBetTicket, WLBoughtTicket, BuyBackAmtSB, BuyBackAmtBA, CashOutComm
				)
				SELECT
					b.winlostdate,
					b.currency,
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
					0 AS WLBetTicket,
					0 AS WLBoughtTicket,
					0 AS BuyBackAmtSB,
					0 AS BuyBackAmtBA,
					SUM(CASE WHEN b.bettype = 913 THEN b.awinlost ELSE 0 END) AS CashOutComm
				FROM
					dbo.bettrans b WITH (NOLOCK)
					INNER JOIN @VIPCust v ON b.custid = v.CustID
				WHERE
					b.winlostdate BETWEEN @TempFromDate AND @_ToDate
					AND b.bettype IN (911, 912, 913)
					AND b.statusID IN (111, 112, 113)
					AND b.transid >= @transid
				GROUP BY
					b.winlostdate,
					b.currency
			END

			IF 1 IN (@ShowNG, @ShowVS, @ShowCS, @ShowKN, @ShowAGC, @ShowVB, @ShowAB, @ShowFW, @ShowVS2, @ShowLT, @ShowPP, @ShowCC, @ShowSG, @ShowVRG, @ShowTG, @ShowI4D, 
				@ShowSXG, @ShowSBC, @ShowJK, @ShowGDG, @ShowSLT, @ShowHB, @ShowWM)
			BEGIN
				INSERT INTO #SAgWinLoss
				(
					winlostdate, Currency, ProductCode, Turnover, BTActualStake,
					Winlost, LicenseeWL, AmtDueToBA, CommBA,
					PlayerComm, Betcount, licenseeWLBT, BetTradeComm,
					WLBetTicket, WLBoughtTicket, BuyBackAmtSB, BuyBackAmtBA, CashOutComm
				)
				SELECT
					b.winlostdate,
					b.currency,
					bt.ProductCode,
					SUM(CASE WHEN RAND() + 1 > 0 AND @drawfilter IN (2, 3) AND b.statusID = 111 THEN 0 ELSE stake END) AS turnover,
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
					0 AS CashOutComm
				FROM
					dbo.bettrans b WITH (NOLOCK)
					INNER JOIN @VIPCust v ON b.custid = v.CustID
					INNER JOIN @bettype bt ON b.bettype = bt.bettype
				WHERE 
					b.winlostdate BETWEEN @TempFromDate AND @_ToDate
					AND b.statusID IN (111, 112, 113)
					AND b.transid >= @transid
					AND (b.bettype NOT BETWEEN 1611 AND 1699 OR b.matchid <> 150)
				GROUP BY
					b.winlostdate,
					b.currency,
					bt.ProductCode
			END

			-- check promotion prize - PP promotion prize and NPH Promotion prize --
			IF @CheckPromotionPrize = 1 AND EXISTS (
				SELECT TOP(1) 1
				FROM dbo.bettrans b WITH (NOLOCK)
					INNER JOIN @VIPCust v ON b.custid = v.CustID
				WHERE b.winlostdate BETWEEN @TempFromDate AND @_ToDate
					AND ((b.bettype IN (SELECT Bettype FROM @ExcludedBetType WHERE ProductCode <> 'SB') OR (b.bettype BETWEEN 1611 AND 1699 AND b.matchid = 150)) AND b.statusID IN (111,112,113)))
			BEGIN
				SET @PromotionPrize = 1
			END
		END
	END

	IF @_FromDate <= @MoveBetsDay 
	BEGIN
		IF @_ToDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @_ToDate
	
		DECLARE @CustBettrade TABLE (Recommend INT, CustId INT, Currency INT)

		INSERT INTO @CustBettrade
		SELECT
			c.recommend,
			bt.custID,
			bt.currency 
		FROM f_GetBetTradeCustList(@LicenseeName) bt
			INNER JOIN dbo.Customer c WITH(NOLOCK) ON bt.custID = c.custid AND c.roleid = 1

		IF @VIPPlayerOnly = 0
		BEGIN
			IF @ShowBA = 1
			BEGIN
				INSERT INTO #SAgWinLoss
				(
					winlostdate, Currency, ProductCode, Turnover, BTActualStake,
					Winlost, LicenseeWL, AmtDueToBA, CommBA,
					PlayerComm, Betcount, licenseeWLBT, BetTradeComm,  
					WLBetTicket, WLBoughtTicket, BuyBackAmtSB, BuyBackAmtBA, CashOutComm
				)
				SELECT
					b.winlostdate,
					b.currency,
					'BA',
					SUM(CASE WHEN RAND() + 1 > 0 THEN b.turnover ELSE 0 END
						*
						CASE WHEN @drawfilter IN (2, 3) THEN
							CASE
								WHEN b.statusID = 111 THEN 0
								WHEN b.statusID IN (114, 115) THEN 0.5
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
					0 AS CashOutComm
				FROM
					bodb_licenseereport.dbo.rptLicWinloss2 b WITH (NOLOCK)
					INNER JOIN @tempAg ag ON b.recommend = ag.custID AND b.Currency = ag.currency
				WHERE
					b.Winlostdate BETWEEN @_FromDate AND @TempToDate
					AND (b.bettype < 901 OR b.bettype > 904)
					AND (b.bettype < 911 OR b.bettype > 914)
					AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.BetType = b.BetType)
					AND b.roleid = 1
					AND b.statusID <> 101 --exclude REJECT bets
					AND b.isBA = 1 
				GROUP BY
					b.winlostdate,
					b.currency

				INSERT INTO @WLBetTicket (
					WinLostDate,
					Currency,
					WLBetTicket)
				SELECT
					b.winlostdate,
					b.currency,
					SUM(b.winlost)
				FROM
					bodb_licenseereport.dbo.rptLicWinloss2 b WITH (NOLOCK)
					INNER JOIN @CustBettrade ag
						ON b.recommend = ag.recommend
						AND b.custid = ag.custid
						AND b.Currency = ag.currency
				WHERE
					b.Winlostdate BETWEEN @_FromDate AND @TempToDate
					AND (b.bettype < 901 OR b.bettype > 904)
					AND (b.bettype < 911 OR b.bettype > 914)
					AND b.roleid = 1
					AND b.statusID <> 101 --exclude REJECT bets
					AND b.isBA = 1
				GROUP BY
					b.winlostdate,
					b.currency
			END
	
			--exclude BA tickets
			IF 1 IN (@showSB, @ShowNG, @ShowVS, @ShowCS, @ShowKN, @ShowAGC, @ShowVB, @ShowAB, @ShowFW, @ShowVS2, @ShowLT, @ShowPP, @ShowCC, @ShowSG, @ShowVRG, @ShowTG, @ShowI4D, 
				@ShowSXG, @ShowSBC, @ShowSAG, @ShowPGS, @ShowJK, @ShowGDG, @ShowSLT, @ShowHB, @ShowWM)
			BEGIN
				INSERT INTO #SAgWinLoss
				(
					winlostdate, Currency, ProductCode, Turnover, BTActualStake,
					Winlost, LicenseeWL, AmtDueToBA, CommBA,
					PlayerComm, Betcount, licenseeWLBT, BetTradeComm,
					WLBetTicket, WLBoughtTicket, BuyBackAmtSB, BuyBackAmtBA, CashOutComm
				)
				SELECT
					b.winlostdate,
					b.currency,
					t.ProductCode,
					SUM(CASE WHEN RAND() + 1 > 0 THEN b.turnover ELSE 0 END
						*
						CASE WHEN RAND() + 1 > 0 AND @drawfilter IN (2, 3) THEN
							CASE
								WHEN b.statusID = 111 THEN 0
								WHEN b.statusID IN (114, 115) THEN 0.5
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
					0 AS CashOutComm
				FROM
					bodb_licenseereport.dbo.rptLicWinloss2 b WITH (NOLOCK)
					INNER JOIN @tempAg ag ON b.recommend = ag.custID AND ag.currency = b.Currency
					INNER JOIN @SportType t ON b.sporttype = t.SportType
				WHERE
					b.Winlostdate BETWEEN @_FromDate AND @TempToDate
					AND (b.bettype < 901 OR b.bettype > 904)
					AND (b.bettype < 911 OR b.bettype > 914)
					AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.BetType = b.BetType)
					AND b.roleid = 1
					AND b.statusID <> 101 --exclude REJECT bets
					AND b.isBA = 0
				GROUP BY
					b.winlostdate,
					b.currency,
					t.ProductCode

				INSERT INTO @WLBetTicket(
					WinLostDate,
					Currency,
					WLBetTicket)
				SELECT
					b.winlostdate,
					b.currency,
					SUM(b.winlost)
				FROM 
					bodb_licenseereport.dbo.rptLicWinloss2 b WITH (NOLOCK)
					INNER JOIN @CustBettrade ag
						ON b.recommend = ag.recommend
						AND b.custid = ag.custid
						AND b.Currency = ag.currency
				WHERE
					b.Winlostdate BETWEEN @_FromDate AND @TempToDate
					AND (b.bettype < 901 OR b.bettype > 904)
					AND (b.bettype < 911 OR b.bettype > 914)
					AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.BetType = b.BetType)
					AND b.roleid = 1
					AND b.statusID <> 101 --exclude REJECT bets
					AND b.isBA = 0
					AND b.sporttype = 0
				GROUP BY
					b.winlostdate,
					b.currency
			END

			IF @ShowBT = 1
			BEGIN
				INSERT INTO #SAgWinLoss
				(
					winlostdate, Currency, ProductCode, Turnover, BTActualStake,
					Winlost, LicenseeWL, AmtDueToBA, CommBA,
					PlayerComm, Betcount, licenseeWLBT, BetTradeComm,
					WLBetTicket, WLBoughtTicket, BuyBackAmtSB, BuyBackAmtBA, CashOutComm
				)
				SELECT
					b.winlostdate,
					ag.currency,
					'BT',
					0 AS turnover,
					SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 902 THEN b.winlost + BuyBackAmt + BABuyBackAmt ELSE 0 END) AS BTActualStake,
					SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 903 THEN 0 ELSE b.winlost END) AS Winlost,
					0 AS LicenseeWL,
					0 AS AmountDueToBA,
					0 AS CommBA,
					0 AS PlayerComm,
					SUM(CASE WHEN RAND() + 1 > 0 AND ((b.bettype = 903) OR (@drawfilter = 2 AND b.statusID = 111)) THEN 0 ELSE b.BetCount END) AS BetCount,
					-SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype IN (901, 902) THEN b.winlost ELSE 0 END) AS licenseeWLBT,
					SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 903 THEN b.awinlost ELSE 0 END) AS BetTradeComm,
					0 WLBetTicket,
					SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 902 THEN b.winlost ELSE 0 END) AS WLBoughtTicket,
					SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 902 THEN BuyBackAmt ELSE 0 END) AS BuyBackAmtSB,
					SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 902 THEN BABuyBackAmt ELSE 0 END) AS BuyBackAmtBA,
					0 AS CashOutComm
				FROM
					bodb_licenseereport.dbo.rptLicWinloss2 b WITH (NOLOCK)
					INNER JOIN @tempAg ag ON b.recommend = ag.custID AND ag.currency = b.Currency
				WHERE 
					b.Winlostdate BETWEEN @_FromDate AND @TempToDate
					AND b.bettype IN (901, 902, 903)
					AND b.statusID IN (111, 112, 113)
					AND b.roleid = 1 
				GROUP BY b.winlostdate,
					ag.currency,
					b.bettype
			END

			IF @ShowCO = 1
			BEGIN
				INSERT INTO #SAgWinLoss
				(
					winlostdate, Currency, ProductCode, Turnover, BTActualStake,
					Winlost, LicenseeWL, AmtDueToBA, CommBA,
					PlayerComm, Betcount, licenseeWLBT, BetTradeComm, 
					WLBetTicket, WLBoughtTicket, BuyBackAmtSB, BuyBackAmtBA, CashOutComm
				)
				SELECT
					b.winlostdate,
					ag.currency,
					'CO',
					0 AS turnover,
					0 AS BTActualStake,
					SUM(CASE WHEN b.bettype = 913 THEN 0 ELSE b.winlost END) AS Winlost,    
					- SUM(CASE WHEN b.bettype = 913 THEN 0 ELSE b.winlost END) AS LicenseeWL,
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
					INNER JOIN @tempAg ag ON b.recommend = ag.custID AND ag.currency = b.Currency
				WHERE 
					b.Winlostdate BETWEEN @_FromDate AND @TempToDate
					AND b.bettype IN (911, 912, 913) 
					AND b.statusID IN (111, 112, 113)
					AND b.roleid = 1 
				GROUP BY
					b.winlostdate,
					ag.currency
			END
	
			-- check promotion prize - PP promotion prize and NPH Promotion prize and Tips --
			IF @CheckPromotionPrize = 1
				AND @PromotionPrize = 0
				AND EXISTS (	SELECT TOP(1) 1
								FROM bodb_licenseereport.dbo.rptLicWinloss2 b WITH (NOLOCK)
									INNER JOIN @tempAg ag ON b.recommend = ag.custID AND ag.currency = b.Currency
								WHERE b.Winlostdate BETWEEN @_FromDate AND @TempToDate
									AND ((b.bettype IN (SELECT Bettype FROM @ExcludedBetType WHERE ProductCode <> 'SB') OR b.sporttype = 150) AND b.statusID IN (111,112,113))
									AND b.roleid = 2)
			BEGIN
				SET @PromotionPrize = 1
			END
		END
		ELSE
		BEGIN
			IF @ShowBA = 1
			BEGIN
				INSERT INTO #SAgWinLoss
				(
					winlostdate, Currency, ProductCode, Turnover, BTActualStake,
					Winlost, LicenseeWL, AmtDueToBA, CommBA,
					PlayerComm, Betcount, licenseeWLBT, BetTradeComm,  
					WLBetTicket, WLBoughtTicket, BuyBackAmtSB, BuyBackAmtBA, CashOutComm
				)
				SELECT
					b.winlostdate,
					b.currency,
					'BA',
					SUM(CASE WHEN RAND() + 1 > 0 THEN b.turnover ELSE 0 END
						*
						CASE WHEN @drawfilter IN (2, 3) THEN
							CASE
								WHEN b.statusID = 111 THEN 0
								WHEN b.statusID IN (114, 115) THEN 0.5
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
					0 AS CashOutComm
				FROM
					bodb_licenseereport.dbo.rptLicWinloss2 b WITH (NOLOCK)
					INNER JOIN @VIPCust v ON b.custid = v.CustID
				WHERE
					b.Winlostdate BETWEEN @_FromDate AND @TempToDate
					AND (b.bettype < 901 OR b.bettype > 904)
					AND (b.bettype < 911 OR b.bettype > 914)
					AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.BetType = b.BetType)
					AND b.roleid = 1
					AND b.statusID <> 101 --exclude REJECT bets
					AND b.isBA = 1 
				GROUP BY
					b.winlostdate,
					b.currency

				INSERT INTO @WLBetTicket (
					WinLostDate,
					Currency,
					WLBetTicket)
				SELECT
					b.winlostdate,
					b.currency,
					SUM(b.winlost)
				FROM
					bodb_licenseereport.dbo.rptLicWinloss2 b WITH (NOLOCK)
					INNER JOIN @CustBettrade ag
						ON b.recommend = ag.recommend
						AND b.custid = ag.custid
						AND b.Currency = ag.currency
					INNER JOIN @VIPCust v ON b.custid = v.CustID
				WHERE
					b.Winlostdate BETWEEN @_FromDate AND @TempToDate
					AND (b.bettype < 901 OR b.bettype > 904)
					AND (b.bettype < 911 OR b.bettype > 914)
					AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.BetType = b.BetType)
					AND b.roleid = 1
					AND b.statusID <> 101 --exclude REJECT bets
					AND b.isBA = 1
				GROUP BY
					b.winlostdate,
					b.currency
			END
	
			--exclude BA tickets
			IF 1 IN (@showSB, @ShowNG, @ShowVS, @ShowCS, @ShowKN, @ShowAGC, @ShowVB, @ShowAB, @ShowFW, @ShowVS2, @ShowLT, @ShowPP, @ShowCC, @ShowSG, @ShowVRG, @ShowTG, @ShowI4D, 
				@ShowSXG, @ShowSBC, @ShowJK, @ShowGDG, @ShowSLT, @ShowHB, @ShowWM)
			BEGIN
				INSERT INTO #SAgWinLoss
				(
					winlostdate, Currency, ProductCode, Turnover, BTActualStake,
					Winlost, LicenseeWL, AmtDueToBA, CommBA,
					PlayerComm, Betcount, licenseeWLBT, BetTradeComm,
					WLBetTicket, WLBoughtTicket, BuyBackAmtSB, BuyBackAmtBA, CashOutComm
				)
				SELECT
					b.winlostdate,
					b.currency,
					t.ProductCode,
					SUM(CASE WHEN RAND() + 1 > 0 THEN b.turnover ELSE 0 END
						*
						CASE WHEN RAND() + 1 > 0 AND @drawfilter IN (2, 3) THEN
							CASE
								WHEN b.statusID = 111 THEN 0
								WHEN b.statusID IN (114, 115) THEN 0.5
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
					0 AS CashOutComm
				FROM
					bodb_licenseereport.dbo.rptLicWinloss2 b WITH (NOLOCK)
					INNER JOIN @SportType t ON b.sporttype = t.SportType
					INNER JOIN @VIPCust v ON b.custid = v.CustID
				WHERE
					b.Winlostdate BETWEEN @_FromDate AND @TempToDate
					AND (b.bettype < 901 OR b.bettype > 904)
					AND (b.bettype < 911 OR b.bettype > 914)
					AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.BetType = b.BetType)
					AND b.roleid = 1
					AND b.statusID <> 101 --exclude REJECT bets
					AND b.isBA = 0 
				GROUP BY
					b.winlostdate,
					b.currency,
					t.ProductCode

				INSERT INTO @WLBetTicket(
					WinLostDate,
					Currency,
					WLBetTicket)
				SELECT
					b.winlostdate,
					b.currency,
					SUM(b.winlost)
				FROM 
					bodb_licenseereport.dbo.rptLicWinloss2 b WITH (NOLOCK)
					INNER JOIN @CustBettrade ag
						ON b.recommend = ag.recommend
						AND b.custid = ag.custid
						AND b.Currency = ag.currency
					INNER JOIN @VIPCust v ON b.custid = v.CustID
				WHERE
					b.Winlostdate BETWEEN @_FromDate AND @TempToDate
					AND (b.bettype < 901 OR b.bettype > 904)
					AND (b.bettype < 911 OR b.bettype > 914)
					AND b.roleid = 1
					AND b.statusID <> 101 --exclude REJECT bets
					AND b.isBA = 0
					AND b.sporttype = 0
				GROUP BY
					b.winlostdate,
					b.currency
			END

			IF @ShowBT = 1
			BEGIN
				INSERT INTO #SAgWinLoss
				(
					winlostdate, Currency, ProductCode, Turnover, BTActualStake,
					Winlost, LicenseeWL, AmtDueToBA, CommBA,
					PlayerComm, Betcount, licenseeWLBT, BetTradeComm,
					WLBetTicket, WLBoughtTicket, BuyBackAmtSB, BuyBackAmtBA, CashOutComm
				)
				SELECT
					b.winlostdate,
					b.currency,
					'BT',
					0 AS turnover,
					SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 902 THEN b.winlost + BuyBackAmt + BABuyBackAmt ELSE 0 END) AS BTActualStake,
					SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 903 THEN 0 ELSE b.winlost END) AS Winlost,
					0 AS LicenseeWL,
					0 AS AmountDueToBA,
					0 AS CommBA,
					0 AS PlayerComm,
					SUM(CASE WHEN RAND() + 1 > 0 AND ((b.bettype = 903) OR (@drawfilter = 2 AND b.statusID = 111)) THEN 0 ELSE b.BetCount END) AS BetCount,
					-SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype IN (901, 902) THEN b.winlost ELSE 0 END) AS licenseeWLBT,
					SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 903 THEN b.awinlost ELSE 0 END) AS BetTradeComm,
					0 WLBetTicket,
					SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 902 THEN b.winlost ELSE 0 END) AS WLBoughtTicket,
					SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 902 THEN BuyBackAmt ELSE 0 END) AS BuyBackAmtSB,
					SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 902 THEN BABuyBackAmt ELSE 0 END) AS BuyBackAmtBA,
					0 AS CashOutComm
				FROM
					bodb_licenseereport.dbo.rptLicWinloss2 b WITH (NOLOCK)
					INNER JOIN @VIPCust v ON b.custid = v.CustID
				WHERE 
					b.Winlostdate BETWEEN @_FromDate AND @TempToDate
					AND b.bettype IN (901, 902, 903)
					AND b.statusID IN (111, 112, 113)
					AND b.roleid = 1 
				GROUP BY b.winlostdate,
					b.currency,
					b.bettype
			END

			IF @ShowCO = 1
			BEGIN
				INSERT INTO #SAgWinLoss
				(
					winlostdate, Currency, ProductCode, Turnover, BTActualStake,
					Winlost, LicenseeWL, AmtDueToBA, CommBA,
					PlayerComm, Betcount, licenseeWLBT, BetTradeComm, 
					WLBetTicket, WLBoughtTicket, BuyBackAmtSB, BuyBackAmtBA, CashOutComm
				)
				SELECT
					b.winlostdate,
					b.currency,
					'CO',
					0 AS turnover,
					0 AS BTActualStake,
					SUM(CASE WHEN b.bettype = 913 THEN 0 ELSE b.winlost END) AS Winlost,    
					- SUM(CASE WHEN b.bettype = 913 THEN 0 ELSE b.winlost END) AS LicenseeWL,
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
					INNER JOIN @VIPCust v ON b.custid = v.CustID
				WHERE 
					b.Winlostdate BETWEEN @_FromDate AND @TempToDate
					AND b.bettype IN (911, 912, 913) 
					AND b.statusID IN (111, 112, 113)
					AND b.roleid = 1 
				GROUP BY
					b.winlostdate,
					b.currency
			END
	
			-- check promotion prize - PP promotion prize and NPH Promotion prize --
			IF @CheckPromotionPrize = 1
				AND @PromotionPrize = 0
				AND EXISTS (	SELECT TOP(1) 1
								FROM bodb_licenseereport.dbo.rptLicWinloss2 b WITH (NOLOCK)
									INNER JOIN @VIPCust v ON b.custid = v.CustID
								WHERE b.Winlostdate BETWEEN @_FromDate AND @TempToDate
									AND ((b.bettype IN (SELECT Bettype FROM @ExcludedBetType WHERE ProductCode <> 'SB') OR b.sporttype = 150) AND b.statusID IN (111,112,113))
									AND b.roleid = 1)
			BEGIN
				SET @PromotionPrize = 1
			END
		END
	END

	DECLARE @SAgWL TABLE
	( 
		winlostdate			SMALLDATETIME,
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
		TurnoverCC			MONEY,
		TurnoverSG			MONEY,
		TurnoverVRG			MONEY,
		TurnoverTG			MONEY,
		TurnoverI4D			MONEY,
		TurnoverSXG			MONEY,
		TurnoverSBC			MONEY,
		TurnoverSAG			MONEY,
		TurnoverPGS			MONEY,
		TurnoverJK			MONEY,
		TurnoverGDG			MONEY,
		TurnoverSLT			MONEY,
		TurnoverHB			MONEY,
		TurnoverWM			MONEY,
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
		LicenseeWLCC		MONEY,
		LicenseeWLSG		MONEY,
		LicenseeWLVRG		MONEY,
		LicenseeWLTG		MONEY,
		LicenseeWLI4D		MONEY,
		LicenseeWLSXG		MONEY,
		LicenseeWLSBC		MONEY,
		LicenseeWLSAG		MONEY,
		LicenseeWLPGS		MONEY,
		LicenseeWLJK		MONEY,
		LicenseeWLGDG		MONEY,
		LicenseeWLSLT		MONEY,
		LicenseeWLHB		MONEY,
		LicenseeWLWM		MONEY,
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
		UNIQUE CLUSTERED (winlostdate, currency)
	)

	INSERT INTO @SAgWL
	(
		winlostdate, Currency,
		TurnoverSB, TurnoverBA, TurnoverNG, TurnoverVS, TurnoverCS, TurnoverKN, turnoverAGC, turnoverVB, turnoverAB, 
		turnoverFW, turnoverCO, TurnoverVS2, TurnoverLT, TurnoverPP, TurnoverCC, TurnoverSG, TurnoverVRG, TurnoverTG,
		TurnoverI4D, TurnoverSXG, TurnoverSBC, TurnoverSAG,  TurnoverPGS, TurnoverJK, TurnoverGDG, TurnoverSLT, TurnoverHB, TurnoverWM,
		BTActualStake, Winlost,
		LicenseeWLSB, LicenseeWLBA, LicenseeWLNG, LicenseeWLVS, LicenseeWLCS,
		LicenseeWLKN, LicenseeWLAGC, LicenseeWLVB, LicenseeWLAB, LicenseeWLFW, LicenseeWLCO, LicenseeWLVS2, LicenseeWLLT,
		LicenseeWLPP, LicenseeWLCC, LicenseeWLSG, LicenseeWLVRG, LicenseeWLTG, LicenseeWLI4D,  LicenseeWLSXG, LicenseeWLSBC, 
		LicenseeWLSAG, LicenseeWLPGS, LicenseeWLJK, LicenseeWLGDG, LicenseeWLSLT, LicenseeWLHB, LicenseeWLWM,
		AmtDueToBA,
		CommBA,
		PlayerComm,
		Betcount,
		licenseeWLBT,
		BetTradeComm,
		WLBetTicket, WLBoughtTicket,
		BuyBackAmtSB, BuyBackAmtBA,
		CashOutComm
	)
	SELECT
		winlostdate,
		Currency,
		SUM(CASE ProductCode WHEN 'SB'	THEN Turnover ELSE 0 END)	AS TurnoverSB,
		SUM(CASE ProductCode WHEN 'BA'	THEN Turnover ELSE 0 END)	AS TurnoverBA,
		SUM(CASE ProductCode WHEN 'NG'	THEN Turnover ELSE 0 END)	AS TurnoverNG,
		SUM(CASE ProductCode WHEN 'VS'	THEN Turnover ELSE 0 END)	AS TurnoverVS,
		SUM(CASE ProductCode WHEN 'CS'	THEN Turnover ELSE 0 END)	AS TurnoverCS,
		SUM(CASE ProductCode WHEN 'KN'	THEN Turnover ELSE 0 END)	AS TurnoverKN,
		SUM(CASE ProductCode WHEN 'AGC'	THEN Turnover ELSE 0 END)	AS TurnoverAGC,
		SUM(CASE ProductCode WHEN 'VB'	THEN Turnover ELSE 0 END)	AS TurnoverVB,
		SUM(CASE ProductCode WHEN 'AB'	THEN Turnover ELSE 0 END)	AS TurnoverAB,
		SUM(CASE ProductCode WHEN 'FW'	THEN Turnover ELSE 0 END)	AS TurnoverFW,
		SUM(CASE ProductCode WHEN 'CO'	THEN Turnover ELSE 0 END)	AS TurnoverCO,
		SUM(CASE ProductCode WHEN 'VS2'	THEN Turnover ELSE 0 END)	AS TurnoverVS2,
		SUM(CASE ProductCode WHEN 'LT'	THEN Turnover ELSE 0 END)	AS TurnoverLT,
		SUM(CASE ProductCode WHEN 'PP'	THEN Turnover ELSE 0 END)	AS TurnoverPP,
		SUM(CASE ProductCode WHEN 'CC'	THEN Turnover ELSE 0 END)	AS TurnoverCC,
		SUM(CASE ProductCode WHEN 'SG'	THEN Turnover ELSE 0 END)	AS TurnoverSG,
		SUM(CASE ProductCode WHEN 'VRG'	THEN Turnover ELSE 0 END)	AS TurnoverVRG,
		SUM(CASE ProductCode WHEN 'TG'	THEN Turnover ELSE 0 END)	AS TurnoverTG,
		SUM(CASE ProductCode WHEN 'I4D'	THEN Turnover ELSE 0 END)	AS TurnoverI4D,
		SUM(CASE ProductCode WHEN 'SXG'	THEN Turnover ELSE 0 END)	AS TurnoverSXG,
		SUM(CASE ProductCode WHEN 'SBC'	THEN Turnover ELSE 0 END)	AS TurnoverSBC,
		SUM(CASE ProductCode WHEN 'SAG'	THEN Turnover ELSE 0 END)	AS TurnoverSAG,
		SUM(CASE ProductCode WHEN 'PGS'	THEN Turnover ELSE 0 END)	AS TurnoverPGS,
		SUM(CASE ProductCode WHEN 'JK'	THEN Turnover ELSE 0 END)	AS TurnoverJK,
		SUM(CASE ProductCode WHEN 'GDG'	THEN Turnover ELSE 0 END)	AS TurnoverGDG,
		SUM(CASE ProductCode WHEN 'SLT'	THEN Turnover ELSE 0 END)	AS TurnoverSLT,
		SUM(CASE ProductCode WHEN 'HB'	THEN Turnover ELSE 0 END)	AS TurnoverHB,
		SUM(CASE ProductCode WHEN 'WM'	THEN Turnover ELSE 0 END)	AS TurnoverWM,
		SUM(BTActualStake)	AS BTActualStake,
		SUM(Winlost)		AS Winlost,
		SUM(CASE ProductCode WHEN 'SB'	THEN LicenseeWL ELSE 0 END)	AS LicenseeWLSB,
		SUM(CASE ProductCode WHEN 'BA'	THEN LicenseeWL ELSE 0 END)	AS LicenseeWLBA,
		SUM(CASE ProductCode WHEN 'NG'	THEN LicenseeWL ELSE 0 END)	AS LicenseeWLNG,
		SUM(CASE ProductCode WHEN 'VS'	THEN LicenseeWL ELSE 0 END)	AS LicenseeWLVS,
		SUM(CASE ProductCode WHEN 'CS'	THEN LicenseeWL ELSE 0 END)	AS LicenseeWLCS,
		SUM(CASE ProductCode WHEN 'KN'	THEN LicenseeWL ELSE 0 END)	AS LicenseeWLKN,
		SUM(CASE ProductCode WHEN 'AGC'	THEN LicenseeWL ELSE 0 END)	AS LicenseeWLAGC,
		SUM(CASE ProductCode WHEN 'VB'	THEN LicenseeWL ELSE 0 END)	AS LicenseeWLVB,
		SUM(CASE ProductCode WHEN 'AB'	THEN LicenseeWL ELSE 0 END)	AS LicenseeWLAB,
		SUM(CASE ProductCode WHEN 'FW'	THEN LicenseeWL ELSE 0 END)	AS LicenseeWLFW,
		SUM(CASE ProductCode WHEN 'CO'	THEN LicenseeWL ELSE 0 END)	AS LicenseeWLCO,
		SUM(CASE ProductCode WHEN 'VS2'	THEN LicenseeWL ELSE 0 END)	AS LicenseeWLVS2,
		SUM(CASE ProductCode WHEN 'LT'	THEN LicenseeWL ELSE 0 END)	AS LicenseeWLLT,
		SUM(CASE ProductCode WHEN 'PP'	THEN LicenseeWL ELSE 0 END)	AS LicenseeWLPP,
		SUM(CASE ProductCode WHEN 'CC'	THEN LicenseeWL ELSE 0 END)	AS LicenseeWLCC,
		SUM(CASE ProductCode WHEN 'SG'	THEN LicenseeWL ELSE 0 END)	AS LicenseeWLSG,
		SUM(CASE ProductCode WHEN 'VRG'	THEN LicenseeWL ELSE 0 END)	AS LicenseeWLVRG,
		SUM(CASE ProductCode WHEN 'TG'	THEN LicenseeWL ELSE 0 END)	AS LicenseeWLTG,
		SUM(CASE ProductCode WHEN 'I4D'	THEN LicenseeWL ELSE 0 END)	AS LicenseeWLI4D,
		SUM(CASE ProductCode WHEN 'SXG'	THEN LicenseeWL ELSE 0 END)	AS LicenseeWLSXG,
		SUM(CASE ProductCode WHEN 'SBC'	THEN LicenseeWL ELSE 0 END)	AS LicenseeWLSBC,
		SUM(CASE ProductCode WHEN 'SAG'	THEN LicenseeWL ELSE 0 END)	AS LicenseeWLSAG,
		SUM(CASE ProductCode WHEN 'PGS'	THEN LicenseeWL ELSE 0 END)	AS LicenseeWLPGS,
		SUM(CASE ProductCode WHEN 'JK'	THEN LicenseeWL ELSE 0 END)	AS LicenseeWLJK,
		SUM(CASE ProductCode WHEN 'GDG'	THEN LicenseeWL ELSE 0 END)	AS LicenseeWLGDG,
		SUM(CASE ProductCode WHEN 'SLT'	THEN LicenseeWL ELSE 0 END)	AS LicenseeWLSLT,
		SUM(CASE ProductCode WHEN 'HB'	THEN LicenseeWL ELSE 0 END)	AS LicenseeWLHB,
		SUM(CASE ProductCode WHEN 'WM'	THEN LicenseeWL ELSE 0 END)	AS LicenseeWLWM,
		SUM(AmtDuetoBA)		AS AmtDuetoBA,
		SUM(CommBA)			AS CommBA,
		SUM(playerComm)		AS PlayerComm,
		SUM(Betcount)		AS Betcount,
		SUM(licenseeWLBT)	AS licenseeWLBT,
		SUM(BetTradeComm)	AS BetTradeComm,
		SUM(WLBetTicket)	AS WLBetTicket,
		SUM(WLBoughtTicket)	AS WLBoughtTicket,
		SUM(BuyBackAmtSB)	AS BuyBackAmtSB,
		SUM(BuyBackAmtBA)	AS BuyBackAmtBA,
		SUM(CashOutComm)	AS CashOutComm
	FROM #SAgWinLoss
	GROUP BY winlostdate, Currency

	UPDATE s
	SET s.WLBetTicket = s.WLBetTicket + w.WLBetTicket
	FROM
		@SAgWL s
		INNER JOIN (	SELECT
							SUM(WLBetTicket) WLBetTicket,
							WinLostDate,
							Currency
						FROM @WLBetTicket
						GROUP BY winlostdate, currency ) w
			ON s.winlostdate = w.winlostdate AND s.currency = w.currency-- AND s.statusID = w.statusID

	IF EXISTS (SELECT TOP (1) 1 FROM #SAgWinLoss)
	BEGIN
		INSERT INTO @ExchangeRate(FromDate, ToDate, ExchangeID, USD, EUR, GBP, Rate, DefaultRate)
		SELECT FromDate, ToDate, ExchangeID, USD, EUR, GBP, Rate, DefaultRate
		FROM dbo.Lrf_f_GetExchangeRate(@_FromDate, @_ToDate, @BaseCurrency, @DefaultBaseCurrency) e
		WHERE EXISTS (SELECT 1 FROM @tempAg a WHERE e.ExchangeID = a.Currency)
	END

	SELECT
		CASE
			WHEN @ReportType = 1 THEN CONVERT(VARCHAR(8),w.winlostdate,112)
			WHEN @ReportType = 2 THEN CONVERT(VARCHAR(6),w.winlostdate,112)
			ELSE '0'
		END ReportType,
		Currency,

		CAST(SUM(TurnoverSB		*e.Rate)	AS MONEY)   AS TurnoverSB,
		CAST(SUM(TurnoverBA		*e.Rate)	AS MONEY)   AS TurnoverBA,
		CAST(SUM(TurnoverNG		*e.Rate)	AS MONEY)   AS TurnoverNG,
		CAST(SUM(TurnoverVS		*e.Rate)	AS MONEY)	AS TurnoverVS,
		CAST(SUM(TurnoverCS		*e.Rate)	AS MONEY)   AS TurnoverCS,
		CAST(SUM(TurnoverKN		*e.Rate)	AS MONEY)   AS TurnoverKN,
		CAST(SUM(TurnoverAGC	*e.Rate)	AS MONEY)   AS TurnoverAGC,
		CAST(SUM(TurnoverVB		*e.Rate)	AS MONEY)   AS TurnoverVB,
		CAST(SUM(TurnoverAB		*e.Rate)	AS MONEY)   AS TurnoverAB,
		CAST(SUM(TurnoverFW		*e.Rate)	AS MONEY)   AS TurnoverFW,
		CAST(SUM(TurnoverCO		*e.Rate)	AS MONEY)   AS TurnoverCO,
		CAST(SUM(TurnoverVS2	*e.Rate)	AS MONEY)   AS TurnoverVS2,
		CAST(SUM(TurnoverLT		*e.Rate)	AS MONEY)   AS TurnoverLT,
		CAST(SUM(TurnoverPP		*e.Rate)	AS MONEY)   AS TurnoverPP,
		CAST(SUM(TurnoverCC		*e.Rate)	AS MONEY)   AS TurnoverCC,
		CAST(SUM(TurnoverSG		*e.Rate)	AS MONEY)   AS TurnoverSG,
		CAST(SUM(TurnoverVRG	*e.Rate)	AS MONEY)   AS TurnoverVRG,
		CAST(SUM(TurnoverTG		*e.Rate)	AS MONEY)   AS TurnoverTG,
		CAST(SUM(TurnoverI4D	*e.Rate)	AS MONEY)   AS TurnoverI4D,
		CAST(SUM(TurnoverSXG	*e.Rate)	AS MONEY)   AS TurnoverSXG,
		CAST(SUM(TurnoverSBC	*e.Rate)	AS MONEY)   AS TurnoverSBC,
		CAST(SUM(TurnoverSAG	*e.Rate)	AS MONEY)   AS TurnoverSAG,
		CAST(SUM(TurnoverPGS	*e.Rate)	AS MONEY)   AS TurnoverPGS,
		CAST(SUM(TurnoverJK		*e.Rate)	AS MONEY)   AS TurnoverJK,
		CAST(SUM(TurnoverGDG	*e.Rate)	AS MONEY)   AS TurnoverGDG,
		CAST(SUM(TurnoverSLT	*e.Rate)	AS MONEY)   AS TurnoverSLT,
		CAST(SUM(TurnoverHB		*e.Rate)	AS MONEY)   AS TurnoverHB,
		CAST(SUM(TurnoverWM		*e.Rate)	AS MONEY)   AS TurnoverWM,
		CAST(SUM(BTActualStake	*e.Rate)	AS MONEY)   AS BTActualStake,
		CAST(SUM(Winlost		*e.Rate)	AS MONEY)	AS Winlost,
		CAST(SUM(LicenseeWLSB	*e.Rate)	AS MONEY)	AS LicenseeWLSB,
		CAST(SUM(LicenseeWLBA	*e.Rate)	AS MONEY)	AS LicenseeWLBA,
		CAST(SUM(LicenseeWLNG	*e.Rate)	AS MONEY) 	AS LicenseeWLNG,
		CAST(SUM(LicenseeWLVS	*e.Rate)	AS MONEY)	AS LicenseeWLVS,
		CAST(SUM(LicenseeWLCS	*e.Rate)	AS MONEY)	AS LicenseeWLCS,
		CAST(SUM(LicenseeWLKN	*e.Rate)	AS MONEY)	AS LicenseeWLKN,
		CAST(SUM(LicenseeWLAGC	*e.Rate)	AS MONEY)	AS LicenseeWLAGC,
		CAST(SUM(LicenseeWLVB	*e.Rate)	AS MONEY)	AS LicenseeWLVB,
		CAST(SUM(LicenseeWLAB	*e.Rate)	AS MONEY)	AS LicenseeWLAB,
		CAST(SUM(LicenseeWLFW	*e.Rate)	AS MONEY)	AS LicenseeWLFW,
		CAST(SUM(LicenseeWLCO	*e.Rate)	AS MONEY)	AS LicenseeWLCO,
		CAST(SUM(LicenseeWLVS2	*e.Rate)	AS MONEY)	AS LicenseeWLVS2,
		CAST(SUM(LicenseeWLLT	*e.Rate)	AS MONEY)	AS LicenseeWLLT,
		CAST(SUM(LicenseeWLPP	*e.Rate)	AS MONEY)	AS LicenseeWLPP,
		CAST(SUM(LicenseeWLCC	*e.Rate)	AS MONEY)	AS LicenseeWLCC,
		CAST(SUM(LicenseeWLSG	*e.Rate)	AS MONEY)	AS LicenseeWLSG,
		CAST(SUM(LicenseeWLVRG	*e.Rate)	AS MONEY)	AS LicenseeWLVRG,
		CAST(SUM(LicenseeWLTG	*e.Rate)	AS MONEY)	AS LicenseeWLTG,
		CAST(SUM(LicenseeWLI4D	*e.Rate)	AS MONEY)	AS LicenseeWLI4D,
		CAST(SUM(LicenseeWLSXG	*e.Rate)	AS MONEY)	AS LicenseeWLSXG,
		CAST(SUM(LicenseeWLSBC	*e.Rate)	AS MONEY)	AS LicenseeWLSBC,
		CAST(SUM(LicenseeWLSAG	*e.Rate)	AS MONEY)	AS LicenseeWLSAG,
		CAST(SUM(LicenseeWLPGS	*e.Rate)	AS MONEY)	AS LicenseeWLPGS,
		CAST(SUM(LicenseeWLJK	*e.Rate)	AS MONEY)	AS LicenseeWLJK,
		CAST(SUM(LicenseeWLGDG	*e.Rate)	AS MONEY)	AS LicenseeWLGDG,
		CAST(SUM(LicenseeWLSLT	*e.Rate)	AS MONEY)	AS LicenseeWLSLT,
		CAST(SUM(LicenseeWLHB	*e.Rate)	AS MONEY)	AS LicenseeWLHB,
		CAST(SUM(LicenseeWLWM	*e.Rate)	AS MONEY)	AS LicenseeWLWM,
		CAST(SUM(CommBA			*e.Rate)	AS MONEY)	AS CommBA,
		CAST(SUM(PlayerComm		*e.Rate)	AS MONEY)	AS PlayerComm,
		CAST(SUM(AmtDuetoBA		*e.Rate)	AS MONEY)	AS AmtDuetoBA,
		CAST(SUM(licenseeWLBT	*e.Rate)	AS MONEY)   AS licenseeWLBT,
		CAST(SUM(BetTradeComm	*e.Rate)	AS MONEY)	AS BetTradeComm,
		CAST(SUM((WLBetTicket+WLBoughtTicket-BetTradeComm)* e.Rate) AS MONEY)	AS AmtDueToBT,
		CAST(SUM(BuyBackAmtSB	*e.Rate)	AS MONEY)	AS BuyBackAmtSB,
		CAST(SUM(BuyBackAmtBA	*e.Rate)	AS MONEY)	AS BuyBackAmtBA,
		CAST(SUM(CashOutComm	*e.Rate)	AS MONEY)	AS CashOutComm,
		SUM(Betcount)									AS Betcount
	FROM
		@SAgWL w
		INNER JOIN @ExchangeRate e ON w.winlostdate BETWEEN e.FromDate AND e.ToDate AND w.currency = e.ExchangeId
	GROUP BY
		w.Currency,
		CASE
			WHEN @ReportType = 1 THEN CONVERT(VARCHAR(8), w.winlostdate, 112)
			WHEN @ReportType = 2 THEN CONVERT(VARCHAR(6), w.winlostdate, 112)
			ELSE '0'
		END
	ORDER BY ReportType

	SELECT
		CAST(SUM(TurnoverSB		*e.USD)	AS MONEY)	AS TurnoverSBUSD,
		CAST(SUM(TurnoverBA		*e.USD)	AS MONEY)	AS TurnoverBAUSD,
		CAST(SUM(TurnoverNG		*e.USD)	AS MONEY)	AS TurnoverNGUSD,
		CAST(SUM(TurnoverVS		*e.USD)	AS MONEY)	AS TurnoverVSUSD,
		CAST(SUM(TurnoverCS		*e.USD)	AS MONEY)	AS TurnoverCSUSD,
		CAST(SUM(TurnoverKN		*e.USD)	AS MONEY)	AS TurnoverKNUSD,
		CAST(SUM(TurnoverAGC	*e.USD)	AS MONEY)	AS TurnoverAGCUSD,
		CAST(SUM(TurnoverVB		*e.USD)	AS MONEY)	AS TurnoverVBUSD,
		CAST(SUM(TurnoverAB		*e.USD)	AS MONEY)	AS TurnoverABUSD,
		CAST(SUM(TurnoverFW		*e.USD)	AS MONEY)	AS TurnoverFWUSD,
		CAST(SUM(TurnoverCO		*e.USD)	AS MONEY)	AS TurnoverCOUSD,
		CAST(SUM(TurnoverVS2	*e.USD)	AS MONEY)	AS TurnoverVS2USD,
		CAST(SUM(TurnoverLT		*e.USD)	AS MONEY)	AS TurnoverLTUSD,
		CAST(SUM(TurnoverPP		*e.USD)	AS MONEY)	AS TurnoverPPUSD,
		CAST(SUM(TurnoverCC		*e.USD)	AS MONEY)	AS TurnoverCCUSD,
		CAST(SUM(TurnoverSG		*e.USD)	AS MONEY)	AS TurnoverSGUSD,
		CAST(SUM(TurnoverVRG	*e.USD)	AS MONEY)	AS TurnoverVRGUSD,
		CAST(SUM(TurnoverTG		*e.USD)	AS MONEY)	AS TurnoverTGUSD,
		CAST(SUM(TurnoverI4D	*e.USD)	AS MONEY)	AS TurnoverI4DUSD,
		CAST(SUM(TurnoverSXG	*e.USD)	AS MONEY)	AS TurnoverSXGUSD,
		CAST(SUM(TurnoverSBC	*e.USD)	AS MONEY)	AS TurnoverSBCUSD,
		CAST(SUM(TurnoverSAG	*e.USD)	AS MONEY)   AS TurnoverSAGUSD,
		CAST(SUM(TurnoverPGS	*e.USD)	AS MONEY)	AS TurnoverPGSUSD,
		CAST(SUM(TurnoverJK		*e.USD)	AS MONEY)	AS TurnoverJKUSD,
		CAST(SUM(TurnoverGDG	*e.USD)	AS MONEY)	AS TurnoverGDGUSD,
		CAST(SUM(TurnoverSLT	*e.USD)	AS MONEY)	AS TurnoverSLTUSD,
		CAST(SUM(TurnoverHB		*e.USD)	AS MONEY)	AS TurnoverHBUSD,
		CAST(SUM(TurnoverWM		*e.USD)	AS MONEY)	AS TurnoverWMUSD,
		CAST(SUM(BTActualStake	*e.USD)	AS MONEY)	AS BTActualStakeUSD,
		CAST(SUM(Winlost		*e.USD)	AS MONEY)	AS WinlostUSD,
		CAST(SUM(LicenseeWLSB	*e.USD)	AS MONEY)	AS LicenseeWLSBUSD,
		CAST(SUM(LicenseeWLBA	*e.USD)	AS MONEY)	AS LicenseeWLBAUSD,
		CAST(SUM(LicenseeWLNG	*e.USD)	AS MONEY)	AS LicenseeWLNGUSD,
		CAST(SUM(LicenseeWLVS	*e.USD)	AS MONEY)	AS LicenseeWLVSUSD,
		CAST(SUM(LicenseeWLCS	*e.USD)	AS MONEY)	AS LicenseeWLCSUSD,
		CAST(SUM(LicenseeWLKN	*e.USD)	AS MONEY)	AS LicenseeWLKNUSD,
		CAST(SUM(LicenseeWLAGC	*e.USD)	AS MONEY)	AS LicenseeWLAGCUSD,
		CAST(SUM(LicenseeWLVB	*e.USD)	AS MONEY)	AS LicenseeWLVBUSD,
		CAST(SUM(LicenseeWLAB	*e.USD)	AS MONEY)	AS LicenseeWLABUSD,
		CAST(SUM(LicenseeWLFW	*e.USD)	AS MONEY)	AS LicenseeWLFWUSD,
		CAST(SUM(LicenseeWLCO	*e.USD)	AS MONEY)	AS LicenseeWLCOUSD,
		CAST(SUM(LicenseeWLVS2	*e.USD)	AS MONEY)	AS LicenseeWLVS2USD,
		CAST(SUM(LicenseeWLLT	*e.USD)	AS MONEY)	AS LicenseeWLLTUSD,
		CAST(SUM(LicenseeWLPP	*e.USD)	AS MONEY)	AS LicenseeWLPPUSD,
		CAST(SUM(LicenseeWLCC	*e.USD)	AS MONEY)	AS LicenseeWLCCUSD,
		CAST(SUM(LicenseeWLSG	*e.USD)	AS MONEY)	AS LicenseeWLSGUSD,
		CAST(SUM(LicenseeWLVRG	*e.USD)	AS MONEY)	AS LicenseeWLVRGUSD,
		CAST(SUM(LicenseeWLTG	*e.USD)	AS MONEY)	AS LicenseeWLTGUSD,
		CAST(SUM(LicenseeWLI4D	*e.USD)	AS MONEY)	AS LicenseeWLI4DUSD,
		CAST(SUM(LicenseeWLSXG	*e.USD)	AS MONEY)	AS LicenseeWLSXGUSD,
		CAST(SUM(LicenseeWLSBC	*e.USD)	AS MONEY)	AS LicenseeWLSBCUSD,
		CAST(SUM(LicenseeWLSAG	*e.USD)	AS MONEY)	AS LicenseeWLSAGUSD,
		CAST(SUM(LicenseeWLPGS	*e.USD)	AS MONEY)	AS LicenseeWLPGSUSD,
		CAST(SUM(LicenseeWLJK	*e.USD)	AS MONEY)	AS LicenseeWLJKUSD,
		CAST(SUM(LicenseeWLGDG	*e.USD)	AS MONEY)	AS LicenseeWLGDGUSD,
		CAST(SUM(LicenseeWLSLT	*e.USD)	AS MONEY)	AS LicenseeWLSLTUSD,
		CAST(SUM(LicenseeWLHB	*e.USD)	AS MONEY)	AS LicenseeWLHBUSD,
		CAST(SUM(LicenseeWLWM	*e.USD)	AS MONEY)	AS LicenseeWLWMUSD,
		CAST(SUM(CommBA			*e.USD)	AS MONEY)	AS CommBAUSD,
		CAST(SUM(PlayerComm		*e.USD)	AS MONEY)	AS PlayerCommUSD,
		CAST(SUM(AmtDuetoBA		*e.USD)	AS MONEY)	AS AmtDuetoBAUSD,
		CAST(SUM(licenseeWLBT	*e.USD)	AS MONEY)   AS licenseeWLBTUSD,
		CAST(SUM(BetTradeComm	*e.USD)	AS MONEY)	AS BetTradeCommUSD,
		CAST(SUM((WLBetTicket + WLBoughtTicket - BetTradeComm)* e.USD) AS MONEY)	AS AmtDueToBTUSD,
		CAST(SUM(BuyBackAmtSB	*e.USD)	AS MONEY)	AS BuyBackAmtSBUSD,
		CAST(SUM(BuyBackAmtBA	*e.USD)	AS MONEY)	AS BuyBackAmtBAUSD,
		CAST(SUM(CashOutComm	*e.USD)	AS MONEY)	AS CashOutCommUSD,
		CAST(SUM(TurnoverSB		*e.EUR)	AS MONEY)	AS TurnoverSBEUR,
		CAST(SUM(TurnoverBA		*e.EUR)	AS MONEY)	AS TurnoverBAEUR,
		CAST(SUM(TurnoverNG		*e.EUR)	AS MONEY)	AS TurnoverNGEUR,
		CAST(SUM(TurnoverVS		*e.EUR)	AS MONEY)	AS TurnoverVSEUR,
		CAST(SUM(TurnoverCS		*e.EUR)	AS MONEY)	AS TurnoverCSEUR,
		CAST(SUM(TurnoverKN		*e.EUR)	AS MONEY)	AS TurnoverKNEUR,
		CAST(SUM(TurnoverAGC	*e.EUR)	AS MONEY)	AS TurnoverAGCEUR,
		CAST(SUM(TurnoverVB		*e.EUR)	AS MONEY)	AS TurnoverVBEUR,
		CAST(SUM(TurnoverAB		*e.EUR)	AS MONEY)	AS TurnoverABEUR,
		CAST(SUM(TurnoverFW		*e.EUR)	AS MONEY)	AS TurnoverFWEUR,
		CAST(SUM(TurnoverCO		*e.EUR)	AS MONEY)	AS TurnoverCOEUR,
		CAST(SUM(TurnoverVS2	*e.EUR)	AS MONEY)	AS TurnoverVS2EUR,
		CAST(SUM(TurnoverLT		*e.EUR)	AS MONEY)	AS TurnoverLTEUR,
		CAST(SUM(TurnoverPP		*e.EUR)	AS MONEY)	AS TurnoverPPEUR,
		CAST(SUM(TurnoverCC		*e.EUR)	AS MONEY)	AS TurnoverCCEUR,
		CAST(SUM(TurnoverSG		*e.EUR)	AS MONEY)	AS TurnoverSGEUR,
		CAST(SUM(TurnoverVRG	*e.EUR)	AS MONEY)	AS TurnoverVRGEUR,
		CAST(SUM(TurnoverTG		*e.EUR)	AS MONEY)	AS TurnoverTGEUR,
		CAST(SUM(TurnoverI4D	*e.EUR)	AS MONEY)	AS TurnoverI4DEUR,
		CAST(SUM(TurnoverSXG	*e.EUR)	AS MONEY)	AS TurnoverSXGEUR,
		CAST(SUM(TurnoverSBC	*e.EUR)	AS MONEY)	AS TurnoverSBCEUR,
		CAST(SUM(TurnoverSAG	*e.EUR)	AS MONEY)	AS TurnoverSAGEUR,
		CAST(SUM(TurnoverPGS	*e.EUR)	AS MONEY)	AS TurnoverPGSEUR,
		CAST(SUM(TurnoverJK		*e.EUR)	AS MONEY)	AS TurnoverJKEUR,
		CAST(SUM(TurnoverGDG	*e.EUR)	AS MONEY)	AS TurnoverGDGEUR,
		CAST(SUM(TurnoverSLT	*e.EUR)	AS MONEY)	AS TurnoverSLTEUR,
		CAST(SUM(TurnoverHB		*e.EUR)	AS MONEY)	AS TurnoverHBEUR,
		CAST(SUM(TurnoverWM		*e.EUR)	AS MONEY)	AS TurnoverWMEUR,
		CAST(SUM(BTActualStake	*e.EUR)	AS MONEY)	AS BTActualStakeEUR,
		CAST(SUM(Winlost		*e.EUR)	AS MONEY)	AS WinlostEUR,
		CAST(SUM(LicenseeWLSB	*e.EUR)	AS MONEY)	AS LicenseeWLSBEUR,
		CAST(SUM(LicenseeWLBA	*e.EUR)	AS MONEY)	AS LicenseeWLBAEUR,
		CAST(SUM(LicenseeWLNG	*e.EUR)	AS MONEY) 	AS LicenseeWLNGEUR,
		CAST(SUM(LicenseeWLVS	*e.EUR)	AS MONEY)	AS LicenseeWLVSEUR,
		CAST(SUM(LicenseeWLCS	*e.EUR)	AS MONEY)	AS LicenseeWLCSEUR,
		CAST(SUM(LicenseeWLKN	*e.EUR)	AS MONEY)	AS LicenseeWLKNEUR,
		CAST(SUM(LicenseeWLAGC	*e.EUR)	AS MONEY)	AS LicenseeWLAGCEUR,
		CAST(SUM(LicenseeWLVB	*e.EUR)	AS MONEY)	AS LicenseeWLVBEUR,
		CAST(SUM(LicenseeWLAB	*e.EUR)	AS MONEY)	AS LicenseeWLABEUR,
		CAST(SUM(LicenseeWLFW	*e.EUR)	AS MONEY)	AS LicenseeWLFWEUR,
		CAST(SUM(LicenseeWLCO	*e.EUR)	AS MONEY)	AS LicenseeWLCOEUR,
		CAST(SUM(LicenseeWLVS2	*e.EUR)	AS MONEY)	AS LicenseeWLVS2EUR,
		CAST(SUM(LicenseeWLLT	*e.EUR)	AS MONEY)	AS LicenseeWLLTEUR,
		CAST(SUM(LicenseeWLPP	*e.EUR)	AS MONEY)	AS LicenseeWLPPEUR,
		CAST(SUM(LicenseeWLCC	*e.EUR)	AS MONEY)	AS LicenseeWLCCEUR,
		CAST(SUM(LicenseeWLSG	*e.EUR)	AS MONEY)	AS LicenseeWLSGEUR,
		CAST(SUM(LicenseeWLVRG	*e.EUR)	AS MONEY)	AS LicenseeWLVRGEUR,
		CAST(SUM(LicenseeWLTG	*e.EUR)	AS MONEY)	AS LicenseeWLTGEUR,
		CAST(SUM(LicenseeWLI4D	*e.EUR)	AS MONEY)	AS LicenseeWLI4DEUR,
		CAST(SUM(LicenseeWLSXG	*e.EUR)	AS MONEY)	AS LicenseeWLSXGEUR,
		CAST(SUM(LicenseeWLSBC	*e.EUR)	AS MONEY)	AS LicenseeWLSBCEUR,
		CAST(SUM(LicenseeWLSAG	*e.EUR)	AS MONEY)	AS LicenseeWLSAGEUR,
		CAST(SUM(LicenseeWLPGS	*e.EUR)	AS MONEY)	AS LicenseeWLPGSEUR,
		CAST(SUM(LicenseeWLJK	*e.EUR)	AS MONEY)	AS LicenseeWLJKEUR,
		CAST(SUM(LicenseeWLGDG	*e.EUR)	AS MONEY)	AS LicenseeWLGDGEUR,
		CAST(SUM(LicenseeWLSLT	*e.EUR)	AS MONEY)	AS LicenseeWLSLTEUR,
		CAST(SUM(LicenseeWLHB	*e.EUR)	AS MONEY)	AS LicenseeWLHBEUR,
		CAST(SUM(LicenseeWLWM	*e.EUR)	AS MONEY)	AS LicenseeWLWMEUR,
		CAST(SUM(CommBA			*e.EUR)	AS MONEY)	AS CommBAEUR,
		CAST(SUM(PlayerComm		*e.EUR)	AS MONEY)	AS PlayerCommEUR,
		CAST(SUM(AmtDuetoBA		*e.EUR)	AS MONEY)	AS AmtDuetoBAEUR,
		CAST(SUM(licenseeWLBT	*e.EUR)	AS MONEY)   AS licenseeWLBTEUR,
		CAST(SUM(BetTradeComm	*e.EUR)	AS MONEY)	AS BetTradeCommEUR,
		CAST(SUM((WLBetTicket + WLBoughtTicket - BetTradeComm)* e.EUR) AS MONEY)	AS AmtDueToBTEUR,
		CAST(SUM(BuyBackAmtSB	*e.EUR)	AS MONEY)	AS BuyBackAmtSBEUR,
		CAST(SUM(BuyBackAmtBA	*e.EUR)	AS MONEY)	AS BuyBackAmtBAEUR,
		CAST(SUM(CashOutComm	*e.EUR)	AS MONEY)	AS CashOutCommEUR,
		CAST(SUM(TurnoverSB		*e.GBP)	AS MONEY)	AS TurnoverSBGBP, 
		CAST(SUM(TurnoverBA		*e.GBP)	AS MONEY)	AS TurnoverBAGBP,
		CAST(SUM(TurnoverNG		*e.GBP)	AS MONEY)	AS TurnoverNGGBP,
		CAST(SUM(TurnoverVS		*e.GBP)	AS MONEY)	AS TurnoverVSGBP,
		CAST(SUM(TurnoverCS		*e.GBP)	AS MONEY)	AS TurnoverCSGBP,
		CAST(SUM(TurnoverKN		*e.GBP)	AS MONEY)	AS TurnoverKNGBP,
		CAST(SUM(TurnoverAGC	*e.GBP)	AS MONEY)	AS TurnoverAGCGBP,
		CAST(SUM(TurnoverVB		*e.GBP)	AS MONEY)	AS TurnoverVBGBP,
		CAST(SUM(TurnoverAB		*e.GBP)	AS MONEY)	AS TurnoverABGBP,
		CAST(SUM(TurnoverFW		*e.GBP)	AS MONEY)	AS TurnoverFWGBP,
		CAST(SUM(TurnoverCO		*e.GBP)	AS MONEY)	AS TurnoverCOGBP,
		CAST(SUM(TurnoverVS2	*e.GBP)	AS MONEY)	AS TurnoverVS2GBP,
		CAST(SUM(TurnoverLT		*e.GBP)	AS MONEY)	AS TurnoverLTGBP,
		CAST(SUM(TurnoverPP		*e.GBP)	AS MONEY)	AS TurnoverPPGBP,
		CAST(SUM(TurnoverCC		*e.GBP)	AS MONEY)	AS TurnoverCCGBP,
		CAST(SUM(TurnoverSG		*e.GBP)	AS MONEY)	AS TurnoverSGGBP,
		CAST(SUM(TurnoverVRG	*e.GBP)	AS MONEY)	AS TurnoverVRGGBP,
		CAST(SUM(TurnoverTG		*e.GBP)	AS MONEY)	AS TurnoverTGGBP,
		CAST(SUM(TurnoverI4D	*e.GBP)	AS MONEY)	AS TurnoverI4DGBP,
		CAST(SUM(TurnoverSXG	*e.GBP)	AS MONEY)	AS TurnoverSXGGBP,
		CAST(SUM(TurnoverSBC	*e.GBP)	AS MONEY)	AS TurnoverSBCGBP,
		CAST(SUM(TurnoverSAG	*e.GBP)	AS MONEY)   AS TurnoverSAGGBP,
		CAST(SUM(TurnoverPGS	*e.GBP)	AS MONEY)	AS TurnoverPGSGBP,
		CAST(SUM(TurnoverJK		*e.GBP)	AS MONEY)	AS TurnoverJKGBP,
		CAST(SUM(TurnoverGDG	*e.GBP)	AS MONEY)	AS TurnoverGDGGBP,
		CAST(SUM(TurnoverSLT	*e.GBP)	AS MONEY)	AS TurnoverSLTGBP,
		CAST(SUM(TurnoverHB		*e.GBP)	AS MONEY)	AS TurnoverHBGBP,
		CAST(SUM(TurnoverWM		*e.GBP)	AS MONEY)	AS TurnoverWMGBP,
		CAST(SUM(BTActualStake	*e.GBP)	AS MONEY)	AS BTActualStakeGBP,
		CAST(SUM(Winlost		*e.GBP)	AS MONEY)	AS WinlostGBP,
		CAST(SUM(LicenseeWLSB	*e.GBP)	AS MONEY)	AS LicenseeWLSBGBP,
		CAST(SUM(LicenseeWLBA	*e.GBP)	AS MONEY)	AS LicenseeWLBAGBP,
		CAST(SUM(LicenseeWLNG	*e.GBP)	AS MONEY)	AS LicenseeWLNGGBP,
		CAST(SUM(LicenseeWLVS	*e.GBP)	AS MONEY)	AS LicenseeWLVSGBP,
		CAST(SUM(LicenseeWLCS	*e.GBP)	AS MONEY)	AS LicenseeWLCSGBP,
		CAST(SUM(LicenseeWLKN	*e.GBP)	AS MONEY)	AS LicenseeWLKNGBP,
		CAST(SUM(LicenseeWLAGC	*e.GBP)	AS MONEY)	AS LicenseeWLAGCGBP,
		CAST(SUM(LicenseeWLVB	*e.GBP)	AS MONEY)	AS LicenseeWLVBGBP,
		CAST(SUM(LicenseeWLAB	*e.GBP)	AS MONEY)	AS LicenseeWLABGBP,
		CAST(SUM(LicenseeWLFW	*e.GBP)	AS MONEY)	AS LicenseeWLFWGBP,
		CAST(SUM(LicenseeWLCO	*e.GBP)	AS MONEY)	AS LicenseeWLCOGBP,
		CAST(SUM(LicenseeWLVS2	*e.GBP)	AS MONEY)	AS LicenseeWLVS2GBP,
		CAST(SUM(LicenseeWLLT	*e.GBP)	AS MONEY)	AS LicenseeWLLTGBP,
		CAST(SUM(LicenseeWLPP	*e.GBP)	AS MONEY)	AS LicenseeWLPPGBP,
		CAST(SUM(LicenseeWLCC	*e.GBP)	AS MONEY)	AS LicenseeWLCCGBP,
		CAST(SUM(LicenseeWLSG	*e.GBP)	AS MONEY)	AS LicenseeWLSGGBP,
		CAST(SUM(LicenseeWLVRG	*e.GBP)	AS MONEY)	AS LicenseeWLVRGGBP,
		CAST(SUM(LicenseeWLTG	*e.GBP)	AS MONEY)	AS LicenseeWLTGGBP,
		CAST(SUM(LicenseeWLI4D	*e.GBP)	AS MONEY)	AS LicenseeWLI4DGBP,
		CAST(SUM(LicenseeWLSXG	*e.GBP)	AS MONEY)	AS LicenseeWLSXGGBP,
		CAST(SUM(LicenseeWLSBC	*e.GBP)	AS MONEY)	AS LicenseeWLSBCGBP,
		CAST(SUM(LicenseeWLSAG	*e.GBP)	AS MONEY)	AS LicenseeWLSAGGBP,
		CAST(SUM(LicenseeWLPGS	*e.GBP)	AS MONEY)	AS LicenseeWLPGSGBP,
		CAST(SUM(LicenseeWLJK	*e.GBP)	AS MONEY)	AS LicenseeWLJKGBP,
		CAST(SUM(LicenseeWLGDG	*e.GBP)	AS MONEY)	AS LicenseeWLGDGGBP,
		CAST(SUM(LicenseeWLSLT	*e.GBP)	AS MONEY)	AS LicenseeWLSLTGBP,
		CAST(SUM(LicenseeWLHB	*e.GBP)	AS MONEY)	AS LicenseeWLHBGBP,
		CAST(SUM(LicenseeWLWM	*e.GBP)	AS MONEY)	AS LicenseeWLWMGBP,
		CAST(SUM(CommBA			*e.GBP)	AS MONEY)	AS CommBAGBP,
		CAST(SUM(PlayerComm		*e.GBP)	AS MONEY)	AS PlayerCommGBP,
		CAST(SUM(AmtDuetoBA		*e.GBP)	AS MONEY)	AS AmtDuetoBAGBP,
		CAST(SUM(licenseeWLBT	*e.GBP)	AS MONEY)	AS licenseeWLBTGBP,
		CAST(SUM(BetTradeComm	*e.GBP)	AS MONEY)	AS BetTradeCommGBP,
		CAST(SUM((WLBetTicket+WLBoughtTicket-BetTradeComm)* e.GBP) AS MONEY)	AS AmtDueToBTGBP,
		CAST(SUM(BuyBackAmtSB	*e.GBP)	AS MONEY)	AS BuyBackAmtSBGBP,
		CAST(SUM(BuyBackAmtBA	*e.GBP)	AS MONEY)	AS BuyBackAmtBAGBP,
		CAST(SUM(CashOutComm	*e.GBP)	AS MONEY)	AS CashOutCommGBP,
		CAST(SUM(TurnoverSB		*e.DefaultRate)	AS MONEY)	AS TurnoverSB,
		CAST(SUM(TurnoverBA		*e.DefaultRate)	AS MONEY)	AS TurnoverBA,
		CAST(SUM(TurnoverNG		*e.DefaultRate)	AS MONEY)	AS TurnoverNG,
		CAST(SUM(TurnoverVS		*e.DefaultRate)	AS MONEY)	AS TurnoverVS,
		CAST(SUM(TurnoverCS		*e.DefaultRate)	AS MONEY)	AS TurnoverCS,
		CAST(SUM(TurnoverKN		*e.DefaultRate)	AS MONEY)	AS TurnoverKN,
		CAST(SUM(TurnoverAGC	*e.DefaultRate)	AS MONEY)	AS TurnoverAGC,
		CAST(SUM(TurnoverVB		*e.DefaultRate)	AS MONEY)	AS TurnoverVB,
		CAST(SUM(TurnoverAB		*e.DefaultRate)	AS MONEY)	AS TurnoverAB,
		CAST(SUM(TurnoverFW		*e.DefaultRate)	AS MONEY)	AS TurnoverFW,
		CAST(SUM(TurnoverCO		*e.DefaultRate)	AS MONEY)	AS TurnoverCO,
		CAST(SUM(TurnoverVS2	*e.DefaultRate)	AS MONEY)	AS TurnoverVS2,
		CAST(SUM(TurnoverLT		*e.DefaultRate)	AS MONEY)	AS TurnoverLT,
		CAST(SUM(TurnoverPP		*e.DefaultRate)	AS MONEY)	AS TurnoverPP,
		CAST(SUM(TurnoverCC		*e.DefaultRate)	AS MONEY)	AS TurnoverCC,
		CAST(SUM(TurnoverSG		*e.DefaultRate)	AS MONEY)	AS TurnoverSG,
		CAST(SUM(TurnoverVRG	*e.DefaultRate)	AS MONEY)	AS TurnoverVRG,
		CAST(SUM(TurnoverTG		*e.DefaultRate)	AS MONEY)	AS TurnoverTG,
		CAST(SUM(TurnoverI4D	*e.DefaultRate)	AS MONEY)	AS TurnoverI4D,
		CAST(SUM(TurnoverSXG	*e.DefaultRate)	AS MONEY)	AS TurnoverSXG,
		CAST(SUM(TurnoverSBC	*e.DefaultRate)	AS MONEY)	AS TurnoverSBC,
		CAST(SUM(TurnoverSAG	*e.DefaultRate)	AS MONEY)   AS TurnoverSAG,
		CAST(SUM(TurnoverPGS	*e.DefaultRate)	AS MONEY)	AS TurnoverPGS,
		CAST(SUM(TurnoverJK		*e.DefaultRate)	AS MONEY)	AS TurnoverJK,
		CAST(SUM(TurnoverGDG	*e.DefaultRate)	AS MONEY)	AS TurnoverGDG,
		CAST(SUM(TurnoverSLT	*e.DefaultRate)	AS MONEY)	AS TurnoverSLT,
		CAST(SUM(TurnoverHB		*e.DefaultRate)	AS MONEY)	AS TurnoverHB,
		CAST(SUM(TurnoverWM		*e.DefaultRate)	AS MONEY)	AS TurnoverWM,
		CAST(SUM(BTActualStake	*e.DefaultRate)	AS MONEY)	AS BTActualStake,
		CAST(SUM(Winlost		*e.DefaultRate)	AS MONEY)	AS Winlost,
		CAST(SUM(LicenseeWLSB	*e.DefaultRate)	AS MONEY)	AS LicenseeWLSB,
		CAST(SUM(LicenseeWLBA	*e.DefaultRate)	AS MONEY)	AS LicenseeWLBA,
		CAST(SUM(LicenseeWLNG	*e.DefaultRate)	AS MONEY)	AS LicenseeWLNG,
		CAST(SUM(LicenseeWLVS	*e.DefaultRate)	AS MONEY)	AS LicenseeWLVS,
		CAST(SUM(LicenseeWLCS	*e.DefaultRate)	AS MONEY)	AS LicenseeWLCS,
		CAST(SUM(LicenseeWLKN	*e.DefaultRate)	AS MONEY)	AS LicenseeWLKN,
		CAST(SUM(LicenseeWLAGC	*e.DefaultRate)	AS MONEY)	AS LicenseeWLAGC,
		CAST(SUM(LicenseeWLVB	*e.DefaultRate)	AS MONEY)	AS LicenseeWLVB,
		CAST(SUM(LicenseeWLAB	*e.DefaultRate)	AS MONEY)	AS LicenseeWLAB,
		CAST(SUM(LicenseeWLFW	*e.DefaultRate)	AS MONEY)	AS LicenseeWLFW,
		CAST(SUM(LicenseeWLCO	*e.DefaultRate)	AS MONEY)	AS LicenseeWLCO,
		CAST(SUM(LicenseeWLVS2	*e.DefaultRate)	AS MONEY)	AS LicenseeWLVS2,
		CAST(SUM(LicenseeWLLT	*e.DefaultRate)	AS MONEY)	AS LicenseeWLLT,
		CAST(SUM(LicenseeWLPP	*e.DefaultRate)	AS MONEY)	AS LicenseeWLPP,
		CAST(SUM(LicenseeWLCC	*e.DefaultRate)	AS MONEY)	AS LicenseeWLCC,
		CAST(SUM(LicenseeWLSG	*e.DefaultRate)	AS MONEY)	AS LicenseeWLSG,
		CAST(SUM(LicenseeWLVRG	*e.DefaultRate)	AS MONEY)	AS LicenseeWLVRG,
		CAST(SUM(LicenseeWLTG	*e.DefaultRate)	AS MONEY)	AS LicenseeWLTG,
		CAST(SUM(LicenseeWLI4D	*e.DefaultRate)	AS MONEY)	AS LicenseeWLI4D,
		CAST(SUM(LicenseeWLSXG	*e.DefaultRate)	AS MONEY)	AS LicenseeWLSXG,
		CAST(SUM(LicenseeWLSBC	*e.DefaultRate)	AS MONEY)	AS LicenseeWLSBC,
		CAST(SUM(LicenseeWLSAG	*e.DefaultRate)	AS MONEY)	AS LicenseeWLSAG,
		CAST(SUM(LicenseeWLPGS	*e.DefaultRate)	AS MONEY)	AS LicenseeWLPGS,
		CAST(SUM(LicenseeWLJK	*e.DefaultRate)	AS MONEY)	AS LicenseeWLJK,
		CAST(SUM(LicenseeWLGDG	*e.DefaultRate)	AS MONEY)	AS LicenseeWLGDG,
		CAST(SUM(LicenseeWLSLT	*e.DefaultRate)	AS MONEY)	AS LicenseeWLSLT,
		CAST(SUM(LicenseeWLHB	*e.DefaultRate)	AS MONEY)	AS LicenseeWLHB,
		CAST(SUM(LicenseeWLWM	*e.DefaultRate)	AS MONEY)	AS LicenseeWLWM,
		CAST(SUM(CommBA			*e.DefaultRate)	AS MONEY)	AS CommBA,
		CAST(SUM(PlayerComm		*e.DefaultRate)	AS MONEY)	AS PlayerComm,
		CAST(SUM(AmtDuetoBA		*e.DefaultRate)	AS MONEY)	AS AmtDuetoBA,
		CAST(SUM(licenseeWLBT	*e.DefaultRate)	AS MONEY)	AS licenseeWLBT,
		CAST(SUM(BetTradeComm	*e.DefaultRate)	AS MONEY)	AS BetTradeComm,
		CAST(SUM((WLBetTicket + WLBoughtTicket - BetTradeComm)* e.DefaultRate) AS MONEY)	AS AmtDueToBT,
		CAST(SUM(BuyBackAmtSB	*e.DefaultRate)	AS MONEY)	AS BuyBackAmtSB,
		CAST(SUM(BuyBackAmtBA	*e.DefaultRate)	AS MONEY)	AS BuyBackAmtBA,
		CAST(SUM(CashOutComm	*e.DefaultRate)	AS MONEY)	AS CashOutComm,
		@PromotionPrize										AS PromotionPrize,
		SUM(Betcount)										AS Betcount
	FROM
		@SAgWL w
		INNER JOIN @ExchangeRate e ON w.winlostdate BETWEEN e.FromDate AND e.ToDate AND w.currency = e.ExchangeId

	DROP TABLE #SAgWinLoss
END
GO
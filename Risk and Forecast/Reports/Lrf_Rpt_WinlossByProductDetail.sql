/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_WinlossByProductDetail]
	@AgentList				VARCHAR(MAX),
	@CustId					INT				= 0,	-- AgentID
	@MemberId				INT				= 0,	-- memberID
	@FromDate				SMALLDATETIME,
	@ToDate					SMALLDATETIME,
	@MoveBetsDay			SMALLDATETIME,
	@ProductList			VARCHAR(MAX)	= '',
	@DrawFilter				SMALLINT		= 1,
	@BaseCurrency			VARCHAR(3)		= '',
	@DefaultBaseCurrency	VARCHAR(3)	= ''
AS

/*
	Created: Henry
	Date: 2011-07-06
	Task: Winloss By Product Detail Report for Licensee Member Level
	DB: DBEXT.bodb02

	Revisions:
		- 20111013@Henry: change to use rptLicWinloss2
		- 20111208@Jim: change bettype condition
		- 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily  
		- 20120529@Henry: enhance performance
		- 20120731@Jim: add playercomm value
		- 20120815@Jim: add live casino
		- 20120905@Jim: add virtual sport
		- 20121004@Jim: replace @currency input param by @currencyID
		- 20121022@Jim:  re-calculate AmountDueTo3rd's value 
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
		- 20180723@Harper: Improve performance for winloss by product report [RedmineID: #98358]
		- 20180810@Joseph: Remove table LicenseeCustInfo [RedmineID: #99464]
		- 20181005@Amanda: Remove Racing, Bingo [RedmineID: #99378]
		- 20181031@Patrick: DB052 indexes revolution [RedmineID: #103572]
		- 20181221@Joseph: Integrate Happy 5 for NumberGame [RedmineID: #103698]
		- 20190215@Joseph: HotFix: Licensee WL data isn't included PP ( range: rptLicWinloss2) [RedmineID: #108934]
		- 20190304@Amanda: Integrate PP Promotion Prize [RedmineID: #109471]
		- 20190322@Amanda: Remove MGCLC & MGRnG [RedmineID: #107704]
		- 20190614@Amanda: Add Base currency param [RedmineID: #112531]
		- 20190910@Amanda: Add bet types that support Half Won/ Half Lose [RedmineID: #118300]
		- 20190923@Amanda: Change the way to handle Half Won/ Half Lose bet types [RedmineID: #119879]
		- 20191121@Amanda: Exclude PP Promotion and Tournament Prize [RedmineID: #123804]
		- 20200407@Vickie: HotFix: Licensee WL data isn't included CC, SG, VRG [RedmineID: #131937]
		- 20200408@Hogan: Add new product Table Games [RedmineID: #131447]
		- 20200323@Vickie: Add new product Indo 4D [RedmineID: #130859]
		- 20200423@Hogan: Add new product Sexy Gaming [RedmineID: #132829]
		- 20200423@Vickie: Integrate Saba Club [RedmineID: #132702]
		- 20200714@Hogan: Add 7 games for Jackpot and 2 bettype for Contribution (4297) and Jackpot Prize (4298) [RedmineID: #137290]
		- 20200728@Hogan: Integrate SA Gaming [RedmineID: #128493]
		- 20201016@Hogan: Integrate Arcadia Gaming Bonus [RedmineID: #143648]
		- 20201022@Louis: Integrate PG Soft [RedmineID: #139182]
		- 20201126@Hogan: Integrate Joker [RedmineID: #141408]
		- 20201202@Louis: Licensee Spread Setting [RedmineID: #142532]
		- 20201202@Hogan: Add new sport Saba.club Free Bets [RedmineID: #142369]
		- 20201231@Louis: Integrate Happy 5 Linked Games [RedmineID: #147446]
		- 20200122@Hogan: Integrate GDG [RedmineID: #147267]
		- 20210122@Hogan: Integrate Four Guardians [RedmineID: #148100]
		- 20210305@Hogan: Integrate Sport Lottery [RedmineID: #150872]
		- 20210416@Hogan: Integrate Habanero RNG Games [RedmineID: #150843]
		- 20210428@Hogan: Integrate WM Live Casino [RedmineID: #140944]
		- 20210519@Louis: Integrate Big Gaming product [RedmineID: #146773]
		- 20210525@Hogan: Integrate Vgaming [RedmineID: #151583]
		- 20210630@Hogan: Integrate Creative Gaming [RedmineID: #152619]
		- 20210831@Kos: Enhance performance [RedmineID: #160981]
		- 20211109@Kos: Merge Sports Lottery into Sportsbook [RedmineID: #163191]
		- 20220224@Hogan: Integrate Virtual Sports 3 (Leap Gaming)[RedmineID: #145337]

	Param's Explanation:
		+ @DrawFilter: 'No Draw' filter is supportted (1:Normal 2:No Draw 3:No Draw for Turnover only)
		+ @MoveBetsDay: The day we move tickets to bettrans14
		+ @AgentList: XML structure
			<ROOT>
				<Agent AgentId="12345" Currency="3"/>
				<Agent AgentId="12345" Currency="5"/>
			</ROOT>
*/

BEGIN
	SET NOCOUNT ON

	-- Get agent list
	DECLARE @TempAg AS TABLE (CustId INT PRIMARY KEY, Currency INT)

	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @AgentList

		INSERT INTO @TempAg (CustId, Currency)
		SELECT AgentId, Currency
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId INT, Currency INT) AS Data
		WHERE @CustId = 0 OR AgentId = @CustId

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
			,ErrMsg = N'Parameter invalid.'

		RETURN
	END CATCH;

	-- Get excluded bettype
	DECLARE @ExcludedBetType TABLE (ProductCode VARCHAR (10), BetType INT)

	INSERT INTO @ExcludedBetType (ProductCode, BetType)
	SELECT ProductCode, BetType
	FROM dbo.Lrf_f_SelExcludedBetType()

	-- Get sport/bettype matrix
	DECLARE @BetType	TABLE (BetType INT PRIMARY KEY, ProductCode VARCHAR(10))
	DECLARE @SportType	TABLE (SportType INT PRIMARY KEY, ProductCode VARCHAR(10))

	SET @ProductList = REPLACE(@ProductList, ' ', '')

	---#2: Begin: Get SportBettypeMatrix
	IF LEN(ISNULL(@ProductList, '')) > 0 
	BEGIN
		DECLARE @IsTest BIT = 0

		SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

		INSERT INTO @BetType (BetType, ProductCode)
		SELECT DISTINCT BetType, ProductPrefix
		FROM f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', @ProductList, @IsTest)
		WHERE BetType NOT IN (SELECT BetType FROM @ExcludedBetType e WHERE e.ProductCode = ProductPrefix)
			AND BetType NOT IN (72, 901, 902, 903, 904, 911, 912, 913, 914)

		-- Insert Sport Type
		INSERT INTO @SportType (SportType, ProductCode)
		SELECT DISTINCT SportType, ProductCode
		FROM dbo.f_LicWinLoss_ProductSportType_Sel(@ProductList)
		WHERE ProductCode NOT IN ('VS', 'VS2') AND SportType NOT IN (150, 173)

		-- Group products under SB into SB
		DECLARE @SBProductList VARCHAR(100) = 'SB'

		SET @SBProductList = dbo.Lrf_f_GroupProductCode(@SBProductList)

		UPDATE @BetType
		SET ProductCode = 'SB'
		WHERE ProductCode <> 'SB'
			AND ',' + @SBProductList + ',' LIKE '%,' + ProductCode + ',%'

		UPDATE @SportType
		SET ProductCode = 'SB'
		WHERE ProductCode <> 'SB'
			AND ',' + @SBProductList + ',' LIKE '%,' + ProductCode + ',%'
	END

	CREATE TABLE #SAgWinLoss (
		WinLostDate		DATETIME,
		CustId			INT,
		Currency		INT,
		ProductCode		VARCHAR(10),
		Turnover		MONEY,
		WinLost			MONEY,
		LicenseeWL		MONEY,
		Comm			MONEY,
		PlayerComm		MONEY,
		AmtDueTo3rd		MONEY,
		BetCount		BIGINT
	)

	CREATE NONCLUSTERED INDEX IDX_Index_SA ON #SAgWinLoss(Currency)

	DECLARE @sumTurnOver	BIT = 1
	DECLARE @sumBetCount	BIT = 1
	DECLARE @RCount			INT

	IF @DrawFilter = 2
	BEGIN
		SET @sumTurnOver = 0
		SET @sumBetCount = 0
	END

	IF @DrawFilter = 3
	BEGIN
		SET @sumTurnOver = 0
	END

	DECLARE @TempFromDate DATETIME
	DECLARE @TempToDate DATETIME
	DECLARE @FDate DATETIME
	DECLARE @TDate DATETIME

	-- To Deal With Parameter Sniffing
	SELECT @FDate = @FromDate, @TDate = @ToDate
	
	-- bettrans range
	IF @TDate > @MoveBetsDay
	BEGIN
		IF @FDate <= @MoveBetsDay
			SET @TempFromDate =  DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @FDate

		DECLARE @HWHLCutDate SMALLDATETIME = '2019-10-01' -- half won/ half lose cut date

		---#3.1: Begin: Get data for BA product
		IF PATINDEX('%,BA,%', ',' + @ProductList + ',') > 0  ---- BA Product
		BEGIN
			SELECT DISTINCT transid, r.Currency
			INTO #tmpBA
			FROM bodb_licensee.dbo.LicenseeBATransaction_active BA WITH(NOLOCK)
				INNER JOIN @TempAg r ON BA.recommend = r.custID
			WHERE @MemberID = 0 OR BA.CustId = @MemberID

			INSERT INTO #SAgWinLoss
			SELECT
				b.winlostdate,
				b.custid,
				ba.currency,
				'BA' AS ProductCode,
				SUM(b.stake
					*
					CASE
						WHEN b.statusID = 111 THEN 0|@sumTurnOver
						WHEN b.winlostdate >= @HWHLCutDate
							AND b.statusID IN (112, 113)
							AND b.modds IN (-0.25, 0.25)
							AND b.bettype NOT IN (29,38) THEN (1|@sumTurnOver)/(~@sumTurnOver+1.0) -- exclude parlay, bet builder
						WHEN b.winlostdate < @HWHLCutDate
							AND (b.statusID = 112 OR b.statusID = 113)
							AND ABS(b.modds) = 0.25
							AND b.bettype IN(1,3,7,8,17,18,124,125,482,483,484,485) THEN (1|@sumTurnOver)/(~@sumTurnOver+1.0)
						ELSE 1
					END
				) AS Turnover,
				SUM(b.winlost - b.actual_stake) AS Winlost,
				0 AS LicenseeWL,
				SUM(b.comm) AS Comm,
				SUM(b.playercomm) AS PlayerComm,
				- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd,
				SUM(1 * (CASE WHEN b.statusID = 111 THEN 0|@sumBetCount ELSE 1 END)) AS BetCount
			FROM
				#tmpBA ba
				CROSS APPLY (
					SELECT TOP(1)
						tmp.winlostdate,
						tmp.custid,
						tmp.statusID,
						tmp.modds,
						tmp.bettype,
						tmp.winlost,
						tmp.actual_stake,
						tmp.comm,
						tmp.playercomm,
						tmp.awinlost,
						tmp.stake
					FROM dbo.bettrans tmp WITH ( NOLOCK)
					WHERE tmp.transid = ba.TransID
						AND tmp.currency = ba.Currency
						AND tmp.winlostdate BETWEEN @TempFromDate AND @TDate 
						AND tmp.statusID IN (111, 112, 113)
						AND (@MemberID = 0 OR tmp.CustId = @MemberID)
						AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.BetType = tmp.BetType)
				) AS b
			WHERE (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
			GROUP BY
				b.winlostdate,
				b.custid,
				ba.currency

			DROP TABLE #tmpBA
		END

		---#3.2: Begin: Get data for VS Parlay
		IF EXISTS (SELECT 1 FROM @bettype WHERE ProductCode = 'VS2')
		BEGIN
			INSERT INTO #SAgWinLoss
			SELECT
				b.winlostdate,
				b.custid,
				b.currency,
				'VS2' + CONVERT(VARCHAR(10), s.sporttype) AS ProductCode,
				SUM(b.stake * CASE
								WHEN b.statusID = 111 THEN 0|@sumTurnOver
								ELSE 1
							END) AS Turnover,
				SUM(b.winlost - b.actual_stake) AS Winlost,
				- SUM(b.winlost - b.actual_stake) AS LicenseeWL,
				SUM(b.comm) AS Comm,
				SUM(b.playercomm) AS PlayerComm,
				- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd,
				SUM(1 * (CASE WHEN b.statusID = 111 THEN 0|@sumBetCount ELSE 1 END)) AS BetCount
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				CROSS APPLY (	SELECT TOP 1 m.sporttype
								FROM bodb02.dbo.bettransm bm WITH (NOLOCK)
									INNER JOIN bodb02.dbo.match m WITH (NOLOCK) ON bm.matchid = m.matchid
								WHERE b.refno = bm.refno AND b.custid = bm.custid
							) AS s
				INNER JOIN @TempAg a ON b.recommend = a.custid
			WHERE b.bettype = 2799 -- Betradar VS Parlay
				AND b.winlostdate BETWEEN @TempFromDate AND @TDate
				AND (@MemberID = 0 OR b.CustId = @MemberID)
				AND b.statusID  IN (111, 112, 113)
				AND b.matchid = 2799
			GROUP BY
				b.winlostdate,
				b.custid,
				b.currency,
				'VS2' + CONVERT(VARCHAR(10), s.sporttype)
		END

		---#3.3: Begin: Get data for all products, Exclude VS2 parlay ticket and BA
		IF EXISTS (SELECT 1 FROM @bettype)
		BEGIN
			INSERT INTO #SAgWinLoss
			SELECT
				b.winlostdate,
				b.custid,
				a.currency,
				CASE
					WHEN bt.ProductCode LIKE 'VS%' AND bt.ProductCode <> 'VS3' THEN
						CASE
							WHEN ISNULL(vs.sporttype, 0) = 0 THEN bt.ProductCode + CONVERT(VARCHAR(10), ISNULL(m.sporttype,0))
							ELSE bt.ProductCode + CONVERT(VARCHAR(10), vs.sporttype)
						END
					ELSE bt.ProductCode
				END AS ProductCode,
				SUM(stake *
					CASE 
						WHEN b.statusID = 111 THEN 0|@sumTurnOver
						WHEN bt.ProductCode = 'SB'
							AND b.winlostdate >= @HWHLCutDate
							AND b.statusID IN (112, 113)
							AND b.modds IN (-0.25, 0.25)
							AND b.bettype NOT IN (29,38) THEN (1|@sumTurnOver)/(~@sumTurnOver+1.0) -- exclude parlay, bet builder
						WHEN bt.ProductCode = 'SB'
							AND b.winlostdate < @HWHLCutDate
							AND (b.statusID = 112 OR b.statusID = 113)
							AND ABS(modds) = 0.25
							AND b.bettype IN(1,3,7,8,17,18,124,125,482,483,484,485) THEN (1|@sumTurnOver)/(~@sumTurnOver+1.0)
						ELSE 1 END
				) AS Turnover, 
				SUM(b.winlost - b.actual_stake) AS Winlost,
				- SUM(b.winlost - b.actual_stake) AS LicenseeWL,
				SUM(b.comm) AS Comm,
				SUM(b.playercomm) AS PlayerComm,
				- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AS AmountDueTo3rd,
				SUM(1 * (CASE WHEN b.statusID = 111 THEN 0|@sumBetCount ELSE 1 END)) AS BetCount
			FROM 
				dbo.bettrans b WITH (NOLOCK, INDEX = IX_recommend)
				INNER JOIN @TempAg a ON b.recommend = a.custid
				INNER JOIN @bettype bt ON b.bettype = bt.bettype AND b.bettype <> 2799
				LEFT JOIN dbo.match m WITH(NOLOCK)
					ON b.matchid = m.matchid
					AND b.bettype NOT IN (SELECT bettype FROM dbo.f_VSHorseRacingByBettype())
					AND bt.ProductCode LIKE 'VS%'
				LEFT JOIN (
					SELECT DISTINCT o.Orid, r.SportType
					FROM VSOutright o WITH (NOLOCK)
						INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
				) vs ON b.oddsid = vs.Orid AND b.bettype IN (1231,1232,1233,1237,1238,1220,1235,1236)
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @TDate
				AND (@MemberID = 0 OR b.CustId = @MemberID)
				AND b.statusID  IN (111, 112, 113)
				AND b.matchID > 0 
				AND (CASE WHEN bt.ProductCode ='SB' THEN b.tpositiontaking ELSE 1 END <> 0)  --- EXCLUDE BA 
				AND (b.bettype NOT BETWEEN 1611 AND 1699 OR b.matchid <> 150)
				AND (b.bettype NOT BETWEEN 3801 AND 3899 OR b.matchid <> 173)
			GROUP BY
				b.winlostdate,
				b.custid
				,a.currency
				,CASE
					WHEN bt.ProductCode LIKE 'VS%' AND bt.ProductCode <> 'VS3' THEN
						CASE WHEN ISNULL(vs.sporttype, 0) = 0  
							THEN bt.ProductCode + CONVERT(VARCHAR(10), ISNULL(m.sporttype,0))
							ELSE bt.ProductCode + CONVERT(VARCHAR(10), vs.sporttype)
						END
					ELSE bt.ProductCode
				END
		END
	END
	---#3: END: Get Sum data from bettrans After Move Bets Day  

	---#4: BEGIN: Get Sum data from Sum Table Before Move Bets Day
	IF @FDate <= @MoveBetsDay
	BEGIN
		IF @TDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @TDate

		---#4.1: Begin: Get data for BA product
		IF PATINDEX('%,BA,%', ',' + @ProductList + ',') > 0
		BEGIN
			INSERT INTO #SAgWinLoss
			SELECT
				b.winlostdate,
				b.custid,
				b.currency,
				'BA' AS ProductCode,
				SUM(b.turnover * CASE
									WHEN b.statusID = 111  THEN 0|@sumTurnOver
									WHEN b.statusID IN (114, 115) THEN (1|@sumTurnOver)/(~@sumTurnOver+1.0)
									ELSE 1
								END),
				SUM(b.winlost),
				0 AS LicenseeWL,
				SUM(b.comm) AS Comm,
				SUM(b.playercomm) AS PlayerComm,
				- SUM(b.awinlost + b.winlost + b.comm) AS AmountDueTo3rd,
				SUM(b.betcount * CASE WHEN b.statusID = 111 THEN 0|@sumBetCount ELSE 1 END)
			FROM 
				bodb_licenseereport.dbo.rptLicWinloss2 b WITH (NOLOCK)
				INNER JOIN @TempAg ag ON b.recommend = ag.custID
			WHERE
				b.Winlostdate BETWEEN @FDate AND @TempToDate
				AND (@MemberID = 0 OR b.CustId = @MemberID)
				AND b.roleid = 1
				AND b.statusID <> 101 --exclude REJECT bets
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
				AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.BetType = b.BetType)
				AND ISNULL(b.isBA, 0) = 1
			GROUP BY
				b.winlostdate,
				b.currency,
				b.custid
		END

		---#4.2: Begin: Get data for all products exclude VS, VS2
		IF EXISTS (SELECT 1 FROM @SportType)
		BEGIN
			INSERT INTO #SAgWinLoss
			SELECT
				b.winlostdate,
				b.custid,
				b.currency,
				t.ProductCode,
				SUM(b.turnover * CASE
									WHEN b.statusID = 111  THEN 0|@sumTurnOver
									WHEN b.statusID IN (114, 115) THEN (1|@sumTurnOver)/(~@sumTurnOver+1.0)
									ELSE 1
								END),
				SUM(b.winlost),
				- SUM(b.winlost) AS LicenseeWL,
				SUM(b.comm) AS Comm,
				SUM(b.playercomm) AS PlayerComm,
				- SUM(b.awinlost + b.winlost + b.comm) AS AmountDueTo3rd,
				SUM(b.betcount * CASE WHEN b.statusID = 111 THEN 0|@sumBetCount ELSE 1 END)
			FROM
				bodb_licenseereport.dbo.rptLicWinloss2 b WITH (NOLOCK)
				INNER JOIN @SportType t ON b.sporttype = t.SportType
				INNER JOIN @TempAg ag ON b.recommend = ag.custID
			WHERE
				b.Winlostdate BETWEEN @FDate AND @TempToDate
				AND (@MemberID = 0 OR b.CustId = @MemberID)
				AND b.roleid = 1
				AND b.statusID <> 101 --exclude REJECT bets
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
				AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.BetType = b.BetType)
				AND ISNULL(b.isBA, 0) = 0
			GROUP BY
				b.winlostdate,
				b.currency,
				b.custid,
				t.ProductCode
		END

		---#4.3: Begin: Get data for VS, VS2 from DW
		IF EXISTS (SELECT 1 FROM @bettype WHERE ProductCode IN ('VS', 'VS2'))
		BEGIN
			DECLARE @n INT = 2147483647

			DECLARE @tblVS AS TABLE (
				RptDate		DATETIME,
				SportId		INT,
				CustId		INT,
				Currency	INT,
				Turnover	MONEY,
				WinLoss		MONEY,
				CommissionA	MONEY,
				CommissionP	MONEY,
				WinLossA	MONEY,
				BetCount	INT )

			IF @MemberID <> 0
			BEGIN
				INSERT INTO @tblVS (
					RptDate
					,CustId
					,SportId
					,Currency
					,Turnover
					,WinLoss
					,CommissionA
					,CommissionP
					,WinLossA
					,BetCount)
				SELECT
					 vs.winlostDate
					,vs.CustId
					,vs.sportID
					,t.currency
					,SUM(vs.Turnover)
					,SUM(vs.WinLossP)
					,SUM(vs.CommissionA)
					,SUM(vs.CommissionP)
					,SUM(vs.WinLossA)
					,SUM(vs.Betcount)
				FROM @TempAg t
					CROSS APPLY (
						SELECT TOP (@n)
							DATEADD(MONTH, DATEDIFF(MONTH, 0, b.rptDate), 0) AS WinLostDate,
							b.SportID,
							b.CustID,
							SUM(b.Stake * CASE
												WHEN b.[status] = 3  THEN 0|@sumTurnOver
												WHEN b.[Status] IN (13, 12) THEN (1|@sumTurnOver)/(~@sumTurnOver+1.0)
												ELSE 1
											END) AS Turnover,
							SUM(b.WinlossP) AS WinLossP,
							SUM(b.CommissionA) AS CommissionA,
							SUM(b.commissionP) AS CommissionP,
							SUM(b.WinlossA) AS WinLossA,
							SUM(b.betcount * CASE WHEN b.status = 3 THEN 0|@sumBetCount ELSE 1 END) AS Betcount
						FROM DBWH.bodb_Account.dbo.mcCustVirtualSport b WITH (NOLOCK) 
						WHERE t.CustID = b.recommend
							AND rptdate BETWEEN @FDate AND @TempToDate
							AND status IN (8, 3, 4)
							AND b.CustID = @MemberID
						GROUP BY
							b.rptDate,
							b.CustID,
							b.SportID
					) AS vs
				GROUP BY
					vs.winlostDate,
					vs.CustId,
					vs.sportID,
					t.currency
				OPTION (OPTIMIZE FOR (@n = 1))
			END
			ELSE
			BEGIN
				INSERT INTO @tblVS (
					RptDate
					,CustId
					,SportId
					,Currency
					,Turnover
					,WinLoss
					,CommissionA
					,CommissionP
					,WinLossA
					,BetCount)
				SELECT 
					 vs.winlostDate
					,vs.CustId
					,vs.sportID
					,t.currency
					,SUM(vs.Turnover)
					,SUM(vs.WinlossP)
					,SUM(vs.CommissionA)
					,SUM(vs.commissionP)
					,SUM(vs.WinlossA)
					,SUM(vs.Betcount)
				FROM @TempAg t
					CROSS APPLY (
						SELECT TOP (@n)
							DATEADD(MONTH, DATEDIFF(MONTH, 0, b.rptDate), 0) AS WinLostDate,
							b.CustID,
							b.SportID,
							SUM(b.Stake * CASE
											WHEN b.[status] = 3  THEN 0|@sumTurnOver
											WHEN b.[Status] IN (13,12) THEN (1|@sumTurnOver)/(~@sumTurnOver+1.0)
											ELSE 1
										END) AS Turnover,
							SUM(b.WinlossP) AS WinlossP,
							SUM(b.CommissionA) AS CommissionA,
							SUM(b.commissionP) AS commissionP,
							SUM(b.WinlossA) AS WinlossA,
							SUM(b.betcount * CASE WHEN b.status = 3 THEN 0|@sumBetCount ELSE 1 END) AS Betcount
						FROM DBWH.bodb_Account.dbo.mcCustVirtualSport b WITH (NOLOCK)
						WHERE t.CustID = b.recommend
							AND b.Currency = t.Currency
							AND rptdate BETWEEN @FDate AND @TempToDate
							AND status IN (8,3,4)
						GROUP BY
							b.rptDate,
							b.CustID,
							b.SportID
					) AS vs
				GROUP BY 
					vs.winlostDate
					,vs.CustId
					,vs.sportID
					,t.currency
				OPTION (OPTIMIZE FOR (@n = 1))
			END

			SELECT s.SportType,
				s.ProductPrefix
			INTO #tmpSport
			FROM (	SELECT DISTINCT
						m.SportType,
						p.ProductPrefix
					FROM dbo.SportBettypeMatrix m WITH (NOLOCK)
						INNER JOIN dbo.Products p WITH (NOLOCK) ON m.ProductID = p.ProductID
					WHERE p.ProductPrefix IN ('VS', 'VS2')
						AND m.BetType IN (SELECT bettype FROM @bettype) ) s

			INSERT INTO #SAgWinLoss
			SELECT
				b.RptDate
				,b.CustId
				,b.Currency
				,ts.ProductPrefix + CONVERT(VARCHAR(10), ISNULL(b.sportID,0)) AS ProductCode
				,SUM(b.Turnover)
				,SUM(b.WinLoss)
				,-SUM(b.WinLoss) AS LicenseeWL
				,SUM(b.CommissionA) AS Comm
				,SUM(b.CommissionP) AS PlayerComm,
				- SUM(b.WinLossA + b.WinLoss + b.CommissionA) AS AmountDueTo3rd,
				SUM(b.BetCount)
			FROM @tblVS b
				INNER JOIN #tmpSport ts ON b.sportID = ts.SportType
			GROUP BY
				b.rptdate
				,b.CustID
				,b.currency
				,ts.ProductPrefix + CONVERT(VARCHAR(10), ISNULL(b.sportID, 0))

			DROP TABLE #tmpSport
		END
	END
	---#4: END: Get Sum data from Sum Table Before Move Bets Day 

	-- Get exchange rate
	CREATE TABLE #Exchange (FromDate DATETIME, ToDate DATETIME, ExchangeID INT, USD FLOAT, EUR FLOAT, GBP FLOAT, Rate FLOAT, DefaultRate FLOAT)

	IF EXISTS (SELECT TOP(1) 1 FROM #SAgWinLoss)
	BEGIN
		DECLARE @MinDate SMALLDATETIME,
			@MaxDate SMALLDATETIME

		SELECT @MinDate = MIN (winlostdate),
			@MaxDate = MAX (winlostdate)
		FROM #SAgWinLoss

		INSERT INTO #Exchange(FromDate, ToDate, ExchangeID, USD, EUR, GBP, Rate, DefaultRate)
		SELECT FromDate, ToDate, ExchangeID, USD, EUR, GBP, Rate, DefaultRate
		FROM dbo.Lrf_f_GetExchangeRate(@MinDate, @MaxDate, @BaseCurrency, @DefaultBaseCurrency) e
		WHERE EXISTS (SELECT 1 FROM @TempAg a WHERE e.ExchangeID = a.Currency)
	END

	CREATE NONCLUSTERED INDEX IX_Exchange ON #Exchange (FromDate, ToDate, ExchangeID)

	-- Return result
	SELECT
		c.username,
		SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS Nickname,
		w.CustId,
		w.Currency,
		w.ProductCode,
		SUM(w.BetCount) AS BetCount,
	
		CAST(SUM(w.Turnover		* e.Rate)	AS MONEY)	AS Turnover,
		CAST(SUM(w.WinLost		* e.Rate)	AS MONEY)	AS Winlost,
		CAST(SUM(w.LicenseeWL	* e.Rate)	AS MONEY)	AS LicenseeWL,
		CAST(SUM(w.Comm			* e.Rate)	AS MONEY)	AS Comm,
		CAST(SUM(w.PlayerComm	* e.Rate)	AS MONEY)	AS PlayerComm,
		CAST(SUM(w.AmtDueTo3rd	* e.Rate)	AS MONEY)	AS AmtDueto3rd,

		-- BaseEUR
		CAST(SUM(w.Turnover		* e.EUR)	AS MONEY)	AS TurnoverEUR,
		CAST(SUM(w.WinLost		* e.EUR)	AS MONEY)	AS WinlostEUR,
		CAST(SUM(w.LicenseeWL	* e.EUR)	AS MONEY)	AS LicenseeWLEUR,
		CAST(SUM(w.Comm			* e.EUR)	AS MONEY)	AS CommEUR,
		CAST(SUM(w.PlayerComm	* e.EUR)	AS MONEY)	AS PlayerCommEUR,
		CAST(SUM(w.AmtDueTo3rd	* e.EUR)	AS MONEY)	AS AmtDueto3rdEUR,

		-- BaseUSD
		CAST(SUM(w.Turnover		* e.USD)	AS MONEY)	AS TurnoverUSD,
		CAST(SUM(w.WinLost		* e.USD)	AS MONEY)	AS WinlostUSD,
		CAST(SUM(w.LicenseeWL	* e.USD)	AS MONEY)	AS LicenseeWLUSD,
		CAST(SUM(w.Comm			* e.USD)	AS MONEY)	AS CommUSD,
		CAST(SUM(w.PlayerComm	* e.USD)	AS MONEY)	AS PlayerCommUSD,
		CAST(SUM(w.AmtDueTo3rd	* e.USD)	AS MONEY)	AS AmtDueto3rdUSD,

		-- BaseGBP
		CAST(SUM(w.Turnover		* e.GBP)	AS MONEY)	AS TurnoverGBP,
		CAST(SUM(w.WinLost		* e.GBP)	AS MONEY)	AS WinlostGBP,
		CAST(SUM(w.LicenseeWL	* e.GBP)	AS MONEY)	AS LicenseeWLGBP,
		CAST(SUM(w.Comm			* e.GBP)	AS MONEY)	AS CommGBP,
		CAST(SUM(w.PlayerComm	* e.GBP)	AS MONEY)	AS PlayerCommGBP,
		CAST(SUM(w.AmtDueTo3rd	* e.GBP)	AS MONEY)	AS AmtDueto3rdGBP,

		-- DefaultBaseCurrency
		CAST(SUM(w.Turnover		* e.DefaultRate)	AS MONEY)	AS TurnoverBase,
		CAST(SUM(w.WinLost		* e.DefaultRate)	AS MONEY)	AS WinlostBase,
		CAST(SUM(w.LicenseeWL	* e.DefaultRate)	AS MONEY)	AS LicenseeWLBase,
		CAST(SUM(w.Comm			* e.DefaultRate)	AS MONEY)	AS CommBase,
		CAST(SUM(w.PlayerComm	* e.DefaultRate)	AS MONEY)	AS PlayerCommBase,
		CAST(SUM(w.AmtDueTo3rd	* e.DefaultRate)	AS MONEY)	AS AmtDueto3rdBase
	FROM
		#SAgWinLoss AS w
		INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON w.custid = c.custid
		INNER JOIN #Exchange AS e ON e.ExchangeID = w.Currency AND w.winlostdate BETWEEN e.FromDate AND e.ToDate
	GROUP BY
		w.custid,
		c.username,
		c.username2,
		w.Currency,
		Productcode
	ORDER BY c.username ASC

	DROP TABLE #SAgWinLoss
	DROP TABLE #Exchange
END
GO

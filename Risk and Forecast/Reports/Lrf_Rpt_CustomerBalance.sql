/*<info serverAlias="DBACC-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_CustomerBalance]
	@AgentList		VARCHAR(MAX),
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@ProductList	VARCHAR(500),
	@ShowBT			BIT			= 0,		-- Bet Trade
	@ShowCO			BIT			= 0,		-- Cash Out
	@OrderItem		TINYINT		= 1,
	@TopCount		INT			= 0,
	@PageSize		INT			= 1000,
	@PageIndex		INT			= 1
AS

/*
	Created: 20120917@Henry
	Task : Report Customer Balance
	DB: DBACC.bodb02
	Original: Lrf_Rpt_CustomerTurnOver

	Revisions:
		- 20120917@henry: change SP name Lrf_Rpt_CustomerTurnOver to Lrf_Rpt_CustomerBalance + split column
		- 20121004@Jim: replace @currency input param by @currencyID
		- 20130117@henry: enhance performance
		- 20130123@Daniel: Change link server alias
		- 20130225@Scott: support RNG Casino ,Bingo
		- 20130618@Jim:  Restrict permission of Licensee Users by currency
		- 20130809@Jim: offer Virtual Horse Racing
		- 20131007@Jim: offer Virtual Tennis
		- 20140217@Hannah: add condition for @LicenseeType
		- 20140305@Florent: support Keno
		- 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
		- 20150612@Jim: support MicroGaming
		- 20150630@Winnie: support Bettrade
		- 20150930@Florent: support AGC
		- 20151108@Jim: Separated MicroGaming into 2 product
		- 20151228@Patrick: Exclude 901 & 902 for turnover
		- 20151228@Bobby: Implement RNG Casino sporttype(208,209,210)
		- 20160408@Percy: Support Voidbridge single wallet [Redmine: #55057]
		- 20160619@Jim: Allbet - Live Casino Integration for Licensees [Redmine: #59624]
		- 20160727@Jim:  LRF - Commercial terms changed for Bet Trade [Redmine: #61342]
		- 20160913@Jim : LRF - Implement Colossus Bets [Redmine: #63785]
		- 20161115@Jim: LRF - Integrate new product Fishing World [RedmineID : #66737]
		- 20170228@Paul: Get @AgentList by web instead of @UserId, @CurrencyID, @LicenseeID, Remove @excludeTest, @LicenseeType [Redmine: #71679]
		- 20170328@Paul: Support sorting values for Opening Balance and Closing Balance [RedmineID: #74120]
		- 20170330@Paul: Implement Cash Out [RedmineID :#71727]
		- 20170706@Harper: LRF - Integrate Bet Radar Virtual Sports [RedmineID: #78241]
		- 20170731@Harper: LRF - Integrate Lottery [RedmineID: #79997]
		- 20180129@Harper: Remove LC from product list [RedmineID: #85965]
		- 20180412@Harper: Integrate Bonus wallet [RedmineID: 91740]
		- 20180418@Amanda: LAP - Integrate PP [RedmineID: #92318]
		- 20180808@Amanda: Remove Racing, Bingo [RedmineID: #99378]
		- 20181228@Joseph: Remove vnteam [RedmineID: #103698]
		- 20190322@Amanda: Remove MGCLC & MGRnG [RedmineID: #107704]
		- 20190708@Amanda: Add new product Card Club [RedmineID: #115449]
		- 20191025@Amanda: Add new column - Promotion [RedmineID: #120333]
		- 20191212@Vickie: Integrate SpadeGaming [RedmineID: #124103]
		- 20200108@Vickie: Add new product Virtual Games [RedmineID: #124911]
		- 20200406@Hogan: Add new product Table Games [RedmineID: #131447]
		- 20200323@Vickie: Add new product Indo 4D [RedmineID: #130859]
		- 20200423@Hogan: Add new product Sexy Gaming [RedmineID: #132829]
		- 20200423@Vickie: Integrate Saba Club [RedmineID: #132702]
						- Change to use @ProductList
		- 20211109@Kos: Merge Sports Lottery into Sportsbook [RedmineID: #163191]
		- 20241701@Evan: Merge VS, VS2, VS3 as VS only [RedmineID: #199523]
		- 20240311@Eddie: Change 'bodbLicenseeNet' to 'wsv_lap' account [RedmineID: #201098]
		- 20240605@Kelvin: Exclude CusitID in bodb02.dbo.Dep_Customer_Archived [RedmineID: #206148]

	Param's Explanation:
		+ @TopCount:
			0: get all
			100: get 100 top by @OrderItem
			500: get 500 top by @OrderItem
		+ @OrderItem:
			1: Deposit
			2: Withdrawal
			3: Turnover
			4: Winloss desc
			5: Winloss asc
			6: Opening balance
			7: Closing balance
*/

BEGIN
	SET NOCOUNT ON

	-- Get agent list
	CREATE TABLE #TmpAg (CustId INT, Currency INT)

	CREATE CLUSTERED INDEX IX_TmpAg ON #TmpAg (CustId);

	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @AgentList
	
		INSERT INTO #TmpAg (CustId, Currency)
		SELECT AgentId, Currency 
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId INT, Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY
	BEGIN CATCH
		SELECT ErrCode = 100,
			ErrMsg = N'Parameter invalid.'

		RETURN
	END CATCH;

	DECLARE @ShowSB BIT = 0

	IF ',' + @ProductList + ',' LIKE '%,SB,%'
		SET @ShowSB = 1

	SELECT @ProductList = STRING_AGG(b.ProductPrefix, ',')
	FROM (
		SELECT DISTINCT ISNULL(b.ProductPrefix,a.Value) AS ProductPrefix
		FROM STRING_SPLIT(@ProductList, ',') a
			LEFT JOIN dbo.Lrf_f_GroupProduct() b ON a.Value = b.GroupProductPrefix
	) b

	-- Get sport type
	CREATE TABLE #SportType (SportType INT PRIMARY KEY, ProductCode VARCHAR(10))

	IF LEN(ISNULL(@ProductList, '')) > 0 
	BEGIN
		INSERT INTO #SportType (SportType, ProductCode)
		SELECT DISTINCT SportType, ISNULL(p.GroupProductPrefix, s.ProductCode)
		FROM dbo.f_LicWinLoss_ProductSportType_Sel(@ProductList) s 
			LEFT JOIN dbo.Lrf_f_GroupProduct() p ON s.ProductID = p.ProductId
	END

	IF @ShowBT = 1
	BEGIN
		INSERT INTO #SportType (SportType, ProductCode)
		VALUES (- 2, 'BT') -- 901

		INSERT INTO #SportType (SportType, ProductCode)
		VALUES (- 3, 'BT') -- 902
	END

	IF @ShowCO = 1
	BEGIN
		INSERT INTO #SportType (SportType, ProductCode)
		VALUES (-6, 'CO') -- 911

		INSERT INTO #SportType (SportType, ProductCode)
		VALUES (-7, 'CO') -- 912
	END

	CREATE TABLE #SumWinlost (
		CustId				INT,
		Deposit				MONEY,
		AffiliateTransfer	MONEY,
		Withdrawal			MONEY,
		Turnover			MONEY,
		WinLoss				MONEY,
		Bonus				MONEY,
		Adjustment			MONEY,
		Promotion			MONEY,
		Outstanding			MONEY,
		OpeningBalance		MONEY,
		ClosingBalance		MONEY,
		DrawGame			MONEY,
		TurnoverBA			MONEY,
		CommBA				MONEY,
		PlayerComm			MONEY,
		AmountDueToBA		MONEY)

	DECLARE @CutDate DATETIME

	DECLARE @tmpdate SMALLDATETIME
		, @fdate SMALLDATETIME
		, @tdate SMALLDATETIME

	SELECT @CutDate = MIN(winlostdate)
		, @fdate = @FromDate
		, @tdate = @ToDate
	FROM bodb_report.dbo.rptdepwinlost WITH (NOLOCK)

	IF @fdate < @CutDate
	BEGIN
		SELECT @tmpdate = CASE
							WHEN @tdate >= @CutDate THEN DATEADD(dd, -1, @CutDate)
							ELSE @tdate
						END

		INSERT INTO #SumWinlost
		SELECT b.custid
			, SUM(b.Deposit) AS Deposit
			, SUM(b.Aff2MemTransfer) AS AffiliateTransfer
			, SUM(b.Withdrawal) AS Withdrawal
			, 0 AS Turnover
			, 0 AS winloss
			, SUM(ISNULL(b.Bonus, 0) + ISNULL(bo.Bonus, 0)) AS Bonus
			, SUM(ISNULL(b.Adjustment, 0) + ISNULL(bo.Adjustment, 0)) AS Adjustment
			, SUM(b.Promotion) AS Promotion
			, 0 AS Outstanding
			, SUM(CASE b.winlostdate
					WHEN @fdate THEN b.OpeningBalance
					ELSE 0
				END) AS OpeningBalance
			, SUM(CASE b.winlostdate
					WHEN @tdate THEN b.ClosingBalance
					ELSE 0
				END) AS ClosingBalance
			, 0 AS DrawGame
			, CASE
				WHEN @showSB = 1 THEN SUM(ISNULL(Turnover_BA, 0))
				ELSE 0
			END TurnoverBA
			, CASE 
				WHEN @showSB = 1 THEN SUM(ISNULL(Comm_BA, 0))
				ELSE 0
			END CommBA
			, 0 AS PlayerComm
			, CASE 
				WHEN @showSB = 1 THEN SUM(ISNULL(AmountDueTo_BA, 0))
				ELSE 0
			END AmountDueToBA
		FROM bodb_Report.dbo.rptDepWinlost_bk AS b WITH (NOLOCK)
			INNER JOIN #TmpAg AS a ON b.recommend = a.CustId
			LEFT JOIN bodb_Report.dbo.rptDepWinlost_BonusWallet AS bo WITH (NOLOCK) ON b.custid = bo.CustID AND b.winlostdate = bo.Winlostdate
		WHERE b.winlostdate BETWEEN @fdate AND @tmpdate
			AND NOT EXISTS (SELECT TOP 1 1 FROM bodb02.dbo.Dep_Customer_Archived da WITH(NOLOCK) WHERE b.CustID = da.CustID) 
		GROUP BY b.CustId;

		WITH sourceDATA
		AS (
			SELECT p.custid
				, SUM(ISNULL(CASE 
								WHEN p.sporttype IN (-2, -3, -5, -6, -7) THEN 0
								ELSE p.turnover
							END, 0)) AS Turnover
				, SUM(ISNULL(p.outstanding, 0)) AS outstanding
				, SUM(ISNULL(p.winlost, 0)) AS Winloss
				, SUM(ISNULL(p.drawTO, 0)) AS DrawGame
				, SUM(ISNULL(p.playercomm, 0)) AS PlayerComm
			FROM bodb_Report.dbo.rptDepWinlostByProduct_bk AS p WITH (NOLOCK)
				INNER JOIN #SumWinlost AS d ON p.custid = d.custid
				INNER JOIN #SportType AS s ON s.SportType = p.sporttype
			WHERE p.winlostdate BETWEEN @fdate AND @tmpdate
			GROUP BY p.custid
			)
		UPDATE #SumWinlost
		SET Turnover = ISNULL(s.turnover, 0)
			, Outstanding = ISNULL(s.outstanding, 0)
			, WinLoss = ISNULL(s.winloss, 0)
			, DrawGame = ISNULL(s.drawgame, 0)
			, PlayerComm = ISNULL(s.playercomm, 0)
		FROM sourceDATA s
		WHERE #SumWinlost.custid = s.custid
	END

	IF @tdate >= @CutDate
	BEGIN
		SELECT @tmpdate = CASE
							WHEN @fdate < @CutDate THEN @CutDate
							ELSE @fdate
						END

		SELECT b.custid
			, SUM(b.Deposit) AS Deposit
			, SUM(b.Aff2MemTransfer) AS AffiliateTransfer
			, SUM(b.Withdrawal) AS Withdrawal
			, CAST(0 AS MONEY) AS Turnover
			, CAST(0 AS MONEY) AS winloss
			, SUM(ISNULL(b.Bonus, 0) + ISNULL(b.BonusWallet, 0)) AS Bonus
			, SUM(ISNULL(b.Adjustment, 0) + ISNULL(b.AdjBonusWallet, 0)) AS Adjustment
			, SUM(b.Promotion) AS Promotion
			, CAST(0 AS MONEY) AS Outstanding
			, SUM(CASE b.winlostdate
					WHEN @fdate THEN b.OpeningBalance
					ELSE 0
				END) AS OpeningBalance
			, SUM(CASE b.winlostdate
					WHEN @tdate THEN b.ClosingBalance
					ELSE 0
				END) AS ClosingBalance
			, CAST(0 AS MONEY) AS DrawGame
			, CASE
				WHEN @showSB = 1 THEN SUM(ISNULL(Turnover_BA, 0))
				ELSE 0
			END TurnoverBA
			, CASE
				WHEN @showSB = 1 THEN SUM(ISNULL(Comm_BA, 0))
				ELSE 0
			END CommBA
			, CAST(0 AS MONEY) AS PlayerComm
			, CASE 
				WHEN @showSB = 1 THEN SUM(ISNULL(AmountDueTo_BA, 0))
				ELSE 0
			END AmountDueToBA
		INTO #SumWinlost2
		FROM bodb_Report.dbo.rptDepWinlost AS b WITH (NOLOCK)
			INNER JOIN #TmpAg AS a ON b.recommend = a.CustId
		WHERE b.winlostdate BETWEEN @tmpdate AND @tdate
			AND NOT EXISTS (SELECT TOP 1 1 FROM bodb02.dbo.Dep_Customer_Archived da WITH(NOLOCK) WHERE b.CustID = da.CustID)
		GROUP BY b.CustId;

		WITH sourceDATA
		AS (
			SELECT p.custid
				, SUM(ISNULL(CASE
								WHEN p.sporttype IN (-2, -3, -5, -6, -7) THEN 0
								ELSE p.turnover
							END, 0)) AS Turnover
				, SUM(ISNULL(p.outstanding, 0)) AS outstanding
				, SUM(ISNULL(p.winlost, 0)) AS Winloss
				, SUM(ISNULL(p.drawTO, 0)) AS DrawGame
				, SUM(ISNULL(p.playercomm, 0)) AS PlayerComm
			FROM bodb_Report.dbo.rptDepWinlostByProduct p WITH (NOLOCK)
				INNER JOIN #SumWinlost2 d ON p.custid = d.custid
				INNER JOIN #SportType AS s ON s.SportType = p.sporttype
			WHERE p.winlostdate BETWEEN @tmpdate AND @tdate
			GROUP BY p.custid
			)
		UPDATE #SumWinlost2
		SET Turnover = ISNULL(s.turnover, 0)
			, outstanding = ISNULL(s.outstanding, 0)
			, Winloss = ISNULL(s.winloss, 0)
			, DrawGame = ISNULL(s.drawgame, 0)
			, PlayerComm = ISNULL(s.playercomm, 0)
		FROM sourceDATA s
		WHERE #SumWinlost2.custid = s.custid

		UPDATE #SumWinlost
		SET Deposit = #SumWinlost.Deposit + s.Deposit
			, AffiliateTransfer = #SumWinlost.AffiliateTransfer + s.AffiliateTransfer
			, Withdrawal = #SumWinlost.Withdrawal + s.Withdrawal
			, Turnover = #SumWinlost.Turnover + s.Turnover
			, Winloss = #SumWinlost.Winloss + s.Winloss
			, Bonus = #SumWinlost.Bonus + s.Bonus
			, Adjustment = #SumWinlost.Adjustment + s.Adjustment
			, Promotion = #SumWinlost.Promotion + s.Promotion
			, Outstanding = #SumWinlost.Outstanding + s.Outstanding
			, OpeningBalance = #SumWinlost.OpeningBalance + s.OpeningBalance
			, ClosingBalance = #SumWinlost.ClosingBalance + s.ClosingBalance
			, DrawGame = #SumWinlost.DrawGame + s.DrawGame
			, TurnoverBA = #SumWinlost.TurnoverBA + s.TurnoverBA
			, CommBA = #SumWinlost.CommBA + s.CommBA
			, PlayerComm = #SumWinlost.PlayerComm + s.PlayerComm
			, AmountDueToBA = #SumWinlost.AmountDueToBA + s.AmountDueToBA
		FROM #SumWinlost2 s
		WHERE #SumWinlost.custid = s.custid

		INSERT INTO #SumWinlost
		SELECT Custid
			, Deposit
			, AffiliateTransfer
			, Withdrawal
			, Turnover
			, Winloss
			, Bonus
			, Adjustment
			, Promotion
			, Outstanding
			, OpeningBalance
			, ClosingBalance
			, DrawGame
			, TurnoverBA
			, CommBA
			, PlayerComm
			, AmountDueToBA
		FROM #SumWinlost2
		WHERE custid NOT IN (SELECT Custid FROM #SumWinlost)

		DROP TABLE #SumWinlost2
	END

	DECLARE @RowStart INT
		, @RowEnd INT

	SELECT @PageIndex = @PageIndex - 1
		, @RowStart = @PageSize * @PageIndex + 1
		, @RowEnd = @RowStart + @PageSize - 1

	IF @OrderItem = 5
	BEGIN
		IF @TopCount = 0
		BEGIN
			SELECT c.username
				, SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS nickname
				, toptbl.*
			FROM (
				SELECT rpt.*
					, ROW_NUMBER() OVER (ORDER BY rpt.Winloss, rpt.Custid) AS RowNum
				FROM #SumWinlost rpt
				) AS toptbl
				INNER JOIN dbo.Customer c WITH (NOLOCK) ON c.custid = toptbl.custid
			WHERE toptbl.RowNum BETWEEN @RowStart AND @RowEnd
			ORDER BY RowNum ASC

			SELECT COUNT(DISTINCT CustID) AS TotalRows
				, SUM(Deposit) AS SumDeposit
				, SUM(AffiliateTransfer) AS SumAffiliateTransfer
				, SUM(Withdrawal) AS SumWithdrawal
				, SUM(Turnover) AS SumTurnover
				, SUM(Winloss) AS SumWinloss
				, SUM(Bonus) AS SumBonus
				, SUM(Adjustment) AS SumAdjustment
				, SUM(Promotion) AS SumPromotion
				, SUM(Outstanding) AS SumOutstanding
				, SUM(OpeningBalance) AS SumOpeningBalance
				, SUM(ClosingBalance) AS SumClosingBalance
				, SUM(DrawGame) AS SumDrawGame
				, SUM(TurnoverBA) AS SumTurnoverBA
				, SUM(CommBA) AS SumCommBA
				, SUM(PlayerComm) AS SumPlayerComm
				, SUM(AmountDueToBA) AS SumAmountDueToBA
			FROM #SumWinlost
		END
		ELSE
		BEGIN
			SELECT c.username
				, SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS nickname
				, toptbl.*
			FROM (
				SELECT TOP (@TopCount) rpt.*
					, ROW_NUMBER() OVER (ORDER BY rpt.Winloss, rpt.Custid) AS RowNum
				FROM #SumWinlost rpt
				) AS toptbl
				INNER JOIN dbo.Customer c WITH (NOLOCK) ON c.custid = toptbl.custid
			WHERE toptbl.RowNum BETWEEN @RowStart AND @RowEnd
			ORDER BY RowNum ASC

			SELECT COUNT(DISTINCT CustID) AS TotalRows
				, SUM(Deposit) AS SumDeposit
				, SUM(AffiliateTransfer) AS SumAffiliateTransfer
				, SUM(Withdrawal) AS SumWithdrawal
				, SUM(Turnover) AS SumTurnover
				, SUM(Winloss) AS SumWinloss
				, SUM(Bonus) AS SumBonus
				, SUM(Adjustment) AS SumAdjustment
				, SUM(Promotion) AS SumPromotion
				, SUM(Outstanding) AS SumOutstanding
				, SUM(OpeningBalance) AS SumOpeningBalance
				, SUM(ClosingBalance) AS SumClosingBalance
				, SUM(DrawGame) AS SumDrawGame
				, SUM(TurnoverBA) AS SumTurnoverBA
				, SUM(CommBA) AS SumCommBA
				, SUM(PlayerComm) AS SumPlayerComm
				, SUM(AmountDueToBA) AS SumAmountDueToBA
			FROM (
				SELECT TOP (@TopCount)
					rpt.*,
					ROW_NUMBER() OVER (ORDER BY rpt.Winloss) AS RowNum
				FROM #SumWinlost rpt
				ORDER BY RowNum ASC
				) A
		END
	END
	ELSE
	BEGIN
		IF @TopCount = 0
		BEGIN
			SELECT c.username
				, SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS Nickname
				, toptbl.*
			FROM (
					SELECT rpt.*
						, ROW_NUMBER() OVER (ORDER BY CASE @OrderItem
														WHEN 1 THEN rpt.Deposit
														WHEN 2 THEN rpt.Withdrawal
														WHEN 3 THEN rpt.Turnover
														WHEN 4 THEN rpt.Winloss
														WHEN 6 THEN rpt.OpeningBalance
														WHEN 7 THEN rpt.ClosingBalance
													END DESC, rpt.Custid) AS RowNum
					FROM #SumWinlost rpt
				) AS toptbl
				INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON c.custid = toptbl.custid
			WHERE toptbl.RowNum BETWEEN @RowStart AND @RowEnd
			ORDER BY RowNum ASC

			SELECT COUNT(DISTINCT CustID) AS TotalRows
				, SUM(Deposit) AS SumDeposit
				, SUM(AffiliateTransfer) AS SumAffiliateTransfer
				, SUM(Withdrawal) AS SumWithdrawal
				, SUM(Turnover) AS SumTurnover
				, SUM(Winloss) AS SumWinloss
				, SUM(Bonus) AS SumBonus
				, SUM(Adjustment) AS SumAdjustment
				, SUM(Promotion) AS SumPromotion
				, SUM(Outstanding) AS SumOutstanding
				, SUM(OpeningBalance) AS SumOpeningBalance
				, SUM(ClosingBalance) AS SumClosingBalance
				, SUM(DrawGame) AS SumDrawGame
				, SUM(TurnoverBA) AS SumTurnoverBA
				, SUM(CommBA) AS SumCommBA
				, SUM(PlayerComm) AS SumPlayerComm
				, SUM(AmountDueToBA) AS SumAmountDueToBA
			FROM #SumWinlost
		END
		ELSE
		BEGIN
			SELECT c.username
				, SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS nickname
				, toptbl.*
			FROM (
					SELECT TOP (@TopCount) rpt.*
						, ROW_NUMBER() OVER (ORDER BY CASE @OrderItem
														WHEN 1 THEN rpt.Deposit
														WHEN 2 THEN rpt.Withdrawal
														WHEN 3 THEN rpt.Turnover
														WHEN 4 THEN rpt.Winloss
														WHEN 6 THEN rpt.OpeningBalance
														WHEN 7 THEN rpt.ClosingBalance
													END DESC, rpt.Custid) AS RowNum
					FROM #SumWinlost rpt
				) AS toptbl
				INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON c.custid = toptbl.custid
			WHERE toptbl.RowNum BETWEEN @RowStart AND @RowEnd
			ORDER BY RowNum ASC

			SELECT COUNT(DISTINCT CustID) AS TotalRows
				, SUM(Deposit) AS SumDeposit
				, SUM(AffiliateTransfer) AS SumAffiliateTransfer
				, SUM(Withdrawal) AS SumWithdrawal
				, SUM(Turnover) AS SumTurnover
				, SUM(Winloss) AS SumWinloss
				, SUM(Bonus) AS SumBonus
				, SUM(Adjustment) AS SumAdjustment
				, SUM(Promotion) AS SumPromotion
				, SUM(Outstanding) AS SumOutstanding
				, SUM(OpeningBalance) AS SumOpeningBalance
				, SUM(ClosingBalance) AS SumClosingBalance
				, SUM(DrawGame) AS SumDrawGame
				, SUM(TurnoverBA) AS SumTurnoverBA
				, SUM(CommBA) AS SumCommBA
				, SUM(PlayerComm) AS SumPlayerComm
				, SUM(AmountDueToBA) AS SumAmountDueToBA
			FROM (
				SELECT TOP (@TopCount) rpt.*
					, ROW_NUMBER() OVER (ORDER BY CASE @OrderItem
													WHEN 1 THEN rpt.Deposit
													WHEN 2 THEN rpt.Withdrawal
													WHEN 3 THEN rpt.Turnover
													WHEN 4 THEN rpt.Winloss
													WHEN 6 THEN rpt.OpeningBalance
													WHEN 7 THEN rpt.ClosingBalance
												END DESC, rpt.Custid) AS RowNum
				FROM #SumWinlost rpt
				ORDER BY RowNum ASC
				) AS A
		END
	END

	DROP TABLE #SumWinlost
	DROP TABLE #TmpAg
END
GO

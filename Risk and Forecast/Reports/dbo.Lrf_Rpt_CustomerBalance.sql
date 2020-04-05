/*<info serverAlias="DBACC-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_CustomerBalance] 
	@FromDate		SMALLDATETIME
	, @ToDate		SMALLDATETIME
	, @OrderItem	TINYINT = 1
	, @TopCount		INT = 0
	, @PageSize		INT = 1000
	, @PageIndex	INT = 1
	, @showSB		BIT = 0
	, @ShowNG		BIT = 0
	, @ShowVS		BIT = 0
	, @ShowCS		BIT = 0
	, @ShowKN		BIT = 0
	, @ShowBT		BIT = 0 -- Keno
	, @ShowAGC		BIT = 0
	, @ShowVB		BIT = 0
	, @ShowAB		BIT = 0
	, @ShowCB		BIT = 0
	, @ShowFW		BIT = 0
	, @ShowCO		BIT = 0
	, @ShowVS2		BIT = 0 -- BetRadar VS
	, @ShowLT		BIT = 0 -- Lottery
	, @ShowPP		BIT = 0 -- PP
	, @ShowCC		BIT = 0 -- Card club
	, @ShowSG		BIT = 0 -- Spadegaming 
	, @ShowVRG		BIT = 0 -- Virtual Games
	, @ShowTG		BIT = 0 -- Table Games
	, @ShowI4D		BIT = 0 -- Indo 4D
	,@AgentList		VARCHAR(MAX)
AS

/*
	Created: 20120917@Henry
	Task : Report Customer Balance
	DB: DBACC/bodb02
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

	Param's Explanation:
		+ @excludeTest: remove currency UUS
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

	DECLARE @CutDate DATETIME
	DECLARE @tmpAg TABLE (
		custID INT
		, Currency INT
		)
	DECLARE @sporttype	TABLE (sporttype INT, ProductCode VARCHAR(10))
	DECLARE @ProductList	VARCHAR (500)

	DECLARE @RowStart INT
		, @RowEnd INT
	
	DECLARE @tmpdate SMALLDATETIME
		, @fdate SMALLDATETIME
		, @tdate SMALLDATETIME

	SELECT @CutDate = MIN(winlostdate)
		, @fdate = @FromDate
		, @tdate = @ToDate
	FROM bodb_report.dbo.rptdepwinlost WITH (NOLOCK)

	SELECT @PageIndex = @PageIndex - 1
		, @RowStart = @PageSize * @PageIndex + 1
		, @RowEnd = @RowStart + @PageSize - 1

	IF @ShowSB = 1
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'SB', 'SB')

	IF @ShowNG = 1
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'NG', 'NG')	
		
	IF @ShowVS = 1
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'VS', 'VS')

	IF @ShowCS = 1
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'CS', 'CS')

	IF @ShowKN = 1
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'KN', 'KN')    

	IF @ShowAGC = 1
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'AGC', 'AGC')

	IF @ShowVB = 1
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'VB', 'VB')

	IF @ShowAB = 1
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'AB', 'AB')

	IF @ShowCB = 1
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'CB', 'CB')

	IF @ShowBT = 1
	BEGIN
		INSERT INTO @sporttype (sporttype, ProductCode)
		VALUES (- 2, 'BT') -- 901

		INSERT INTO @sporttype (sporttype, ProductCode)
		VALUES (- 3, 'BT') -- 902
	END

	IF @ShowFW = 1
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'FW', 'FW')

	IF @ShowCO = 1
	BEGIN
		INSERT INTO @sporttype (sporttype, ProductCode)
		VALUES (-6, 'CO') -- 911

		INSERT INTO @sporttype (sporttype, ProductCode)
		VALUES (-7, 'CO') -- 912
	END

	IF @ShowVS2 = 1
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'VS2', 'VS2')
	END

	IF @ShowLT = 1
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'LT', 'LT')
	END
	
	IF @ShowPP = 1
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'PP', 'PP')
	END
	
	IF @ShowCC = 1
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'CC', 'CC')
	END

	IF @ShowSG = 1
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'SG', 'SG')
	END

	IF @ShowVRG = 1
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'VRG', 'VRG')
	END

	IF @ShowTG = 1 -- Table Games
	BEGIN 
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'TG', 'TG')
	END

	IF @ShowI4D = 1
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'I4D', 'I4D')
	END

	IF LEN(ISNULL(@ProductList, '')) > 0 
	BEGIN
		-- Insert Sport Type
		INSERT INTO @sporttype ( sporttype, ProductCode )
		SELECT DISTINCT sporttype, ProductCode
		FROM dbo.f_LicWinLoss_ProductSportType_Sel(@ProductList)
	END

	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@AgentList
	
		INSERT INTO @tmpAg(CustId, Currency)
		SELECT AgentId, Currency 
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
			,ErrMsg = N'Parameter invalid.'

		RETURN
	END CATCH;

	CREATE TABLE #SumWinlost (
		Custid INT
		, Deposit MONEY
		, AffiliateTransfer MONEY
		, Withdrawal MONEY
		, Turnover MONEY
		, Winloss MONEY
		, Bonus MONEY
		, Adjustment MONEY
		, Promotion	MONEY
		, Outstanding MONEY
		, OpeningBalance MONEY
		, ClosingBalance MONEY
		, DrawGame MONEY
		, TurnoverBA MONEY
		, CommBA MONEY
		, PlayerComm MONEY
		, AmountDueToBA MONEY
		)

	IF @fdate < @CutDate
	BEGIN
		SELECT @tmpdate = CASE 
							WHEN @tdate >= @CutDate THEN DATEADD(dd, - 1, @CutDate)
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
					WHEN @fdate
						THEN b.OpeningBalance
					ELSE 0
					END) OpeningBalance
			, SUM(CASE b.winlostdate
					WHEN @tdate
						THEN b.ClosingBalance
					ELSE 0
					END) ClosingBalance
			, 0 AS DrawGame
			, CASE 
				WHEN @showSB = 1
					THEN SUM(ISNULL(Turnover_BA, 0))
				ELSE 0
				END TurnoverBA
			, CASE 
				WHEN @showSB = 1
					THEN SUM(ISNULL(Comm_BA, 0))
				ELSE 0
				END CommBA
			, 0 AS PlayerComm
			, CASE 
				WHEN @showSB = 1
					THEN SUM(ISNULL(AmountDueTo_BA, 0))
				ELSE 0
				END AmountDueToBA
		FROM bodb_Report.dbo.rptDepWinlost_bk b WITH (NOLOCK)
		INNER JOIN @tmpAg a
			ON b.recommend = a.CustId AND b.Currency = a.Currency
		LEFT JOIN bodb_Report.dbo.rptDepWinlost_BonusWallet bo WITH (NOLOCK)
			ON b.custid = bo.CustID AND b.winlostdate = bo.Winlostdate
		WHERE b.winlostdate BETWEEN @fdate
				AND @tmpdate
		GROUP BY b.custid;

		WITH sourceDATA
		AS (
			SELECT p.custid
				, SUM(ISNULL(CASE 
							WHEN p.sporttype IN (
									- 2
									, - 3
									, - 5
									, -6
									, -7
									)
								THEN 0
							ELSE p.turnover
							END, 0)) AS Turnover
				, SUM(ISNULL(p.outstanding, 0)) AS outstanding
				, SUM(ISNULL(p.winlost, 0)) AS Winloss
				, SUM(ISNULL(p.drawTO, 0)) AS DrawGame
				, SUM(ISNULL(p.playercomm, 0)) AS PlayerComm
			FROM bodb_Report.dbo.rptDepWinlostByProduct_bk p WITH (NOLOCK)
			INNER JOIN #SumWinlost d
				ON p.custid = d.custid
			WHERE p.winlostdate BETWEEN @fdate AND @tmpdate
				AND sporttype IN (SELECT sporttype FROM @sporttype)
			GROUP BY p.custid
			)
		UPDATE #SumWinlost
		SET turnover = ISNULL(s.turnover, 0)
			, outstanding = ISNULL(s.outstanding, 0)
			, winloss = ISNULL(s.winloss, 0)
			, drawgame = ISNULL(s.drawgame, 0)
			, playercomm = ISNULL(s.playercomm, 0)
		FROM sourceDATA s
		WHERE #SumWinlost.custid = s.custid
	END

	IF @tdate >= @CutDate
	BEGIN
		SELECT @tmpdate = CASE 
				WHEN @fdate < @CutDate
					THEN @CutDate
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
					WHEN @fdate
						THEN b.OpeningBalance
					ELSE 0
					END) OpeningBalance
			, SUM(CASE b.winlostdate
					WHEN @tdate
						THEN b.ClosingBalance
					ELSE 0
					END) ClosingBalance
			, CAST(0 AS MONEY) AS DrawGame
			, CASE 
				WHEN @showSB = 1
					THEN SUM(ISNULL(Turnover_BA, 0))
				ELSE 0
				END TurnoverBA
			, CASE 
				WHEN @showSB = 1
					THEN SUM(ISNULL(Comm_BA, 0))
				ELSE 0
				END CommBA
			, CAST(0 AS MONEY) AS PlayerComm
			, CASE 
				WHEN @showSB = 1
					THEN SUM(ISNULL(AmountDueTo_BA, 0))
				ELSE 0
				END AmountDueToBA
		INTO #SumWinlost2
		FROM bodb_Report.dbo.rptDepWinlost b WITH (NOLOCK)
		INNER JOIN @tmpAg a
			ON b.recommend = a.CustId
				AND b.Currency = a.Currency
		WHERE b.winlostdate BETWEEN @tmpdate
				AND @tdate
		GROUP BY b.custid;

		WITH sourceDATA
		AS (
			SELECT p.custid
				, SUM(ISNULL(CASE 
							WHEN p.sporttype IN (
									- 2
									, - 3
									, - 5
									, -6
									, -7
									)
								THEN 0
							ELSE p.turnover
							END, 0)) AS Turnover
				, SUM(ISNULL(p.outstanding, 0)) AS outstanding
				, SUM(ISNULL(p.winlost, 0)) AS Winloss
				, SUM(ISNULL(p.drawTO, 0)) AS DrawGame
				, SUM(ISNULL(p.playercomm, 0)) AS PlayerComm
			FROM bodb_Report.dbo.rptDepWinlostByProduct p WITH (NOLOCK)
			INNER JOIN #SumWinlost2 d
				ON p.custid = d.custid
			WHERE p.winlostdate BETWEEN @tmpdate
					AND @tdate
				AND sporttype IN (
					SELECT sporttype
					FROM @sporttype
					)
			GROUP BY p.custid
			)
		UPDATE #SumWinlost2
		SET turnover = ISNULL(s.turnover, 0)
			, outstanding = ISNULL(s.outstanding, 0)
			, winloss = ISNULL(s.winloss, 0)
			, drawgame = ISNULL(s.drawgame, 0)
			, playercomm = ISNULL(s.playercomm, 0)
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
		WHERE custid NOT IN (
				SELECT custid
				FROM #SumWinlost
				)
	END

	IF @OrderItem = 5
	BEGIN
		IF @TopCount = 0
		BEGIN
			SELECT c.username
				, SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS nickname
				, toptbl.*
			FROM (
				SELECT rpt.*
					, ROW_NUMBER() OVER (
						ORDER BY rpt.Winloss
							, rpt.Custid
						) AS RowNum
				FROM #SumWinlost rpt
				) AS toptbl
			INNER JOIN Customer c WITH (NOLOCK)
				ON c.custid = toptbl.custid
			WHERE toptbl.RowNum BETWEEN @RowStart
					AND @RowEnd
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
			FROM #SumWinlost rpt
		END
		ELSE
		BEGIN
			SELECT c.username
				, SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS nickname
				, toptbl.*
			FROM (
				SELECT TOP (@TopCount) rpt.*
					, ROW_NUMBER() OVER (
						ORDER BY rpt.Winloss
							, rpt.Custid
						) AS RowNum
				FROM #SumWinlost rpt
				) AS toptbl
			INNER JOIN Customer c WITH (NOLOCK)
				ON c.custid = toptbl.custid
			WHERE toptbl.RowNum BETWEEN @RowStart
					AND @RowEnd
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
					, ROW_NUMBER() OVER (
						ORDER BY rpt.Winloss
						) AS RowNum
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
				, SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS nickname
				, toptbl.*
			FROM (
				SELECT rpt.*
					, ROW_NUMBER() OVER (
						ORDER BY CASE @orderItem
								WHEN 1
									THEN rpt.Deposit
								WHEN 2
									THEN rpt.Withdrawal
								WHEN 3
									THEN rpt.Turnover
								WHEN 4
									THEN rpt.Winloss
								WHEN 6
									THEN rpt.OpeningBalance
								WHEN 7
									THEN rpt.ClosingBalance
								END DESC
							, rpt.Custid
						) AS RowNum
				FROM #SumWinlost rpt
					/*
				where
				CASE
					WHEN @orderItem=1 AND rpt.Deposit > 0 THEN 1  
					WHEN @orderItem=2 AND rpt.Withdrawal > 0 THEN 1  
					WHEN @orderItem=3 AND rpt.Turnover > 0 THEN 1  
					WHEN @orderItem=4 AND rpt.Winloss <> 0 THEN 1  
					end = 1  
				*/
				) AS toptbl
			INNER JOIN Customer c WITH (NOLOCK)
				ON c.custid = toptbl.custid
			WHERE toptbl.RowNum BETWEEN @RowStart
					AND @RowEnd
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
			FROM #SumWinlost rpt
				/*  
			where    
			CASE   
			WHEN @orderItem=1 AND rpt.Deposit > 0 THEN 1  
			WHEN @orderItem=2 AND rpt.Withdrawal > 0 THEN 1  
			WHEN @orderItem=3 AND rpt.Turnover > 0 THEN 1  
			WHEN @orderItem=4 AND rpt.Winloss <> 0 THEN 1  
			end = 1   
			*/
		END
		ELSE
		BEGIN
			SELECT c.username
				, SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS nickname
				, toptbl.*
			FROM (
				SELECT TOP (@TopCount) rpt.*
					, ROW_NUMBER() OVER (
						ORDER BY CASE @orderItem
								WHEN 1
									THEN rpt.Deposit
								WHEN 2
									THEN rpt.Withdrawal
								WHEN 3
									THEN rpt.Turnover
								WHEN 4
									THEN rpt.Winloss
								WHEN 6
									THEN rpt.OpeningBalance
								WHEN 7
									THEN rpt.ClosingBalance
								END DESC
							, rpt.Custid
						) AS RowNum
				FROM #SumWinlost rpt
					/*  
				where  
				CASE   
					WHEN @orderItem=1 AND rpt.Deposit >0 THEN 1  
					WHEN @orderItem=2 AND rpt.Withdrawal >0 THEN 1  
					WHEN @orderItem=3 AND rpt.Turnover >0 THEN 1  
					WHEN @orderItem=4 AND rpt.Winloss <>0 THEN 1  
					end = 1  
				*/
				) AS toptbl
			INNER JOIN bodb02.dbo.Customer c WITH (NOLOCK)
				ON c.custid = toptbl.custid
			WHERE toptbl.RowNum BETWEEN @RowStart
					AND @RowEnd
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
					, ROW_NUMBER() OVER (
						ORDER BY CASE @orderItem
								WHEN 1
									THEN rpt.Deposit
								WHEN 2
									THEN rpt.Withdrawal
								WHEN 3
									THEN rpt.Turnover
								WHEN 4
									THEN rpt.Winloss
								WHEN 6
									THEN rpt.OpeningBalance
								WHEN 7
									THEN rpt.ClosingBalance
								END DESC
							, rpt.Custid
						) AS RowNum
				FROM #SumWinlost rpt
				ORDER BY RowNum ASC
					/*  
				where  
				CASE   
					WHEN @orderItem=1 AND rpt.Deposit >0 THEN 1  
					WHEN @orderItem=2 AND rpt.Withdrawal >0 THEN 1  
					WHEN @orderItem=3 AND rpt.Turnover >0 THEN 1  
					WHEN @orderItem=4 AND rpt.Winloss <>0 THEN 1  
					end = 1  
				ORDER BY RowNum ASC  
				*/
				) A
		END
	END

	DROP TABLE #SumWinlost
END
GO

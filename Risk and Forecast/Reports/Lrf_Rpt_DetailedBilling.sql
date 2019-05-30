/*<info serverAlias="DBLIC-bodb_licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Lrf_Rpt_DetailedBilling]  	
	@LicenseeID		INT,
	@FromDate		SMALLDATETIME,  
	@ToDate			SMALLDATETIME,
	@BaseCurrency	VARCHAR(3),
	@Environment	VARCHAR(5)
AS 
/*  Created: Amanda  
	Date: 2019-05-21
    Task : Get data for detailed Billing report
    DB: DBLIC.bodb_licensee  
   
    Revisions:  
    - 20190521@Amanda: Create SP [RedmineID: #107704]
*/  
BEGIN
	SET NOCOUNT ON  

	DECLARE @PartyID INT, @ProductCode VARCHAR(1000)
	DECLARE @GD_Tip SMALLINT = 1706
	DECLARE @ProductId INT
	DECLARE @IsTest BIT = 0
	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	CREATE TABLE #Result
	(
		ProductCode		VARCHAR(10),
		Turnover		MONEY,
		CustomerWL		MONEY,
		LicenseeNetWL	MONEY,
		AmountDue		MONEY
	)
	
	CREATE TABLE #Exchange
	(
		ExFromDate		SMALLDATETIME,
		ExToDate		SMALLDATETIME,
		ExchangeID		INT,
		Rate			FLOAT
	)
	
	DECLARE @ChargeInfo AS TABLE
	(
		PartyId		INT,
		LicenseeId	INT,
		ProductID	INT,
		Bettype		INT,
		Rate		MONEY,
		FromDate	SMALLDATETIME,
		ToDate		SMALLDATETIME,
		ChargeType	TINYINT
	)
	
	DECLARE @Bettype AS TABLE
	(
		Bettype		INT,
		ProductCode	VARCHAR(10)
	)
	
	DECLARE @Product AS TABLE
	(
		Id		INT,
		Code	VARCHAR(10)
	)
	
	DECLARE @TempAG AS TABLE
	(
		CustId INT,
		CurrencyId INT
	)
	
	DECLARE @Total AS TABLE (
		[Description]	NVARCHAR(500),
		Amount			MONEY
	)
	
	DECLARE @InvoiceHeader AS TABLE (
		Id				BIGINT
	)
	
	SELECT @PartyID = PartyID
	FROM dbo.OAS_Party WITH(NOLOCK)
	WHERE OldRefID = @LicenseeId AND PartyType = 1
	
	INSERT INTO @Product(Id, Code)
	SELECT DISTINCT
		c.ProductID,
		CASE WHEN c.ProductID = 0 THEN 'SB' ELSE p.ProductPrefix END
	FROM dbo.OAS_ChargeInfo c WITH (NOLOCK)
		LEFT JOIN dbo.Product3rd p WITH (NOLOCK) ON c.ProductID = p.Productid AND p.ProductPrefix NOT IN ('BT', 'MGCLC', 'MGCRNG')
	WHERE c.FromParty = @PartyID
		AND c.FromDate <= c.ToDate
		AND c.ToDate >= @FromDate
		AND c.FromDate <= @ToDate
		AND (c.ProductID = 0 OR p.Productid IS NOT NULL)

	SELECT @ProductCode = STUFF(
			(
				SELECT ',' + Code
				FROM @Product i
				FOR XML PATH('')
			), 1, 1, '')
	
	INSERT INTO @ChargeInfo(PartyId, LicenseeId, ProductID, Bettype, Rate, Fromdate, Todate, ChargeType)
	SELECT DISTINCT
			PartyID,
			LicenseeID,
			ProductID,
			CASE 
				WHEN ProductID = 11 AND ChargeType = 12 THEN @GD_Tip
				ELSE Bettype
			END,
			DI_Rate,
			Fromdate,
			Todate,
			ChargeType
	FROM dbo.LA_f_ChargeInfo(@PartyID, @FromDate, @ToDate, @ProductCode, 'OA', 1)
	--WHERE DI_Rate > 0
	
	INSERT INTO @TempAG(CustId, CurrencyId)
	SELECT CustID, Currency
	FROM dbo.f_SelLicenseeCust(@LicenseeID)
	WHERE Currency <> 20 AND RoleID = 2
	
	;WITH CTE_CurrencyList AS (
		SELECT DISTINCT CurrencyId
		FROM @TempAG
	)
	INSERT INTO #Exchange(ExFromDate, ExToDate, ExchangeID, Rate)
	SELECT	FirstExchangeDateByMonth, 
			LastExchangeDateByMonth,
			ExchangeID,
			CASE 
				WHEN @BaseCurrency = 'USD' THEN USD
				WHEN @BaseCurrency = 'EUR' THEN EUR
				WHEN @BaseCurrency = 'GBP' THEN GBP
				WHEN @BaseCurrency = 'MYR' THEN MYR
				WHEN @BaseCurrency = 'CNY' THEN CNY
				WHEN @BaseCurrency = 'THB' THEN THB
				WHEN @BaseCurrency = 'IDR' THEN IDR
				WHEN @BaseCurrency = 'INH' THEN INH
				ELSE 1
			END
	FROM bodb02.dbo.Lrf_f_GetSubExchangeDaily(@FromDate, @ToDate) e
	INNER JOIN CTE_CurrencyList c ON e.ExchangeId = c.CurrencyID 
	
	IF EXISTS (SELECT 1 FROM @Product WHERE Code = 'AGC')
	BEGIN
		CREATE TABLE #DataWinloss3rd
		(
			Recommend		INT,
			Winlostdate		DATETIME,
			Currency		INT,
			Turnover		MONEY,
			Winloss			MONEY
		)
	
		SELECT @ProductId = Id FROM @Product WHERE Code = 'AGC'
		DECLARE @SQL VARCHAR(4000) = ''
		
		SELECT @SQL = 'SELECT Recommend, Winlostdate, Currency, TurnOver, Winloss '
					+ 'FROM OPENQUERY(DBACC,''SELECT c.recommend, r.Winlostdate, r.Currency, SUM(r.TurnOver) AS TurnOver, SUM(r.Winlost) AS Winloss'
					+						' FROM bodb_report.dbo.rptDepWinlost_AGCasino r WITH (NOLOCK)'
					+						' INNER JOIN bodb02.dbo.Custinfo c WITH (NOLOCK) ON r.CustID = c.CustID'
					+						' INNER JOIN bodb_Licensee.dbo.LicenseeCust l WITH (NOLOCK) ON c.recommend = l.CustID'
					+						' WHERE r.Winlostdate BETWEEN ' + CONVERT( VARCHAR(10),@FromDate, 120) + ' AND ' + CONVERT( VARCHAR(10),@ToDate, 120)
					+						' AND l.LicenseeId = ' + CONVERT(VARCHAR(10), @LicenseeID)
					+						' AND l.RoleId = 2'
					+						' GROUP BY c.recommend, r.Winlostdate, r.Currency'
					+						''')'
	
		INSERT INTO #DataWinloss3rd(Recommend, Winlostdate, Currency, TurnOver, Winloss)
		EXECUTE (@SQL)
		
		INSERT INTO #Result(ProductCode, Turnover, CustomerWL, LicenseeNetWL, AmountDue)
		SELECT
				'AGC'
			,	SUM(r.Turnover					* e.Rate)	AS Turnover
			,	SUM(r.WinLoss					* e.Rate)	AS CustomerWL
			,	- SUM(r.Winloss * ( 1 - c.Rate) * e.Rate)	AS LicenseeNetWL
			,	- SUM(r.WinLoss * c.Rate		* e.Rate)	AS AmountDue
		FROM #DataWinloss3rd r WITH (NOLOCK)
			INNER JOIN @TempAG ag ON r.Recommend = ag.CustId AND r.Currency = ag.CurrencyId
			INNER JOIN @ChargeInfo c ON r.Winlostdate BETWEEN c.Fromdate AND c.Todate
			INNER JOIN #Exchange e ON r.Currency = e.ExchangeID
		WHERE c.Rate > 0
			AND c.ProductID = @ProductId
			AND r.Winlostdate BETWEEN e.ExFromDate AND e.ExToDate
		
		DELETE FROM @Product WHERE Code = 'AGC'
		DROP TABLE #DataWinloss3rd
	END
	
	IF EXISTS (SELECT 1 FROM @Product WHERE Code = 'VG')
	BEGIN
		SELECT @ProductId = Id FROM @Product WHERE Code = 'VG'
		
		INSERT INTO #Result(ProductCode, Turnover, CustomerWL, LicenseeNetWL, AmountDue)
		SELECT
				'VG'
			,	SUM(r.TurnOver					* e.Rate)	AS TurnOver
			,	SUM(r.Winlost					* e.Rate)	AS CustomerWL
			,	- SUM(r.Winlost* ( 1 - c.Rate)	* e.Rate)	AS LicenseeNetWL
			,	- SUM(r.Winlost  * c.Rate		* e.Rate)	AS AmountDue
		FROM bodb_LicenseeReport.dbo.rptDepWinlost_ThirdParty r WITH (NOLOCK)
			INNER JOIN bodb02.dbo.Custinfo co WITH (NOLOCK) ON r.CustID = co.CustID
			INNER JOIN @TempAG ag ON co.recommend = ag.CustId AND r.Currency = ag.CurrencyId
			INNER JOIN @ChargeInfo c ON r.Winlostdate BETWEEN c.Fromdate AND c.Todate
			INNER JOIN #Exchange e ON r.Currency = e.ExchangeID
		WHERE r.Winlostdate BETWEEN @FromDate AND @Todate
			AND r.ProductId = @ProductId
			AND c.Rate > 0
			AND c.ProductID = @ProductId
			AND r.Winlostdate BETWEEN e.ExFromDate AND e.ExToDate
		
		DELETE FROM @Product WHERE Code = 'VG'
	END
	
	IF EXISTS (SELECT 1 FROM @Product WHERE Code = 'GD')
	BEGIN
		SELECT @ProductId = Id FROM @Product WHERE Code = 'GD'
	
		;WITH CTE_GD AS(
			SELECT	b.rptDate
				,	b.CurrencyID
				,	b.Bettype
				,	SUM(b.Turnover)													AS Turnover
				,	SUM(CASE WHEN b.Bettype = @GD_Tip THEN 0 ELSE b.MemberWL END )	AS MemberWL
				,	SUM(CASE WHEN b.Bettype = @GD_Tip THEN - MemberWL ELSE 0 END )	AS TipAmount
			FROM bodb_LicenseeReport.dbo.rpt_BettingByProduct b WITH (NOLOCK)
			WHERE b.rptDate BETWEEN @FromDate AND @ToDate
				AND b.StatusId NOT IN (-1, 101, 102, 103)
				AND b.customercategory NOT IN (27, 28)
				AND b.ProductID = @ProductId
				AND b.SiteId = @LicenseeID
			GROUP BY b.rptDate, b.CurrencyId, b.Bettype
		)
		INSERT INTO #Result( ProductCode, Turnover, CustomerWL, LicenseeNetWL, AmountDue)
		SELECT
				'GD'
			,	SUM(b.Turnover											* e.Rate)	AS Turnover
			,	SUM(b.MemberWL											* e.Rate)	AS CustomerWL
			,	- SUM(b.MemberWL * (1 - c.Rate)							* e.Rate)	AS LicenseeNetWL
			,	SUM(((- b.MemberWL * c.Rate) + (b.TipAmount * c.Rate))	* e.Rate)	AS AmountDue
		FROM CTE_GD b
			INNER JOIN @ChargeInfo c ON b.rptDate BETWEEN c.Fromdate AND c.Todate AND c.Bettype = b.Bettype
			INNER JOIN #Exchange e ON b.CurrencyID = e.ExchangeID
		WHERE c.ProductID = @ProductId
			AND c.Rate > 0
			AND b.rptDate BETWEEN e.ExFromDate AND e.ExToDate
		
		DELETE FROM @Product WHERE Code = 'GD'
	END
	
	IF EXISTS (SELECT 1 FROM @Product WHERE Code = 'BA')
	BEGIN
		SELECT @ProductId = Id FROM @Product WHERE Code = 'BA'
	
		INSERT INTO @Bettype (Bettype)
		(
			SELECT DISTINCT BetType
			FROM bodb02.dbo.f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', 'BA', @IsTest)
		)
	
		INSERT INTO #Result( ProductCode, Turnover, CustomerWL, LicenseeNetWL, AmountDue)
		SELECT
				'BA'
			,	SUM(b.turnover * e.Rate *
						CASE
							WHEN b.[Status] = 111			THEN 0
							WHEN b.[Status] IN (114, 115)	THEN 0.5 
							ELSE 1
						END)											AS turnover
			,	SUM(b.WinLoss								* e.Rate)	AS CustomerWL
			,	SUM(b.CommissionA							* e.Rate)	AS LicenseeNetWL
			,	- SUM((b.WinLoss * c.Rate + b.CommissionA)	* e.Rate)	AS AmountDue
		FROM
			bodb_licenseereport.dbo.rpt_Betting_BA b WITH (NOLOCK)
			INNER JOIN @Bettype bt ON b.Bettype = bt.Bettype
			INNER JOIN @ChargeInfo c ON b.rptDate BETWEEN c.FromDate AND c.ToDate
			INNER JOIN #Exchange e ON b.CurrencyID = e.ExchangeID
		WHERE
			b.SiteID = @LicenseeID
			AND b.[Status] NOT IN (-1, 101, 102, 103)
			AND b.CurrencyID <> 20
			AND c.Rate > 0
			AND c.ProductID = @ProductId
			AND b.rptDate BETWEEN e.ExFromDate AND e.ExToDate
			
		DELETE FROM @Bettype
		DELETE FROM @Product WHERE Code = 'BA'
	END
	
	IF EXISTS (SELECT 1 FROM @Product WHERE Code = 'CB')
	BEGIN
		-- Local variables
		SELECT @ProductId = Id FROM @Product WHERE Code = 'CB'
		DECLARE @CommChargeType INT = 6
		DECLARE @CashInShareChargeType INT = 7

		-- Get Winloss Data
		CREATE TABLE #TempData (
			rptDate							DATETIME,
			CurrencyId						INT,
			Turnover						MONEY,
			TurnoverForCommision			MONEY,
			WinningPrize					MONEY,
			CashOut							MONEY,
			CommisionShare					MONEY,
			CashInShare						MONEY,
			CashInAmount					MONEY
		)

		INSERT INTO #TempData (rptDate, CurrencyId, Turnover, TurnoverForCommision, WinningPrize, CashOut, CashInAmount)
		SELECT	b.rptDate,
				b.CurrencyId,
				SUM(b.Turnover)												AS Turnover,
				SUM(CASE
					WHEN ISNULL(b.TicketType, 0) = 0 THEN b.Turnover
					ELSE b.ExtraAmount
					END)													AS TurnoverForCommision,
				SUM(ISNULL(b.WinPrizeAmount,0))								AS WinningPrize,
				SUM(ISNULL(b.CashOutAmount,0))								AS CashOut,
				SUM(ISNULL(b.BuyBackAmount,0))								AS CashInAmount
		FROM bodb_LicenseeReport.dbo.rpt_BettingByProduct b WITH (NOLOCK)
		JOIN @ChargeInfo c ON b.rptDate BETWEEN c.FromDate AND c.ToDate
		WHERE b.SiteID = @LicenseeID
			AND b.ProductID = @ProductId
			AND b.CustomerCategory NOT IN (27, 28)
			AND b.StatusId NOT IN (-1, 101, 102, 103)
			AND CurrencyId <> 20
			AND c.ChargeType = @CommChargeType -- to remove duplicate we use one of (6,7)
			AND c.ProductID = @ProductId
		GROUP BY rptdate, CurrencyId

		-- Calculate Commision, Cash In Share
		UPDATE #TempData
		SET CommisionShare = td.TurnoverForCommision * cm.Rate,
			CashInShare = td.CashInAmount * ci.Rate
		FROM #TempData td
		JOIN @ChargeInfo AS cm ON cm.ChargeType = @CommChargeType AND (td.rptDate BETWEEN cm.FromDate AND cm.ToDate)
		JOIN @ChargeInfo AS ci ON ci.ChargeType = @CashInShareChargeType AND (td.rptDate BETWEEN ci.FromDate AND ci.ToDate)
		WHERE cm.ProductID = @ProductId AND ci.ProductID = @ProductId

		INSERT INTO #Result(ProductCode, Turnover, CustomerWL, LicenseeNetWL, AmountDue)
		SELECT 
				'CB'
			,	SUM(td.Turnover																			* e.Rate) AS Turnover
			,	SUM((td.WinningPrize + td.CashOut)														* e.Rate) AS CustomerWL
			,	SUM((td.CommisionShare + td.CashInShare)												* e.Rate) AS LicenseeNetWL
			,	SUM((td.Turnover - td.WinningPrize - td.CashOut - td.CommisionShare - td.CashInShare)	* e.Rate) AS AmountDue
		FROM #TempData td
		INNER JOIN #Exchange e ON td.CurrencyID = e.ExchangeID
		WHERE @ToDate BETWEEN e.ExFromDate AND e.ExToDate

		-- Drop temp tables
		DROP TABLE #TempData
		DELETE FROM @Product WHERE Code = 'CB'
	END
	
	IF EXISTS (SELECT 1 FROM @Product WHERE Code = 'CO')
	BEGIN
		SELECT @ProductId = Id FROM @Product WHERE Code = 'CO'
	
		INSERT INTO #Result( ProductCode, Turnover, CustomerWL, LicenseeNetWL, AmountDue)
		SELECT	'CO'
			,	0																							AS Turnover
			,	SUM((b.TicketPayout + b.BuyBackAmt + b.BABuyBackAmt)							* e.Rate)	AS CustomerWL
			,	SUM((b.BuyBackAmt * c.Rate)														* e.Rate)	AS LicenseeNetWL
			,	SUM((b.TicketPayout - b.BuyBackAmt - b.BABuyBackAmt - (b.BuyBackAmt * c.Rate))	* e.Rate)	AS Company
		FROM bodb_licenseereport.dbo.rptLicCashoutSummary b WITH (NOLOCK)
			INNER JOIN @ChargeInfo c ON b.Winlostdate BETWEEN c.FromDate AND c.ToDate
			INNER JOIN #Exchange e ON b.Currency = e.ExchangeID
		WHERE b.SiteId = @LicenseeID 
			AND b.Currency <> 20
			AND b.ProductID = @ProductId
			AND b.RoleID = 1 -- Member
			AND c.Rate > 0
			AND c.ProductID = @ProductId
			AND b.Winlostdate BETWEEN e.ExFromDate AND e.ExToDate
		
		DELETE FROM @Product WHERE Code = 'CO'
	END
	
	IF EXISTS (SELECT 1 FROM @Product WHERE Code = 'BX')
	BEGIN
		SELECT @ProductId = Id FROM @Product WHERE Code = 'BX'
	
		INSERT INTO #Result( ProductCode, Turnover, CustomerWL, LicenseeNetWL, AmountDue)
		SELECT 'BX'
			, SUM(b.turnover												* e.Rate)	AS Turnover
			, SUM((b.MemberWL + b.CommissionP)								* e.Rate)	AS CustomerWL
			, SUM((-b.MemberWL * (1 - c.Rate) + b.CommissionA)				* e.Rate)	AS LicenseeNetWL
			, SUM((-b.MemberWL * c.Rate - (b.CommissionA + b.CommissionP))	* e.Rate)	AS AmountDue
		FROM bodb_LicenseeReport.dbo.rpt_BettingByProduct b WITH (NOLOCK)
			INNER JOIN @ChargeInfo c ON b.SiteId = c.LicenseeID AND b.rptDate BETWEEN c.FromDate AND c.ToDate
			INNER JOIN #Exchange e ON b.CurrencyId = e.ExchangeID
		WHERE b.SiteID = @LicenseeID
			AND b.CurrencyId <> 20
			AND b.ProductID = @ProductId
			AND b.StatusId NOT IN (-1, 101, 102, 103)
			AND b.customercategory NOT IN (27, 28)
			AND c.Rate > 0
			AND c.ProductID = @ProductId
			AND b.rptDate BETWEEN e.ExFromDate AND e.ExToDate
		
		DELETE FROM @Product WHERE Code = 'BX'
	END
	
	IF EXISTS (SELECT 1 FROM @Product WHERE Code = 'PP')
	BEGIN
		SELECT @ProductId = Id FROM @Product WHERE Code = 'PP'
		DECLARE @PromotionPrize INT = 4300
	
		;WITH cte_WinLossData AS(
			SELECT b.rptDate, b.CurrencyID
				, SUM(ISNULL(b.turnover, 0)) AS Turnover
				, SUM(CASE WHEN b.Bettype <> @PromotionPrize THEN ISNULL(b.MemberWL, 0) ELSE 0 END) Winloss
				, SUM(CASE WHEN b.Bettype = @PromotionPrize THEN ISNULL(b.MemberWL, 0) ELSE 0 END) AS WinningPrize
				FROM bodb_LicenseeReport.dbo.rpt_BettingByProduct b WITH (NOLOCK)
				WHERE
					b.ProductID = @ProductId
					AND	b.SiteID = @LicenseeID
					AND b.rptDate BETWEEN @FromDate AND @ToDate
					AND (b.CurrencyID <> 20)
					AND b.[StatusId] NOT IN (-1, 101, 102, 103)
				GROUP BY b.rptdate, b.CurrencyID
		)
		INSERT INTO #Result( ProductCode, Turnover, CustomerWL, LicenseeNetWL, AmountDue)
		SELECT	'PP'
			,	SUM(Turnover							* e.Rate)	AS Turnover
			,	SUM((WinLoss + WinningPrize)			* e.Rate)	AS CustomerWL
			,	SUM(-Winloss * ( 1 - c.Rate)			* e.Rate)	AS LicenseeNetWL
			,	SUM(((-WinLoss * c.Rate) - WinningPrize)* e.Rate)	AS AmountDue
		FROM cte_WinLossData d
			INNER JOIN @ChargeInfo c ON d.rptDate BETWEEN c.Fromdate AND c.Todate
			INNER JOIN #Exchange e ON d.CurrencyId = e.ExchangeID
		WHERE c.Rate > 0
			AND c.ProductID = @ProductId
			AND d.rptDate BETWEEN e.ExFromDate AND e.ExToDate
		GROUP BY rptDate, CurrencyID

		DELETE FROM @Product WHERE Code = 'PP'
	END
	
	IF EXISTS (SELECT TOP 1 1 FROM @Product)
	BEGIN
		SELECT @ProductCode = STUFF(
		(
			SELECT ',' + p.ProductPrefix
			FROM @Product i
			INNER JOIN bodb_licensee.dbo.Product3rd p (NOLOCK) ON i.Id = p.Productid
			FOR XML PATH('')
		), 1, 1, '')
		
		INSERT INTO @Bettype (Bettype, ProductCode)
		(
			SELECT DISTINCT BetType, ProductPrefix
			FROM bodb02.dbo.f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', @ProductCode, @IsTest)
		)
	
		INSERT INTO #Result( ProductCode, Turnover, CustomerWL, LicenseeNetWL, AmountDue)
		SELECT p.Code
			,	SUM(b.turnover											* e.Rate)	AS Turnover
			,	SUM(b.winloss											* e.Rate)	AS CustomerWL
			,	- SUM(b.winloss * ( 1 - c.Rate)							* e.Rate)	AS LicenseeNetWL
			,	- SUM((b.winloss * c.Rate + ISNULL(b.CommissionA, 0))	* e.Rate)	AS AmountDue
		FROM bodb_licenseereport.dbo.rpt_Betting b WITH (NOLOCK)
		INNER JOIN @Bettype bt ON b.Bettype = bt.Bettype
		INNER JOIn @Product p ON bt.ProductCode = p.Code
		INNER JOIN @ChargeInfo c ON p.Id = c.ProductID AND b.rptDate BETWEEN c.Fromdate AND c.Todate
		INNER JOIN #Exchange e ON b.CurrencyId = e.ExchangeID
		WHERE
			b.SiteID = @LicenseeID
			AND b.rptDate BETWEEN @FromDate AND @ToDate
			AND b.CurrencyID <> 20
			AND b.[Status] NOT IN (-1, 101, 102, 103)
			AND b.customercategory NOT IN (27, 28)
			AND c.Rate > 0
			AND b.rptDate BETWEEN e.ExFromDate AND e.ExToDate
		GROUP BY p.Code
	END
	
	INSERT INTO @InvoiceHeader(Id)
	SELECT InvoiceHeaderId
	FROM dbo.LA_InvoiceHeader WITH(NOLOCK)
		WHERE PartyId = @PartyID
		AND StatusId = 0
		AND FromDate = @FromDate
		AND ToDate = @ToDate
		AND ((@Environment = 'PRO' AND Environment IS NULL) OR Environment = @Environment)
	
	IF EXISTS (SELECT TOP 1 1 FROM @InvoiceHeader
	)
	BEGIN
		INSERT INTO @Total([Description], Amount)
		SELECT s.[Description], ISNULL(Income,0) - ISNULL(Expense,0) AS Amount
		FROM dbo.LA_InvoiceStatement s WITH (NOLOCK)
		INNER JOIN @InvoiceHeader h ON s.InvoiceHeaderId = h.Id
		WHERE s.StatusID = 0 AND InvItemTypeId IN (4,5,26)
		ORDER BY s.InvItemTypeId
	END

	SELECT ProductCode, Turnover, CustomerWL, LicenseeNetWL, AmountDue
	FROM #Result
	ORDER BY ProductCode
	
	SELECT ExchangeID AS CurrencyId, Rate
	FROM #Exchange
	
	SELECT [Description], Amount FROM @Total
	
	DROP TABLE #Result
	DROP TABLE #Exchange
END
GO
/*<info serverAlias="DBACC-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_ExtraPayout_OddsBoost_Detail]
	@AgentList			VARCHAR(MAX),
	@FromDate			SMALLDATETIME,
	@ToDate				SMALLDATETIME,
	@MoveBetsDay		SMALLDATETIME,
	@BalanceUpDay		SMALLDATETIME,
	@BaseCurrency		VARCHAR(12)		= ''
AS

/*
	Created: 20250924@Kelvin
	Task: LAP - Extra Payout WL report - OddsBoost level - Detail
	DB: DBACC.bodb02
	Revisions:
		- 20250924@Kelvin: Enhance to count Total Trans & View Detail of Odds Boost Bonus[RedmineID: #239758]

	Param's Explanation:
		+ @PromotionTypeList: promotion type list separated by ','
			- 101: Sportsbook - Odds Boost Bonus (BetType: 997)
*/

BEGIN
	SET NOCOUNT ON

	-- Get agent list
	--===================================================================================================================
	CREATE TABLE #TempAg (CustId INT, Currency INT)

	CREATE CLUSTERED INDEX IX_CustId ON #TempAg (CustId)

	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @AgentList

		INSERT INTO #TempAg (CustId, Currency)
		SELECT AgentId, Currency
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId INT, Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY
	BEGIN CATCH
		SELECT ErrCode = 100,
			ErrMsg = N'Invalid Parameter.'

		RETURN
	END CATCH;
	--===================================================================================================================

	CREATE TABLE #Data
	(
		WinLostDate		SMALLDATETIME,
		CustId			INT,
		Currency		INT,
		RefNo			BIGINT,
		ProductCode		VARCHAR(10),
		PromotionType	SMALLINT,
		CustomerAmount	MONEY
	)

	DECLARE @TempToDate	SMALLDATETIME,
		@TempFromDate	SMALLDATETIME
		
	-- bettrans
	IF @ToDate > @MoveBetsDay
	BEGIN
		SET @TempFromDate = CASE
								WHEN @FromDate <= @MoveBetsDay THEN DATEADD(DAY, 1, @MoveBetsDay)
								ELSE @FromDate
							END

		-- bettrans
		INSERT INTO #Data 
		(
			WinLostDate,
			CustId,
			Currency,
			RefNo,
			ProductCode,
			PromotionType,
			CustomerAmount
		)
		SELECT
			b.winlostdate,
			b.custid,
			b.currency,
			b.TransId,
			'SB' AS ProductCode,
			101 AS PromotionType,
			fOddsBoost.GapAmountBeforePT AS CustomerAmount
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN #TempAg AS a ON a.CustId = b.recommend
			LEFT JOIN dbo.f_Set_OddsTypeBettypes() fdec -- check for decimal odds only
				ON b.bettype = fdec.BetType
			CROSS APPLY dbo.f_Set_Cal_OddBoostAdjustBonus(2, b.odds, b.stake, b.actual_stake, b.scomm, b.winlost, b.awinlost, b.mwinlost, b.swinlost, b.statusID, b.statuswinlost, b.apositiontaking, b.mpositiontaking, b.spositiontaking, b.tpositiontaking, fdec.OddsType, b.ExtraInfo) AS fOddsBoost
		WHERE b.winlostdate BETWEEN @TempFromDate AND @ToDate
			AND b.statusID IN (101, 102, 103, 111, 112, 113) -- reject, void, refund, draw, won, lose
			AND b.OddsType NOT IN (6, 7) -- 6: Exclude Myanmar Odds, 7: Scorebox Odds
			AND betdaqid = -3
	END

	IF @FromDate <= @MoveBetsDay AND @ToDate >= @BalanceUpDay
	BEGIN
		SET @TempToDate = CASE
						WHEN @ToDate >= @MoveBetsDay THEN @MoveBetsDay
						ELSE @ToDate
					END

		SET @TempFromDate = CASE
								WHEN @FromDate < @BalanceUpDay THEN @BalanceUpDay
								ELSE @FromDate
							END
		--bettrans14
		INSERT INTO #Data 
		(
			WinLostDate,
			CustId,
			Currency,
			RefNo,
			ProductCode,
			PromotionType,
			CustomerAmount
		)
		SELECT
			b.winlostdate,
			b.custid,
			b.currency,
			b.TransId,
			'SB' AS ProductCode,
			101 AS PromotionType,
			fOddsBoost.GapAmountBeforePT AS CustomerAmount
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN #TempAg AS a ON a.CustId = b.recommend
			LEFT JOIN dbo.f_Set_OddsTypeBettypes() fdec -- check for decimal odds only
				ON b.bettype = fdec.BetType
			CROSS APPLY dbo.f_Set_Cal_OddBoostAdjustBonus(2, b.odds, b.stake, b.actual_stake, b.scomm, b.winlost, b.awinlost, b.mwinlost, b.swinlost, b.statusID, b.statuswinlost, b.apositiontaking, b.mpositiontaking, b.spositiontaking, b.tpositiontaking, fdec.OddsType, b.ExtraInfo) AS fOddsBoost
		WHERE b.winlostdate BETWEEN @TempFromDate AND @ToDate
			AND b.statusID IN (101, 102, 103, 111, 112, 113) -- reject, void, refund, draw, won, lose
			AND b.OddsType NOT IN (6, 7) -- 6: Exclude Myanmar Odds, 7: Scorebox Odds
			AND betdaqid = -3
	END

	--bettrans_bk
	IF @FromDate < @BalanceUpDay
	BEGIN
		SET @TempToDate = CASE
								WHEN @ToDate >= DATEADD(dd, -1, @BalanceUpDay) THEN DATEADD(dd, -1, @BalanceUpDay)
								ELSE @ToDate
							END
		--bettrans_bk
		INSERT INTO #Data 
		(
			WinLostDate,
			CustId,
			Currency,
			RefNo,
			ProductCode,
			PromotionType,
			CustomerAmount
		)
		SELECT
			b.winlostdate,
			b.custid,
			b.currency,
			b.TransId,
			'SB' AS ProductCode,
			101 AS PromotionType,
			fOddsBoost.GapAmountBeforePT AS CustomerAmount
		FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
			INNER JOIN #TempAg AS a ON a.CustId = b.recommend
			LEFT JOIN dbo.f_Set_OddsTypeBettypes() fdec -- check for decimal odds only
				ON b.bettype = fdec.BetType
			CROSS APPLY dbo.f_Set_Cal_OddBoostAdjustBonus(2, b.odds, b.stake, b.actual_stake, b.scomm, b.winlost, b.awinlost, b.mwinlost, b.swinlost, b.statusID, b.statuswinlost, b.apositiontaking, b.mpositiontaking, b.spositiontaking, b.tpositiontaking, fdec.OddsType, b.ExtraInfo) AS fOddsBoost
		WHERE b.winlostdate BETWEEN @FromDate AND @TempToDate
			AND b.statusID IN (101, 102, 103, 111, 112, 113) -- reject, void, refund, draw, won, lose
			AND b.OddsType NOT IN (6, 7) -- 6: Exclude Myanmar Odds, 7: Scorebox Odds
			AND betdaqid = -3
	END

	-- Get exchange rate
	DECLARE @ExchangeRate TABLE (
		FromDate	SMALLDATETIME,
		ToDate		SMALLDATETIME,
		ExchangeId	INT,
		Rate		FLOAT)

	IF EXISTS (SELECT 1 FROM #Data)
	BEGIN
		INSERT INTO @ExchangeRate(FromDate, ToDate, ExchangeID, Rate)
		SELECT FromDate, ToDate, ExchangeID, Rate
		FROM dbo.Lrf_f_GetExchangeRate(@FromDate, @ToDate, @BaseCurrency, '') e
		WHERE EXISTS (SELECT 1 FROM #TempAg AS a WHERE e.ExchangeID = a.Currency)
	END

	-- Return result
	SELECT
		d.WinLostDate,
		d.Currency,
		SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2)) AS [ExternalID],
		c.username AS [SystemID],
		d.RefNo,
		d.ProductCode,
		d.PromotionType,
		d.CustomerAmount,
		(d.CustomerAmount * e.Rate) AS BasedCustomerAmount
	FROM #Data AS d
		INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON c.custid = d.CustId
		INNER JOIN @ExchangeRate AS e
			ON d.WinLostDate BETWEEN e.FromDate AND e.ToDate
				AND d.Currency = e.ExchangeId
	ORDER BY 
		d.WinLostDate ASC

	DROP TABLE IF EXISTS #TempAg
	DROP TABLE IF EXISTS #Data
END
GO
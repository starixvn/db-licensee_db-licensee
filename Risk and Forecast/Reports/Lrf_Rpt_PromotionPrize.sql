/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_PromotionPrize]
	@AgentId				INT				= 0,
	@UserName				VARCHAR(50)		= '',
	@FromDate				SMALLDATETIME,
	@ToDate					SMALLDATETIME,
	@MoveBetsDay			SMALLDATETIME,
	@AgentList				VARCHAR(MAX),
	@DefaultBaseCurrency	VARCHAR(3),
	@VIPPlayerOnly	BIT = 0
AS

/*
	Created: Amanda@20190304
	Task: Integrate PP Promotion Prize [RedmineID: #109471]
	DB: DBEXT.bodb02

	Revisions:
		- 20190304@Amanda: Get PP Promotion Prize data [RedmineID: #109471]
		- 20190621@Amanda: Add @@DefaultBaseCurrency parameter [Redmine: #112531]
		- 20191017@Amanda: Rename SP from Lrf_Rpt_PP_PromotionPrize to Lrf_Rpt_PromotionPrize and integrate NPH Promotion [Redmine: #120333]
		- 20191122@Amanda: Include PP Tournament Prize [Redmine: #123804]
		- 20191204@Amanda: Change name of NPH Promotion to Saba Promotion [Redmine: #124612]
		- 20200714@Hogan: Add 7 games for Jackpot and 2 bettype for Contribution (4297) and Jackpot Prize (4298) [RedmineID: #137290]
		- 20200803@Kos: Support Saba Loyalty [RedmineID: #138493]
		- 20200820@Hogan: Support filter by VIP player [RedmineID: #138371]
		- 20201013@Hogan: Integrate SA Gaming [RedmineID: #128493]
		- 20201016@Hogan: Integrate Arcadia Gaming Bonus [RedmineID: #143648]
		- 20201104@Hogan: Add new sport Saba.club Free Bets [RedmineID: #142369]

	Param's Explanation:
		+ @MoveBetsDay: The day we move tickets to bettrans14
		+ @AgentList: xml structure
			<ROOT>
				<Agent AgentId="12345" Currency="3"/>
				<Agent AgentId="12345" Currency="5"/>
			</ROOT>
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #PromotionData
	(
		WinLostDate			DATETIME,
		CurrencyId			INT,
		WinLost				MONEY,
		AWinLost			MONEY,
		OddsSpread			MONEY,
		CustId				INT,
		BetType				INT,
		SportType			SMALLINT
	)

	CREATE TABLE #Exchange(FromDate SMALLDATETIME, ToDate SMALLDATETIME, ExchangeID INT, DefaultRate FLOAT)
	CREATE TABLE #tmpCust(CustId INT)
	
	DECLARE @tempAg	TABLE(custID INT, currency INT)
	DECLARE @VIPCust TABLE (CustId INT)

	DECLARE @PPPromotion			SMALLINT = 4300,-- PP Promotion Prize
			@PPTournament			SMALLINT = 4299,-- PP Tournament Prize
			@PPContribution			SMALLINT = 4297,-- PP Contribution
			@PPJackpot				SMALLINT = 4298,-- PP Jackpot Prize
			@CCBonus				SMALLINT = 1906,-- Arcadia Gaming Bonus
			@PPsportType			SMALLINT = 248,
			@SPRsportType			SMALLINT = 246,
			@SAGbetType	 			SMALLINT = 3007,-- Tip ticket of SA Gaming
			@CCsportType			SMALLINT = 165,
			@SAGsportType			SMALLINT = 244,
			@SBCFreeBetsSportType	SMALLINT = 150,
			@PP						VARCHAR(10) = 'PP',
			@SPR					VARCHAR(10) = 'SPR',
			@PPC					VARCHAR(10) = 'PPC',
			@SAG					VARCHAR(10) = 'SAG',
			@CCB					VARCHAR(10) = 'CCB',
			@SBCFB					VARCHAR(10) = 'SBCFB'

	DECLARE @_FromDate SMALLDATETIME,
		@_ToDate SMALLDATETIME

	SELECT @_FromDate = @FromDate,
		@_ToDate = @ToDate

	DECLARE @IsTest BIT = 0
	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
				,@AgentList
		INSERT INTO @TempAg (custID, currency)
		SELECT AgentId, Currency
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId INT, Currency INT) AS Data
		WHERE @AgentId = 0
			OR (@AgentId <> 0 AND AgentId = @AgentId)

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
				,ErrMsg = N'Parameter invalid.'

		RETURN
	END CATCH;

	SELECT @Username = LTRIM(RTRIM(ISNULL(@Username, '')))

	IF @Username <> ''
	BEGIN
		INSERT INTO #tmpCust
		SELECT c.custid
		FROM dbo.Customer c WITH (NOLOCK)
			INNER JOIN @TempAg a ON a.custID = c.recommend
		WHERE (c.username2 LIKE '%$%' + @Username + '%'
				OR c.username LIKE '%' + @Username + '%')
			AND c.roleid = 1
	END

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

	DECLARE @TempFromDate	DATETIME,
		@TempToDate		DATETIME

	IF @_ToDate > @MoveBetsDay
	BEGIN
		IF @_FromDate <= @MoveBetsDay 
			SET @TempFromDate = DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @_FromDate

		INSERT INTO #PromotionData (
			WinLostDate,
			CurrencyId,
			WinLost,
			AWinLost,
			OddsSpread,
			CustId,
			BetType,
			SportType
		)
		SELECT
			b.winlostdate,
			b.currency,
			b.winlost,
			ABS(b.awinlost),
			b.oddsspread,
			b.custid,
			b.bettype,
			b.matchid
		FROM
			dbo.bettrans b WITH (NOLOCK)
			INNER JOIN @tempAg a ON b.recommend = a.custID AND b.Currency = a.Currency
			LEFT JOIN @VIPCust v ON b.custid = v.CustID
		WHERE
			b.winlostdate BETWEEN @TempFromDate AND @_ToDate
			AND((b.bettype IN (@PPPromotion, @PPTournament, @PPJackpot, 17000, 17003, @CCBonus) AND b.statusID = 112)
				OR (b.bettype = @PPContribution AND b.statusID = 111)
				OR (b.bettype = @SAGbetType AND b.statusID = 113)
				OR (b.matchid = @SBCFreeBetsSportType AND b.statusID IN (111,112,113)))
			AND (@VIPPlayerOnly = 0 OR (@VIPPlayerOnly = 1 AND v.custid IS NOT NULL))
	END

	IF @_FromDate <= @MoveBetsDay 
	BEGIN
		IF @_ToDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @_ToDate

		INSERT INTO #PromotionData (
			WinLostDate,
			CurrencyId,
			WinLost,
			AWinLost,
			OddsSpread,
			CustId,
			BetType,
			SportType
		)
		SELECT
			b.winlostdate,
			b.currency,
			b.winlost,
			ABS(b.awinlost),
			b.BuyBackAmt,
			b.custid,
			b.bettype,
			b.sporttype
		FROM 
			bodb_licenseereport.dbo.rptLicWinloss2 b WITH (NOLOCK)
			INNER JOIN @tempAg a ON b.recommend = a.custID AND b.Currency = a.Currency
			LEFT JOIN @VIPCust v ON b.custid = v.CustID
		WHERE 
			b.winlostdate BETWEEN @_FromDate AND @TempToDate
			AND b.sporttype IN (@PPsportType, @SPRsportType, @SAGsportType, @CCsportType, @SBCFreeBetsSportType)
			AND((b.bettype IN (@PPPromotion, @PPTournament, @PPJackpot, 17000, 17003, @CCBonus) AND b.statusID = 112)
				OR (b.bettype = @PPContribution AND b.statusID = 111)
				OR (b.bettype = @SAGbetType AND b.statusID = 113)
				OR (b.sporttype = @SBCFreeBetsSportType AND b.statusID IN (111,112,113)))
			AND b.roleID = 1
			AND (@VIPPlayerOnly = 0 OR (@VIPPlayerOnly = 1 AND v.custid IS NOT NULL))
	END

	IF @Username <> ''
	BEGIN
		DELETE d
		FROM #PromotionData d
			LEFT JOIN #tmpCust c ON d.custid = c.custid
		WHERE c.custid IS NULL
	END

	-- #Region: Handle Exchange Rate
	DECLARE @MinDate SMALLDATETIME, @MaxDate SMALLDATETIME
	
	SELECT @MinDate = MIN (winlostdate),
		@MaxDate = MAX (winlostdate)
	FROM #PromotionData
	
	INSERT INTO #Exchange(FromDate, ToDate, ExchangeID, DefaultRate)
	SELECT FromDate, ToDate, ExchangeID, DefaultRate
	FROM dbo.Lrf_f_GetExchangeRate(@MinDate, @MaxDate, '', @DefaultBaseCurrency)

	-- #Region: Return data
	SELECT
		p.BetType,
		p.SportType,
		CASE
			WHEN p.BetType IN (17000, 17003) THEN @SPR
			WHEN p.BetType = @PPContribution THEN @PPC
			WHEN p.BetType = @SAGbetType THEN @SAG
			WHEN p.BetType = @CCBonus THEN @CCB
			When p.SportType = @SBCFreeBetsSportType THEN @SBCFB
			ELSE @PP
		END AS ProductCode,
		SUM(p.Winlost * e.DefaultRate)		AS SumAmount,
		SUM(p.Awinlost * e.DefaultRate)		AS SumContributionAmount,
		SUM(p.Oddsspread * e.DefaultRate)	AS SumTurnover,
		CASE 
			WHEN p.BetType = @SAGbetType THEN SUM(p.AWinlost* e.DefaultRate) 
			ELSE 0 END AS SumTipSharing
	FROM #PromotionData p
		INNER JOIN #Exchange e ON e.ExchangeID = p.CurrencyId AND p.winlostdate BETWEEN e.FromDate AND e.ToDate
	GROUP BY p.BetType, p.SportType

	SELECT
		p.BetType,
		p.SportType,
		CASE
			WHEN p.BetType IN (17000, 17003) THEN @SPR
			WHEN p.BetType = @PPContribution THEN @PPC
			WHEN p.BetType = @SAGbetType THEN @SAG
			WHEN p.BetType = @CCBonus THEN @CCB
			When p.SportType = @SBCFreeBetsSportType THEN @SBCFB
			ELSE @PP
		END AS ProductCode,
		p.winlostdate		AS [Date],
		p.CurrencyId,
		SUM(p.Winlost)		AS Amount,
		SUM(p.Awinlost)		AS ContributionAmount,
		CASE WHEN p.BetType = @SAGbetType THEN SUM(p.AWinlost) ELSE 0 END AS TipSharing,
		SUM(p.Oddsspread)	AS Turnover,
		c.username			AS UserName,
		SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2)) AS NickName
	FROM #PromotionData p
		INNER JOIN dbo.Customer c WITH (NOLOCK) ON p.CustId = c.custid
	GROUP BY
		p.BetType,
		p.SportType,
		p.winlostdate,
		p.CustId,
		p.CurrencyId,
		c.username,
		c.username2
	ORDER BY p.winlostdate

	DROP TABLE #PromotionData
	DROP TABLE #Exchange
END
GO
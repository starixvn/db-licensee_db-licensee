/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_CashOut_Mem]
	@AgentList				VARCHAR(MAX),
	@FromDate				SMALLDATETIME,
	@ToDate					SMALLDATETIME,
	@MoveBetsDay			SMALLDATETIME,
	@BaseCurrency			VARCHAR(12)		= '',
	@DefaultBaseCurrency	VARCHAR(12)		= ''
AS

/*
	Created: 20211217@Kos
	Task: LAP - Cash Out Win Loss report for new model - Member level
	DB: DBEXT.bodb02

	Revisions:
		- 20211217@Kos: New SP [RedmineID: #165160]
		- 20220222@Kos: Hotfix - show agent data [RedmineID: #168905]
		- 20220914@Evan: Expand length of @BaseCurrency [Redmine #177481]

	Param's Explanation:
		+ @AgentList: XML structure
			<ROOT>
				<Agent AgentId="12345" Currency="3"/>
				<Agent AgentId="12345" Currency="5"/>
			</ROOT>
*/

BEGIN
	SET NOCOUNT ON

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

	-- Get sport type list
	DECLARE @SportType TABLE (SportType INT PRIMARY KEY, ProductCode VARCHAR(10))

	INSERT INTO @SportType (SportType, ProductCode)
	SELECT DISTINCT SportType, ProductCode
	FROM dbo.f_LicWinLoss_ProductSportType_Sel('SB')

	-- Get bettype list
	DECLARE @BetType TABLE (BetType INT PRIMARY KEY, ProductCode VARCHAR(10))

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @BetType (BetType, ProductCode)
	SELECT DISTINCT BetType, ProductPrefix
	FROM dbo.f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', 'SB', @IsTest)
	WHERE BetType NOT IN (9, 29, 10, 914, 901, 902, 903, 904)

	DECLARE @Data TABLE (
		CustId		INT,
		WinLostDate	SMALLDATETIME,
		Currency	INT,
		BetCount	BIGINT,
		Turnover	MONEY,
		WinLost		MONEY,
		LicenseeWL	MONEY,
		PlayerComm	MONEY,
		BAComm		MONEY,
		AmtDueToBA	MONEY
	)

	DECLARE
		@_FromDate	SMALLDATETIME,
		@_ToDate	SMALLDATETIME

	SELECT @_FromDate = @FromDate,
		@_ToDate = @ToDate

	DECLARE @TempFromDate	SMALLDATETIME,
		@TempToDate			SMALLDATETIME

	-- bettrans range
	IF @_ToDate > @MoveBetsDay
	BEGIN
		SET @TempFromDate = CASE
								WHEN @_FromDate <= @MoveBetsDay THEN DATEADD(DAY, 1, @MoveBetsDay)
								ELSE @_FromDate
							END

		INSERT INTO @Data (
			CustId,
			WinLostDate,
			Currency,
			BetCount,
			Turnover,
			WinLost,
			LicenseeWL,
			PlayerComm,
			BAComm,
			AmtDueToBA )
		SELECT
			b.custid,
			b.winlostdate,
			b.currency,
			COUNT(1) AS BetCount,
			SUM(b.stake) AS Turnover,
			SUM(b.winlost - b.actual_stake) AS WinLost,
			-SUM(CASE WHEN b.tpositiontaking <> 0 THEN b.winlost - b.actual_stake ELSE 0 END) AS LicenseeWL,
			SUM(b.playerComm) AS PlayerComm,
			SUM(CASE WHEN b.tpositiontaking = 0 THEN b.comm ELSE 0 END) AS BAComm,
			-SUM(CASE
					WHEN b.tpositiontaking = 0 THEN b.winlost - b.actual_stake + b.awinlost + b.comm
					ELSE 0
				END) AS AmtDueToBA
		FROM
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN #TempAg AS a ON a.CustId = b.recommend
			INNER JOIN @BetType AS bt ON bt.bettype = b.bettype
		WHERE
			b.winlostdate BETWEEN @TempFromDate AND @_ToDate
			AND b.statusID IN (111, 112, 113)
			AND b.betdaqid = -2
		GROUP BY
			b.custid,
			b.winlostdate,
			b.currency
	END

	-- bettrans14 & bettrans_bk range
	IF @_FromDate <= @MoveBetsDay
	BEGIN
		SET @TempToDate = CASE
							WHEN @_ToDate >= @MoveBetsDay THEN @MoveBetsDay
							ELSE @_ToDate
						END

		INSERT INTO @Data (
			CustId,
			WinLostDate,
			Currency,
			BetCount,
			Turnover,
			WinLost,
			LicenseeWL,
			PlayerComm,
			BAComm,
			AmtDueToBA )
		SELECT
			b.custid,
			b.winlostdate,
			b.currency,
			SUM(b.betcount) AS BetCount,
			SUM(b.turnover) AS Turnover,
			SUM(b.winlost) AS WinLost,
			-SUM(CASE WHEN b.isBA = 0 THEN b.winlost ELSE 0 END) AS LicenseeWL,
			SUM(b.playercomm) AS PlayerComm,
			SUM(CASE WHEN b.isBA = 1 THEN b.comm ELSE 0 END) AS BAComm,
			-SUM(CASE WHEN b.isBA = 1 THEN b.winlost + b.awinlost + b.comm ELSE 0 END) AS AmountDueToBA
		FROM
			bodb_LicenseeReport.dbo.rptLicWinloss2 AS b WITH (NOLOCK)
			INNER JOIN #TempAg AS a ON a.CustId = b.recommend
			INNER JOIN @SportType AS s ON s.SportType = b.sporttype
		WHERE
			b.winlostdate BETWEEN @FromDate AND @TempToDate
			AND b.statusID <> 101	--exclude REJECT
			AND b.bettype NOT IN (901, 902, 903, 904, 914, 9, 29, 10)
			AND b.TicketType = 1
			AND b.roleid = 1
		GROUP BY
			b.custid,
			b.winlostdate,
			b.currency
	END

	DELETE FROM @Data WHERE BetCount = 0

	-- Get exchange rate
	DECLARE @ExchangeRate TABLE (
		FromDate	SMALLDATETIME,
		ToDate		SMALLDATETIME,
		ExchangeId	INT,
		Rate		FLOAT)

	IF EXISTS (SELECT TOP(1) 1 FROM @Data)
	BEGIN
		INSERT INTO @ExchangeRate(FromDate, ToDate, ExchangeID, Rate)
		SELECT FromDate, ToDate, ExchangeID, Rate
		FROM dbo.Lrf_f_GetExchangeRate(@_FromDate, @_ToDate, @BaseCurrency, '') e
		WHERE EXISTS (SELECT 1 FROM #TempAg AS a WHERE e.ExchangeID = a.Currency)
	END

	SELECT
		d.CustId,
		c.username,
		SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS Nickname,
		d.Currency,
		SUM(d.BetCount) AS Betcount,
		CAST(SUM(d.Turnover)	AS MONEY) AS Turnover,
		CAST(SUM(d.WinLost)		AS MONEY) AS WinLost,
		CAST(SUM(d.LicenseeWL)	AS MONEY) AS LicenseeWL,
		CAST(SUM(d.PlayerComm)	AS MONEY) AS PlayerComm,
		CAST(SUM(d.BAComm)		AS MONEY) AS BAComm,
		CAST(SUM(d.AmtDueToBA)	AS MONEY) AS AmtDuetoBA,
		CAST(SUM(d.Turnover		* e.Rate) AS MONEY) AS BasedTurnover,
		CAST(SUM(d.WinLost		* e.Rate) AS MONEY) AS BasedWinLost,
		CAST(SUM(d.LicenseeWL	* e.Rate) AS MONEY) AS BasedLicenseeWL,
		CAST(SUM(d.PlayerComm	* e.Rate) AS MONEY) AS BasedPlayerComm,
		CAST(SUM(d.BAComm		* e.Rate) AS MONEY) AS BasedBAComm,
		CAST(SUM(d.AmtDueToBA	* e.Rate) AS MONEY) AS BasedAmtDuetoBA
	FROM @Data AS d
		INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON c.custid = d.CustId
		INNER JOIN @ExchangeRate AS e
			ON d.WinLostDate BETWEEN e.FromDate AND e.ToDate
				AND d.currency = e.ExchangeId
	GROUP BY
		d.CustId,
		c.username,
		SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)),
		d.Currency
	ORDER BY c.username ASC

	DROP TABLE #TempAg
END
GO

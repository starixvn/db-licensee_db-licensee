/*<info serverAlias="DBEXT-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_MatchWinLossByOutrightParlay]
	@AgentList		VARCHAR(MAX),
	@Date			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@ProductList	VARCHAR(500),
	@ShowBA			BIT				= 0,
	@BaseCurrency	VARCHAR(12)		= ''
AS

/*
	Created: 20120529@don
	DB: DBEXT.bodb02
	Original: Lrf_Rpt_MatchWinLossDetail

	Revisions:
		- 20120725@Henry: if bettype 29 then show actual_stake else stake
		- 20120803@Jim: add PlayerComm value ( for give commission to member)
		- 20120913@Jim: Split column LicenseeWL to separate product
		- 20121004@Jim: replace @currencyname input param by @currencyID
		- 20130404@Jim: set default @ShowSB=0
		- 20130514@Jim: Restrict permission of Licensee Users by currency
		- 20140620@Florent: add column betcount
		- 20141111@Jim: changing currency for KeenOcean member  (#Redmine 25673)
		- 20150123@Jim: support base on Currency GBP
		- 20170227@Harper: LRF - Get data by @AgentList instead of @UserID [RedmineID: #71679]
		- 20170704@Harper: LRF - Integrate Bet Radar Virtual Sports [RedmineID: #78241]
		- 20180808@Amanda: Remove Racing [RedmineID: #99378]
		- 20190620@Amanda: Add Base currency param [RedmineID: #112531]
		- 20201231@Louis: Integrate Happy 5 Linked Games [RedmineID: #147446]
		- 20210120@Kos: Support bk range [RedmineID: #151151]
					- Remove input params @showSB, @showNG, @ShowVS, @showVS2, @ShowCS
					- Add input param @ProductList VARCHAR(500)
					- Don't return column HomeId, AwayId, IsNeutral, MatchCode, Race, MatchId, LeagueId anymore
					- Rename output column from MemberWinLost to WinLost
		- 20220914@Evan: Expand length of @BaseCurrency [Redmine #177481]
		- 20241701@Evan: Merge VS, VS2, VS3 as VS only [RedmineID: #199523]
		- 20242901@Evan: Integrate VS4 [RedmineID: #199347]

	Param's Explanation:
		+ @AgentList: XML structure
			<ROOT>
				<Agent AgentId="12345" Currency="3"/>
				<Agent AgentId="12345" Currency="5"/>
			</ROOT>
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @TempAg TABLE (CustId INT, Currency INT)
	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @AgentList

		INSERT INTO @TempAg (CustId, Currency)
		SELECT AgentId, Currency
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId INT, Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100,
			ErrMsg = N'Parameter invalid.'

		RETURN
	END CATCH;

	DECLARE @ShowSB	BIT = 0

	IF ',' + @ProductList + ',' LIKE '%,SB,%'
		SET @ShowSB = 1

	IF @ShowBA = 1
		SET @ProductList = @ProductList + ',SB'

	SELECT @ProductList = STRING_AGG(b.ProductPrefix, ',')
	FROM (
		SELECT DISTINCT ISNULL(b.ProductPrefix,a.Value) AS ProductPrefix
		FROM STRING_SPLIT(@ProductList, ',') a
			LEFT JOIN dbo.Lrf_f_GroupProduct() b ON a.Value = b.GroupProductPrefix
	) b
			
	DECLARE @BetType TABLE (BetType INT PRIMARY KEY, ProductCode VARCHAR(10), EventType TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @BetType (BetType, ProductCode, EventType)
	SELECT DISTINCT a.BetType, ISNULL(b.GroupProductPrefix,a.ProductPrefix), a.EventType
	FROM dbo.f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', @ProductList, @IsTest) a
		LEFT JOIN dbo.Lrf_f_GroupProduct() b ON a.ProductPrefix = b.ProductPrefix
	WHERE EventType IN (0, 2)
		AND BetType NOT IN (SELECT BetType FROM dbo.Lrf_f_SelExcludedBetType())

	DECLARE @Data TABLE (
		ProductCode	VARCHAR(10),
		BetType		SMALLINT,
		Currency	INT,
		BetCount	INT,
		Turnover	MONEY,
		WinLost		MONEY,
		PlayerComm	MONEY,
		LicenseeWL	MONEY,
		CommBA		MONEY,
		AmtDueToBA	MONEY )

	DECLARE @_Date AS SMALLDATETIME

	SET @_Date = @Date

	-- bettrans
	IF @_Date > @MoveBetsDay
	BEGIN
		INSERT INTO @Data (
			ProductCode,
			BetType,
			Currency,
			BetCount,
			Turnover,
			WinLost,
			PlayerComm,
			LicenseeWL,
			CommBA,
			AmtDueToBA )
		SELECT
			bt.ProductCode,
			b.bettype,
			b.currency,
			COUNT(1) AS BetCount,
			SUM(b.stake) AS Turnover,
			SUM(b.winlost - b.actual_stake) AS WinLost,
			SUM(b.playercomm) AS PlayerComm,
			-SUM(CASE
					WHEN bt.ProductCode = 'SB' AND b.tpositiontaking = 0 THEN 0
					ELSE b.winlost - b.actual_stake
				END) AS LicenseeWL,
			SUM(CASE
					WHEN bt.ProductCode = 'SB' AND b.tpositiontaking = 0 THEN b.comm
					ELSE 0
				END) AS CommBA,
			SUM(CASE
					WHEN bt.ProductCode = 'SB' AND b.tpositiontaking = 0 THEN b.winlost - b.actual_stake + b.awinlost + b.comm
					ELSE 0
				END) AS AmountDueToBA
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN @TempAg AS a ON a.CustId = b.recommend
			INNER JOIN @BetType AS bt ON bt.BetType = b.bettype
		WHERE b.winlostdate = @_Date
			AND b.statusID IN (111, 112, 113)
			AND CASE
					WHEN @ShowBA = 0 AND bt.ProductCode = 'SB' AND b.tpositiontaking = 0 THEN 0
					WHEN @ShowSB = 0 AND bt.ProductCode = 'SB' AND b.tpositiontaking <> 0 THEN 0
					ELSE 1
				END <> 0
		GROUP BY
			bt.ProductCode,
			b.bettype,
			bt.EventType,
			b.currency
	END

	-- bettrans14 & bettrans_bk
	IF @_Date <= @MoveBetsDay
	BEGIN
		INSERT INTO @Data (
			ProductCode,
			BetType,
			Currency,
			BetCount,
			Turnover,
			WinLost,
			PlayerComm,
			LicenseeWL,
			CommBA,
			AmtDueToBA )
		SELECT
			bt.ProductCode,
			b.bettype,
			b.currency,
			SUM(b.betcount) AS BetCount,
			SUM(b.stake) AS Turnover,
			SUM(b.winlost) AS WinLost,
			SUM(b.playercomm) AS PlayerComm,
			-SUM(CASE
					WHEN bt.ProductCode = 'SB' AND b.isBA = 1 THEN 0
					ELSE b.winlost
				END) AS LicenseeWL,
			SUM(CASE
					WHEN bt.ProductCode = 'SB' AND b.isBA = 1 THEN b.comm
					ELSE 0
				END) AS CommBA,
			SUM(CASE
					WHEN bt.ProductCode = 'SB' AND b.isBA = 1 THEN b.winlost + b.awinlost + b.comm
					ELSE 0
				END) AS AmountDueToBA
		FROM bodb_LicenseeReport.dbo.rptWinlostbyLeague AS b WITH (NOLOCK)
			INNER JOIN @TempAg AS a ON a.CustId = b.recommend
			INNER JOIN @BetType AS bt ON bt.BetType = b.bettype
		WHERE b.winlostdate = @_Date
			AND b.statusID <> 101
			AND CASE
					WHEN @ShowBA = 0 AND bt.ProductCode = 'SB' AND b.isBA = 1 THEN 0
					WHEN @ShowSB = 0 AND bt.ProductCode = 'SB' AND b.isBA = 0 THEN 0
					ELSE 1
				END <> 0
		GROUP BY
			bt.ProductCode,
			b.bettype,
			bt.EventType,
			b.currency
	END

	DECLARE @ExchangeDaily TABLE (ExchangeId INT, Rate FLOAT)

	INSERT INTO @ExchangeDaily(ExchangeId, Rate)
	SELECT ExchangeID, Rate
	FROM dbo.Lrf_f_GetExchangeRate(@_Date, @_Date, @BaseCurrency, '')

	-- Result
	SELECT
		b.ProductCode,
		ISNULL(ss.GroupTypeId,b.bettype) AS bettype,  
		SUM(b.BetCount) AS BetCount,
		CAST(SUM(b.Turnover		* e.Rate) AS MONEY) AS Turnover,
		CAST(SUM(b.WinLost		* e.Rate) AS MONEY) AS WinLost,
		CAST(SUM(b.LicenseeWL	* e.Rate) AS MONEY) AS LicenseeWL,
		CAST(SUM(b.CommBA		* e.Rate) AS MONEY) AS CommBA,
		CAST(SUM(b.PlayerComm	* e.Rate) AS MONEY) AS PlayerComm,
		CAST(SUM(b.AmtDueToBA	* e.Rate) AS MONEY) AS AmtDuetoBA
	FROM @Data AS b
		INNER JOIN @ExchangeDaily AS e ON e.ExchangeId = b.Currency
		LEFT JOIN dbo.Lrf_f_GroupBettype() ss ON b.bettype = ss.bettype
	GROUP BY b.ProductCode, ISNULL(ss.GroupTypeId,b.bettype)  
END
GO
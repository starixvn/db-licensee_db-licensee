/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_MatchWinLoss]
	@AgentList		VARCHAR(MAX),
	@Date			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@ProductList	VARCHAR(500),
	@ShowBA			BIT				= 0,
	@BaseCurrency	VARCHAR(3) = ''
AS

/*
	Created: 20120529@Don
	DB: DBEXT.bodb02
	Original: Lrf_Rpt_MatchWinLoss

	Revisions:
		- 20120815@Henry: add live casino
		- 20120820@Jim: add more bettype, sporttype, showtime columns in the result
		- 20120831@Jim: add virtual sport
		- 20121004@Jim: replace @currency input param by @currencyID
		- 20121115@Henry: Only Sportsbook needs to exclude BA
		- 20121128@Henry: use new table LicenseeBATransaction_active to get bettrans BA tickets
		- 20130401@Scott: add more parameter @ShowCS,@ShowBG
		- 20130514@Jim: Restrict permission of Licensee Users by currency
		- 20130809@Jim: offer Virtual Horse Racing
		- 20140423@Kyan: offer Virtual Speedway, Virtual Cycling
		- 20140620@Florent: offer 14 new bettypes and Sporting Solution (36 new bettypes)
		- 20140915@Florent: hotfix duplicated VS bettype
		- 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
		- 20150123@Jim: support base on Currency GBP
		- 20150123@Jim: support base on Currency GBP
		- 20150622@Winnie: exclude 3 transactions SOLD/BOUGHT/BetTrade Commission 
		- 20160727@Jim:  LRF - Commercial terms changed for Bet Trade [Redmine: #61342]
		- 20170227@Harper: LRF - Get data by @AgentList instead of @UserID [RedmineID: #71679]
		- 20170327@Paul: Implement Cash Out [RedmineID :#71727]
		- 20170704@Harper: LRF - Integrate Bet Radar Virtual Sports [RedmineID: #78241]
		- 20180129@Harper: Remove LC from product list [RedmineID: #85965]
		- 20180808@Amanda: Remove Racing, Bingo [RedmineID: #99378]
		- 20181019@Amanda: Add new bet types for E-Sports 2.0 [RedmineID: #100721]
		- 20190620@Amanda: Add Base currency param [RedmineID: #112531]
		- 20191118@Amanda: Remove unused param [RedmineID: #120336]
		- 20190312@Amanda: Add new bet types Single Match Parlay (ID: 38) [RedmineID: #108298]
		- 20200508@Vickie: Add new bet types for E-Sports 2.0 [RedmineID: #132548]
		- 20200623@Kos: Integrate archive process for table VSRaceInfo [Redmine: #136285]
		- 20201001@Louis: Licensee Spread Setting [RedmineID: #142532]
		- 20210115@Kos: Enhance to remove hard code [RedmineID: #148808]
					- Remove input params @showSB, @showNG, @ShowVS, @showVS2
					- Add input param @ProductList VARCHAR(500)
					- Rename output column from MemberWinLost to WinLost

	Param's Explanation:
		+ @AgentList: XML structure
			<ROOT>
				<Agent AgentId="12345" Currency="3"/>
				<Agent AgentId="12345" Currency="5"/>
			</ROOT> 
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @TempAg AS TABLE (CustId INT, Currency INT)
	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @AgentList

		INSERT INTO @TempAg (custID, currency)
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

	DECLARE @BetType TABLE (BetType INT PRIMARY KEY, ProductCode VARCHAR(10), EventType TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @BetType (BetType, ProductCode, EventType)
	SELECT DISTINCT BetType, ProductPrefix, EventType
	FROM dbo.f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', @ProductList, @IsTest)
	WHERE EventType IN (1, 3)
		AND BetType NOT IN (SELECT BetType FROM dbo.Lrf_f_SelExcludedBetType())

	DECLARE @Data TABLE (
		MatchId			INT,
		MatchCode		NVARCHAR(50),
		HomeId			INT,
		AwayId			INT,
		KickOffTime		DATETIME,
		IsNeutral		BIT,
		LeagueId		INT,
		ProductName		VARCHAR(4),
		EventType		TINYINT,
		SportType		SMALLINT,
		Currency		INT,
		BetCount		INT,
		Turnover		MONEY,
		WinLost			MONEY,
		PlayerComm		MONEY,
		LicenseeWL		MONEY,
		CommBA			MONEY,
		AmtDueToBA		MONEY
	)

	DECLARE @_Date AS SMALLDATETIME

	SET @_Date = @Date

	-- bettrans
	IF @_Date > @MoveBetsDay
	BEGIN
		INSERT INTO @Data (
			MatchId,
			ProductName,
			EventType,
			Currency,
			BetCount,
			Turnover,
			WinLost,
			PlayerComm,
			LicenseeWL,
			CommBA,
			AmtDueToBA )
		SELECT
			CASE bt.EventType
				WHEN 3 THEN b.oddsid
				ELSE b.matchid
			END AS MatchId,
			CASE
				WHEN bt.ProductCode = 'SB' AND b.tpositiontaking = 0 THEN 'BA'
				ELSE bt.ProductCode
			END AS ProductName,
			bt.EventType,
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
					WHEN bt.ProductCode = 'SB' AND b.tpositiontaking = 0 THEN b.Winlost + b.awinlost + b.comm
					ELSE 0
				END) AS AmountDueToBA
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN @TempAg AS a ON b.recommend = a.CustId AND b.currency = a.Currency
			INNER JOIN @BetType AS bt ON bt.BetType = b.bettype
		WHERE b.winlostdate = @_Date
			AND b.statusID IN (111, 112, 113)
			AND CASE
					WHEN @ShowBA = 0 AND bt.ProductCode = 'SB' AND b.tpositiontaking = 0 THEN 0
					WHEN @ShowSB = 0 AND bt.ProductCode = 'SB' AND b.tpositiontaking <> 0 THEN 0
					ELSE 1
				END <> 0
		GROUP BY
			CASE bt.EventType
				WHEN 3 THEN b.oddsid
				ELSE b.matchid
			END,
			CASE
				WHEN bt.ProductCode = 'SB' AND b.tpositiontaking = 0 THEN 'BA'
				ELSE bt.ProductCode
			END,
			bt.EventType,
			b.currency

		UPDATE b
		SET
			b.HomeId = m.homeid,
			b.AwayId = m.awayid,
			b.LeagueId = m.leagueid,
			b.MatchCode = m.matchcode,
			b.SportType = m.sporttype,
			b.IsNeutral = ISNULL(m.IsNeutral, CONVERT(BIT, 0))
		FROM @Data AS b
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON m.matchid = b.MatchId
		WHERE b.EventType = 1

		UPDATE b
		SET
			b.MatchId = o.EventID,
			b.HomeId = 0,
			b.AwayId = 0,
			b.KickOffTime = r.EventTime,
			b.LeagueId = r.LeagueID,
			b.MatchCode = '',
			b.SportType = r.SportType,
			b.IsNeutral = 0
		FROM @Data AS b
			INNER JOIN dbo.VSOutright AS o WITH (NOLOCK) ON o.Orid = b.MatchId
			INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
		WHERE b.EventType = 3
	END

	-- bettrans14
	IF @_Date <= @MoveBetsDay
	BEGIN
		INSERT INTO @Data (
			MatchId,
			ProductName,
			EventType,
			Currency,
			BetCount,
			Turnover,
			WinLost,
			PlayerComm,
			LicenseeWL,
			CommBA,
			AmtDueToBA )
		SELECT
			CASE bt.EventType
				WHEN 3 THEN b.oddsid
				ELSE b.matchid
			END AS MatchId,
			CASE
				WHEN bt.ProductCode = 'SB' AND b.isBA = 1 THEN 'BA'
				ELSE bt.ProductCode
			END AS ProductName,
			bt.EventType,
			b.currency,
			COUNT(1) AS BetCount,
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
					WHEN bt.ProductCode = 'SB' AND b.isBA = 1 THEN b.Winlost + b.awinlost + b.comm
					ELSE 0
				END) AS AmountDueToBA
		FROM bodb_licenseereport.dbo.rptWinlostbyLeague AS b WITH (NOLOCK)
			INNER JOIN @TempAg AS a ON a.CustId = b.recommend AND a.Currency = b.currency
			INNER JOIN @BetType AS bt ON bt.BetType = b.bettype
		WHERE b.winlostdate = @_Date
			AND b.statusID <> 101
			AND CASE
					WHEN @ShowBA = 0 AND bt.ProductCode = 'SB' AND b.isBA = 1 THEN 0
					WHEN @ShowSB = 0 AND bt.ProductCode = 'SB' AND b.isBA = 0 THEN 0
					ELSE 1
				END <> 0
		GROUP BY
			CASE bt.EventType
				WHEN 3 THEN b.oddsid
				ELSE b.matchid
			END,
			CASE
				WHEN bt.ProductCode = 'SB' AND b.isBA = 1 THEN 'BA'
				ELSE bt.ProductCode
			END,
			bt.EventType,
			b.currency

		UPDATE b
		SET
			b.HomeId = m.homeid,
			b.AwayId = m.awayid,
			b.LeagueId = m.leagueid,
			b.MatchCode = m.matchcode,
			b.SportType = m.sporttype,
			b.IsNeutral = ISNULL(m.IsNeutral, CONVERT(BIT, 0))
		FROM @Data AS b
			INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON m.matchid = b.MatchId
		WHERE b.EventType = 1

		UPDATE b
		SET
			b.MatchId = o.EventID,
			b.HomeId = 0,
			b.AwayId = 0,
			b.KickOffTime = r.EventTime,
			b.LeagueId = r.LeagueID,
			b.MatchCode = '',
			b.SportType = r.SportType,
			b.IsNeutral = 0
		FROM @Data AS b
			INNER JOIN dbo.VSOutright14 AS o WITH (NOLOCK) ON o.Orid = b.MatchId
			INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
		WHERE b.EventType = 3
	END

	DECLARE @ExchangeDaily TABLE(ExchangeId INT, Rate FLOAT)

	INSERT INTO @ExchangeDaily(ExchangeId, Rate)
	SELECT ExchangeId, Rate
	FROM dbo.Lrf_f_GetExchangeRate(@_Date, @_Date, @BaseCurrency, '')

	-- Result
	SELECT
		b.MatchId,
		ISNULL(b.MatchCode, '') AS MatchCode,
		b.HomeId,
		b.AwayId,
		ISNULL(b.KickOffTime, 0) AS KickOffTime,
		b.IsNeutral,
		b.LeagueId,
		b.ProductName,
		b.SportType,
		SUM(b.BetCount) AS BetCount,
		CAST(SUM(b.Turnover		* e.Rate) AS MONEY) AS Turnover,
		CAST(SUM(b.WinLost		* e.Rate) AS MONEY) AS WinLost,
		CAST(SUM(b.LicenseeWL	* e.Rate) AS MONEY) AS LicenseeWL,
		CAST(SUM(b.CommBA		* e.Rate) AS MONEY) AS CommBA,
		CAST(SUM(b.PlayerComm	* e.Rate) AS MONEY) AS PlayerComm,
		CAST(SUM((b.AmtDueToBA)	* e.Rate) AS MONEY) AS AmtDuetoBA
	FROM @Data AS b
		INNER JOIN @ExchangeDaily AS e ON e.ExchangeId = b.Currency
	GROUP BY
		b.MatchId,
		ISNULL(b.MatchCode, ''),
		b.HomeId,
		b.AwayId,
		ISNULL(b.KickOffTime, 0),
		b.IsNeutral,
		b.LeagueId,
		b.ProductName,
		b.SportType
	ORDER BY CASE ProductName
				WHEN 'SB' THEN 0
				WHEN 'NG' THEN 1
				ELSE 2
			END
END
GO

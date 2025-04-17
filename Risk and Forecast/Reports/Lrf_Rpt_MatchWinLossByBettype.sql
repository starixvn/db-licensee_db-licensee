/*<info serverAlias="DBEXT-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_MatchWinLossByBettype]
	@AgentList		VARCHAR(MAX),
	@MatchId		INT,
	@Date			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME,
	@ProductList	VARCHAR(500),
	@BaseCurrency	VARCHAR(12)		= '',
	@EventType		TINYINT         = NULL
AS

/*
	Created: 20120529@Don
	DB: DBEXT.bodb02
	Original: Lrf_Rpt_MatchWinLossDetail
	Revisions:
		- 20120815@Henry: add live casino
		- 20120904@Jim : add virtual Sport
		- 20121004@Jim: replace @currencyname input param by @currencyID
		- 20121115@Henry: Only Sportsbook needs to exclude BA
		- 20121128@Henry: use new table LicenseeBATransaction_active to get bettrans BA tickets
		- 20130401@Scott: add more parameter @ShowCS,@ShowBG
		- 20130514@Jim: Restrict permission of Licensee Users by currency
		- 20130809@Jim: offer Virtual Horse Racing
		- 20131203@Jim: offer Virtual Greyhound, Virtual Motor Racing
		- 20130423@Kyan: offer Virtual Speedway, Virtual Cycling 
		- 20140620@Florent: offer 14 new bettypes and Sporting Solution (36 new bettypes), column Betcount
		- 20140915@Florent: hotfix duplicated VS bettype
		- 20141017@Jim : Apply for the change in Sporting Solution structure (#24478)
		- 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
		- 20150123@Jim: support base on Currency GBP
		- 20150203@Jim: fix bug duplicate command when retrieve BA data from bettrans14
		- 20150415@Jim: change to use f_GroupBettype instead of LRF_view_bettype_SS
		- 20150622@Winnie: exclude 3 transactions SOLD/BOUGHT/BetTrade Commission 
		- 20160727@Jim:  LRF - Commercial terms changed for Bet Trade [Redmine: #61342]
		- 20170227@Harper: LRF - Get data by @AgentList instead of @UserID [RedmineID: #71679]
		- 20170327@Paul: Implement Cash Out [RedmineID :#71727]
		- 20170731@Harper: LRF - Integrate Bet Radar Virtual Sports [RedmineID: #78241]
		- 20180129@Harper: Remove LC from product list [RedmineID: #85965]
		- 20180808@Amanda: Remove Racing, Bingo [RedmineID: #99378]
		- 20181019@Amanda: Add new bet types for E-Sports 2.0 [RedmineID: #100721]
		- 20181210@Joseph: Integrate Happy 5 for NumberGame [RedmineID: #103698]
		- 20190620@Amanda: Add Base currency param [RedmineID: #112531]
		- 20190312@Amanda: Add new bet types Single Match Parlay (ID: 38) [RedmineID: #108298]
		- 20200508@Vickie: Add new bet types for E-Sports 2.0 [RedmineID: #132548]
		- 20200623@Kos: Integrate archive process for table VSRaceInfo [Redmine: #136285]
		- 20201001@Louis: Licensee Spread Setting [RedmineID: #142532]
		- 20210119@Hogan: Integrate Four Guardians [RedmineID: #148100]
		- 20210304@Hogan: Integrate Cricket AIO [RedmineID: #150386]
		- 20210720@Kos: Support bk range [RedmineID: #151151]
					- Remove input params @showSB, @showNG, @ShowVS, @showVS2, @ShowCS, @LeagueID
					- Add input param @ProductList VARCHAR(500), @BalanceUpDay SMALLDATETIME
					- Rename output column from MemberWinLost to WinLost
		- 20220914@Evan: Expand length of @BaseCurrency [Redmine #177481]
		- 20241701@Evan: Merge VS, VS2, VS3 as VS only [RedmineID: #199523]
		- 20240830@Lewis: BaseBallAIO - phase 2 [RedmineID: #209344]
		- 20241001@Kelvin: LAP - Integrate BetRadar Virtual Horses & Dogs Racing [RedmineID: #210808]
		- 20241024@Kelvin: LAP - Integrate Betby (VS6) [RedmineID: #212446]
		- 20250122@Kelvin: Drop BA functions [RedmineID: #216882]
		- 20250417@Kelvin: LAP - Support Commission for ASKMESLOT, Funky Games, HOTDOG [RedmineID: #221461]

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
	SELECT DISTINCT BetType, ProductPrefix, EventType
	FROM dbo.f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', @ProductList, @IsTest)
	WHERE EventType = @EventType
		AND BetType NOT IN (SELECT BetType FROM dbo.Lrf_f_SelExcludedBetType())

	DECLARE
		@MatchSportType	SMALLINT,
		@ParentId		INT

	DECLARE @Match TABLE (MatchId INT)

	IF EXISTS (SELECT TOP 1 1 FROM @BetType WHERE EventType = 1)
	BEGIN
		SELECT
			@MatchSportType = sporttype,
			@ParentId = ParentID
		FROM dbo.match WITH (NOLOCK)
		WHERE matchid = @MatchId AND eventdate > @MoveBetsDay

		IF @MatchSportType IS NULL
		BEGIN
			SELECT
				@MatchSportType = sporttype,
				@ParentId = ParentID
			FROM dbo.match14 WITH (NOLOCK)
			WHERE matchid = @MatchId
				AND eventdate BETWEEN @BalanceUpDay AND @MoveBetsDay
		END

		IF @MatchSportType IS NULL
		BEGIN
			SELECT
				@MatchSportType = sporttype,
				@ParentId = ParentID
			FROM DBARC.bodb_Archive.dbo.match_bk WITH (NOLOCK)
			WHERE matchid = @MatchId
		END
	END

	IF @MatchSportType IS NOT NULL
		BEGIN
			IF @MatchSportType IN (50, 8) AND @ParentId IS NULL	-- Cricket, parent match
			BEGIN
				INSERT INTO @Match
				SELECT
					@MatchId
				UNION
				SELECT DISTINCT
					MatchId
				FROM dbo.match WITH (NOLOCK)
				WHERE ParentID = @MatchId
					AND sporttype = @MatchSportType
					AND ChildMatchType = 200
				UNION
				SELECT DISTINCT
					MatchId
				FROM dbo.match14 WITH (NOLOCK)
				WHERE ParentID = @MatchId
					AND sporttype = @MatchSportType
					AND ChildMatchType = 200
				UNION
				SELECT DISTINCT
					MatchId
				FROM DBARC.bodb_Archive.dbo.match_bk WITH (NOLOCK)
				WHERE ParentID = @MatchId
					AND sporttype = @MatchSportType
					AND ChildMatchType = 200
			END
		END

	DECLARE @Data TABLE (
		MatchId				INT,
		MatchCode			NVARCHAR(50),
		HomeId				INT,
		AwayId				INT,
		VendorMatchId		VARCHAR(50),
		Distance            VARCHAR(50),
		IsNeutral			BIT,
		LeagueId			INT,
		SportType			SMALLINT,
		BetType				SMALLINT,
		EventType			TINYINT,
		LiveIndicator		BIT,
		Currency			INT,
		BetCount			INT,
		Turnover			MONEY,
		WinLost				MONEY,
		PlayerComm			MONEY,
		LicenseeWL			MONEY)

	DECLARE @_Date AS SMALLDATETIME

	SET @_Date = @Date

	-- bettrans
	IF @_Date > @MoveBetsDay
	BEGIN
		INSERT INTO @Data (
			MatchId,
			BetType,
			EventType,
			LiveIndicator,
			Currency,
			BetCount,
			Turnover,
			WinLost,
			PlayerComm,
			LicenseeWL)
		SELECT
			b.matchid,
			b.bettype,
			bt.EventType,
			CASE
				WHEN bt.ProductCode = 'NG' THEN b.liveindicator
				ELSE 0
			END AS LiveIndicator,
			b.currency,
			COUNT(1) AS BetCount,
			SUM(b.stake) AS Turnover,
			SUM(b.winlost - b.actual_stake) AS WinLost,
			SUM(b.playercomm) AS PlayerComm,
			-SUM(b.winlost - b.actual_stake) AS LicenseeWL
		FROM dbo.bettrans AS b WITH(NOLOCK)
			INNER JOIN @TempAg AS t ON t.CustId = b.recommend
			INNER JOIN @BetType AS bt ON bt.BetType = b.bettype
		WHERE b.winlostdate = @_Date
			AND b.statusID IN (111, 112, 113)
			AND (
					b.matchid = @MatchId
					OR b.matchid IN (SELECT MatchId FROM @Match)
				)
		GROUP BY
			b.matchid,
			b.bettype,
			bt.EventType,
			b.liveindicator,
			b.currency,
			bt.ProductCode

		IF EXISTS(SELECT TOP(1) 1 FROM @Data WHERE EventType = 1)
		BEGIN
			UPDATE b
			SET
				b.MatchId = CASE WHEN m.ChildMatchType = 200 THEN m.ParentId ELSE m.matchid END,
				b.MatchCode = m.matchcode,
				b.HomeId = m.homeid,
				b.AwayId = m.awayid,
				b.IsNeutral = ISNULL(m.IsNeutral, CONVERT(BIT, 0)),
				b.LeagueId = m.leagueid,
				b.SportType = m.sporttype,
				b.VendorMatchId = '',
				b.Distance = ''
			FROM @Data AS b
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON m.matchid = b.MatchId
			WHERE b.EventType = 1
		END

		IF EXISTS(SELECT TOP(1) 1 FROM @Data WHERE EventType = 3)
		BEGIN
			UPDATE b
			SET
				b.MatchCode = '',
				b.HomeId = 0,
				b.AwayId = 0,
				b.IsNeutral = 0,
				b.LeagueId = r.LeagueID,
				b.SportType = r.SportType,
				b.VendorMatchId = r.VendorMatchId,
				b.Distance = r.Distance
			FROM @Data AS b
				INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = b.MatchId
			WHERE b.EventType = 3
		END

		IF EXISTS(SELECT TOP(1) 1 FROM @Data WHERE EventType = 5)
		BEGIN
			UPDATE b
			SET
				b.MatchCode = m.matchcode,
				b.HomeId = m.HomeId,
				b.AwayId = m.AwayId,
				b.IsNeutral = 0,
				b.LeagueId = m.League3rdId,
				b.SportType = m.SportType,
				b.VendorMatchId = '',
				b.Distance = ''
			FROM @Data AS b
				INNER JOIN dbo.Match3rd AS m WITH (NOLOCK) ON m.Match3rdId = b.MatchId
			WHERE b.EventType = 5
		END
	END

	-- bettrans14 & bettrans_bk
	IF @_Date <= @MoveBetsDay
	BEGIN
		INSERT INTO @Data (
			MatchId,
			BetType,
			EventType,
			LiveIndicator,
			Currency,
			BetCount,
			Turnover,
			WinLost,
			PlayerComm,
			LicenseeWL)
		SELECT
			b.matchid,
			b.bettype,
			bt.EventType,
			CASE
				WHEN bt.ProductCode = 'NG' THEN b.LiveIndicator
				ELSE 0
			END AS LiveIndicator,
			b.currency,
			SUM(b.betcount) AS BetCount,
			SUM(b.stake) AS Turnover,
			SUM(b.winlost) AS WinLost,
			SUM(b.playercomm) AS PlayerComm,
			-SUM(b.winlost) AS LicenseeWL
		FROM bodb_LicenseeReport.dbo.rptWinlostbyLeague AS b WITH (NOLOCK)
			INNER JOIN @TempAg AS t ON t.CustId = b.recommend
			INNER JOIN @BetType AS bt ON bt.BetType = b.bettype
		WHERE b.winlostdate = @_Date
			AND b.statusID <> 101
			AND (
					b.matchid = @MatchId
					OR b.matchid IN (SELECT MatchId FROM @Match)
				)
		GROUP BY
			b.matchid,
			b.bettype,
			bt.EventType,
			b.LiveIndicator,
			b.currency,
			bt.ProductCode

		IF @_Date BETWEEN @BalanceUpDay AND @MoveBetsDay -- bettrans14
		BEGIN
			IF EXISTS(SELECT TOP(1) 1 FROM @Data WHERE EventType = 1)
			BEGIN
				UPDATE b
				SET
					b.MatchId = CASE WHEN m.ChildMatchType = 200 THEN m.ParentId ELSE m.matchid END,
					b.MatchCode = m.matchcode,
					b.HomeId = m.homeid,
					b.AwayId = m.awayid,
					b.IsNeutral = ISNULL(m.IsNeutral, CONVERT(BIT, 0)),
					b.LeagueId = m.leagueid,
					b.SportType = m.sporttype,
					b.VendorMatchId = '',
					b.Distance = ''
				FROM @Data AS b
					INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON m.matchid = b.MatchId
				WHERE b.EventType = 1
			END

			IF EXISTS(SELECT TOP(1) 1 FROM @Data WHERE EventType = 3)
			BEGIN
				UPDATE b
				SET
					b.MatchCode = '',
					b.HomeId = 0,
					b.AwayId = 0,
					b.IsNeutral = 0,
					b.LeagueId = r.LeagueID,
					b.SportType = r.SportType,
					b.VendorMatchId = r.VendorMatchId,
					b.Distance = r.Distance
				FROM @Data AS b
					INNER JOIN dbo.VSRaceInfo14 AS r WITH (NOLOCK) ON r.EventID = b.MatchId
				WHERE b.EventType = 3
			END

			IF EXISTS(SELECT TOP(1) 1 FROM @Data WHERE EventType = 5)
			BEGIN
				UPDATE b
				SET
					b.MatchCode = m.matchcode,
					b.HomeId = m.HomeId,
					b.AwayId = m.AwayId,
					b.IsNeutral = 0,
					b.LeagueId = m.League3rdId,
					b.SportType = m.SportType,
					b.VendorMatchId = '',
					b.Distance = ''
				FROM @Data AS b
					INNER JOIN dbo.Match3rd14 AS m WITH (NOLOCK) ON m.Match3rdId = b.MatchId
				WHERE b.EventType = 5
			END
		END
		ELSE	-- bettrans_bk
		BEGIN
			CREATE TABLE #TmpMatch (
				MatchId			INT,
				ParentId		INT,
				ChildMatchType	TINYINT,
				MatchCode		NVARCHAR(50),
				HomeId			INT,
				AwayId			INT,
				IsNeutral		BIT,
				LeagueId		INT,
				SportType		SMALLINT,
				EventType		TINYINT
			)

			CREATE CLUSTERED INDEX IX_MatchId ON #TmpMatch (MatchId);

			INSERT INTO #TmpMatch (MatchId, EventType)
			SELECT DISTINCT MatchId, EventType FROM @Data			
			WHERE EventType IN (1, 5)

			IF EXISTS(SELECT TOP(1) 1 FROM @Data WHERE EventType = 1)
			BEGIN
				UPDATE b
				SET
					b.ParentId = m.ParentId,
					b.ChildMatchType = m.ChildMatchType,
					b.MatchCode = m.matchcode,
					b.HomeId = m.homeid,
					b.AwayId = m.awayid,
					b.IsNeutral = ISNULL(m.IsNeutral, CONVERT(BIT, 0)),
					b.LeagueId = m.leagueid,
					b.SportType = m.sporttype
				FROM #TmpMatch AS b
					INNER JOIN DBARC.bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON m.matchid = b.MatchId
				WHERE b.EventType = 1

				UPDATE b
				SET
					b.MatchId = CASE WHEN m.ChildMatchType = 200 THEN m.ParentId ELSE m.matchid END,
					b.MatchCode = m.matchcode,
					b.HomeId = m.homeid,
					b.AwayId = m.awayid,
					b.IsNeutral = m.IsNeutral,
					b.LeagueId = m.leagueid,
					b.SportType = m.sporttype,
					b.VendorMatchId = '',
					b.Distance = ''
				FROM @Data AS b
					INNER JOIN #TmpMatch AS m ON m.matchid = b.MatchId AND m.EventType = b.EventType
				WHERE b.EventType = 1
			END

			IF EXISTS(SELECT TOP(1) 1 FROM @Data WHERE EventType = 3)
			BEGIN
				UPDATE b
				SET
					b.MatchCode = '',
					b.HomeId = 0,
					b.AwayId = 0,
					b.LeagueId = r.LeagueID,
					b.IsNeutral = 0,
					b.SportType = r.SportType,
					b.VendorMatchId = r.VendorMatchId,
					b.Distance = r.Distance
				FROM @Data AS b
					INNER JOIN DBARC.bodb_Archive.dbo.VSRaceInfo_bk AS r WITH (NOLOCK) ON r.EventID = b.MatchId
				WHERE b.EventType = 3
			END

			IF EXISTS(SELECT TOP(1) 1 FROM @Data WHERE EventType = 5)
			BEGIN
				UPDATE b
				SET
					b.MatchCode = m.matchcode,
					b.HomeId = m.HomeId,
					b.AwayId = m.AwayId,					
					b.LeagueId = m.League3rdId,
					b.SportType = m.SportType
				FROM #TmpMatch AS b
					INNER JOIN DBARC.bodb_Archive.dbo.Match3rd_bk AS m WITH (NOLOCK) ON m.Match3rdId = b.MatchId
				WHERE b.EventType = 5
				
				UPDATE b
				SET
					b.MatchCode = m.matchcode,
					b.HomeId = m.homeid,
					b.AwayId = m.awayid,
					b.IsNeutral = 0,
					b.LeagueId = m.leagueid,
					b.SportType = m.sporttype,
					b.VendorMatchId = '',
					b.Distance = ''
				FROM @Data AS b
					INNER JOIN #TmpMatch AS m ON m.matchid = b.MatchId AND b.EventType = m.EventType
				WHERE b.EventType = 5
			END

			DROP TABLE #TmpMatch
		END
	END

	DECLARE @ExchangeDaily TABLE (ExchangeId INT, Rate FLOAT)

	INSERT INTO @ExchangeDaily(ExchangeId, Rate)
	SELECT ExchangeID, Rate
	FROM dbo.Lrf_f_GetExchangeRate(@_Date, @_Date, @BaseCurrency, '')

	DECLARE @GroupBetType TABLE (BetType INT, GroupTypeId INT)

	INSERT INTO @GroupBetType
	SELECT
		bettype,
		GroupTypeId
	FROM dbo.Lrf_f_GroupBettype()

	SELECT
		b.MatchId,
		b.EventType,
		b.MatchCode,
		b.HomeId,
		b.AwayId,
		b.VendorMatchId,
		b.Distance,
		b.IsNeutral,
		b.LeagueId,
		b.SportType,
		CASE
			WHEN ISNULL(ss.bettype, 0) <> 0 THEN ss.GroupTypeId
			ELSE b.BetType
		END AS BetType,
		b.LiveIndicator,
		SUM(b.BetCount) AS BetCount,
		CAST(SUM(b.Turnover		* e.Rate) AS MONEY) AS Turnover,
		CAST(SUM(b.WinLost		* e.Rate) AS MONEY) AS WinLost,
		CAST(SUM(b.PlayerComm	* e.Rate) AS MONEY) AS PlayerComm,
		CAST(SUM(b.LicenseeWL	* e.Rate) AS MONEY) AS LicenseeWL
	FROM @Data AS b
		INNER JOIN @ExchangeDaily AS e ON e.ExchangeId = b.Currency
		LEFT JOIN @GroupBetType AS ss ON ss.bettype = b.BetType
	GROUP BY
		b.MatchId,
		b.EventType,
		b.MatchCode,
		b.HomeId,
		b.AwayId,
		b.VendorMatchId,
		b.Distance,
		b.IsNeutral,
		b.LeagueId,
		b.SportType,
		CASE
			WHEN ISNULL(ss.bettype, 0) <> 0 THEN ss.GroupTypeId
			ELSE b.BetType
		END,
		b.LiveIndicator
END
GO

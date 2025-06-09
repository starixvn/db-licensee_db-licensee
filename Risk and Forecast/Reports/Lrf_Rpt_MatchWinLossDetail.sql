/*<info serverAlias="DBEXT-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_MatchWinLossDetail]
	@AgentList		VARCHAR(MAX),
	@Date			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME,
	@ProductList	VARCHAR(500),
	@PageSize		INT				= 1000,
	@PageIndex		INT				= 1,
	@BaseCurrency	VARCHAR(12)		= ''
AS

/*
	Created: 20101201@Jacob
	DB: DBEXT.bodb02
	Original: Age_Rpt_MatchWinLossDetail_Ag

	Revisions:
		- 20101201@Jacob: Copy source code from Age_Rpt_MatchWinLossDetail_Ag
		- 20110303@Jacob: Allow to choose all type of licensee AND all currency + suppport based currency
		- 20110325@Henry: Enhance performance (by using Custid instead of AgentId)
		- 20110505@Henry: Support filter by Sportbook, RaceBook
		- 20110519@Henry: Support filter by NumberGame
		- 20110616@Henry: Suport filter BA tickets + add column commission
		- 20110707@Henry: show Comm, Amt Due to for each 3rd party product: BA, Racing
		- 20110729@Henry: offer 3 new bettypes for Number Game + Mix Parlay Combination
		- 20111208@Jim: change bettype condition
		- 20120214@Jim: Replace table ExchangeDaily by function Lrf_f_GetExchangeDaily
		- 20120730@Jim: add playercomm value
		- 20120815@Henry: add live casino
		- 20120904@Jim: add virtual sport
		- 20121004@Jim: replace @currencyname input param by @currencyID
		- 20121115@Henry: Only Sportsbook needs to exclude BA
		- 20121128@Henry: use new table LicenseeBATransaction_active to get bettrans BA tickets
		- 20130426@Scott: Add more parameter @ShowBG,@ShowCS
		- 20130618@Jim: Restrict permission of Licensee Users by currency
		- 20130809@Jim: offer Virtual Horse Racing
		- 20131203@Jim: offer Virtual Greyhound, Virtual Motor Racing
		- 20140212@Florent: fix group by, rownumber
		- 20140620@Florent: offer 14 new bettypes and Sporting Solution (36 new bettypes)
		- 20140915@Florent: hotfix duplicated VS bettype and re-move hard code for VHR
		- 20141017@Jim : Apply for the change in Sporting Solution structure (#24478)
		- 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
		- 20140128@Jim: base on GBP
		- 20150415@Jim: change to use f_GroupBettype instead of LRF_view_bettype_SS
		- 20150622@Winnie: exclude 3 transactions SOLD/BOUGHT/BetTrade Commission
		- 20160727@Jim:  LRF - Commercial terms changed for Bet Trade [Redmine: #61342]
		- 20170227@Harper: LRF - Get data by @AgentList instead of @UserID [RedmineID: #71679]
		- 20170327@Paul: Implement Cash Out [RedmineID :#71727]
		- 20170524@Harper: Make sure data correct between two stages of Balance up process [RedmineID: #77065]
		- 20170706@Harper: LRF - Integrate Bet Radar Virtual Sports [RedmineID: #78241]
		- 20180129@Harper: Remove LC from product list [RedmineID: #85965]
		- 20180808@Amanda: Remove Racing, Bingo [RedmineID: #99378]
		- 20181019@Amanda: Add new bet types for E-Sports 2.0 [RedmineID: #100721]
		- 20181210@Joseph: Integrate Happy 5 for NumberGame [RedmineID: #103698]
		- 20190620@Amanda: Add Base currency param [RedmineID: #112531]
		- 20190312@Amanda: Add new bet types Single Match Parlay (ID: 38) [RedmineID: #108298]
		- 20200508@Vickie: Add new bet types for E-Sports 2.0 [RedmineID: #132548]
		- 20200623@Kos: Integrate archive process for table VSRaceInfo [Redmine: #136285]
		- 20201001@Louis: Licensee Spread Setting [RedmineID: #142532]
		- 20201231@Louis: Integrate Happy 5 Linked Games [RedmineID: #147446]
		- 20210119@Hogan: Integrate Four Guardians [RedmineID: #148100]
		- 20210304@Hogan: Integrate Cricket AIO [RedmineID: #150386]
		- 20210720@Kos: Support bk range [RedmineID: #151151]
					- Remove input params @showSB, @showNG, @ShowVS, @showVS2, @ShowCS, @FromDate. @ToDate
					- Add input param @ProductList VARCHAR(500), @Date SMALLDATETIME, @BalanceUpDay SMALLDATETIME
					- Rename output column from MemberWinLost to WinLost, SumMemberWinLost to SumWinLost
					- Don't return column Race, showtime anymore
		- 20220914@Evan: Expand length of @BaseCurrency [Redmine #177481]
		- 20241701@Evan: Merge VS, VS2, VS3 as VS only [RedmineID: #199523]
		- 20242901@Evan: Integrate VS4 [RedmineID: #199347]
		- 20240830@Lewis: BaseBallAIO - phase 2 [RedmineID: #209344]
		- 20241001@Kelvin: LAP - Integrate BetRadar Virtual Horses & Dogs Racing [RedmineID: #210808]
		- 20241024@Kelvin: LAP - Integrate Betby (VS6) [RedmineID: #212446]
		- 20250122@Kelvin: Drop BA functions [RedmineID: #216882]
		- 20241107@Kelvin: Integrate VS5 [RedmineID: #207582]
		- 20250509@Kelvin: Enhancement to speed up integrate new casino product [RedmineID: #226292]

	Param's Explanation:
		+ @AgentList: XML structure
			<ROOT>
				<Agent AgentId="12345" Currency="3"/>
				<Agent AgentId="12345" Currency="5"/>
			</ROOT> 
*/

BEGIN
	SET NOCOUNT ON

	/* Get agent list */
	-----------------------------------------------------------------------------------------------------------------------------------
	DECLARE @TempAg AS TABLE (CustId INT, Currency INT)
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
	-----------------------------------------------------------------------------------------------------------------------------------

	/* Get Parlay BetType */
	-----------------------------------------------------------------------------------------------------------------------------------
	DECLARE @ParlayBetType TABLE (ProductCode VARCHAR (10), BetType INT)

	INSERT INTO @ParlayBetType (ProductCode, BetType)
	SELECT ProductCode, BetType FROM dbo.Lrf_f_SelParlayBetType()
	-----------------------------------------------------------------------------------------------------------------------------------

	/* Get BetType */
	-----------------------------------------------------------------------------------------------------------------------------------
	SELECT @ProductList = STRING_AGG(b.ProductPrefix, ',')
	FROM (
		SELECT DISTINCT ISNULL(b.ProductPrefix,a.Value) AS ProductPrefix
		FROM STRING_SPLIT(@ProductList, ',') a
			LEFT JOIN dbo.Lrf_f_GroupProduct() b ON a.Value = b.GroupProductPrefix
	) b
	
	DECLARE @BetType TABLE (BetType INT PRIMARY KEY, ProductCode VARCHAR(10), EventType TINYINT, IsParLay BIT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @BetType (BetType, ProductCode, EventType, IsParLay)
	SELECT DISTINCT f.BetType, ISNULL(lf.GroupProductPrefix, f.ProductPrefix), f.EventType
		, CASE WHEN pl.BetType IS NOT NULL THEN 1 ELSE 0 END AS IsParLay
	FROM dbo.f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', @ProductList, @IsTest) f
		LEFT JOIN dbo.Lrf_f_GroupProduct() lf ON f.ProductId = lf.ProductId
		LEFT JOIN @ParlayBetType pl ON f.Bettype = pl.BetType
	WHERE f.BetType NOT IN (SELECT BetType FROM dbo.Lrf_f_SelExcludedBetType())
	-----------------------------------------------------------------------------------------------------------------------------------

	DECLARE @Data TABLE (
		BetGroup		TINYINT,
		MatchId			INT,
		MatchCode		NVARCHAR(50),
		HomeId			INT,
		AwayId			INT,
		VendorMatchId	VARCHAR(50),
		Distance        VARCHAR(50),
		KickOffTime		DATETIME,
		IsNeutral		BIT,
		LeagueId		INT,
		EventType		TINYINT,
		SportType		SMALLINT,
		BetType			SMALLINT,
		ProductCode		VARCHAR(10),
		LiveIndicator	BIT,
		Currency		INT,
		BetCount		INT,
		Turnover		MONEY,
		WinLost			MONEY,
		PlayerComm		MONEY,
		LicenseeWL		MONEY
	)

	DECLARE @_Date AS SMALLDATETIME

	SET @_Date = @Date

	-- bettrans
	IF @_Date > @MoveBetsDay
	BEGIN
		INSERT INTO @Data (
			BetGroup,
			MatchId,
			MatchCode,
			HomeId,
			AwayId,
			KickOffTime,
			IsNeutral,
			LeagueId,
			EventType,
			SportType,
			BetType,
			ProductCode,
			LiveIndicator,
			Currency,
			BetCount,
			Turnover,
			WinLost,
			PlayerComm,
			LicenseeWL)
		SELECT
			CASE
				WHEN b.bettype = 10 THEN 2
				WHEN b.bettype = 29 THEN 4
				WHEN bt.IsParLay = 1 AND bt.ProductCode = 'VS' THEN 3
				WHEN bt.EventType = 0 THEN 5
				ELSE 0
			END AS BetGroup,
			CASE
				WHEN bt.EventType IN (1, 3, 5) THEN b.matchid
				ELSE 0
			END AS MatchId,
			CASE b.bettype
				WHEN 10 THEN 'ZZZZ'
				ELSE ''
			END AS MatchCode,
			0 AS HomeId,
			0 AS AwayId,
			NULL AS KickOffTime,
			CONVERT(BIT, 0) AS IsNeutral,
			0 AS LeagueId,
			bt.EventType,
			CASE
				WHEN b.bettype = 10 THEN 103
				WHEN b.bettype = 29 THEN 102
				WHEN bt.IsParLay = 1 AND bt.ProductCode = 'VS' THEN 104
				WHEN bt.EventType = 0 THEN b.matchid
				ELSE 0
			END AS SportType,
			b.bettype,
			bt.ProductCode,
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
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN @TempAg AS a ON a.CustId = b.recommend
			INNER JOIN @BetType AS bt ON bt.BetType = b.bettype
		WHERE b.winlostdate = @_Date
			AND b.statusID IN (111, 112, 113)
		GROUP BY
			bt.ProductCode,
			b.bettype,
			CASE
				WHEN b.bettype = 10 THEN 2
				WHEN b.bettype = 29 THEN 4
				WHEN bt.IsParLay = 1 AND bt.ProductCode = 'VS' THEN 3
				WHEN bt.EventType = 0 THEN 5
				ELSE 0
			END,
			CASE
				WHEN bt.EventType IN (1, 3, 5) THEN b.matchid
				ELSE 0
			END,
			bt.EventType,
			CASE
				WHEN b.bettype = 10 THEN 103
				WHEN b.bettype = 29 THEN 102
				WHEN bt.IsParLay = 1 AND bt.ProductCode = 'VS' THEN 104
				WHEN bt.EventType = 0 THEN b.matchid
				ELSE 0
			END,
			CASE
				WHEN bt.ProductCode = 'NG' THEN b.liveindicator
				ELSE 0
			END,
			b.currency

		IF EXISTS(SELECT TOP(1) 1 FROM @Data WHERE EventType = 1)
		BEGIN
			UPDATE b
			SET
				b.MatchId = CASE WHEN m.ChildMatchType = 200 THEN m.ParentID ELSE m.matchid END,
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
				b.KickOffTime = r.EventTime,
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
			BetGroup,
			MatchId,
			MatchCode,
			HomeId,
			AwayId,
			KickOffTime,
			IsNeutral,
			LeagueId,
			EventType,
			SportType,
			BetType,
			ProductCode,
			LiveIndicator,
			Currency,
			BetCount,
			Turnover,
			WinLost,
			PlayerComm,
			LicenseeWL
			)
		SELECT
			CASE 
				WHEN b.bettype = 10 THEN 2
				WHEN b.bettype = 29 THEN 4
				WHEN bt.IsParLay = 1 AND bt.ProductCode = 'VS' THEN 3
				ELSE 0
			END AS BetGroup,
			CASE
				WHEN bt.EventType IN (1, 3, 5) THEN b.matchid
				ELSE 0
			END AS MatchId,
			CASE b.bettype
				WHEN 10 THEN 'ZZZZ'
				ELSE ''
			END AS MatchCode,
			0 AS HomeId,
			0 AS AwayId,
			NULL AS KickOffTime,
			CONVERT(BIT, 0) AS IsNeutral,
			0 AS LeagueId,
			bt.EventType,
			CASE
				WHEN b.bettype = 10 THEN 103
				WHEN b.bettype = 29 THEN 102
				WHEN bt.IsParLay = 1 AND bt.ProductCode = 'VS' THEN 104
				WHEN bt.EventType = 0 THEN b.matchid
				ELSE 0
			END AS SportType,
			b.bettype,
			bt.ProductCode,
			CASE
				WHEN bt.ProductCode = 'NG' THEN b.liveindicator
				ELSE 0
			END AS LiveIndicator,
			b.currency,
			SUM(b.betcount) AS BetCount,
			SUM(b.stake) AS Turnover,
			SUM(b.winlost) AS WinLost,
			SUM(b.playercomm) AS PlayerComm,
			-SUM(b.winlost) AS LicenseeWL
		FROM bodb_LicenseeReport.dbo.rptWinlostbyLeague AS b WITH (NOLOCK)
			INNER JOIN @TempAg AS a ON a.CustId = b.recommend
			INNER JOIN @BetType AS bt ON bt.BetType = b.bettype
		WHERE b.winlostdate = @_Date
			AND b.statusID <> 101
		GROUP BY
			bt.ProductCode,
			b.bettype,
			CASE 
				WHEN b.bettype = 10 THEN 2
				WHEN b.bettype = 29 THEN 4
				WHEN bt.IsParLay = 1 AND bt.ProductCode = 'VS' THEN 3
				ELSE 0
			END,
			CASE
				WHEN bt.EventType IN (1, 3, 5) THEN b.matchid
				ELSE 0
			END,
			bt.EventType,
			CASE
				WHEN b.bettype = 10 THEN 103
				WHEN b.bettype = 29 THEN 102
				WHEN bt.IsParLay = 1 AND bt.ProductCode = 'VS' THEN 104
				WHEN bt.EventType = 0 THEN b.matchid
				ELSE 0
			END,
			CASE
				WHEN bt.ProductCode = 'NG' THEN b.liveindicator
				ELSE 0
			END,
			b.currency

		IF @_Date BETWEEN @BalanceUpDay AND @MoveBetsDay	-- bettrans14
		BEGIN
			IF EXISTS(SELECT TOP(1) 1 FROM @Data WHERE EventType = 1)
			BEGIN
				UPDATE b
				SET
					b.MatchId = CASE WHEN m.ChildMatchType = 200 THEN m.ParentID ELSE m.matchid END,
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
					b.KickOffTime = r.EventTime,
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
					INNER JOIN #TmpMatch AS m ON m.matchid = b.MatchId AND b.EventType = m.EventType
				WHERE b.EventType = 1
			END

			IF EXISTS(SELECT TOP(1) 1 FROM @Data WHERE EventType = 3)
			BEGIN
				UPDATE b
				SET
					b.MatchCode = '',
					b.HomeId = 0,
					b.AwayId = 0,
					b.KickOffTime = r.EventTime,
					b.IsNeutral = 0,
					b.LeagueId = r.LeagueID,
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

	DECLARE @ExchangeDaily TABLE (
		FromDate	SMALLDATETIME,
		ToDate		SMALLDATETIME,
		ExchangeId	INT,
		Rate		FLOAT)

	DECLARE
		@RowStart INT,
		@RowEnd INT,
		@TotalRows INT

	SELECT
		@PageIndex = @PageIndex - 1,
		@RowStart = @PageSize * @PageIndex + 1,
		@RowEnd = @RowStart + @PageSize - 1

	INSERT INTO @ExchangeDaily(FromDate, ToDate, ExchangeId, Rate)
	SELECT FromDate, ToDate, ExchangeId, Rate
	FROM dbo.Lrf_f_GetExchangeRate(@_Date, @_Date, @BaseCurrency, '')

	SELECT @TotalRows = COUNT(1)
	FROM ( SELECT DISTINCT
				BetGroup,
				MatchId,
				MatchCode,
				HomeId,
				AwayId,
				VendorMatchId,
				Distance,
				KickOffTime,
				IsNeutral,
				LeagueId,
				SportType,
				BetType,
				ProductCode,
				LiveIndicator,
				EventType
			FROM @Data
		) AS Temp

	DECLARE @GroupBetType TABLE (BetType INT, GroupTypeId INT)

	INSERT INTO @GroupBetType
	SELECT
		bettype,
		GroupTypeId
	FROM dbo.Lrf_f_GroupBettype()

	SELECT wl.*
	FROM ( SELECT
				b.BetGroup,
				b.MatchId,				
				ISNULL(b.MatchCode, '') AS MatchCode,
				b.HomeId,
				b.AwayId,
				b.VendorMatchId,
				b.Distance,
				ISNULL(b.KickOffTime, 0) AS KickOffTime,
				b.IsNeutral,
				b.LeagueId,
				b.SportType,
				CASE
					WHEN ISNULL(ss.bettype, 0) <> 0 THEN ss.GroupTypeId ELSE b.BetType
				END AS BetType,
				b.ProductCode,
				b.LiveIndicator,
				b.EventType,
				SUM(b.BetCount) AS BetCount,
				CAST(SUM(b.Turnover		* e.Rate) AS MONEY) AS Turnover,
				CAST(SUM(b.WinLost		* e.Rate) AS MONEY) AS WinLost,
				CAST(SUM(b.PlayerComm	* e.Rate) AS MONEY) AS PlayerComm,
				CAST(SUM(b.LicenseeWL	* e.Rate) AS MONEY) AS LicenseeWL,
				ROW_NUMBER() OVER (ORDER BY b.BetGroup, b.MatchId, b.LeagueId) AS RowNum
			FROM
				@Data AS b
				INNER JOIN @ExchangeDaily AS e ON e.ExchangeId = b.Currency
				LEFT JOIN @GroupBetType AS ss ON ss.bettype = b.BetType
			GROUP BY
				b.BetGroup,
				b.MatchId,				
				ISNULL(b.MatchCode, ''),
				b.HomeId,
				b.AwayId,
				b.VendorMatchId,
				b.Distance,
				ISNULL(b.KickOffTime, 0),
				b.IsNeutral,
				b.LeagueId,
				b.SportType,
				CASE
					WHEN ISNULL(ss.bettype, 0) <> 0 THEN ss.GroupTypeId ELSE b.BetType
				END,
				b.ProductCode,
				b.LiveIndicator,
				b.EventType
			) wl
	WHERE wl.RowNum BETWEEN @RowStart AND @RowEnd

	SELECT
		ISNULL(@TotalRows, 0)						AS TotalRows,
		SUM(b.BetCount)								AS SumBetCount,
		CAST(SUM(b.Turnover		* e.Rate) AS MONEY) AS SumTurnover,
		CAST(SUM(b.WinLost		* e.Rate) AS MONEY) AS SumWinLost,
		CAST(SUM(b.PlayerComm	* e.Rate) AS MONEY) AS SumPlayerComm,
		CAST(SUM(b.LicenseeWL	* e.Rate) AS MONEY) AS SumLicenseeWL
	FROM @Data AS b
		INNER JOIN @ExchangeDaily AS e ON e.ExchangeId = b.Currency
END
GO
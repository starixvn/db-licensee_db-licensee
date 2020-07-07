/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_MatchWinLossDetail]
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@showSB			BIT = 0,
	@showNG			BIT = 0,
	@showBA			BIT = 0,
	@ShowVS			BIT = 0,
	@ShowCS			BIT = 0,
	@ShowVS2		BIT = 0,
	@PageSize		INT = 1000,
	@PageIndex		INT = 1,
	@AgentList		VARCHAR(MAX),
	@BaseCurrency	VARCHAR(3) = ''
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

	Param's Explanation:
		+ @AgentList: xml structure
					<ROOT>
						<Agent AgentId="12345" Currency="3"/>
						<Agent AgentId="12345" Currency="5"/>
					</ROOT> 
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @ExchangeDaily TABLE(FromDate SMALLDATETIME, ToDate SMALLDATETIME, ExchangeId INT, Rate FLOAT)  

	DECLARE
		@RowStart INT,
		@RowEnd INT,
		@TotalRows INT,
		@Today SMALLDATETIME,
		@TempFromDate SMALLDATETIME,
		@TempToDate SMALLDATETIME

	DECLARE @_ToDate AS SMALLDATETIME,
		@_FromDate AS SMALLDATETIME

	SET @_ToDate = @todate
	SET @_FromDate = @fromdate

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	SELECT
		@PageIndex = @PageIndex - 1,
		@RowStart = @PageSize * @PageIndex + 1,
		@RowEnd = @RowStart + @PageSize - 1,
		@Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120)

	DECLARE @TempAg AS TABLE (CustId INT, Currency INT)
	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
				,@AgentList
		INSERT INTO @TempAg (custID, currency)
		SELECT AgentId, Currency
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
				,ErrMsg = N'Parameter invalid.'

		RETURN
	END CATCH;

	DECLARE @bettype TABLE (bettype INT PRIMARY KEY, ProductCode VARCHAR(10))
	DECLARE @ProductList VARCHAR (500)

	DECLARE @AgMatchWLDetails TABLE
	(
		Winlostdate SMALLDATETIME,
		KickoffTime DATETIME,
		Currency INT,
		BetGroup INT,
		matchid INT,
		homeid INT,
		awayid INT,
		bettype SMALLINT,
		sporttype SMALLINT,
		leagueid INT,
		turnover MONEY,
		MemberWinLost MONEY,
		LicenseeWL MONEY, --Sportbook and NumberGame  
		AmtDueToBA MONEY,
		CommBA   MONEY,
		PlayerComm  MONEY,
		race    NVARCHAR(20),
		matchcode   NVARCHAR(50),
		isNeutral   BIT,
		liveindicator  BIT,
		showtime  NVARCHAR(50),
		betcount INT
	)

	DECLARE @TempBetList AS TABLE (
		Winlostdate  DATETIME,
		currency   INT,
		Bettype   INT,
		Stake   MONEY,
		Winlost   MONEY,
		awinlost  MONEY,
		comm   MONEY,
		oddsid INT,
		playercomm  MONEY,
		MatchID   INT,
		Liveawayscore SMALLINT,
		liveindicator  BIT,
		tpositiontaking SMALLMONEY,
		Betcount INT
	)

	IF @ShowNG = 1
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'NG', 'NG')
	END

	IF @ShowVS = 1
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'VS', 'VS')
	END  

	IF @ShowVS2 = 1 -- Betradar Virtual Sports
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'VS2', 'VS2')
	END

	IF LEN(ISNULL(@ProductList, '')) > 0 
	BEGIN
		-- Insert Bettype
		INSERT INTO @bettype ( bettype, ProductCode )
		SELECT DISTINCT BetType, ProductPrefix
		FROM f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', @ProductList, @IsTest)
	END

	IF @_Todate > @MoveBetsDay
	BEGIN
		IF @_FromDate <= @MoveBetsDay
			SET @TempFromDate = DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @_FromDate

		IF @ShowBA = 1
		BEGIN
			INSERT INTO @TempBetList
			SELECT
				b.Winlostdate,
				b.currency,
				b.bettype,
				SUM(CASE WHEN b.bettype <> 29 THEN b.stake ELSE b.actual_stake END) AS Stake,
				SUM(b.winlost - b.actual_stake) AS Winlost,
				0 AS awinlost,
				SUM(b.comm),
				b.oddsid,
				SUM(playercomm) AS PlayerComm,
				b.matchid,
				0 AS Liveawayscore,
				0 AS liveindicator,
				0 AS tpositiontaking,
				COUNT(1) betcount
			FROM dbo.bettrans b WITH(NOLOCK)
				INNER JOIN @TempAg t ON b.recommend = t.CustId AND b.currency = t.Currency
				INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction_active BA WITH (NOLOCK) ON b.recommend = BA.recommend AND b.transid = BA.transid
			WHERE b.winlostdate BETWEEN @TempFromDate AND @_Todate
				AND b.statusID IN (111, 112, 113)
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
			GROUP BY
				b.Winlostdate,
				b.currency,
				b.oddsid,
				b.bettype,
				b.matchid

			-- SB
			INSERT INTO @AgMatchWLDetails
			SELECT
				b.Winlostdate,
				NULL,
				b.currency,
				0 AS BetGroup,
				m.matchid,
				m.homeid,
				m.awayid,
				b.bettype,
				CASE
					WHEN b.bettype = 9 THEN 101
					WHEN b.bettype = 29 THEN 102
					WHEN b.bettype = 10 THEN 103
					ELSE ISNULL(m.sporttype, 1)
				END sporttype,
				m.leagueid,
				SUM(b.Stake),
				SUM(b.Winlost),
				0 AS LicenseeWL,
				-SUM(b.Winlost + b.awinlost + b.comm) AS AmtDueToBA,
				SUM(b.comm) AS CommBA,
				SUM(b.playercomm) AS PlayerComm,
				'',
				m.matchcode,
				ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral,
				0 AS liveindicator,
				'' AS ShowTime,
				SUM(b.Betcount) betcount
			FROM @TempBetList b  
				INNER JOIN match m WITH ( NOLOCK ) ON m.matchid = b.matchid  
			WHERE b.bettype < 31
				OR (b.Bettype BETWEEN 121 AND 999) 
				OR (b.Bettype BETWEEN 1301 AND 1399) --new tennis's bettypes
				OR (b.Bettype BETWEEN 9001 AND 9399) -- E-Sports 2.0
				OR b.Bettype = 38					 -- Single Match Parlay
			GROUP BY
				b.Winlostdate,
				b.currency,
				m.matchid,
				m.homeid,
				m.awayid,
				b.bettype,
				CASE
					WHEN b.bettype = 9 THEN 101
					WHEN b.bettype = 29 THEN 102
					WHEN b.bettype = 10 THEN 103
					ELSE ISNULL(m.sporttype,1)
					END,
				m.leagueid,
				m.matchcode,
				m.isNeutral

			-- Combination Mix Parlay
			INSERT INTO @AgMatchWLDetails
			SELECT
				b.Winlostdate,
				NULL,
				b.currency,
				4 AS BetGroup,
				0 AS matchid,
				0 AS homeid,
				0 AS awayid,
				29 AS bettype,
				102 AS sporttype,
				0 AS leagueid,
				SUM(stake),
				SUM(Winlost),
				0 AS LicenseeWL,
				-SUM (Winlost +  awinlost + comm) AS AmtDueToBA,
				SUM (comm ) AS CommBA,
				SUM(playercomm)AS PlayerComm,
				'' AS race,
				'' AS matchcode,
				CONVERT(BIT, 0) AS IsNeutral,
				0 AS liveindicator,
				'' AS showtime,
				SUM(b.Betcount) betcount
			FROM @TempBetList b
			WHERE b.bettype = 29
			GROUP BY
				b.Winlostdate,
				b.currency

			--Outright  
			INSERT INTO @AgMatchWLDetails  
			SELECT
				b.Winlostdate,
				NULL,	
				b.currency,  
				2 AS BetGroup,  
				0 AS matchid,  
				0 AS homeid,  
				0 AS awayid,  
				bettype,  
				103 As sporttype,
				0 AS leagueid,  
				SUM(stake),  
				SUM(Winlost),  
				0 AS LicenseeWL,  
				-SUM (Winlost +  awinlost + comm) AS AmtDueToBA,  
				SUM (comm ) AS CommBA,  
				SUM(b.playercomm) AS PlayerComm,  
				m.groupmatch AS race,  
				'ZZZZ' AS matchcode,  
				CONVERT(BIT, 0) AS IsNeutral,  
				0 AS liveindicator,  
				'' AS showtime,
				SUM(b.Betcount) betcount
			FROM @TempBetList b  
				INNER JOIN dbo.outright m WITH ( NOLOCK ) ON m.orid = b.matchid
			WHERE b.bettype = 10  
			GROUP BY
				b.Winlostdate,
				b.currency,
				b.Bettype,
				m.groupmatch
		END

		--Get general data  
		DELETE FROM @TempBetList  

		INSERT INTO @TempBetList  
		SELECT
			b.Winlostdate,  
			b.currency,  
			b.bettype,  
			SUM(CASE WHEN b.bettype <> 29 THEN stake ELSE actual_stake END) AS Stake,  
			SUM(winlost - actual_stake) AS Winlost,  
			SUM(b.awinlost) AS awinlost,  
			SUM(b.comm) AS comm,
			b.oddsid, 	
			SUM(b.playercomm) AS playercomm,  
			b.matchid,  
			b.Liveawayscore,  
			CASE WHEN (b.bettype BETWEEN 81 AND 120) OR (b.bettype BETWEEN 8101 AND 8120) THEN b.liveindicator ELSE 0 END AS liveindicator,  
			b.tpositiontaking,
			COUNT(1) betcount
		FROM bettrans b WITH(NOLOCK)
			INNER JOIN @TempAg t ON b.recommend = t.CustId AND b.currency = t.Currency
		WHERE b.winlostdate between @TempFromDate AND @_Todate  
			AND b.statusID IN (111,112,113)  
			AND (b.bettype < 901 OR b.bettype > 904)
			AND (b.bettype < 911 OR b.bettype > 914)
			AND b.matchid > 0  
		GROUP BY
			b.Winlostdate,  
			b.currency,
			b.oddsid,	
			b.bettype,  
			b.matchid,  
			b.Liveawayscore,  
			CASE WHEN (b.bettype BETWEEN 81 AND 120) OR (b.bettype BETWEEN 8101 AND 8120) THEN b.liveindicator ELSE 0 END,  
			b.tpositiontaking  

		IF @ShowSB = 1
		BEGIN  
			--exclude BA tickets  
			INSERT INTO @AgMatchWLDetails  
			SELECT
				b.Winlostdate,
				NULL,	
				b.currency,  
				0 AS BetGroup,  
				m.matchid,  
				m.homeid,  
				m.awayid,  
				b.bettype,  
				CASE WHEN b.bettype = 9 THEN 101
					WHEN b.bettype = 29 THEN 102
					WHEN b.bettype = 10 THEN 103
					ELSE ISNULL(m.sporttype,1)
					END sporttype,
				m.leagueid,  
				SUM(stake),  
				SUM(winlost),  
				-SUM(b.winlost) AS LicenseeWL,  
				0 AS AmountDueToBA,  
				0 AS CommBA,  
				SUM(b.playercomm) AS PlayerComm,  
				'',  
				m.matchcode,  
				ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral,  
				b.liveindicator AS liveindicator,  
				'' AS ShowTime,
				SUM(b.Betcount) betcount
			FROM @TempBetList b  
				INNER JOIN match m WITH ( NOLOCK ) ON m.matchid = b.matchid  
			WHERE (b.bettype < 31 
					OR (b.bettype BETWEEN 121 AND 999)
					OR (b.Bettype BETWEEN 1301 AND 1399) --new tennis's bettypes
					OR (b.Bettype BETWEEN 9001 AND 9399) -- E-Sports 2.0
					OR b.Bettype = 38					 -- Single Match Parlay
				) AND  
				b.tpositiontaking <> 0  
			GROUP BY
				b.Winlostdate,  
				b.currency,  
				m.matchid,  
				m.homeid,  
				m.awayid,  
				b.bettype, 
				CASE WHEN b.bettype = 9 THEN 101
					WHEN b.bettype = 29 THEN 102
					WHEN b.bettype = 10 THEN 103
					ELSE ISNULL(m.sporttype,1)
					END,	
				m.leagueid,  
				m.matchcode,  
				m.isNeutral,  
				b.liveindicator   

			-- Outright   
			INSERT INTO @AgMatchWLDetails  
			SELECT
				b.Winlostdate,
				NULL,	
				b.currency,  
				2 AS BetGroup,  
				0 AS matchid,  
				0 AS homeid,  
				0 AS awayid,  
				10 AS bettype, 
				103 AS sporttype,	
				0 AS leagueid,  
				SUM(b.stake),  
				SUM(b.winlost),  
				- SUM(b.winlost) AS LicenseeWL,  
				0 AS AmountDueToBA,  
				0 AS CommBA,  
				SUM (b.playercomm) AS PlayerComm,  
				m.groupmatch AS race,  
				'ZZZZ' AS matchcode,  
				CONVERT(BIT, 0) AS IsNeutral,  
				0 AS liveindicator,  
				'' AS showtime,
				SUM(b.Betcount) betcount  
			FROM @TempBetList b  
				INNER JOIN dbo.outright m WITH ( NOLOCK ) ON m.orid = b.matchid  
			WHERE b.bettype = 10 AND b.tpositiontaking <> 0  
			GROUP BY b.Winlostdate,b.currency,m.groupmatch    

			--Combination MixParlay  
			INSERT INTO @AgMatchWLDetails  
			SELECT
				b.Winlostdate,
				NULL,	
				b.currency,  
				4 AS BetGroup,  
				0 AS matchid,  
				0 AS homeid,  
				0 AS awayid,  
				29 AS bettype, 
				102 AS sporttype,	
				0 AS leagueid,  
				SUM(stake),  
				SUM(winlost),  
				-SUM(b.winlost) AS LicenseeWL,  
				0 AS AmountDueToBA,  
				0 AS CommBA,  
				SUM(b.playercomm)  AS PlayerComm,  
				'' AS race,  
				'' AS matchcode,  
				CONVERT(BIT, 0) AS IsNeutral,  
				0 AS liveindicator,  
				'' AS showtime,
				SUM(b.Betcount) betcount
			FROM @TempBetList b  
			WHERE b.bettype = 29  
				AND b.tpositiontaking <> 0  
			GROUP BY b.Winlostdate,  
				b.currency  
		END

		IF (@showNG = 1 OR @ShowVS = 1 OR @ShowVS2 = 1)   
		BEGIN
			--exclude BA tickets  
			INSERT INTO @AgMatchWLDetails  
			SELECT
				b.Winlostdate,
				NULL,	
				b.currency,  
				0 AS BetGroup,  
				m.matchid,  
				m.homeid,  
				m.awayid,  
				b.bettype,
				CASE WHEN b.bettype = 9 THEN 101
					WHEN b.bettype = 29 THEN 102
					WHEN b.bettype = 10 THEN 103
					WHEN b.Bettype = 2799 THEN 104
					ELSE ISNULL(m.sporttype,1)
					END sporttype,
				m.leagueid,  
				SUM(stake),  
				SUM(winlost),  
				-SUM(b.winlost) AS LicenseeWL,  
				0 AS AmountDueToBA,  
				0 AS CommBA,  
				SUM(b.playercomm) AS PlayerComm,  
				'',  
				m.matchcode,  
				ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral,  
				b.liveindicator AS liveindicator,  
				'' AS ShowTime,
				SUM(b.Betcount) betcount  
			FROM @TempBetList b  
				INNER JOIN dbo.match m WITH ( NOLOCK ) ON m.matchid = b.matchid  
				INNER JOIN @bettype bt ON b.bettype = bt.bettype 
			WHERE b.bettype NOT IN (SELECT bettype FROM dbo.f_VSHorseRacingByBettype())
			GROUP BY
				b.Winlostdate,  
				b.currency,  
				m.matchid,  
				m.homeid,  
				m.awayid,  
				b.bettype,  
				CASE WHEN b.bettype = 9 THEN 101
					WHEN b.bettype = 29 THEN 102
					WHEN b.bettype = 10 THEN 103
					WHEN b.Bettype = 2799 THEN 104
					ELSE ISNULL(m.sporttype,1)
					END,
				m.leagueid,  
				m.matchcode,  
				m.isNeutral,  
				b.liveindicator

			IF EXISTS (SELECT 1 FROM @TempBetList WHERE bettype IN (SELECT bettype FROM dbo.f_VSHorseRacingByBettype()) )
			BEGIN 
				INSERT INTO @AgMatchWLDetails
				SELECT
					b.Winlostdate,
					r.EventTime KickoffTime,
					b.currency,
					0 AS BetGroup,
					o.EventID matchid,
					o.RacerID AS homeID,
					0 AS awayid,
					b.bettype,
					r.sporttype,
					r.leagueid,  
					SUM(b.stake),  
					SUM(b.winlost),  
					-SUM(b.winlost) AS LicenseeWL,  
					0 AS AmountDueToBA,  
					0 AS CommBA,  
					SUM(b.playercomm)  AS PlayerComm,  
					b.oddsid,  
					CONVERT (VARCHAR(50),o.RacerNum) AS matchcode,  
					ISNULL(0, CONVERT(BIT, 0)) AS IsNeutral,  
					b.liveindicator AS liveindicator,
					CONVERT(VARCHAR(20),r.EventTime) AS ShowTime,
					SUM(b.Betcount) betcount
				FROM @TempBetList b  
					INNER JOIN dbo.VSOutright o WITH (NOLOCK) ON b.oddsid=o.Orid
					INNER JOIN dbo.VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
					INNER JOIN @bettype bt ON b.bettype = bt.bettype  
				WHERE b.bettype IN (SELECT bettype FROM dbo.f_VSHorseRacingByBettype())
				GROUP BY
					b.Winlostdate,  
					b.currency, 
					b.oddsid,
					o.EventID,  
					o.RacerID,  
					b.bettype,
					r.sporttype,	
					r.leagueid,  
					o.RacerNum,  
					b.liveindicator,
					r.EventTime
			END

			IF @ShowVS2 = 1
			BEGIN
				-- Mix Parlay BetRadar VS
				INSERT INTO @AgMatchWLDetails  
				SELECT
					b.Winlostdate,
					NULL,	
					b.currency,  
					3 AS BetGroup,  
					0 AS matchid,  
					0 AS homeid,  
					0 AS awayid,  
					2799 AS bettype, 
					104 AS sporttype,		
					0 AS leagueid,  
					SUM(stake),  
					SUM(winlost),  
					-SUM(b.winlost) AS LicenseeWL,  
					0 AS AmountDueToBA,  
					0 AS CommBA,  
					SUM(b.playercomm)  AS PlayerComm,  
					'' AS race,  
					'' AS matchcode,  
					CONVERT(BIT, 0) AS IsNeutral,  
					0 AS liveindicator,  
					'' AS showtime,
					SUM(b.Betcount) betcount
				FROM @TempBetList b  
				WHERE b.bettype = 2799
					AND b.tpositiontaking <> 0  
				GROUP BY b.Winlostdate,  
						b.currency 
			END
		END
	END

	IF @_Fromdate <= @MoveBetsDay   
	BEGIN  
		IF @_ToDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @_ToDate

		IF @ShowBA = 1  
		BEGIN  
			DELETE FROM @TempBetList  

			INSERT INTO @TempBetList   
			SELECT
				b.Winlostdate,
				b.currency,  
				b.bettype,  
				SUM(stake) AS Stake,  
				SUM(winlost - actual_stake) AS Winlost,  
				0 AS awinlost,  
				SUM(comm),
				b.oddsid,
				SUM(b.playercomm ) AS PlayerComm,  
				b.matchid,  
				0 AS Liveawayscore,  
				0 AS liveindicator,  
				0 AS tpositiontaking,
				COUNT(1) betcount 
			FROM dbo.bettrans14 b WITH(NOLOCK)  
				INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction_bk BA WITH (NOLOCK) ON b.recommend = BA.recommend AND b.transid = BA.transid    
				INNER JOIN @TempAg t ON b.recommend = t.CustId AND t.Currency = t.Currency  
			WHERE b.winlostdate between @_Fromdate AND @TempToDate  
				AND b.statusID IN (111,112,113)  
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
			GROUP BY
				b.Winlostdate,  
				b.currency,  
				b.oddsid,
				b.bettype,  
				b.matchid  

			--SB  
			INSERT INTO @AgMatchWLDetails  
			SELECT
				b.Winlostdate,
				NULL,
				b.currency,  
				0 AS BetGroup,  
				m.matchid,  
				m.homeid,  
				m.awayid,  
				b.bettype, 
				CASE WHEN b.bettype = 9 THEN 101
					WHEN b.bettype = 29 THEN 102
					WHEN b.bettype = 10 THEN 103
					ELSE ISNULL(m.sporttype,1)
					END sporttype,
				m.leagueid,  
				SUM(stake),  
				SUM(Winlost),  
				0 AS LicenseeWL,  
				-SUM (Winlost +  awinlost + comm) AS AmtDueToBA,  
				SUM (comm) AS CommBA,  
				SUM(b.playercomm) AS PlayerComm,  
				'' AS race,  
				m.matchcode,  
				ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral,  
				0 AS liveindicator,  
				'' AS showtime,
				SUM(b.Betcount) betcount 
			FROM @TempBetList b  
				INNER JOIN dbo.match14 m WITH ( NOLOCK ) ON m.matchid = b.matchid  
			WHERE b.bettype < 31
				OR (b.Bettype BETWEEN 121 AND 999)  
				OR (b.Bettype BETWEEN 1301 AND 1399) --new tennis's bettypes
				OR (b.Bettype BETWEEN 9001 AND 9399) -- E-Sports 2.0
				OR b.Bettype = 38					 -- Single Match Parlay
			GROUP BY
				b.Winlostdate,  
				b.currency,   
				m.matchid,  
				m.homeid,  
				m.awayid,  
				b.bettype,
				CASE WHEN b.bettype = 9 THEN 101
					WHEN b.bettype = 29 THEN 102
					WHEN b.bettype = 10 THEN 103
					ELSE ISNULL(m.sporttype,1)
					END,
				m.leagueid,
				m.matchcode,
				m.isNeutral  

			--Mix Parlay Combination  
			INSERT INTO @AgMatchWLDetails  
			SELECT
				b.Winlostdate,
				NULL,	
				b.currency,  
				4 AS BetGroup,  
				0 AS matchid,  
				0 AS homeid,  
				0 AS awayid,  
				29 AS bettype,
				102 AS sporttype,  
				0 AS leagueid,  
				SUM(stake),  
				SUM(Winlost),  
				0 AS LicenseeWL,  
				-SUM (Winlost +  awinlost + comm) AS AmtDueToBA,  
				SUM (comm) AS CommBA,  
				SUM(b.playercomm) AS PlayerComm,  
				'' AS race,  
				'' AS matchcode,  
				CONVERT(BIT, 0) AS IsNeutral,  
				0 AS liveindicator,  
				'' AS showtime,
				SUM(b.betcount) betcount
			FROM @TempBetList b   
			WHERE b.bettype = 29  
			GROUP BY b.Winlostdate,  
					b.currency   

			--outright  
			INSERT INTO @AgMatchWLDetails  
			SELECT
				b.Winlostdate,
				NULL,
				b.currency,  
				2  AS BetGroup,  
				0 AS matchid,  
				0 AS homeid,  
				0 AS awayid,  
				bettype, 
				103 AS bettype, 
				0 AS leagueid,  
				SUM(stake),  
				SUM(Winlost),  
				0 AS LicenseeWL,  
				-SUM (Winlost +  awinlost + comm) AS AmtDueToBA,  
				SUM (comm ) AS CommBA,  
				SUM(b.PlayerComm) AS PlayerComm,  
				m.groupmatch AS race,  
				'ZZZZ' AS matchcode,  
				CONVERT(BIT, 0) AS IsNeutral,  
				0 AS liveindicator,  
				'' AS showtime,
				SUM(b.betcount) betcount  
			FROM @TempBetList b  
				INNER JOIN dbo.outright14 m WITH ( NOLOCK ) ON m.orid = b.matchid  
			WHERE b.bettype = 10  
			GROUP BY b.Winlostdate,  
					b.currency,  
					bettype,  
					m.groupmatch  
		END  
  
		--Get general data  
		DELETE FROM @TempBetList  

		INSERT INTO @TempBetList  
		SELECT
			b.Winlostdate,  
			b.currency,  
			b.bettype,  
			SUM(stake) AS Stake,  
			SUM(winlost - actual_stake) AS Winlost,  
			SUM(b.awinlost) AS awinlost,  
			SUM(b.comm) AS comm,
			b.oddsid,
			SUM( b.playercomm ) AS playercomm,  
			b.matchid,  
			b.Liveawayscore,  
			CASE WHEN (b.bettype BETWEEN 81 AND 120) OR (b.bettype BETWEEN 8101 AND 8120) THEN b.liveindicator ELSE 0 END AS liveindicator,  
			b.tpositiontaking,
			COUNT(1) betcount  
		FROM dbo.bettrans14 b WITH(NOLOCK)
			INNER JOIN @TempAg t ON b.recommend = t.CustId AND b.currency = t.Currency
		WHERE b.winlostdate between @_Fromdate AND @TempToDate  
			AND b.ruben = 1  
			AND b.statusID NOT IN ( 101, 102, 103 )  
			AND (b.bettype < 901 OR b.bettype > 904)
			AND (b.bettype < 911 OR b.bettype > 914)
		GROUP BY
			b.Winlostdate,  
			b.currency,
			b.oddsid,	
			b.bettype,  
			b.matchid,  
			b.Liveawayscore,  
			CASE WHEN (b.bettype BETWEEN 81 AND 120) OR (b.bettype BETWEEN 8101 AND 8120) THEN b.liveindicator ELSE 0 END,  
			b.tpositiontaking  
  
		IF (@ShowSB=1)  
		BEGIN  
			INSERT INTO @AgMatchWLDetails  
			SELECT
				b.Winlostdate,
				NULL,
				b.currency,  
				0 AS BetGroup,  
				m.matchid,  
				m.homeid,  
				m.awayid,  
				b.bettype, 
				CASE WHEN b.bettype = 9 THEN 101
					WHEN b.bettype = 29 THEN 102
					WHEN b.bettype = 10 THEN 103
					ELSE ISNULL(m.sporttype,1)
					END sporttype,   
				m.leagueid,  
				SUM(stake),  
				SUM(winlost),  
				-SUM(b.winlost) AS LicenseeWL,  
				0 AS AmountDueToBA,  
				0 AS CommBA,  
				SUM(b.playercomm) AS PlayerComm,  
				'' AS race,  
				m.matchcode,  
				ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral,  
				b.liveindicator AS liveindicator,  
				'' AS ShowTime,
				SUM(b.betcount) betcount  
			FROM @TempBetList b  
				INNER JOIN dbo.match14 m WITH ( NOLOCK ) ON m.matchid = b.matchid  
			WHERE (b.bettype < 31 
					OR (b.bettype BETWEEN 121 AND 999)
					OR (b.Bettype BETWEEN 1301 AND 1399) --new tennis's bettypes
					OR (b.Bettype BETWEEN 9001 AND 9399) -- E-Sports 2.0
					OR b.Bettype = 38					 -- Single Match Parlay
				) AND  
				b.tpositiontaking<>0   
			GROUP BY
				b.Winlostdate,  
				b.currency,   
				m.matchid,  
				m.homeid,  
				m.awayid,  
				b.bettype,
				CASE WHEN b.bettype = 9 THEN 101
					WHEN b.bettype = 29 THEN 102
					WHEN b.bettype = 10 THEN 103
					ELSE ISNULL(m.sporttype,1)
					END,	
				m.leagueid,  
				m.matchcode,  
				m.isNeutral,  
				b.liveindicator

			-- Combination Mix parlay (14)   
			INSERT INTO @AgMatchWLDetails  
			SELECT
				b.Winlostdate,
				NULL,
				b.currency,  
				4 AS BetGroup,  
				0 AS matchid,  
				0 AS homeid,  
				0 AS awayid,  
				29 AS bettype,
				102 AS sporttype,
				0 AS leagueid,  
				SUM(stake) AS stake,  
				SUM(b.winlost),  
				-SUM(b.winlost) AS LicenseeWL,  
				0 AS AmountDueToBA,  
				0 AS CommBA,  
				SUM(b.playercomm) AS PlayerComm,  
				'' AS race,  
				'' AS matchcode,  
				CONVERT(BIT, 0) AS IsNeutral,  
				0 AS liveindicator,  
				'' AS showtime,
				SUM(b.betcount) betcount   
			FROM @TempBetList b  
			WHERE b.bettype = 29  
				AND b.tpositiontaking<>0  
			GROUP BY b.Winlostdate,  
					b.currency   

			-- Outright (14) + HR  
			INSERT INTO @AgMatchWLDetails  
			SELECT
				b.Winlostdate,
				NULL,	
				b.currency,  
				2 AS BetGroup,  
				0 AS matchid,  
				0 AS homeid,  
				0 AS awayid,  
				10 AS bettype, 
				103 AS sporttype, 
				0 AS leagueid,  
				SUM(b.stake),  
				SUM(winlost),  
				- SUM(b.winlost) AS LicenseeWL,  
				0 AS AmountDueToBA,  
				0 AS CommBA,  
				SUM (  b.playercomm ) AS PlayerComm,  
				m.groupmatch AS race,  
				'ZZZZ' AS matchcode,  
				CONVERT(BIT, 0) AS IsNeutral,  
				0 AS liveindicator,  
				'' AS showtime,
				SUM(b.betcount) betcount    
			FROM @TempBetList b  
				INNER JOIN dbo.outright14 m WITH ( NOLOCK ) ON m.orid = b.matchid  
			WHERE b.bettype = 10 AND b.tpositiontaking<>0  
			GROUP BY b.Winlostdate,  
					b.currency,  
					m.groupmatch   
		END

		IF (@showNG = 1 OR @ShowVS = 1 OR @ShowVS2 = 1)   
		BEGIN  
			INSERT INTO @AgMatchWLDetails  
			SELECT  b.Winlostdate,
				NULL,	
				b.currency,  
				0 AS BetGroup,  
				m.matchid,  
				m.homeid,  
				m.awayid,  
				b.bettype,  
				CASE WHEN b.bettype = 9 THEN 101
					WHEN b.bettype = 29 THEN 102
					WHEN b.bettype = 10 THEN 103
					WHEN b.Bettype = 2799 THEN 104
					ELSE ISNULL(m.sporttype,1)
					END sporttype,	
				m.leagueid,  
				SUM(stake),  
				SUM(winlost),  
				-SUM(b.winlost) AS LicenseeWL,  
				0 AS AmountDueToBA,  
				0 AS CommBA,  
				SUM(b.playercomm) AS PlayerComm,  
				'' AS race,  
				m.matchcode,  
				ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral,  
				b.liveindicator AS liveindicator,  
				'' AS ShowTime,
				SUM(b.betcount) betcount    
			FROM @TempBetList b  
				INNER JOIN dbo.match14 m WITH ( NOLOCK ) ON m.matchid = b.matchid  
				INNER JOIN @bettype bt ON b.bettype = bt.bettype  
			WHERE b.bettype NOT IN (SELECT bettype FROM dbo.f_VSHorseRacingByBettype())
			GROUP BY
				b.Winlostdate,  
				b.currency,   
				m.matchid,  
				m.homeid,  
				m.awayid,  
				b.bettype,
				CASE WHEN b.bettype = 9 THEN 101
					WHEN b.bettype = 29 THEN 102
					WHEN b.bettype = 10 THEN 103
					WHEN b.Bettype = 2799 THEN 104
					ELSE ISNULL(m.sporttype,1)
					END,		
				m.leagueid,  
				m.matchcode,  
				m.isNeutral,  
				b.liveindicator

			IF EXISTS (SELECT 1 FROM  @TempBetList  WHERE bettype IN (SELECT bettype FROM dbo.f_VSHorseRacingByBettype()))
			BEGIN 
				INSERT INTO @AgMatchWLDetails  
				SELECT
					b.Winlostdate,
					r.EventTime KickoffTime,	
					b.currency,
					0 AS BetGroup, 	
					o.EventID matchid,  
					o.RacerID AS homeID,  
					0 AS awayid,  
					b.bettype,
					r.sporttype,	
					r.leagueid,  
					SUM(b.stake),  
					SUM(b.winlost),  
					-SUM(b.winlost) AS LicenseeWL,  
					0 AS AmountDueToBA,  
					0 AS CommBA,  
					SUM(b.playercomm)  AS PlayerComm,  
					b.oddsid,  
					CONVERT(VARCHAR(50),o.RacerNum) AS matchcode,  
					ISNULL(0, CONVERT(BIT, 0)) AS IsNeutral,  
					b.liveindicator AS liveindicator,
					CONVERT(VARCHAR(20),r.EventTime) AS ShowTime,
					SUM(b.betcount) betcount    
				FROM @TempBetList b  
					INNER JOIN dbo.VSOutright14 o WITH (NOLOCK) ON b.oddsid=o.Orid
					INNER JOIN dbo.VSRaceInfo14 r WITH (NOLOCK) ON r.EventID = o.EventID
					INNER JOIN @bettype bt ON b.bettype = bt.bettype  
				WHERE b.bettype IN (SELECT bettype FROM dbo.f_VSHorseRacingByBettype())
				GROUP BY
					b.Winlostdate,  
					b.currency,
					b.oddsid,		
					o.EventID,  
					o.RacerID,  
					b.bettype,
					r.sporttype,	
					r.leagueid,  
					o.RacerNum,  
					b.liveindicator,
					r.EventTime
			END

			IF @ShowVS2 = 1
			BEGIN
				-- Mix Parlay BetRadar VS
				INSERT INTO @AgMatchWLDetails  
				SELECT
					b.Winlostdate,
					NULL,
					b.currency,  
					3 AS BetGroup,  
					0 AS matchid,  
					0 AS homeid,  
					0 AS awayid,  
					2799 AS bettype,
					104 AS sporttype,
					0 AS leagueid,  
					SUM(stake) AS stake,  
					SUM(b.winlost),  
					-SUM(b.winlost) AS LicenseeWL,  
					0 AS AmountDueToBA,  
					0 AS CommBA,  
					SUM(b.playercomm)  AS PlayerComm,  
					'' AS race,  
					'' AS matchcode,  
					CONVERT(BIT, 0) AS IsNeutral,  
					0 AS liveindicator,  
					'' AS showtime,
					SUM(b.betcount) betcount  
				FROM @TempBetList b  
				WHERE b.bettype = 2799  
					AND b.tpositiontaking<>0  
				GROUP BY b.Winlostdate,  
						b.currency
			END
		END
	END

	INSERT INTO @ExchangeDaily(FromDate, ToDate, ExchangeId, Rate)
	SELECT FromDate, ToDate, ExchangeId, Rate
	FROM dbo.Lrf_f_GetExchangeRate(@_FromDate,@_ToDate, @BaseCurrency, '')

	SELECT @TotalRows = COUNT(1)  
	FROM ( SELECT DISTINCT  
				BetGroup,  
				matchid,  
				homeid,  
				awayid,  
				bettype,
				sporttype,	
				matchcode,  
				leagueid,  
				isNeutral,  
				race,  
				liveindicator  
			FROM @AgMatchWLDetails
		) AS Temp  

	SELECT  wl.*  
	FROM ( SELECT      
				BetGroup,  
				matchid,  
				--CASE WHEN b.bettype IN (1231, 1232, 1233, 1237, 1238) THEN 0 ELSE homeid END homeid,
				CASE WHEN vhr.Bettype IS NOT NULL THEN 0 ELSE homeid END homeid,
				--CASE WHEN b.bettype IN (1231, 1232, 1233, 1237, 1238) THEN 0 ELSE awayid END awayid,  
				CASE WHEN vhr.Bettype IS NOT NULL THEN 0 ELSE awayid END awayid,
				CASE WHEN ISNULL(ss.bettype,0) <> 0 THEN ss.grouptypeId
						ELSE b.bettype 
					END bettype, 
				sporttype,	
				leagueid,   
				CAST(SUM(turnover		* e.Rate) AS MONEY) AS turnover,
				CAST(SUM(MemberWinLost	* e.Rate) AS MONEY) AS MemberWinLost,
				CAST(SUM(LicenseeWL		* e.Rate) AS MONEY) AS LicenseeWL, 
				CAST(SUM(CommBA			* e.Rate) AS MONEY) AS CommBA,
				CAST(SUM(PlayerComm		* e.Rate) AS MONEY) AS PlayerComm,
				CAST(SUM((AmtDuetoBA)	* e.Rate) AS MONEY) AS AmtDuetoBA,
				--CASE WHEN b.bettype IN (1231, 1232, 1233, 1237, 1238) THEN 0 ELSE race END race,  
				CASE WHEN vhr.Bettype IS NOT NULL THEN 0 ELSE race END race,
				--CASE WHEN b.bettype IN (1231, 1232, 1233, 1237, 1238) THEN '' ELSE matchcode END matchcode,  
				CASE WHEN vhr.Bettype IS NOT NULL THEN '' ELSE matchcode END matchcode,
				isNeutral,  
				liveindicator,
				b.KickoffTime,
				SUM(b.betcount) betcount, 		
				'' AS showtime,  
				--ROW_NUMBER() OVER ( ORDER BY betgroup, matchid, leagueid, race, bettype, matchcode ) AS RowNum  
				ROW_NUMBER() OVER (	ORDER BY betgroup,matchid,leagueid) AS RowNum
			FROM    
				@AgMatchWLDetails b  
				INNER JOIN @ExchangeDaily e ON b.currency = e.ExchangeId AND b.winlostdate BETWEEN e.FromDate AND e.ToDate
				LEFT JOIN (SELECT bettype FROM dbo.f_VSHorseRacingByBettype()) vhr on b.bettype = vhr.Bettype
				LEFT JOIN dbo.f_GroupBettype() ss ON b.bettype = ss.bettype
			GROUP BY    
				BetGroup,  
				matchid,  
				--CASE WHEN b.bettype IN (1231, 1232, 1233, 1237, 1238) THEN 0 ELSE homeid END,  
				CASE WHEN vhr.Bettype IS NOT NULL THEN 0 ELSE homeid END,
				--CASE WHEN b.bettype IN (1231, 1232, 1233, 1237, 1238) THEN 0 ELSE awayid END, 
				CASE WHEN vhr.Bettype IS NOT NULL THEN 0 ELSE awayid END,
				CASE WHEN ISNULL(ss.bettype,0) <> 0 THEN ss.grouptypeId
						ELSE b.bettype 
					END,
				sporttype,	
				leagueid, 
				--CASE WHEN b.bettype IN (1231, 1232, 1233, 1237, 1238) THEN 0 ELSE race END,  
				CASE WHEN vhr.Bettype IS NOT NULL THEN 0 ELSE race END,
				--CASE WHEN b.bettype IN (1231, 1232, 1233, 1237, 1238) THEN '' ELSE matchcode END,  
				CASE WHEN vhr.Bettype IS NOT NULL THEN '' ELSE matchcode END,
				isNeutral,  
				liveindicator,
				b.KickoffTime
			) wl  
	WHERE wl.RowNum BETWEEN @RowStart AND @RowEnd  

	SELECT
		CAST(SUM(Turnover		* e.Rate) AS MONEY) AS SumTurnover,
		CAST(SUM(MemberWinLost	* e.Rate) AS MONEY) AS SumMemberWinLost,  
		CAST(SUM(LicenseeWL		* e.Rate) AS MONEY) AS SumLicenseeWL,  
		CAST(SUM(CommBA			* e.Rate) AS MONEY) AS SumCommBA,  
		CAST(SUM(PlayerComm		* e.Rate) AS MONEY) AS SumPlayerComm,
		CAST(SUM(AmtDuetoBA		* e.Rate) AS MONEY) AS SumAmtDuetoBA,
		ISNULL(@TotalRows, 0)						AS TotalRows,
		SUM(b.betcount)								AS SumBetCount
	FROM
		@AgMatchWLDetails b  
		INNER JOIN @ExchangeDaily e ON b.currency = e.ExchangeId AND b.winlostdate BETWEEN e.FromDate AND e.ToDate
END
GO
/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
 
ALTER PROCEDURE [dbo].[Lrf_Rpt_WinlossByLeagueDetail]
	@Odds FLOAT = 0
	,@LeagueID INT
	,@MatchID INT =0
	,@PageSize INT = 1000
	,@PageIndex INT = 1
	,@TotalRows INT = 0 OUTPUT
	,@FromDate SMALLDATETIME
	,@ToDate SMALLDATETIME
	,@MoveBetsDay SMALLDATETIME
	,@ShowWin BIT =1
	,@ShowLoss BIT =1
	,@ShowDraw BIT =1
	,@ShowSB BIT = 1
	,@ShowBA BIT = 1
	,@AgentList		VARCHAR(MAX)
	,@BaseCurrency	VARCHAR(3) = ''
AS
/*  
Created: 20140102@Florent  
Task :   
DB: DB052.bodb02
Original:   
Revisions:  
	- 20140207@Florent: Add filter ShowBA and ShowSB
	- 20140214@Florent: use new sum table rptCustomerMatch
	- 20140620@Florent: offer 14 new bettypes and Sporting Solution (36 new bettypes)
	- 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
	- 20150127@Jim: support base on GBP Currency
	- 20150623@Winnie: exclude 3 transactions SOLD/BOUGHT/BetTrade Commission
	- 20151127@Bobby: #48081 - Apply PH-AIO new bettypes
	- 20151203@Bobby: Database - Change datatype [Redmine: #48660]
	- 20160727@Jim:  LRF - Commercial terms changed for Bet Trade [Redmine: #61342]
	- 20170228@Paul: Get @AgentList by web instead of @UserId, @CurrencyID, @LicenseeID [Redmine: #71679]
	- 20170328@Paul: Implement Cash Out [RedmineID :#71727]
	- 20180808@Amanda: Remove bet type related to Racing [RedmineID: #99378]
	- 20181019@Amanda: Add new bet types for E-Sports 2.0 [RedmineID: #100721]
	- 20190620@Amanda: Add Base currency param [RedmineID: #112531]
	- 20181019@Amanda: Add new bet types (PH AIO - Phase 4a) [RedmineID: #115448]
Param's Explanation:   
   
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @TempFromDate SMALLDATETIME
	DECLARE @TempToDate SMALLDATETIME
	DECLARE @ExchangeDaily TABLE (
		FromDate SMALLDATETIME
		,ToDate SMALLDATETIME
		,ExchangeId INT
		,Rate FLOAT
		)
	--SET @_Date = @Date  
	DECLARE @Today SMALLDATETIME

	SELECT @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120)

	DECLARE @TempAg AS TABLE (CustId INT,Currency int)

	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@AgentList
	
		INSERT INTO @TempAg(CustId, Currency)
		SELECT AgentId, Currency 
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
			,ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH;
	-----------------------------------    


	-----------------------------------
	DECLARE @AgMatchWLDetails TABLE (
		custid INT
		,Winlostdate SMALLDATETIME
		,Currency INT
		,odds MONEY
		,sporttype SMALLINT
		,leagueid INT
		,turnover MONEY
		,MemberWinLost MONEY
		,LicenseeWL MONEY
		,AmtDueToBA MONEY
		,CommBA MONEY
		,PlayerComm MONEY
		,matchcode NVARCHAR(50)
		,isNeutral BIT
		,liveindicator BIT
		,betcount INT
		)
	---
	---
	DECLARE @Status AS TABLE (StatusID INT)

	IF @ShowWin = 1
	BEGIN
		INSERT INTO @status
		SELECT 112

		INSERT INTO @status
		SELECT 114
	END

	IF @Showloss = 1
	BEGIN
		INSERT INTO @status
		SELECT 113

		INSERT INTO @status
		SELECT 115
	END

	IF @Showdraw = 1
		INSERT INTO @status
		SELECT 111

	----
	--IF @_Date > @MoveBetsDay   
	--BEGIN  
	IF @Todate > @MoveBetsDay
	BEGIN
		IF @FromDate <= @MoveBetsDay
			SET @TempFromDate = DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @FromDate

		--ShowBA
		IF @ShowBA = 1
		BEGIN
			INSERT INTO @AgMatchWLDetails
			SELECT b.custid
				,b.Winlostdate
				,b.currency
				,CASE 
					WHEN (b.bettype IN (1,2,3,7,12,8,20,21,1301,1303,1305,1306,1308,1311,1312,1316,1318,1324,153,154,155,156)	 -- add more Sportting Solution bettype 
								OR b.bettype BETWEEN 9001 AND 9086	-- Esport 2
								OR b.bettype BETWEEN 81 AND 88
								OR b.bettype BETWEEN 90 AND 120
								OR b.bettype IN (157,178,183,184,194,197,198,203,204,205) -- add more bettype BetRadar 
								OR b.bettype BETWEEN 401 AND 404 -- add more PH-AIO new bettypes
								OR b.bettype IN (467,468,469) -- PH-AIO new bettypes (phase 4a)
							)
						THEN CASE 
								WHEN b.OddsType = 1
									THEN b.odds + 1 --decimal
								WHEN b.OddsType = 2
									THEN b.Odds + 1 --hongkong to decimal
								WHEN b.OddsType IN (3, 4, 7)
									THEN --malay and indo and new oddstype to decimal
										CASE 
											WHEN b.odds < 0
												THEN (1 - cast(1 AS FLOAT) / cast(b.odds AS FLOAT))
											WHEN b.odds >= 0
												THEN (1 + b.odds)
											END
								WHEN OddsType = 5
									THEN --american odds to decimal
										CASE 
											WHEN (b.odds * 100) < 0
												THEN (1 - cast(1 AS FLOAT) / cast(b.odds AS FLOAT))
											WHEN (b.odds * 100) % 2 = 0
												THEN 2
											WHEN (b.odds * 100) > 0
												THEN (1 + b.odds)
											END
								END
					ELSE b.Odds
					END odds
				,0 sporttype
				,m.leagueid
				,SUM(stake)
				,SUM(winlost - b.actual_stake)
				,0 AS LicenseeWL
				, - SUM(winlost - b.actual_stake + awinlost + comm)AS AmountDueToBA
				,SUM(comm) AS CommBA
				,SUM(b.playercomm) AS PlayerComm
				,m.matchcode
				,ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral
				,b.liveindicator AS liveindicator
				,COUNT(1) betcount
			FROM
				--#TempBetList b  
				bettrans AS b WITH (NOLOCK)
			INNER JOIN match m WITH (NOLOCK) ON m.matchid = b.matchid
			INNER JOIN @TempAg ta ON b.recommend = ta.CustId AND b.Currency = ta.Currency
			WHERE (--SportBook
					b.bettype <= 30
					OR (b.bettype BETWEEN 121 AND 999)
					OR (b.Bettype BETWEEN 1301 and 1399) --new tennis's bettypes
					OR (b.Bettype BETWEEN 9001 and 9086) -- E-Sports
					)
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
				-- --AND b.tpositiontaking <> 0  
				AND b.winlostdate BETWEEN @TempFromDate AND @todate
				AND b.statusID IN (
					SELECT *
					FROM @status
					)
				AND m.leagueid = @LeagueID
				and b.tpositiontaking=0 --GetBA
				AND (@matchid=0 or b.matchid = @MatchID)
			GROUP BY b.custid
				,b.Winlostdate
				,b.currency
				,m.leagueid
				,m.matchcode
				,m.isNeutral
				,b.liveindicator
				,b.tpositiontaking
				,CASE 
					WHEN (b.bettype IN (1,2,3,7,12,8,20,21,1301,1303,1305,1306,1308,1311,1312,1316,1318,1324,153,154,155,156)	 -- add more Sportting Solution bettype 
								OR b.bettype BETWEEN 9001 AND 9086	-- Esport 2
								OR b.bettype BETWEEN 81 AND 88
								OR b.bettype BETWEEN 90 AND 120
								OR b.bettype IN (157,178,183,184,194,197,198,203,204,205) -- add more bettype BetRadar 
								OR b.bettype BETWEEN 401 AND 404 -- add more PH-AIO new bettypes
								OR b.bettype IN (467,468,469) -- PH-AIO new bettypes (phase 4a)
							)
						THEN CASE 
								WHEN b.OddsType = 1
									THEN b.odds + 1 --decimal
								WHEN b.OddsType = 2
									THEN b.Odds + 1 --hongkong to decimal
								WHEN b.OddsType IN (3, 4, 7)
									THEN --malay and indo and new oddstype to decimal
										CASE 
											WHEN b.odds < 0
												THEN (1 - cast(1 AS FLOAT) / cast(b.odds AS FLOAT))
											WHEN b.odds >= 0
												THEN (1 + b.odds)
											END
								WHEN OddsType = 5
									THEN --american odds to decimal
										CASE 
											WHEN (b.odds * 100) < 0
												THEN (1 - cast(1 AS FLOAT) / cast(b.odds AS FLOAT))
											WHEN (b.odds * 100) % 2 = 0
												THEN 2
											WHEN (b.odds * 100) > 0
												THEN (1 + b.odds)
											END
								END
					ELSE b.Odds
					END
			ORDER BY b.winlostdate DESC
		END

		IF @ShowSB = 1
		BEGIN
			INSERT INTO @AgMatchWLDetails
			SELECT b.custid
				,b.Winlostdate
				,b.currency
				,CASE 
					WHEN (b.bettype IN (1,2,3,7,12,8,20,21,1301,1303,1305,1306,1308,1311,1312,1316,1318,1324,153,154,155,156)	 -- add more Sportting Solution bettype 
								OR b.bettype BETWEEN 9001 AND 9086	-- Esport 2
								OR b.bettype BETWEEN 81 AND 88
								OR b.bettype BETWEEN 90 AND 120
								OR b.bettype IN (157,178,183,184,194,197,198,203,204,205) -- add more bettype BetRadar 
								OR b.bettype BETWEEN 401 AND 404 -- add more PH-AIO new bettypes
								OR b.bettype IN (467,468,469) -- PH-AIO new bettypes (phase 4a)
							)
						THEN CASE 
								WHEN b.OddsType = 1
									THEN b.odds + 1 --decimal
								WHEN b.OddsType = 2
									THEN b.Odds + 1 --hongkong to decimal
								WHEN b.OddsType IN (3, 4, 7)
									THEN --malay and indo and new oddstype to decimal
										CASE 
											WHEN b.odds < 0
												THEN (1 - cast(1 AS FLOAT) / cast(b.odds AS FLOAT))
											WHEN b.odds >= 0
												THEN (1 + b.odds)
											END
								WHEN OddsType = 5
									THEN --american odds to decimal
										CASE 
											WHEN (b.odds * 100) < 0
												THEN (1 - cast(1 AS FLOAT) / cast(b.odds AS FLOAT))
											WHEN (b.odds * 100) % 2 = 0
												THEN 2
											WHEN (b.odds * 100) > 0
												THEN (1 + b.odds)
											END
								END
					ELSE b.Odds
					END odds
				,0 sporttype
				,m.leagueid
				,SUM(stake)
				,SUM(winlost - b.actual_stake)
				,- SUM(winlost - b.actual_stake) AS LicenseeWL
				,0 as AmountDueToBA
				,0 AS CommBA
				,SUM(b.playercomm) AS PlayerComm
				,m.matchcode
				,ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral
				,b.liveindicator AS liveindicator
				,COUNT(1) betcount
			FROM
				--#TempBetList b  
				bettrans AS b WITH (NOLOCK)
			INNER JOIN match m WITH (NOLOCK) ON m.matchid = b.matchid
			INNER JOIN @TempAg ta ON b.recommend = ta.CustId AND b.Currency = ta.Currency
			WHERE (
					b.bettype <= 30
					OR (b.bettype BETWEEN 121 AND 999)
					OR (b.Bettype BETWEEN 1301 and 1399) --new tennis's bettypes
					OR (b.Bettype BETWEEN 9001 and 9086) -- E-Sports
					)
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)			
				AND b.winlostdate BETWEEN @TempFromDate AND @todate
				AND b.statusID IN (
					SELECT *
					FROM @status
					)
				AND m.leagueid = @LeagueID
				AND b.tpositiontaking <> 0  
				AND (@matchid=0 or b.matchid = @MatchID)
			GROUP BY b.custid
				,b.Winlostdate
				,b.currency
				,m.leagueid
				,m.matchcode
				,m.isNeutral
				,b.liveindicator
				,b.tpositiontaking
				,CASE 
					WHEN (b.bettype IN (1,2,3,7,12,8,20,21,1301,1303,1305,1306,1308,1311,1312,1316,1318,1324,153,154,155,156)	 -- add more Sportting Solution bettype 
								OR b.bettype BETWEEN 9001 AND 9086	-- Esport 2
								OR b.bettype BETWEEN 81 AND 88
								OR b.bettype BETWEEN 90 AND 120
								OR b.bettype IN (157,178,183,184,194,197,198,203,204,205) -- add more bettype BetRadar 
								OR b.bettype BETWEEN 401 AND 404 -- add more PH-AIO new bettypes
								OR b.bettype IN (467,468,469) -- PH-AIO new bettypes (phase 4a)
							)
						THEN CASE 
								WHEN b.OddsType = 1
									THEN b.odds + 1 --decimal
								WHEN b.OddsType = 2
									THEN b.Odds + 1 --hongkong to decimal
								WHEN b.OddsType IN (3, 4, 7)
									THEN --malay and indo and new oddstype to decimal
										CASE 
											WHEN b.odds < 0
												THEN (1 - cast(1 AS FLOAT) / cast(b.odds AS FLOAT))
											WHEN b.odds >= 0
												THEN (1 + b.odds)
											END
								WHEN OddsType = 5
									THEN --american odds to decimal
										CASE 
											WHEN (b.odds * 100) < 0
												THEN (1 - cast(1 AS FLOAT) / cast(b.odds AS FLOAT))
											WHEN (b.odds * 100) % 2 = 0
												THEN 2
											WHEN (b.odds * 100) > 0
												THEN (1 + b.odds)
											END
								END
					ELSE b.Odds
					END
			ORDER BY b.winlostdate DESC
		END
	END

	IF @Fromdate <= @MoveBetsDay
	BEGIN
		IF @ToDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @ToDate

		--Get general data  
		begin
			IF @ShowBA=1 
			BEGIN
				INSERT INTO @AgMatchWLDetails
				SELECT b.custid
					,b.Winlostdate
					,ta.currency
					,CASE 
						WHEN (b.bettype IN (1,2,3,7,12,8,20,21,1301,1303,1305,1306,1308,1311,1312,1316,1318,1324,153,154,155,156)	 -- add more Sportting Solution bettype 
								OR b.bettype BETWEEN 9001 AND 9086	-- Esport 2
								OR b.bettype BETWEEN 81 AND 88
								OR b.bettype BETWEEN 90 AND 120
								OR b.bettype IN (157,178,183,184,194,197,198,203,204,205) -- add more bettype BetRadar 
								OR b.bettype BETWEEN 401 AND 404 -- add more PH-AIO new bettypes
								OR b.bettype IN (467,468,469) -- PH-AIO new bettypes (phase 4a)
							)
							THEN CASE 
									WHEN b.OddsType = 1
										THEN b.odds + 1 --decimal
									WHEN b.OddsType = 2
										THEN b.Odds + 1 --hongkong to decimal
									WHEN b.OddsType IN (3, 4, 7)
										THEN --malay and indo and new oddstype to decimal
											CASE 
												WHEN b.odds < 0
													THEN (1 - cast(1 AS FLOAT) / cast(b.odds AS FLOAT))
												WHEN b.odds >= 0
													THEN (1 + b.odds)
												END
									WHEN OddsType = 5
										THEN --american odds to decimal
											CASE 
												WHEN (b.odds * 100) < 0
													THEN (1 - cast(1 AS FLOAT) / cast(b.odds AS FLOAT))
												WHEN (b.odds * 100) % 2 = 0
													THEN 2
												WHEN (b.odds * 100) > 0
													THEN (1 + b.odds)
												END
									END
						ELSE b.Odds
						END odds
					,0 AS sporttype
					,@LeagueID leagueid
					,SUM(stake)
					,SUM(winlost)
					,0 AS LicenseeWL
					--,sum(AmtDueToBA) AS AmountDueToBA
					,-sum(Winlost +  awinlost + comm) AS AmountDueToBA
					--0 AS AmountDueToBA,
					,SUM (comm ) AS CommBA
					--0 AS CommBA
					,0 PlayerComm
					,0 matchcode
					,0 AS IsNeutral
					,0 AS liveindicator
					,SUM(b.betcount) betcount
				FROM bodb_LicenseeReport.dbo.rptCustomerMatch b WITH (
						NOLOCK
						)
				INNER JOIN @TempAg ta ON b.recommend = ta.CustId AND b.Currency = ta.Currency
				WHERE b.winlostdate BETWEEN @FromDate AND @TempToDate
					AND (
						b.bettype <= 30
						OR (b.bettype BETWEEN 121 AND 999)
						OR (b.Bettype BETWEEN 1301 and 1399) --new tennis's bettypes
						OR (b.Bettype BETWEEN 9001 and 9086) -- E-Sports
						)
					AND (b.bettype < 901 OR b.bettype > 904)
					AND (b.bettype < 911 OR b.bettype > 914)
					AND (@matchid=0 or b.matchid = @MatchID)
					AND b.statusID IN (
						SELECT *
						FROM @status
						)
					And b.isBA=1
					AND b.leagueid=@leagueid
				GROUP BY b.custid
					,b.Winlostdate
					,ta.Currency
					,b.isBA
					,CASE 
						WHEN (b.bettype IN (1,2,3,7,12,8,20,21,1301,1303,1305,1306,1308,1311,1312,1316,1318,1324,153,154,155,156)	 -- add more Sportting Solution bettype 
								OR b.bettype BETWEEN 9001 AND 9086	-- Esport 2
								OR b.bettype BETWEEN 81 AND 88
								OR b.bettype BETWEEN 90 AND 120
								OR b.bettype IN (157,178,183,184,194,197,198,203,204,205) -- add more bettype BetRadar 
								OR b.bettype BETWEEN 401 AND 404 -- add more PH-AIO new bettypes
								OR b.bettype IN (467,468,469) -- PH-AIO new bettypes (phase 4a)
							)
							THEN CASE 
									WHEN b.OddsType = 1
										THEN b.odds + 1 --decimal
									WHEN b.OddsType = 2
										THEN b.Odds + 1 --hongkong to decimal
									WHEN b.OddsType IN (3, 4, 7)
										THEN --malay and indo and new oddstype to decimal
											CASE 
												WHEN b.odds < 0
													THEN (1 - cast(1 AS FLOAT) / cast(b.odds AS FLOAT))
												WHEN b.odds >= 0
													THEN (1 + b.odds)
												END
									WHEN OddsType = 5
										THEN --american odds to decimal
											CASE 
												WHEN (b.odds * 100) < 0
													THEN (1 - cast(1 AS FLOAT) / cast(b.odds AS FLOAT))
												WHEN (b.odds * 100) % 2 = 0
													THEN 2
												WHEN (b.odds * 100) > 0
													THEN (1 + b.odds)
												END
									END
						ELSE b.Odds
						END
			END
				IF @ShowSB=1 
			BEGIN
				INSERT INTO @AgMatchWLDetails
				SELECT b.custid
					,b.Winlostdate
					,ta.currency
					,CASE 
						WHEN (b.bettype IN (1,2,3,7,12,8,20,21,1301,1303,1305,1306,1308,1311,1312,1316,1318,1324,153,154,155,156)	 -- add more Sportting Solution bettype 
								OR b.bettype BETWEEN 9001 AND 9086	-- Esport 2
								OR b.bettype BETWEEN 81 AND 88
								OR b.bettype BETWEEN 90 AND 120
								OR b.bettype IN (157,178,183,184,194,197,198,203,204,205) -- add more bettype BetRadar 
								OR b.bettype BETWEEN 401 AND 404 -- add more PH-AIO new bettypes
								OR b.bettype IN (467,468,469) -- PH-AIO new bettypes (phase 4a)
							)
							THEN CASE 
									WHEN b.OddsType = 1
										THEN b.odds + 1 --decimal
									WHEN b.OddsType = 2
										THEN b.Odds + 1 --hongkong to decimal
									WHEN b.OddsType IN (3, 4, 7)
										THEN --malay and indo and new oddstype to decimal
											CASE 
												WHEN b.odds < 0
													THEN (1 - cast(1 AS FLOAT) / cast(b.odds AS FLOAT))
												WHEN b.odds >= 0
													THEN (1 + b.odds)
												END
									WHEN OddsType = 5
										THEN --american odds to decimal
											CASE 
												WHEN (b.odds * 100) < 0
													THEN (1 - cast(1 AS FLOAT) / cast(b.odds AS FLOAT))
												WHEN (b.odds * 100) % 2 = 0
													THEN 2
												WHEN (b.odds * 100) > 0
													THEN (1 + b.odds)
												END
									END
						ELSE b.Odds
						END odds
					,0 AS sporttype
					,@LeagueID leagueid
					,SUM(stake)
					,SUM(winlost)
					,- SUM(b.winlost) AS LicenseeWL
					,0 AmountDueToBA
					,0 AS CommBA			
					,0 AS PlayerComm
					,0 matchcode
					,0 AS IsNeutral
					,0 AS liveindicator
					,SUM(b.betcount) betcount
				FROM bodb_LicenseeReport.dbo.rptCustomerMatch b WITH (
						NOLOCK
						)
				INNER JOIN @TempAg ta ON b.recommend = ta.CustId AND b.Currency = ta.Currency
				WHERE b.winlostdate BETWEEN @FromDate AND @TempToDate
					AND (
						b.bettype <= 30
						OR (b.bettype BETWEEN 121 AND 999)
						OR (b.Bettype BETWEEN 1301 and 1399) --new tennis's bettypes
						OR (b.Bettype BETWEEN 9001 and 9086) -- E-Sports
						)
					AND (b.bettype < 901 OR b.bettype > 904)
					AND (b.bettype < 911 OR b.bettype > 914)
					--AND b.matchid = @MatchID
					AND (@matchid=0 or b.matchid = @MatchID)
					AND b.statusID IN (
						SELECT *
						FROM @status
						)
					AND b.isBA=0
					and b.leagueid=@leagueid
				GROUP BY b.custid
					,b.Winlostdate
					,ta.currency				
					,b.isBA
					,CASE 
						WHEN (b.bettype IN (1,2,3,7,12,8,20,21,1301,1303,1305,1306,1308,1311,1312,1316,1318,1324,153,154,155,156)	 -- add more Sportting Solution bettype 
								OR b.bettype BETWEEN 9001 AND 9086	-- Esport 2
								OR b.bettype BETWEEN 81 AND 88
								OR b.bettype BETWEEN 90 AND 120
								OR b.bettype IN (157,178,183,184,194,197,198,203,204,205) -- add more bettype BetRadar 
								OR b.bettype BETWEEN 401 AND 404 -- add more PH-AIO new bettypes
								OR b.bettype IN (467,468,469) -- PH-AIO new bettypes (phase 4a)
							)
							THEN CASE 
									WHEN b.OddsType = 1
										THEN b.odds + 1 --decimal
									WHEN b.OddsType = 2
										THEN b.Odds + 1 --hongkong to decimal
									WHEN b.OddsType IN (3, 4, 7)
										THEN --malay and indo and new oddstype to decimal
											CASE 
												WHEN b.odds < 0
													THEN (1 - cast(1 AS FLOAT) / cast(b.odds AS FLOAT))
												WHEN b.odds >= 0
													THEN (1 + b.odds)
												END
									WHEN OddsType = 5
										THEN --american odds to decimal
											CASE 
												WHEN (b.odds * 100) < 0
													THEN (1 - cast(1 AS FLOAT) / cast(b.odds AS FLOAT))
												WHEN (b.odds * 100) % 2 = 0
													THEN 2
												WHEN (b.odds * 100) > 0
													THEN (1 + b.odds)
												END
									END
						ELSE b.Odds
						END
			END
		end
	END

	INSERT INTO @ExchangeDaily(FromDate, ToDate, ExchangeId, Rate)
	SELECT FromDate, ToDate, ExchangeID, Rate
	FROM dbo.Lrf_f_GetExchangeRate(@fromDate, @ToDate, @BaseCurrency, '') e
	WHERE EXISTS (SELECT 1 FROM @TempAg a WHERE a.Currency = e.ExchangeID)

	DECLARE @RowStart INT
		,@RowEnd INT

	SELECT @PageIndex = @PageIndex - 1
		,@RowStart = @PageSize * @PageIndex + 1
		,@RowEnd = @RowStart + @PageSize - 1

	SELECT @TotalRows = count(a.custid)
	FROM (
		SELECT custid
		FROM @AgMatchWLDetails
		WHERE odds >= @odds
		GROUP BY custid
			,sporttype
			,leagueid
		) A

	--SELECT @TotalRow TotalRow 
	-- Result  
	SELECT A.*
	FROM (
		SELECT ROW_NUMBER() OVER (
				ORDER BY b.custid
					,username
					,SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, len(c.username2) - CHARINDEX('$', c.username2))
					,sporttype
					,leagueid
				) AS RowNum
			,b.custid
			,c.username
			,SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, len(c.username2) - CHARINDEX('$', c.username2)) AS nickname
			,sporttype
			,leagueid
			,CAST(SUM(turnover * e.Rate) AS MONEY) AS turnover
		
			,CAST(SUM(MemberWinLost * e.Rate) AS MONEY) AS MemberWinLost

			--- licenseeWL  
			,CAST(SUM(LicenseeWL * e.Rate) AS MONEY) AS LicenseeWL
		
			,CAST(SUM(CommBA * e.Rate) AS MONEY) AS CommBA
		
			,CAST(SUM(PlayerComm * e.Rate) AS MONEY) AS PlayerComm
		
			,CAST(SUM((AmtDuetoBA) * e.Rate) AS MONEY) AS AmtDuetoBA
			,sum(b.betcount) betcount
		FROM @AgMatchWLDetails b
		INNER JOIN Customer c(NOLOCK) ON b.custid = c.custid
		INNER JOIN @ExchangeDaily e ON b.winlostdate BETWEEN e.FromDate AND e.ToDate
			AND b.currency = e.ExchangeId
		WHERE odds >= @odds
		GROUP BY b.custid
			,username
			,SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, len(c.username2) - CHARINDEX('$', c.username2))
			,sporttype
			,leagueid
			--ORDER BY b.custid
		) A
	WHERE A.RowNum BETWEEN @RowStart AND @RowEnd

	SELECT  CAST(SUM(turnover * e.Rate) AS MONEY) AS turnover

			,CAST(SUM(MemberWinLost * e.Rate) AS MONEY) AS MemberWinLost

			--- licenseeWL  
			,CAST(SUM(LicenseeWL * e.Rate) AS MONEY) AS LicenseeWL
		
			,CAST(SUM(CommBA * e.Rate) AS MONEY) AS CommBA
		
			,CAST(SUM(PlayerComm * e.Rate) AS MONEY) AS PlayerComm
		
			,CAST(SUM((AmtDuetoBA) * e.Rate) AS MONEY) AS AmtDuetoBA
			,sum(b.betcount) betcount
		FROM @AgMatchWLDetails b
		INNER JOIN Customer c(NOLOCK) ON b.custid = c.custid
		INNER JOIN @ExchangeDaily e ON b.winlostdate BETWEEN e.FromDate AND e.ToDate
			AND b.currency = e.ExchangeId
		WHERE odds >= @odds


END
GO
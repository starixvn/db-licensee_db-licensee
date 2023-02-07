USE [bodb_LicenseeReport]
GO
CREATE OR ALTER FUNCTION [dbo].[LAP_f_WinlossAnalysis_BettransSel] (
	@AgentList		XML, 
	@FromDate		SMALLDATETIME, 
	@ToDate			SMALLDATETIME, 
	@BettypeRef		XML, 
	@StatusIds		VARCHAR(1000),
	@BetFromRef		XML,
	@LiveIds		VARCHAR(1000),
	@BaseCurrency	VARCHAR(12),
	@SportIDs		VARCHAR(1000)
)
RETURNS TABLE
AS
RETURN
	WITH CTE_Agency AS (
		SELECT DISTINCT t.c.value('@AgencyId', 'INT') AS recommend,
			t.c.value('@Currency', 'INT') AS Currency
		FROM @AgentList.nodes('/ROOT/Agent') AS t(c)
	),
	CTE_BetFrom AS (
		SELECT DISTINCT t.c.value('@PlatformId', 'INT') AS PlatformId,
			t.c.value('@BetFrom', 'VARCHAR(5)') AS BetFrom
		FROM @BetFromRef.nodes('/ROOT/Row') AS t(c)
	),
	CTE_Bettype AS (
		SELECT DISTINCT tbl.ProductId, tbl.Bettype, tbl.RefTable, tbl.EventType,
			CASE WHEN tbl.RefTable IN (1,2) OR tbl.ProductID = 47 THEN 1 ELSE 0 END IsUsingOddsSpread,
			CASE WHEN cont.Bettype IS NOT NULL THEN 1 ELSE 0 END AS IsContributionBettype,
			tbl.Product3rdId
		FROM (
			SELECT DISTINCT t.c.value('@p', 'INT') AS ProductId,
				t.c.value('@p3', 'INT') AS Product3rdId,
				t.c.value('@b', 'INT') AS Bettype,
				t.c.value('@r', 'INT') AS RefTable,
				t.c.value('@e', 'INT') AS EventType
			FROM @BettypeRef.nodes('/ROOT/Row') AS t(c)
		) AS tbl
		OUTER APPLY 
		(
			SELECT f.Bettype
			FROM bodb02.dbo.f_BettypePrizeGroup() f
			WHERE f.BettypeGroup = 'Contribution'
				AND f.Bettype = tbl.bettype
		) AS cont
	), CTE_SabaSporttypeRef AS (
		SELECT t.SportType AS SabaSportType, t.SportType, t.LeagueGroupID
		FROM bodb02.[dbo].[LAP_f_WinlossAnalysis_SabaSportSel] () AS saba
		CROSS APPLY
		(
			SELECT Sporttype, LeagueGroupID
			FROM OPENJSON(saba.SporttypeRef)
			WITH (Sporttype INT '$.Sporttype',
				LeagueGroupIDs NVARCHAR(MAX) '$.LeagueGroupID' AS JSON
			)
			CROSS APPLY OPENJSON(LeagueGroupIDs) WITH (LeagueGroupID VARCHAR(20) '$')
		) AS t
		WHERE saba.SporttypeRef IS NOT NULL
	)
	SELECT 
		b.[recommend]
		,CAST(b.[winlostdate] AS DATE) AS [winlostdate]
		,s.ProductId, s.Product3rdId
		,ck.sporttype
		,b.[bettype]
		,b.[custid]
		,b.[currency]
		,bf.PlatformId
		-----------------
		,SUM(CASE 
				WHEN s.Product3rdId & 12 = 12 THEN ck.Turnover
				WHEN s.Product3rdId & 8 = 0 AND ba.IsBA = 1 THEN 0
				WHEN s.Product3rdId & 8 = 8 AND ba.IsBA = 0 THEN 0
				ELSE ck.Turnover
			END) AS Turnover
		,SUM(CASE 
				WHEN s.Product3rdId & 12 = 12 THEN ck.NetTurnover
				WHEN s.Product3rdId & 8 = 0 AND ba.IsBA = 1 THEN 0
				WHEN s.Product3rdId & 8 = 8 AND ba.IsBA = 0 THEN 0
				ELSE ck.NetTurnover
			END) AS NetTurnover
		,SUM(CASE 
				WHEN s.Product3rdId & 12 = 12 THEN (b.winlost-b.actual_stake)
				WHEN s.Product3rdId & 8 = 0 AND ba.IsBA = 1 THEN 0
				WHEN s.Product3rdId & 8 = 8 AND ba.IsBA = 0 THEN 0
				ELSE (b.winlost-b.actual_stake)
			END) AS MemWinloss
		,SUM(CASE 
				WHEN s.Product3rdId & 12 = 12 THEN b.[playercomm]
				WHEN s.Product3rdId & 8 = 0 AND ba.IsBA = 1 THEN 0
				WHEN s.Product3rdId & 8 = 8 AND ba.IsBA = 0 THEN 0
				ELSE b.[playercomm]
			END) AS [MemComm]
		,SUM(CASE 
				WHEN s.Product3rdId & 12 = 12 THEN b.[comm]
				WHEN s.Product3rdId & 8 = 0 AND ba.IsBA = 1 THEN 0
				WHEN s.Product3rdId & 8 = 8 AND ba.IsBA = 0 THEN 0
				ELSE b.[comm]
			END) AS [LicComm]
		--,SUM(CASE 
		--		WHEN s.Product3rdId & 12 = 12 THEN ck.BetEffective
		--		WHEN s.Product3rdId & 8 = 0 AND ba.IsBA = 1 THEN 0
		--		WHEN s.Product3rdId & 8 = 8 AND ba.IsBA = 0 THEN 0
		--		ELSE ck.BetEffective
		--	END) AS BetEffective
		,SUM(CASE 
				WHEN s.Product3rdId & 12 = 12 THEN ck.AmtDueToBA
				WHEN s.Product3rdId & 8 = 0 AND ba.IsBA = 1 THEN 0
				WHEN s.Product3rdId & 8 = 8 AND ba.IsBA = 0 THEN 0
				ELSE ck.AmtDueToBA
			END) AS AmtDueToBA
		------------BASE
		--,SUM(Turnover * e.Rate) AS BaseTurnover
		--,SUM(NetTurnover * e.Rate) AS BaseNetTurnover
		--,SUM((b.winlost-b.actual_stake) * e.Rate) AS BaseMemWinloss
		--,SUM(b.[playercomm] * e.Rate) AS [BaseMemComm]
		--,SUM(b.[comm] * e.Rate) AS [BaseLicComm]
		--,SUM(BetEffective * e.Rate) AS BaseBetEffective
		--,SUM(AmtDueToBA * e.Rate) AS BaseAmtDueToBA
		,SUM(CASE 
				WHEN s.Product3rdId & 12 = 12 THEN 1
				WHEN s.Product3rdId & 8 = 0 AND ba.IsBA = 1 THEN 0
				WHEN s.Product3rdId & 8 = 8 AND ba.IsBA = 0 THEN 0
				ELSE 1
			END) AS BetCount

	FROM [bodb02].[dbo].[bettrans] b WITH(NOLOCK)--, INDEX=IX_recommend)
		INNER JOIN CTE_Agency cs WITH(NOLOCK) on cs.recommend = b.recommend
		INNER JOIN CTE_Bettype s ON s.bettype = b.bettype 
		LEFT JOIN [bodb02].dbo.match m WITH(NOLOCK) ON b.matchid = m.matchid
		LEFT JOIN [bodb02].dbo.League l WITH(NOLOCK) ON m.leagueid = l.leagueid AND l.LeagueGroupID IN (42,74,108,113,122,151)
		LEFT JOIN [bodb02].dbo.outright o WITH(NOLOCK) ON b.matchid = o.orid
		LEFT JOIN [bodb02].dbo.League lo WITH (NOLOCK) ON lo.leagueid = o.leagueid
		LEFT JOIN [bodb02].dbo.VSRaceInfo vs WITH(NOLOCK) ON b.matchid = vs.EventID
		LEFT JOIN [bodb_licensee].dbo.LicenseeBATransaction AS lba WITH (NOLOCK) ON b.transid = lba.transid
		OUTER APPLY (
			SELECT 
				IIF(lba.TransID IS NOT NULL, 1, 0) AS IsBA
		) AS ba
		OUTER APPLY ( 
			SELECT TOP 1 SabaSportType 
			FROM CTE_SabaSporttypeRef ref 
			WHERE s.ProductId = 1 AND ref.Sporttype = m.Sporttype AND ref.LeagueGroupID = l.LeagueGroupID
		) AS saba
		OUTER APPLY (
			SELECT 
				ABS(b.[stake]) AS Turnover,
				CASE
					WHEN b.statusID IN (112, 113) AND
						b.modds IN (-0.25, 0.25)
						---- Sportsbook
						AND (b.bettype < 999 OR
						b.bettype BETWEEN 1301 AND 1399 OR--Sporting Solution
						b.bettype BETWEEN 9001 AND 9399 OR--E-Sports
						b.bettype BETWEEN 9400 AND 9998) AND --Cricket AIO
						b.bettype NOT IN (71, 72) AND
						b.bettype NOT BETWEEN 81 AND 120 THEN ABS(stake) / 2
					WHEN s.IsUsingOddsSpread = 1 THEN b.oddsspread -- BBIN
					ELSE ABS(b.stake)
				END AS NetTurnover,
				(CASE
					WHEN ba.IsBA = 1 THEN 0
					ELSE ABS(b.winlost)
				END) AS BetEffective,
				-(CASE
					WHEN ba.IsBA = 1 THEN (b.winlost + b.awinlost + b.comm) --COUNT for BA's tickets
					ELSE 0
				END) AS AmtDueToBA,
				CASE 
					WHEN s.EventType = 1 THEN 
						CASE 
							WHEN s.ProductId = 1 AND s.EventType = 1 AND b.betdaqid = -2 THEN -2 --> Castout Sport 
							--WHEN s.ProductId = 1 AND m.sporttype = 1 AND l.LeagueGroupID IN (42,74,108) THEN
							--WHEN s.ProductId = 1 AND m.sporttype = 1 AND l.LeagueGroupID IN (42,74,108) THEN -3 --> SABA Soccer
							--WHEN s.ProductId = 1 AND m.sporttype = 1 AND l.LeagueGroupID IN (113) THEN -4 --> SABA Soccer PinGoal
							--WHEN s.ProductId = 1 AND m.sporttype = 2 AND l.LeagueGroupID IN (42) THEN -5 --> SABA Basketball
							--WHEN s.ProductId = 1 AND m.sporttype = 2 AND l.LeagueGroupID IN (122) THEN -6 --> SABA Basketball PinGoal
							--WHEN s.ProductId = 1 AND m.sporttype = 43 AND l.LeagueGroupID IN (151) THEN -7 --> SABA ESports PinGoal
							--WHEN s.ProductId = 1 AND m.sporttype = 50 AND l.LeagueGroupID IN (42) THEN -8 --> SABA Cricket
							ELSE CAST(ISNULL(saba.SabaSportType, m.sporttype) AS INT)
						END
					WHEN s.EventType = 2 THEN CAST(lo.sporttype AS INT)
					WHEN s.EventType = 3 THEN CAST(vs.SportType AS INT)
					WHEN s.EventType = 0 THEN
						CASE WHEN b.matchid = 29 THEN -1 --Parlay Sport
						ELSE b.matchid
						END
					ELSE 0
				END AS SportType,
				--0 AS SportType,
				--CASE 
				--	WHEN ((l.LeagueGroupID IN (42,74,108,113) AND m.sporttype = 1 ) 
				--			OR (l.LeagueGroupID IN (122, 42) AND m.sporttype = 2 )
				--			OR (l.LeagueGroupID = 42 AND m.sporttype = 50)
				--			OR (l.LeagueGroupID = 151 AND m.sporttype = 43)
				--		) AND b.betdaqid <> -2 --AND b.winlostdate >= SabaInfo_CutOffDate 
				--		THEN l.LeagueGroupID 
				--	ELSE 0
				--END AS LeagueGroupID, -- Saba Sports
				--0 AS LeagueGroupID,
				CASE
					WHEN s.ProductId = 1 AND s.EventType = 1 AND b.betdaqid = -2 THEN 1 -- Castout
					ELSE 0
				END AS TicketType,
				CASE
					WHEN 
						--b.winlostdate >= HWHLCutDate AND
						b.statusID IN (112, 113)
						AND b.modds IN (-0.25, 0.25)
						AND (b.bettype < 999
							OR b.bettype BETWEEN 1301 AND 1399
							OR b.bettype BETWEEN 9001 AND 9399
							OR b.bettype BETWEEN 9400 AND 9998
							OR b.bettype BETWEEN 3900 AND 3999)	-- Sportsbook
						AND b.bettype NOT IN (29, 38, 911, 912, 913, 914)  --- Parlay, betbuilder, Cashout
						AND b.bettype NOT BETWEEN 81 AND 120
						THEN CASE WHEN b.statusID = 112 THEN 114 ELSE 115 END
					WHEN 
						--b.winlostdate < HWHLCutDate AND 
						b.statusID IN (112, 113)
						AND b.bettype IN (1, 3, 7, 8, 17, 18, 124, 125, 482, 483, 484, 485)
						AND ABS(b.modds) = 0.25
						THEN CASE WHEN b.statusID = 112 THEN 114 ELSE 115 END
					ELSE b.statusID
				END AS statusID,
				ISNULL(CASE WHEN b.bettype IN(9,29) THEN b.livehomescore ELSE b.liveindicator END, 0) AS liveindicator
		) AS ck
		OUTER APPLY (SELECT TOP 1 bf.PlatformId FROM CTE_BetFrom bf WHERE b.betfrom =  bf.BetFrom) AS bf
		
	WHERE b.winlostdate BETWEEN @FromDate AND @ToDate
		AND ',' + @StatusIDs + ',' LIKE '%,' + CAST(b.statusID AS VARCHAR(3)) + ',%'
		AND (@LiveIds IS NULL OR ',' + @LiveIds + ',' LIKE '%,' + CAST(ck.liveindicator AS VARCHAR(3)) + ',%')
		AND (@SportIDs IS NULL OR  ',' + @SportIDs + ',' LIKE '%,' + CAST(ck.sporttype AS VARCHAR(3)) + ',%')
		--AND b.matchid = 70073138

	GROUP BY b.[recommend]
		,CAST(b.[winlostdate] AS DATE)
		,s.ProductId, s.Product3rdId
		,ck.sporttype
		,b.[bettype]
		,b.[custid]
		,b.[currency]
		,bf.PlatformId


	HAVING SUM(CASE 
				WHEN s.Product3rdId & 12 = 12 THEN 1
				WHEN s.Product3rdId & 8 = 0 AND ba.IsBA = 1 THEN 0
				WHEN s.Product3rdId & 8 = 8 AND ba.IsBA = 0 THEN 0
				ELSE 1
			END) > 0

USE [bodb_LicenseeReport]
GO
/****** Object:  UserDefinedFunction [dbo].[f_LicenseeWinlossActive]    Script Date: 1/18/2023 3:57:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


--CREATE OR ALTER  VIEW [dbo].[view_LicenseeWinlossActive]
CREATE OR ALTER  FUNCTION [dbo].[f_LicenseeWinlossActiveSel] (
	@AgentList		XML, 
	@FromDate		SMALLDATETIME, 
	@ToDate			SMALLDATETIME, 
	@BettypeRef		XML, 
	@StatusIds		VARCHAR(1000),
	@Betfroms		NVARCHAR(1000),
	@LiveIds		VARCHAR(1000),
	@PlayerList		XML,
	@SportIDs		VARCHAR(1000)
)
RETURNS TABLE
AS
RETURN
	WITH CTE_agency AS (
		SELECT DISTINCT t.c.value('@AgencyId', 'int') AS recommend
		FROM @AgentList.nodes('/root/row') AS t(c)
	),
	CTE_Player AS (
		SELECT DISTINCT t.c.value('@CustId', 'int') AS custid
		FROM @PlayerList.nodes('/root/row') AS t(c)
	),
	cteWLD AS (
		SELECT 
			CAST(MAX(NetTO_CutOffDate) AS SMALLDATETIME) AS NetTO_CutOffDate
			, CAST(MAX(GrossComm_CutOffDate) AS SMALLDATETIME) AS GrossComm_CutOffDate
			, CAST(MAX(SabaInfo_CutOffDate) AS SMALLDATETIME) AS SabaInfo_CutOffDate
			, CAST('2019-10-01' AS SMALLDATETIME) AS HWHLCutDate
		FROM (
			SELECT  NetTO_CutOffDate = CASE WHEN f.TypeName = 'NetTO' THEN f.CutoffDate ELSE NULL END
				,GrossComm_CutOffDate = CASE WHEN f.TypeName = 'GrossComm' THEN f.CutoffDate ELSE NULL END
				,SabaInfo_CutOffDate = CASE WHEN f.TypeName = 'SabaSport' THEN f.CutoffDate ELSE NULL END
			--FROM bodb02.dbo.Lrf_f_GetCutOffDate() f
			FROM bodb02.dbo.f_GetCutOffDate() f
			WHERE f.TypeName IN ('NetTO', 'GrossComm','SabaSport')
		) AS ck
	),
	sportBettype AS (
		SELECT tbl.ProductId, tbl.Bettype, tbl.RefTable, tbl.EventType,SportType,
			CASE WHEN tbl.RefTable IN (1,2) OR tbl.ProductID = 47 THEN 1 ELSE 0 END IsUsingOddsSpread,
			CASE WHEN cont.Bettype IS NOT NULL THEN 1 ELSE 0 END AS IsContributionBettype
		FROM (
			SELECT t.c.value('@p', 'int') AS ProductId,
				t.c.value('@p', 'int') AS Bettype,
				t.c.value('@r', 'int') AS RefTable,
				t.c.value('@e', 'int') AS EventType,
				t.c.value('@s', 'int') AS SportType
			FROM @BettypeRef.nodes('/root/row') AS t(c)
		) AS tbl
		OUTER APPLY 
		(
			SELECT f.Bettype
			FROM bodb02.dbo.f_BettypePrizeGroup() f
			WHERE f.BettypeGroup = 'Contribution'
				AND f.Bettype = tbl.bettype
		) AS cont
	)
	SELECT 
		b.[recommend]
		,b.[winlostdate]
		,s.ProductId
		,ck.sporttype
		,b.[bettype]
		,b.[custid]
		,b.[currency]
		,b.[betfrom]
		/*,ck.LeagueGroupID
		,ck.ticketType
		,ck.[statusID]
		,ba.IsBA
		,ck.liveindicator
		,b.[apositiontaking]*/
		-----------------
		,SUM(Turnover) AS Turnover
		,SUM(NetTurnover) AS NetTurnover
		,SUM(b.winlost-b.actual_stake) AS MemWinloss
		,SUM(b.[playercomm]) AS [MemComm]
		,SUM(b.[comm]) AS [LicComm]
		,SUM(BetEffective) AS BetEffective
		,SUM(AmtDueToBA) AS AmtDueToBA
		,COUNT(1) AS BetCount

	FROM [bodb02].[dbo].[bettrans] b with(nolock)
		INNER JOIN CTE_agency cs WITH(NOLOCK) on cs.recommend = b.recommend
		INNER JOIN sportBettype s ON s.bettype = b.bettype 
		LEFT JOIN [bodb02].dbo.match m WITH(NOLOCK) ON b.matchid = m.matchid
		LEFT JOIN [bodb02].dbo.League l WITH(NOLOCK) ON m.leagueid = l.leagueid AND l.LeagueGroupID IN (42,74,108,113,122,151)
		LEFT JOIN [bodb02].dbo.outright o WITH(NOLOCK) ON b.matchid = o.orid
		LEFT JOIN bodb02.dbo.League lo WITH (NOLOCK) ON lo.leagueid = o.leagueid
		LEFT JOIN [bodb02].dbo.VSRaceInfo vs WITH(NOLOCK) ON b.matchid = vs.EventID
		LEFT JOIN bodb_licensee.dbo.LicenseeBATransaction AS lba WITH (NOLOCK) ON b.transid = lba.transid
		OUTER APPLY cteWLD wld
		OUTER APPLY (
			SELECT IIF(lba.TransID IS NOT NULL, 1, 0) AS IsBA
		) AS ba
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
					WHEN b.statusID = 111 AND
						(
						---- Sportsbook
						(b.bettype < 999 OR
						b.bettype BETWEEN 1301 AND 1399 OR--Sporting Solution
						b.bettype BETWEEN 9001 AND 9399 OR--E-Sports
						b.bettype BETWEEN 9400 AND 9998) AND--Cricket AIO
						b.bettype NOT IN (71, 72) AND
						b.bettype NOT BETWEEN 81 AND 120
					) THEN 0
					WHEN b.winlostdate < NetTO_CutOffDate AND
						(
							b.bettype BETWEEN 2401 AND 2499   -- Allbet
							OR b.bettype BETWEEN 3001 AND 3099   -- SA Gaming
							OR b.bettype BETWEEN 3101 AND 3150   -- AE Casino
							OR b.bettype BETWEEN 3300 AND 3399   -- BBIN	
							OR b.bettype BETWEEN 3201 AND 3299   -- IBCBet Live Casino
							OR b.bettype BETWEEN 5601 AND 5699   -- ION 	 
							OR b.bettype BETWEEN 3401 AND 3499   -- WM
							OR b.bettype BETWEEN 5701 AND 5799   -- GDG
							OR b.bettype BETWEEN 3501 AND 3599   -- BG
							OR b.bettype BETWEEN 3701 AND 3799   -- PP Live Casino
						) THEN oddsspread
					WHEN s.IsUsingOddsSpread = 1 THEN b.oddsspread -- BBIN
					WHEN s.RefTable IN (1, 2) AND b.winlostdate >= GrossComm_CutOffDate THEN 0
					WHEN s.RefTable IN (1, 2) AND b.winlostdate >= NetTO_CutOffDate THEN
						CASE WHEN s.IsContributionBettype = 0 THEN b.oddsspread ELSE 0	END
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
							WHEN s.ProductId = 1 AND s.EventType = 1 AND b.betdaqid = -2 THEN -98 --> Castout Sport 
							ELSE CAST(m.sporttype AS INT)
						END
					WHEN s.EventType = 2 THEN CAST(lo.sporttype AS INT)
					WHEN s.EventType = 3 THEN CAST(vs.SportType AS INT)
					WHEN s.EventType = 0 THEN
						CASE WHEN b.matchid <> 2799 AND b.matchid = 29 THEN -99 --Parlay Sport
						ELSE b.matchid 
						END
					ELSE s.SportType
				END AS SportType,
				--s.SportType,
				CASE 
					WHEN ((l.LeagueGroupID IN (42,74,108,113) AND m.sporttype = 1 ) 
							OR (l.LeagueGroupID IN (122, 42) AND m.sporttype = 2 )
							OR (l.LeagueGroupID = 42 AND m.sporttype = 50)
							OR (l.LeagueGroupID = 151 AND m.sporttype = 43)
						) AND b.betdaqid <> -2 AND b.winlostdate >= SabaInfo_CutOffDate THEN l.LeagueGroupID 
					ELSE 0
				END AS LeagueGroupID, -- Saba Sports
				CASE
					WHEN s.ProductId = 1 AND s.EventType = 1 AND b.betdaqid = -2 THEN 1 -- Castout
					ELSE 0
				END AS TicketType,
				CASE
					WHEN b.winlostdate >= HWHLCutDate
						AND b.statusID IN (112, 113)
						AND b.modds IN (-0.25, 0.25)
						AND (b.bettype < 999
							OR b.bettype BETWEEN 1301 AND 1399
							OR b.bettype BETWEEN 9001 AND 9399
							OR b.bettype BETWEEN 9400 AND 9998
							OR b.bettype BETWEEN 3900 AND 3999)	-- Sportsbook
						AND b.bettype NOT IN (29, 38, 911, 912, 913, 914)  --- Parlay, betbuilder, Cashout
						AND b.bettype NOT BETWEEN 81 AND 120
						THEN CASE WHEN b.statusID = 112 THEN 114 ELSE 115 END
					WHEN b.winlostdate < HWHLCutDate
						AND b.statusID IN (112, 113)
						AND b.bettype IN (1, 3, 7, 8, 17, 18, 124, 125, 482, 483, 484, 485)
						AND ABS(b.modds) = 0.25
						THEN CASE WHEN b.statusID = 112 THEN 114 ELSE 115 END
					ELSE b.statusID
				END AS statusID,
				ISNULL(CASE WHEN b.bettype IN(9,29) THEN IIF(b.livehomescore=0,1,b.livehomescore) ELSE IIF(b.liveindicator=0, 1, 2) END, 0) AS liveindicator
		) AS ck
		
		
	WHERE b.winlostdate BETWEEN @FromDate AND @ToDate
		AND ',' + @StatusIDs + ',' LIKE '%,' + CAST(b.statusID AS VARCHAR(3)) + ',%'
		AND (@Betfroms IS NULL OR ',' + @Betfroms + ',' LIKE '%,' + b.betfrom + ',%')
		AND (@LiveIds IS NULL OR ',' + @LiveIds + ',' LIKE '%,' + CAST(ck.liveindicator AS VARCHAR(3)) + ',%')
		AND (@PlayerList IS NULL OR EXISTS (SELECT TOP 1 1 FROM CTE_Player pl WHERE pl.CustId = b.custid))
		AND (@SportIDs IS NULL OR  ',' + @SportIDs + ',' LIKE '%,' + CAST(ck.sporttype AS VARCHAR(3)) + ',%')

	GROUP BY b.[recommend]
		,b.[winlostdate]
		,s.ProductId
		,ck.sporttype
		,b.[bettype]
		,b.[custid]
		,b.[currency]
		,b.[betfrom]
		/*,ck.LeagueGroupID
		,ck.ticketType
		,ck.[statusID]
		,ck.IsBA
		,ck.liveindicator
		,b.apositiontaking*/



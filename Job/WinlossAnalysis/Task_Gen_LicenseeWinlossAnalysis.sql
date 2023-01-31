USE [bodb_LicenseeReport]
GO
/****** Object:  UserDefinedFunction [dbo].[f_LicenseeWinlossActive]    Script Date: 1/18/2023 3:57:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


--CREATE OR ALTER  VIEW [dbo].[view_LicenseeWinlossActive]
CREATE OR ALTER FUNCTION [dbo].[f_LicenseeWinlossActive] (@FromDate SMALLDATETIME, @ToDate SMALLDATETIME)
RETURNS TABLE
AS
RETURN
	WITH cteWLD AS (
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
		SELECT DISTINCT 
			--ISNULL(p.GroupProductId, tbl.ProductID) AS ProductID, 
			tbl.ProductID, tbl.BetType, tbl.RefTable, CASE WHEN tbl.RefTable IN (1,2) OR tbl.ProductID = 47 THEN 1 ELSE 0 END IsUsingOddsSpread
			--, ISNULL(f.Sporttype, 0) AS Sporttype, ISNULL(f.LeagueGroupID, 0) AS LeagueGroupID, ISNULL(f.TicketType, 0) AS TicketType
			, tbl.EventType
			, CASE WHEN cont.Bettype IS NOT NULL THEN 1 ELSE 0 END AS IsContributionBettype
		FROM bodb02.dbo.f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', '', 0) tbl
			--LEFT JOIN bodb02.dbo.f_GroupProduct() p ON P.ProductId = tbl.ProductID
			--LEFT JOIN bodb02.dbo.f_GetProductDetail() f ON f.ProductId = tbl.ProductID AND f.Bettype = tbl.BetType
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
		,ck.LeagueGroupID
		,ck.ticketType
		,b.[custid]
		,ck.[statusID]
		,b.[currency]
		,b.[betfrom]
		,ck.IsBA
		,ck.liveindicator
		,b.[apositiontaking]
		-----------------
		,SUM(ABS(b.[stake])) AS Turnover
		,SUM(CASE
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
		END) AS NetTurnover
		,SUM(b.[winlost] - b.[actual_stake]) AS MemWinloss
		,SUM(b.[awinlost]) AS [awinlost]
		,SUM(b.[mwinlost]) AS [mwinlost]
		,SUM(b.[swinlost]) AS [swinlost]
		,SUM(b.[playercomm]) AS [playercomm]
		,SUM(b.[comm]) AS [comm]
		,SUM(b.[acomm]) AS [acomm]
		,SUM(CASE
				WHEN b.statusID IN (112, 113) THEN 
					CASE
						WHEN (b.bettype IN (4300, 4299, 4298, 4297, 3007, 1906, 1698, 1699, 3150, 3898, 3899, 4599, 4600, 2499)
							OR (b.bettype BETWEEN 1611 AND 1697 AND b.matchid = 150)
							OR (b.bettype BETWEEN 3801 AND 3899 AND b.matchid = 173)
							OR (b.bettype BETWEEN 8700 AND 8709 AND b.matchid = 157)) THEN 0
						ELSE ABS(b.winlost - b.actual_stake)
					END -- exclude Promotion Prize, Tip ticket from BetEffective
				ELSE 0
			END) AS BetEffective
		,SUM(CASE
			--WHEN b.bettype = 18000 OR b.bettype BETWEEN 1401 AND 1499 THEN CONVERT(MONEY, ISNULL(IIF(ISNUMERIC(b.ExtraInfo)=1,b.ExtraInfo,0), 0)) -- Extra Amount For CB Free Play Ticket
			WHEN b.bettype BETWEEN 1401 AND 1499 THEN CONVERT(MONEY, IIF(ISNUMERIC(b.ExtraInfo)=1, b.ExtraInfo, 0)) -- poker games: gem & insurance
			WHEN b.bettype BETWEEN 81 AND 120 OR b.bettype BETWEEN 8101 AND 8120 THEN b.stake * (1 - b.tpositiontaking) -- House Turnover In NG WL
			WHEN b.bettype BETWEEN 5001 AND 5099 THEN b.actual_stake -- Net Turnover In Indo 4D
			ELSE 0 
		END) AS ExtraAmount
		--, MIN(b.winlostdate) OVER() AS Min_WLD, MAX(b.winlostdate) OVER() AS Max_WLD
	FROM [bodb02].[dbo].[bettrans] b with(nolock)
		INNER JOIN bodb02.dbo.Dep_CustSuper cs WITH(NOLOCK) on cs.custid = b.srecommend
		INNER JOIN sportBettype s ON s.bettype = b.bettype 
		LEFT JOIN [bodb02].dbo.match m WITH(NOLOCK) ON b.matchid = m.matchid
		LEFT JOIN [bodb02].dbo.League l WITH(NOLOCK) ON m.leagueid = l.leagueid AND l.LeagueGroupID IN (42,74,108,113,122,151)
		LEFT JOIN [bodb02].dbo.outright o WITH(NOLOCK) ON b.matchid = o.orid
		LEFT JOIN bodb02.dbo.League lo WITH (NOLOCK) ON lo.leagueid = o.leagueid
		LEFT JOIN [bodb02].dbo.VSRaceInfo vs WITH(NOLOCK) ON b.matchid = vs.EventID
		LEFT JOIN bodb_licensee.dbo.LicenseeBATransaction AS ba WITH (NOLOCK) ON b.transid = ba.transid
		CROSS APPLY cteWLD wld
		OUTER APPLY (
			SELECT 
				CASE 
					WHEN s.EventType = 1 THEN CAST(m.sporttype AS INT)
					WHEN s.EventType = 2 THEN CAST(lo.sporttype AS INT)
					WHEN s.EventType = 3 THEN CAST(vs.SportType AS INT)
					WHEN s.EventType = 0 THEN CASE WHEN b.matchid <> 2799 AND b.matchid = 29 THEN 0 ELSE b.matchid END
					ELSE 0 
				END AS sporttype
				,CASE 
					WHEN ((l.LeagueGroupID IN (42,74,108,113) AND m.sporttype = 1 ) 
							OR (l.LeagueGroupID IN (122, 42) AND m.sporttype = 2 )
							OR (l.LeagueGroupID = 42 AND m.sporttype = 50)
							OR (l.LeagueGroupID = 151 AND m.sporttype = 43)
						) AND b.betdaqid <> -2 AND b.winlostdate >= SabaInfo_CutOffDate THEN l.LeagueGroupID 
					ELSE 0
				END AS LeagueGroupID
				,CASE
					WHEN s.ProductId = 1 AND s.EventType = 1 AND b.betdaqid = -2 THEN 1
					ELSE 0
				END AS TicketType
				,CASE
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
				END AS statusID
				,IIF(ba.TransID IS NOT NULL, 1, 0) AS IsBA
				,ISNULL(CASE WHEN b.bettype IN(9,29) THEN b.livehomescore ELSE b.liveindicator END, 0) AS liveindicator
		) AS ck
		
		
	WHERE b.statusID IN (111, 112, 113)
		AND b.winlostdate BETWEEN @FromDate AND @ToDate
	GROUP BY b.[recommend]
		,b.[winlostdate]
		,s.ProductId
		,ck.sporttype
		,b.[bettype]
		,ck.LeagueGroupID
		,ck.ticketType
		,b.[custid]
		,ck.[statusID]
		,b.[currency]
		,b.[betfrom]
		,ck.IsBA
		,ck.liveindicator
		,b.apositiontaking



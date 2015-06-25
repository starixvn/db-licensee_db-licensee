USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_Rpt_CustomerTurnOver]    Script Date: 6/3/2015 4:25:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

 
ALTER PROCEDURE  [dbo].[Lrf_Rpt_CustomerTurnOver_Pagination]
(
	@searchCust 	BIT = 0
	,@FromDate 		SMALLDATETIME
	,@tempFromDate 	SMALLDATETIME
	,@ToDate 		SMALLDATETIME
	,@tempToDate 	SMALLDATETIME
	,@MoveBetsDay 	SMALLDATETIME
	,@Odds 			FLOAT
	,@ReportBy  	TINYINT   =  1 
	,@offsetRow 	INT
	,@maxRow		INT
	,@totalBettrans	INT = 0 OUTPUT
	,@totalSumRpt	INT = 0 OUTPUT
)
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @topRow INT 
	SET @topRow = (@maxRow - @offsetRow) + 1

	-- VIEW specific members
	IF( @searchCust = 1 )
	BEGIN
		IF( @totalBettrans = 0 -- no caching
			OR (
				@totalBettrans > 0
				AND (@offsetRow <= @totalBettrans)
			)
		)
		BEGIN
			IF ( @odds = 0 )
			BEGIN
				WITH CTE_Paging AS
				(
					SELECT 
						RowIdx = ROW_NUMBER() OVER ( ORDER BY 
												CASE WHEN @ReportBy =  2 THEN DATEADD(M, DATEDIFF(M, 0, b.winlostdate), 0)
													ELSE b.winlostdate
												END DESC
												, c.username
											)
						, CASE WHEN @ReportBy =  2 THEN DATEADD(M, DATEDIFF(M, 0, b.winlostdate), 0)
							ELSE b.winlostdate
						END as winlostdate
						, c.Custid
						, TotalRow = COUNT(1) OVER()
						
					FROM dbo.bettrans b WITH(NOLOCK)
						INNER JOIN #recommend rec 
						ON b.Recommend	= rec.CustID 
						INNER JOIN #tempCust  c
						ON b.custid 	= c.custid
						INNER JOIN #bettype bt
						ON b.bettype 	=  bt.typeid
						INNER JOIN #Status st
						ON b.StatusID 	=  st.StatusID
						--EventType =  1
						LEFT JOIN dbo.match m WITH (NOLOCK) 
						ON b.matchid 		= m.matchid
						AND bt.EventType 	= 1
						--EventType =  2
						LEFT JOIN dbo.outright o with(nolock) 
						ON b.matchid 		= o.orid 
						AND bt.EventType 	= 2
						LEFT JOIN dbo.league l with(nolock) 
						ON o.leagueid 		= l.leagueid
						--EventType =  3
						LEFT JOIN dbo.VSOutright  vs WITH (NOLOCK)
						ON b.oddsid			= vs.Orid
						AND bt.EventType 	= 3
						LEFT JOIN dbo.VSRaceInfo r WITH (NOLOCK) 
						ON vs.EventID  		= r.EventID
						LEFT JOIN #ProductID p 
						ON (
							bt.EventType	= 1 AND m.sporttype	= p.sportID
							OR bt.EventType = 2 AND l.sporttype	= p.sportID
							OR bt.EventType = 3 AND r.sporttype	= p.sportID
							OR bt.EventType = 0 AND 1			= p.sportID
						)

					WHERE b.winlostdate BETWEEN @tempFromDate AND @todate
						AND p.sportID > 0
						
					GROUP BY 
						CASE WHEN @ReportBy =  2 THEN DATEADD(M, DATEDIFF(M, 0, b.winlostdate), 0)
								ELSE b.winlostdate
							END
						, c.custid
						, c.username
				)
				INSERT INTO #tempCustPaging 
				SELECT TOP (@topRow) 
					p.RowIdx AS rowno
					, 1 AS whTicket
					, p.winlostdate
					, p.custid
					, p.TotalRow
				FROM CTE_Paging p
				WHERE p.RowIdx BETWEEN @offsetRow AND @maxRow
					OR (@totalBettrans = 0)	
				ORDER BY p.RowIdx ASC
				
			END
			-- Has Odds Value
			IF ( @odds > 0 )
			BEGIN
				WITH CTE_Paging AS
				(
					SELECT 
						RowIdx = ROW_NUMBER() OVER ( ORDER BY 
												CASE WHEN @ReportBy =  2 THEN DATEADD(M, DATEDIFF(M, 0, b.winlostdate), 0)
													ELSE b.winlostdate
												END DESC
												, c.username
											)
						, CASE WHEN @ReportBy =  2 THEN DATEADD(M, DATEDIFF(M, 0, b.winlostdate), 0)
							ELSE b.winlostdate
						END as winlostdate
						, c.Custid
						, TotalRow = COUNT(1) OVER()
						
					FROM dbo.bettrans b WITH(NOLOCK)
						INNER JOIN #recommend rec 
						ON b.Recommend	= rec.CustID 
						INNER JOIN #tempCust  c
						ON b.custid 	= c.custid
						INNER JOIN #bettype bt
						ON b.bettype 	=  bt.typeid
						INNER JOIN #Status st
						ON b.StatusID 	=  st.StatusID
						--EventType =  1
						LEFT JOIN dbo.match m WITH (NOLOCK) 
						ON b.matchid 		= m.matchid
						AND bt.EventType 	= 1
						--EventType =  2
						LEFT JOIN dbo.outright o with(nolock) 
						ON b.matchid 		= o.orid 
						AND bt.EventType 	= 2
						LEFT JOIN dbo.league l with(nolock) 
						ON o.leagueid 		= l.leagueid
						--EventType =  3
						LEFT JOIN dbo.VSOutright  vs WITH (NOLOCK)
						ON b.oddsid			= vs.Orid
						AND bt.EventType 	= 3
						LEFT JOIN dbo.VSRaceInfo r WITH (NOLOCK) 
						ON vs.EventID  		= r.EventID
						LEFT JOIN #ProductID p 
						ON (
							bt.EventType	= 1 AND m.sporttype	= p.sportID
							OR bt.EventType = 2 AND l.sporttype	= p.sportID
							OR bt.EventType = 3 AND r.sporttype	= p.sportID
							OR bt.EventType = 0 AND 1			= p.sportID
						)

					WHERE b.winlostdate BETWEEN @tempFromDate AND @todate
						AND p.sportID > 0
						AND CASE WHEN (b.bettype IN (1,2,3,7,12,8,20,21,1301,1303,1305,1306,1308,1311,1312,1316,1318,1324,153,154,155,156)	 -- add more Sportting Solution bettype 
										OR b.bettype BETWEEN 81 AND 88
										OR b.bettype BETWEEN 90 AND 120
										OR b.bettype IN (157,178,183,184,194,197,198,203,204,205) -- add more bettype BetRadar 
									)
									THEN 
											CASE WHEN b.OddsType = 1 THEN b.odds + 1 --decimal
													WHEN b.OddsType = 2 THEN b.Odds + 1 --hongkong to decimal
													WHEN b.OddsType IN (3,4) THEN --malay and indo to decimal
																		CASE 
																			WHEN b.odds < 0 THEN (1 -  cast(1 as float) / cast(b.odds AS float))
																			WHEN b.odds >=0 THEN (1 + b.odds) END
													WHEN OddsType = 5 THEN --american odds to decimal
																	CASE
																	WHEN (b.odds * 100) < 0 THEN (1- cast (1 AS float)/ cast (b.odds AS float))
																	WHEN (b.odds * 100) % 2 = 0 THEN 2
																	WHEN (b.odds * 100) > 0 THEN (1 + b.odds) END 
												END 
								ELSE b.Odds
							END >= @odds
						
					GROUP BY 
						CASE WHEN @ReportBy =  2 THEN DATEADD(M, DATEDIFF(M, 0, b.winlostdate), 0)
								ELSE b.winlostdate
							END
						, c.custid
						, c.username
				)
				INSERT INTO #tempCustPaging 
				SELECT TOP (@topRow) 
					p.RowIdx AS rowno
					, 1 AS whTicket
					, p.winlostdate
					, p.custid
					, p.TotalRow
				FROM CTE_Paging p
				WHERE p.RowIdx BETWEEN @offsetRow AND @maxRow
					OR (@totalBettrans = 0)
				ORDER BY p.RowIdx ASC
			END
			
			--SET totalBettrans
			SELECT TOP 1 @totalBettrans = TotalRow
			FROM #tempCustPaging p
			WHERE whTicket = 1
		END
		
		IF( @totalSumRpt = 0 -- no caching
			OR (
				@totalSumRpt > 0
				AND (@maxRow > @totalBettrans)
			)
		)
		BEGIN
			IF ( @odds = 0 )
			BEGIN
				WITH CTE_Paging AS 
				(
					SELECT 
						RowIdx = ROW_NUMBER() OVER ( ORDER BY 
												CASE WHEN @ReportBy =  2 THEN DATEADD(M, DATEDIFF(M, 0, b.winlostdate), 0)
													ELSE b.winlostdate
												END DESC
												, c.username
											) + @totalBettrans
						, CASE WHEN @ReportBy =  2 THEN DATEADD(M, DATEDIFF(M, 0, b.winlostdate), 0)
							ELSE b.winlostdate
						END as winlostdate
						, c.Custid
						, TotalRow = COUNT(1) OVER()
						
					FROM bodb_LicenseeReport.dbo.rptcustomerturnOver b WITH(NOLOCK)--, INDEX=CIX_winlostdate)
						INNER JOIN #recommend rec
						ON b.Recommend	= rec.CustID
						INNER JOIN #tempCust c
						ON b.custid 	= c.custid
						INNER JOIN #bettype bt
						ON b.bettype 	=  bt.typeid
						INNER JOIN #Status st
						ON b.StatusID 	=  st.StatusID
						INNER JOIN #ProductID p 
						ON CASE	WHEN b.bettype IN (9, 10, 29) THEN 1
								ELSE b.sporttype 
							END			= p.sportID
					WHERE b.winlostdate BETWEEN @fromdate AND @tempToDate
							
					GROUP BY 
						CASE WHEN @ReportBy =  2 THEN DATEADD(M, DATEDIFF(M, 0, b.winlostdate), 0)
								ELSE b.winlostdate
							END
						, c.custid
						, c.username
				)
				INSERT INTO #tempCustPaging 
				SELECT TOP (@topRow) 
					p.RowIdx AS rowno
					, 2 AS whTicket
					, p.winlostdate
					, p.custid
					, p.TotalRow
				FROM CTE_Paging p
				WHERE p.RowIdx BETWEEN @offsetRow AND @maxRow
					OR (@totalSumRpt = 0)
				ORDER BY p.RowIdx ASC
			END	
			-- Has Odds Value
			IF (@odds > 0)
			BEGIN
				WITH CTE_Paging AS
				(
					SELECT 
						RowIdx = ROW_NUMBER() OVER ( ORDER BY 
												CASE WHEN @ReportBy =  2 THEN DATEADD(M, DATEDIFF(M, 0, b.winlostdate), 0)
													ELSE b.winlostdate
												END DESC
												, c.username
											) + @totalBettrans
						, CASE WHEN @ReportBy =  2 THEN DATEADD(M, DATEDIFF(M, 0, b.winlostdate), 0)
							ELSE b.winlostdate
						END as winlostdate
						, c.Custid
						, TotalRow = COUNT(1) OVER()
						
					FROM bodb_LicenseeReport.dbo.rptcustomerturnOver b WITH(NOLOCK)--, INDEX=CIX_winlostdate)
						INNER JOIN #recommend rec
						ON b.Recommend	= rec.CustID
						INNER JOIN #tempCust c
						ON b.custid 	= c.custid
						INNER JOIN #bettype bt
						ON b.bettype 	=  bt.typeid
						INNER JOIN #Status st
						ON b.StatusID 	=  st.StatusID
						INNER JOIN #ProductID p 
						ON CASE	WHEN b.bettype IN (9, 10, 29) THEN 1
								ELSE b.sporttype 
							END			= p.sportID
					WHERE b.winlostdate BETWEEN @fromdate AND @tempToDate
						AND CASE WHEN (b.bettype IN (1,2,3,7,12,8,20,21,1301,1303,1305,1306,1308,1311,1312,1316,1318,1324,153,154,155,156)	 -- add more Sportting Solution bettype 
										OR b.bettype BETWEEN 81 AND 88
										OR b.bettype BETWEEN 90 AND 120
										OR b.bettype IN (157,178,183,184,194,197,198,203,204,205) -- add more bettype BetRadar 
									)
									THEN 
											CASE WHEN b.OddsType = 1 THEN b.odds + 1 --decimal
													WHEN b.OddsType = 2 THEN b.Odds + 1 --hongkong to decimal
													WHEN b.OddsType IN (3,4) THEN --malay and indo to decimal
																		CASE 
																			WHEN b.odds < 0 THEN (1 -  cast(1 as float) / cast(b.odds AS float))
																			WHEN b.odds >=0 THEN (1 + b.odds) END
													WHEN OddsType = 5 THEN --american odds to decimal
																	CASE
																	WHEN (b.odds * 100) < 0 THEN (1- cast (1 AS float)/ cast (b.odds AS float))
																	WHEN (b.odds * 100) % 2 = 0 THEN 2
																	WHEN (b.odds * 100) > 0 THEN (1 + b.odds) END 
												END 
								ELSE b.Odds
							END >= @odds
						
					GROUP BY 
						CASE WHEN @ReportBy =  2 THEN DATEADD(M, DATEDIFF(M, 0, b.winlostdate), 0)
								ELSE b.winlostdate
							END
						, c.custid
						, c.username
					
				)
				INSERT INTO #tempCustPaging 
				SELECT TOP (@topRow) 
					p.RowIdx AS rowno
					, 2 AS whTicket
					, p.winlostdate
					, p.custid
					, p.TotalRow
				FROM CTE_Paging p
				WHERE p.RowIdx BETWEEN @offsetRow AND @maxRow
					OR (@totalSumRpt = 0)
				ORDER BY p.RowIdx ASC
			END
			
			--SET totalSumRpt
			SELECT TOP 1 @totalSumRpt = TotalRow
			FROM #tempCustPaging p
			WHERE whTicket = 2
		END
	END

	-- VIEW all members
	IF (@searchCust = 0)
	BEGIN
		IF( @totalBettrans = 0 -- no caching
			OR (
				@totalBettrans > 0
				AND (@offsetRow <= @totalBettrans)
			)
		)
		BEGIN
			IF( @odds = 0 )
			BEGIN
				WITH CTE_Paging AS 
				(
					SELECT 
						RowIdx = ROW_NUMBER() OVER ( ORDER BY 
												CASE WHEN @ReportBy =  2 THEN DATEADD(M, DATEDIFF(M, 0, b.winlostdate), 0)
													ELSE b.winlostdate
												END DESC
												, ISNULL(SUBSTRING(c.username2,CHARINDEX ('$',c.username2,1)+1,LEN(c.username2)),c.username)
											)
						, CASE WHEN @ReportBy =  2 THEN DATEADD(M, DATEDIFF(M, 0, b.winlostdate), 0)
							ELSE b.winlostdate
						END as winlostdate
						, c.Custid
						, TotalRow = COUNT(1) OVER()
					FROM dbo.bettrans b WITH(NOLOCK)
						INNER JOIN #recommend rec 
						ON b.Recommend	= rec.CustID 
						INNER JOIN bodb_licensee.dbo.LicenseeCustinfo  c WITH (NOLOCK)
						ON b.custid 	= c.custid
						INNER JOIN #bettype bt
						ON b.bettype 	=  bt.typeid
						INNER JOIN #Status st
						ON b.StatusID 	=  st.StatusID
						--EventType =  1
						LEFT JOIN dbo.match m WITH (NOLOCK) 
						ON b.matchid 		= m.matchid
						AND bt.EventType 	= 1
						--EventType =  2
						LEFT JOIN dbo.outright o with(nolock) 
						ON b.matchid 		= o.orid 
						AND bt.EventType 	= 2
						LEFT JOIN dbo.league l with(nolock) 
						ON o.leagueid 		= l.leagueid
						--EventType =  3
						LEFT JOIN dbo.VSOutright  vs WITH (NOLOCK)
						ON b.oddsid			= vs.Orid
						AND bt.EventType 	= 3
						LEFT JOIN dbo.VSRaceInfo r WITH (NOLOCK) 
						ON vs.EventID  		= r.EventID
						LEFT JOIN #ProductID p 
						ON (
							bt.EventType	= 1 AND m.sporttype	= p.sportID
							OR bt.EventType = 2 AND l.sporttype	= p.sportID
							OR bt.EventType = 3 AND r.sporttype	= p.sportID
							OR bt.EventType = 0 AND 1			= p.sportID
						)

					WHERE b.winlostdate BETWEEN @tempFromDate AND @todate
						AND p.sportID IS NOT NULL
					
					GROUP BY
						CASE WHEN @ReportBy =  2 THEN DATEADD(M, DATEDIFF(M, 0, b.winlostdate), 0)
													ELSE b.winlostdate
												END
						, ISNULL(SUBSTRING(c.username2,CHARINDEX ('$',c.username2,1)+1,LEN(c.username2)),c.username)
						, c.custid
				)
				INSERT INTO #tempCustPaging 
				SELECT TOP (@topRow) 
					p.RowIdx AS rowno
					, 1 AS whTicket
					, p.winlostdate
					, p.custid
					, p.TotalRow
				FROM CTE_Paging p
				WHERE p.RowIdx BETWEEN @offsetRow AND @maxRow
					OR (@totalBettrans = 0)
				ORDER BY p.RowIdx ASC
			END
			
			-- Has Odds Value
			IF (@odds > 0)
			BEGIN
				WITH CTE_Paging AS 
				(
					SELECT 
						RowIdx = ROW_NUMBER() OVER ( ORDER BY 
												CASE WHEN @ReportBy =  2 THEN DATEADD(M, DATEDIFF(M, 0, b.winlostdate), 0)
													ELSE b.winlostdate
												END DESC
												, ISNULL(SUBSTRING(c.username2,CHARINDEX ('$',c.username2,1)+1,LEN(c.username2)),c.username)
											)
						, CASE WHEN @ReportBy =  2 THEN DATEADD(M, DATEDIFF(M, 0, b.winlostdate), 0)
							ELSE b.winlostdate
						END as winlostdate
						, c.Custid
						, TotalRow = COUNT(1) OVER()
					FROM dbo.bettrans b WITH(NOLOCK)
						INNER JOIN #recommend rec 
						ON b.Recommend	= rec.CustID 
						INNER JOIN bodb_licensee.dbo.LicenseeCustinfo  c WITH (NOLOCK)
						ON b.custid 	= c.custid
						INNER JOIN #bettype bt
						ON b.bettype 	=  bt.typeid
						INNER JOIN #Status st
						ON b.StatusID 	=  st.StatusID
						--EventType =  1
						LEFT JOIN dbo.match m WITH (NOLOCK) 
						ON b.matchid 		= m.matchid
						AND bt.EventType 	= 1
						--EventType =  2
						LEFT JOIN dbo.outright o with(nolock) 
						ON b.matchid 		= o.orid 
						AND bt.EventType 	= 2
						LEFT JOIN dbo.league l with(nolock) 
						ON o.leagueid 		= l.leagueid
						--EventType =  3
						LEFT JOIN dbo.VSOutright  vs WITH (NOLOCK)
						ON b.oddsid			= vs.Orid
						AND bt.EventType 	= 3
						LEFT JOIN dbo.VSRaceInfo r WITH (NOLOCK) 
						ON vs.EventID  		= r.EventID
						LEFT JOIN #ProductID p 
						ON (
							bt.EventType	= 1 AND m.sporttype	= p.sportID
							OR bt.EventType = 2 AND l.sporttype	= p.sportID
							OR bt.EventType = 3 AND r.sporttype	= p.sportID
							OR bt.EventType = 0 AND 1			= p.sportID
						)

					WHERE b.winlostdate BETWEEN @tempFromDate AND @todate
						AND p.sportID IS NOT NULL
						AND CASE WHEN (b.bettype IN (1,2,3,7,12,8,20,21,1301,1303,1305,1306,1308,1311,1312,1316,1318,1324,153,154,155,156)	 -- add more Sportting Solution bettype 
										OR b.bettype BETWEEN 81 AND 88
										OR b.bettype BETWEEN 90 AND 120
										OR b.bettype IN (157,178,183,184,194,197,198,203,204,205) -- add more bettype BetRadar 
									)
									THEN 
											CASE WHEN b.OddsType = 1 THEN b.odds + 1 --decimal
													WHEN b.OddsType = 2 THEN b.Odds + 1 --hongkong to decimal
													WHEN b.OddsType IN (3,4) THEN --malay and indo to decimal
																		CASE 
																			WHEN b.odds < 0 THEN (1 -  cast(1 as float) / cast(b.odds AS float))
																			WHEN b.odds >=0 THEN (1 + b.odds) END
													WHEN OddsType = 5 THEN --american odds to decimal
																	CASE
																	WHEN (b.odds * 100) < 0 THEN (1- cast (1 AS float)/ cast (b.odds AS float))
																	WHEN (b.odds * 100) % 2 = 0 THEN 2
																	WHEN (b.odds * 100) > 0 THEN (1 + b.odds) END 
												END 
								ELSE b.Odds
							END >= @odds
							
					GROUP BY
						CASE WHEN @ReportBy =  2 THEN DATEADD(M, DATEDIFF(M, 0, b.winlostdate), 0)
													ELSE b.winlostdate
												END
						, ISNULL(SUBSTRING(c.username2,CHARINDEX ('$',c.username2,1)+1,LEN(c.username2)),c.username)
						, c.custid
				)
				INSERT INTO #tempCustPaging 
				SELECT TOP (@topRow) 
					p.RowIdx AS rowno
					, 1 AS whTicket
					, p.winlostdate
					, p.custid
					, p.TotalRow
				FROM CTE_Paging p
				WHERE p.RowIdx BETWEEN @offsetRow AND @maxRow
					OR (@totalBettrans = 0)
				ORDER BY p.RowIdx ASC
			END
			-- SET totalBettrans
			SELECT TOP 1 @totalBettrans = TotalRow
			FROM #tempCustPaging p
			WHERE whticket = 1
		END	

		IF( @totalSumRpt = 0 -- no caching
			OR (
				@totalSumRpt > 0
				AND (@maxRow > @totalBettrans)
			)
		)
		BEGIN
			IF(@odds = 0)
			BEGIN
				WITH CTE_Paging AS 
				(
					SELECT 
						RowIdx = ROW_NUMBER() OVER ( ORDER BY 
												CASE WHEN @ReportBy =  2 THEN DATEADD(M, DATEDIFF(M, 0, b.winlostdate), 0)
													ELSE b.winlostdate
												END DESC
												, ISNULL(SUBSTRING(c.username2,CHARINDEX ('$',c.username2,1)+1,LEN(c.username2)),c.username)
											) + @totalBettrans
						, CASE WHEN @ReportBy =  2 THEN DATEADD(M, DATEDIFF(M, 0, b.winlostdate), 0)
							ELSE b.winlostdate
						END as winlostdate
						, c.Custid
						, TotalRow = COUNT(1) OVER()
					FROM bodb_LicenseeReport.dbo.rptcustomerturnOver b WITH(NOLOCK)--, INDEX=CIX_winlostdate)
						INNER JOIN #recommend rec
						ON b.Recommend	= rec.CustID
						INNER JOIN bodb_licensee.dbo.LicenseeCustinfo  c WITH (NOLOCK)
						ON b.custid 	= c.custid
						INNER JOIN #bettype bt
						ON b.bettype 	=  bt.typeid
						INNER JOIN #Status st
						ON b.StatusID 	=  st.StatusID
						INNER JOIN #ProductID p 
						ON CASE	WHEN b.bettype IN (9, 10, 29) THEN 1
								ELSE b.sporttype 
							END			= p.sportID
					WHERE b.winlostdate BETWEEN @fromdate AND @tempToDate
						
					GROUP BY 
						CASE WHEN @ReportBy =  2 THEN DATEADD(M, DATEDIFF(M, 0, b.winlostdate), 0)
								ELSE b.winlostdate
							END
						, ISNULL(SUBSTRING(c.username2,CHARINDEX ('$',c.username2,1)+1,LEN(c.username2)),c.username)
						, c.custid
				)
				INSERT INTO #tempCustPaging 
				SELECT TOP (@topRow) 
					p.RowIdx AS rowno
					, 2 AS whTicket
					, p.winlostdate
					, p.custid
					, p.TotalRow
				FROM CTE_Paging p
				WHERE (p.RowIdx BETWEEN @offsetRow AND @maxRow)
					OR (@totalSumRpt = 0)
				ORDER BY p.RowIdx ASC
			END
			-- Has Odds Value
			IF ( @odds > 0 )
			BEGIN
				WITH CTE_Paging AS 
				(	
					SELECT 
						RowIdx = ROW_NUMBER() OVER ( ORDER BY 
												CASE WHEN @ReportBy =  2 THEN DATEADD(M, DATEDIFF(M, 0, b.winlostdate), 0)
													ELSE b.winlostdate
												END DESC
												, ISNULL(SUBSTRING(c.username2,CHARINDEX ('$',c.username2,1)+1,LEN(c.username2)),c.username)
											) + @totalBettrans
						, CASE WHEN @ReportBy =  2 THEN DATEADD(M, DATEDIFF(M, 0, b.winlostdate), 0)
							ELSE b.winlostdate
						END as winlostdate
						, c.Custid
						, TotalRow = COUNT(1) OVER()
					FROM bodb_LicenseeReport.dbo.rptcustomerturnOver b WITH(NOLOCK)--, INDEX=CIX_winlostdate)
						INNER JOIN #recommend rec
						ON b.Recommend	= rec.CustID
						INNER JOIN bodb_licensee.dbo.LicenseeCustinfo  c WITH (NOLOCK)
						ON b.custid 	= c.custid
						INNER JOIN #bettype bt
						ON b.bettype 	=  bt.typeid
						INNER JOIN #Status st
						ON b.StatusID 	=  st.StatusID
						INNER JOIN #ProductID p 
						ON CASE	WHEN b.bettype IN (9, 10, 29) THEN 1
								ELSE b.sporttype 
							END			= p.sportID
					WHERE b.winlostdate BETWEEN @fromdate AND @tempToDate
						AND @odds > 0 
						AND CASE WHEN (b.bettype IN (1,2,3,7,12,8,20,21,1301,1303,1305,1306,1308,1311,1312,1316,1318,1324,153,154,155,156)	 -- add more Sportting Solution bettype 
										OR b.bettype BETWEEN 81 AND 88
										OR b.bettype BETWEEN 90 AND 120
										OR b.bettype IN (157,178,183,184,194,197,198,203,204,205) -- add more bettype BetRadar 
										)
										THEN 
												CASE WHEN b.OddsType = 1 THEN b.odds + 1 --decimal
														WHEN b.OddsType = 2 THEN b.Odds + 1 --hongkong to decimal
														WHEN b.OddsType IN (3,4) THEN --malay and indo to decimal
																			CASE 
																				WHEN b.odds < 0 THEN (1 -  cast(1 as float) / cast(b.odds AS float))
																				WHEN b.odds >=0 THEN (1 + b.odds) END
														WHEN OddsType = 5 THEN --american odds to decimal
																		CASE
																		WHEN (b.odds * 100) < 0 THEN (1- cast (1 AS float)/ cast (b.odds AS float))
																		WHEN (b.odds * 100) % 2 = 0 THEN 2
																		WHEN (b.odds * 100) > 0 THEN (1 + b.odds) END 
													END 
									ELSE b.Odds
								END >= @odds
						
					GROUP BY 
						CASE WHEN @ReportBy =  2 THEN DATEADD(M, DATEDIFF(M, 0, b.winlostdate), 0)
								ELSE b.winlostdate
							END
						, ISNULL(SUBSTRING(c.username2,CHARINDEX ('$',c.username2,1)+1,LEN(c.username2)),c.username)
						, c.custid
				)
				INSERT INTO #tempCustPaging 
				SELECT TOP (@topRow) 
					p.RowIdx AS rowno
					, 2 AS whTicket
					, p.winlostdate
					, p.custid
					, p.TotalRow
				FROM CTE_Paging p
				WHERE (p.RowIdx BETWEEN @offsetRow AND @maxRow)
					OR (@totalSumRpt = 0)
				ORDER BY p.RowIdx ASC
			END
			-- SET totalSumRpt
			SELECT TOP 1 @totalSumRpt = TotalRow
			FROM #tempCustPaging p
			WHERE whTicket = 2
		END
	END
	-- Reset paging
	DELETE p
	FROM #tempCustPaging p
	WHERE (p.rowno < @offsetRow OR p.rowno > @maxRow)
	RETURN;
END
GO 
GRANT EXECUTE ON [dbo].[Lrf_Rpt_CustomerTurnOver_Pagination] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_CustomerTurnOver_Pagination] TO [vnteam] 
GO
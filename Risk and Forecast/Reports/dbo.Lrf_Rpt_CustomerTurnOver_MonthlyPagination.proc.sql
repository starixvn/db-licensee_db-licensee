USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_Rpt_CustomerTurnOver]    Script Date: 6/3/2015 4:25:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

 
CREATE PROCEDURE  [dbo].[Lrf_Rpt_CustomerTurnOver_MonthlyPagination]
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
WITH RECOMPILE
AS
/*
Revision:
- 20150623@Winnie: exclude 3 transactions SOLD/BOUGHT/BetTrade Commission
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @topRow INT 
	CREATE TABLE #tempPaging 
	(
		winlostdate	SMALLDATETIME
		,custid			INT
		--,TotalRow		INT
		,whticket		TINYINT
	)
	
	SET @topRow = (@maxRow - @offsetRow) + 1

	-- VIEW specific members
	IF( @searchCust = 1 )
	BEGIN
		IF( @ToDate > @MoveBetsDay )
		BEGIN
			WITH CTE_Paging AS
			(
				SELECT 
					DATEADD(M, DATEDIFF(M, 0, b.winlostdate), 0) AS winlostdate
					, b.custid
					--, TotalRow = COUNT(1) OVER()
					
				FROM #tempBettrans b	
					
				GROUP BY 
					DATEADD(M, DATEDIFF(M, 0, b.winlostdate), 0)
					, b.custid
			)
			INSERT INTO #tempPaging
			SELECT p.*
				,1 AS whticket
			FROM CTE_Paging p			
		END
		
		IF( @FromDate <= @MoveBetsDay )
		BEGIN
			IF ( @odds = 0 )
			BEGIN
				WITH CTE_Paging AS 
				(
					SELECT 
						DATEADD(M, DATEDIFF(M, 0, b.winlostdate), 0) as winlostdate
						, b.custid
						--, TotalRow = COUNT(1) OVER()
						
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
						--LEFT JOIN #tempPaging tp
						--ON b.custid = tp.custid AND tp.winlostdate = DATEADD(M, DATEDIFF(M, 0, b.winlostdate), 0)
						
					WHERE b.winlostdate BETWEEN @fromdate AND @tempToDate
							AND b.bettype NOT IN (901,902,903)
						--AND tp.custid IS NULL
							
					GROUP BY 
						DATEADD(M, DATEDIFF(M, 0, b.winlostdate), 0)
						, b.custid
				)
				INSERT INTO #tempPaging
				SELECT p.*
					,2 AS whticket
				FROM CTE_Paging p
				
				OPTION (RECOMPILE)
			END	
			
			-- Has Odds Value
			IF (@odds > 0)
			BEGIN
				WITH CTE_Paging AS
				(
					SELECT 
						DATEADD(M, DATEDIFF(M, 0, b.winlostdate), 0) as winlostdate
						, b.custid
						--, TotalRow = COUNT(1) OVER()
						
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
						--LEFT JOIN #tempPaging tp
						--ON b.custid = tp.custid AND tp.winlostdate = DATEADD(M, DATEDIFF(M, 0, b.winlostdate), 0)
						
					WHERE b.winlostdate BETWEEN @fromdate AND @tempToDate
						AND b.bettype NOT IN (901,902,903)
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
						--AND tp.custid IS NULL
						
					GROUP BY 
						DATEADD(M, DATEDIFF(M, 0, b.winlostdate), 0)
						, b.custid
					
				)
				INSERT INTO #tempPaging
				SELECT p.*
					,2 AS whticket
				FROM CTE_Paging p
				
				OPTION (RECOMPILE)
			END
		END
	END 
	--END searchCust = 1

	-- VIEW all members
	IF (@searchCust = 0)
	BEGIN
		IF( @ToDate > @MoveBetsDay )
		BEGIN
			WITH CTE_Paging AS 
			(
				SELECT 
					DATEADD(M, DATEDIFF(M, 0, b.winlostdate), 0) AS winlostdate
					, b.custid
					--, TotalRow = COUNT(1) OVER()
					
				FROM #tempBettrans b	
				
				GROUP BY
					DATEADD(M, DATEDIFF(M, 0, b.winlostdate), 0)
					, b.custid
			)
			INSERT INTO #tempPaging
			SELECT p.*
				,1 AS whticket
			FROM CTE_Paging p
		END	

		IF( @FromDate <= @MoveBetsDay )
		BEGIN
			IF(@odds = 0)
			BEGIN
				WITH CTE_Paging AS 
				(
					SELECT 
						DATEADD(M, DATEDIFF(M, 0, b.winlostdate), 0) AS winlostdate
						, b.custid
						--, TotalRow = COUNT(1) OVER()
						
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
							
						--LEFT JOIN #tempPaging tp
						--ON b.custid = tp.custid AND tp.winlostdate = DATEADD(M, DATEDIFF(M, 0, b.winlostdate), 0)
						
					WHERE b.winlostdate BETWEEN @fromdate AND @tempToDate
						AND b.bettype NOT IN (901,902,903)
						--AND tp.custid IS NULL
						
					GROUP BY 
						DATEADD(M, DATEDIFF(M, 0, b.winlostdate), 0)
						, b.custid
				)
				INSERT INTO #tempPaging
				SELECT p.*
					,2 AS whticket
				FROM CTE_Paging p
				
				OPTION (RECOMPILE)
			END
			-- Has Odds Value
			IF ( @odds > 0 )
			BEGIN
				WITH CTE_Paging AS 
				(	
					SELECT 
						DATEADD(M, DATEDIFF(M, 0, b.winlostdate), 0) AS winlostdate
						, b.custid
						--, TotalRow = COUNT(1) OVER()
						
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
						--LEFT JOIN #tempPaging tp
						--ON b.custid = tp.custid AND tp.winlostdate = DATEADD(M, DATEDIFF(M, 0, b.winlostdate), 0)
						
					WHERE b.winlostdate BETWEEN @fromdate AND @tempToDate
						AND b.bettype NOT IN (901,902,903)
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
						--AND tp.custid IS NULL
						
					GROUP BY 
						DATEADD(M, DATEDIFF(M, 0, b.winlostdate), 0)
						, b.custid
				)
				INSERT INTO #tempPaging
				SELECT p.*
					,2 AS whticket
				FROM CTE_Paging p
				
				OPTION (RECOMPILE)
			END
			
		END
	END
	--CREATE INDEXERS
	CREATE CLUSTERED INDEX [CIX_tempPaging] ON #tempPaging (custid, winlostdate, whticket)		
	
	--REMOVE duplicate rows
	DELETE p
	FROM #tempPaging p
		LEFT JOIN #tempPaging t ON p.custid = t.custid AND p.winlostdate = t.winlostdate AND t.whticket = 1
	WHERE p.whticket = 2
		AND t.custid > 0
	
	--GET paging item
	;WITH CTE_MixPaging AS 
	(
		SELECT RowIdx = ROW_NUMBER() OVER ( ORDER BY 
							t.winlostdate DESC
							, ISNULL(SUBSTRING(c.username2,CHARINDEX ('$',c.username2,1)+1,LEN(c.username2)),c.username)
						)
			, t.winlostdate
			, t.Custid 		
			, t.whticket
			
		FROM #tempPaging t
			INNER JOIN bodb_licensee.dbo.LicenseeCustinfo  c WITH (NOLOCK)
			ON t.custid = c.custid
			
		GROUP BY 
			t.winlostdate
			, ISNULL(SUBSTRING(c.username2,CHARINDEX ('$',c.username2,1)+1,LEN(c.username2)),c.username)
			, t.Custid
			, t.whticket			
	)
	,CTE_TotalRow AS
	(
		SELECT t.whticket
			, COUNT(1) AS TotalRow
		FROM CTE_MixPaging t
		GROUP BY t.whticket
	)
	INSERT INTO #tempCustPaging 
	SELECT TOP (@topRow) 
		p.RowIdx AS rowno
		, p.whTicket
		, p.winlostdate
		, p.custid
		, t.TotalRow
	FROM CTE_MixPaging p
		INNER JOIN CTE_TotalRow t ON p.whticket = t.whticket
	WHERE p.RowIdx BETWEEN @offsetRow AND @maxRow

	UNION ALL -- just get sum totalrow
	SELECT TOP (1) 
		0 AS rowno
		, p.whTicket
		, p.winlostdate
		, p.custid
		, t.TotalRow
	FROM CTE_MixPaging p
		INNER JOIN CTE_TotalRow t ON p.whticket = t.whticket
	WHERE @totalBettrans = 0 AND p.whTicket = 1
	
	UNION ALL -- just get sum totalrow
	SELECT TOP (1) 
		0 AS rowno
		, p.whTicket
		, p.winlostdate
		, p.custid
		, t.TotalRow
	FROM CTE_MixPaging p
		INNER JOIN CTE_TotalRow t ON p.whticket = t.whticket
	WHERE @totalSumRpt = 0 AND p.whTicket = 2
	
	OPTION (RECOMPILE);
	
	-- SET totalBettrans
	SELECT TOP(1) @totalBettrans = TotalRow
	FROM #tempCustPaging p
	WHERE whticket = 1 AND rowno = 0
	
	-- SET totalSumRpt
	SELECT TOP(1) @totalSumRpt = TotalRow
	FROM #tempCustPaging p
	WHERE whticket = 2 AND rowno = 0
		
	-- Reset paging
	DELETE p
	FROM #tempCustPaging p
	WHERE (p.rowno < @offsetRow OR p.rowno > @maxRow)
	
	DROP TABLE #tempPaging;

	RETURN;
END
GO 
GRANT EXECUTE ON [dbo].[Lrf_Rpt_CustomerTurnOver_MonthlyPagination] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_CustomerTurnOver_MonthlyPagination] TO [vnteam] 
GO
/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="1"></info>*/
USE [bodb02]
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
	,@PageSize 		INT
	,@PageIndex 	INT
	,@IsExportExcel BIT
	,@totalBettrans	INT = 0 OUTPUT
	,@totalSumRpt	INT = 0 OUTPUT
) 
WITH RECOMPILE
AS
/*	
Created: 20150603@Bobby
Task: Customer Performance Report
DB: DBEXT/BODB02
Revision:
	- 20151127@Bobby: #48081 - Apply PH-AIO new bettypes
	- 20160720@Jim : Implement 67 new bet types (PH All in one - Phase 2) [Redmine : #53520]
	- 20171006@Percy: Hotfix - Add missing mutilple odds bettypes [RedmineID: #84457]
		1. Basketball (603-607, 609-613, 615-617)
		2. Virtual Sports 2 (2701-2707)
	- 20180129@Percy: Hotfix page size, page index [RedmineID: #90104]
	- 20180409@Joseph: Implement new sports for VS2: BasketBall - Virual Soccer World Cup [Redmine: #90881]
	- 20180810@Joseph: Remove table LicenseeCustInfo [RedmineID: #99464]

Parameter's Explanation:
			
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @offsetRow INT, @maxRow INT, @topRow INT 
	
	SELECT
		@offsetRow = (((@PageIndex - 1) * @PageSize) + 1)
	   ,@maxRow = (@PageSize * @PageIndex)

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
			WITH CTE_Paging AS
			(
				SELECT 
					RowIdx = ROW_NUMBER() OVER ( ORDER BY 
											b.winlostdate DESC
											, c.username
										)
					, b.winlostdate
					, c.Custid
					, TotalRow = COUNT(1) OVER()
					
				FROM #tempBettrans b	
					INNER JOIN #recommend rec 
					ON b.Recommend	= rec.CustID 
					INNER JOIN #tempCust  c
					ON b.custid 	= c.custid
					
				GROUP BY 
					b.winlostdate
					, c.custid
					, c.username
			)
			INSERT INTO #tempCustPaging 
			SELECT
				p.RowIdx AS rowno
				, 1 AS whTicket
				, p.winlostdate
				, p.custid
				, p.TotalRow
			FROM CTE_Paging p
			WHERE (p.RowIdx BETWEEN @offsetRow AND @maxRow)
				OR (@totalBettrans = 0 AND p.RowIdx = 1)
				OR @IsExportExcel = 1

			OPTION (RECOMPILE)
			
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
												b.winlostdate DESC
												, c.username
											) + ISNULL(@totalBettrans,0)
						, b.winlostdate
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
						b.winlostdate
						, c.custid
						, c.username
				)
				INSERT INTO #tempCustPaging 
				SELECT
					p.RowIdx AS rowno
					, 2 AS whTicket
					, p.winlostdate
					, p.custid
					, p.TotalRow
				FROM CTE_Paging p
				WHERE (p.RowIdx BETWEEN @offsetRow AND @maxRow)
					OR ( @totalSumRpt = 0 AND p.RowIdx = (@totalBettrans+ 1))
					OR @IsExportExcel = 1
				
				OPTION (RECOMPILE)
			END	
			-- Has Odds Value
			IF (@odds > 0)
			BEGIN
				WITH CTE_Paging AS
				(
					SELECT 
						RowIdx = ROW_NUMBER() OVER ( ORDER BY 
												b.winlostdate DESC
												, c.username
											) + ISNULL(@totalBettrans,0)
						, b.winlostdate
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
										OR b.bettype BETWEEN 401 AND 404 -- add more PH-AIO new bettypes
										OR b.bettype = 428 -- 2H Odd/Even
										OR (bettype BETWEEN 603 AND 607 OR bettype BETWEEN 609 AND 613 OR bettype BETWEEN 615 AND 617) -- Basketball bettypes
										OR bettype BETWEEN 2701 AND 2707 -- Virtual Sport 2
										OR bettype BETWEEN 2800 AND 2829 -- Virtual Sport 2: basketball
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
						b.winlostdate
						, c.custid
						, c.username
					
				)
				INSERT INTO #tempCustPaging 
				SELECT
					p.RowIdx AS rowno
					, 2 AS whTicket
					, p.winlostdate
					, p.custid
					, p.TotalRow
				FROM CTE_Paging p
				WHERE (p.RowIdx BETWEEN @offsetRow AND @maxRow)
					OR ( @totalSumRpt = 0 AND p.RowIdx = (@totalBettrans+ 1))
					OR @IsExportExcel = 1
				
				OPTION (RECOMPILE)
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
			WITH CTE_Paging AS 
			(
				SELECT 
					RowIdx = ROW_NUMBER() OVER ( ORDER BY 
											b.winlostdate DESC
											, ISNULL(SUBSTRING(c.username2,CHARINDEX ('$',c.username2,1)+1,LEN(c.username2)),c.username)
										)
					, b.winlostdate
					, c.Custid
					, TotalRow = COUNT(1) OVER()
				FROM #tempBettrans b	
					INNER JOIN #recommend rec 
					ON b.Recommend	= rec.CustID 
					INNER JOIN Customer  c WITH (NOLOCK)
					ON b.custid 	= c.custid
				
				GROUP BY
					b.winlostdate
					, ISNULL(SUBSTRING(c.username2,CHARINDEX ('$',c.username2,1)+1,LEN(c.username2)),c.username)
					, c.custid
			)
			INSERT INTO #tempCustPaging 
			SELECT
				p.RowIdx AS rowno
				, 1 AS whTicket
				, p.winlostdate
				, p.custid
				, p.TotalRow
			FROM CTE_Paging p
			WHERE (p.RowIdx BETWEEN @offsetRow AND @maxRow)
				OR (@totalBettrans = 0 AND p.RowIdx = 1)
				OR @IsExportExcel = 1
			
			OPTION (RECOMPILE)
			
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
												b.winlostdate DESC
												, ISNULL(SUBSTRING(c.username2,CHARINDEX ('$',c.username2,1)+1,LEN(c.username2)),c.username)
											) + ISNULL(@totalBettrans,0)
						, b.winlostdate
						, c.Custid
						, TotalRow = COUNT(1) OVER()
					FROM bodb_LicenseeReport.dbo.rptcustomerturnOver b WITH(NOLOCK)--, INDEX=CIX_winlostdate)
						INNER JOIN #recommend rec
						ON b.Recommend	= rec.CustID
						INNER JOIN Customer  c WITH (NOLOCK)
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
						b.winlostdate
						, ISNULL(SUBSTRING(c.username2,CHARINDEX ('$',c.username2,1)+1,LEN(c.username2)),c.username)
						, c.custid
				)
				INSERT INTO #tempCustPaging 
				SELECT
					p.RowIdx AS rowno
					, 2 AS whTicket
					, p.winlostdate
					, p.custid
					, p.TotalRow
				FROM CTE_Paging p
				WHERE (p.RowIdx BETWEEN @offsetRow AND @maxRow )
					OR ( @totalSumRpt = 0 AND p.RowIdx = (@totalBettrans+ 1))
					OR @IsExportExcel = 1
				
				OPTION (RECOMPILE)
			END
			
			-- Has Odds Value
			IF ( @odds > 0 )
			BEGIN
				WITH CTE_Paging AS 
				(	
					SELECT 
						RowIdx = ROW_NUMBER() OVER ( ORDER BY 
												b.winlostdate DESC
												, ISNULL(SUBSTRING(c.username2,CHARINDEX ('$',c.username2,1)+1,LEN(c.username2)),c.username)
											) + ISNULL(@totalBettrans,0)
						, b.winlostdate
						, c.Custid
						, TotalRow = COUNT(1) OVER()
					FROM bodb_LicenseeReport.dbo.rptcustomerturnOver b WITH(NOLOCK)--, INDEX=CIX_winlostdate)
						INNER JOIN #recommend rec
						ON b.Recommend	= rec.CustID
						INNER JOIN Customer  c WITH (NOLOCK)
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
										OR b.bettype BETWEEN 401 AND 404 -- add more PH-AIO new bettypes
										OR b.bettype = 428 -- 2H Odd/Even
										OR (bettype BETWEEN 603 AND 607 OR bettype BETWEEN 609 AND 613 OR bettype BETWEEN 615 AND 617) -- Basketball bettypes
										OR bettype BETWEEN 2701 AND 2707 -- Virtual Sport 2
										OR bettype BETWEEN 2800 AND 2829 -- Virtual Sport 2: basketball
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
						b.winlostdate
						, ISNULL(SUBSTRING(c.username2,CHARINDEX ('$',c.username2,1)+1,LEN(c.username2)),c.username)
						, c.custid
				)
				INSERT INTO #tempCustPaging 
				SELECT
					p.RowIdx AS rowno
					, 2 AS whTicket
					, p.winlostdate
					, p.custid
					, p.TotalRow
				FROM CTE_Paging p
				WHERE (p.RowIdx BETWEEN @offsetRow AND @maxRow )
					OR ( @totalSumRpt = 0 AND p.RowIdx = (@totalBettrans+ 1))
					OR @IsExportExcel = 1
				
				OPTION (RECOMPILE)
			END
			-- SET totalSumRpt
			SELECT TOP 1 @totalSumRpt = TotalRow
			FROM #tempCustPaging p
			WHERE whTicket = 2
		END
	END
	-- Reset paging
	IF @IsExportExcel = 0
		DELETE p
		FROM #tempCustPaging p
		WHERE (p.rowno < @offsetRow OR p.rowno > @maxRow)

	RETURN;
END
GO
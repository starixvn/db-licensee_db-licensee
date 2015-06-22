USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_Rpt_CustomerTurnOver]    Script Date: 6/3/2015 4:25:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

 
ALTER PROCEDURE  [dbo].[Lrf_Rpt_CustomerTurnOver]
	@LicenseeID 	INT
	,@UserID  		INT
	,@Username 		VARCHAR(50) =  '' 
	,@Product  		VARCHAR(MAX) 
	,@Bettype  		VARCHAR(MAX)
	,@CurrencyID 	INT
	,@FromDate 		SMALLDATETIME
	,@ToDate 		SMALLDATETIME
	,@Odds 			FLOAT
	,@ReportBy  	TINYINT   =  1 
	,@MoveBetsDay 	SMALLDATETIME
	,@BalanceUpDay 	SMALLDATETIME
	,@Langkey 		NVARCHAR(10) =  'en-US'
	,@PageSize 		INT =  1000
	,@PageIndex 	INT =  1
	,@IsExportExcel BIT =  0
	,@ShowWin 		BIT =  1
	,@ShowLoss 		BIT =  1
	,@ShowDraw 		BIT =  1
	,@Duration		INT	=  0 OUTPUT
AS
/*	
Created	: Henry
Task: Customer Performance Report
Date: 2011-12-28
DB: DBEXT/BODB02
Original: Lrf_Rpt_CustomerPerformance
Revision:
	- 20120214@Henry: Seperate 3 options: Win/Loss/Draw (and all)
	- 20120801@Jim: add PlayerComm value 
	- 20130124@Daniel: Change link server alias
	- 20130618@Jim:  Restrict permission of Licensee Users by currency
	- 20131021@Jim: Add more products to Customer Turnover Report
	- 20131130@Florent: turning SP
	- 20131205@Florent: add more product and search LIKE customer
	- 20131225@Florent: Remove using bettrans14, use only bettrans and rptCustomerturnover
	- 20140104@Don: Improve performance -> Replacing table @Status with #Status
	- 20140120@Florent: using index Non clusered IX_recommend for table rptCustomerturnover
	- 20140212@Florent : Sorting DESC
	- 20140716@Jim: fix bug Total row in excel file is incorrect (hotfix #19101)
	- 20141017@Jim : Apply for the change in Sporting Solution structure (#24478)
	- 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
	- 20141203@Jim : fix issue cannot query data when pass a User belong to CNY Currency (hot fix #27017)
	- 20141204@Jim : hot fix #27063
	- 20150415@Jim: support betradar phase 2
	- 20150528@Jim: add more bettype Betradar and Sporting solution (for support multiple oddstype)
	- 20150603@Bobby: Revise code & improve performance
	- 20150618@Bobby: Apply pre-caching sumtotal from rptcustomerturnOver table
	
Parameter's Explanation:
	- @ReportBy:  1: daily, 2: monthly
	- @FilterBy:  1: Win, 2: Loss, 3: Draw
	- @SportID   : Sport type ID  
	- @bettype   : Bet type ID  
	- @MoveBetsDay: The day we move tickets to bettrans14
	- @BalanceUpDay: The day we move tickets to bettrans_bk	
			
*/
BEGIN

	SET NOCOUNT ON
	
	DECLARE @startTime		DATETIME
		, @tempFromDate 	SMALLDATETIME
		, @tempToDate 		SMALLDATETIME
		, @TotalRows		INT
		, @currencyName 	VARCHAR(10)
		, @searchCust		BIT
		, @totalBettrans	INT
		, @totalSumRpt		INT
		, @rptCode			VARCHAR(MAX)
		, @rptHash			VARBINARY(128)
	
	--SET start time value
	SET @startTime 			= GETDATE()
	
	CREATE TABLE #custData
	(
		rowno				INT
		, winlostdate 		DATE
		, custid 			INT
		, username			NVARCHAR(50)
		, currency			INT
		, sporttype			INT
		, bettype			INT
		, betcount 			INT
		, turnover			MONEY
		, winlost			MONEY
		, playercomm		MONEY
	)
	
	CREATE TABLE #tempCust 
	(
		custid			INT
	)
	
	CREATE TABLE #tempCustRec 
	(
		rowno			INT
		, whticket		TINYINT
		, winlostdate	DATETIME
		, custid		INT
		, username		NVARCHAR(30)
	)
	
	-- CREATE temp caching table
	IF ( OBJECT_ID('tempdb..##tempLRFCustTORpt') IS NULL )
	BEGIN
		CREATE TABLE ##tempLRFCustTORpt
		(
			whticket		TINYINT
			, betcount		INT
			, turnover		MONEY
			, winlost		MONEY
			, playercomm	MONEY
			, totalrow		INT
			, rptHash		VARBINARY(128)
			, rptVer		INT IDENTITY(1,1)
		)
		CREATE CLUSTERED INDEX [CIX_tempCustTORpt] ON ##tempLRFCustTORpt (rptHash, whticket)
	END
	
	CREATE TABLE #tempSumTotal 
	(
		whticket		TINYINT
		, betcount		INT
		, turnover		MONEY
		, winlost		MONEY
		, playercomm	MONEY
		, totalrow		INT
	)
	
	SELECT VAL AS sportId 
	INTO #ProductID 
	FROM dbo.strSplit(@Product,',')
	
	IF  NOT EXISTS (SELECT TOP 1 1  FROM #ProductID )
	BEGIN 
		RETURN;
	END 
	
	SELECT st AS StatusID
	INTO #Status
	FROM (
		----@ShowWin
		SELECT 112 AS st, 1 AS sh
		UNION ALL
		SELECT 114 AS st, 1 AS sh
		--@ShowLoss
		UNION ALL
		SELECT 113 AS st, 2 AS sh
		UNION ALL
		SELECT 115 AS st, 2 AS sh
		--@@ShowDraw
		UNION ALL
		SELECT 111 AS st, 3 AS sh
	) t
	WHERE (@ShowWin		= 1 AND sh = 1)
		OR (@ShowLoss	= 1 AND sh = 2)
		OR (@ShowDraw	= 1 AND sh = 3)
	
	-- bettype
	DECLARE @SportBettype TABLE(ProductID INT, Bettype INT,EventType INT)
	INSERT INTO @SportBettype
	EXEC bodb02.dbo.Acc_SportBettypeMatrix_Sel @mode=4
	
	SELECT VAL AS typeID
	INTO #BettypeID
	FROM dbo.strSplit(@Bettype,',') AS b

	INSERT INTO #BettypeID
	SELECT ss.bettype AS typeID
	FROM dbo.f_GroupBettype() ss
		INNER JOIN #BettypeID b 
		ON b.typeid 	=  ss.GroupTypeId
	WHERE ss.bettype NOT IN (SELECT typeID FROM #BettypeID)	

	
	SELECT 
		bt.typeID
		, sp.ProductId
		, sp.EventType
	INTO #bettype	
	FROM #BettypeID bt 
		INNER JOIN @SportBettype sp 
		ON bt.typeid 	=  sp.bettype
		
	DROP TABLE #BettypeID
		
	SELECT 
		lc.CustID
		,lc.Currency
	INTO #recommend	
	FROM bodb_licensee.dbo.f_SelLicenseeCust (@LicenseeID) lc  
		INNER JOIN bodb_licensee.dbo.CurrencyUser c WITH (NOLOCK) 
		ON lc.LicenseeID	= c.LicenseeID 
		AND lc.Currency		= c.CurrencyID
	WHERE	lc.RoleID	= 2
		AND lc.Currency	= @CurrencyID		
		AND c.usrID		= @userID 
		AND c.SystemID	= 1 
		AND c.isActive	= 1	 
	
	
	SELECT @Username 	=  LTRIM(RTRIM(ISNULL(@Username,'')))
		, @tempFromDate =  CASE WHEN @FromDate <= @MoveBetsDay THEN DATEADD(DAY,1,@MoveBetsDay)
								ELSE @FromDate
							END
		, @tempToDate 	=  CASE WHEN @ToDate >= @MoveBetsDay THEN @MoveBetsDay 
								ELSE @ToDate 
							END
		, @searchCust	= 0
		, @Duration		= 0
	
	-- COMPUTE hashing rpt code
	SELECT @rptCode =
			'l:'+CAST(@LicenseeID AS VARCHAR(10))
			+'a:'+CAST(@UserID AS VARCHAR(10))
			+'u:'+ISNULL(@Username,'')
			+'p:'+REPLACE(@Product, ',','')
			+'b:'+REPLACE(@Bettype, ',','')
			+'c:'+CAST(@CurrencyID AS VARCHAR(10))
			+'f:'+REPLACE(CAST(@FromDate AS VARCHAR(12)), ' ','')
			+'t:'+REPLACE(CAST(@tempToDate AS VARCHAR(12)), ' ','')
			+'o:'+CAST(@Odds AS VARCHAR(10))
			+'r:'+CAST(@ReportBy AS VARCHAR(5))
			+'w:'+CAST(@ShowWin AS VARCHAR(5))
			+'l:'+CAST(@ShowLoss AS VARCHAR(5))
			+'d:'+CAST(@ShowDraw AS VARCHAR(5))
		, @rptHash = HASHBYTES('SHA1', @rptCode)
	
	IF ( LEN(@Username) > 0 )
	BEGIN 
		INSERT INTO #tempCust
		SELECT c.custid
		FROM bodb02.dbo.Customer c WITH (NOLOCK) -- for using indexer
			INNER JOIN bodb_licensee.dbo.LicenseeCustinfo  lc WITH (NOLOCK) 
			ON c.CustID		= lc.CustID  
		WHERE c.roleid		= 1
			AND c.recommend		IN (SELECT custid FROM #recommend)
			AND (
				c.username2 	LIKE '%$%' 	+ @Username + '%'
				OR c.username	LIKE '%' 	+ @Username + '%'
			)
		IF(@@ROWCOUNT = 0) GOTO OutputResult;
		
		SET @searchCust = 1
	END

	----------SUMTOTOAL--------------
	IF(@Todate > @MoveBetsDay )
	BEGIN
		INSERT INTO #tempSumTotal
		SELECT 1				AS WhTicket
			, SUM(1)			AS betcount
			, SUM(stake) 		AS turnover
			, SUM(b.winlost - b.actual_stake) AS winlost
			, SUM(b.playercomm) AS playercomm
			, COUNT(DISTINCT  
					CASE WHEN @ReportBy =  2 THEN CONVERT(VARCHAR(6), b.winlostdate, 112)
						ELSE CONVERT(VARCHAR(8), b.winlostdate, 112)
					END 
					+ ISNULL(SUBSTRING(c.username2,CHARINDEX ('$',c.username2,1)+1,LEN(c.username2)),c.username)
				
			) AS TotalRows
		FROM dbo.bettrans b WITH(NOLOCK)
			INNER JOIN #recommend rec 
			ON b.Recommend	= rec.CustID 
			INNER JOIN bodb_licensee.dbo.LicenseeCustinfo  c WITH (NOLOCK)
			ON b.custid 	= c.custid
			LEFT OUTER JOIN #tempCust  tc WITH (NOLOCK)
			ON c.custid 	= tc.custid AND @searchCust = 1
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
			AND (@Odds = 0 
					OR (@Odds > 0 
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
					)
			)
			AND (
				@searchCust 	= 0
				OR (@searchCust = 1 AND tc.custid > 0)
			)
	END
	-- GET from temp table caching
	INSERT INTO #tempSumTotal
	SELECT TOP 1 
		rpt.whticket
		, rpt.betcount
		, rpt.turnover
		, rpt.winlost
		, rpt.playercomm
		, rpt.totalrow
	FROM ##tempLRFCustTORpt rpt
	WHERE rpt.rptHash		= @rptHash 
		AND rpt.whticket 	= 2
	ORDER BY rptVer DESC
		
	IF(@FromDate <= @MoveBetsDay AND NOT EXISTS(SELECT TOP 1 1 FROM #tempSumTotal WHERE whticket = 2 ))
	BEGIN
		INSERT INTO #tempSumTotal
		SELECT 2				AS WhTicket 
			, SUM(b.betcount)	AS betcount
			, SUM(b.stake) 		AS turnover
			, SUM(b.winlost)  	AS winlost
			, SUM(b.playercomm) AS playercomm
			, COUNT(DISTINCT  
						CASE WHEN @ReportBy =  2 THEN CONVERT(VARCHAR(6), b.winlostdate, 112)
							ELSE CONVERT(VARCHAR(8), b.winlostdate, 112)
						END 
						+ ISNULL(SUBSTRING(c.username2,CHARINDEX ('$',c.username2,1)+1,LEN(c.username2)),c.username)
				
			) AS TotalRows
		FROM bodb_LicenseeReport.dbo.rptcustomerturnOver_bobby b WITH(NOLOCK)--, INDEX=CIX_winlostdate)
			INNER JOIN #recommend rec
			ON b.Recommend	= rec.CustID
			INNER JOIN bodb_licensee.dbo.LicenseeCustinfo  c WITH (NOLOCK)
			ON b.custid 	= c.custid
			LEFT OUTER JOIN #tempCust  tc WITH (NOLOCK)
			ON c.custid 	= tc.custid AND @searchCust = 1
			INNER JOIN #bettype bt
			ON b.bettype 	=  bt.typeid
			INNER JOIN #Status st
			ON b.StatusID 	=  st.StatusID
			INNER JOIN #ProductID p 
			ON CASE	WHEN b.bettype IN (9, 10, 29) THEN 1
					ELSE b.sporttype 
				END			= p.sportID
		WHERE b.winlostdate BETWEEN @fromdate AND @tempToDate
			AND (@Odds = 0 
					OR (@Odds > 0 
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
					)
			)
			AND (
				@searchCust 	= 0
				OR (@searchCust = 1 AND tc.custid > 0)
			)
			
		--INSERT into temp caching table
		IF(@@ROWCOUNT > 0 AND @rptHash IS NOT NULL)
		BEGIN
			INSERT INTO ##tempLRFCustTORpt
			SELECT rpt.whticket
				, rpt.betcount
				, rpt.turnover
				, rpt.winlost
				, rpt.playercomm
				, rpt.totalrow
				, @rptHash AS rptHash
			FROM #tempSumTotal rpt
			WHERE rpt.whticket 		= 2 
				AND rpt.totalrow 	> 0
		END
	END
	
	IF(NOT EXISTS (SELECT TOP 1 1 FROM #tempSumTotal WHERE totalrow > 0 )) GOTO OutputResult;

	SELECT @totalBettrans	= CASE WHEN s.whticket = 1 THEN ISNULL(s.totalrow,0) ELSE ISNULL(@totalBettrans, 0) END
		, @totalSumRpt		= CASE WHEN s.whticket = 2 THEN ISNULL(s.totalrow,0) ELSE ISNULL(@totalSumRpt,0) END
	FROM #tempSumTotal s
	
	----------------------------------------
	-----------PAGING CONFIG ---------------
	----------------------------------------
	DECLARE @offsetRow 	INT
		, @maxRow		INT
	
	IF(@IsExportExcel =  1)
	BEGIN
		SELECT @PageIndex	= 1
			, @PageSize		= 65000
	END

	SELECT @offsetRow	= (((@PageIndex - 1) * @PageSize) + 1) 
		, @maxRow		= (@PageSize * @PageIndex)

	IF(@totalBettrans > 0
		AND (@offsetRow <= @totalBettrans)
	)
	BEGIN

		INSERT INTO #tempCustRec
		SELECT p.RowIdx AS rowno
			, p.WhTicket
			, p.winlostdate
			, p.custid
			, p.username
		FROM (
			SELECT
				ROW_NUMBER () OVER (
					ORDER BY CASE WHEN @ReportBy =  2 THEN DATEADD(M, DATEDIFF(M, 0, b.winlostdate), 0)
								ELSE b.winlostdate
							END DESC
							, ISNULL(SUBSTRING(c.username2,CHARINDEX ('$',c.username2,1)+1,LEN(c.username2)),c.username) ASC
				) AS RowIdx
				, 1 AS WhTicket
				, CASE WHEN @ReportBy =  2 THEN DATEADD(M, DATEDIFF(M, 0, b.winlostdate), 0)
						ELSE b.winlostdate
					END AS winlostdate
				, b.custid
				, ISNULL(SUBSTRING(c.username2,CHARINDEX ('$',c.username2,1)+1,LEN(c.username2)),c.username) AS username
				
			FROM dbo.bettrans b WITH(NOLOCK)
				INNER JOIN #recommend rec 
				ON b.Recommend	= rec.CustID 
				INNER JOIN bodb_licensee.dbo.LicenseeCustinfo  c WITH (NOLOCK)
				ON b.custid 	= c.custid
				LEFT OUTER JOIN #tempCust  tc WITH (NOLOCK)
				ON c.custid 	= tc.custid
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
				AND (@Odds = 0 
						OR (@Odds > 0 
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
						)
				)
				AND (
					@searchCust 	= 0
					OR (@searchCust = 1 	AND tc.custid > 0)
				)
			GROUP BY 
				CASE WHEN @ReportBy =  2 THEN DATEADD(M, DATEDIFF(M, 0, b.winlostdate), 0)
						ELSE b.winlostdate
					END
				, b.custid
				, ISNULL(SUBSTRING(c.username2,CHARINDEX ('$',c.username2,1)+1,LEN(c.username2)),c.username)
	
		) p
		WHERE p.RowIdx BETWEEN @offsetRow AND @maxRow
	END

	IF(@totalSumRpt > 0
		AND (@maxRow > @totalBettrans)
	)
	BEGIN
		
		INSERT INTO #tempCustRec
		SELECT p.RowIdx AS rowno
			, p.WhTicket
			, p.winlostdate
			, p.custid
			, p.username
			
		FROM (
			SELECT ROW_NUMBER () OVER (
						ORDER BY CASE WHEN @ReportBy =  2 THEN DATEADD(M, DATEDIFF(M, 0, b.winlostdate), 0)
									ELSE b.winlostdate
								END DESC
								, ISNULL(SUBSTRING(c.username2,CHARINDEX ('$',c.username2,1)+1,LEN(c.username2)),c.username) ASC
				) + @totalBettrans AS RowIdx
				, 2 AS WhTicket 
				, CASE WHEN @ReportBy =  2 THEN DATEADD(M, DATEDIFF(M, 0, b.winlostdate), 0)
						ELSE b.winlostdate
					END AS winlostdate
				, b.custid
				, ISNULL(SUBSTRING(c.username2,CHARINDEX ('$',c.username2,1)+1,LEN(c.username2)),c.username) AS username
			
			FROM bodb_LicenseeReport.dbo.rptcustomerturnOver_bobby b WITH(NOLOCK)--, INDEX=CIX_winlostdate)
				INNER JOIN #recommend rec
				ON b.Recommend	= rec.CustID
				INNER JOIN bodb_licensee.dbo.LicenseeCustinfo  c WITH (NOLOCK)
				ON b.custid 	= c.custid
				LEFT OUTER JOIN #tempCust  tc WITH (NOLOCK)
				ON b.custid 	= tc.custid AND @searchCust = 1
				INNER JOIN #bettype bt
				ON b.bettype 	=  bt.typeid
				INNER JOIN #Status st
				ON b.StatusID 	=  st.StatusID
				INNER JOIN #ProductID p 
				ON CASE	WHEN b.bettype IN (9, 10, 29) THEN 1
						ELSE b.sporttype 
					END			= p.sportID
			WHERE b.winlostdate BETWEEN @fromdate AND @tempToDate
				AND (@Odds = 0 
						OR (@Odds > 0 
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
						)
				)
				AND (
					@searchCust 	= 0
					OR (@searchCust = 1 AND tc.custid > 0)
				)
			GROUP BY 
				CASE WHEN @ReportBy =  2 THEN DATEADD(M, DATEDIFF(M, 0, b.winlostdate), 0)
						ELSE b.winlostdate
					END
				, b.custid
				, ISNULL(SUBSTRING(c.username2,CHARINDEX ('$',c.username2,1)+1,LEN(c.username2)),c.username)
			
		) p
		WHERE p.RowIdx BETWEEN @offsetRow AND @maxRow
	END
	
	--GET sum member detial
	IF(@totalBettrans > 0 AND EXISTS ( SELECT TOP 1 1 FROM #tempCustRec WHERE whticket= 1 ))
	BEGIN
		INSERT INTO #custData
		SELECT c.rowno
			, c.winlostdate 
			, c.custid
			, c.username
			, rec.currency
			, CASE 
				WHEN m.sporttype	IS NOT NULL		AND bt.EventType  =  1	THEN m.sporttype
				WHEN l.sporttype	IS NOT NULL		AND bt.EventType  =  2	THEN l.sporttype
				WHEN r.sporttype 	IS NOT NULL		AND bt.EventType  =  3	THEN r.SportType
				ELSE 1 
			END AS sporttype
			,b.bettype
			,SUM(1) as betcount
			,SUM(b.stake) as turnover 
			,SUM(b.winlost - b.actual_stake) as winlost
			,SUM(b.playercomm) as playercomm
		FROM dbo.bettrans b WITH(NOLOCK)
			INNER JOIN #recommend rec
			ON b.Recommend	= rec.CustID
			INNER JOIN #tempCustRec c 
			ON  b.custid		= c.custid 
			AND CASE WHEN @ReportBy =  2 THEN DATEADD(M, DATEDIFF(M, 0, b.winlostdate), 0)
						ELSE b.winlostdate
					END = c.winlostdate
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
		WHERE c.WhTicket = 1
			AND p.sportID IS NOT NULL
			AND (@odds = 0 
				OR (@odds > 0 
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
				)
			)


		GROUP BY
			c.rowno
			,c.winlostdate 
			,c.custid
			,c.username
			,rec.currency
			, CASE 
				WHEN m.sporttype	IS NOT NULL		AND bt.EventType  =  1	THEN m.sporttype
				WHEN l.sporttype	IS NOT NULL		AND bt.EventType  =  2	THEN l.sporttype
				WHEN r.sporttype 	IS NOT NULL		AND bt.EventType  =  3	THEN r.SportType
				ELSE 1 
			END
			,b.bettype
	END

	IF(@totalSumRpt > 0 AND EXISTS ( SELECT TOP 1 1 FROM #tempCustRec WHERE whticket= 2 ))
	BEGIN
		INSERT INTO #custData
		SELECT 
			c.rowno
			, c.winlostdate 
			, c.custid
			, c.username
			, rec.currency
			, CASE	WHEN b.bettype IN (9, 10, 29) THEN 1
					ELSE b.sporttype 
				END AS sporttype  
			,b.bettype
			,SUM(b.betcount) as betcount
			,SUM(b.stake) as turnover 
			,SUM(b.winlost) as winlost
			,SUM(b.playercomm) as playercomm
		FROM bodb_LicenseeReport.dbo.rptcustomerturnOver_bobby b WITH (NOLOCK)
			INNER JOIN #recommend rec
			ON b.Recommend	= rec.CustID
			INNER JOIN #tempCustRec c 
			ON  b.custid		= c.custid 
				AND CASE WHEN @ReportBy =  2 THEN DATEADD(M, DATEDIFF(M, 0, b.winlostdate), 0)
						ELSE b.winlostdate
					END = c.winlostdate
			INNER JOIN #bettype bt
			ON b.bettype 	=  bt.typeid
			INNER JOIN #Status st
			ON b.StatusID 	=  st.StatusID
			INNER JOIN #ProductID p 
			ON CASE	WHEN b.bettype IN (9, 10, 29) THEN 1
					ELSE b.sporttype 
				END			= p.sportID
		WHERE c.whticket	= 2
			AND (@odds = 0 
				OR (@odds > 0 
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
				)
			)
		GROUP BY
			c.rowno
			, c.winlostdate 
			, c.custid
			, c.username
			, rec.currency
			, CASE	WHEN b.bettype IN (9, 10, 29) THEN 1
					ELSE b.sporttype 
				END
			,b.bettype
	END

	OutputResult:
	BEGIN
		SELECT 
			c.RowNo
			, CASE WHEN @ReportBy =  2 THEN CONVERT(VARCHAR(6), c.winlostdate, 112)
				ELSE CONVERT(VARCHAR(8), c.winlostdate, 112)
			END AS ReportBy
			, c.username
			, e.Code AS currency
			, c.sporttype
			, CASE 
					WHEN @Langkey =  'zh-CN'	AND ISNULL(bt.typenamecn, '')	<> '' THEN bt.typenamecn
					WHEN @Langkey =  'zh-TW'	AND ISNULL(bt.typenamecn, '')	<> '' THEN bt.typenamecn
					WHEN @Langkey =  'th-TH'	AND ISNULL(bt.typenameth, '')	<> '' THEN bt.typenameth
					WHEN @Langkey =  'ja-JP'	AND ISNULL(bt.typenamej, '')	<> '' THEN bt.typenamej
					WHEN @Langkey =  'ko-KR'	AND ISNULL(bt.typenameko, '')	<> '' THEN bt.typenameko
					WHEN @Langkey =  'es'  		AND ISNULL(bt.typenameES, '')	<> '' THEN bt.typenameES
					WHEN @Langkey =  'vi-VN'	AND ISNULL(bt.typenamee, '')	<> '' THEN bt.typenamee
					ELSE typenamee 
				END AS bettype
			, c.betcount
			, c.turnover
			, c.winlost
			, c.playercomm
		FROM #custData c
			LEFT JOIN dbo.f_GroupBettype() ss 
			ON c.bettype = ss.bettype
			INNER JOIN dbo.bettype bt WITH(NOLOCK)
			ON ISNULL(ss.GroupTypeID, c.bettype) = bt.typeid
			INNER JOIN dbo.exchange e WITH (NOLOCK) 
			ON c.currency = e.exchangeid
		ORDER BY 
			c.rowno

		SELECT 
			SUM(ISNULL(s.betcount, 0))		AS SumBetCount
			, SUM(ISNULL(s.turnover, 0))	AS SumTurnover
			, SUM(ISNULL(s.winlost, 0))		AS SumWinlost
			, SUM(ISNULL(s.playercomm, 0))	AS SumComm
			, SUM(ISNULL(s.totalrow, 0))	AS TotalRows
		FROM #tempSumTotal s
	END
	
	DROP TABLE #tempCust
	DROP TABLE #ProductID
	DROP TABLE #bettype 
	DROP TABLE #Status
	DROP TABLE #recommend
	DROP TABLE #tempCustRec
	DROP TABLE #custData
	DROP TABLE #tempSumTotal
	
	--SET duration time
	SET @Duration = DATEDIFF(MS, @startTime, GETDATE())
	
	RETURN;
END
GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_CustomerTurnOver] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_CustomerTurnOver] TO [vnteam] 
GO

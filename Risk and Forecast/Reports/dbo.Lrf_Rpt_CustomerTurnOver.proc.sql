/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/


SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

 
ALTER PROCEDURE  [dbo].[Lrf_Rpt_CustomerTurnOver]
(
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
	,@AgentList		VARCHAR(MAX)
) 
WITH RECOMPILE
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
	- 20150618@Bobby: Apply pre-caching sumtotal from rptcustomerturnOver_bobby table
	- 20150821@Winnie: KeenOcean revert currency
	- 20151023@Victor: Support New Simplified Chinese
	- 20151127@Bobby: #48081 - Apply PH-AIO new bettypes
	- 20151203@Bobby: Database - Change datatype [Redmine: #48660]
	- 20151209@Bobby: Do rollback step for Bettype & ProductId data type
	- 20151223@Jim: Add "Effective Betting Value" in Customer Turnover report [Redmine: #45736]
	- 20160413@Victor: support MKK currency code
	- 20160720@Jim : Implement 67 new bet types (PH All in one - Phase 2) [Redmine : #53520]
	- 20170228@Paul: Get @AgentList by web instead of @UserId, @CurrencyID, @LicenseeID [Redmine: #71679]
	- 20170707@Harper: LRF - Integrate Bet Radar Virtual Sports [RedmineID: #78241]

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
		, @rptHash			VARBINARY(256)
		, @rptHashSum		VARBINARY(256)
		, @offsetRow 		INT
		, @maxRow			INT
	
	--SET start time value
	SET @startTime 			= GETDATE()
	
	CREATE TABLE #custData
	(
		rowno				INT
		, winlostdate 		DATE
		, custid 			INT
		, currency			INT
		, sporttype			SMALLINT
		, bettype			INT
		, betcount 			INT
		, turnover			MONEY
		, winlost			MONEY
		, BetEffective      MONEY
		, playercomm		MONEY
		, whticket			TINYINT
	)
	
	CREATE TABLE #tempCust 
	(
		custid			INT
		, username		NVARCHAR(30)
	)
	
	CREATE TABLE #tempCustPaging 
	(
		rowno			INT
		, whticket		TINYINT
		, winlostdate	DATETIME
		, custid		INT
		, totalrow		INT
	)
	
	CREATE TABLE #tempLRFCustTORpt
		(
			whticket		TINYINT
			, betcount		INT
			, turnover		MONEY
			, winlost		MONEY
			, BetEffective  MONEY
			, playercomm	MONEY
			, totalrow		INT
			, rptHash		VARBINARY(256)
			, rptDate		DATETIME
			, rptVer		INT IDENTITY(1,1)
		)
	
	
	END
	
	CREATE TABLE #tempSumTotal 
	(
		whticket		TINYINT
		, betcount		INT
		, turnover		MONEY
		, winlost		MONEY
		, BetEffective  MONEY
		, playercomm	MONEY
		, totalrow		INT
	)
	
	CREATE TABLE #tempBettrans
	(
		winlostdate		SMALLDATETIME
		, custid		INT
		, recommend		INT
		, sporttype		SMALLINT
		, matchid		INT
		, bettype		INT
		, oddsid		INT
		, winlost		MONEY
		, BetEffective  MONEY
		, stake			MONEY
		, playercomm	MONEY
		, Odds			MONEY
		, oddstype 		tinyint	
		, EventType		TINYINT
		, ProductId		INT
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
		
	CREATE TABLE #recommend
	(
		CustID			INT,
		Currency		INT
	)

	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@AgentList
	
		INSERT INTO #recommend(CustId, Currency)
		SELECT AgentId, Currency 
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
			,ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH;
	
	
	SELECT @Username 	=  LTRIM(RTRIM(ISNULL(@Username,'')))
		, @tempFromDate =  CASE WHEN @FromDate <= @MoveBetsDay THEN DATEADD(DAY,1,@MoveBetsDay)
								ELSE @FromDate
							END
		, @tempToDate 	=  CASE WHEN @ToDate >= @MoveBetsDay THEN @MoveBetsDay 
								ELSE @ToDate 
							END
		, @searchCust	= 0
		, @Duration		= 0
	
	IF ( LEN(@Username) > 0 )
	BEGIN 
		INSERT INTO #tempCust
		SELECT c.custid
			, ISNULL(SUBSTRING(c.username2,CHARINDEX ('$',c.username2,1)+1,LEN(c.username2)),c.username) AS username
		FROM  bodb_licensee.dbo.LicenseeCustinfo  c WITH (NOLOCK) 
		  
		WHERE   c.recommend		IN (SELECT custid FROM #recommend)
			AND (
				c.username2 	LIKE '%$%' 	+ @Username + '%'
				OR c.username	LIKE '%' 	+ @Username + '%'
			)
		IF(@@ROWCOUNT = 0) GOTO OutputResult;
		
		SET @searchCust  	= 1
	END
	
	IF (@ToDate > @MoveBetsDay)
	BEGIN

		SELECT DISTINCT b.transid, s.sporttype
		INTO #tmpParlay
		FROM dbo.bettrans b WITH (NOLOCK)
			INNER JOIN #recommend rec ON b.Recommend = rec.CustID
			INNER JOIN #Status st ON b.StatusID =  st.StatusID
			CROSS APPLY (	SELECT TOP 1 m.sporttype
							FROM dbo.bettransm bm WITH (NOLOCK)
								INNER JOIN dbo.match m WITH (NOLOCK) ON bm.matchid = m.matchid
							WHERE b.refno = bm.refno AND b.custid = bm.custid
					) AS s
		WHERE b.bettype = 2799		
			AND b.winlostdate BETWEEN @tempFromDate AND @ToDate
			AND b.matchid = 2799

		INSERT INTO #tempBettrans
		SELECT b.winlostdate
			, b.custid
			, recommend
			, CASE WHEN bt.EventType = 0 THEN
					CASE WHEN b.bettype = 2799 THEN p.sporttype ELSE 1 END
			  ELSE 0 END AS sporttype
			, b.matchid
			, b.bettype
			, b.oddsid
			, (b.winlost - b.actual_stake) AS winlost
			, ABS(b.winlost - b.actual_stake) BetEffective
			, b.stake
			, b.playercomm
			, b.Odds
			, b.oddstype 
			, bt.EventType
			, bt.ProductID
		FROM dbo.bettrans b WITH(NOLOCK)
			INNER JOIN #recommend rec ON b.Recommend = rec.CustID 
			INNER JOIN #bettype bt ON b.bettype =  bt.typeid
			INNER JOIN #Status st ON b.StatusID =  st.StatusID
			LEFT JOIN #tmpParlay p ON b.transid = p.transid
		WHERE b.winlostdate BETWEEN @tempFromDate AND @ToDate
		
		UPDATE #tempBettrans 
		SET Odds = CASE WHEN OddsType = 1 THEN odds + 1 --decimal
						 WHEN OddsType = 2 THEN Odds + 1 --hongkong to decimal
						 WHEN OddsType IN (3,4) THEN --malay and indo to decimal
												CASE 
													WHEN odds < 0 THEN (1 -  cast(1 as float) / cast(odds AS float))
													WHEN odds >=0 THEN (1 + odds) END
						 WHEN OddsType = 5 THEN --american odds to decimal
											CASE
											WHEN (odds * 100) < 0 THEN (1- cast (1 AS float)/ cast (odds AS float))
											WHEN (odds * 100) % 2 = 0 THEN 2
											WHEN (odds * 100) > 0 THEN (1 + odds) END 
					 END 
		WHERE bettype IN (1,2,3,7,12,8,20,21,1301,1303,1305,1306,1308,1311,1312,1316,1318,1324,153,154,155,156)	 -- add more Sportting Solution bettype 
						OR bettype BETWEEN 81 AND 88
						OR bettype BETWEEN 90 AND 120
						OR bettype IN (157,178,183,184,194,197,198,203,204,205) -- add more bettype BetRadar 
						OR bettype BETWEEN 401 AND 404 -- add more PH-AIO new bettypes
						OR bettype = 428 -- 2H Odd/Even
			
		-- CREATE INDEXERS
		CREATE CLUSTERED 	INDEX [CIX_tempBettrans] 			ON #tempBettrans (recommend, custid, winlostdate)
		CREATE NONCLUSTERED INDEX IDX_tempBettrans_EventType 	ON #tempBettrans(EventType)
		
		IF( @searchCust = 1)
		BEGIN
			DELETE b
			FROM #tempBettrans b
				INNER JOIN #recommend rec
				ON b.Recommend	= rec.CustID
				LEFT JOIN #tempCust c
				ON b.custid = c.custid
			WHERE c.custid IS NULL
		END
		
		--FILTER odds value
		IF(@odds > 0)
		BEGIN
			DELETE b
			FROM #tempBettrans b
			WHERE b.odds < @odds
		END
		
		IF(EXISTS(SELECT TOP 1 1 FROM #tempBettrans WHERE EventType = 1 ))
		BEGIN
			UPDATE b
			SET b.sporttype = m.sporttype
			FROM #tempBettrans b
				INNER JOIN dbo.match m WITH(NOLOCK)
				ON b.matchid = m.matchid
			WHERE b.EventType = 1
				AND m.eventdate BETWEEN @tempFromDate AND @ToDate 
		END
		
		IF(EXISTS(SELECT TOP 1 1 FROM #tempBettrans WHERE EventType = 2 ))
		BEGIN
			UPDATE b
			SET b.sporttype = l.sporttype
			FROM #tempBettrans b
				INNER JOIN dbo.outright o with(nolock) 
				ON b.matchid 		= o.orid 
				INNER JOIN dbo.league l with(nolock) 
				ON o.leagueid 		= l.leagueid
			WHERE b.EventType = 2
				AND o.eventdate BETWEEN @tempFromDate AND @ToDate 
		END

		IF(EXISTS(SELECT TOP 1 1 FROM #tempBettrans WHERE EventType = 3 ))
		BEGIN
			UPDATE b
			SET b.sporttype = r.sporttype
			FROM #tempBettrans b
				INNER JOIN dbo.VSOutright  vs WITH (NOLOCK)
				ON b.oddsid			= vs.Orid
				INNER JOIN dbo.VSRaceInfo r WITH (NOLOCK) 
				ON vs.EventID  		= r.EventID
			WHERE b.EventType = 3
				AND vs.eventdate BETWEEN @tempFromDate AND @ToDate 
		END		
		
		--FILTER product
		DELETE b
		FROM #tempBettrans b
		WHERE b.sporttype NOT IN (
			SELECT sportid FROM #ProductID
		)
	END
	
	GET_SUMTOTAL:
	BEGIN
		-- COMPUTE hashing rpt code
		SELECT @rptCode 	= 'l:'+CAST(@LicenseeID AS VARCHAR(10))
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
			, @rptHash 		= HASHBYTES('SHA1', @rptCode + 'td:'+REPLACE(CAST(@ToDate AS VARCHAR(12)), ' ','')  + 'ts:'+CONVERT(VARCHAR(13), @startTime, 120)) -- in 1hour
			, @rptHashSum 	= HASHBYTES('SHA1', @rptCode)
			
		DECLARE @isCached BIT = 0
		-- GET from temp table caching
		IF  EXISTS ( SELECT TOP 1 1 FROM #tempLRFCustTORpt )
		BEGIN
			INSERT INTO #tempSumTotal
			SELECT s.*
			FROM (
				SELECT TOP 1 rpt.whticket
					, rpt.betcount
					, rpt.turnover
					, rpt.winlost
					, rpt.BetEffective
					, rpt.playercomm
					, rpt.totalrow
				FROM #tempLRFCustTORpt rpt
				WHERE rpt.rptHash = @rptHash AND rpt.whticket = 1
					AND @pageIndex <> 1

				UNION ALL
				SELECT TOP 1 rpt.whticket
					, rpt.betcount
					, rpt.turnover
					, rpt.winlost
					, rpt.BetEffective
					, rpt.playercomm
					, rpt.totalrow
				FROM #tempLRFCustTORpt rpt
				WHERE rpt.rptHash = @rptHashSum AND rpt.whticket = 2	
			) s		
		END 		
		
		--SELECT totalrows
		SELECT 
			@totalBettrans		= CASE WHEN s.whticket 	= 1 THEN SUM(ISNULL(s.totalrow,0)) ELSE ISNULL(@totalBettrans, 0) END
			, @totalSumRpt		= CASE WHEN s.whticket 	= 2 THEN SUM(ISNULL(s.totalrow,0)) ELSE ISNULL(@totalSumRpt,0) END
			, @isCached			= CASE WHEN COUNT(1) 	= 2 THEN 1 ELSE 0 END
		FROM #tempSumTotal s
		
		GROUP BY 
			s.whticket
			, s.totalrow
		
		SELECT @totalBettrans	= ISNULL(@totalBettrans, 0)
			, @totalSumRpt		= ISNULL(@totalSumRpt, 0)
		--SELECT @isCached isCached, * FROM #tempSumTotal s	
		
		IF( @isCached = 0 )
		BEGIN
												EXEC [dbo].[Lrf_Rpt_CustomerTurnOver_SumTotal]
				@searchCust 	= @searchCust
				,@FromDate 		= @FromDate
				,@tempFromDate 	= @tempFromDate
				,@ToDate 		= @toDate
				,@tempToDate 	= @tempToDate
				,@MoveBetsDay 	= @MoveBetsDay
				,@Odds 			= @Odds
				,@ReportBy  	= @ReportBy
				
			-- CHECK for update/insert cache
			IF EXISTS (SELECT TOP 1 1 FROM #tempLRFCustTORpt) 
			BEGIN
				MERGE INTO #tempLRFCustTORpt c
				USING ( 
					SELECT *
						, CASE 
							WHEN  whticket = 1 THEN @rptHash
							WHEN  whticket = 2 THEN @rptHashSum 
							ELSE NULL
						END AS rptHash
						, @startTime rptDate
					FROM  #tempSumTotal
					WHERE betcount > 0
				) rpt 
				ON ( c.rptHash = rpt.rptHash AND c.whticket = rpt.whticket )
				WHEN MATCHED THEN
					UPDATE 
						SET c.betcount	= rpt.betcount
						, c.turnover	= rpt.turnover
						, c.winlost		= rpt.winlost
						, c.BetEffective = rpt.BetEffective
						, c.playercomm	= rpt.playercomm
						, c.totalrow	= rpt.totalrow
					
				WHEN NOT MATCHED BY TARGET THEN
					INSERT( whticket
						, betcount
						, turnover
						, winlost
						, BetEffective
						, playercomm
						, totalrow
						, rptHash
						, rptDate
					)
					VALUES (rpt.whticket
						, rpt.betcount
						, rpt.turnover
						, rpt.winlost
						, rpt.BetEffective
						, rpt.playercomm
						, rpt.totalrow 
						, rpt.rptHash
						, rpt.rptDate
					)
				;
			END 
		END
		
	END

	--SELECT * FROM #tempSumTotal
	-- CHECK sumtotal
	IF(NOT EXISTS (SELECT TOP 1 1 FROM #tempSumTotal WHERE betcount > 0 )) GOTO OutputResult;
	
	----------------------------------------
	-----------PAGING CONFIG ---------------
	----------------------------------------
	GET_PAGING:
	BEGIN
		IF(@IsExportExcel =  1)
		BEGIN
			SELECT @PageIndex	= 1
				, @PageSize		= 65000
		END
		
		SELECT @offsetRow	= (((@PageIndex - 1) * @PageSize) + 1) 
			, @maxRow		= (@PageSize * @PageIndex)
			
		IF(@ReportBy = 1)
		BEGIN
			EXEC [dbo].[Lrf_Rpt_CustomerTurnOver_Pagination]
				@searchCust 	= @searchCust
				,@FromDate 		= @FromDate
				,@tempFromDate 	= @tempFromDate
				,@ToDate 		= @toDate
				,@tempToDate 	= @tempToDate
				,@MoveBetsDay 	= @MoveBetsDay
				,@Odds 			= @Odds
				,@ReportBy  	= @ReportBy
				,@offsetRow 	= @offsetRow 
				,@maxRow		= @maxRow
				,@totalBettrans	= @totalBettrans OUTPUT
				,@totalSumRpt	= @totalSumRpt OUTPUT
		END
		IF(@ReportBy = 2)
		BEGIN
			EXEC [dbo].[Lrf_Rpt_CustomerTurnOver_MonthlyPagination]
				@searchCust 	= @searchCust
				,@FromDate 		= @FromDate
				,@tempFromDate 	= @tempFromDate
				,@ToDate 		= @toDate
				,@tempToDate 	= @tempToDate
				,@MoveBetsDay 	= @MoveBetsDay
				,@Odds 			= @Odds
				,@ReportBy  	= @ReportBy
				,@offsetRow 	= @offsetRow 
				,@maxRow		= @maxRow
				,@totalBettrans	= @totalBettrans OUTPUT
				,@totalSumRpt	= @totalSumRpt OUTPUT
		END

		--select @totalBettrans totalBettrans, @totalSumRpt totalSumRpt
		IF( @totalBettrans > 0 OR @totalSumRpt > 0 )
		BEGIN
			--UPDATE sumtotal
			UPDATE s
			SET s.totalrow = CASE 	WHEN s.whticket = 1 THEN @totalBettrans
									WHEN s.whticket = 2 THEN @totalSumRpt
								END
			FROM #tempSumTotal s 
			WHERE ISNULL(s.totalrow, 0) = 0
			
			--- UPDATE total rows caching
			
			IF EXISTS( SELECT TOP 1 1 FROM #tempLRFCustTORpt )
			BEGIN
				;WITH CTE_Total AS (
					SELECT s.whticket
						, s.totalrow
						, CASE 
							WHEN  s.whticket = 1 THEN @rptHash
							WHEN  s.whticket = 2 THEN @rptHashSum 
							ELSE NULL
						END AS rptHash
					FROM #tempSumTotal s
				)
				-- totalBettrans & totalSumRpt
				UPDATE rpt
				SET rpt.totalrow = t.TotalRow
				FROM #tempLRFCustTORpt rpt
					INNER JOIN CTE_Total t 
					ON rpt.rptHash = t.rptHash AND rpt.whticket = t.whticket
					
			END 
		END
		
	END
	
	--SELECT * FROM #tempSumTotal
	
	GET_SUMMEMBER:
	BEGIN
		DECLARE @pStartDate	DATE
			,@pEndDate		DATE

		SELECT @pStartDate	= MIN(Winlostdate)
			, @pEndDate		= MAX(Winlostdate)
		FROM #tempCustPaging c

		SELECT @pStartDate	= CASE WHEN @pStartDate < @FromDate THEN @FromDate ELSE @pStartDate END
			, @pEndDate		= CASE WHEN @reportBy = 2 THEN DATEADD(DD, -1, DATEADD(M, 1, @pEndDate)) ELSE @pEndDate END
			, @pEndDate		= CASE WHEN @pEndDate > @ToDate THEN @ToDate ELSE @pEndDate END
		
		EXEC [dbo].[Lrf_Rpt_CustomerTurnOver_SumMember]
			@pStartDate		= @pStartDate
			,@pEndDate		= @pEndDate
			,@Odds 			= @Odds
			,@ReportBy  	= @ReportBy
			,@MoveBetsDay 	= @MoveBetsDay
	END	
	
 
	OutputResult:
	BEGIN
		WITH CTE_Bettype AS
		(
			SELECT b.bettype
				,CASE 
					WHEN @Langkey =  'zh-CN'	AND ISNULL(bt.typenamecn, '')	<> '' THEN bt.typenamecn
					WHEN @Langkey =  'zh-TW'	AND ISNULL(bt.typenamecn, '')	<> '' THEN bt.typenamecn
					WHEN @Langkey =  'zh-Hans'	AND ISNULL(bt.typenamecn, '')	<> '' THEN bt.typenamecn
					WHEN @Langkey =  'th-TH'	AND ISNULL(bt.typenameth, '')	<> '' THEN bt.typenameth
					WHEN @Langkey =  'ja-JP'	AND ISNULL(bt.typenamej, '')	<> '' THEN bt.typenamej
					WHEN @Langkey =  'ko-KR'	AND ISNULL(bt.typenameko, '')	<> '' THEN bt.typenameko
					WHEN @Langkey =  'es'  		AND ISNULL(bt.typenameES, '')	<> '' THEN bt.typenameES
					WHEN @Langkey =  'vi-VN'	AND ISNULL(bt.typenamee, '')	<> '' THEN bt.typenamee
					ELSE typenamee 
				END AS typenamee
			FROM #custData b
				LEFT JOIN dbo.f_GroupBettype() ss 
				ON b.bettype 	= ss.bettype
				INNER JOIN dbo.bettype bt WITH(NOLOCK)
				ON ISNULL(ss.GroupTypeID, b.bettype) = bt.typeid
				
			GROUP BY 
				b.bettype
				,CASE 
					WHEN @Langkey =  'zh-CN'	AND ISNULL(bt.typenamecn, '')	<> '' THEN bt.typenamecn
					WHEN @Langkey =  'zh-TW'	AND ISNULL(bt.typenamecn, '')	<> '' THEN bt.typenamecn
					WHEN @Langkey =  'zh-Hans'	AND ISNULL(bt.typenamecn, '')	<> '' THEN bt.typenamecn
					WHEN @Langkey =  'th-TH'	AND ISNULL(bt.typenameth, '')	<> '' THEN bt.typenameth
					WHEN @Langkey =  'ja-JP'	AND ISNULL(bt.typenamej, '')	<> '' THEN bt.typenamej
					WHEN @Langkey =  'ko-KR'	AND ISNULL(bt.typenameko, '')	<> '' THEN bt.typenameko
					WHEN @Langkey =  'es'  		AND ISNULL(bt.typenameES, '')	<> '' THEN bt.typenameES
					WHEN @Langkey =  'vi-VN'	AND ISNULL(bt.typenamee, '')	<> '' THEN bt.typenamee
					ELSE bt.typenamee 
				END
		)
		SELECT 
			b.RowNo
			, CASE WHEN @ReportBy =  2 THEN CONVERT(VARCHAR(6), b.winlostdate, 112)
				ELSE CONVERT(VARCHAR(8), b.winlostdate, 112)
			END AS ReportBy
			, ISNULL(SUBSTRING(c.username2,CHARINDEX ('$',c.username2,1)+1,LEN(c.username2)),c.username) AS username
			, CASE 
				WHEN e.exchangeid = 20 THEN 'UUS'
				WHEN e.exchangeid = 51 THEN 'INH'
				WHEN e.exchangeid = 70 THEN 'MKK'
				WHEN e.exchangeid = 66 AND b.winlostdate<'2015-09-01' THEN 'HKD'
				WHEN e.exchangeid = 66 AND b.winlostdate>='2015-09-01' THEN 'CNY'
				ELSE e.Code END AS Currency
			, b.sporttype
			, CASE WHEN b.bettype BETWEEN 81 AND 120 THEN  N'NG - ' + bt.typenamee
				 WHEN (b.bettype BETWEEN 1201 AND 1299) THEN  N'VS - '+bt.typenamee + CASE WHEN b.bettype = 1204 THEN '(Soccer)'
																					WHEN b.bettype = 1235 THEN '(Tennis)'
																					ELSE ''
																				END
				WHEN (b.bettype BETWEEN 2701 AND 2799) THEN  N'VS2 - ' + bt.typenamee
				ELSE  bt.typenamee
			END AS bettype
			, SUM(b.betcount)	AS betcount
			, SUM(b.turnover)	AS turnover
			, SUM(b.winlost) 	AS winlost
			, SUM(b.BetEffective) AS BetEffective
			, SUM(b.playercomm) AS playercomm

		FROM #custData b
			INNER JOIN bodb_licensee.dbo.LicenseeCustinfo c WITH (NOLOCK) 
			ON b.CustID		= c.CustID 
			INNER JOIN CTE_Bettype bt
			ON b.bettype = bt.bettype
			INNER JOIN dbo.exchange e WITH (NOLOCK) 
			ON b.currency = e.exchangeid
			
		GROUP BY
			b.RowNo
			, CASE WHEN @ReportBy =  2 THEN CONVERT(VARCHAR(6), b.winlostdate, 112)
				ELSE CONVERT(VARCHAR(8), b.winlostdate, 112)
			END
			, ISNULL(SUBSTRING(c.username2,CHARINDEX ('$',c.username2,1)+1,LEN(c.username2)),c.username)
			, CASE 
				WHEN e.exchangeid = 20 THEN 'UUS'
				WHEN e.exchangeid = 51 THEN 'INH'
				WHEN e.exchangeid = 70 THEN 'MKK'
				WHEN e.exchangeid = 66 AND b.winlostdate<'2015-09-01' THEN 'HKD'
				WHEN e.exchangeid = 66 AND b.winlostdate>='2015-09-01' THEN 'CNY'
				ELSE e.Code END
			, b.sporttype
			, CASE WHEN b.bettype BETWEEN 81 AND 120 THEN  N'NG - ' + bt.typenamee
				 WHEN (b.bettype BETWEEN 1201 AND 1299) THEN  N'VS - '+bt.typenamee + CASE WHEN b.bettype = 1204 THEN '(Soccer)'
																					WHEN b.bettype = 1235 THEN '(Tennis)'
																					ELSE ''
																				END
				 WHEN (b.bettype BETWEEN 2701 AND 2799) THEN  N'VS2 - ' + bt.typenamee
				 ELSE  bt.typenamee
			END
		ORDER BY 
			b.rowno ASC
			
		-- OUTPUT sumtotal
		SELECT 
			SUM(ISNULL(s.betcount, 0))		AS SumBetCount
			, SUM(ISNULL(s.turnover, 0))	AS SumTurnover
			, SUM(ISNULL(s.winlost, 0))		AS SumWinlost
			, SUM(ISNULL(s.BetEffective,0)) AS SUMBetEffective
			, SUM(ISNULL(s.playercomm, 0))	AS SumComm
			, SUM(ISNULL(s.totalrow, 0))	AS TotalRows
			
		FROM #tempSumTotal s
	END
		 
	DROP TABLE #tempCust
	DROP TABLE #ProductID
	DROP TABLE #bettype 
	DROP TABLE #Status
	DROP TABLE #recommend
	DROP TABLE #tempCustPaging
	DROP TABLE #custData
	DROP TABLE #tempSumTotal
	DROP TABLE #tempBettrans
	DROP TABLE #tempLRFCustTORpt
	--SET duration time
	SET @Duration = DATEDIFF(MS, @startTime, GETDATE())
GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_CustomerTurnOver] TO [bodbLicenseeNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_CustomerTurnOver] TO [vnteam] AS [dbo]
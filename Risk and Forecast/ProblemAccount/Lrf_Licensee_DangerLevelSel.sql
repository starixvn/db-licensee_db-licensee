/*<info serverAlias="DBACC-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_Licensee_DangerLevelSel]
	@FromDate	DATETIME,
	@ToDate		DATETIME,
	@Username	VARCHAR(50) = '',
	@AgentList	VARCHAR(MAX),
	@IsCheckAll	BIT,
	@OrderCol	TINYINT = 1,
	@SortType	TINYINT = 1,
	@PageSize	INT = 500,
	@PageIndex	INT = 1,
	@TotalItems	INT = 0 OUTPUT,
	@Langkey	VARCHAR(20) = 'en-US',
	@Sporttype	VARCHAR(50),
	@Level		VARCHAR(100)
AS
/*
	Created: 20221109@Tacy
	Task: LAP - Player Segmentation - Saba Virtual Setting 
	DB: DBACC/bodb02
		
	Revisions:
		- 20221109@Tacy: Create SP [RedmineID: #179078]

	Paramter's Explanations:
		@Sporttype	= "Soccer,Basketball"
		@Level		= None ~ 0, [1-15] : DangerLevel
		@OrderCol	= 1 : System ID
					= 2 : sort by external ID
					= 3 : MarkDate
					= 4 : Soccer
					= 5 : Basketball
		@SortType	= 1 : ASC
					= 2 : DESC	
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @RowCount INT, @RowStart INT, @RowEnd INT
	SELECT  @PageIndex = @PageIndex - 1, 
			@RowStart = @PageSize * @PageIndex + 1, 
			@RowEnd = @RowStart + @PageSize - 1 

	CREATE TABLE #TempAg (custid INT)
	CREATE TABLE #tblDangerLevel (DangerLevel TINYINT)

	CREATE TABLE #tblSabaSport (
			Sporttype			TINYINT,
			SportName			VARCHAR(50))

	CREATE TABLE #CustList (
			RowID				INT IDENTITY(1,1),
			CustId				INT PRIMARY KEY, 
			DangerLevel			INT, 
			SoccerLevel			TINYINT,
			BasketballLevel		TINYINT,
			UpdateSoccer		TINYINT, --1:Auto; 2:Manual
			UpdateBasketball	TINYINT,
			AgentID				INT, 
			username			VARCHAR(50), 
			username2			VARCHAR(50), 
			LastModifiedDate	DATETIME
	)
	
	CREATE TABLE #CustLog (
			CustId				INT, 
			NewLevel		TINYINT,
			OldLevel		TINYINT, 
			isSoccer			BIT,
			isManual			BIT,
			LogDate				DATETIME,
			PRIMARY KEY CLUSTERED (CustId, LogDate, isSoccer, isManual)
	)

	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@AgentList
	
		INSERT INTO #TempAg(CustId)
		SELECT AgentId
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
			,ErrMsg = N'Paramter invalid.'
		RETURN
	END CATCH;
	
	INSERT INTO #tblDangerLevel (DangerLevel)
	SELECT CASE WHEN ISNUMERIC(RTRIM(LTRIM(value)))=1 THEN RTRIM(LTRIM(value)) ELSE 0 END AS DangerLevel
	FROM string_split(@Level,',')

	INSERT INTO #tblSabaSport (SportName, Sporttype)
	SELECT	RTRIM(LTRIM(value)) AS SportName,
			CASE WHEN RTRIM(LTRIM(value))='Soccer' THEN 1 ELSE 2 END Sporttype
	FROM string_split(@Sporttype,',')

	IF @Username <> ''
	BEGIN
		INSERT INTO #CustList(custid, DangerLevel, SoccerLevel, BasketballLevel, AgentID, username, username2)
		SELECT ci.custid, ISNULL(c.DangerLevel,0) DangerLevel, t.soccer, t.basketball,
			ci.recommend, ci.username,
			SUBSTRING(ci.username2,  CHARINDEX('$',ci.username2)+1, LEN(ci.username2)-CHARINDEX('$',ci.username2)) AS username2
		FROM customer ci WITH(NOLOCK)
			INNER JOIN custinfo c WITH(NOLOCK) ON c.custid = ci.custid
			CROSS APPLY f_GetDangerLevelInfo(ISNULL(c.DangerLevel,0)) t
		WHERE ci.recommend IN (SELECT custid FROM #TempAg)
			AND (ci.username  LIKE @username + '%' OR ci.username2 LIKE '%$'+@username + '%')		
			AND ci.roleid = 1
	END
	ELSE
	BEGIN
		INSERT INTO #CustList(custid, DangerLevel, SoccerLevel, BasketballLevel, AgentID, username, username2)
		SELECT ci.custid, ISNULL(c.DangerLevel,0) DangerLevel, t.soccer, t.basketball,
			ci.recommend, ci.username,
			SUBSTRING(ci.username2,  CHARINDEX('$',ci.username2)+1, LEN(ci.username2)-CHARINDEX('$',ci.username2)) AS username2
		FROM customer ci WITH(NOLOCK)
			INNER JOIN custinfo c WITH(NOLOCK) ON c.custid = ci.custid
			CROSS APPLY f_GetDangerLevelInfo(ISNULL(c.DangerLevel,0)) t
		WHERE ci.recommend IN (SELECT custid FROM #TempAg)
			AND ci.roleid = 1
	END

	DECLARE @RowID INT = 1

	SELECT @TotalItems = COUNT(1) FROM #CustList

	
	WHILE (1=1)
	BEGIN
		--CustLog:
		INSERT INTO #CustLog (CustId, LogDate, NewLevel, OldLevel, isSoccer, isManual)
		SELECT TOP 1
				ul.custid,
				ul.logdate,
				x.Control.value('@DangerLevel', 'tinyint') AS NewLevel,
				x2.Control.value('@DangerLevel', 'tinyint') AS OldLevel,
				1 AS isSoccer,
				0 AS isManual
		FROM DBLOG.bodb_CustomerLog.dbo.UserLog_RunSP ul WITH(NOLOCK) 
			INNER JOIN #CustList cl ON cl.CustId=ul.custid
			CROSS APPLY (VALUES(CAST(ul.TrackingValue as xml))) AS v(Casted)
			CROSS APPLY (VALUES(CAST(ul.TrackingValue2 as xml))) AS v2(Casted)
			CROSS APPLY v.Casted.nodes('/R') AS x(Control)
			CROSS APPLY v2.Casted.nodes('/R') AS x2(Control)
		WHERE ul.ActionID=1191
			AND RowID=@RowID 
		ORDER BY ul.logdate DESC

		--Auto basketball
		INSERT INTO #CustLog (CustId, LogDate, NewLevel, OldLevel, isSoccer, isManual)
		SELECT TOP 1
				ul.custid,
				ul.logdate,
				x.Control.value('@DangerLevel', 'tinyint') AS NewLevel,
				x2.Control.value('@DangerLevel', 'tinyint') AS OldLevel,
				0 AS isSoccer,
				0 AS isManual
		FROM DBLOG.bodb_CustomerLog.dbo.UserLog_RunSP ul WITH(NOLOCK) 
			INNER JOIN #CustList cl ON cl.CustId=ul.custid
			CROSS APPLY (VALUES(CAST(ul.TrackingValue as xml))) AS v(Casted)
			CROSS APPLY (VALUES(CAST(ul.TrackingValue2 as xml))) AS v2(Casted)
			CROSS APPLY v.Casted.nodes('/R') AS x(Control)
			CROSS APPLY v2.Casted.nodes('/R') AS x2(Control)
		WHERE ul.ActionID=1192
			AND RowID=@RowID 
		ORDER BY ul.logdate DESC
		
		INSERT INTO #CustLog (CustId, LogDate, NewLevel, OldLevel, isSoccer, isManual)
		SELECT TOP 1
				ul.custid,
				ul.logdate,
				x.Control.value('@DangerLevel', 'tinyint') AS NewLevel,
				x2.Control.value('@DangerLevel', 'tinyint') AS OldLevel,
				1 AS isSoccer,
				1 AS isManual
		FROM DBLOG.bodb_CustomerLog.dbo.UserLog_RunSP ul WITH(NOLOCK) 
			INNER JOIN #CustList cl ON cl.CustId=ul.custid
			CROSS APPLY (VALUES(CAST(ul.TrackingValue as xml))) AS v(Casted)
			CROSS APPLY (VALUES(CAST(ul.TrackingValue2 as xml))) AS v2(Casted)
			CROSS APPLY v.Casted.nodes('/R') AS x(Control)
			CROSS APPLY v2.Casted.nodes('/R') AS x2(Control)
		WHERE ul.ActionID=1193
			AND RowID=@RowID 
			AND	--curr = new
				SoccerLevel = x.Control.value('@DangerLevel', 'tinyint')
			AND --new<>old
				x.Control.value('@DangerLevel', 'tinyint')
				<>
				x2.Control.value('@DangerLevel', 'tinyint') 
		ORDER BY ul.logdate DESC
		
		--Manual DangerLevel
		INSERT INTO #CustLog (CustId, LogDate, NewLevel, OldLevel, isSoccer, isManual)
		SELECT TOP 1
				ul.custid,
				ul.logdate,
				x.Control.value('@DangerLevel', 'tinyint') AS NewLevel,
				x2.Control.value('@DangerLevel', 'tinyint') AS OldLevel,
				0 AS isSoccer,
				1 AS isManual
		FROM DBLOG.bodb_CustomerLog.dbo.UserLog_RunSP ul WITH(NOLOCK) 
			INNER JOIN #CustList cl ON cl.CustId=ul.custid
			CROSS APPLY (VALUES(CAST(ul.TrackingValue as xml))) AS v(Casted)
			CROSS APPLY (VALUES(CAST(ul.TrackingValue2 as xml))) AS v2(Casted)
			CROSS APPLY v.Casted.nodes('/R') AS x(Control)
			CROSS APPLY v2.Casted.nodes('/R') AS x2(Control)
		WHERE ul.ActionID=1194
			AND RowID=@RowID 
			AND	--curr = new
				BasketballLevel = x.Control.value('@DangerLevel', 'tinyint')
			AND --new<>old
				x.Control.value('@DangerLevel', 'tinyint')
				<>
				x2.Control.value('@DangerLevel', 'tinyint')
		ORDER BY ul.logdate DESC
		
		SET @RowID = @RowID + 1
		
		IF @RowID>@TotalItems
			BREAK
	END
	
	;WITH tmp1 AS (
		SELECT tmp.CustId,
				--Soccer
				CASE WHEN t1.custid IS NOT NULL AND t1.isManual=0 THEN 1	--auto
					 WHEN t1.custid IS NOT NULL AND t1.isManual=1 THEN 2	--manual	
																  ELSE 0
				END UpdateSoccer,
				t1.LogDate AS ModifiedDate_sc,
				--Basketball
				CASE WHEN t2.custid IS NOT NULL AND t2.isManual=0 THEN 1	
					 WHEN t2.custid IS NOT NULL AND t2.isManual=1 THEN 2	
																  ELSE 0
				END UpdateBasketball,
				t2.LogDate AS ModifiedDate_bb
		FROM #CustList tmp
		OUTER APPLY (SELECT TOP 1 cl.CustId, cl.LogDate, isManual FROM #CustLog cl 
					 WHERE cl.custid=tmp.custid AND cl.isSoccer=1 
						AND tmp.SoccerLevel=cl.NewLevel
						AND cl.NewLevel<>cl.OldLevel
					 ORDER BY LogDate DESC) t1
		OUTER APPLY (SELECT TOP 1 cl.CustId, cl.LogDate, isManual FROM #CustLog cl 
					 WHERE cl.custid=tmp.custid AND cl.isSoccer=0 
						AND tmp.SoccerLevel=cl.NewLevel
						AND cl.NewLevel<>cl.OldLevel
					 ORDER BY LogDate DESC) t2
	),
	tmp2 AS (
		SELECT custid, UpdateSoccer, UpdateBasketball,
			CASE WHEN UpdateSoccer<>0 AND UpdateBasketball=0	THEN ModifiedDate_sc
					WHEN UpdateSoccer=0 AND UpdateBasketball<>0	THEN ModifiedDate_bb
					WHEN (UpdateSoccer=1 AND UpdateBasketball=1)
					  OR (UpdateSoccer=2 AND UpdateBasketball=2)THEN ModifiedDate_sc 
					WHEN ModifiedDate_sc>ModifiedDate_bb		THEN ModifiedDate_sc
																ELSE ModifiedDate_bb 
			END LastModifiedDate
		FROM tmp1 T1
		WHERE NOT (UpdateSoccer=0 AND UpdateBasketball=0)
	)
	UPDATE t
	SET	t.UpdateSoccer=t2.UpdateSoccer,
		t.UpdateBasketball=t2.UpdateBasketball,
		t.LastModifiedDate=t2.LastModifiedDate
	FROM #CustList t
	INNER JOIN tmp2 t2 ON t2.CustId=t.CustId
	
	--Filter: @LastModifiedDate
	DELETE FROM #CustList
	WHERE NOT (1 = CASE WHEN @IsCheckAll = 1 THEN 1  
						WHEN @IsCheckAll = 0 AND LastModifiedDate BETWEEN @FromDate AND @ToDate THEN 1
						ELSE 0 END)

	-- filter @SabaSports AND @DangerLevel
	IF EXISTS (SELECT 1 FROM #tblSabaSport WHERE Sporttype=1)
		AND NOT EXISTS (SELECT 1 FROM #tblSabaSport WHERE Sporttype=2)
		--select: Saba Soccer only
	BEGIN
		DELETE FROM #CustList
		WHERE NOT (UpdateSoccer<>0 AND UpdateBasketball=0
			AND SoccerLevel IN (SELECT DangerLevel FROM #tblDangerLevel))
	END
	ELSE IF NOT EXISTS (SELECT 1 FROM #tblSabaSport WHERE Sporttype=1)
		AND EXISTS (SELECT 1 FROM #tblSabaSport WHERE Sporttype=2)
		--select: Saba Basketball only
	BEGIN
		DELETE FROM #CustList
		WHERE NOT (UpdateSoccer=0 AND UpdateBasketball<>0
			AND BasketballLevel IN (SELECT DangerLevel FROM #tblDangerLevel))
	END
	ELSE --select all sports
	BEGIN
		DELETE FROM #CustList
		WHERE NOT ((SoccerLevel IN (SELECT DangerLevel FROM #tblDangerLevel) 
			OR BasketballLevel IN (SELECT DangerLevel FROM #tblDangerLevel)))
	END

	SELECT @TotalItems = COUNT(1) FROM #CustList

	IF @OrderCol IN (1,2)
	BEGIN
		;WITH t1 AS(
			SELECT *, 
				CASE WHEN @OrderCol = 1 THEN username 
					 WHEN @OrderCol = 2 THEN username2 
				END OrderCol
			FROM #CustList
		),
		t2 AS (
			SELECT *, ROW_NUMBER () OVER (ORDER BY CASE WHEN @SortType = 1 THEN OrderCol END ASC,	
													CASE WHEN @SortType = 2 THEN OrderCol END DESC ) rn
			FROM t1
		)
		SELECT t2.*
		FROM t2 
		WHERE rn BETWEEN @rowstart AND @rowend
		ORDER BY rn ASC
	END
	ELSE IF @OrderCol=3
	BEGIN
		;WITH t1 AS (
			SELECT *, ROW_NUMBER () OVER (ORDER BY CASE WHEN @SortType = 1 THEN LastModifiedDate END ASC,	
													CASE WHEN @SortType = 2 THEN LastModifiedDate END DESC ) rn
			FROM #CustList
		)
		SELECT t1.*
		FROM T1 
		WHERE rn BETWEEN @rowstart AND @rowend
		ORDER BY rn ASC
	END
	ELSE
	BEGIN
		;WITH t1 AS(
			SELECT *, 
				CASE WHEN @OrderCol = 1 THEN username 
					 WHEN @OrderCol = 2 THEN username2 
					 WHEN @OrderCol = 4 THEN SoccerLevel 
					 WHEN @OrderCol = 5 THEN BasketballLevel 
				END OrderCol
			FROM #CustList
		),
		t2 AS (
			SELECT *, ROW_NUMBER () OVER (ORDER BY CASE WHEN @SortType = 1 THEN OrderCol END ASC,	
													CASE WHEN @SortType = 2 THEN OrderCol END DESC ) rn
			FROM t1
		)
		SELECT t2.*
		FROM t2 
		WHERE rn BETWEEN @rowstart AND @rowend
		ORDER BY rn ASC
	END

	DROP TABLE #tblDangerLevel, #CustList, #CustLog, #tblSabaSport, #TempAg
END
GO
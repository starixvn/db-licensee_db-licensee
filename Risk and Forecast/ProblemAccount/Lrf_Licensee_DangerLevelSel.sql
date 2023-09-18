/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="bodbLicenseeNet" viewers="" isFunction="0"></info>*/
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
	DB: DBLOG/bodb_CustomerLog
		
	Revisions:
		- 20221109@Tacy: Create SP [RedmineID: #179078]
		- 20230228@Tacy: HF - LAP - Player Segmentation - Saba Virtual Setting - Duplicate datalog [RedmineID: #184368]
		- 20230824@Tacy: LAP - Player Segmentation - Saba Virtual Setting - Enhance performance [RedmineID: #193149]

	Paramter's Explanations:
		@Sporttype	= "1,2"
		@Level		= [0-15] : DangerLevel
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
	CREATE TABLE #tblSabaSport (Sporttype TINYINT)

	CREATE TABLE #CustList (
			CustId				INT PRIMARY KEY, 
			DangerLevel			INT, 
			SoccerLevel			TINYINT,
			BasketballLevel		TINYINT,
			UpdateSoccer		BIT, --1:Auto; 2:Manual
			UpdateBasketball	BIT,
			AgentID				INT, 
			username			VARCHAR(50), 
			username2			VARCHAR(50), 
			LastModifiedDate	DATETIME,
			ActionID			INT
	)

	CREATE TABLE #CustLog (
			CustId			INT, 
			TrackingValue	NVARCHAR(MAX),
			NewLevel		TINYINT,
			LogDate			DATETIME,
			ActionID		INT,
			PRIMARY KEY CLUSTERED (CustId, LogDate, ActionID)
	)
	
	CREATE TABLE #CustLog_Archive (
			CustId			INT, 
			ActionID		INT,
			PRIMARY KEY CLUSTERED (CustId, ActionID)
	)

	CREATE TABLE #CustLog_ArchiveTmp (
			CustId			INT, 
			ActionID		INT,
			PRIMARY KEY CLUSTERED (CustId, ActionID)
	)

	DECLARE @ActionLog TABLE (ActionID SMALLINT)

	DECLARE @__archiveDate DATETIME, @MinLogDate DATETIME
	
	SELECT @__archiveDate = DATEADD(DAY, 1, bodb_CustomerLog.dbo.f_CustomerLog_GetArchiveDate())
	
	SELECT @MinLogDate='2022-12-14'

	IF @IsCheckAll=0
	BEGIN
		IF @ToDate < @MinLogDate
			RETURN
		IF @FromDate < @MinLogDate
			SET @FromDate=@MinLogDate
	END
	ELSE
	BEGIN
		SELECT @FromDate=@MinLogDate, @ToDate=GETDATE()
	END

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
	
	INSERT INTO @ActionLog (ActionID)
	SELECT 1191 UNION ALL
	SELECT 1192 UNION ALL
	SELECT 1193 UNION ALL
	SELECT 1194 

	INSERT INTO #tblDangerLevel (DangerLevel)
	SELECT RTRIM(LTRIM(value)) AS DangerLevel
	FROM string_split(@Level,',')

	INSERT INTO #tblSabaSport (Sporttype)
	SELECT	RTRIM(LTRIM(value)) AS Sporttype
	FROM string_split(@Sporttype,',')

	IF @Username <> ''
	BEGIN
		INSERT INTO #CustList(custid, DangerLevel, SoccerLevel, BasketballLevel, AgentID, username, username2)
		SELECT ci.custid, ISNULL(c.DangerLevel,0) DangerLevel, t.soccer, t.basketball,
			ci.recommend, ci.username,
			SUBSTRING(ci.username2,  CHARINDEX('$',ci.username2)+1, LEN(ci.username2)-CHARINDEX('$',ci.username2)) AS username2
		FROM bodb02.dbo.customer ci WITH(NOLOCK)
			INNER JOIN bodb02.dbo.custinfo c WITH(NOLOCK) ON c.custid = ci.custid
			CROSS APPLY f_GetDangerLevelInfo(ISNULL(c.DangerLevel,0)) t
		WHERE ci.recommend IN (SELECT custid FROM #TempAg)
			AND (ci.username  LIKE @username + '%' OR ci.username2 LIKE '%$'+@username + '%')		
			AND ci.roleid = 1
			AND ((soccer IN (SELECT DangerLevel FROM #tblDangerLevel) 
			OR basketball IN (SELECT DangerLevel FROM #tblDangerLevel)))
	END
	ELSE
	BEGIN
		INSERT INTO #CustList(custid, DangerLevel, SoccerLevel, BasketballLevel, AgentID, username, username2)
		SELECT ci.custid, ISNULL(c.DangerLevel,0) DangerLevel, t.soccer, t.basketball,
			ci.recommend, ci.username,
			SUBSTRING(ci.username2,  CHARINDEX('$',ci.username2)+1, LEN(ci.username2)-CHARINDEX('$',ci.username2)) AS username2
		FROM bodb02.dbo.customer ci WITH(NOLOCK)
			INNER JOIN bodb02.dbo.custinfo c WITH(NOLOCK) ON c.custid = ci.custid
			CROSS APPLY f_GetDangerLevelInfo(ISNULL(c.DangerLevel,0)) t
		WHERE ci.recommend IN (SELECT custid FROM #TempAg)
			AND ci.roleid = 1
			AND ((soccer IN (SELECT DangerLevel FROM #tblDangerLevel) 
			OR basketball IN (SELECT DangerLevel FROM #tblDangerLevel)))
	END
	
	--Get UserLog
	;WITH UserLog AS( 
		SELECT	ul.custid,
				ul.ActionID,
				ul.logdate,
				ul.TrackingValue,
				ROW_NUMBER () OVER (PARTITION BY cl.CustId, ul.ActionID ORDER BY ul.logdate DESC) rn
		FROM UserLog_RunSP ul WITH(NOLOCK) 
			INNER JOIN #CustList cl ON cl.CustId=ul.custid
		WHERE ul.ActionID BETWEEN 1191 AND 1194
		AND logdate>=@FromDate
	)
	INSERT INTO #CustLog (CustId, LogDate, TrackingValue, ActionID)
	SELECT CustId, LogDate, TrackingValue, ActionID
	FROM UserLog
	WHERE rn=1

	--Get UserLog_Archive
	IF NOT @FromDate >= @__archiveDate
	BEGIN
		INSERT INTO #CustLog_Archive (CustId, ActionID)
		SELECT cl.CustId, al.ActionID
		FROM #CustList cl
		CROSS APPLY @ActionLog al
		OUTER APPLY (SELECT clg.CustId FROM #CustLog clg WHERE cl.CustId=clg.CustId AND al.ActionID=clg.ActionID) t
		WHERE t.CustId IS NULL

		WHILE (1=1)
		BEGIN
			TRUNCATE TABLE #CustLog_ArchiveTmp

			DELETE TOP (2000) T
			OUTPUT deleted.CustId, deleted.ActionID INTO #CustLog_ArchiveTmp
			FROM #CustLog_Archive T

			IF @@ROWCOUNT=0
				BREAK;

			;WITH UserLog_Archive AS( 
				SELECT	ul.custid,
						ul.ActionID,
						ul.logdate
				FROM #CustLog_ArchiveTmp cl
				CROSS APPLY (SELECT TOP 1 ul.custid, ul.ActionID, ul.logdate
								FROM bodb_CustomerLog_Archive.dbo.UserLog_RunSP ul WITH(NOLOCK)
								WHERE cl.CustId=ul.custid
								AND ul.ActionID = cl.ActionID
								AND UL.logdate>=@FromDate
								ORDER BY logdate DESC) ul
				WHERE NOT EXISTS (SELECT 1 
								 FROM #CustLog t2 
								 WHERE t2.CustId=ul.custid 
								 AND t2.ActionID=ul.ActionID 
								)
		
			)
			INSERT INTO #CustLog (CustId, LogDate, ActionID)
			SELECT CustId, LogDate, ActionID
			FROM UserLog_Archive
		END

		--Update: Trackingvalue
		UPDATE t
		SET t.TrackingValue = ul.TrackingValue
		FROM #CustLog t
			INNER JOIN  bodb_CustomerLog_Archive.dbo.UserLog_RunSP ul WITH(NOLOCK) 
				ON t.CustId = ul.custid
				AND t.ActionID = ul.ActionID
				AND t.LogDate = ul.logdate
		WHERE t.TrackingValue IS NULL
			AND ul.logdate >= @FromDate
	END

	--Update: NewLevel
	UPDATE clg
	SET clg.NewLevel=x.Control.value('@DangerLevel', 'tinyint')
	FROM #CustLog clg
	CROSS APPLY (VALUES(CAST(clg.TrackingValue as xml))) AS v(Casted)
	CROSS APPLY v.Casted.nodes('/R') AS x(Control)

	--Get LastModifiedDate
	UPDATE cl
	SET	cl.LastModifiedDate=t1.LogDate,
		cl.ActionID=t1.ActionID
	FROM #CustList cl
	CROSS APPLY (SELECT TOP 1 t.CustId, t.LogDate, t.ActionID
				 FROM #CustLog t 
				 WHERE cl.custid=t.custid 
				 ORDER BY LogDate DESC) t1

	--Filter: @LastModifiedDate
	DELETE FROM #CustList
	WHERE NOT (1 = CASE WHEN LastModifiedDate BETWEEN @FromDate AND @ToDate	THEN 1  
						WHEN @IsCheckAll = 1 AND LastModifiedDate IS NULL 
							AND (SoccerLevel=0 OR BasketballLevel=0)		THEN 1  
						ELSE 0 END)

	--UpdateSoccer/Basketball???
	;WITH tmp1 AS (
		SELECT tmp.CustId,
				--Soccer
				CASE WHEN tmp.ActionID IN (1191,1193)							THEN 1
					 WHEN tmp.ActionID=1192 
						AND t1.CustId IS NOT NULL AND t1.ActionID=1191
						AND DATEDIFF(HH, tmp.LastModifiedDate, t1.LogDate)=0	THEN 1
					 ELSE 0
				END UpdateSoccer,
				CASE WHEN tmp.ActionID IN (1192,1194)							THEN 1	
					 WHEN tmp.ActionID=1191 
						AND t2.CustId IS NOT NULL AND t2.ActionID=1192
						AND DATEDIFF(HH, tmp.LastModifiedDate, t2.LogDate)=0	THEN 1
					 ELSE 0
				END UpdateBasketball
		FROM #CustList tmp
		OUTER APPLY (SELECT TOP 1 cl.CustId, cl.LogDate, cl.ActionID FROM #CustLog cl 
					 WHERE cl.custid=tmp.custid AND cl.ActionID IN (1191,1193) 
						AND tmp.SoccerLevel=cl.NewLevel
					 ORDER BY LogDate DESC) t1
		OUTER APPLY (SELECT TOP 1 cl.CustId, cl.LogDate, cl.ActionID FROM #CustLog cl 
					 WHERE cl.custid=tmp.custid AND cl.ActionID IN (1192,1194) 
						AND tmp.BasketballLevel=cl.NewLevel
					 ORDER BY LogDate DESC) t2
	)
	UPDATE t
	SET	t.UpdateSoccer=t1.UpdateSoccer,
		t.UpdateBasketball=t1.UpdateBasketball
	FROM #CustList t
	INNER JOIN tmp1 t1 ON t1.CustId=t.CustId

	-- filter @SabaSports AND @DangerLevel
	IF EXISTS (SELECT 1 FROM #tblSabaSport WHERE Sporttype=1)
		AND NOT EXISTS (SELECT 1 FROM #tblSabaSport WHERE Sporttype=2)
		--select: Saba Soccer
	BEGIN
		DELETE FROM #CustList
		WHERE (UpdateSoccer=0 AND LastModifiedDate IS NOT NULL)	--GET ALL
			OR SoccerLevel NOT IN (SELECT DangerLevel FROM #tblDangerLevel)	
	END
	ELSE IF NOT EXISTS (SELECT 1 FROM #tblSabaSport WHERE Sporttype=1)
		AND EXISTS (SELECT 1 FROM #tblSabaSport WHERE Sporttype=2)
		--select: Saba Basketball
	BEGIN
		DELETE FROM #CustList
		WHERE (UpdateBasketball=0 AND LastModifiedDate IS NOT NULL)	--GET ALL
			OR BasketballLevel NOT IN (SELECT DangerLevel FROM #tblDangerLevel)
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
		SELECT CustId, SoccerLevel, BasketballLevel, AgentID, username, username2, LastModifiedDate
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
		SELECT CustId, SoccerLevel, BasketballLevel, AgentID, username, username2, LastModifiedDate
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
		SELECT CustId, SoccerLevel, BasketballLevel, AgentID, username, username2, LastModifiedDate
		FROM t2 
		WHERE rn BETWEEN @rowstart AND @rowend
		ORDER BY rn ASC
	END

	DROP TABLE #tblDangerLevel, #CustList, #CustLog, #tblSabaSport, #TempAg, #CustLog_Archive, #CustLog_ArchiveTmp
END
GO
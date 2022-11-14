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
	SELECT  @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1 

	CREATE TABLE #TempAg (custid INT)
	CREATE TABLE #tblDangerLevel (DangerLevel TINYINT)

	CREATE TABLE #tblSabaSport (
			Sporttype			TINYINT,
			SportName			VARCHAR(50))

	CREATE TABLE #CustList (
			CustId				INT PRIMARY KEY, 
			DangerLevel			INT, 
			SoccerLevel			TINYINT,
			BasketballLevel		TINYINT,
			UpdateSoccer		TINYINT, --1:Auto; 2:Manual
			UpdateBasketball	TINYINT,
			AgentID				INT, 
			username			VARCHAR(50), 
			username2			VARCHAR(50), 
			LastModifiedDate	DATETIME)
	
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
	SELECT RTRIM(LTRIM(value)) AS DangerLevel
	FROM string_split(@Level,',')

	INSERT INTO #tblSabaSport (SportName, Sporttype)
	SELECT	RTRIM(LTRIM(value)) AS SportName,
			CASE WHEN RTRIM(LTRIM(value))='Soccer' THEN 1 ELSE 2 END Sporttype
	FROM string_split(@Sporttype,',')

	IF @Username <> ''
	BEGIN
		;WITH tmp1 AS (
			SELECT ci.custid, ISNULL(c.DangerLevel,0) DangerLevel, t.soccer, t.basketball,
				ci.recommend, ci.username,
				SUBSTRING(ci.username2,  CHARINDEX('$',ci.username2)+1, LEN(ci.username2)-CHARINDEX('$',ci.username2)) AS username2,
				--Soccer
				CASE WHEN	(t1.custid IS NOT NULL	AND t3.custid IS NULL) OR 
							(t1.custid IS NOT NULL	AND t3.custid IS NOT NULL AND t1.logdate>t3.logdate) THEN 1	--auto
					 WHEN	(t1.custid IS NULL		AND t3.custid IS NOT NULL) OR 
							(t1.custid IS NOT NULL	AND t3.custid IS NOT NULL AND t1.logdate<t3.logdate) THEN 2	--manual	
																										 ELSE 0
				END UpdateSoccer,
				CASE WHEN	(t1.custid IS NOT NULL	AND t3.custid IS NULL) OR 
							(t1.custid IS NOT NULL	AND t3.custid IS NOT NULL AND t1.logdate>t3.logdate) THEN t1.logdate
					 WHEN	(t1.custid IS NULL		AND t3.custid IS NOT NULL) OR 
							(t1.custid IS NOT NULL	AND t3.custid IS NOT NULL AND t1.logdate<t3.logdate) THEN t3.logdate	
				END ModifiedDate_sc,
				--Basketball
				CASE WHEN	(t2.custid IS NOT NULL	AND t4.custid IS NULL) OR 
							(t2.custid IS NOT NULL	AND t4.custid IS NOT NULL AND t2.logdate>t4.logdate) THEN 1
					 WHEN	(t2.custid IS NULL		AND t4.custid IS NOT NULL) OR 
							(t2.custid IS NOT NULL	AND t4.custid IS NOT NULL AND t2.logdate<t4.logdate) THEN 2	
																										 ELSE 0
				END UpdateBasketball,
				CASE WHEN	(t2.custid IS NOT NULL	AND t4.custid IS NULL) OR 
							(t2.custid IS NOT NULL	AND t4.custid IS NOT NULL AND t2.logdate>t4.logdate) THEN t2.logdate
					 WHEN	(t2.custid IS NULL		AND t4.custid IS NOT NULL) OR 
							(t2.custid IS NOT NULL	AND t4.custid IS NOT NULL AND t2.logdate<t4.logdate) THEN t4.logdate	
				END ModifiedDate_bb
			FROM customer ci WITH(NOLOCK)
				INNER JOIN custinfo c WITH(NOLOCK) ON c.custid = ci.custid
				CROSS APPLY f_GetDangerLevelInfo(ISNULL(c.DangerLevel,0)) t
				OUTER APPLY (SELECT TOP 1 ul.custid, ul.logdate FROM DBLOG.bodb_CustomerLog.dbo.UserLog_RunSP ul WITH(NOLOCK) 
							 WHERE ul.custid=ci.custid
								AND ActionID=1191	-- Auto Update Saba Soccer DangerLevel
							 ORDER BY logdate DESC) t1
				OUTER APPLY (SELECT TOP 1 ul.custid, ul.logdate FROM DBLOG.bodb_CustomerLog.dbo.UserLog_RunSP ul WITH(NOLOCK) 
							 WHERE ul.custid=ci.custid
								AND ActionID=1192	-- Auto Update Saba Basketball DangerLevel
							 ORDER BY logdate DESC) t2
				OUTER APPLY (SELECT TOP 1 ul.custid, ul.logdate FROM DBLOG.bodb_CustomerLog.dbo.UserLog_RunSP ul WITH(NOLOCK) 
							 WHERE ul.custid=ci.custid
								AND ActionID=1193	-- Manual Update Saba Soccer DangerLevel
							 ORDER BY logdate DESC) t3
				OUTER APPLY (SELECT TOP 1 ul.custid, ul.logdate FROM DBLOG.bodb_CustomerLog.dbo.UserLog_RunSP ul WITH(NOLOCK) 
							 WHERE ul.custid=ci.custid
								AND ActionID=1194	-- Manual Update Saba Basketball DangerLevel
							 ORDER BY logdate DESC) t4
			WHERE ci.recommend IN (SELECT custid FROM #TempAg)
				AND (ci.username  LIKE @username + '%' OR ci.username2 LIKE '%$'+@username + '%')		
				AND ci.roleid = 1
		),
		tmp2 AS (
			SELECT custid, DangerLevel, soccer, basketball, UpdateSoccer, UpdateBasketball, recommend, username, username2,
				CASE WHEN UpdateSoccer<>0 AND UpdateBasketball=0 THEN ModifiedDate_sc
					 WHEN UpdateSoccer=0 AND UpdateBasketball<>0 THEN ModifiedDate_bb
					 WHEN ModifiedDate_sc>ModifiedDate_bb		 THEN ModifiedDate_sc 
																 ELSE ModifiedDate_bb 
				END LastModifiedDate
			FROM tmp1 T1
			WHERE NOT (UpdateSoccer=0 AND UpdateBasketball=0)
		)
		INSERT INTO #CustList(custid, DangerLevel, SoccerLevel, BasketballLevel, UpdateSoccer, UpdateBasketball, AgentID, username, username2, LastModifiedDate)
		SELECT custid, DangerLevel, soccer, basketball, UpdateSoccer, UpdateBasketball, recommend, username, username2, LastModifiedDate
		FROM tmp2
		WHERE (soccer IN (SELECT DangerLevel FROM #tblDangerLevel) OR
			   basketball IN (SELECT DangerLevel FROM #tblDangerLevel))
			AND 1 = CASE WHEN @IsCheckAll = 1 THEN 1  
						 WHEN @IsCheckAll = 0 AND LastModifiedDate BETWEEN @FromDate AND @ToDate THEN 1
						 ELSE 0 END	
	END
	ELSE
	BEGIN
		;WITH tmp1 AS (
			SELECT ci.custid, ISNULL(c.DangerLevel,0) DangerLevel, t.soccer, t.basketball,
				ci.recommend, ci.username,
				SUBSTRING(ci.username2,  CHARINDEX('$',ci.username2)+1, LEN(ci.username2)-CHARINDEX('$',ci.username2)) AS username2,
				--Soccer
				CASE WHEN	(t1.custid IS NOT NULL	AND t3.custid IS NULL) OR 
							(t1.custid IS NOT NULL	AND t3.custid IS NOT NULL AND t1.logdate>t3.logdate) THEN 1	--auto
					 WHEN	(t1.custid IS NULL		AND t3.custid IS NOT NULL) OR 
							(t1.custid IS NOT NULL	AND t3.custid IS NOT NULL AND t1.logdate<t3.logdate) THEN 2	--manual	
																										 ELSE 0
				END UpdateSoccer,
				CASE WHEN	(t1.custid IS NOT NULL	AND t3.custid IS NULL) OR 
							(t1.custid IS NOT NULL	AND t3.custid IS NOT NULL AND t1.logdate>t3.logdate) THEN t1.logdate
					 WHEN	(t1.custid IS NULL		AND t3.custid IS NOT NULL) OR 
							(t1.custid IS NOT NULL	AND t3.custid IS NOT NULL AND t1.logdate<t3.logdate) THEN t3.logdate	
				END ModifiedDate_sc,
				--Basketball
				CASE WHEN	(t2.custid IS NOT NULL	AND t4.custid IS NULL) OR 
							(t2.custid IS NOT NULL	AND t4.custid IS NOT NULL AND t2.logdate>t4.logdate) THEN 1
					 WHEN	(t2.custid IS NULL		AND t4.custid IS NOT NULL) OR 
							(t2.custid IS NOT NULL	AND t4.custid IS NOT NULL AND t2.logdate<t4.logdate) THEN 2	
																										 ELSE 0
				END UpdateBasketball,
				CASE WHEN	(t2.custid IS NOT NULL	AND t4.custid IS NULL) OR 
							(t2.custid IS NOT NULL	AND t4.custid IS NOT NULL AND t2.logdate>t4.logdate) THEN t2.logdate
					 WHEN	(t2.custid IS NULL		AND t4.custid IS NOT NULL) OR 
							(t2.custid IS NOT NULL	AND t4.custid IS NOT NULL AND t2.logdate<t4.logdate) THEN t4.logdate	
				END ModifiedDate_bb
			FROM customer ci WITH(NOLOCK)
				INNER JOIN custinfo c WITH(NOLOCK) ON c.custid = ci.custid
				CROSS APPLY f_GetDangerLevelInfo(ISNULL(c.DangerLevel,0)) t
				OUTER APPLY (SELECT TOP 1 ul.custid, ul.logdate FROM DBLOG.bodb_CustomerLog.dbo.UserLog_RunSP ul WITH(NOLOCK) 
							 WHERE ul.custid=ci.custid
								AND ActionID=1191	-- Auto Update Saba Soccer DangerLevel
							 ORDER BY logdate DESC) t1
				OUTER APPLY (SELECT TOP 1 ul.custid, ul.logdate FROM DBLOG.bodb_CustomerLog.dbo.UserLog_RunSP ul WITH(NOLOCK) 
							 WHERE ul.custid=ci.custid
								AND ActionID=1192	-- Auto Update Saba Basketball DangerLevel
							 ORDER BY logdate DESC) t2
				OUTER APPLY (SELECT TOP 1 ul.custid, ul.logdate FROM DBLOG.bodb_CustomerLog.dbo.UserLog_RunSP ul WITH(NOLOCK) 
							 WHERE ul.custid=ci.custid
								AND ActionID=1193	-- Manual Update Saba Soccer DangerLevel
							 ORDER BY logdate DESC) t3
				OUTER APPLY (SELECT TOP 1 ul.custid, ul.logdate FROM DBLOG.bodb_CustomerLog.dbo.UserLog_RunSP ul WITH(NOLOCK) 
							 WHERE ul.custid=ci.custid
								AND ActionID=1194	-- Manual Update Saba Basketball DangerLevel
							 ORDER BY logdate DESC) t4
			WHERE ci.recommend IN (SELECT custid FROM #TempAg)
				AND ci.roleid = 1
		),
		tmp2 AS (
			SELECT custid, DangerLevel, soccer, basketball, UpdateSoccer, UpdateBasketball, recommend, username, username2,
				CASE WHEN UpdateSoccer<>0 AND UpdateBasketball=0 THEN ModifiedDate_sc
					 WHEN UpdateSoccer=0 AND UpdateBasketball<>0 THEN ModifiedDate_bb
					 WHEN ModifiedDate_sc>ModifiedDate_bb		 THEN ModifiedDate_sc 
																 ELSE ModifiedDate_bb 
				END LastModifiedDate
			FROM tmp1 T1
			WHERE NOT (UpdateSoccer=0 AND UpdateBasketball=0)
		)
		INSERT INTO #CustList(custid, DangerLevel, SoccerLevel, BasketballLevel, UpdateSoccer, UpdateBasketball, AgentID, username, username2, LastModifiedDate)
		SELECT custid, DangerLevel, soccer, basketball, UpdateSoccer, UpdateBasketball, recommend, username, username2, LastModifiedDate
		FROM tmp2
		WHERE (soccer IN (SELECT DangerLevel FROM #tblDangerLevel) OR
			   basketball IN (SELECT DangerLevel FROM #tblDangerLevel))
			AND 1 = CASE WHEN @IsCheckAll = 1 THEN 1  
						 WHEN @IsCheckAll = 0 AND LastModifiedDate BETWEEN @FromDate AND @ToDate THEN 1
						 ELSE 0 END	
	END

	-- filter @SabaSports AND @DangerLevel
	IF EXISTS (SELECT 1 FROM #tblSabaSport WHERE Sporttype=1)
		AND NOT EXISTS (SELECT 1 FROM #tblSabaSport WHERE Sporttype=2)
		--select: Saba Soccer only
	BEGIN
		DELETE from #CustList
		WHERE (UpdateSoccer=0 AND UpdateBasketball<>0)	--upd basketball only
			OR (SoccerLevel NOT IN (SELECT DangerLevel FROM #tblDangerLevel))
	END
	ELSE IF NOT EXISTS (SELECT 1 FROM #tblSabaSport WHERE Sporttype=1)
		AND EXISTS (SELECT 1 FROM #tblSabaSport WHERE Sporttype=2)
		--select: Saba Basketball only
	BEGIN
		DELETE from #CustList
		WHERE (UpdateSoccer<>0 AND UpdateBasketball=0)	--upd soccer only
			OR (BasketballLevel NOT IN (SELECT DangerLevel FROM #tblDangerLevel))
	END

	SELECT @TotalItems = COUNT(1) FROM #CustList

	;WITH t1 AS(
		SELECT *, 
			CASE WHEN @OrderCol = 1 THEN username 
				 WHEN @OrderCol = 2 THEN username2 
				 WHEN @OrderCol = 3 THEN LastModifiedDate 
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

	DROP TABLE #tblDangerLevel
	DROP TABLE #CustList
	DROP TABLE #tblSabaSport
END
GO
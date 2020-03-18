/*<info serverAlias="DBACC-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE Lrf_ProblemAccount_LicenseeProblemPlayerSel
	@FromDate	DATETIME,
	@ToDate		DATETIME,
	@Username	VARCHAR(50) = '',
	@AgentList	VARCHAR(MAX),
	@IsCheckAll	BIT,
	@OrderCol	TINYINT = 1,
	@SortType	TINYINT = 1,
	
	@PageSize	INT = 500,
	@PageIndex	INT = 1,
	@TotalItems	INT = 0 OUTPUT
AS
	/*
		Created: 20200211@Johnson
		Task: Problem Account - Licensee Problem player 
		DB: DBACC/bodb02
		
		Revisions:
			- 20200211@Johnson: initial sp [redmine:#128077]
			
		Paramter's Explanations:
			@OrderCol = 1: System ID
						= 2: sort by external ID
						= 3: MarkDate
			@SortType = 1: ASC, 2: DESC			
	*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @RowCount INT, @RowStart INT, @RowEnd INT
	SELECT  @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1 

	CREATE TABLE #TempAg (custid INT)
	CREATE TABLE #CustList (CustId INT PRIMARY KEY, CreatedDate DATETIME, username VARCHAR(50), username2 VARCHAR(50), isMarkVoid BIT)
	
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
	
	IF @Username <> ''
	BEGIN
		INSERT INTO #CustList(custid,CreatedDate,username,username2,isMarkVoid)
		SELECT ci.custid,p.CreatedDate, username, 
			SUBSTRING(ci.username2,  CHARINDEX('$',ci.username2)+1, LEN(ci.username2)-CHARINDEX('$',ci.username2)) AS username2,
			ISNULL(isMarkVoid,0)
		FROM customer ci WITH(NOLOCK)
			INNER JOIN ProblemAccount p WITH(NOLOCK) ON ci.custid = p.custid
		WHERE ci.recommend IN (SELECT custid FROM #TempAg)
			AND roleid = 1
			AND (username  LIKE @username + '%' OR username2 LIKE '%$'+@username + '%')			
	END
	ELSE
	BEGIN
		INSERT INTO #CustList(custid,CreatedDate,username,username2,isMarkVoid)
		SELECT ci.custid,p.CreatedDate, username, 
			SUBSTRING(ci.username2,  CHARINDEX('$',ci.username2)+1, LEN(ci.username2)-CHARINDEX('$',ci.username2)) AS username2,
			ISNULL(isMarkVoid,0)
		FROM customer ci WITH(NOLOCK)
			INNER JOIN ProblemAccount p WITH(NOLOCK) ON ci.custid = p.custid
		WHERE ci.recommend IN (SELECT custid FROM #TempAg)
			AND roleid = 1
	END
	
	;WITH t AS (
		SELECT c.CustId, MIN(tv.CreatedDate) CreatedDate		
		FROM #CustList c
			INNER JOIN dbo.TicketVoiding_VoidedTransaction tv WITH (NOLOCK) ON c.CustId = tv.custid			
		WHERE IssueTypeId = 11	
		GROUP BY c.CustId
	)
	UPDATE c
	SET c.CreatedDate = CASE WHEN c.CreatedDate < t.CreatedDate THEN c.CreatedDate ELSE t.CreatedDate END
	FROM #CustList c
		INNER JOIN t ON c.custid = t.custid
		
	IF @IsCheckAll = 0
	BEGIN
		DELETE #CustList
		WHERE CreatedDate NOT BETWEEN @FromDate AND @ToDate
	END
	
	SELECT @TotalItems = COUNT(1) FROM #CustList
	
	IF @OrderCol IN (1,2)
	BEGIN
		;WITH t1 AS(
		SELECT *, CASE WHEN @OrderCol = 1 THEN username ELSE username2 END OrderCol
		FROM #CustList
		),
		t2 AS (
		SELECT *, ROW_NUMBER () OVER (ORDER BY CASE WHEN @SortType = 1 THEN OrderCol END ASC,	
												CASE WHEN @SortType = 2 THEN OrderCol END DESC ) rn
		FROM t1
		)
		SELECT t2.*, CASE WHEN d.custid IS NULL THEN 0 ELSE 1 END as isVIP
		FROM t2 
			LEFT JOIN Dep_CustVIP d WITH(NOLOCK) ON t2.custid = d.custid
		WHERE rn BETWEEN @rowstart AND @rowend
		ORDER BY rn ASC
	END
	ELSE
	BEGIN
		;WITH t AS (
		SELECT *, ROW_NUMBER () OVER (ORDER BY CASE WHEN @SortType = 1 THEN CreatedDate END ASC,	
												CASE WHEN @SortType = 2 THEN CreatedDate END DESC) rn
		FROM #CustList
		)
		SELECT t.*, CASE WHEN d.custid IS NULL THEN 0 ELSE 1 END as isVIP
		FROM t
			LEFT JOIN Dep_CustVIP d WITH(NOLOCK) ON t.custid = d.custid
		WHERE rn BETWEEN @rowstart AND @rowend
		ORDER BY rn ASC
	END	
END
GO	

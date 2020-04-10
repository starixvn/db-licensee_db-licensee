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
	@TotalItems	INT = 0 OUTPUT,
	@Language	VARCHAR(10) = 'E',
	@Currency	INT = 0,
	@ReasonGroupID	TINYINT = 0
AS
	/*
		Created: 20200211@Johnson
		Task: Problem Account - Licensee Problem player 
		DB: DBACC/bodb02
		
		Revisions:
			- 20200211@Johnson: initial sp [redmine:#128077]
			- 20200410@Eden: LAP - Player Segmentation [redmine:#131929]
			
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
	CREATE TABLE #CustList (CustId INT PRIMARY KEY, CreatedDate DATETIME, username VARCHAR(50), username2 VARCHAR(50), isMarkVoid BIT, MaxBet MONEY, MaxPerEvent MONEY, ReasonID TINYINT ,Reason NVARCHAR(4000))
	
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
		INSERT INTO #CustList(custid,CreatedDate,username,username2,isMarkVoid,MaxBet,MaxPerEvent,ReasonID)
		SELECT ci.custid,p.CreatedDate, username,
			SUBSTRING(ci.username2,  CHARINDEX('$',ci.username2)+1, LEN(ci.username2)-CHARINDEX('$',ci.username2)) AS username2,
			ISNULL(isMarkVoid,0), p.MaxBet, p.MaxPerEvent, ReasonID
		FROM customer ci WITH(NOLOCK)
			INNER JOIN ProblemAccount p WITH(NOLOCK) ON ci.custid = p.custid
		WHERE ci.recommend IN (SELECT custid FROM #TempAg)
			AND roleid = 1
			AND (username  LIKE @username + '%' OR username2 LIKE '%$'+@username + '%')		
			AND ci.currency = CASE WHEN @Currency = 0 THEN ci.currency ELSE @Currency END
	END
	ELSE
	BEGIN
		INSERT INTO #CustList(custid,CreatedDate,username,username2,isMarkVoid,MaxBet,MaxPerEvent,ReasonID)
		SELECT ci.custid,p.CreatedDate, username,
			SUBSTRING(ci.username2,  CHARINDEX('$',ci.username2)+1, LEN(ci.username2)-CHARINDEX('$',ci.username2)) AS username2,
			ISNULL(isMarkVoid,0), p.MaxBet, p.MaxPerEvent, ReasonID
		FROM customer ci WITH(NOLOCK)
			INNER JOIN ProblemAccount p WITH(NOLOCK) ON ci.custid = p.custid
		WHERE ci.recommend IN (SELECT custid FROM #TempAg)
			AND roleid = 1
			AND ci.currency = CASE WHEN @Currency = 0 THEN ci.currency ELSE @Currency END
	END

	SELECT c.custid, c.CreatedDate , c.ReasonID
	INTO #temp1
	FROM #CustList c
	UNION ALL
	SELECT c.custid, tv.CreatedDate, tv.SubIssueTypeID
	FROM #CustList c
		INNER JOIN dbo.TicketVoiding_VoidedTransaction tv WITH (NOLOCK) ON c.CustId = tv.custid			
	WHERE IssueTypeId = 11	

	CREATE NONCLUSTERED INDEX PK_temp1_custid_CreatedDate ON #temp1(CustID,CreatedDate) INCLUDE (ReasonID)

	UPDATE t
	SET t.Reason = REVERSE(SUBSTRING(REVERSE(CONVERT(NVARCHAR(MAX),(	SELECT CONVERT(NVARCHAR,tmp.CreatedDate,101) + ': ' + tmp.ReasonName + CHAR(10) 
											FROM(
												SELECT MIN(t2.CreatedDate) AS CreatedDate
													,CASE WHEN @Language = 'SC' THEN REPLACE(MIN(pr.ReasonNameCS),'(M)','') ELSE REPLACE(MIN(pr.ReasonName),'(M)','') END AS ReasonName
												FROM #temp1 t2 
													INNER JOIN dbo.ProblemAccountReason pr WITH (NOLOCK) ON pr.ReasonID = t2.ReasonId 
												WHERE t.custid = t2.custid 
													AND pr.ReasonGroupID IS NOT NULL -- not show reason not in defined group
													AND pr.ReasonGroupID = CASE WHEN @ReasonGroupID <> 0 THEN @ReasonGroupID ELSE pr.ReasonGroupID END
												GROUP BY PR.ReasonGroupID
											) tmp
											ORDER BY tmp.CreatedDate 
											FOR XML PATH ('')
										)
							)),2,10000))
		,t.CreatedDate = (	SELECT TOP 1 t2.CreatedDate
							FROM #temp1 t2 
							WHERE t.custid = t2.custid
							ORDER BY t2.CreatedDate) --Get MIN(CreatedDate)
	FROM #CustList t

	--;WITH t AS (
	--	SELECT c.CustId, MIN(tv.CreatedDate) CreatedDate		
	--	FROM #CustList c
	--		INNER JOIN dbo.TicketVoiding_VoidedTransaction tv WITH (NOLOCK) ON c.CustId = tv.custid			
	--	WHERE IssueTypeId = 11	
	--	GROUP BY c.CustId
	--)
	--UPDATE c
	--SET c.CreatedDate = CASE WHEN c.CreatedDate < t.CreatedDate THEN c.CreatedDate ELSE t.CreatedDate END
	--FROM #CustList c
	--	INNER JOIN t ON c.custid = t.custid
		
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
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
	@Langkey	VARCHAR(20) = 'en-US',
	@ReasonGroupID	VARCHAR(200) = '',
	@BaseCurrency	VARCHAR(3) = ''
AS
	/*
		Created: 20200211@Johnson
		Task: Problem Account - Licensee Problem player 
		DB: DBACC/bodb02
		
		Revisions:
			- 20200211@Johnson: initial sp [redmine:#128077]
			- 20200410@Eden: LAP - Player Segmentation [redmine:#131929]
			- 20200417@Elodie: Unremove VIP if void abnormal [Redmine: #132736]
			- 20200717@Johnson: return agentid to support subsidiary [redmine:#136974]
			- 20200909@Johnson: add customer class [redmine:#141157]
			- 20200914@Johnson: fix sort MarkDate [redmine:#141525]
			- 20200916@Johnson: get archive data for TicketVoiding_VoidedTransaction [redmine:#141699] 
			- 20201103@Winfred: sort customer Class [redmine:#144706]
			- 20201204@Johnson: remove linked server when get data in TicketVoiding_VoidedTransaction_bk [redmine:#141699]
		Paramter's Explanations:
			@OrderCol = 1: System ID
						= 2: sort by external ID
						= 3: MarkDate
						= 4: customer Class
			@SortType = 1: ASC, 2: DESC		 	
	*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @RowCount INT, @RowStart INT, @RowEnd INT
	SELECT  @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1 

	CREATE TABLE #TempAg (custid INT)
	CREATE TABLE #CustList (CustId INT PRIMARY KEY, AgentID INT, CreatedDate DATETIME, username VARCHAR(50), username2 VARCHAR(50), MaxBet MONEY, MaxPerEvent MONEY, ReasonID TINYINT ,Reason NVARCHAR(4000))
	
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

	DECLARE @currentDate DATETIME   
	SELECT  @currentDate = CONVERT(DATE, GETDATE())

	SELECT ExchangeID, Rate
	INTO #ExchangeRate
	FROM Lrf_f_GetExchangeRate(@currentDate, @currentDate, @BaseCurrency, '')
	
	SELECT RTRIM(LTRIM(VAL)) AS ReasonGroupID
	INTO #ReasonGroup
	FROM Lrf_f_StringSplit(@ReasonGroupID,',')

	IF @Username <> ''
	BEGIN
		INSERT INTO #CustList(custid,AgentID,CreatedDate,username,username2,MaxBet,MaxPerEvent,ReasonID)
		SELECT ci.custid,ci.recommend,p.CreatedDate, username,
			SUBSTRING(ci.username2,  CHARINDEX('$',ci.username2)+1, LEN(ci.username2)-CHARINDEX('$',ci.username2)) AS username2,
		        e.Rate*p.MaxBet AS MaxBet, e.Rate*p.MaxPerEvent AS MaxPerEvent, ReasonID
		FROM customer ci WITH(NOLOCK)
			INNER JOIN ProblemAccount p WITH(NOLOCK) ON ci.custid = p.custid
			LEFT JOIN #ExchangeRate e ON e.ExchangeID = ci.currency
		WHERE ci.recommend IN (SELECT custid FROM #TempAg)
			AND roleid = 1
			AND (username  LIKE @username + '%' OR username2 LIKE '%$'+@username + '%')		
	END
	ELSE
	BEGIN
		INSERT INTO #CustList(custid,AgentID,CreatedDate,username,username2,MaxBet,MaxPerEvent,ReasonID)
		SELECT ci.custid,ci.recommend,p.CreatedDate, username,
			SUBSTRING(ci.username2,  CHARINDEX('$',ci.username2)+1, LEN(ci.username2)-CHARINDEX('$',ci.username2)) AS username2,
			e.Rate*p.MaxBet AS MaxBet, e.Rate*p.MaxPerEvent AS MaxPerEvent, ReasonID
		FROM customer ci WITH(NOLOCK)
			INNER JOIN ProblemAccount p WITH(NOLOCK) ON ci.custid = p.custid
			LEFT JOIN #ExchangeRate e ON e.ExchangeID = ci.currency
		WHERE ci.recommend IN (SELECT custid FROM #TempAg)
			AND roleid = 1
	END
	
	;WITH T AS (
		SELECT c.custid, tv.CreatedDate, tv.SubIssueTypeID
		FROM #CustList c
			INNER JOIN dbo.TicketVoiding_VoidedTransaction tv WITH (NOLOCK) ON c.CustId = tv.custid			
		WHERE IssueTypeId = 11
		UNION 
		SELECT c.custid, tv.CreatedDate, tv.SubIssueTypeID
		FROM #CustList c
			INNER JOIN bodb_Archive.dbo.TicketVoiding_VoidedTransaction_bk tv WITH (NOLOCK) ON c.CustId = tv.custid			
		WHERE IssueTypeId = 11
	)
	SELECT c.custid, c.CreatedDate , c.ReasonID
	INTO #temp1
	FROM #CustList c
	UNION ALL
	SELECT DISTINCT t.custid, t.CreatedDate, t.SubIssueTypeID
	FROM T

	CREATE NONCLUSTERED INDEX PK_temp1_custid_CreatedDate ON #temp1(CustID,CreatedDate) INCLUDE (ReasonID)

	IF @IsCheckAll = 0
	BEGIN
		DELETE #temp1
		WHERE CreatedDate NOT BETWEEN @FromDate AND @ToDate
	END

	DELETE c
	FROM #CustList c
	WHERE c.CustId NOT IN (	SELECT t.CustId
							FROM #temp1 t 
								INNER JOIN dbo.ProblemAccountReason pr WITH (NOLOCK) ON pr.ReasonID = t.ReasonId
								INNER JOIN #ReasonGroup rg ON pr.ReasonGroupID = rg.ReasonGroupID
							) 


	UPDATE t
	SET t.Reason = REVERSE(SUBSTRING(REVERSE(CONVERT(NVARCHAR(MAX),(	SELECT CONVERT(NVARCHAR,tmp.CreatedDate,101) + ': ' + tmp.ReasonName + '#' 
											FROM(
												SELECT MIN(t2.CreatedDate) AS CreatedDate
													,CASE WHEN @Langkey = 'zh-CN' THEN REPLACE(MIN(pr.ReasonNameCS),'(M)','') ELSE REPLACE(MIN(pr.ReasonName),'(M)','') END AS ReasonName
												FROM #temp1 t2 
													INNER JOIN dbo.ProblemAccountReason pr WITH (NOLOCK) ON pr.ReasonID = t2.ReasonId 
													--INNER JOIN #ReasonGroup rg ON pr.ReasonGroupID = rg.ReasonGroupID
												WHERE t.custid = t2.custid
												GROUP BY PR.ReasonGroupID
											) tmp
											ORDER BY tmp.CreatedDate DESC
											FOR XML PATH ('')
										)
							)),2,10000))
		,t.CreatedDate = (	SELECT TOP 1 t2.CreatedDate
							FROM #temp1 t2 
							WHERE t.custid = t2.custid
							ORDER BY t2.CreatedDate) --Get MIN(CreatedDate)
	FROM #CustList t
	
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
		SELECT t2.*, ci.CustomerClass, CASE WHEN d.custid IS NULL THEN 0 ELSE 1 END as isVIP
		FROM t2 
			INNER JOIN custinfo ci WITH(NOLOCK) ON ci.custid = t2.custid
			LEFT JOIN Dep_CustVIP d WITH(NOLOCK) ON t2.custid = d.custid
		WHERE rn BETWEEN @rowstart AND @rowend
		ORDER BY rn ASC
	END
	ELSE IF @OrderCol IN (4)
	BEGIN
		;WITH t AS (
		SELECT a.*,ci.CustomerClass, ROW_NUMBER () OVER (ORDER BY CASE WHEN @SortType = 1 THEN ci.CustomerClass END ASC,	
												CASE WHEN @SortType = 2 THEN ci.CustomerClass END DESC) rn
		FROM #CustList a
		INNER JOIN custinfo ci WITH(NOLOCK) ON ci.custid = a.custid
		)
		SELECT t.*, CASE WHEN d.custid IS NULL THEN 0 ELSE 1 END as isVIP
		FROM t
			LEFT JOIN Dep_CustVIP d WITH(NOLOCK) ON t.custid = d.custid
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
		SELECT t.*, ci.CustomerClass, CASE WHEN d.custid IS NULL THEN 0 ELSE 1 END as isVIP
		FROM t
			INNER JOIN custinfo ci WITH(NOLOCK) ON ci.custid = t.custid
			LEFT JOIN Dep_CustVIP d WITH(NOLOCK) ON t.custid = d.custid
		WHERE rn BETWEEN @rowstart AND @rowend
		ORDER BY rn ASC
	END	
END
GO	
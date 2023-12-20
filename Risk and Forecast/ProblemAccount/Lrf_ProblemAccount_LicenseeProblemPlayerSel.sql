/*<info serverAlias="DBACC-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_ProblemAccount_LicenseeProblemPlayerSel]
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
	@CustomerClass VARCHAR(1000) = ''
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
			- 20201209@Winfred: get isBA for Problem player [redmine:#146508]
			- 20210128@Johnson: filter customer class [redmine:#]
			- 20210607@Johnson: change source for Problem account, remove @BaseCurrency[redmine:#155692]
			- 20231219@Winfred: LAP - Allow mark VIP for BA players [Redmine: #198627]
		Paramter's Explanations:
			@OrderCol = 1: System ID
						= 2: sort by external ID
						= 3: MarkDate
						= 4: customer Class
			@SortType = 1: ASC, 2: DESC	
			@CustomerClass: '0,1,2,3,4,5,6,7,8,9,10,11,12,13' (all)
	*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @RowCount INT, @RowStart INT, @RowEnd INT
	SELECT  @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1 

	CREATE TABLE #TempAg (custid INT)
	CREATE TABLE #CustList (CustId INT PRIMARY KEY, CustomerClass SMALLINT, AgentID INT, CreatedDate DATETIME, username VARCHAR(50), username2 VARCHAR(50), Reason NVARCHAR(4000))
	
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

	SELECT RTRIM(LTRIM(VAL)) AS CategoryID
	INTO #tblCategory
	FROM Lrf_f_StringSplit(@ReasonGroupID,',')
	
	SELECT RTRIM(LTRIM(VAL)) AS CustomerClass
	INTO #tblCustomerClass
	FROM Lrf_f_StringSplit(@CustomerClass,',')

	IF @Username <> ''
	BEGIN
		INSERT INTO #CustList(custid,AgentID,CreatedDate,username,username2)
		SELECT ci.custid,ci.recommend,p.ModifiedDate, ci.username,
			SUBSTRING(ci.username2,  CHARINDEX('$',ci.username2)+1, LEN(ci.username2)-CHARINDEX('$',ci.username2)) AS username2
		FROM customer ci WITH(NOLOCK)
			INNER JOIN ProblemAccountClassification p WITH(NOLOCK) ON ci.custid = p.custid			
			INNER JOIN custinfo c WITH(NOLOCK) ON c.custid = ci.custid
		WHERE ci.recommend IN (SELECT custid FROM #TempAg)
			AND ci.roleid = 1
			AND (ci.username  LIKE @username + '%' OR ci.username2 LIKE '%$'+@username + '%')		
			AND c.CustomerClass IN (SELECT customerClass FROM CategoryConfig WITH(NOLOCK) WHERE OfferDeposit = 1)
			
	END
	ELSE
	BEGIN
		INSERT INTO #CustList(custid,AgentID,CreatedDate,username,username2)
		SELECT ci.custid,ci.recommend,p.ModifiedDate, ci.username,
			SUBSTRING(ci.username2,  CHARINDEX('$',ci.username2)+1, LEN(ci.username2)-CHARINDEX('$',ci.username2)) AS username2			
		FROM customer ci WITH(NOLOCK)
			INNER JOIN ProblemAccountClassification p WITH(NOLOCK) ON ci.custid = p.custid			
			INNER JOIN custinfo c WITH(NOLOCK) ON c.custid = ci.custid
		WHERE ci.recommend IN (SELECT custid FROM #TempAg)
			AND ci.roleid = 1
			AND c.CustomerClass IN (SELECT customerClass FROM CategoryConfig WITH(NOLOCK) WHERE OfferDeposit = 1)
	END
		
	SELECT c.custid, c.CreatedDate, c.CategoryID
	INTO #temp1
	FROM Dep_CustCategoryHistory c WITH(NOLOCK)
	WHERE custid IN (SELECT custid FROM #CustList)
		AND 1 = CASE WHEN @IsCheckAll = 1 THEN 1  
					WHEN @IsCheckAll = 0 AND CreatedDate BETWEEN @FromDate AND @ToDate THEN 1
					ELSE 0 END				

	CREATE NONCLUSTERED INDEX PK_temp1_custid_CreatedDate ON #temp1(CustID,CreatedDate) INCLUDE (CategoryID)

	
	DELETE c
	FROM #CustList c
	WHERE c.CustId NOT IN (	SELECT t.CustId
							FROM #temp1 t 
							WHERE CategoryID IN (SELECT CategoryID FROM #tblCategory)
							) 


	UPDATE t
	SET t.CustomerClass = ISNULL(ci.CustomerClass,0),
		t.Reason = REVERSE(SUBSTRING(REVERSE(CONVERT(NVARCHAR(MAX),(	SELECT CONVERT(NVARCHAR,tmp.CreatedDate,101) + ': ' + tmp.ReasonName + '#' 
											FROM(
												SELECT MAX(t2.CreatedDate) AS CreatedDate
													,CASE WHEN @Langkey = 'zh-CN' THEN MIN(ISNULL(CategoryNameCS,CategoryName)) ELSE MIN(CategoryName) END AS ReasonName
												FROM #temp1 t2 
													INNER JOIN dbo.CategoryConfig c WITH (NOLOCK) ON c.CategoryID = t2.CategoryID 													
												WHERE t.custid = t2.custid
												GROUP BY c.CategoryID
											) tmp
											ORDER BY tmp.CreatedDate DESC
											FOR XML PATH ('')
										)
							)),2,10000))		
	FROM #CustList t
		INNER JOIN custinfo ci WITH(NOLOCK) ON t.custid = ci.custid
	
	DELETE #CustList
	WHERE customerClass NOT IN (SELECT customerClass FROM #tblCustomerClass)
	
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
		SELECT t2.*, CASE WHEN d.custid IS NULL THEN 0 ELSE 1 END as isVIP--,CASE WHEN b.custid IS NULL THEN 0 ELSE 1 END AS IsBA
		FROM t2 
			LEFT JOIN Dep_CustVIP d WITH(NOLOCK) ON t2.custid = d.custid
			--LEFT JOIN Dep_CustBAActive b WITH(NOLOCK) ON t2.custid = b.custid
		WHERE rn BETWEEN @rowstart AND @rowend
		ORDER BY rn ASC
	END
	ELSE IF @OrderCol IN (4)
	BEGIN
		;WITH t AS (
		SELECT a.*, ROW_NUMBER () OVER (ORDER BY CASE WHEN @SortType = 1 THEN CustomerClass END ASC,	
												CASE WHEN @SortType = 2 THEN CustomerClass END DESC) rn
		FROM #CustList a
		)
		SELECT t.*, CASE WHEN d.custid IS NULL THEN 0 ELSE 1 END as isVIP--,CASE WHEN b.custid IS NULL THEN 0 ELSE 1 END AS IsBA
		FROM t
			LEFT JOIN Dep_CustVIP d WITH(NOLOCK) ON t.custid = d.custid
			--LEFT JOIN Dep_CustBAActive b WITH(NOLOCK) ON t.custid = b.custid
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
		SELECT t.*, CASE WHEN d.custid IS NULL THEN 0 ELSE 1 END as isVIP--,CASE WHEN b.custid IS NULL THEN 0 ELSE 1 END AS IsBA
		FROM t			
			LEFT JOIN Dep_CustVIP d WITH(NOLOCK) ON t.custid = d.custid
			--LEFT JOIN Dep_CustBAActive b WITH(NOLOCK) ON t.custid = b.custid
		WHERE rn BETWEEN @rowstart AND @rowend
		ORDER BY rn ASC
	END	
	
	DROP TABLE #tblCategory
	DROP TABLE #CustList
	DROP TABLE #tblCustomerClass
	DROP TABLE #temp1
END
GO
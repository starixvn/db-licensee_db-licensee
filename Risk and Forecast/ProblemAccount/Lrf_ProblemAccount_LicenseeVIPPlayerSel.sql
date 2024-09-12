/*<info serverAlias="DBACC-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_ProblemAccount_LicenseeVIPPlayerSel]
	@Username	VARCHAR(50) = '',
	@AgentList	VARCHAR(MAX),
	@VipOption	TINYINT = 0,
	@OrderCol	TINYINT = 1,
	@SortType	TINYINT = 1,
	@CustomerClass VARCHAR(1000)='',
	@FullCustomerClass	VARCHAR(1000)	= NULL,
	@IsCheckAll	BIT,
	@FromDate	DATETIME,
	@ToDate		DATETIME,
	@PageSize	INT = 1000,
	@PageIndex	INT = 1,
	@TotalItems	INT = 0 OUTPUT
AS
	/*
		Created: 20200212@Johnson
		Task: Problem Account - Licensee VIP player 
		DB: DBACC/bodb02
		
		Revisions:
			- 20200212@Johnson: initial sp [redmine:#128077]
			- 20200417@Elodie: Unremove VIP if void abnormal [Redmine: #132736]
			- 20200717@Johnson: return agentid to support subsidiary [redmine:#136974]
			- 20201001@Louis: Licensee Spread Setting [RedmineID: #142532]	
			- 20201209@Winfred: get isBA for Problem player [redmine:#146508]
			- 20210128@Johnson: filter customer class [redmine:#]
			- 20230615@Johnson: sort CC by risk level [redmine:#189631]
			- 20230621@Johnson: show wrong CC when miss info in Custinfo[redmine:#190081]
			- 20230628@Johnson: VIP Management - Enhance Export Excel incase order by CC [redmine:#190159]
			- 20230803@Winfred: LAP - Player Segmentation - Add Risk Level's last update time [redmine:#191101]
			- 20231219@Winfred: LAP - Allow mark VIP for BA players [Redmine: #198627]
			- 20240910@Kelvin: Support Odds Boost Voucher [RedmineID: #210613]
		Paramter's Explanations:
			- @VipOption: 0: All, 1: Yes, 2 : No
			- @OrderCol = 1: sort by System ID	
						= 2: external ID	
						= 4: customer Class	(follow Lrf_ProblemAccount_LicenseeProblemPlayerSel)	
			- @SortType = 1: ASC, 2: DESC
			- @CustomerClass: '0,1,2,3,4,5,6,7,8,9,10,11,12,13' (all)
			- @FullCustomerClass: '0,1,2,3,4,5,6,7,8,9,10,11,12,13' (all)
				-> CC = 0: Uncategorized	
	*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @RowCount INT, @RowStart INT, @RowEnd INT
	SELECT  @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1 

	DECLARE @TempAg TABLE (custid INT)
	CREATE TABLE #CustList (CustId INT PRIMARY KEY, CustomerClass SMALLINT, AgentID INT, username VARCHAR(50), username2 VARCHAR(50), isVIP BIT, LastMaskDate DATETIME,IsValid BIT DEFAULT(0))
	--, IsBA BIT
	DECLARE @DocHandler INT,	
		@IsUncategorizedCC BIT = 0

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@AgentList
	
		INSERT INTO @TempAg(CustId)
		SELECT AgentId
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
			,ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH;
	
	;WITH t AS (
		SELECT ci.custid, ci.recommend as AgentID, username, 
			SUBSTRING(ci.username2,  CHARINDEX('$',ci.username2)+1, LEN(ci.username2)-CHARINDEX('$',ci.username2)) AS username2,
			username2 AS username2Ori
		FROM customer ci WITH(NOLOCK)
			INNER JOIN @TempAg a ON ci.recommend = a.custid
		WHERE roleid = 1			
	)
	INSERT INTO #CustList(custid,AgentID,username,username2,isVip)--,IsBA)
	SELECT t.custid,AgentID, username, username2, 
		CASE WHEN c.custid IS NULL THEN 0 ELSE 1 END
		--,CASE WHEN d.custid IS NULL THEN 0 ELSE 1 END
	FROM t
		OUTER APPLY ( SELECT TOP 1 custid FROM dbo.Dep_CustVIP WITH (NOLOCK) WHERE custid = t.custid ) c
		--OUTER APPLY ( SELECT TOP 1 custid FROM dbo.Dep_CustBAActive WITH (NOLOCK) WHERE custid = t.custid ) d
	WHERE (@VipOption = 0 
		OR ( @VipOption = 1 AND c.custid IS NOT NULL)
		OR (@VipOption = 2 AND c.custid IS NULL))
		AND ((@Username <> '' AND (username  LIKE @username + '%' OR username2Ori LIKE '%$'+@username + '%')) OR @Username = '')
		AND t.username  NOT LIKE '%CASHOUT%'
		AND t.username  NOT LIKE '%ClearBal%'
		AND t.username  NOT LIKE '%BetTrade%'
		AND t.username  NOT LIKE '%01OddsAdj%'
		AND t.username  NOT LIKE '%01OddsBoostAdj%'
		
	SELECT ID, RTRIM(LTRIM(VAL)) AS CustomerClass
	INTO #tblCustomerClass
	FROM Lrf_f_StringSplit(@CustomerClass,',')
	
	SELECT ID, RTRIM(LTRIM(VAL)) AS CustomerClass
	INTO #tblFullCustomerClass
	FROM Lrf_f_StringSplit(@FullCustomerClass,',')
	
	UPDATE t
	SET t.customerClass = ISNULL(ci.customerClass,0)
	FROM #CustList t
		INNER JOIN custinfo ci WITH(NOLOCK) ON t.custid = ci.custid
		
	IF EXISTS (SELECT 1 FROM #tblCustomerClass WHERE CustomerClass = 0)
	BEGIN
		;WITH T AS (
			SELECT c.CustID, c.CustomerClass, CASE WHEN c.CustomerClass IS NOT NULL AND c.CustomerClass NOT IN (SELECT CustomerClass FROM #tblFullCustomerClass WHERE CustomerClass <> 0) THEN 1 ELSE 0 END as IsUncategorizedCC
			FROM #CustList c		
		)
		DELETE T
		WHERE customerClass IS NULL --not have data in custinfo
			OR 1 = CASE WHEN IsUncategorizedCC = 1 THEN 0
						WHEN IsUncategorizedCC = 0 AND CustomerClass IN (SELECT CustomerClass FROM #tblCustomerClass) THEN 0 
						ELSE 1 END
	END
	ELSE 	
	BEGIN
		DELETE #CustList 
		WHERE customerClass NOT IN (SELECT customerClass FROM #tblCustomerClass)
			OR customerClass IS NULL --not have data in custinfo
	END
	
	IF @IsCheckAll = 1
	BEGIN
		UPDATE a 
		SET a.LastMaskDate = b.ModifiedDate , a.IsValid = 1
		FROM #CustList a
			CROSS APPLY (SELECT TOP 1 ModifiedDate FROM Dep_CustomerClass WITH(NOLOCK) WHERE CustID = a.CustID) b
		WHERE a.customerClass <> 0
	END
	ELSE
	BEGIN
		UPDATE a 
		SET a.LastMaskDate = b.ModifiedDate , a.IsValid = 1
		FROM #CustList a
			CROSS APPLY (SELECT TOP 1 ModifiedDate FROM Dep_CustomerClass WITH(NOLOCK) WHERE CustID = a.CustID AND ModifiedDate BETWEEN @FromDate AND @ToDate) b
		WHERE a.customerClass <> 0

		DELETE #CustList WHERE IsValid = 0
	END

	SELECT @TotalItems = COUNT(1) FROM #CustList
	
	IF @OrderCol IN (1,2)
	BEGIN
		;WITH t1 AS(
		SELECT *, CASE WHEN @OrderCol = 1 THEN username 
						WHEN @OrderCol = 2 THEN username2 END OrderCol
		FROM #CustList
		),
		t2 AS (
		SELECT *, ROW_NUMBER () OVER (ORDER BY CASE WHEN @SortType = 1 THEN OrderCol END ASC,	
												CASE WHEN @SortType = 2 THEN OrderCol END DESC) rn
		FROM t1
		)
		SELECT t2.*--,ISNULL(isMarkVoid,0) isMarkVoid			
		FROM t2 
			LEFT JOIN ProblemAccount p WITH(NOLOCK) ON t2.custid = p.custid
		WHERE rn BETWEEN @rowstart AND @rowend
		ORDER BY rn ASC
	END
	ELSE IF @OrderCol = 4
	BEGIN
		;WITH t1 AS(
		SELECT c.*, CASE WHEN @OrderCol = 4 THEN t.ID END OrderCol
		FROM #CustList c
			INNER JOIN #tblCustomerClass t ON c.CustomerClass = t.CustomerClass
		),
		t2 AS (
		SELECT *, ROW_NUMBER () OVER (ORDER BY CASE WHEN @SortType = 1 THEN OrderCol END ASC,	
												CASE WHEN @SortType = 2 THEN OrderCol END DESC, username ASC) rn
		FROM t1
		)
		SELECT t2.*--,ISNULL(isMarkVoid,0) isMarkVoid			
		FROM t2 
			LEFT JOIN ProblemAccount p WITH(NOLOCK) ON t2.custid = p.custid
		WHERE rn BETWEEN @rowstart AND @rowend
		ORDER BY rn ASC
	END
	ELSE IF @OrderCol = 5
	BEGIN
		;WITH t1 AS(
		SELECT c.*, CASE WHEN @OrderCol = 5 THEN c.LastMaskDate END OrderCol
		FROM #CustList c
			INNER JOIN #tblCustomerClass t ON c.CustomerClass = t.CustomerClass
		),
		t2 AS (
		SELECT *, ROW_NUMBER () OVER (ORDER BY CASE WHEN @SortType = 1 THEN OrderCol END ASC,	
												CASE WHEN @SortType = 2 THEN OrderCol END DESC, username ASC) rn
		FROM t1
		)
		SELECT t2.*--,ISNULL(isMarkVoid,0) isMarkVoid			
		FROM t2 
			LEFT JOIN ProblemAccount p WITH(NOLOCK) ON t2.custid = p.custid
		WHERE rn BETWEEN @rowstart AND @rowend
		ORDER BY rn ASC
	END
	
	DROP TABLE #tblCustomerClass
	DROP TABLE #tblFullCustomerClass
	DROP TABLE #CustList
END	
GO

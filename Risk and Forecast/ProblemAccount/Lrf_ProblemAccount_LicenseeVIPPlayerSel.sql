/*<info serverAlias="DBACC-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_ProblemAccount_LicenseeVIPPlayerSel]
	@Username	VARCHAR(50) = '',
	@AgentList	VARCHAR(MAX),
	@VipOption	TINYINT = 0,
	@OrderCol	TINYINT = 1,
	@SortType	TINYINT = 1,
	@CustomerClass VARCHAR(1000)='',
	
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
		Paramter's Explanations:
			- @VipOption: 0: All, 1: Yes, 2 : No
			- @OrderCol = 1: sort by System ID	
						= 2: external ID	
						= 4: customer Class	(follow Lrf_ProblemAccount_LicenseeProblemPlayerSel)	
			- @SortType = 1: ASC, 2: DESC
			- @CustomerClass: '0,1,2,3,4,5,6,7,8,9,10,11,12,13' (all)		
	*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @RowCount INT, @RowStart INT, @RowEnd INT
	SELECT  @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1 

	CREATE TABLE #TempAg (custid INT)
	CREATE TABLE #CustList (CustId INT PRIMARY KEY, CustomerClass SMALLINT, AgentID INT, username VARCHAR(50), username2 VARCHAR(50), isVIP BIT, IsBA BIT)
	
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
		;WITH t AS (
		SELECT ci.custid, ci.recommend as AgentID, username, 
			SUBSTRING(ci.username2,  CHARINDEX('$',ci.username2)+1, LEN(ci.username2)-CHARINDEX('$',ci.username2)) AS username2,
			CASE WHEN d.custid IS NULL THEN 0 ELSE 1 END AS isVIP
			,CASE WHEN b.custid IS NULL THEN 0 ELSE 1 END AS IsBA
		FROM customer ci WITH(NOLOCK)
			LEFT JOIN Dep_CustVIP d WITH(NOLOCK) ON ci.custid = d.custid
			LEFT JOIN Dep_CustBAActive b WITH(NOLOCK) ON ci.custid = b.custid
		WHERE ci.recommend IN (SELECT custid FROM #TempAg)
			AND roleid = 1
			AND (username  LIKE @username + '%' OR username2 LIKE '%$'+@username + '%')
			AND ci.username  NOT LIKE '%CASHOUT%'
			AND ci.username  NOT LIKE '%ClearBal%'
			AND ci.username  NOT LIKE '%BetTrade%'
			AND ci.username  NOT LIKE '%01OddsAdj%'
		)
		INSERT INTO #CustList(custid,AgentID,username,username2,isVip,IsBA)
		SELECT custid,AgentID, username, username2, isVip,IsBA
		FROM t
		WHERE isVIP = CASE WHEN @VipOption = 1 THEN 1
							WHEN @VipOption = 2 THEN 0 ELSE isVip END 
	END
	ELSE
	BEGIN
		;WITH t AS (
		SELECT ci.custid, ci.recommend as AgentID, username, 
			SUBSTRING(ci.username2,  CHARINDEX('$',ci.username2)+1, LEN(ci.username2)-CHARINDEX('$',ci.username2)) AS username2,
			CASE WHEN d.custid IS NULL THEN 0 ELSE 1 END AS isVIP
			,CASE WHEN b.custid IS NULL THEN 0 ELSE 1 END AS IsBA
		FROM customer ci WITH(NOLOCK)
			LEFT JOIN Dep_CustVIP d WITH(NOLOCK) ON ci.custid = d.custid
			LEFT JOIN Dep_CustBAActive b WITH(NOLOCK) ON ci.custid = b.custid			
		WHERE ci.recommend IN (SELECT custid FROM #TempAg)
			AND roleid = 1	
			AND ci.username  NOT LIKE '%CASHOUT%'	
			AND ci.username  NOT LIKE '%ClearBal%'
			AND ci.username  NOT LIKE '%BetTrade%'
			AND ci.username  NOT LIKE '%01OddsAdj%'
		)
		INSERT INTO #CustList(custid,AgentID,username,username2,isVip,IsBA)
		SELECT custid, AgentID, username, username2, isVip,IsBA
		FROM t
		WHERE isVIP = CASE WHEN @VipOption = 1 THEN 1
							WHEN @VipOption = 2 THEN 0 ELSE isVip END 
	END
		
	SELECT ID, RTRIM(LTRIM(VAL)) AS CustomerClass
	INTO #tblCustomerClass
	FROM Lrf_f_StringSplit(@CustomerClass,',')
	
	UPDATE t
	SET t.customerClass = ISNULL(ci.customerClass,0)
	FROM #CustList t
		INNER JOIN custinfo ci WITH(NOLOCK) ON t.custid = ci.custid
	
	DELETE #CustList 
	WHERE customerClass NOT IN (SELECT customerClass FROM #tblCustomerClass)
	
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
												CASE WHEN @SortType = 2 THEN OrderCol END DESC) rn
		FROM t1
		)
		SELECT t2.*--,ISNULL(isMarkVoid,0) isMarkVoid			
		FROM t2 
			LEFT JOIN ProblemAccount p WITH(NOLOCK) ON t2.custid = p.custid
		WHERE rn BETWEEN @rowstart AND @rowend
		ORDER BY rn ASC
	END
	
	DROP TABLE #tblCustomerClass
	DROP TABLE #TempAg	
	DROP TABLE #CustList
END	
GO

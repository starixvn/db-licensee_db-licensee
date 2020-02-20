/*<info serverAlias="DBACC-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE Lrf_ProblemAccount_LicenseeVIPPlayerSel
	@Username	VARCHAR(50) = '',
	@AgentList	VARCHAR(MAX),
	@VipOption	TINYINT = 0,
	@OrderCol	TINYINT = 0,
	@SortType	TINYINT = 0,
	
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
			
		Paramter's Explanations:
			- @VipOption: 0: All, 1: Yes, 2 : No
			- @OrderCol = 1: sort by external ID
						= 2: System ID						
			- @SortType = 1: ASC, 2: DESC			
	*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @RowCount INT, @RowStart INT, @RowEnd INT
	SELECT  @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1 

	CREATE TABLE #TempAg (custid INT)
	CREATE TABLE #CustList (CustId INT PRIMARY KEY, username VARCHAR(50), username2 VARCHAR(50))
	
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
		SELECT ci.custid, username, 
			SUBSTRING(ci.username2,  CHARINDEX('$',ci.username2)+1, LEN(ci.username2)-CHARINDEX('$',ci.username2)) AS username2,
			CASE WHEN d.custid IS NULL THEN 0 ELSE 1 END AS isVIP
		FROM customer ci WITH(NOLOCK)
			LEFT JOIN Dep_CustVIP d WITH(NOLOCK) ON ci.custid = d.custid
		WHERE ci.recommend IN (SELECT custid FROM #TempAg)
			AND roleid = 1
			AND (username  LIKE @username + '%' OR username2 LIKE '$'+@username+'%')
		)
		INSERT INTO #CustList(custid,username,username2,isVip)
		SELECT custid, username, username2, isVip
		FROM t
		WHERE isVIP = CASE WHEN @VipOption = 1 THEN 1
							WHEN @VipOption = 2 THEN 0 ELSE isVip END 
	END
	ELSE
	BEGIN
		;WITH t AS (
		SELECT ci.custid, username, 
			SUBSTRING(ci.username2,  CHARINDEX('$',ci.username2)+1, LEN(ci.username2)-CHARINDEX('$',ci.username2)) AS username2,
			CASE WHEN d.custid IS NULL THEN 0 ELSE 1 END AS isVIP
		FROM customer ci WITH(NOLOCK)
			LEFT JOIN Dep_CustVIP d WITH(NOLOCK) ON ci.custid = d.custid
		WHERE ci.recommend IN (SELECT custid FROM #TempAg)
			AND roleid = 1			
		)
		INSERT INTO #CustList(custid,username,username2,isVip)
		SELECT custid, username, username2, isVip
		FROM t
		WHERE isVIP = CASE WHEN @VipOption = 1 THEN 1
							WHEN @VipOption = 2 THEN 0 ELSE isVip END 
	END
	
	SELECT @TotalItems = COUNT(1) FROM #CustList
	
	;WITH t1 AS(
	SELECT *, CASE WHEN @OrderCol = 1 THEN username ELSE username2 END OrderCol
	FROM #CustList
	),
	t2 AS (
	SELECT *, ROW_NUMBER () OVER (ORDER BY CASE WHEN @SortType = 1 THEN OrderCol END ASC,	
											CASE WHEN @SortType = 2 THEN OrderCol END DESC) rn
	FROM t1
	)
	SELECT t2.*, CASE WHEN d.custid IS NULL THEN 0 ELSE 1 END as isVIP
	FROM t2 		
	WHERE rn BETWEEN @rowstart AND @rowend
END	
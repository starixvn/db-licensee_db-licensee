/*<info serverAlias="DBCUST-CUSTDB" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE dbo.Acc_Dep_WLMonitored_Player_Sel
	 @AgentList	VARCHAR(MAX)
	,@Username VARCHAR(30)= ''
	,@Sporttype SMALLINT = 0
	,@IsGetAll	BIT = 1
	,@SortType       TINYINT = 1
	,@IsDesc	     BIT = 1
	,@PageSize       INT = 50
	,@PageIndex      INT = 1
	,@TotalItems     INT = 0 OUTPUT
	,@XMLReachList	 VARCHAR(MAX)
AS  
/*  
	Created:	20220523@Eden
	Task:		View Monitored Player List - Deposit
	DB:			DBCUST/CustDB
	Original:	
  
	Revisions:  
	    - 20220523@Eden: LAP - Player Segmentation - Monitored Player [Redmine:#172605]

	Param's Explanation:
		- @SortType : ( order by)
			1: ExternalID (default)
			2: SystemID 
			3: Currency
			4: Current Winning Threshold
			5: No Of Reached
			6: Last Reached Date
			7: Problem Player
			8: VIP Player

		- @IsGetAll:
			1: get all players in the monitor list
			0: only get list of monitored players who have notification within data range

	DECLARE @TotalItems INT
	EXEC Acc_Dep_WLMonitored_Player_Sel 
		     @AgentList='<ROOT><Agent AgentId="1255632" Currency="2"/></ROOT>'
			,@Username = ''
			,@Sporttype = 0
			,@FromDate = '2022/09/01'
			,@ToDate = '2022/09/18'
			,@IsGetAll = 1
			,@SortType = 1
			,@IsDesc = 1
			,@PageSize            = 20
			,@PageIndex           = 1
			,@TotalItems          = @TotalItems OUTPUT
			,@XMLReachList	= '<ROOT>
								  <R CustID="1411402" ReachedCnt="66" AccumWL="515.0000" WinningThreshold="300.0000" CreatedDate="2022-09-12T04:21:01.970" />
								  <R CustID="1417244" ReachedCnt="3" AccumWL="100.0000" WinningThreshold="1000.0000" CreatedDate="2022-09-01T05:32:58.287" />
								  <R CustID="1425328" ReachedCnt="3" AccumWL="100.0000" WinningThreshold="1000.0000" CreatedDate="2022-09-01T05:32:58.287" />
								  <R CustID="1438229" ReachedCnt="3" AccumWL="100.0000" WinningThreshold="1000.0000" CreatedDate="2022-09-01T05:32:58.287" />
								</ROOT>'
		SELECT @TotalItems
	
*/  
BEGIN 
	DECLARE @RowStart int, @RowEnd int
	SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1

	CREATE TABLE #TempAg (custid INT)
	
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

	CREATE TABLE #TempHistory(
		[CustID] [int],
		[ReachedCnt] [int],
		[AccumWL] [money],
		[WinningThreshold] [money],
		[CreatedDate] [datetime]
	)

	CREATE TABLE #Temp(
		CustID					INT,
		username2				VARCHAR(50),
		username				VARCHAR(30),
		ExchangeId				INT,
		Currency				NVARCHAR(50),
		CurrentWinningThreshold	MONEY,
		NoOfReached				INT,
		LastReachedDate			DATETIME,
		ProblemPlayer			BIT,
		VIPPlayer				BIT,
		ReachedWinLossAmount	MONEY,
		ReachedWinningThreshold	MONEY,
		recommend				INT,
		RowNumber				INT IDENTITY(1,1)
	)

	CREATE TABLE #Temp2(
		CustID					INT,
		username2				VARCHAR(50),
		username				VARCHAR(30),
		ExchangeId				INT,
		Currency				NVARCHAR(50),
		CurrentWinningThreshold	MONEY,
		NoOfReached				INT,
		LastReachedDate			DATETIME,
		ProblemPlayer			BIT,
		VIPPlayer				BIT,
		ReachedWinLossAmount	MONEY,
		ReachedWinningThreshold	MONEY,
		recommend				INT,
		RowNumber				INT IDENTITY(1,1)
	)

	IF ISNULL(@XMLReachList,'') <> ''
	BEGIN
		-- For read xml					
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @XMLReachList

		INSERT INTO #TempHistory(CustID,ReachedCnt,AccumWL,WinningThreshold,CreatedDate )
		SELECT CustID,ReachedCnt,AccumWL,WinningThreshold,CreatedDate 
		FROM OPENXML (@DocHandler, '/ROOT/R',1) 
		WITH (
			[CustID] [int],
			[ReachedCnt] [int],
			[AccumWL] [money],
			[WinningThreshold] [money],
			[CreatedDate] [datetime]
		) AS Data

		EXEC sp_xml_removedocument @DocHandler
		-- end read xml	
	END		

	IF @IsGetAll = 1
	BEGIN
		INSERT INTO #Temp(
			 CustID					
			,username2				
			,username				
			,ExchangeId				
			,Currency				
			,CurrentWinningThreshold	
			,NoOfReached				
			,LastReachedDate			
			,ProblemPlayer			
			,VIPPlayer				
			,ReachedWinLossAmount	
			,ReachedWinningThreshold	
			,recommend					
		)
		SELECT ci.custid,
			SUBSTRING(c.username2,  CHARINDEX('$',c.username2)+1, LEN(c.username2)-CHARINDEX('$',c.username2)) AS username2,
			ci.username,
			e.ExchangeId,
			e.currency,
			w.WinningThreshold AS CurrentWinningThreshold,
			his.ReachedCnt AS NoOfReached,
			his.CreatedDate AS LastReachedDate,
			CASE WHEN p.custid IS NOT NULL THEN 1 ELSE 0 END AS ProblemPlayer,
			CASE WHEN d.custid IS NOT NULL THEN 1 ELSE 0 END AS VIPPlayer,
			his.AccumWL AS ReachedWinLossAmount,
			his.WinningThreshold AS ReachedWinningThreshold,
			ci.recommend
		FROM Dep_WLMonitored_Player w WITH(NOLOCK)
			INNER JOIN custInfo ci WITH(NOLOCK) ON w.CustID = ci.custid
			INNER JOIN customer c WITH(NOLOCK) ON ci.custid = c.custid
			INNER JOIN #TempAg ag ON ci.recommend = ag.custid
			INNER JOIN Exchange e WITH(NOLOCK) ON e.ExchangeId = ci.currency
			LEFT JOIN #TempHistory his 
				ON his.custid = w.custid
			LEFT JOIN ProblemAccountClassification p WITH(NOLOCK) 
				ON w.CustID = p.custid
			LEFT JOIN Dep_CustVIP d WITH(NOLOCK) 
				ON w.custid = d.custid
		WHERE ci.roleid = 1
			AND (ci.username LIKE  '%' + ISNULL(@Username,'') + '%'
					OR SUBSTRING(c.username2,  CHARINDEX('$',c.username2)+1, LEN(c.username2)-CHARINDEX('$',c.username2)) LIKE  '%' + ISNULL(@Username,'') + '%'
				)
	END
	ELSE
	BEGIN
		INSERT INTO #Temp(
			 CustID					
			,username2				
			,username				
			,ExchangeId				
			,Currency				
			,CurrentWinningThreshold	
			,NoOfReached				
			,LastReachedDate			
			,ProblemPlayer			
			,VIPPlayer				
			,ReachedWinLossAmount	
			,ReachedWinningThreshold	
			,recommend					
		)
		SELECT ci.custid,
			SUBSTRING(c.username2,  CHARINDEX('$',c.username2)+1, LEN(c.username2)-CHARINDEX('$',c.username2)) AS username2,
			ci.username,
			e.ExchangeId,
			e.currency,
			w.WinningThreshold AS CurrentWinningThreshold,
			his.ReachedCnt AS NoOfReached,
			his.CreatedDate AS LastReachedDate,
			CASE WHEN p.custid IS NOT NULL THEN 1 ELSE 0 END AS ProblemPlayer,
			CASE WHEN d.custid IS NOT NULL THEN 1 ELSE 0 END AS VIPPlayer,
			his.AccumWL AS ReachedWinLossAmount,
			his.WinningThreshold AS ReachedWinningThreshold,
			ci.recommend
		FROM Dep_WLMonitored_Player w WITH(NOLOCK)
			INNER JOIN custInfo ci WITH(NOLOCK) ON w.CustID = ci.custid
			INNER JOIN customer c WITH(NOLOCK) ON ci.custid = c.custid
			INNER JOIN #TempAg ag ON ci.recommend = ag.custid
			INNER JOIN Exchange e WITH(NOLOCK) ON e.ExchangeId = ci.currency
			INNER JOIN #TempHistory his 
				ON his.custid = w.custid
			LEFT JOIN ProblemAccountClassification p WITH(NOLOCK) 
				ON w.CustID = p.custid
			LEFT JOIN Dep_CustVIP d WITH(NOLOCK) 
				ON w.custid = d.custid
		WHERE ci.roleid = 1
			AND (ci.username LIKE  '%' + ISNULL(@Username,'') + '%'
					OR SUBSTRING(c.username2,  CHARINDEX('$',c.username2)+1, LEN(c.username2)-CHARINDEX('$',c.username2)) LIKE  '%' + ISNULL(@Username,'') + '%'
				)
	END

	INSERT INTO #Temp2(
		 CustID					
		,username2				
		,username				
		,ExchangeId				
		,Currency				
		,CurrentWinningThreshold	
		,NoOfReached				
		,LastReachedDate			
		,ProblemPlayer			
		,VIPPlayer				
		,ReachedWinLossAmount	
		,ReachedWinningThreshold	
		,recommend					
	)
	SELECT  CustID					
		,username2				
		,username				
		,ExchangeId				
		,Currency				
		,CurrentWinningThreshold	
		,NoOfReached				
		,LastReachedDate			
		,ProblemPlayer			
		,VIPPlayer				
		,ReachedWinLossAmount	
		,ReachedWinningThreshold	
		,recommend	
	FROM #Temp
	ORDER BY	CASE WHEN @SortType = 1 AND @IsDesc = 0 THEN username2 END ASC,
				CASE WHEN @SortType = 2 AND @IsDesc = 0 THEN username END ASC,
				CASE WHEN @SortType = 3 AND @IsDesc = 0 THEN Currency END ASC,
				CASE WHEN @SortType = 4 AND @IsDesc = 0 THEN CurrentWinningThreshold END ASC,
				CASE WHEN @SortType = 5 AND @IsDesc = 0 THEN NoOfReached END ASC,
				CASE WHEN @SortType = 6 AND @IsDesc = 0 THEN LastReachedDate END ASC,
				CASE WHEN @SortType = 7 AND @IsDesc = 0 THEN ProblemPlayer END ASC,
				CASE WHEN @SortType = 8 AND @IsDesc = 0 THEN VIPPlayer END ASC,
				-----------
				CASE WHEN @SortType = 1 AND @IsDesc = 1 THEN username2 END DESC,
				CASE WHEN @SortType = 2 AND @IsDesc = 1 THEN username END DESC,
				CASE WHEN @SortType = 3 AND @IsDesc = 1 THEN Currency END DESC,
				CASE WHEN @SortType = 4 AND @IsDesc = 1 THEN CurrentWinningThreshold END DESC,
				CASE WHEN @SortType = 5 AND @IsDesc = 1 THEN NoOfReached END DESC,
				CASE WHEN @SortType = 6 AND @IsDesc = 1 THEN LastReachedDate END DESC,
				CASE WHEN @SortType = 7 AND @IsDesc = 1 THEN ProblemPlayer END DESC,
				CASE WHEN @SortType = 8 AND @IsDesc = 1 THEN VIPPlayer END DESC,
				Username ASC

	SELECT @TotalItems = COUNT(1) 
	FROM #Temp2

	SELECT CustID					
		,username2				
		,username				
		,ExchangeId				
		,Currency				
		,CurrentWinningThreshold	
		,NoOfReached				
		,LastReachedDate			
		,ProblemPlayer			
		,VIPPlayer				
		,ReachedWinLossAmount	
		,ReachedWinningThreshold	
		,recommend
		,RowNumber
	FROM  #Temp2
	WHERE RowNumber BETWEEN @rowstart AND @rowend 	
	ORDER BY RowNumber

	DROP TABLE #Temp
	DROP TABLE #Temp2
	DROP TABLE #TempAg
	DROP TABLE #TempHistory
END
GO
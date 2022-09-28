/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE dbo.Acc_Dep_WLMonitored_HistorySelByAG
	 @AgentList	VARCHAR(MAX)
	,@Sporttype SMALLINT = 0
	,@FromDate DATETIME
	,@ToDate DATETIME
	,@XMLReachList	 VARCHAR(MAX) OUTPUT
AS  
/*  
	Created:	20220523@Eden
	Task:		Get reach history by Agents
	DB:			DBEXT-bodb02
	Original:	
  
	Revisions:  
	    - 20220523@Eden: LAP - Player Segmentation - Monitored Player [Redmine:#172605]

	Param's Explanation:

	Sample:
	DECLARE @XMLReachList	 VARCHAR(MAX)
	EXEC Acc_Dep_WLMonitored_HistorySelByAG 
		     @AgentList='<ROOT>
							<Agent AgentId="1015423" Currency="2"/>
							<Agent AgentId="791088" Currency="2"/>
						</ROOT>'
			,@FromDate = '2022/09/01'
			,@ToDate = '2022/09/18'
			,@XMLReachList = @XMLReachList OUTPUT
	SELECT CONVERT(XML,@XMLReachList) AS XMLReachList
	
*/  
BEGIN 
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

	DECLARE @Sql NVARCHAR(MAX) 

	CREATE TABLE #Dep_WLMonitored_Player_History(
		[CustID] [int],
		[AccumWL] [money],
		[WinningThreshold] [money],
		[CreatedDate] [datetime]
	)
	CREATE TABLE #TempHistory(
		[CustID] [int],
		[ReachedCnt] [int],
		[AccumWL] [money],
		[WinningThreshold] [money],
		[CreatedDate] [datetime]
	)
	
	INSERT INTO #Dep_WLMonitored_Player_History(CustID,AccumWL,WinningThreshold,CreatedDate)
	SELECT ci.CustID, w.AccumWL, w.WinningThreshold, w.CreatedDate
	FROM bodb02.dbo.Dep_WLMonitored_Player_History w WITH(NOLOCK)
		INNER JOIN bodb02.dbo.custinfo ci WITH(NOLOCK) ON ci.custid = w.custid
	WHERE ci.recommend IN (SELECT * FROM #TempAg)
		AND sporttype = @Sporttype
		AND ci.roleid = 1
		AND w.CreatedDate >= @FromDate
		AND w.CreatedDate < @ToDate + 1

	;WITH TMP AS(
	SELECT CustID, CreatedDate,WinningThreshold,AccumWL
		, ROW_NUMBER() OVER (PARTITION BY CustID ORDER BY CreatedDate DESC,AccumWL DESC,WinningThreshold DESC) AS RN
		, ROW_NUMBER() OVER (PARTITION BY CustID ORDER BY CreatedDate,AccumWL,WinningThreshold ) AS RN2
	FROM #Dep_WLMonitored_Player_History
	)
	INSERT INTO #TempHistory(CustID,ReachedCnt,CreatedDate,WinningThreshold,AccumWL)
	SELECT t.custid,
		RN2 AS ReachedCnt,
		t.CreatedDate,
		t.WinningThreshold,
		t.AccumWL
	FROM TMP t
	WHERE RN = 1

	SELECT @XMLReachList =
							(
								SELECT CustID,ReachedCnt,AccumWL,WinningThreshold,CreatedDate 
								FROM #TempHistory
								FOR XML RAW('R'), ROOT ('ROOT')
							)

	DROP TABLE #Dep_WLMonitored_Player_History
	DROP TABLE #TempAg
	DROP TABLE #TempHistory
END
GO
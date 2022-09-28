/*<info serverAlias="DBCUST-CUSTDB" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE dbo.Acc_Dep_WLMonitored_Player_Del
	 @CustList VARCHAR(MAX) = ''
	,@AgentList VARCHAR(MAX) = ''
	,@Sporttype SMALLINT = 0
	,@ErrCode INT = 0 OUT
	,@ErrMsg VARCHAR(500) = '' OUT
	,@UserId INT = 0
	,@IP VARCHAR(20) = ''
AS  
/*  
	Created:	20220523@Eden
	Task:		Delete Player threshold (Member)
	DB:			DBCUST-CUSTDB
	Original:	
  
	Revisions:  
	    - 20220523@Eden: LAP - Player Segmentation - Monitored Player [Redmine:#172605]

	Param's Explanation:  	

	DECLARE @ErrCode INT = 0 ,@ErrMsg VARCHAR(500) = ''
	EXEC Acc_Dep_WLMonitored_Player_Del 
		 @CustList = '29047611,29049901,50991198,111111'
		,@AgentList='<ROOT><Agent AgentId="3233923" Currency="2"/></ROOT>'
		,@Sporttype = 0
		,@ErrCode = @ErrCode OUT
		,@ErrMsg = @ErrMsg OUT
		,@UserID=338
		,@IP='10.18.200.204'
	SELECT @ErrCode, @ErrMsg

	
*/  
BEGIN
	SET NOCOUNT ON
	
	DECLARE @startRun DATETIME, @endRun DATETIME, @duration INT
	DECLARE @ActionID INT = 31807
	DECLARE @CustID INT
	DECLARE @TrackingValue1 VARCHAR(MAX) = ''

	CREATE TABLE #Cust_Tbl(CustID INT)
	CREATE TABLE #Cust_Tbl_Batch(CustID INT)
	DECLARE @Cust_log TABLE(CustID INT,IsLog BIT DEFAULT 0)

	SET @startRun = GETDATE()

	CREATE TABLE #TempAg (custid INT)
	DECLARE @DocHandler INT
		
	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@AgentList
	
		INSERT INTO #TempAg(CustId)
		SELECT AgentId
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int]) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT @ErrCode = 1000
			,@ErrMsg = N'Invalid parameter.'

		RETURN
	END CATCH;

	INSERT INTO #Cust_Tbl(CustID)
	SELECT DISTINCT value 
	FROM string_split(@CustList,',')
	WHERE value <> ''

	DELETE t
	FROM customer ci WITH(NOLOCK)
		INNER JOIN #Cust_Tbl t 
			ON ci.custid = t.CustID
	WHERE roleid != 1
	
	DELETE t
	FROM customer ci WITH(NOLOCK)
		INNER JOIN #Cust_Tbl t 
			ON ci.custid = t.CustID
	WHERE ci.recommend NOT IN (SELECT custid FROM #TempAg)

	WHILE 1 = 1
	BEGIN
		TRUNCATE TABLE #Cust_Tbl_Batch

		DELETE TOP(5000) t
		OUTPUT deleted.CUSTID INTO #Cust_Tbl_Batch(CustID)
		FROM #Cust_Tbl t

		IF @@ROWCOUNT = 0
			BREAK

		DELETE g
		OUTPUT deleted.CustID INTO @Cust_log(CustID)
		FROM Dep_WLMonitored_Player g WITH(ROWLOCK,UPDLOCK)
			INNER JOIN #Cust_Tbl_Batch t 
				ON g.CustID = t.CustID
		WHERE g.Sporttype = @Sporttype
	END

	SELECT @EndRun = GETDATE()    
	SELECT @Duration  = DATEDIFF (MILLISECOND,@startRun,@endRun)

	--Process log
	WHILE 1 = 1
	BEGIN
		UPDATE TOP(1) t
		SET t.IsLog = 1
			,@CustID = t.CustID
		FROM @Cust_log t
		WHERE t.IsLog = 0

		IF @@ROWCOUNT = 0
			BREAK

		SELECT  @TrackingValue1 = '<R '
						+ 'IP="' + COALESCE(@IP, SPACE(1)) + '" '
						+ 'Sporttype="'+ coalesce(cast(@Sporttype as varchar(10)),space(1)) + '" '
						+ ' />'

		EXEC dbo.Acc_WriteLog_UserLog_RunSP_Wrapper
				@UserId				= @UserId,
				@CustId				= 0,
				@ActionId			= @ActionID,
				@TrackingValue		= @TrackingValue1,
				@Duration			= @Duration
	END

	DROP TABLE #Cust_Tbl
	DROP TABLE #Cust_Tbl_Batch
	DROP TABLE #TempAg
END	
GO
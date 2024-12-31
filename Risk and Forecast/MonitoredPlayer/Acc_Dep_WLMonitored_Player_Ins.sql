/*<info serverAlias="DBCUST-CUSTDB" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE dbo.Acc_Dep_WLMonitored_Player_Ins
	 @AgentList VARCHAR(MAX) = ''
	,@CustID INT = NULL
	,@Sporttype SMALLINT = 0
	,@username VARCHAR(30) = ''
	,@username2 VARCHAR(50) = ''
	,@WinningThreshold MONEY = NULL
	,@ErrCode INT = 0 OUT
	,@ErrMsg VARCHAR(500) = '' OUT
	,@UserId INT = 0
	,@IP VARCHAR(20) = ''
AS  
/*  
	Created:	20220523@Eden
	Task:		Insert Player threshold (Member), single
	DB:			DBCUST-CUSTDB
	Original:	
  
	Revisions:  
	    - 20220523@Eden: LAP - Player Segmentation - Monitored Player [Redmine:#172605]
		- 20241230@Aries: Scale Out DBCUST - Apply Inhouse replication for the remaning tables [Redmine: #215627]

	Param's Explanation:  	
		@ErrCode =
				1000: Invalid parameter.
				100: Invalid System ID
				101: Invalid External ID
				102: <System ID/External ID> is existing in the list. Please check again!
				103: Invalid Daily Winning Threshold
				104: Invalid account
				0: Update successfully

	DECLARE @ErrCode INT = 0 ,@ErrMsg VARCHAR(500) = ''
	exec Acc_Dep_WLMonitored_Player_Ins 
	     @AgentList='<ROOT><Agent AgentId="3233923" Currency="2"/></ROOT>'
		,@Username='SPONUUS01462'
		,@Username2=''
		,@WinningThreshold = 100
		,@ErrCode = @ErrCode OUT
		,@ErrMsg = @ErrMsg OUT
		,@UserID=338,@IP='10.18.200.204'
	SELECT @ErrCode, @ErrMsg

	
*/  
BEGIN
	SET NOCOUNT ON
	
	DECLARE @startRun DATETIME, @endRun DATETIME, @duration INT
	DECLARE @ActionID INT = 31805
	DECLARE @TrackingValue1 VARCHAR(MAX) = ''
	DECLARE @Site varchar(10)
	DECLARE @CurrentDTS DATETIME

	SET @startRun = GETDATE()

	IF @WinningThreshold IS NULL OR @WinningThreshold < 0
	BEGIN
			SELECT @ErrCode = 103
				,@ErrMsg = N'Invalid Daily Winning Threshold'

			RETURN
	END

	CREATE TABLE #TempAg (custid INT)
	DECLARE @DocHandler INT
		
	IF ISNULL(@CustID,0) = 0 --Single Insert
	BEGIN
		IF ISNULL(@username,'')<> '' AND ISNULL(@username2,'')<> ''
		BEGIN 
			SELECT @ErrCode = 1000
				,@ErrMsg = N'Invalid parameter.'
			RETURN
		END

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

		IF @username2 <> ''
		BEGIN
			SELECT TOP (1) @Site = ci.Site 
			FROM #TempAg t
				INNER JOIN customer ci WITH(NOLOCK) ON  ci.custid = t.custid

			SELECT @custid = ci.custid
			FROM customer ci WITH(NOLOCK)
			WHERE recommend IN (SELECT custid FROM #TempAg)
				AND roleid = 1	
				AND ci.username2 = @site +  '$' + @username2

			IF ISNULL(@CustID,0) = 0
			BEGIN
				SELECT @ErrCode = 101
					,@ErrMsg = N'Invalid External ID'

				RETURN
			END

			IF EXISTS ( SELECT 1 FROM Dep_WLMonitored_Player WITH(NOLOCK) WHERE CustID = @CustID AND Sporttype = @Sporttype)
			BEGIN
					SELECT @ErrCode = 102
						,@ErrMsg = @username2 + N' is existing in the list. Please check again!'

					RETURN
			END
		END
		ELSE
		BEGIN
			SELECT @custid = ci.custid
			FROM customer ci WITH(NOLOCK)
			WHERE recommend IN (SELECT custid FROM #TempAg)
				AND roleid = 1	
				AND ci.username = @username

			IF ISNULL(@CustID,0) = 0
			BEGIN
				SELECT @ErrCode = 100
					,@ErrMsg = N'Invalid System ID'

				RETURN
			END

			IF EXISTS ( SELECT 1 FROM Dep_WLMonitored_Player WITH(NOLOCK) WHERE CustID = @CustID AND Sporttype = @Sporttype)
			BEGIN
					SELECT @ErrCode = 102
						,@ErrMsg = @username + N' is existing in the list. Please check again!'

					RETURN
			END
		END
	END

	SET @CurrentDTS = GETDATE()

	INSERT INTO Dep_WLMonitored_Player(CustID,Sporttype,WinningThreshold,WinningUpdateTime,InitSettingTime,RepUpdateTime)
	SELECT @CustID,@Sporttype,@WinningThreshold,@CurrentDTS,@CurrentDTS,dbo.f_GetDateTime2()
	
	SELECT @EndRun = GETDATE()    
	SELECT @Duration  = DATEDIFF (MILLISECOND,@startRun,@endRun)

	SELECT  @TrackingValue1 = '<R '
						+ 'IP="' + COALESCE(@IP, SPACE(1)) + '" '
						+ 'Sporttype="'+ coalesce(cast(@Sporttype as varchar(10)),space(1)) + '" '
						+ 'WinningThreshold="'+ coalesce(cast(@WinningThreshold as varchar(50)),'') + '" '
						+ ' />'

	EXEC dbo.Acc_WriteLog_UserLog_RunSP_Wrapper
			@UserId				= @UserId,
			@CustId				= 0,
			@ActionId			= @ActionID,
			@TrackingValue		= @TrackingValue1,
			@Duration			= @Duration

	DROP TABLE #TempAg
END	
GO
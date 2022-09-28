/*<info serverAlias="DBCUST-CUSTDB" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE dbo.Acc_Dep_WLMonitored_Player_Upd
	 @AgentList VARCHAR(MAX) = ''
	,@CustID INT = NULL
	,@Sporttype SMALLINT = 0
	,@WinningThreshold MONEY = NULL
	,@ErrCode INT = 0 OUT
	,@ErrMsg VARCHAR(500) = '' OUT
	,@UserId INT = 0
	,@IP VARCHAR(20) = ''
	,@IsBatchUpd BIT = 0
AS  
/*  
	Created:	20220523@Eden
	Task:		Update Player threshold (Member), single
	DB:			DBCUST-CUSTDB
	Original:	
  
	Revisions:  
	    - 20220523@Eden: LAP - Player Segmentation - Monitored Player [Redmine:#172605]

	Param's Explanation:  	
		@ErrCode =
				1000: Invalid parameter.
				100: Invalid System ID
				101: Invalid External ID
				103: Invalid Daily Winning Threshold
				104: Invalid account
				105: Could not update because the player no longer exists on the monitored list.
				0: Update successfully

	DECLARE @ErrCode INT = 0 ,@ErrMsg VARCHAR(500) = ''
	exec Acc_Dep_WLMonitored_Player_Upd 
	     @CustID = 29047611
	    ,@WinningThreshold = 100
	    ,@AgentList='<ROOT><Agent AgentId="3233923" Currency="2"/></ROOT>'
		,@ErrCode = @ErrCode OUT
		,@ErrMsg = @ErrMsg OUT
		,@UserID=338,@IP='10.18.200.204'
	SELECT @ErrCode, @ErrMsg

	
*/  
BEGIN
	SET NOCOUNT ON
	
	DECLARE @startRun DATETIME, @endRun DATETIME, @duration INT
	DECLARE @ActionID INT = 31806
	DECLARE @TrackingValue1 VARCHAR(MAX) = '', @TrackingValue2 VARCHAR(MAX) = ''
	DECLARE @WinningThreshold_old MONEY
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
		
	IF @IsBatchUpd = 0
	BEGIN
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

		IF NOT EXISTS(
			SELECT 1
			FROM customer ci WITH(NOLOCK)
			WHERE recommend IN (SELECT custid FROM #TempAg)
				AND roleid = 1
				AND ci.custid = @CustID
		)
		BEGIN
			SELECT @ErrCode = 104
				,@ErrMsg = N'Invalid account'

			RETURN
		END
	END

	SELECT @WinningThreshold_old = WinningThreshold FROM Dep_WLMonitored_Player WITH(NOLOCK) WHERE CustID = @CustID AND Sporttype = @Sporttype

	IF @@ROWCOUNT = 0
	BEGIN
			SELECT @ErrCode = 105
				,@ErrMsg = N'Could not update because the player no longer exists on the monitored list.'

			RETURN
	END

	IF @WinningThreshold = @WinningThreshold_old
		RETURN -- unchanged

	SET @CurrentDTS = GETDATE()

	UPDATE g 
	SET g.WinningThreshold = @WinningThreshold,
		g.WinningUpdateTime = @CurrentDTS
	FROM Dep_WLMonitored_Player g WITH(ROWLOCK,UPDLOCK) 
	WHERE CustID = @CustID 
		AND Sporttype = @Sporttype
	
	SELECT @EndRun = GETDATE()    
	SELECT @Duration  = DATEDIFF (MILLISECOND,@startRun,@endRun)

	SELECT  @TrackingValue1 = '<R '
						+ 'IP="' + COALESCE(@IP, SPACE(1)) + '" '
						+ 'Sporttype="'+ coalesce(cast(@Sporttype as varchar(10)),space(1)) + '" '
						+ 'WinningThreshold="'+ coalesce(cast(@WinningThreshold as varchar(50)),'') + '" '
						+ ' />'

	SELECT  @TrackingValue2 = '<R '
						+ 'IP="' + COALESCE(@IP, SPACE(1)) + '" '
						+ 'Sporttype="'+ coalesce(cast(@Sporttype as varchar(10)),space(1)) + '" '
						+ 'WinningThreshold="'+ coalesce(cast(@WinningThreshold_old as varchar(50)),'') + '" '
						+ ' />'

	EXEC dbo.Acc_WriteLog_UserLog_RunSP_Wrapper
			@UserId				= @UserId,
			@CustId				= 0,
			@ActionId			= @ActionID,
			@TrackingValue		= @TrackingValue1,
			@TrackingValue2		= @TrackingValue2,
			@Duration			= @Duration

	DROP TABLE #TempAg
END	
GO
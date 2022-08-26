/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE Lrf_EnableDisableBAMember @CustId INT
	, @Mode VARCHAR(10)
	, @UpdatedBy INT = 0
	, @Ip VARCHAR(50) = ''

	, @ErrCode INT = 0 OUTPUT
	, @ErrMsg VARCHAR(200) = '' OUTPUT
AS  
/*
Created: 20150305@Patrick
Task : Enable/disable BA member
DB: DBCUST/CustDB
Revisions:
	- 20150305@Patrick: First commit
	- 20220301@Eden: Deposit - Sportsbook - Revise customer settings [Redmine: #167898]
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON
	DECLARE @startRun DATETIME, @endRun DATETIME, @duration INT
	SET @startRun = GETDATE()

	IF @Mode = 'On'
	BEGIN
		IF NOT EXISTS (SELECT 1 FROM dbo.Dep_CustBAActive WITH(NOLOCK) WHERE CustId = @CustId)
		BEGIN
			INSERT INTO dbo.Dep_CustBAActive(CustId)
			VALUES(@CustId)
			
			IF @@ERROR <> 0
			BEGIN
				SELECT @ErrCode = 100, @ErrMsg = 'Fail to enable BA member!'
				RETURN
			END
		END
	END
	ELSE IF @Mode = 'Off'
	BEGIN
		DELETE dbo.Dep_CustBAActive WITH(ROWLOCK)
		WHERE CustId = @CustId

		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrCode = 100, @ErrMsg = 'Fail to disable BA member!'
			RETURN
		END

	END

	SET @endRun = GETDATE()
	SET @duration = DATEDIFF(MILLISECOND, @startRun, @endRun)
	
	--write log
	DECLARE @LogSPData VARCHAR(1024)
	SELECT @LogSPData = '<Lrf_EnableDisableBAMember CustId="' + COALESCE(CAST(@CustId AS VARCHAR(50)), SPACE(1)) 
		+ '" ' + 'Mode="' + COALESCE(CAST(@Mode AS VARCHAR(50)), SPACE(1))
		+ '" ' + 'UpdatedBy="' + COALESCE(CAST(@UpdatedBy AS VARCHAR(50)), SPACE(1))
		+ '" ' + 'Ip="' + COALESCE(CAST(@Ip AS VARCHAR(50)), SPACE(1)) + '" />'

	BEGIN TRY
		EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP @UserID = @UpdatedBy
			, @CustID = @CustId
			, @ActionID = 2418
			, @TrackingValue = @LogSPData
			, @duration = @duration
	END TRY

	BEGIN CATCH
		EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP @UserID = @UpdatedBy
			, @CustID = @CustId
			, @ActionID = 2418
			, @TrackingValue = @LogSPData
			, @duration = @duration
	END CATCH

END
GO

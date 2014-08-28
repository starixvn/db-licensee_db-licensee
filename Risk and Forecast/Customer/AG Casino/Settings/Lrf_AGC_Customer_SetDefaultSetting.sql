ALTER PROCEDURE	dbo.Lrf_AGC_Customer_SetDefaultSetting
	@CustID		INT,
	@SuperID	INT,
	@Language	VARCHAR(10)		= 'en-US',
	@ErrCode	INT				= 0		OUTPUT,
	@ErrMsg		VARCHAR(8000)	= ''	OUTPUT
AS
/*
	Created: 20140818@Victor
	Task: Set default setting of AG Casino product for new member
	DB: DBLIC/bodb_licensee
	Original:
	Revisions:
	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @startRun			DATETIME
			,@endRun			DATETIME
			,@duration			INT
			,@LogSPData			VARCHAR(MAX)
			,@TrackingValue2	VARCHAR(MAX)
			,@AGGroup			VARCHAR(20)		= ''
			,@SIsEnabled		BIT				= 0

	SET @startRun = GETDATE()

	SELECT @AGGroup = ISNULL(DefaultGroup,'')
		,@SIsEnabled = ISNULL(IsEnabled,0)
	FROM DBTXN.CustDB.dbo.Dep_SuperSetting_AGCasino WITH (NOLOCK) 
	WHERE CustID = @SuperID

	DECLARE @CustIDs VARCHAR(20)
	SELECT @CustIDs = CONVERT(VARCHAR(20), @CustID)

	IF (LEN(@AGGroup) = 0)
		RETURN

	EXEC DBTXN.CustDB.dbo.Dep_UpdCustSetting_AGC @CustIDs = @CustIDs, @AGGroup = @AGGroup
	EXEC DBTXN.CustDB.dbo.Dep_UpdCustStatus_AGC @CustIDs = @CustIDs, @IsEnabled = @SIsEnabled

	-- Write log
	SET @endRun = GETDATE()
	SET @duration  = DATEDIFF(MILLISECOND,@startRun,@endRun)

	SELECT @LogSPData = '<Lrf_AGC_Customer_SetDefaultSetting CustID="'+ COALESCE(CAST(@CustID as VARCHAR(50)),SPACE(1)) + '" ' +
						'AGGroup="'+ COALESCE(CAST(@AGGroup as VARCHAR(20)),SPACE(1)) + '" ' +
						'ErrCode="'+ COALESCE(CAST(@ErrCode as VARCHAR(50)),SPACE(1)) + '" ' +
						'ErrMsg="'+ COALESCE(CAST(@ErrMsg as VARCHAR(8000)),SPACE(1))+ '" />'

	SELECT @TrackingValue2 = '<Lrf_AGC_Customer_SetDefaultSetting CustID="'+ COALESCE(CAST(@CustID as VARCHAR(50)),SPACE(1)) + '" ' +
						'AGGroup=" " ' +
						'ErrCode="'+ COALESCE(CAST(@ErrCode as VARCHAR(50)),SPACE(1)) + '" ' +
						'ErrMsg="'+ COALESCE(CAST(@ErrMsg as VARCHAR(8000)),SPACE(1))+ '" />'

	BEGIN TRY
	    EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP 
				    @UserID = @CustID,
				    @CustID = @CustID,
				    @ActionID = 2041,
				    @TrackingValue = @LogSPData,
				    @TrackingValue2 = @TrackingValue2,
				    @duration = @duration
    END TRY
    BEGIN CATCH
	    EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP 
				    @UserID = @CustID,
				    @CustID = @CustID,
				    @ActionID = 2041,
				    @TrackingValue = @LogSPData,
				    @TrackingValue2 = @TrackingValue2,
				    @duration = @duration
    END CATCH
	
END

GO

GRANT EXECUTE ON dbo.Lrf_AGC_Customer_SetDefaultSetting TO Dot_Member
GO
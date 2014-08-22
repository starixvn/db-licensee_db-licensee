ALTER PROCEDURE	dbo.Lrf_AGC_UpdCustStatus
	@CustID		INT,
	@IsEnabled	BIT,
	@UserID		INT,
	@IP			VARCHAR(40),
	@Language	VARCHAR(10)		= 'en-US',
	@ErrCode	INT				= 0		OUTPUT,
	@ErrMsg		VARCHAR(8000)	= ''	OUTPUT
AS
/*
	Created: 20140818@Victor
	Task: Update member status of AG Casino product
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
			,@IsEnableAG_Old		BIT			= 0
	SET @startRun = GETDATE()

	-- Get old status of member
	DECLARE @Srecommend INT
			,@SEnabled INT = 0
	SELECT @Srecommend = srecommend FROM bodb02.dbo.Customer c WITH (NOLOCK) WHERE c.CustID = @CustID

	SELECT @IsEnableAG_Old = ISNULL(IsEnabled,0)
	FROM DBTXN.CustDB.dbo.Dep_CustSetting_AGC WITH (NOLOCK)
	WHERE CustID = @CustId

	SELECT @SEnabled = ISNULL(IsEnabled,0) FROM DBTXN.CustDB.dbo.Dep_SuperSetting_AGC WITH (NOLOCK) WHERE CustID = @Srecommend

	IF (@SEnabled = 0)
		SELECT @IsEnableAG_Old = 0

	-- Call SP to update status
	DECLARE @CustIDs VARCHAR(20)
	SELECT @CustIDs = CONVERT(VARCHAR(20), @CustID)

	EXEC DBTXN.CustDB.dbo.Dep_UpdCustStatus_AGC @CustIDs = @CustIDs, @IsEnabled = @IsEnabled

	-- Write log
	SET @endRun = GETDATE()
	SET @duration  = DATEDIFF(MILLISECOND,@startRun,@endRun)

	SELECT @LogSPData = '<Lrf_AGC_UpdCustStatus CustID="'+ COALESCE(CAST(@CustID as VARCHAR(50)),SPACE(1)) + '" ' +
						'IsEnabled="'+ COALESCE(CAST(@IsEnabled as VARCHAR(1)),SPACE(1)) + '" ' +
						'UserID="'+ COALESCE(CAST(@UserID as VARCHAR(50)),SPACE(1)) + '" ' +
						'IP="'+ COALESCE(CAST(@IP as VARCHAR(40)),SPACE(1)) + '" ' +
						'ErrCode="'+ COALESCE(CAST(@ErrCode as VARCHAR(50)),SPACE(1)) + '" ' +
						'ErrMsg="'+ COALESCE(CAST(@ErrMsg as VARCHAR(8000)),SPACE(1))+ '" />'

	SELECT @TrackingValue2 = '<Lrf_AGC_UpdCustStatus CustID="'+ COALESCE(CAST(@CustID as VARCHAR(50)),SPACE(1)) + '" ' +
						'IsEnabled="'+ COALESCE(CAST(@IsEnableAG_Old as VARCHAR(1)),SPACE(1)) + '" ' +
						'UserID="'+ COALESCE(CAST(@UserID as VARCHAR(50)),SPACE(1)) + '" ' +
						'IP="'+ COALESCE(CAST(@IP as VARCHAR(40)),SPACE(1)) + '" ' +
						'ErrCode="'+ COALESCE(CAST(@ErrCode as VARCHAR(50)),SPACE(1)) + '" ' +
						'ErrMsg="'+ COALESCE(CAST(@ErrMsg as VARCHAR(8000)),SPACE(1))+ '" />'

	BEGIN TRY
	    EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP 
				    @UserID = @UserID,
				    @CustID = @CustID,
				    @ActionID = 2211,
				    @TrackingValue = @LogSPData,
				    @TrackingValue2 = @TrackingValue2,
				    @duration = @duration
    END TRY
    BEGIN CATCH
	    EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP 
				    @UserID = @UserID,
				    @CustID = @CustID,
				    @ActionID = 2211,
				    @TrackingValue = @LogSPData,
				    @TrackingValue2 = @TrackingValue2,
				    @duration = @duration
    END CATCH
END

GO
GRANT EXECUTE ON dbo.Lrf_AGC_UpdCustStatus TO bodbLicenseeNet
GO
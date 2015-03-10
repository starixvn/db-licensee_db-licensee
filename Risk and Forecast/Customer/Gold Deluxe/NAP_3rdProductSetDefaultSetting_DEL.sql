ALTER PROCEDURE	dbo.NAP_3rdProductSetDefaultSetting
	@CustID		INT,
	@SuperID	INT,
	@UserID		INT,
	@Language	VARCHAR(10)		= 'en-US',
	@ErrCode	INT				= 0		OUTPUT,
	@ErrMsg		VARCHAR(8000)	= ''	OUTPUT 
AS
/*
	Created: 20150309@Winnie
	Task: Set default setting of 3rd Casino product for new member
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
			,@SIsEnabled		BIT				= 0

	SET @startRun = GETDATE()

	SELECT 		@SIsEnabled = ISNULL(IsEnabled,0)
	FROM DBTXN.CustDB.dbo.Dep_SupperProductSetting WITH (NOLOCK) 
	WHERE CustID = @SuperID

	DECLARE @CustIDs VARCHAR(20)
	SELECT @CustIDs = CONVERT(VARCHAR(20), @CustID)	
			
	EXEC DBTXN.CustDB.dbo.Dep_UpdCustStatus3rdProduct @CustIDs = @CustIDs, @IsEnabled = @SIsEnabled

	-- Write log
	SET @endRun = GETDATE()
	SET @duration  = DATEDIFF(MILLISECOND,@startRun,@endRun)

	SELECT @LogSPData = '<NAP_3rdProductSetDefaultSetting CustID="'+ COALESCE(CAST(@CustID as VARCHAR(50)),SPACE(1)) + '" ' +
					
						'ErrCode="'+ COALESCE(CAST(@ErrCode as VARCHAR(50)),SPACE(1)) + '" ' +
						'ErrMsg="'+ COALESCE(CAST(@ErrMsg as VARCHAR(8000)),SPACE(1))+ '" />'

	SELECT @TrackingValue2 = '<NAP_3rdProductSetDefaultSetting CustID="'+ COALESCE(CAST(@CustID as VARCHAR(50)),SPACE(1)) + '" ' +
						
						'ErrCode="'+ COALESCE(CAST(@ErrCode as VARCHAR(50)),SPACE(1)) + '" ' +
						'ErrMsg="'+ COALESCE(CAST(@ErrMsg as VARCHAR(8000)),SPACE(1))+ '" />'

	BEGIN TRY
	    EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP 
				    @UserID = @UserID,
				    @CustID = @CustID,
				    @ActionID = 2041,
				    @TrackingValue = @LogSPData,
				    @TrackingValue2 = @TrackingValue2,
				    @duration = @duration
    END TRY
    BEGIN CATCH
	    EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP 
				    @UserID = @UserID,
				    @CustID = @CustID,
				    @ActionID = 2041,
				    @TrackingValue = @LogSPData,
				    @TrackingValue2 = @TrackingValue2,
				    @duration = @duration
    END CATCH
	
END

GO

GRANT EXECUTE ON dbo.NAP_3rdProductSetDefaultSetting TO Dot_Member
GO
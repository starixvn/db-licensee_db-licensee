ALTER PROCEDURE	dbo.Lrf_AGC_Customer_SetDefaultSetting
	@CustID		INT,
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
			,@Srecommend		INT

	SET @startRun = GETDATE()
	SELECT @Srecommend = srecommend FROM bodb02.dbo.Customer c WITH (NOLOCK) WHERE c.CustID = @CustID

	SELECT @AGGroup = ISNULL(DefaultGroup,'')
	FROM DBTXN.CustDB.dbo.Dep_SuperSetting_AGC WITH (NOLOCK) 
	WHERE CustID = @Srecommend

	DECLARE @CustIDs VARCHAR(20)
	SELECT @CustIDs = CONVERT(VARCHAR(20), @CustID)

	EXEC DBTXN.CustDB.dbo.Dep_UpdCustSetting_AGC @CustIDs = @CustIDs, @AGGroup = @AGGroup

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

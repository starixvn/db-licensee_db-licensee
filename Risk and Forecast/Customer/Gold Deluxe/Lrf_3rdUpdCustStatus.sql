ALTER PROCEDURE	dbo.Lrf_3rdUpdCustStatus
	@CustID		INT,
	@ProductId	INT,
	@IsEnabled	BIT,
	@UserID		INT,
	@IP			VARCHAR(40),
	@Language	VARCHAR(10)		= 'en-US',	
	@ErrMsg		VARCHAR(100)	= ''	OUTPUT 
AS
/*
	Created: 20150306@Winnie
	Task: Update member status of 3rd product
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
			,@IsEnable_Old		BIT			= 0
	SET @startRun = GETDATE()

	-- Get old status of member
	DECLARE @Srecommend INT
			,@SEnabled INT = 0
	SELECT @Srecommend = srecommend FROM bodb02.dbo.Customer c WITH (NOLOCK) WHERE c.CustID = @CustID

	SELECT @IsEnable_Old = ISNULL(IsEnabled,0)
	FROM DBTXN.CustDB.dbo.Dep_CustProductSetting WITH (NOLOCK)
	WHERE CustID = @CustId AND ProductId=@ProductId

	SELECT @SEnabled = ISNULL(IsEnabled,0) FROM DBTXN.CustDB.dbo.Dep_SupperProductSetting WITH (NOLOCK) WHERE CustID = @Srecommend AND ProductId=@ProductId

	IF (@SEnabled = 0)
		SELECT @IsEnable_Old = 0

	-- Call SP to update status
	DECLARE @CustIDs VARCHAR(20)
	SELECT @CustIDs = CONVERT(VARCHAR(20), @CustID)

	EXEC DBTXN.CustDB.dbo.Dep_3rdProductUpdCustStatus @CustIDs = @CustIDs, @IsEnabled = @IsEnabled,@ProductId=@ProductId,@ErrMsg=@ErrMsg
	IF(@@ERROR<>0)
	BEGIN
	SELECT @ErrMsg='Could not update'
	RETURN
	END
	-- Write log
	SET @endRun = GETDATE()
	SET @duration  = DATEDIFF(MILLISECOND,@startRun,@endRun)

	SELECT @LogSPData = '<Lrf_3rdUpdCustStatus CustID="'+ COALESCE(CAST(@CustID as VARCHAR(50)),SPACE(1)) + '" ' +
						'ProductId="'+ COALESCE(CAST(@ProductId as VARCHAR(1)),SPACE(1)) + '" ' +
						'IsEnabled="'+ COALESCE(CAST(@IsEnabled as VARCHAR(1)),SPACE(1)) + '" ' +
						'UserID="'+ COALESCE(CAST(@UserID as VARCHAR(50)),SPACE(1)) + '" ' +
						'IP="'+ COALESCE(CAST(@IP as VARCHAR(40)),SPACE(1)) + '" ' +						
						'ErrMsg="'+ COALESCE(CAST(@ErrMsg as VARCHAR(8000)),SPACE(1))+ '" />'

	SELECT @TrackingValue2 = '<Lrf_3rdUpdCustStatus CustID="'+ COALESCE(CAST(@CustID as VARCHAR(50)),SPACE(1)) + '" ' +
						'ProductId="'+ COALESCE(CAST(@ProductId as VARCHAR(1)),SPACE(1)) + '" ' +
						'IsEnabled="'+ COALESCE(CAST(@IsEnable_Old as VARCHAR(1)),SPACE(1)) + '" ' +
						'UserID="'+ COALESCE(CAST(@UserID as VARCHAR(50)),SPACE(1)) + '" ' +
						'IP="'+ COALESCE(CAST(@IP as VARCHAR(40)),SPACE(1)) + '" ' +						
						'ErrMsg="'+ COALESCE(CAST(@ErrMsg as VARCHAR(8000)),SPACE(1))+ '" />'

	BEGIN TRY
	    EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP 
				    @UserID = @UserID,
				    @CustID = @CustID,
				    @ActionID = 2213,
				    @TrackingValue = @LogSPData,
				    @TrackingValue2 = @TrackingValue2,
				    @duration = @duration
    END TRY
    BEGIN CATCH
	    EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP 
				    @UserID = @UserID,
				    @CustID = @CustID,
				    @ActionID = 2213,
				    @TrackingValue = @LogSPData,
				    @TrackingValue2 = @TrackingValue2,
				    @duration = @duration
    END CATCH
END

GO
GRANT EXECUTE ON dbo.Lrf_3rdUpdCustStatus TO bodbLicenseeNet
GO
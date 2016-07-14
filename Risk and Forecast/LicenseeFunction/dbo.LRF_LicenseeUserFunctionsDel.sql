ALTER  PROCEDURE [dbo].[Lrf_LicenseeUserFunctionsDel]	
	@LicenseeId INT,
	@UserId INT,
	@CustID INT,
	@Langkey VARCHAR(10) = 'en-US',
	@IP VARCHAR(50)='',
	@FunctionId INT,
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg nvarchar(4000) = '' OUTPUT
AS
/*
	Created by: [20111210@Jacob]
	Task: Break down permission for account management
	DB: DB052.bodb_Licensee
	Param's Explanation:
		
	Revisions: -20160707@Jim: change the way to grant ACCOUNT MANAGEMENT FUNCTIONS permission ( #58537)
		
	Example:

*/

SET NOCOUNT ON

DECLARE @startRun DATETIME
DECLARE @endRun DATETIME
DECLARE @duration INT
SET @startRun = GETDATE()
IF (@FunctionId<>6)
	BEGIN
		DELETE FROM [dbo].[LicenseeUserFunctions]
		WHERE LicenseeId = @LicenseeId AND 
			 UserId = @CustID AND
			 FunctionId = @FunctionId
	END
	ELSE IF (@FunctionId=6)
	BEGIN 
		DELETE FROM [dbo].[LicenseeUserFunctions]
		WHERE LicenseeId = @LicenseeId AND 
			 UserId = @CustID AND
			 FunctionID IN (SELECT FunctionID FROM dbo.Functions WITH (NOLOCK) WHERE ParentId=6 OR  FunctionId=6)
	END
IF (@@ERROR<>0)	

	BEGIN 
		SELECT @ErrMsg = 
				CASE @Langkey 
					WHEN 'en-US' THEN 'Delete process is unsuccessful!'
					ELSE [bodb02].[dbo].[Lrf_f_Get_MsgNamebyMsgID](200048,@Langkey)
				END, @ErrCode = 101
	RETURN 			
	END 
				 
DECLARE @TrackingValue VARCHAR(2000)


SELECT @TrackingValue = '<Lrf_LicenseeUserFunctionsDel CustID="'+ COALESCE(CAST(@CustID AS VARCHAR(50)),SPACE(1)) + '" ' +
					'LicenseeID="'+ COALESCE(CAST(@LicenseeId AS VARCHAR(50)),SPACE(1)) + '" ' +
					'UserID="'+ COALESCE(CAST(@UserID AS VARCHAR(50)),SPACE(1)) + '" ' +
					'FunctionID="'+ COALESCE(CAST(@FunctionId AS VARCHAR(50)),SPACE(1)) + '" ' +
					'IP="'+ COALESCE(CAST(@IP AS VARCHAR(50)),SPACE(1))+'" />'
					



SET @endRun = GETDATE()
SET @duration  = DATEDIFF (MILLISECOND,@startRun,@endRun)	 

EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
	@UserID = @UserID,
	@CustID = @CustID,
	@ActionID = 2405,
	@TrackingValue = @TrackingValue,
	@duration = @duration

GO
GRANT EXECUTE ON [dbo].[Lrf_LicenseeUserFunctionsDel] TO [bodbLicenseeNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_LicenseeUserFunctionsDel] TO [vnteam] 
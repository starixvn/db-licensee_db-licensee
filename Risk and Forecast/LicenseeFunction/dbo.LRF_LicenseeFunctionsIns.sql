ALTER  PROCEDURE [dbo].[Lrf_LicenseeFunctionsIns]	
	@LicenseeId INT,
	@FunctionId INT,
	@UserId INT,	
	@IP VARCHAR(50)=''	
AS
/*
	Created by: [20111210@Jacob]
	Task: Break down permission for account management
	DB: DB052.bodb_Licensee
	Param's Explanation:
		
	Revisions:
	
	
*/

SET NOCOUNT ON




IF NOT EXISTS (
SELECT 1 FROM [dbo].[LicenseeFunctions] WITH(NOLOCK)
WHERE LicenseeId = @LicenseeId AND 	  
	  FunctionId = @FunctionId
	  )
BEGIN
	DECLARE @startRun DATETIME
	DECLARE @endRun DATETIME
	DECLARE @duration INT
	SET @startRun = GETDATE()


	INSERT INTO [dbo].[LicenseeFunctions](LicenseeId, FunctionId)
	VALUES(@LicenseeId,@FunctionId)
	
	
	DECLARE @TrackingValue VARCHAR(2000)
	
	SELECT @TrackingValue = '<Lrf_LicenseeFunctionsIns '+
						'LicenseeID="'+ COALESCE(CAST(@LicenseeId AS VARCHAR(50)),SPACE(1)) + '" ' +
						'UserID="'+ COALESCE(CAST(@UserID AS VARCHAR(50)),SPACE(1)) + '" ' +
						'FunctionID="'+ COALESCE(CAST(@FunctionId AS VARCHAR(50)),SPACE(1)) + '" ' +
						'IP="'+ COALESCE(CAST(@IP AS VARCHAR(50)),SPACE(1))+'" />'
						
	


	SET @endRun = GETDATE()
	SET @duration  = DATEDIFF (MILLISECOND,@startRun,@endRun)	 

	EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
		@UserID = @UserID,
		@CustID = 0,
		@ActionID = 2411,
		@TrackingValue = @TrackingValue,
		@duration = @duration
END



GO
GRANT EXECUTE ON [dbo].[Lrf_LicenseeFunctionsIns] TO [bodbLicenseeNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_LicenseeFunctionsIns] TO [vnteam] 
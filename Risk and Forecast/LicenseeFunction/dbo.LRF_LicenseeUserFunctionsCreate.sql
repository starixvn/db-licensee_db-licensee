
CREATE  PROCEDURE [dbo].[LRF_LicenseeUserFunctionsCreate]	
	@LicenseeId INT,
	@UserId INT,
	@FunctionId INT
AS
/*
	Created by: [20111210@Jacob]
	Task: Break down permission for account management
	DB: DB052.bodb_Licensee
	Param's Explanation:
		
	Revisions:
	
	Example:
		EXEC [dbo].[LRF_LicenseeUserFunctionsCreate] @LicenseeId=1, @UserId = 1, @FunctionId = 1
*/

SET NOCOUNT ON

DECLARE @Existed BIT

SELECT @Existed = 1 
FROM [dbo].[LicenseeUserFunctions] WITH(NOLOCK)
WHERE @LicenseeId = LicenseeId AND 
	  @UserId = UserId AND
	  @FunctionId = FunctionId
	  
IF @Existed IS NULL
BEGIN	  	
	INSERT INTO [dbo].[LicenseeUserFunctions](LicenseeId, UserId, FunctionId)
	VALUES(@LicenseeId,@UserId, @FunctionId)
END


GO
GRANT EXECUTE ON [dbo].[LRF_LicenseeUserFunctionsCreate] TO [bodbLicenseeNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[LRF_LicenseeUserFunctionsCreate] TO [vnteam] 
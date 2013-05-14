ALTER PROCEDURE [dbo].[LRF_FunctionsDel]  
@FunctionId INT, 
@UserId INT, 
@IP VARCHAR(50)  
  
AS  

/*
	Created by: [20111210@Jacob]
	Task: Break down permission for account management
	DB: DB052.bodb_Licensee
	Param's Explanation:		
	Revisions:
	
	Example:
		
*/
DECLARE @startRun DATETIME  
DECLARE @endRun DATETIME  
DECLARE @duration INT  
SET @startRun = GETDATE()  
   
DELETE FROM [dbo].[Functions] WHERE FunctionId = @FunctionId
DELETE FROM [dbo].[LicenseeFunctions] WHERE FunctionId = @FunctionId
DELETE FROM [dbo].[LicenseeUserFunctions] WHERE FunctionId = @FunctionId
   
  
 DECLARE @TrackingValue VARCHAR(2000)  
   
   
SELECT @TrackingValue = '<LRF_FunctionsDel ' +
					'FunctionID="'+ COALESCE(CAST(@FunctionId AS VARCHAR(50)),SPACE(1)) + '" ' +
					'UserID="'+ COALESCE(CAST(@UserID AS VARCHAR(50)),SPACE(1)) + '" ' +					
					'IP="'+ COALESCE(CAST(@IP AS VARCHAR(50)),SPACE(1))+'" />'
				 
  
 SET @endRun = GETDATE()  
 SET @duration  = DATEDIFF (MILLISECOND,@startRun,@endRun)    
  
 EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP  
  @UserID = @UserID,  
  @CustID = 0,  
  @ActionID = 2409,  
  @TrackingValue = @TrackingValue,  
  @duration = @duration  
  
 
  
  
GO
GRANT EXECUTE ON [dbo].[LRF_FunctionsDel] TO [bodbLicenseeNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[LRF_FunctionsDel] TO [vnteam] 
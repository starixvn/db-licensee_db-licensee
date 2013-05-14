ALTER PROCEDURE [dbo].[LRF_FunctionsIns]  
	@Name NVARCHAR(100),  
	@Description NVARCHAR(4000)=N'',  
	@ParentId  INT = 0,  
	@Url VARCHAR(200),  
	@IsMenu BIT = 0,  
	@IsActive BIT =1,  
	@DisplayOrder INT=0,  
	@IsNew INT =0,  
	@UserId INT, 
	@FunctionId INT OUTPUT, 
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
   
  
 INSERT INTO [dbo].[Functions]
           ([Name]
           ,[Description]
           ,[ParentId]
           ,[Url]
           ,[IsMenu]
           ,[IsActive]
           ,[DisplayOrder]
           ,[IsNew])
     VALUES(@Name,
			@Description,
			@ParentId,
			@Url,
			@IsMenu,
			@IsActive,
			@DisplayOrder,
			@IsNew) 
			
   
 SELECT @FunctionId = @@Identity  
   
  
 DECLARE @TrackingValue VARCHAR(2000)  
   
SELECT @TrackingValue = '<LRF_FunctionsIns ' +
					'FunctionID="'+ COALESCE(CAST(@FunctionId AS VARCHAR(50)),SPACE(1)) + '" ' +
					'UserID="'+ COALESCE(CAST(@UserID AS VARCHAR(50)),SPACE(1)) + '" ' +					
					'IP="'+ COALESCE(CAST(@IP AS VARCHAR(50)),SPACE(1))+'" />'
				 
  
 SET @endRun = GETDATE()  
 SET @duration  = DATEDIFF (MILLISECOND,@startRun,@endRun)    
  
 EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP  
  @UserID = @UserID,  
  @CustID = 0,  
  @ActionID = 2410,  
  @TrackingValue = @TrackingValue,  
  @duration = @duration  
  
 
  
  
GO
GRANT EXECUTE ON [dbo].[LRF_FunctionsIns] TO [bodbLicenseeNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[LRF_FunctionsIns] TO [vnteam] 
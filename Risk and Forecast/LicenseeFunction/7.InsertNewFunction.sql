-- Parameters
DECLARE @FunctionId INT
DECLARE @ParentId INT
DECLARE @DisplayOrder INT
DECLARE @FunctionName NVARCHAR(200)
DECLARE @Description NVARCHAR(4000)
DECLARE @Url VARCHAR(400)
DECLARE @IsMenu BIT
DECLARE @LicenseeIdList TABLE(LicenseeId INT)
DECLARE @LicenseeIdListString VARCHAR(200) 
DECLARE @OldFunctionCount INT

SELECT	@ParentId = 3,
		@OldFunctionCount = 10, -- If user has permission on 10 child functions, assign this function to her/him
		@DisplayOrder = 41,
		@FunctionName = N'Mobile Win Loss',
		@Description = N'',
		@Url = 'Reports/MobileWinloss',
		@IsMenu = 1,
		@LicenseeIdListString = ',1,2,3,4,5,6,7,8,9,10,11,12,14,15,16,17,'

-- End of Parameters

SELECT @FunctionId = FunctionId FROM [dbo].[Functions] WHERE [Name] = @FunctionName

IF @FunctionId IS NOT NULL
BEGIN
	DELETE [dbo].[Functions] WHERE FunctionId = @FunctionId
	DELETE LicenseeFunctions WHERE FunctionId = @FunctionId
	DELETE LicenseeUserFunctions WHERE FunctionId = @FunctionId
END


INSERT INTO @LicenseeIdList(LicenseeId)
SELECT FunctionId
FROM [Functions] 
WHERE CHARINDEX(','+ RTRIM(LTRIM(CONVERT(VARCHAR(10),FunctionId))) + ',',@LicenseeIdListString)>0
	

-- Insert new function	

INSERT [dbo].[Functions] ([Name], [Description], [ParentId], [Url], [IsMenu], [IsActive], [DisplayOrder], [IsNew]) 
VALUES (@FunctionName, @Description, @ParentId, @Url, @IsMenu, 0, @DisplayOrder, 1) 

SELECT @FunctionId =@@IDENTITY

--DELETE LicenseeFunctions WHERE FunctionId = @FunctionId

--DELETE LicenseeUserFunctions WHERE FunctionId = @FunctionId


-- Licensee Functions
DECLARE @LicenseeId INT
DECLARE @UserId INT

INSERT INTO [LicenseeFunctions](LicenseeId, FunctionId)
SELECT LicenseeId, @FunctionId 
FROM @LicenseeIdList

-- LicenseeUserFunctions

INSERT INTO [LicenseeUserFunctions](LicenseeId, UserId, FunctionId)	
SELECT LicenseeId, UserId, @FunctionId
FROM LicenseeUserFunctions l 
INNER JOIN Functions u ON l.FunctionId = u.FunctionId
WHERE u.ParentId =@ParentId
GROUP BY LicenseeId, UserId
HAVING COUNT(l.FunctionId) >= @OldFunctionCount
ORDER BY LicenseeId, UserId


GO
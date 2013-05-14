

USE [bodb_Licensee]
GO


TRUNCATE TABLE [LicenseeUserFunctions]

GO

SET NOCOUNT ON;

DECLARE @LicenseeUserId INT, @LicenseeId INT,  @UserId INT, @PageAccess VARCHAR(1000);


DECLARE LicenseeUserId_Cursor CURSOR FOR 
SELECT LicenseeId, UserId, PageAccess
FROM LicenseeUser

OPEN LicenseeUserId_Cursor;

FETCH NEXT FROM LicenseeUserId_Cursor 
INTO @LicenseeId, @UserId, @PageAccess;


WHILE @@FETCH_STATUS = 0
BEGIN
    PRINT ' Start to process User Id = ' + Convert(varchar(20), @UserId) + '. LicenseeId= ' + Convert(varchar(20), @LicenseeId ) ;
    
/*
1	TOTALBETS
2	FORECAST
3	REPORTS
4	CUSTOMER INFOMATION
5	DATA WAREHOUSE
6	ACCOUNT MANAGEMENT
*/
    
    IF CHARINDEX('TotalBets', @PageAccess) > 0 
    BEGIN
		INSERT INTO [LicenseeUserFunctions](LicenseeId, UserId, FunctionId)
		SELECT DISTINCT @LicenseeId, @UserId, f.FunctionId 
		FROM [Functions] f WITH(NOLOCK)
			INNER JOIN [LicenseeFunctions] l WITH(NOLOCK) ON f.FunctionId = l.FunctionId
		WHERE l.LicenseeId =@LicenseeId			
		AND (f.FunctionId = 1 OR f.ParentId = 1)
    END
    
	IF CHARINDEX('Forecast', @PageAccess) > 0
    BEGIN
		INSERT INTO [LicenseeUserFunctions](LicenseeId, UserId, FunctionId)
		SELECT DISTINCT @LicenseeId, @UserId, f.FunctionId 
		FROM [Functions] f WITH(NOLOCK)
			INNER JOIN [LicenseeFunctions] l WITH(NOLOCK) ON f.FunctionId = l.FunctionId
		WHERE l.LicenseeId =@LicenseeId			
		AND (f.FunctionId = 2 OR f.ParentId = 2)
    END
    
     IF CHARINDEX('Reports', @PageAccess) > 0
    BEGIN
		INSERT INTO [LicenseeUserFunctions](LicenseeId, UserId, FunctionId)
		SELECT DISTINCT @LicenseeId, @UserId, f.FunctionId 
		FROM [Functions] f WITH(NOLOCK)
			INNER JOIN [LicenseeFunctions] l WITH(NOLOCK) ON f.FunctionId = l.FunctionId
		WHERE l.LicenseeId =@LicenseeId			
		AND (f.FunctionId = 3 OR f.ParentId = 3)
    END
    
     IF CHARINDEX('ManageMember', @PageAccess) > 0
    BEGIN
		INSERT INTO [LicenseeUserFunctions](LicenseeId, UserId, FunctionId)
		SELECT DISTINCT @LicenseeId, @UserId, f.FunctionId 
		FROM [Functions] f WITH(NOLOCK)
			INNER JOIN [LicenseeFunctions] l WITH(NOLOCK) ON f.FunctionId = l.FunctionId
		WHERE l.LicenseeId =@LicenseeId			
		AND (f.FunctionId = 4 OR f.ParentId = 4)
    END
    
     IF CHARINDEX('DataWarehouse', @PageAccess) > 0
    BEGIN
		INSERT INTO [LicenseeUserFunctions](LicenseeId, UserId, FunctionId)
		SELECT DISTINCT @LicenseeId, @UserId, f.FunctionId 
		FROM [Functions] f WITH(NOLOCK)
			INNER JOIN [LicenseeFunctions] l WITH(NOLOCK) ON f.FunctionId = l.FunctionId
		WHERE l.LicenseeId =@LicenseeId			
		AND (f.FunctionId = 5 OR f.ParentId = 5)
    END
    
     IF CHARINDEX('ManageAccount', @PageAccess) > 0
    BEGIN
		INSERT INTO [LicenseeUserFunctions](LicenseeId, UserId, FunctionId)
		SELECT DISTINCT @LicenseeId, @UserId, f.FunctionId 
		FROM [Functions] f WITH(NOLOCK)
			INNER JOIN [LicenseeFunctions] l WITH(NOLOCK) ON f.FunctionId = l.FunctionId
		WHERE l.LicenseeId =@LicenseeId			
		AND (f.FunctionId = 6 OR f.ParentId = 6)
    END
    
    
	FETCH NEXT FROM LicenseeUserId_Cursor 
	INTO @LicenseeId, @UserId, @PageAccess;
END

CLOSE LicenseeUserId_Cursor;
DEALLOCATE LicenseeUserId_Cursor;
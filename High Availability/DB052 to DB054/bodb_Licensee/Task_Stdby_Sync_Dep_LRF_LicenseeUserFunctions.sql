IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Task_Stdby_Sync_Dep_LRF_LicenseeUserFunctions]') AND type in (N'P', N'PC'))
	DROP PROCEDURE [dbo].[Task_Stdby_Sync_Dep_LRF_LicenseeUserFunctions]
GO

CREATE PROCEDURE [dbo].[Task_Stdby_Sync_Dep_LRF_LicenseeUserFunctions]
AS
/*
Created	: 20140527@Don
Task	: LRF >> LicenseeUserFunctions - Sync data 
DB		: DB054.bodb_Licensee

Revisions:
	- 20140630@Don: Add check on duplicate key values
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @MAX_Backup_UserFuncionId INT	= 0

	SELECT @MAX_Backup_UserFuncionId		= MAX(UserFuncionId) FROM bodb_Licensee.dbo.LicenseeUserFunctions WITH(NOLOCK)

	SET IDENTITY_INSERT bodb_Licensee.dbo.LicenseeUserFunctions ON

	SELECT UserFuncionId,UserId,FunctionId,LicenseeId 
	INTO #temp
	FROM DBLIC.bodb_Licensee.dbo.LicenseeUserFunctions WITH(NOLOCK)
	WHERE UserFuncionId > @MAX_Backup_UserFuncionId

	IF EXISTS(
		SELECT * 
		FROM bodb_Licensee.dbo.LicenseeUserFunctions ia WITH(NOLOCK) 
			INNER JOIN #temp a ON ia.LicenseeId = a.LicenseeId AND ia.UserId = a.UserId AND ia.FunctionId = a.FunctionId
	)
		DELETE ia
		FROM bodb_Licensee.dbo.LicenseeUserFunctions ia
			INNER JOIN #temp a ON ia.LicenseeId = a.LicenseeId AND ia.UserId = a.UserId AND ia.FunctionId = a.FunctionId
	
	INSERT INTO bodb_Licensee.dbo.LicenseeUserFunctions(UserFuncionId,UserId,FunctionId,LicenseeId)
		SELECT UserFuncionId,UserId,FunctionId,LicenseeId 
		FROM #temp

	SET IDENTITY_INSERT bodb_Licensee.dbo.LicenseeUserFunctions OFF
	
	DROP TABLE #temp
END



GO
GRANT VIEW DEFINITION ON [dbo].[Task_Stdby_Sync_Dep_LRF_LicenseeUserFunctions] TO [vnteam]
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Task_Stdby_Sync_Dep_LRF_LicenseeCustinfo]') AND type in (N'P', N'PC'))
	DROP PROCEDURE [dbo].[Task_Stdby_Sync_Dep_LRF_LicenseeCustinfo]
GO

CREATE PROCEDURE [dbo].[Task_Stdby_Sync_Dep_LRF_LicenseeCustinfo]
AS
/*
Created	: 20140527@Don
Task	: LRF >> LicenseeCustinfo - Sync data 
DB		: DB054.bodb_Licensee

Revisions:
		
*/
BEGIN
	SET NOCOUNT ON
	
	CREATE TABLE #MissingData(recommend INT)

	SELECT recommend, COUNT(*) NoOfMembers into #Main FROM DBLIC.bodb_Licensee.dbo.LicenseeCustinfo WITH(NOLOCK) GROUP BY recommend
	SELECT recommend, COUNT(*) NoOfMembers into #Backup FROM bodb_Licensee.dbo.LicenseeCustinfo WITH(NOLOCK) GROUP BY recommend

	INSERT INTO #MissingData(recommend)
		SELECT m.recommend
		FROM #Main m 
			LEFT JOIN #Backup b ON m.recommend = b.recommend
		WHERE m.NoOfMembers != b.NoOfMembers

	DROP TABLE #Main
	DROP TABLE #Backup

	DECLARE @TempData TABLE(recommend INT)
	WHILE (1=1)
	BEGIN

		DELETE @TempData
		DELETE TOP(1) #MissingData OUTPUT deleted.* INTO @TempData

		IF @@ROWCOUNT > 0 
		BEGIN

			DELETE bodb_Licensee.dbo.LicenseeCustinfo 
			WHERE recommend IN (SELECT recommend FROM @TempData)

			INSERT INTO bodb_Licensee.dbo.LicenseeCustinfo(Custid,recommend,username,username2,currency,SpecialLevel)				SELECT Custid,recommend,username,username2,currency,SpecialLevel 
				FROM DBLIC.bodb_Licensee.dbo.LicenseeCustinfo WITH(NOLOCK)
				WHERE recommend IN (SELECT recommend FROM @TempData)

		END
		ELSE
			BREAK
	
	END
	
	DROP TABLE #MissingData
END



GO
GRANT VIEW DEFINITION ON [dbo].[Task_Stdby_Sync_Dep_LRF_LicenseeCustinfo] TO [vnteam]
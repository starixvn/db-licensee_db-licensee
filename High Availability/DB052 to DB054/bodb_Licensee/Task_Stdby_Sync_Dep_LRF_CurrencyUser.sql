IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Task_Stdby_Sync_Dep_LRF_CurrencyUser]') AND type in (N'P', N'PC'))
	DROP PROCEDURE [dbo].[Task_Stdby_Sync_Dep_LRF_CurrencyUser]
GO

CREATE PROCEDURE [dbo].[Task_Stdby_Sync_Dep_LRF_CurrencyUser]
AS
/*
Created	: 20140527@Don
Task	: LRF >> CurrencyUser - Sync data 
DB		: DB054.bodb_Licensee

Revisions:
		
*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #MissingData(LicenseeID INT)
	
	SELECT LicenseeID, COUNT(*) NoOfPermissions INTO #Main FROM DBLIC.bodb_licensee.dbo.CurrencyUser WITH(NOLOCK) WHERE SystemID = 1 GROUP BY LicenseeID
	SELECT LicenseeID, COUNT(*) NoOfPermissions INTO #Backup FROM bodb_licensee.dbo.CurrencyUser WITH(NOLOCK) WHERE SystemID = 1 GROUP BY LicenseeID

	INSERT INTO #MissingData(LicenseeID)
		SELECT m.LicenseeID
		FROM #Main m 
			LEFT JOIN #Backup b ON m.LicenseeID = b.LicenseeID
		WHERE m.NoOfPermissions != b.NoOfPermissions

	DROP TABLE #Main
	DROP TABLE #Backup

	DECLARE @TempData TABLE(LicenseeID INT)
	WHILE (1=1)
	BEGIN

		DELETE @TempData
		DELETE TOP(1) #MissingData OUTPUT deleted.* INTO @TempData

		IF @@ROWCOUNT > 0 
		BEGIN

			DELETE bodb_Licensee.dbo.CurrencyUser 
			WHERE 
				SystemID = 1 
				AND LicenseeID IN (SELECT LicenseeID FROM @TempData)

			INSERT INTO bodb_Licensee.dbo.CurrencyUser(usrID,LicenseeID,CurrencyID,SystemID,isActive)
				SELECT usrID,LicenseeID,CurrencyID,SystemID,isActive 
				FROM DBLIC.bodb_Licensee.dbo.CurrencyUser WITH(NOLOCK)
				WHERE 
					SystemID = 1 
					AND LicenseeID IN (SELECT LicenseeID FROM @TempData)

		END
		ELSE
			BREAK
	
	END
	
	DROP TABLE #MissingData

END



GO
GRANT VIEW DEFINITION ON [dbo].[Task_Stdby_Sync_Dep_LRF_CurrencyUser] TO [vnteam]
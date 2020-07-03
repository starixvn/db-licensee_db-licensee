/*<info serverAlias="DBCUST-bodb_licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Nap_LM_ITUser_UpdateCurrency]
	@UserId INT,
	@ActiveCurrencies VARCHAR(MAX) = '',
	@DeactiveCurrencies VARCHAR(MAX) = '',
	@SystemId INT = 1
AS
/*
	 Created: Amanda
	 Date: 2019-01-30
	 Task: Implement "IT User Management" function
	 DB: DBCUST.bodb_licensee
	 
	 Revisions:
	  - 20190130@Amanda: Assign/Remove function for user [Redmine: #83584]
	  
	 Developer's Note:
	  - @ActiveCurrencies: <ROOT>
						<LicenseeCurrency LicenseeName="1" CurrencyId="1"/>  
						<LicenseeCurrency LicenseeName="1" CurrencyId="2"/>
					  </ROOT>
	  - @DeactiveCurrencies: <ROOT>
						<LicenseeCurrency LicenseeName="1" CurrencyId="1"/>  
						<LicenseeCurrency LicenseeName="1" CurrencyId="2"/>
					  </ROOT>

*/
BEGIN
	SET NOCOUNT ON;
	
	IF (ISNULL(@ActiveCurrencies, '') = '' AND ISNULL(@DeactiveCurrencies, '') = '')
	BEGIN
		SELECT 'Invalid parameters!' AS [Message]
		RETURN
	END

	DECLARE @Status VARCHAR(30)
	SELECT @Status = [Status] FROM dbo.Users WITH (NOLOCK) WHERE UserID = @UserId AND isInternal = 0
	
	IF @Status IS NULL
	BEGIN
		SELECT 'User does not exist!' AS [Message]
		RETURN
	END

	IF @Status <> 'Open'
	BEGIN
		SELECT 'User is not active!' AS [Message]
		RETURN
	END
	
	DECLARE @Result AS TABLE ([Message] VARCHAR(MAX), IsOk BIT)
	CREATE TABLE #AssignedCurrencies (CurrencyId INT, LicenseeId INT, LicenseeName VARCHAR(50), IsLicenseeActive BIT, IsCurrencyExist BIT, IsLimited BIT)
	CREATE TABLE #RemovedCurrencies (CurrencyId INT, LicenseeName VARCHAR(50))

	IF ISNULL(@ActiveCurrencies, '') <> ''
	BEGIN
		DECLARE @ActiveCurrencyDoc INT

		BEGIN TRY
			EXEC sp_xml_preparedocument @ActiveCurrencyDoc OUTPUT
					,@ActiveCurrencies
			INSERT INTO #AssignedCurrencies (LicenseeName, CurrencyId)
			SELECT LicenseeName, CurrencyId
			FROM OPENXML(@ActiveCurrencyDoc, '/ROOT/LicenseeCurrency', 1) WITH (LicenseeName VARCHAR(50), CurrencyId INT) AS Data

			EXEC sp_xml_removedocument @ActiveCurrencyDoc
		END TRY

		BEGIN CATCH
			INSERT INTO @Result([Message], IsOk)
			SELECT 'Invalid parameter!' AS [Message] , 0
		END CATCH;
	END
	
	IF ISNULL(@DeactiveCurrencies, '') <> ''
	BEGIN
		DECLARE @DeactiveCurrencyDoc INT

		BEGIN TRY
			EXEC sp_xml_preparedocument @DeactiveCurrencyDoc OUTPUT
					,@DeactiveCurrencies
			INSERT INTO #RemovedCurrencies (LicenseeName, CurrencyId)
			SELECT LicenseeName, CurrencyId
			FROM OPENXML(@DeactiveCurrencyDoc, '/ROOT/LicenseeCurrency', 1) WITH (LicenseeName VARCHAR(50), CurrencyId INT) AS Data

			EXEC sp_xml_removedocument @DeactiveCurrencyDoc
		END TRY

		BEGIN CATCH
			INSERT INTO @Result([Message], IsOk)
			SELECT 'Invalid parameter!' AS [Message] , 0
		END CATCH;
	END
	
	IF NOT EXISTS (SELECT TOP(1) 1 FROM @Result WHERE IsOk = 0)
	BEGIN
		IF EXISTS (SELECT TOP(1) 1 FROM #AssignedCurrencies)
		BEGIN
			UPDATE a
			SET a.LicenseeId = l.LicenseeID,
				a.IsLicenseeActive = l.IsActive
			FROM #AssignedCurrencies a
			INNER JOIN dbo.Licensees l WITH (NOLOCK) ON a.LicenseeName = l.LicenseeName
			INNER JOIN dbo.LicenseeUser lu WITH (NOLOCK) ON lu.LicenseeID = l.LicenseeID
			INNER JOIN dbo.SystemLicensee ls WITH (NOLOCK) ON l.LicenseeID = ls.LicenseeID
			INNER JOIN dbo.LicenseeReseller lr WITH (NOLOCK) ON l.LicenseeID = lr.LicenseeID
			INNER JOIN dbo.Resellers r WITH (NOLOCK) ON lr.ResellerID = r.ResellerID
			WHERE lu.UserID = @UserId AND ls.SystemID = @SystemId AND ls.IsActive = 1 AND lr.ResellerID <> 3
			
			IF EXISTS (SELECT TOP(1) 1 FROM #AssignedCurrencies WHERE LicenseeId IS NULL)
			BEGIN
				INSERT INTO @Result([Message], IsOk)
				SELECT '- Licensees do not exist or are not active for LRF system or User does not belong to.(' + STUFF((
								SELECT ', ' + LicenseeName
								FROM #AssignedCurrencies
								WHERE LicenseeId IS NULL
				FOR XML PATH('')), 1, 2, '') + ')', 1
			END
			
			IF EXISTS (SELECT TOP(1) 1 FROM #AssignedCurrencies WHERE LicenseeId IS NOT NULL AND IsLicenseeActive = 0)
			BEGIN
			INSERT INTO @Result([Message], IsOk)
			SELECT '- Licensees are not active.(' + STUFF((
							SELECT ', ' + LicenseeName
							FROM #AssignedCurrencies
							WHERE LicenseeId IS NOT NULL AND IsLicenseeActive = 0
			FOR XML PATH('')), 1, 2, '') + ')', 1
			END

			UPDATE a
			SET a.IsCurrencyExist = 1, IsLimited = CASE WHEN cl.CurrencyId IS NOT NULL THEN 1 ELSE NULL END
			FROM #AssignedCurrencies a
			LEFT JOIN dbo.Lrf_f_LicenseeCurrencyLimit_Main() cl ON a.LicenseeID = cl.LicenseeID AND a.CurrencyId = cl.CurrencyID
			WHERE a.LicenseeId IS NOT NULL
				AND a.IsLicenseeActive = 1
				AND EXISTS (SELECT TOP(1) 1 FROM dbo.LicenseeCust lu WITH (NOLOCK) WHERE lu.LicenseeID = a.LicenseeId AND lu.Currency = a.CurrencyId AND lu.RoleID = 2)
			
			IF EXISTS (SELECT TOP(1) 1 FROM #AssignedCurrencies WHERE LicenseeId IS NOT NULL AND IsLicenseeActive = 1 AND ( IsCurrencyExist IS NULL OR IsLimited = 1 ))
			BEGIN
				INSERT INTO @Result([Message], IsOk)
				SELECT '- Licensees do not offer the following currencies.(' + STUFF((
								SELECT ', ' + LicenseeName + '(ID: ' + CAST(CurrencyId AS VARCHAR(10)) + ')'
								FROM #AssignedCurrencies
								WHERE LicenseeId IS NOT NULL AND IsLicenseeActive = 1 AND ( IsCurrencyExist IS NULL OR IsLimited = 1 )
				FOR XML PATH('')), 1, 2, '') + ')', 1
			END
			
			DELETE #AssignedCurrencies WHERE LicenseeId IS NULL OR IsLicenseeActive = 0 OR IsCurrencyExist IS NULL OR IsLimited = 1
			
			UPDATE cu
			SET cu.isActive = 1
			FROM dbo.CurrencyUser cu WITH (ROWLOCK, UPDLOCK)
			INNER JOIN #AssignedCurrencies a ON cu.LicenseeID = a.LicenseeId AND cu.CurrencyID = a.CurrencyId
			WHERE cu.usrID = @UserId AND cu.SystemID = @SystemId AND cu.isActive = 0
			
			INSERT INTO dbo.CurrencyUser (CurrencyID, LicenseeID, usrID, isActive, SystemID)
			SELECT a.CurrencyId, a.LicenseeId, @UserId, 1, @SystemId
			FROM #AssignedCurrencies a
			WHERE NOT EXISTS (
						SELECT TOP(1) 1
						FROM dbo.CurrencyUser cu WITH (NOLOCK)
						WHERE cu.usrID = @UserId AND cu.LicenseeID = a.LicenseeId AND cu.CurrencyID = a.CurrencyId AND cu.SystemID = @SystemId)
			
		END

		IF EXISTS (SELECT TOP(1) 1 FROM #RemovedCurrencies)
		BEGIN
			UPDATE cu
			SET cu.isActive = 0
			FROM dbo.CurrencyUser cu WITH (ROWLOCK, UPDLOCK)
			INNER JOIN #RemovedCurrencies r ON cu.CurrencyID = r.CurrencyId
			INNER JOIN dbo.Licensees l WITH (NOLOCK) ON r.LicenseeName = l.LicenseeName AND cu.LicenseeId = l.LicenseeID
			WHERE cu.usrID = @UserId AND cu.SystemID = @SystemId AND cu.isActive = 1
		END
	END
	
	IF EXISTS (SELECT TOP(1) 1 FROM @Result WHERE IsOk = 1)
	BEGIN
		SELECT 'Currencies are not actived for the following licensees:' AS [Message], 1 AS IsOk
		UNION ALL
		SELECT [Message], IsOk
		FROM @Result
	END
	ELSE
	BEGIN
		SELECT [Message], IsOk
		FROM @Result
	END
	
	DROP TABLE #AssignedCurrencies
	DROP TABLE #RemovedCurrencies
END
GO
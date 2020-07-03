/*<info serverAlias="DBCUST-bodb_licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Nap_LM_ITUser_UpdateFunction]
	@UserId INT,
	@NewFunctions VARCHAR(MAX) = '',
	@RemovedFunctions VARCHAR(MAX) = '',
	@SystemId INT = 1
AS
/*
	 Created: Amanda
	 Date: 2019-01-28
	 Task: Implement "IT User Management" function
	 DB: DBCUST.bodb_licensee
	 
	 Revisions:
	  - 20190128@Amanda: Assign/Remove function for user [Redmine: #83584]
	  
	 Developer's Note:
	  - @NewFunctions: <ROOT>
						<LicenseeFunction LicenseeName="1" FunctionId="1"/>  
						<LicenseeFunction LicenseeName="1" FunctionId="2"/>
					  </ROOT>
	  - @RemoveFunctions: <ROOT>
						<LicenseeFunction LicenseeName="1" FunctionId="1"/>  
						<LicenseeFunction LicenseeName="1" FunctionId="2"/>
					  </ROOT>

*/
BEGIN
	SET NOCOUNT ON;
	
	IF (ISNULL(@NewFunctions, '') = '' AND ISNULL(@RemovedFunctions, '') = '')
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
	CREATE TABLE #AssignedFunctions (FunctionId INT, LicenseeId INT, LicenseeName VARCHAR(50), IsFunctionExist BIT, IsLicenseeActive BIT)
	CREATE TABLE #RemovedFunctions (FunctionId INT, LicenseeName VARCHAR(50))

	IF ISNULL(@NewFunctions, '') <> ''
	BEGIN
		DECLARE @NewFunctionDoc INT

		BEGIN TRY
			EXEC sp_xml_preparedocument @NewFunctionDoc OUTPUT
					,@NewFunctions
			INSERT INTO #AssignedFunctions (LicenseeName, FunctionId)
			SELECT LicenseeName, FunctionId
			FROM OPENXML(@NewFunctionDoc, '/ROOT/LicenseeFunction', 1) WITH (LicenseeName VARCHAR(50), FunctionId INT) AS Data

			EXEC sp_xml_removedocument @NewFunctionDoc
		END TRY

		BEGIN CATCH
			INSERT INTO @Result([Message], IsOk)
			SELECT 'Invalid parameter!' AS [Message] , 0 	
		END CATCH;
	END
	
	IF ISNULL(@RemovedFunctions, '') <> ''
	BEGIN
		DECLARE @RemoveFunctionDoc INT

		BEGIN TRY
			EXEC sp_xml_preparedocument @RemoveFunctionDoc OUTPUT
					,@RemovedFunctions
			INSERT INTO #RemovedFunctions (LicenseeName, FunctionId)
			SELECT LicenseeName, FunctionId
			FROM OPENXML(@RemoveFunctionDoc, '/ROOT/LicenseeFunction', 1) WITH (LicenseeName VARCHAR(50), FunctionId INT) AS Data

			EXEC sp_xml_removedocument @RemoveFunctionDoc
		END TRY

		BEGIN CATCH
			INSERT INTO @Result([Message], IsOk)
			SELECT 'Invalid parameter!' AS [Message] , 0	
		END CATCH;
	END
	
	IF NOT EXISTS (SELECT TOP(1) 1 FROM @Result WHERE IsOk = 0)
	BEGIN
		IF EXISTS (SELECT TOP(1) 1 FROM #AssignedFunctions)
		BEGIN
			UPDATE a
			SET a.LicenseeId = l.LicenseeID,
				a.IsLicenseeActive = l.IsActive
			FROM #AssignedFunctions a
			INNER JOIN dbo.Licensees l WITH (NOLOCK) ON a.LicenseeName = l.LicenseeName
			INNER JOIN dbo.LicenseeUser lu WITH (NOLOCK) ON lu.LicenseeID = l.LicenseeID
			INNER JOIN dbo.SystemLicensee ls WITH (NOLOCK) ON l.LicenseeID = ls.LicenseeID
			INNER JOIN dbo.LicenseeReseller lr WITH (NOLOCK) ON l.LicenseeID = lr.LicenseeID
			INNER JOIN dbo.Resellers r WITH (NOLOCK) ON lr.ResellerID = r.ResellerID
			WHERE lu.UserID = @UserId AND lu.isActive = 1 AND ls.SystemID = @SystemId AND ls.IsActive = 1 AND lr.ResellerID <> 3
			
			IF EXISTS (SELECT TOP(1) 1 FROM #AssignedFunctions WHERE LicenseeId IS NULL)
			BEGIN
				INSERT INTO @Result([Message], IsOk)
				SELECT '- Licensees do not exist or are not active for LRF system or User does not belong to.(' + STUFF((
								SELECT ', ' + LicenseeName
								FROM #AssignedFunctions
								WHERE LicenseeId IS NULL
				FOR XML PATH('')), 1, 2, '') + ')', 1
			END
			
			IF EXISTS (SELECT TOP(1) 1 FROM #AssignedFunctions WHERE LicenseeId IS NOT NULL AND IsLicenseeActive = 0)
			BEGIN
			INSERT INTO @Result([Message], IsOk)
			SELECT '- Licensees are not active.(' + STUFF((
							SELECT ', ' + LicenseeName
							FROM #AssignedFunctions
							WHERE LicenseeId IS NOT NULL AND IsLicenseeActive = 0
			FOR XML PATH('')), 1, 2, '') + ')', 1
			END
			
			UPDATE a
			SET a.IsFunctionExist = 1
			FROM #AssignedFunctions a
			INNER JOIN dbo.Functions f WITH (NOLOCK) ON a.FunctionId = f.FunctionId
			INNER JOIN dbo.LicenseeFunctions lf WITH (NOLOCK) ON lf.LicenseeID = a.LicenseeId AND f.FunctionId = lf.FunctionId
			WHERE a.LicenseeId IS NOT NULL AND a.IsLicenseeActive = 1
			
			IF EXISTS (SELECT TOP(1) 1 FROM #AssignedFunctions WHERE LicenseeId IS NOT NULL AND IsLicenseeActive = 1 AND IsFunctionExist IS NULL)
			BEGIN
			INSERT INTO @Result([Message], IsOk)
			SELECT '- Functions do not exist or are not in Licensee function list.(' + STUFF((
							SELECT ', ' + LicenseeName + '(ID: ' + CAST(FunctionId AS VARCHAR(10)) + ')'
							FROM #AssignedFunctions
							WHERE LicenseeId IS NOT NULL AND IsLicenseeActive = 1 AND IsFunctionExist IS NULL
			FOR XML PATH('')), 1, 2, '') + ')', 1
			END

			DELETE #AssignedFunctions WHERE LicenseeId IS NULL OR IsLicenseeActive = 0 OR IsFunctionExist IS NULL
			
			INSERT INTO dbo.LicenseeUserFunctions (UserId, LicenseeId, FunctionId)
			SELECT @UserId, a.LicenseeId, a.FunctionId
			FROM #AssignedFunctions a
			WHERE NOT EXISTS (
							SELECT TOP(1) 1
							FROM dbo.LicenseeUserFunctions luf WITH (NOLOCK)
							WHERE luf.UserId = @UserId AND luf.LicenseeId = a.LicenseeId AND luf.FunctionId = a.FunctionId
						)
		END

		IF EXISTS (SELECT TOP(1) 1 FROM #RemovedFunctions)
		BEGIN
			DELETE luf
			FROM dbo.LicenseeUserFunctions luf WITH (ROWLOCK)
			INNER JOIN #RemovedFunctions r ON r.FunctionId = luf.FunctionId
			INNER JOIN dbo.Licensees l WITH (NOLOCK) ON r.LicenseeName = l.LicenseeName AND luf.LicenseeId = l.LicenseeID
			WHERE luf.UserId = @UserId
		END
	END
	
	IF EXISTS (SELECT TOP(1) 1 FROM @Result WHERE IsOk = 1)
	BEGIN
		SELECT 'Functions are not assigned to the following licensees:' AS [Message], 1 AS IsOk
		UNION ALL
		SELECT [Message], IsOk
		FROM @Result
	END
	ELSE
	BEGIN
		SELECT [Message], IsOk
		FROM @Result
	END
	
	DROP TABLE #AssignedFunctions
	DROP TABLE #RemovedFunctions
END
GO
/*<info serverAlias="DBCUST-bodb_licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Nap_LM_ITUser_AssignToLicensee]
	@UserId	INT,
	@AssignedLicensees VARCHAR(MAX) = '',
	@UnassignedLicensees VARCHAR(MAX) = '',
	@AssignOption INT = 0,
	@RemoveOption INT = 0,
	@SystemId INT = 1
AS
/*
	 Created: Amanda
	 Date: 2019-01-24
	 Task: Implement "IT User Management" function
	 DB: DBCUST.bodb_licensee
	 
	 Revisions:
	  - 20190124@Amanda: Add/Remove Licensee for User [Redmine: #83584]
	  
	 Developer's Note:
	  - @AssignedLicensees: 'licenseeName1,licenseeName2,licenseeName3' or 'All'
	  - @UnassignedLicensees: 'licenseeName1,licenseeName2,licenseeName3'
	  - @AssignOption:
		+ 0: Only add licensee
		+ 1: Assign all currencies and functions, excluding "Account Management" and "Notification"
		+ 2: Assign all currencies and functions, including "Account Management" and "Notification"
	  - @RemoveOption:
	    + 0: Only remove licensee
		+ 1: Remove all currencies and functions of removed licensees from user
*/
BEGIN
	SET NOCOUNT ON;
		
	DECLARE @Status VARCHAR(30), @Role VARCHAR(50), @UserName VARCHAR(50)
	SELECT @Status = [Status], @Role = UserRole, @UserName = Username FROM dbo.Users WITH (NOLOCK) WHERE UserID = @UserId AND isInternal = 0

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
	
	DECLARE @Result AS TABLE ([Message] VARCHAR(MAX))
	CREATE TABLE #AssignedLicensee (Id INT, Name VARCHAR(50), IsActive BIT, IsAssigned BIT, IsActiveUser BIT)
		
	IF @Role <> 'Admin' AND ISNULL(@AssignedLicensees, '') <> '' AND (CHARINDEX(',', @AssignedLicensees) > 0 OR @AssignedLicensees = 'ALL')
	BEGIN
		SELECT 'Can not add multiple Licensees for a Licensee user!' AS [Message], 1 AS IsOk
	END
	ELSE
	BEGIN
		DECLARE @Date DATETIME = GETDATE()

		IF @AssignedLicensees = 'All'
		BEGIN
			;WITH LicenseeUser_CTE AS (
				SELECT lu.LicenseeID, lu.isActive
				FROM dbo.LicenseeUser lu WITH (NOLOCK)
				WHERE lu.UserID = @UserId
			)
			INSERT INTO #AssignedLicensee(Id, IsAssigned, IsActiveUser)
			SELECT DISTINCT l.LicenseeID, CASE WHEN cte.LicenseeID IS NULL THEN 0 ELSE 1 END AS IsAssigned, cte.isActive
			FROM dbo.Licensees l WITH (NOLOCK)
			INNER JOIN dbo.SystemLicensee ls WITH (NOLOCK) ON l.LicenseeID = ls.LicenseeID
			INNER JOIN dbo.LicenseeReseller lr WITH (NOLOCK) ON l.LicenseeID = lr.LicenseeID
			INNER JOIN dbo.Resellers r WITH (NOLOCK) ON lr.ResellerID = r.ResellerID
			LEFT JOIN LicenseeUser_CTE cte ON l.LicenseeID = cte.LicenseeID
			WHERE l.IsActive = 1
				AND ls.SystemID = @SystemId
				AND ls.IsActive = 1
				AND lr.ResellerID <> 3
				AND (cte.LicenseeID IS NULL OR cte.isActive = 0) 
		END
		
		IF (ISNULL(@AssignedLicensees,'') <> '') AND @AssignedLicensees <> 'All'
		BEGIN
			INSERT INTO #AssignedLicensee(Name)
			SELECT DISTINCT val
			FROM CUSTDB.dbo.strSplit(@AssignedLicensees,',')

			-- Validate
			UPDATE a
			SET a.Id = l.LicenseeID, a.IsActive = l.IsActive
			FROM #AssignedLicensee a
			INNER JOIN dbo.Licensees l WITH (NOLOCK) ON a.Name = l.LicenseeName
			INNER JOIN dbo.SystemLicensee ls WITH (NOLOCK) ON l.LicenseeID = ls.LicenseeID
			INNER JOIN dbo.LicenseeReseller lr WITH (NOLOCK) ON l.LicenseeID = lr.LicenseeID
			INNER JOIN dbo.Resellers r WITH (NOLOCK) ON lr.ResellerID = r.ResellerID
			WHERE ls.SystemID = @SystemId AND ls.IsActive = 1 AND lr.ResellerID <> 3
			
			UPDATE a
			SET a.IsAssigned = 1, a.IsActiveUser = l.isActive
			FROM #AssignedLicensee a
			INNER JOIN dbo.LicenseeUser l WITH (NOLOCK) ON a.Id = l.LicenseeId
			WHERE a.Id IS NOT NULL AND a.IsActive = 1 AND l.UserID = @UserId
			
			IF EXISTS (SELECT TOP(1) 1 FROM #AssignedLicensee WHERE Id IS NULL)
			BEGIN
				INSERT INTO @Result([Message])
				SELECT '- Licensees do not exist or are not active for LRF system.(' + STUFF((
								SELECT ', ' + Name
								FROM #AssignedLicensee
								WHERE Id IS NULL
				FOR XML PATH('')), 1, 2, '') + ')'
			END

			IF EXISTS (SELECT TOP(1) 1 FROM #AssignedLicensee WHERE Id IS NOT NULL AND IsActive = 0)
			BEGIN
				INSERT INTO @Result([Message])
				SELECT '- Licensees are not active.(' + STUFF((
								SELECT ', ' + Name
								FROM #AssignedLicensee
								WHERE Id IS NOT NULL AND IsActive = 0
				FOR XML PATH('')), 1, 2, '') + ')'
			END
			
			IF EXISTS (SELECT TOP(1) 1 FROM #AssignedLicensee WHERE IsAssigned = 1 AND IsActiveUser = 1)
			BEGIN
				INSERT INTO @Result([Message])
				SELECT '- Licensees have been added this user before.(' + STUFF((
								SELECT ', ' + Name
								FROM #AssignedLicensee
								WHERE IsAssigned = 1 AND IsActiveUser = 1
				FOR XML PATH('')), 1, 2, '') + ')'
			END
			
			DELETE #AssignedLicensee WHERE Id IS NULL OR IsActive = 0 OR (IsAssigned = 1 AND IsActiveUser = 1)
		END
		
		IF EXISTS (SELECT TOP(1) 1 FROM #AssignedLicensee)
		BEGIN
			IF @Role = 'Licensee'
			BEGIN
				UPDATE dbo.Users WITH (ROWLOCK, UPDLOCK)
				SET LicenseeName = @AssignedLicensees
				WHERE UserID = @UserId
			END
		
			-- Update licensee users that were closed
			UPDATE lu
			SET lu.isActive = 1, ModifyBy = NULL, ModifyDate = @Date
			FROM dbo.LicenseeUser lu WITH (ROWLOCK, UPDLOCK)
			INNER JOIN #AssignedLicensee a ON lu.LicenseeID = a.Id
			WHERE lu.UserID = @UserId AND a.IsAssigned = 1 AND a.IsActiveUser = 0
			
			-- Add new licensee user
			INSERT INTO dbo.LicenseeUser (LicenseeId, UserID, isActive, ModifyDate)
			SELECT Id, @UserId, 1, @Date
			FROM #AssignedLicensee
			WHERE IsAssigned = 0 OR IsAssigned IS NULL
			
			-- Add function for licensee user
			IF (@AssignOption = 1)
			BEGIN
				WITH LicenseeFunction_CTE AS (
					SELECT lf.FunctionId, lf.LicenseeId
					FROM #AssignedLicensee l
					INNER JOIN dbo.LicenseeFunctions lf WITH (NOLOCK) ON l.Id = lf.LicenseeId
					GROUP BY lf.FunctionId, lf.LicenseeId
				)
				INSERT INTO dbo.LicenseeUserFunctions (FunctionId, LicenseeId, UserId)
				SELECT f.FunctionId, cte.LicenseeId, @UserId
				FROM LicenseeFunction_CTE cte
				INNER JOIN dbo.Functions f WITH (NOLOCK) ON cte.FunctionId = f.FunctionId
				WHERE f.IsActive = 1
					AND f.FunctionId NOT IN (6, 74)
					AND f.ParentId NOT IN (6, 74)
					AND NOT EXISTS (
						SELECT 1 
						FROM dbo.LicenseeUserFunctions luf WITH (NOLOCK) 
						WHERE luf.LicenseeId = cte.LicenseeId AND luf.UserId = @UserId AND luf.FunctionId = f.FunctionId)
			END
			ELSE IF (@AssignOption = 2)
			BEGIN
				WITH LicenseeFunction_CTE AS (
					SELECT lf.FunctionId, lf.LicenseeId
					FROM #AssignedLicensee l
					INNER JOIN dbo.LicenseeFunctions lf WITH (NOLOCK) ON l.Id = lf.LicenseeId
					GROUP BY lf.FunctionId, lf.LicenseeId
				)
				INSERT INTO dbo.LicenseeUserFunctions (FunctionId, LicenseeId, UserId)
				SELECT f.FunctionId, cte.LicenseeId, @UserId
				FROM LicenseeFunction_CTE cte
				INNER JOIN dbo.Functions f WITH (NOLOCK) ON cte.FunctionId = f.FunctionId
				WHERE f.IsActive = 1
					AND NOT EXISTS (
						SELECT 1 
						FROM dbo.LicenseeUserFunctions luf WITH (NOLOCK) 
						WHERE luf.LicenseeId = cte.LicenseeId AND luf.UserId = @UserId AND luf.FunctionId = f.FunctionId)
			END
			
			IF @AssignOption <> 0
			BEGIN
				CREATE TABLE #AssignedLicenseeCurrency (LicenseeId INT, CurrencyId INT)
				
				INSERT INTO #AssignedLicenseeCurrency(LicenseeId, CurrencyId)
				SELECT lc.LicenseeID, lc.Currency 
				FROM dbo.LicenseeCust lc WITH (NOLOCK)
				INNER JOIN #AssignedLicensee l ON lc.LicenseeID = l.Id
				LEFT JOIN dbo.Lrf_f_LicenseeCurrencyLimit_Main() cl ON lc.LicenseeID = cl.LicenseeID AND lc.Currency = cl.CurrencyID
				WHERE lc.RoleID = 2 AND cl.LicenseeID IS NULL
				GROUP BY lc.LicenseeID, lc.Currency
				
				UPDATE cu
				SET cu.isActive = 1
				FROM dbo.CurrencyUser cu WITH (ROWLOCK, UPDLOCK)
				INNER JOIN #AssignedLicenseeCurrency a ON cu.LicenseeID = a.LicenseeId AND cu.CurrencyID = a.CurrencyId
				WHERE cu.usrID = @UserId AND cu.isActive = 0 AND cu.SystemID = @SystemId
				
				INSERT INTO dbo.CurrencyUser(usrID, LicenseeID, CurrencyID, SystemID, isActive)
				SELECT @UserId, a.LicenseeId, a.CurrencyId, @SystemId, 1
				FROM #AssignedLicenseeCurrency a
				WHERE NOT EXISTS (
						SELECT 1
						FROM dbo.CurrencyUser cu WITH (NOLOCK)
						WHERE cu.usrID = @UserId AND cu.LicenseeID = a.LicenseeId AND cu.CurrencyID = a.CurrencyId AND cu.SystemID = @SystemId
				)
				
				DROP TABLE #AssignedLicenseeCurrency
			END
			
			TRUNCATE TABLE #AssignedLicensee
		END
	END
		
	IF (ISNULL(@UnassignedLicensees,'') <> '')
	BEGIN
		INSERT INTO #AssignedLicensee(Name)
		SELECT DISTINCT val
		FROM CUSTDB.dbo.strSplit(@UnassignedLicensees,',')

		UPDATE a
		SET a.Id = l.LicenseeID
		FROM #AssignedLicensee a
		INNER JOIN dbo.Licensees l WITH (NOLOCK) ON a.Name = l.LicenseeName

		-- Remove function from licensee
		UPDATE l
		SET l.isActive = 0, ModifyBy = NULL, ModifyDate = @Date
		FROM dbo.LicenseeUser l WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #AssignedLicensee a ON l.LicenseeId = a.Id
		WHERE l.UserID = @UserId
		
		-- Remove function from licensee user
		IF (@RemoveOption = 1)
		BEGIN
			DELETE u
			FROM dbo.LicenseeUserFunctions u WITH (ROWLOCK)
			INNER JOIN #AssignedLicensee a ON u.LicenseeId = a.Id
			WHERE u.UserId = @UserId
			
			UPDATE cu
			SET cu.isActive = 0
			FROM dbo.CurrencyUser cu WITH (ROWLOCK, UPDLOCK)
			INNER JOIN #AssignedLicensee a ON cu.LicenseeID = a.Id
			WHERE cu.usrID = @UserId AND cu.SystemID = @SystemId AND cu.isActive = 1
		END
	END
	
	DROP TABLE #AssignedLicensee

	IF EXISTS (SELECT TOP(1) 1 FROM @Result)
	BEGIN
		SELECT 'The following licensees were not added for this user:' AS [Message], 1 AS IsOk 
		UNION ALL
		SELECT [Message], 1 AS IsOk
		FROM @Result
	END
	ELSE
	BEGIN
		SELECT [Message], 1 AS IsOk
		FROM @Result
	END

END
GO
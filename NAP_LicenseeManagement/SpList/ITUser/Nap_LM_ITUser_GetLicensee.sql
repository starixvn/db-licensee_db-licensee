/*<info serverAlias="DBCUST-bodb_licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Nap_LM_ITUser_GetLicensee]
	@UserId	INT = 0,
	@IsAssigned BIT = NULL,
	@SystemId INT = 1 -- LRF
AS
/*
	 Created: Amanda
	 Date: 2019-01-23
	 Task: Implement "IT User Management" function
	 DB: DBCUST.bodb_licensee
	 
	 Revisions:
	  - 20190123@Amanda: Get Licensee to assign/unassign for IT user [Redmine: #83584]
	  
	 Developer's Note:
	  - @IsAssigned: 0 - get licensees that user is not assigned
					 1 - get licensees that user is assigned
					 NULL - all
*/
BEGIN
	SET NOCOUNT ON;

	IF @UserId = 0
	BEGIN
		SELECT l.LicenseeID AS Id, l.LicenseeName AS Name, CAST(0 AS BIT) AS Checked, CAST(1 AS BIT) AS isValid
		FROM dbo.Licensees l WITH (NOLOCK)
		INNER JOIN SystemLicensee sl WITH (NOLOCK) ON l.LicenseeID = sl.LicenseeID
		INNER JOIN LicenseeReseller lr WITH (NOLOCK) ON l.LicenseeID = lr.LicenseeID
		INNER JOIN Resellers r WITH (NOLOCK) ON r.ResellerID = lr.ResellerID
		WHERE l.isActive = 1 AND sl.SystemID = @SystemId AND sl.isActive = 1 AND lr.ResellerID <> 3
		GROUP BY l.LicenseeID, l.LicenseeName
		ORDER BY l.LicenseeName
		
		RETURN
	END

	IF (@IsAssigned IS NULL)
	BEGIN
		;WITH LRF_Licencee AS (
			SELECT sl.LicenseeID
			FROM SystemLicensee sl WITH (NOLOCK)
			INNER JOIN LicenseeReseller lr WITH (NOLOCK) ON sl.LicenseeID = lr.LicenseeID
			INNER JOIN Resellers r WITH (NOLOCK) ON r.ResellerID = lr.ResellerID
			WHERE sl.SystemID = @SystemId AND sl.isActive = 1 AND lr.ResellerID <> 3
			GROUP BY sl.LicenseeID
		)
		SELECT l.LicenseeID AS Id,
			l.LicenseeName AS Name,
			CASE WHEN lu.LicenseeId IS NULL THEN CAST(0 AS BIT) ELSE lu.isActive END AS Checked,
			CASE WHEN ll.LicenseeID IS NOT NULL AND l.IsActive = 1 THEN 1 ELSE 0 END AS IsValid
		FROM dbo.Licensees l WITH (NOLOCK)
		LEFT JOIN dbo.LicenseeUser lu WITH (NOLOCK) ON lu.LicenseeId = l.LicenseeID AND lu.UserID = @UserId
		LEFT JOIN LRF_Licencee ll WITH (NOLOCK) ON l.LicenseeID = ll.LicenseeID
		WHERE (lu.LicenseeID IS NOT NULL AND lu.isActive = 1) OR (ll.LicenseeID IS NOT NULL AND l.IsActive = 1)
		ORDER BY l.LicenseeName
		
		RETURN
	END
	
	IF (@IsAssigned = 1)
	BEGIN
		;WITH LRF_Licencee AS (
			SELECT sl.LicenseeID
			FROM SystemLicensee sl WITH (NOLOCK)
			INNER JOIN LicenseeReseller lr WITH (NOLOCK) ON sl.LicenseeID = lr.LicenseeID
			INNER JOIN Resellers r WITH (NOLOCK) ON r.ResellerID = lr.ResellerID
			WHERE sl.SystemID = @SystemId AND sl.isActive = 1 AND lr.ResellerID <> 3
			GROUP BY sl.LicenseeID
		)
		SELECT	l.LicenseeID AS Id,
				l.LicenseeName AS Name,
				lu.isActive AS Checked,
				CASE WHEN ll.LicenseeID IS NOT NULL AND l.IsActive = 1 THEN 1 ELSE 0 END AS IsValid
		FROM dbo.Licensees l WITH (NOLOCK)
		INNER JOIN dbo.LicenseeUser lu WITH (NOLOCK) ON lu.LicenseeId = l.LicenseeID
		LEFT JOIN LRF_Licencee ll WITH (NOLOCK) ON l.LicenseeID = ll.LicenseeID
		WHERE lu.UserID = @UserId
		ORDER BY l.LicenseeName
		
		RETURN
	END	
	
	SELECT l.LicenseeID AS Id, l.LicenseeName AS Name, CAST(0 AS BIT) AS Checked, CAST(1 AS BIT) AS isValid
	FROM dbo.Licensees l WITH (NOLOCK)
	INNER JOIN dbo.LicenseeUser lu WITH (NOLOCK) ON lu.LicenseeId = l.LicenseeID
	INNER JOIN SystemLicensee sl WITH (NOLOCK) ON l.LicenseeID = sl.LicenseeID
	INNER JOIN LicenseeReseller lr WITH (NOLOCK) ON l.LicenseeID = lr.LicenseeID
	INNER JOIN Resellers r WITH (NOLOCK) ON r.ResellerID = lr.ResellerID
	WHERE l.IsActive = 1 AND lu.UserID = @UserId AND sl.SystemID = @SystemId AND sl.isActive = 1 AND lr.ResellerID <> 3
		AND NOT EXISTS (
			SELECT 1
			FROM dbo.LicenseeUser lu WITH (NOLOCK)
			WHERE lu.UserID = @UserId AND lu.LicenseeID = l.LicenseeID
		)
	GROUP BY l.LicenseeID, l.LicenseeName
	ORDER BY l.LicenseeName
END
GO
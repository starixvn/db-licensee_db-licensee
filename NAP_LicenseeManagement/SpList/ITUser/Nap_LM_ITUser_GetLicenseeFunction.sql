/*<info serverAlias="DBCUST-bodb_licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Nap_LM_ITUser_GetLicenseeFunction]
	@UserId	VARCHAR(50),
	@FunctionId INT = 0,
	@LicenseeId INT = 0,
	@SystemId INT = 1 -- LRF
AS
/*
	 Created: Amanda
	 Date: 2019-01-25
	 Task: Implement "IT User Management" function
	 DB: DBCUST.bodb_licensee
	 
	 Revisions:
	  - 20190125@Amanda: Get licensees & functions of user [Redmine: #83584]
*/
BEGIN
	SET NOCOUNT ON;

	;WITH LRF_Licencee AS (
			SELECT sl.LicenseeID
			FROM SystemLicensee sl WITH (NOLOCK)
			INNER JOIN LicenseeReseller lr WITH (NOLOCK) ON sl.LicenseeID = lr.LicenseeID
			INNER JOIN Resellers r WITH (NOLOCK) ON r.ResellerID = lr.ResellerID
			WHERE sl.SystemID = @SystemId AND sl.isActive = 1 AND lr.ResellerID <> 3 AND (@LicenseeId = 0 OR sl.LicenseeID = @LicenseeId)
			GROUP BY sl.LicenseeID
	)
	SELECT	l.LicenseeID AS Id,
			l.LicenseeName AS Name,
			lu.isActive AS Checked,
			CASE WHEN ll.LicenseeID IS NOT NULL AND l.IsActive = 1 THEN 1 ELSE 0 END AS IsValid
	FROM dbo.Licensees l WITH (NOLOCK)
	INNER JOIN dbo.LicenseeUser lu WITH (NOLOCK) ON lu.LicenseeId = l.LicenseeID
	LEFT JOIN LRF_Licencee ll WITH (NOLOCK) ON l.LicenseeID = ll.LicenseeID
	WHERE lu.UserID = @UserId AND (@LicenseeId = 0 OR l.LicenseeID = @LicenseeId)
	ORDER BY l.LicenseeName
	
	;WITH CTE_LicenseeFunc AS (
		SELECT DISTINCT l.LicenseeID, l.LicenseeName, lf.FunctionId
		FROM dbo.Licensees l WITH (NOLOCK)
		INNER JOIN dbo.LicenseeFunctions lf WITH (NOLOCK) ON l.LicenseeID = lf.LicenseeId
		WHERE (@LicenseeId = 0 OR l.LicenseeID = @LicenseeId)
			AND (@FunctionId = 0 OR lf.FunctionId = @FunctionId) 
	)
	SELECT lu.LicenseeID, 
			f.FunctionId,
			f.Name AS FunctionName,
			luf.UserFuncionId AS UserFunctionId,
			pf.FunctionId AS ParentId,
			cte.LicenseeName,
			f.IsActive
	FROM dbo.LicenseeUser lu WITH (NOLOCK)
	INNER JOIN CTE_LicenseeFunc cte WITH (NOLOCK) ON lu.LicenseeID = cte.LicenseeID
	INNER JOIN dbo.Functions f WITH (NOLOCK) ON cte.FunctionId = f.FunctionId
	LEFT JOIN dbo.Functions pf WITH (NOLOCK) ON f.ParentId = pf.FunctionId
	LEFT JOIN dbo.LicenseeUserFunctions luf WITH (NOLOCK) ON luf.LicenseeId = lu.LicenseeId AND luf.UserId = lu.UserID AND luf.FunctionId = cte.FunctionId
	WHERE lu.UserID = @UserId
END
GO
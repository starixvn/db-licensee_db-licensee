/*<info serverAlias="DBCUST-bodb_licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Nap_LM_ITUser_GetLicenseeCurrency]
	@UserId	INT,
	@CurrencyId INT = 0,
	@LicenseeId INT = 0,
	@SystemId INT = 1
AS
/*
	 Created: Amanda
	 Date: 2019-01-29
	 Task: Implement "IT User Management" function
	 DB: DBCUST.bodb_licensee
	 
	 Revisions:
	  - 20190129@Amanda: Get licensees & functions of user [Redmine: #83584]
	  
	 Developer's Note
	  - @System: 1 - LRF
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
	
	;WITH LicenseeCurrency_CTE AS (
		SELECT DISTINCT lc.LicenseeID, lc.Currency
		FROM dbo.LicenseeUser lu WITH (NOLOCK) 
		INNER JOIN dbo.LicenseeCust lc WITH (NOLOCK) ON lu.LicenseeId = lc.LicenseeID
		LEFT JOIN dbo.Lrf_f_LicenseeCurrencyLimit_Main() cl ON lc.LicenseeID = cl.LicenseeID AND lc.Currency = cl.CurrencyID
		WHERE lu.UserID = @UserId
			AND (@LicenseeId = 0 OR lu.LicenseeID = @LicenseeId)
			AND (@CurrencyId = 0 OR lc.Currency = @CurrencyId)
			AND lc.RoleID = 2
			AND cl.LicenseeID IS NULL
	)
	SELECT l.LicenseeID, 
			e.exchangeid AS CurrencyId,
			e.currency AS CurrencyName,
			CASE WHEN cu.usrID IS NOT NULL THEN 1 ELSE 0 END AS IsAssigned,
			l.LicenseeName
	FROM LicenseeCurrency_CTE cte
	INNER JOIN dbo.Licensees l WITH (NOLOCK) ON cte.LicenseeID = l.LicenseeID
	INNER JOIN CustDB.dbo.exchange e WITH (NOLOCK) ON cte.Currency = e.exchangeid
	LEFT JOIN dbo.CurrencyUser cu WITH (NOLOCK) ON cte.LicenseeID = cu.LicenseeId
												AND cu.usrID = @UserId
												AND cu.CurrencyID = cte.Currency
												AND cu.SystemID = @SystemId
												AND cu.isActive = 1
END
GO
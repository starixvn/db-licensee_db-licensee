/*<info serverAlias="DBCUST-bodb_licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Nap_LM_Licensee_GetByName]
	@LicenseeName	VARCHAR(50)	= ''
AS
/*
	 Created: Amanda
	 Date: 2019-01-10
	 Task: Implement "Licensee Setting" function
	 DB: DBCUST.bodb_licensee
	 
	 Revisions:
	  - 20190110@Amanda: Select Licensee by name [Redmine: #83584]
*/
BEGIN
	SET NOCOUNT ON;
	DECLARE @Reseller VARCHAR(1000), @LicenseeId INT
	
	SELECT @LicenseeId = LicenseeId
	FROM dbo.Licensees l WITH(NOLOCK)
	WHERE l.LicenseeName = @LicenseeName
	
	SELECT @Reseller = STUFF((
		SELECT ', ' + r.ResellerName
		FROM dbo.LicenseeReseller lr WITH (NOLOCK)
		INNER JOIN dbo.Resellers r WITH (NOLOCK) ON lr.ResellerID = r.ResellerID
		WHERE lr.LicenseeID = @LicenseeId
		FOR XML PATH('')), 1, 1, '')

	SELECT 	l.LicenseeID,
			l.LicenseeName,
			l.[Description],
			l.IsDeposit,
			l.AffectedDate,
			l.IsActive,
			l.IsKPIActive,
			l.IsOneWorkActive,
			l.BrandName,
			l.CompanyName,
			l.IsAllowedMemberComm,
			l.EditBetSetting,
			@Reseller AS Reseller
	FROM dbo.Licensees l WITH(NOLOCK)
	WHERE l.LicenseeId = @LicenseeId
	
	
END
GO
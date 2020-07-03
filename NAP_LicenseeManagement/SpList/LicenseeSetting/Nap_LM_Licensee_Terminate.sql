/*<info serverAlias="DBCUST-bodb_licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Nap_LM_Licensee_Terminate]
	@LicenseeName VARCHAR(50)
AS
/*
	 Created: Amanda
	 Date: 2018-11-21
	 Task: Implement "Licensee Setting" function
	 DB: DBCUST.bodb_licensee
	 
	 Revisions:
	  - 20181121@Amanda: Terminate Licensee [Redmine: #83584]
	  - 20181219@Amanda: Validate System data before deactivate [Redmine: #83584]
	  - 20190418@Amanda: Use LM's SP instead of DBA [Redmine: #111321]
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @LicenseeId INT
	
	SELECT @LicenseeId = LicenseeID
	FROM dbo.Licensees WITH (NOLOCK)
	WHERE LicenseeName = @LicenseeName

	IF ISNULL(@LicenseeId, 0) = 0
	BEGIN
		SELECT 'Invalid licensee name!'
		RETURN
	END
	
	IF EXISTS (SELECT 1 FROM dbo.Licensees WITH (NOLOCK) WHERE LicenseeID = @LicenseeId AND isActive = 0 )
		AND NOT EXISTS (SELECT 1 FROM dbo.SystemLicensee WITH (NOLOCK) WHERE LicenseeID = @LicenseeId AND IsActive = 1)
	BEGIN
		SELECT 'This licensee has been terminated by someone!'
		RETURN
	END
	
	UPDATE dbo.Licensees WITH (ROWLOCK, UPDLOCK)
	SET IsActive = 0
	WHERE LicenseeID = @LicenseeId

	DECLARE @SystemNames VARCHAR(100)

	SELECT @SystemNames = STUFF((
							SELECT ',' + s.SystemName
							FROM dbo.SystemLicensee sl WITH (NOLOCK)
							INNER JOIN dbo.Systems s WITH (NOLOCK) ON sl.SystemID = s.id
							WHERE sl.LicenseeID = @LicenseeId AND sl.IsActive = 1
						FOR XML PATH('')), 1, 1, '')  

	IF ISNULL(@SystemNames,'') <> ''
	BEGIN
		EXEC [dbo].[Nap_LM_Licensee_DeactivateSystem] @LicenseeName = @LicenseeName, @SystemName = @SystemNames
	END
END
GO
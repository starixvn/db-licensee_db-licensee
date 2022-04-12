/*<info serverAlias="DBCUST-bodb_licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[NAP_LM_Licensee_Reactivate]
	@LicenseeName VARCHAR(50)
AS

/*
	Created: 20220412@Kos
	Task: Reactivate a licensee
	DB: DBCUST.bodb_Licensee

	Revisions:
		- 20220412@Kos: Created [Redmine: #171356]
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

	IF NOT EXISTS (SELECT 1 FROM dbo.Licensees WITH (NOLOCK) WHERE LicenseeID = @LicenseeId AND IsActive = 0)
	BEGIN
		SELECT 'This licensee has been reactivated by someone!'
		RETURN
	END
	
	UPDATE dbo.Licensees WITH (ROWLOCK, UPDLOCK)
	SET IsActive = 1
	WHERE LicenseeID = @LicenseeId AND IsActive = 0

	UPDATE dbo.SystemLicensee WITH (ROWLOCK, UPDLOCK)
	SET IsActive = 1
	WHERE SystemID IN (1, 2, 3) AND LicenseeID = @LicenseeId
END
GO
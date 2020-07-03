/*<info serverAlias="DBCUST-bodb_licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Nap_LM_Licensee_GetActiveSystem]
	@LicenseeId INT
AS
/*
	 Created: Amanda
	 Date: 2019-01-15
	 Task: Implement "Licensee Setting" function
	 DB: DBCUST.bodb_licensee
	 
	 Revisions:
	  - 20190115@Amanda: Select Active Licensee System [Redmine: #83584]
*/
BEGIN
	SET NOCOUNT ON;
	
	SELECT s.id AS Id, s.SystemName, s.[Description]
	FROM dbo.Systems s WITH (NOLOCK)
	INNER JOIN dbo.SystemLicensee sl WITH (NOLOCK) ON s.id = sl.SystemID
	WHERE sl.LicenseeID = @LicenseeId AND sl.IsActive = 1
END
GO
/*<info serverAlias="DBCUST-bodb_licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Nap_LM_LicenseeList_Select]
	@isAll	INT = 0
AS
/*
	 Created: Amanda
	 Date: 2018-12-24
	 Task: Implement "Licensee Setting" function
	 DB: DBCUST.bodb_licensee
	 
	 Revisions:
	  - 20181224@Amanda: Select Licensee List [Redmine: #83584]
	  
	  Developer's Note:
	  - @isAll	= 1 - get all
				= 0 - exclude inactive licensee
*/
BEGIN
	SET NOCOUNT ON;
	
	SELECT l.LicenseeID AS Id, l.LicenseeName AS Name
	FROM dbo.Licensees l WITH(NOLOCK)
	WHERE @isAll = 1 OR l.IsActive = 1
	ORDER BY L.LicenseeName

END
GO
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Task_PTCS_SelLicenseeList]') AND type in (N'P', N'PC'))
	DROP PROCEDURE [dbo].Task_PTCS_SelLicenseeList
GO


CREATE PROCEDURE Task_PTCS_SelLicenseeList
AS 
/*
Created: 20140408@Victor
Task : [Task_PTCS_SelLicenseeList]
DB: DBPTCS.bodb_PlaytechCS
Original:

Revisions:

Param explanation:

*/

SET NOCOUNT ON

SELECT LicenseeName, VersionKey FROM bodb_PlaytechCS.dbo.LicenseeVersionKey WITH(NOLOCK)

GO

GRANT  EXECUTE  ON [dbo].Task_PTCS_SelLicenseeList  TO [bodbLicenseeNet]
GO
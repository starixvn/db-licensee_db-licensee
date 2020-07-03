/*<info serverAlias="DBCUST-bodb_licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Nap_LM_ITUser_Get]
	@UserId INT,
	@SystemId INT = 1 -- LRF
AS
/*
	 Created: Amanda
	 Date: 2019-02-13
	 Task: Implement "IT User Management" function
	 DB: DBCUST.bodb_licensee
	 
	 Revisions:
	  - 20190213@Amanda: Check valid User [Redmine: #83584]
*/
BEGIN
	SET NOCOUNT ON;

	SELECT	UserID, 
			Username, 
			UserRole, 
			FirstName, 
			LastName, 
			Email, 
			[Status], 
			CreateDate, 
			LicenseeName, 
			isInternal,
			CASE WHEN UserRole = 'Admin' THEN 1 ELSE 0 END AS IsAdmin,
			CASE WHEN [Status] = 'Open' THEN 1 ELSE 0 END AS IsActive
	FROM dbo.Users WITH (NOLOCK)
	WHERE UserID = @UserId AND isInternal = 0
END
GO
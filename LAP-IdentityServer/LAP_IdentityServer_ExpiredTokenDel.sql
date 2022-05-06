/*<info serverAlias="DBCUST-bodb_Licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[LAP_IdentityServer_ExpiredTokenDel]
	@BatchSize INT = 100
AS
/*
	Created by: [20220413@Howard]
	Task: LAP - Store tokens on SQL Server
	DB: DBCUST-bodb_Licensee
	RedmineID: #171304 - LAP - Enhancement
	Param's Explanation:
		
	Revisions: 
		- 20220413@Howard: Init SP (#171304)
	Example:

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @Deleted_Rows INT = 1;
	WHILE (@Deleted_Rows > 0)
	BEGIN
	      DELETE TOP (@BatchSize)
		  FROM dbo.LAP_IdentityServer_Token WITH(ROWLOCK, UPDLOCK)
		  WHERE Expiration IS NOT NULL AND Expiration < GETUTCDATE()
		  SET @Deleted_Rows = @@ROWCOUNT;
	END
END


/*<info serverAlias="DBCUST-bodb_Licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[LAP_IdentityServer_TokenDel]
	@Key NVARCHAR(200)			= ''
	,@SubjectId NVARCHAR(100)	= ''
	,@SessionId NVARCHAR(100)	= ''
	,@ClientId NVARCHAR(200)	= ''
	,@Type NVARCHAR(50)			= ''
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

	IF(ISNULL(@Key, '') <> '')
	BEGIN
		DELETE 
		FROM dbo. LAP_IdentityServer_Token WITH(ROWLOCK, UPDLOCK)
		WHERE [Key] = @Key

		RETURN;
	END

	IF(ISNULL(@SubjectId, '') <> '' OR ISNULL(@SessionId, '') <> '' OR ISNULL(@ClientId, '') <> '' OR ISNULL(@Type, '') <> '')
	BEGIN
		DELETE 
		FROM dbo.LAP_IdentityServer_Token WITH(ROWLOCK, UPDLOCK)
		WHERE (ISNULL(@SubjectId, '') = '' OR SubjectId = @SubjectId)
		AND (ISNULL(@SessionId, '') = '' OR SessionId = @SessionId)
		AND (ISNULL(@ClientId, '') = '' OR ClientId = @ClientId)
		AND (ISNULL(@Type, '') = '' OR [Type] = @Type)
		
		RETURN;
	END
END


/*<info serverAlias="DBCUST-bodb_Licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[LAP_IdentityServer_TokenInsOrUpd]
	@Key NVARCHAR(200)
	,@Type NVARCHAR(50)
	,@ClientId NVARCHAR(200)
	,@CreationTime DATETIME
	,@Data NVARCHAR(MAX)
	,@SubjectId NVARCHAR(200)	= NULL
	,@SessionId NVARCHAR(100)	= NULL
	,@Description NVARCHAR(200) = NULL
	,@Expiration DATETIME		= NULL
	,@ConsumedTime DATETIME		= NULL
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

	IF EXISTS (SELECT TOP 1 1 FROM dbo.LAP_IdentityServer_Token WITH(NOLOCK) WHERE [Key] = @Key)
		BEGIN
			UPDATE dbo.LAP_IdentityServer_Token WITH(ROWLOCK)
			SET [Type]	= @Type
				,SubjectId		= @SubjectId
				,SessionId		= @SessionId
				,ClientId		= @ClientId
				,[Description]	= @Description
				,CreationTime	= @CreationTime
				,Expiration		= @Expiration
				,ConsumedTime	= @ConsumedTime
				,[Data]			= @Data
			WHERE [Key] = @Key
		END
	ELSE 
		BEGIN
			INSERT INTO dbo.LAP_IdentityServer_Token (
				[Key]
				,[Type]
				,SubjectId
				,SessionId
				,ClientId
				,[Description]
				,CreationTime
				,Expiration
				,ConsumedTime
				,[Data]
			)
			VALUES(
				@Key
				,@Type
				,@SubjectId
				,@SessionId
				,@ClientId
				,@Description
				,@CreationTime
				,@Expiration
				,@ConsumedTime
				,@Data
			)
		END

END


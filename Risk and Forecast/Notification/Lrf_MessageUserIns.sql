/*<info serverAlias="DBCUST-SiteConfig" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE Lrf_MessageUserIns
	@MessageId		INT
	,@UserName		VARCHAR(20)
	,@LicenseeName  VARCHAR(50)
	,@Source		TINYINT = 0
AS
/*	
	Created by: Kai
	Task : Mark as read notification (#174308)
	DB: DBCUST/SiteConfig
	Revisions:
		- 20221202@Kai: Initial sp [RedmineID: #174308]
		- 20240715@Kai: Add Source param due to mark as read from CRM [RedmineID: #199443]
*/
BEGIN

	SET NOCOUNT ON
 
	IF NOT EXISTS (
		SELECT 1
		FROM [MessageUser] WITH(NOLOCK)
		WHERE MessageID = @MessageId
			AND UserName = @UserName
			AND LicenseeName = @LicenseeName
			AND [Source] = @Source
	)
	BEGIN
		INSERT INTO [MessageUser] (
			MessageID
			,UserName
			,LicenseeName
			,IsRead
			,UpdatedDate
			,[Source]
		)
		VALUES (
			@MessageID
			,@UserName
			,@LicenseeName
			,1
			,CURRENT_TIMESTAMP
			,@Source
		)
	END
	
END
GO
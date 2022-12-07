/*<info serverAlias="DBCUST-SiteConfig" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE Lrf_MessageUserIns
	@MessageId		INT
	,@UserName		VARCHAR(20)
	,@LicenseeName  VARCHAR(50)
AS
/*	
	Created by: Kai
	Task : Mark as read notification (#174308)
	DB: DBCUST/SiteConfig
	Revisions:
		- 20221202@Kai: Initial sp [RedmineID: #174308]
*/
BEGIN

	SET NOCOUNT ON
 
	IF NOT EXISTS (
		SELECT 1
		FROM [MessageUser] WITH(NOLOCK)
		WHERE MessageID = @MessageId
			AND UserName = @UserName
			AND LicenseeName = @LicenseeName
	)
	BEGIN
		INSERT INTO [MessageUser] (
			MessageID
			,UserName
			,LicenseeName
			,IsRead
			,UpdatedDate
		)
		VALUES (
			@MessageID
			,@UserName
			,@LicenseeName
			,1
			,CURRENT_TIMESTAMP
		)
	END
	
END
GO
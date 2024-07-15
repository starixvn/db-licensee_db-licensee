/*<info serverAlias="DBCUST-SiteConfig" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE Lrf_MessageUserSel
	@FromDate		DATETIME
	,@ToDate		DATETIME
	,@UserName		VARCHAR(20)
	,@LicenseeName  VARCHAR(50)
	,@Source		TINYINT
AS
/*	
	Created by: Kai
	Task : Get MessageId read notification (#199443)
	DB: DBCUST/SiteConfig
	Revisions:
		- 20240715@Kai: Initial sp [RedmineID: #199443]
*/
BEGIN

	SET NOCOUNT ON
 
	SELECT mu.MessageID
	FROM [dbo].[MessageUser] mu WITH(NOLOCK)
	WHERE (mu.UpdatedDate BETWEEN @FromDate AND @ToDate)
		AND mu.[Source] = @Source
		AND mu.LicenseeName = @LicenseeName
		AND mu.UserName = @UserName
		AND mu.IsRead = 1
END
GO
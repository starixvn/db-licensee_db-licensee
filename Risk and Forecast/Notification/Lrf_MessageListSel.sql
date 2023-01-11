/*<info serverAlias="DBCUST-SiteConfig" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE Lrf_MessageListSel
	@UserName		VARCHAR(20)
	,@LicenseeName	VARCHAR(50)
	,@MessageTypes	VARCHAR(50)
	,@FromDate		DATETIME
	,@ToDate		DATETIME
AS
/*	
	Created by: Kai
	Task : Get notification by MessageTypes (#174308)
	DB: DBCUST/SiteConfig
	Revisions:
		- 20221207@Kai: Initial sp [RedmineID: #174308]

	Param's Explanation:
		@MessageTypes: "1,2,3,..." - 1: Abnormal Bet 
*/
BEGIN
	SET NOCOUNT ON

	SELECT	m.MessageID
			,m.MessageType
			,m.SubjectEn
			,m.SubjectCs
			,m.ContentEn
			,m.ContentCs
			,m.EventDate
	FROM [Message] m WITH(NOLOCK)
		INNER JOIN [MessageLicensee] ml WITH(NOLOCK)
			ON m.MessageID = ml.MessageID
		LEFT JOIN [MessageUser] mu WITH(NOLOCK)
			ON m.MessageID = mu.MessageID
				AND mu.UserName = @UserName
				AND mu.LicenseeName = @LicenseeName
	WHERE ml.LicenseeName = @LicenseeName
		AND m.MessageType IN (SELECT value FROM STRING_SPLIT(@MessageTypes, ','))
		AND (m.EventDate BETWEEN @FromDate AND @ToDate)
		AND (mu.IsRead IS NULL OR mu.IsRead = 0)

END
GO
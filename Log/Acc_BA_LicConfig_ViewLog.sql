/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_BA_LicConfig_ViewLog]
	@LicenseeID		INT = NULL
AS
/*
	Created: Henry
	Date: 20110613
	Task : View BA Commission Log
	DB: DBLOG/bodb_CustomerLog
	Original:

	Revisions:
		- 20110824@Johnson: get more column commission by group for hdp, odd/even , over/under bettype.
		- 20111118@Jim : remove ugroup variable
		- 20180924@Elodie: Migrate bodb_Licensee to DBCUST [Redmine:#99855]

	Param's Explanation:
		@LicenseeID: null means get all licensee
*/
BEGIN
	SET NOCOUNT ON
	SELECT 
		A.LicenseeID,
		B.LicenseeName,
		A.groupa,
		A.groupb,
		A.groupc,
		A.groupd,
		A.[1x2Comm],
		A.OtherComm,		
		A.EnableBA,
		A.IP,
		C.username AS ModifyBy,
		LA.ActionNameEN AS [description],
		A.ModifyDate
	FROM 
		dbo.UserLog_LicenseeBAConfig A WITH (NOLOCK)
	INNER JOIN bodb_licensee.dbo.Licensees B WITH (NOLOCK) ON A.LicenseeID = B.LicenseeID
	INNER JOIN bodb02.dbo.Custinfo C WITH (NOLOCK) ON A.ModifyBy = C.CustID
	INNER JOIN dbo.LogAction LA  WITH (NOLOCK) ON A.ActionID = LA.ActionID
	WHERE 
		A.LicenseeID = COALESCE(@LicenseeID,A.LicenseeID)
	ORDER BY A.LicenseeID, A.ModifyDate DESC
			
END
GO

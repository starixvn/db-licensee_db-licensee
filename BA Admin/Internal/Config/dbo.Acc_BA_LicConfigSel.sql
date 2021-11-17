/*<info serverAlias="DBCUST-bodb_Licensee" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/ 

USE bodb_Licensee
GO
ALTER PROCEDURE [dbo].[Acc_BA_LicConfigSel]
AS
/*
	Created: Henry
	Date: 20110606
	Task : Get Licensee Commission Template for all Licensee
	DB: DBCUST/bodb_Licensee
	Original:

	Revisions:
		- 20110823@Johnson: get more column commission by group for hdp, odd/even , over/under bettype.
		- 20011120@Jim: remove ugroup column
		- 20180924@Elodie: Migrate bodb_Licensee to DBCUST [Redmine:#99855]

	Param's Explanation:
	
*/
BEGIN
	SET NOCOUNT ON
		
	SELECT 
		A.LicenseeName, 
		B.LicenseeID, 
		B.groupa,
		B.groupb,
		B.groupc,
		B.groupd,
		B.[1x2Comm], 
		B.OtherComm, 		 
		B.EnableBA, 
		CASE WHEN C.username IS NULL THEN 'Unknown' ELSE C.username END AS ModifyBy,
		B.ModifyDate
	FROM LicenseeBAConfig B WITH (NOLOCK) 
		INNER JOIN Licensees A WITH (NOLOCK) ON A.LicenseeID = B.LicenseeID
		LEFT JOIN CustDB.dbo.Custinfo c WITH (NOLOCK) ON B.ModifyBy = c.Custid
	ORDER BY A.LicenseeID 
		
END
GO

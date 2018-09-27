/*<info serverAlias="DBLic-bodb_Licensee" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_LicenseeCustCommSel]
	@LicenseeID INT,
	@CustID INT = 0
AS  
/*  
 * Created: 20120726@Henry
 * Task : Select List Member Commission
 * DB: DBLIC/bodb_Licensee  
 *  
 * Revisions:     
	-20160805@Jim: LRF - Offer different member commission for parlay tickets [RedmineID:#61897]
	- 20171020@Johnson: offer Allbet commision [Redmine: #82036]
	- 20180927@Winnie: Remove AllBet [RedmineID: #99378]
*/  
BEGIN  
	SET NOCOUNT ON;  

	IF @CustID=0 --get all
	BEGIN
		SELECT 
			lc.CustID,c.username,SUBSTRING(c.username2,  CHARINDEX('$',c.username2)+1, LEN(c.username2)-CHARINDEX('$',c.username2)) AS nickname,
			lc.SBComm,lc.ParlayComm,lc.RacingComm,lc.NGComm,ISNULL(lgc.GroupName,'') AS GroupName
		FROM dbo.LicenseeCustComm lc WITH (NOLOCK)	
			INNER JOIN dbo.LicenseeCustInfo c WITH (NOLOCK)	ON c.custid = lc.custid
			LEFT JOIN dbo.LicenseeGroupComm lgc WITH (NOLOCK) ON lc.GroupCommID = lgc.id
	END
	ELSE
	BEGIN
		SELECT 
			lc.CustID,c.username,SUBSTRING(c.username2,  CHARINDEX('$',c.username2)+1, LEN(c.username2)-CHARINDEX('$',c.username2)) AS nickname,
			lc.SBComm,lc.ParlayComm,lc.RacingComm,lc.NGComm,ISNULL(lgc.GroupName,'') AS GroupName
		FROM dbo.LicenseeCustComm lc WITH (NOLOCK)	
			INNER JOIN dbo.LicenseeCustInfo c WITH (NOLOCK)	ON c.custid = lc.custid
			LEFT JOIN dbo.LicenseeGroupComm lgc WITH (NOLOCK) ON lc.GroupCommID = lgc.id
		WHERE lc.CustID = @CustID
	END
END
GO
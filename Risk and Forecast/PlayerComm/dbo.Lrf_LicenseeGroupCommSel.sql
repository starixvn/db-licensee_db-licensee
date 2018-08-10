/*<info serverAlias="DBLIC-bodb_Licensee" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0"></info>*/ 
ALTER PROCEDURE [dbo].[Lrf_LicenseeGroupCommSel]
	@LicenseeID INT,
	@GroupName VARCHAR(100) = ''
AS  
/*  
 * Created: 20120726@Henry
 * Task : Select Group Commission
 * DB: DBLIC/bodb_Licensee  
 *  
 * Revisions:     
 - 20121227@Henry: Add column IsDefault
 - 20131023@Hannah: Offer Live Casino commission
 - 20131126@Hannah: offer RNG Casino commission
 - 20151106@Francis: Revise SP to enhance performance [Redmine: #47080]
 - 20160805@Jim: LRF - Offer different member commission for parlay tickets [RedmineID:#61897]		
 - 20171020@Johnson: offer Allbet commision [Redmine: #82036]
 - 20180228@Vicky: Remove LC from product list [Redmine: #85965]
 - 20180809@Amanda: Remove Racing [RedmineID: #99378]
*/  
BEGIN  
	SET NOCOUNT ON;  

	SELECT @GroupName = ltrim(rtrim(@GroupName))

	SELECT g.ID AS GroupCommID
		,g.GroupName
		,g.SBComm
		,g.NGComm
		,g.RNGComm
		,g.Parlaycomm
		,g.AllbetComm
		,g.color AS GroupColor
		,ISNULL(c.NumberOfCustomer,0) AS NumberOfCustomer
		,g.IsDefault  
	FROM dbo.LicenseeGroupComm g WITH (NOLOCK)   
		LEFT JOIN (	SELECT COUNT(1) AS NumberOfCustomer, GroupCommID
					FROM LicenseeCustComm (NOLOCK)
					WHERE LicenseeID = @LicenseeID
					GROUP BY GroupCommID) c ON g.id=c.GroupCommID  
	WHERE   
		IsActive = 1   
		AND (@GroupName='' OR (@GroupName<>'' AND GroupName LIKE '%' + @GroupName + '%'))  
		AND g.LicenseeID = @LicenseeID  
	OPTION (MAXDOP 4)  

END
GO
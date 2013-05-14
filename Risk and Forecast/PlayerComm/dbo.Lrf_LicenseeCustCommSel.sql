ALTER PROCEDURE [dbo].[Lrf_LicenseeCustCommSel]
	@LicenseeID INT,
	@CustID INT = 0
AS  
/*  
 * Created: 20120726@Henry
 * Task : Select List Member Commission
 * DB: DB052.bodb_Licensee  
 *  
 * Revisions:     
	
*/  
BEGIN  
SET NOCOUNT ON;  

IF @CustID=0 --get all
BEGIN
	SELECT 
		lc.CustID,c.username,SUBSTRING(c.username2,  CHARINDEX('$',c.username2)+1, LEN(c.username2)-CHARINDEX('$',c.username2)) AS nickname,
		lc.SBComm,lc.RacingComm,lc.NGComm,ISNULL(lgc.GroupName,'') AS GroupName
	FROM LicenseeCustComm lc WITH (NOLOCK)	
		INNER JOIN LicenseeCustInfo c WITH (NOLOCK)	ON c.custid = lc.custid
		LEFT JOIN LicenseeGroupComm lgc WITH (NOLOCK) ON lc.GroupCommID = lgc.id
END
ELSE
BEGIN
	SELECT 
		lc.CustID,c.username,SUBSTRING(c.username2,  CHARINDEX('$',c.username2)+1, LEN(c.username2)-CHARINDEX('$',c.username2)) AS nickname,
		lc.SBComm,lc.RacingComm,lc.NGComm,ISNULL(lgc.GroupName,'') AS GroupName
	FROM LicenseeCustComm lc WITH (NOLOCK)	
		INNER JOIN LicenseeCustInfo c WITH (NOLOCK)	ON c.custid = lc.custid
		LEFT JOIN LicenseeGroupComm lgc WITH (NOLOCK) ON lc.GroupCommID = lgc.id
	WHERE lc.CustID = @CustID
END


END
GO
GRANT EXECUTE ON [dbo].[Lrf_LicenseeCustCommSel] TO [bodbLicenseeNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_LicenseeCustCommSel] TO [vnteam]   
ALTER PROCEDURE [dbo].[Acc_LicenseeCustXMLIns]  
	@strXML NVARCHAR(MAX)
AS  
/*  Created: Henry  
	Date: 2012-02-22
    TASk : Insert data to LicenseeCust in Kahnawake server using XML
    DB: bodb_MoveBet
   
    Revisions:  
		
	Param's Explanation:  
*/  
BEGIN  
SET NOCOUNT ON  

DECLARE @intDocHandle INT

--Create an internal representation of the XML document.      
EXEC sp_xml_preparedocument @intDocHandle OUTPUT, @strXML  

--Delete before insert      
DELETE FROM LicenseeCust WITH (ROWLOCK,UPDLOCK)      

	
INSERT INTO [dbo].LicenseeCust
           (LicenseeID
           ,CustID
           ,RoleID
           ,Currency
           )
SELECT       
	LicenseeID
   ,CustID
   ,RoleID
   ,Currency
FROM OPENXML(@intDocHandle,'/root/licenseecust',2) 	
WITH
(
	licenseeid int,
	custid int,
	roleid int,
	currency int
)    	
	

END   

GO
GRANT EXECUTE ON [dbo].[Acc_LicenseeCustXMLIns] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_LicenseeCustXMLIns] TO [vnteam] 

    
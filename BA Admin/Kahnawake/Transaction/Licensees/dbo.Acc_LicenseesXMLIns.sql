ALTER PROCEDURE [dbo].[Acc_LicenseesXMLIns]  
	@strXML NVARCHAR(MAX)
	
AS  
/*  Created: Henry  
	Date: 2012-03-12
    TASk : Insert data to Licensees in Kahnawake server using XML
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
DELETE FROM Licensees WITH (ROWLOCK,UPDLOCK)      

	
INSERT INTO [dbo].Licensees
           (LicenseeID
           ,LicenseeName
           )
SELECT       
	LicenseeID
    ,LicenseeName
FROM OPENXML(@intDocHandle,'/root/licensees',2) 	
WITH
(
	licenseeid int,
	licenseename VARCHAR(50)
)    	

	

END   

GO
GRANT EXECUTE ON [dbo].[Acc_LicenseesXMLIns] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_LicenseesXMLIns] TO [vnteam] 

    
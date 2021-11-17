ALTER PROCEDURE [dbo].[Acc_LicenseeCurrencyBAGroupXMLIns]  
	@strXML NVARCHAR(MAX)
	
AS  
/*  Created: Henry  
	Date: 2012-03-02
    TASk : Insert data to LicenseeCurrencyBAGroup in Kahnawake server using XML
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
DELETE FROM LicenseeCurrencyBAGroup WITH (ROWLOCK,UPDLOCK)      

	

INSERT INTO [dbo].LicenseeCurrencyBAGroup
           (LicenseeID
           ,Currency
           ,ugroup
           )
SELECT       
	LicenseeID
   ,Currency
   ,ugroup
FROM OPENXML(@intDocHandle,'/root/licenseecurrencybagroup',2) 	
WITH
(
	licenseeid int,
	currency int,
	ugroup VARCHAR(3)
	
)           


	

END   

GO
GRANT EXECUTE ON [dbo].[Acc_LicenseeCurrencyBAGroupXMLIns] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_LicenseeCurrencyBAGroupXMLIns] TO [vnteam] 

      
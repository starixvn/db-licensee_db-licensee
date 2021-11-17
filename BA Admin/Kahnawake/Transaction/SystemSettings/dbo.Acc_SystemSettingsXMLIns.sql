ALTER PROCEDURE [dbo].[Acc_SystemSettingsXMLIns]  
	@strXML NVARCHAR(MAX)
	
AS  
/*  Created: Henry  
	Date: 2012-03-16
    TASk : Insert data to SystemSettings in Kahnawake server using XML
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
DELETE FROM SystemSettings WITH (ROWLOCK,UPDLOCK)      

	
INSERT INTO [dbo].SystemSettings
           (VName
           ,VValue
           )
SELECT       
	VName
    ,VValue
FROM OPENXML(@intDocHandle,'/root/systemsettings',2) 	
WITH
(
	vname VARCHAR(20),
	vvalue VARCHAR(50)
)    	

	

END   

GO
GRANT EXECUTE ON [dbo].[Acc_SystemSettingsXMLIns] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_SystemSettingsXMLIns] TO [vnteam] 

     
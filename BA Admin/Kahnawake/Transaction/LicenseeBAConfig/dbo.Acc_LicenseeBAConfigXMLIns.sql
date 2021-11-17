ALTER PROCEDURE [dbo].[Acc_LicenseeBAConfigXMLIns]  
	@strXML NVARCHAR(MAX)
	
AS  
/*  Created: Henry  
	Date: 2012-03-02
    TASk : Insert data to LicenseeBAConfig in Kahnawake server using XML
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
DELETE FROM LicenseeBAConfig WITH (ROWLOCK,UPDLOCK)    
  

INSERT INTO [dbo].LicenseeBAConfig
           (LicenseeID
           ,[1x2Comm]
           ,OtherComm
           ,groupa
           ,groupb 
           ,groupc 
           ,groupd
           )
SELECT       
	LicenseeID
   ,c1x2comm
   ,OtherComm
   ,groupa
   ,groupb 
   ,groupc 
   ,groupd
FROM OPENXML(@intDocHandle,'/root/licenseebaconfig',2) 	
WITH
(
	licenseeid int,
	c1x2comm DECIMAL(9,8),
	othercomm DECIMAL(9,8),
	groupa DECIMAL(9,8),
	groupb DECIMAL(9,8),
	groupc DECIMAL(9,8),
	groupd DECIMAL(9,8)
	
)           

	

END   

GO
GRANT EXECUTE ON [dbo].[Acc_LicenseeBAConfigXMLIns] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_LicenseeBAConfigXMLIns] TO [vnteam] 

     
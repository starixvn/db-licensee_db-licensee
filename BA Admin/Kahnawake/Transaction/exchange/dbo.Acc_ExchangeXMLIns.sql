ALTER PROCEDURE [dbo].[Acc_ExchangeXMLIns]  
	@strXML NVARCHAR(MAX)
AS  
/*  Created: Henry  
	Date: 2012-03-02
    TASk : Insert data to exchange in Kahnawake server using XML
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
DELETE FROM exchange WITH (ROWLOCK,UPDLOCK)      
WHERE exchangeid IN (      
	SELECT exchangeid FROM OPENXML(@intDocHandle,'root/exchange',2)      
	WITH (exchangeid INT)      
)  

INSERT INTO [dbo].exchange
           (exchangeid
           ,currency
           ,code
           ,multipliedby
           )
SELECT       
	exchangeid
	,currency
	,code
	,multipliedby
FROM OPENXML(@intDocHandle,'/root/exchange',2) 	
WITH
(
	exchangeid int,
	currency NVARCHAR(50),
	code VARCHAR(3),
	multipliedby int
)
           
END   

GO
GRANT EXECUTE ON [dbo].[Acc_ExchangeXMLIns] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_ExchangeXMLIns] TO [vnteam] 

   
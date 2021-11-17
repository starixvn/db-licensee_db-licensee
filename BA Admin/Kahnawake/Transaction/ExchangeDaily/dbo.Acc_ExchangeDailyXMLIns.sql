ALTER PROCEDURE [dbo].[Acc_ExchangeDailyXMLIns]  
	@strXML NVARCHAR(MAX)
AS  
/*  Created: Henry  
	Date: 2012-03-07
    TASk : Insert data to exchangedaily in Kahnawake server using XML
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
DELETE FROM ExchangeDaily WITH (ROWLOCK,UPDLOCK)      
WHERE exchangedate IN (      
	SELECT exchangedate FROM OPENXML(@intDocHandle,'root/exchangedaily',2)      
	WITH (exchangedate SMALLDATETIME)      
)  

INSERT INTO [dbo].exchangedaily
           (exchangedate
           ,exchangeid
           ,code
           ,myr
           ,usd
           ,eur
           ,cny
           ,actualrate
           )
SELECT       
	exchangedate
   ,exchangeid
   ,code
   ,myr
   ,usd
   ,eur
   ,cny
   ,actualrate
FROM OPENXML(@intDocHandle,'/root/exchangedaily',2) 	
WITH
(
	exchangedate smalldatetime
   ,exchangeid int
   ,code varchar(5)
   ,myr float
   ,usd float
   ,eur float
   ,cny float
   ,actualrate float
)
           
END   

GO
GRANT EXECUTE ON [dbo].[Acc_ExchangeDailyXMLIns] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_ExchangeDailyXMLIns] TO [vnteam] 

    
USE [bodb_MoveBet]
GO
/****** Object:  StoredProcedure [dbo].[Acc_ExchangeDailyXMLIns]    Script Date: 07/12/2012 11:04:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Acc_ExchangeDailyOandaXMLIns]  
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
DELETE FROM ExchangeDailyOanda WITH (ROWLOCK,UPDLOCK)      
WHERE exchangedate IN (      
	SELECT exchangedate FROM OPENXML(@intDocHandle,'root/exchangedailyoanda',2)      
	WITH (exchangedate SMALLDATETIME)      
)  

INSERT INTO [dbo].ExchangeDailyOanda
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
FROM OPENXML(@intDocHandle,'/root/exchangedailyoanda',2) 	
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
GRANT EXECUTE ON [dbo].[Acc_ExchangeDailyOandaXMLIns] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_ExchangeDailyOandaXMLIns] TO [vnteam] AS [dbo]
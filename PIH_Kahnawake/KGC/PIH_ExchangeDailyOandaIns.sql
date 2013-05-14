ALTER PROCEDURE [dbo].[PIH_ExchangeDailyOandaIns]  
	@strXML NVARCHAR(MAX)
AS  
/*  Created: Viet  
	Date: 2012-07-16
    DB: WW100_DB.bodb_PIH @ kahnawake
   
    Revisions:  
		
	Param's Explanation:  
*/  
 
SET NOCOUNT ON  
		
DECLARE @intDocHandle INT

--Create an internal representation of the XML document.      
EXEC sp_xml_preparedocument @intDocHandle OUTPUT, @strXML      

SELECT * INTO #temp_exchangedaily
FROM 
    OPENXML(@intDocHandle,'/root/exchangedailyoanda',2) 
    WITH (exchangedate smalldatetime, exchangeid int, code varchar(5), myr float, usd float, eur float, cny float, actualrate float)

DELETE dbo.exchangedailyoanda
FROM #temp_exchangedaily t
WHERE exchangedailyoanda.exchangedate = t.exchangedate
	and exchangedailyoanda.exchangeid = t.exchangeid

INSERT INTO exchangedailyoanda(exchangedate, exchangeid, code, myr, usd, eur, cny, actualrate)
SELECT exchangedate, exchangeid, code, myr, usd, eur, cny, actualrate
FROM #temp_exchangedaily

DROP TABLE #temp_exchangedaily

GO
GRANT EXECUTE ON [dbo].[PIH_ExchangeDailyOandaIns] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[PIH_ExchangeDailyOandaIns] TO [vnteam] 

 
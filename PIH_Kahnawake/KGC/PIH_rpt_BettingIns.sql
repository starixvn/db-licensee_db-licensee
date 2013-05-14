ALTER PROCEDURE [dbo].[PIH_rpt_BettingIns]
    @strXML NVARCHAR(MAX)
AS
/*
Created: 20120717@Don
Task: 
DB: WW100_DB.bodb_PIH @ kahnawake

Revisions:

Param's Explanation:

*/

SET NOCOUNT ON  

DECLARE @intDocHandle INT

--Create an internal representation of the XML document.      
EXEC sp_xml_preparedocument @intDocHandle OUTPUT, @strXML      
  
SELECT * INTO #temp
FROM 
    OPENXML(@intDocHandle,'/root/rpt_Betting',2) 
    WITH (rptDate smalldatetime, SiteID int, CurrencyID int, [Status] smallint, BetCount int, Turnover money, WinLoss money)


DELETE rpt_Betting 
WHERE rptdate in (select distinct rptdate from #temp)
        
INSERT INTO dbo.rpt_Betting(rptDate, SiteID, CurrencyID, [Status], BetCount, Turnover, WinLoss)
    SELECT rptDate, SiteID, CurrencyID, [Status], BetCount, Turnover, WinLoss
    FROM #temp

DROP TABLE #temp

SET NOCOUNT OFF



GO
GRANT VIEW DEFINITION ON [dbo].[PIH_rpt_BettingIns] TO [VNTeam]
GO
GRANT EXECUTE ON [dbo].[PIH_rpt_BettingIns] TO [bodbAdminNet] 
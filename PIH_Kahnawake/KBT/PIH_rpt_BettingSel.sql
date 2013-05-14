ALTER PROCEDURE [dbo].[PIH_rpt_BettingSel]
    @tstamp timestamp
AS
/*
Created: 20120717@Don
Task: 
DB: DB054.bodb_PIH

Revisions:

Param's Explanation:

*/

SET NOCOUNT ON  

DECLARE @mindate datetime
SET @mindate = CAST(FLOOR(CAST(DATEADD(dd, -5, CURRENT_TIMESTAMP) AS FLOAT)) AS DATETIME)
IF @mindate < '2012-08-01' SELECT @mindate = '2012-08-01'

SELECT rptDate, SiteID, CurrencyID, [Status], BetCount, Turnover, WinLoss, tstamp
FROM dbo.rpt_Betting b (NOLOCK)
WHERE rptDate >= @mindate
FOR XML PATH('rpt_Betting'), ROOT('root')


GO
GRANT VIEW DEFINITION ON [dbo].[PIH_rpt_BettingSel] TO [VNTeam]
GO
GRANT EXECUTE ON [dbo].[PIH_rpt_BettingSel] TO [bodbAdminNet] 
ALTER PROCEDURE [dbo].[PIH_Rpt_Winloss]
    @DateFrom datetime, 
    @DateTo datetime,
    @Currency int,
    @DrawFilter int,
    @ReportBy int
AS
/*
Created: 20120716@Don
Task: 
DB: WW100_DB.bodb_PIH @ kahnawake

Revisions:

Param's Explanation:

*/

SET NOCOUNT ON 

DECLARE 
    @DateFrom_SP datetime, 
    @DateTo_SP datetime,
    @Currency_SP int,
    @DrawFilter_SP int,
    @ReportBy_SP int
SELECT
    @DateFrom_SP =@DateFrom, 
    @DateTo_SP =@DateTo,
    @Currency_SP =@Currency,
    @DrawFilter_SP =@DrawFilter,
    @ReportBy_SP =@ReportBy
    
DECLARE
    @DateFrom_Oanda datetime,
    @DateTo_Oanda datetime

SELECT 
    @DateFrom_Oanda = @DateFrom_SP,
    @DateTo_Oanda = @DateTo_SP

SELECT @DateTo_SP = DATEADD(DAY,1,@DateTo_SP)

DECLARE @temp TABLE(rptDate datetime, CurrencyID int, [Status] smallint, Turnover money, BetCount int, CustomerWinLoss money)

INSERT INTO @temp(rptDate, CurrencyID, [Status], Turnover, BetCount, CustomerWinLoss)
    SELECT 
        b.rptDate
        ,b.CurrencyID
        ,b.Status
        ,SUM(b.Turnover) * 0.1 [Turnover]
        ,SUM(b.BetCount) [BetCount]
        ,SUM(b.WinLoss) * 0.1 [CustomerWinLoss]
    FROM dbo.rpt_Betting b (NOLOCK)
    WHERE 
        b.rptDate >= @DateFrom_SP AND b.rptDate < @DateTo_SP
        AND (@Currency_SP = 0 OR b.CurrencyID = @Currency_SP)
        AND b.CurrencyID <> 20
        AND b.Status <> 103 -- Refund
    GROUP BY
        b.rptDate
        ,b.CurrencyID
        ,b.Status

SELECT 
    CASE 
        WHEN @ReportBy_SP = 1 THEN CONVERT(varchar(8),b.rptDate,112) --Daily
        WHEN @ReportBy_SP = 2 THEN CONVERT(varchar(6),b.rptDate,112) --Monthly
    END [Date]
    ,e.Code [Currency]
    ,SUM(
        CASE
            WHEN @DrawFilter = 1 AND b.Status IN (114,115) THEN (b.Turnover * 0.5) 
            WHEN @DrawFilter IN (2,3) AND b.Status = 113 THEN 0 
            WHEN @DrawFilter IN (2,3) AND b.Status IN (114,115) THEN (b.Turnover * 0.5) 
            ELSE b.Turnover 
        END
    ) [Turnover]
    ,SUM(b.BetCount) [BetCount]
    ,SUM(b.CustomerWinLoss) [CustomerWL]
FROM @temp b
    LEFT JOIN dbo.ExchangeDailyOanda e with(NOLOCK) ON b.CurrencyID = e.ExchangeID and e.exchangedate = Convert(varchar(10),getdate() -1,111)
GROUP BY
    CASE 
        WHEN @ReportBy_SP = 1 THEN CONVERT(varchar(8),b.rptDate,112) --Daily
        WHEN @ReportBy_SP = 2 THEN CONVERT(varchar(6),b.rptDate,112) --Monthly
    END 
    ,e.Code
ORDER BY 1, 2

SELECT 
    SUM(
        CASE
            WHEN @DrawFilter = 1 AND b.Status IN (114,115) THEN (b.Turnover * 0.5) 
            WHEN @DrawFilter IN (2,3) AND b.Status = 113 THEN 0 
            WHEN @DrawFilter IN (2,3) AND b.Status IN (114,115) THEN (b.Turnover * 0.5) 
            ELSE b.Turnover
        END * e.EUR
    ) [TotalTurnover_EUR]
    ,SUM(b.CustomerWinLoss * e.EUR) [TotalCustomerWL_EUR]
FROM @temp b
	INNER JOIN ExchangeDailyOanda e on e.exchangedate = b.rptdate and b.currencyid = e.exchangeid   
	
GO
GRANT VIEW DEFINITION ON [dbo].[PIH_Rpt_Winloss] TO [VNTeam] 
GO
GRANT EXECUTE ON [dbo].[PIH_Rpt_Winloss] TO [bodbAdminNet] 
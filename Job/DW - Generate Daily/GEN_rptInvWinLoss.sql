USE [bodb_Invoice]
GO
/****** Object:  StoredProcedure [dbo].[GEN_rptInvWinLoss]    Script Date: 06/23/2015 04:21:10 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[GEN_rptInvWinLoss]
    @date datetime, 
    @date2 datetime = null
AS
/*
Created: 20130610@Don
Task: Generate data into rptInvWinLoss
DB: DB052.bodb_Invoice

Revisions:

Param's Explanation:

*/
IF @date2 IS NULL SET @date2 = @date
SET @date2 = DATEADD(day,1,@date2)

DELETE FROM dbo.rptInvWinLoss
WHERE rptDate>=@date AND rptDate<@date2

;WITH CTE AS (
	SELECT  
		b.rptDate
		,CASE 
			WHEN b.SiteID >= 1 AND b.SiteID < 1000 THEN b.SiteID 
			WHEN b.SiteID >= 1000 AND lbl.LicenseeID IS NOT NULL THEN lbl.LicenseeID
			ELSE 0
		END LicenseeID
		,CASE 
			WHEN b.Bettype < 31 OR (b.Bettype >= 121 AND b.Bettype < 1000) OR (b.Bettype BETWEEN 1301 AND 1334) THEN 1 -- Sportbooks
			WHEN b.Bettype BETWEEN 31 AND 33 THEN 2 -- Racing
			WHEN b.Bettype BETWEEN 81 AND 120 THEN 3 -- Number Game
			WHEN b.Bettype BETWEEN 1101 AND 1199 THEN 5 -- Live Casino
			WHEN b.Bettype BETWEEN 1201 AND 1299 THEN 6 -- Virtual Sports
			WHEN b.Bettype = 71 THEN 7 -- Casino
			ELSE 0
		END ProductID
		,b.CurrencyID
		,b.Status
		,b.CustomerCategory
		,0 isBA
		,ISNULL(SUM(WinLossA),0) GrossWL
		,ISNULL(SUM(WinLoss),0) MemberWL
		,ISNULL(SUM(Turnover),0) Turnover
		,ISNULL(SUM(BetCount),0) BetCount
		,ISNULL(SUM(CommissionA),0) Comm
		,ISNULL(SUM(CommissionP),0) PlayerComm
    FROM
	    bodb_Licensee.dbo.rpt_Betting b (NOLOCK)
		LEFT JOIN dbo.Licensees lic (NOLOCK) ON b.SiteID = lic.LicenseeID
		LEFT JOIN bodb_Licensee.dbo.Labels lbl (NOLOCK) ON b.SiteID = lbl.LabelID
    WHERE rptDate >= @date AND rptDate < @date2
		AND Status IN (111,112,113,114,115)
		AND [CurrencyID] <> 20
    GROUP BY
		b.rptDate
		,CASE 
			WHEN b.SiteID >= 1 AND b.SiteID < 1000 THEN b.SiteID 
			WHEN b.SiteID >= 1000 AND lbl.LicenseeID IS NOT NULL THEN lbl.LicenseeID
			ELSE 0
		END
		,CASE
			WHEN b.Bettype < 31 OR (b.Bettype >= 121 AND b.Bettype < 1000) OR (b.Bettype BETWEEN 1301 AND 1334) THEN 1 -- Sportbooks
			WHEN b.Bettype BETWEEN 31 AND 33 THEN 2 -- Racing
			WHEN b.Bettype BETWEEN 81 AND 120 THEN 3 -- Number Game
			WHEN b.Bettype BETWEEN 1101 AND 1199 THEN 5 -- Live Casino
			WHEN b.Bettype BETWEEN 1201 AND 1299 THEN 6 -- Virtual Sports
			WHEN b.Bettype = 71 THEN 7 -- Casino
			ELSE 0
		END
		,b.CurrencyID
		,b.Status
		,b.CustomerCategory
	UNION ALL
	SELECT  
		b.rptDate
		,CASE WHEN b.SiteID = -1 THEN 0 ELSE b.SiteID END LicenseeID
		,1 ProductID
		,b.CurrencyID
		,b.Status
		,-1 CustomerCategory
		,1 isBA
		,0 GrossWL
		,ISNULL(SUM(WinLoss),0) MemberWL
		,ISNULL(SUM(Turnover),0) Turnover
		,ISNULL(SUM(BetCount),0) BetCount
		,ISNULL(SUM(CommissionA),0) Comm
		,ISNULL(SUM(CommissionP),0) PlayerComm
    FROM bodb_Licensee.dbo.rpt_Betting_BA b (NOLOCK)
    WHERE rptDate >= @date AND rptDate < @date2
		AND Status IN (111,112,113,114,115)
		AND [CurrencyID] <> 20
    GROUP BY
		b.rptDate
		,CASE WHEN b.SiteID = -1 THEN 0 ELSE b.SiteID END
		,b.CurrencyID
		,b.Status
)
INSERT INTO dbo.rptInvWinLoss
        ([rptDate]
        ,[LicenseeID]
        ,[ProductID]
        ,[CurrencyID]
        ,[Status]
        ,[CustomerCategory]
        ,[isBA]
        ,[GrossWL]
        ,[MemberWL]
        ,[Turnover]
        ,[BetCount]
        ,[Comm]
        ,[PlayerComm])
    SELECT  
		rptDate
		,LicenseeID
		,ProductID
		,CurrencyID
		,Status
		,CustomerCategory
		,isBA
		,SUM(GrossWL) GrossWL
		,SUM(MemberWL) MemberWL
		,SUM(Turnover) Turnover
		,SUM(BetCount) BetCount
		,SUM(Comm) Comm
		,SUM(PlayerComm) PlayerComm
    FROM CTE
    GROUP BY
		rptDate
		,LicenseeID
		,ProductID
		,CurrencyID
		,Status
		,CustomerCategory
		,isBA

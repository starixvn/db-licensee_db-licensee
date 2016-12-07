USE [bodb_Licensee]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_Rpt_MonthlyLicCurrencyPlay]    Script Date: 12/07/2016 02:37:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.Lrf_Rpt_MonthlyLicCurrencyPlay    Script Date: 6/19/2012 11:25:07 AM ******/
ALTER PROCEDURE [dbo].[Lrf_Rpt_MonthlyLicCurrencyPlay]  
 @FromDate	SMALLDATETIME,
 @ToDate	SMALLDATETIME
 
AS
/*  Created: Henry
	Date: 2012-05-31
    Task : Licensee Winloss By Country IP Report
    DB: DB052.bodb_licensee
   
    Revisions:  
	
	Param's Explanation:  
	- 20160726@Francis: Move SP to bodb_LicenseeReport - [Redmine: #60449]
	  
*/
    
BEGIN      


SELECT
    l.LicenseeName,
    e.Code,
    CASE
        WHEN b.currency = 2 THEN 'MALAYSIA'
        WHEN b.currency = 4 THEN 'THAILAND'
        WHEN b.currency = 13 THEN 'CHINA'
        WHEN b.currency = 15 THEN 'INDONESIA'  
    END AS CurrencyCountry,
    CASE WHEN ISNULL(ct.countryLONG,'') IN ('','-') THEN 'UNKNOWN'
		ELSE ct.countryLONG END as country,
SUM(CASE WHEN b.statusID = 111  THEN 0
					WHEN b.statusID IN (114,115) THEN 0.5
					WHEN b.statusID IN (112,113) THEN 1 ELSE 0 END * turnover ) AS TurnoverWL,
SUM(CASE WHEN statusID IN (112,113,111,114,115) THEN turnover ELSE 0 END ) AS TurnoverWLD,
SUM(winlost) AS winlost,
sum(BetCount) as betcount,
count(CustID) as membercount
FROM bodb_Report.dbo.rptLicIPBetting b WITH (NOLOCK)
    INNER join Licensees l WITH (NOLOCK) ON l.licenseeid = b.licenseeid
    INNER join bodb02.dbo.exchange e WITH (NOLOCK) ON b.currency = e.exchangeid
	LEFT JOIN country ct WITH (NOLOCK) ON b.countrySHORT = ct.countrySHORT
WHERE
b.winlostdate BETWEEN @FromDate AND @ToDate AND
b.Currency IN (2,4,13,15) --MALAYSIA,THAILAND,CHINA,INDONESIA
GROUP BY l.LicenseeName,b.currency,e.Code,CASE WHEN ISNULL(ct.countryLONG,'') IN ('','-') THEN 'UNKNOWN'
		ELSE ct.countryLONG END
ORDER BY LicenseeName, e.code,CASE WHEN ISNULL(ct.countryLONG,'') IN ('','-') THEN 'UNKNOWN'
		ELSE ct.countryLONG END

	
END
GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_MonthlyLicCurrencyPlay] TO [bodbLicenseeNet] AS [dbo]
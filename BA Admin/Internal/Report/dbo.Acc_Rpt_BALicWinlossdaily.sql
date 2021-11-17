/*<info serverAlias="DBEXT-bodb02" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_Rpt_BALicWinlossDaily]  
	@Date SMALLDATETIME
AS  
/*
	Created: 20110920@Henry  
    Task: BA Winloss Report for Licensee Daily
    DB: DBEXT.bodb02
   
    Revisions:  
		- 20110930@Henry: add live indicator
		- 20111017@Henry: turn to use standard currency name
		- 20111230@Henry: remove virtual concept
		- 20120803@Jim: add playercomm value (for give commission to member)
		- 20191010@Percy: Replace LicenseeBATransaction to LicenseeBATransaction_active [RedmineID: #103656]
	
	Param's Explanation:  
*/  
BEGIN  
SET NOCOUNT ON  

SELECT @Date = CONVERT(varchar(10),@Date,120)

SELECT   
	l.LicenseeName,
	l.LicenseeID,
	b.Currency,
	--e.currency AS CurrencyName,
	CASE WHEN b.Currency = 51 THEN 'INH' ELSE e.Code END AS CurrencyName,
	b.liveindicator,
	SUM(b.actualrate * stake) AS turnoverRM, 
	-- SUM((b.winlost - b.actual_stake)*b.virtualrate) AS WinlostVirtual,  
	SUM((b.winlost - b.actual_stake)*b.actualrate) AS WinlostRM,
	-- - SUM ((b.winlost - b.actual_stake + awinlost + comm) * b.virtualrate )  AS AmtDueToBAVirtual ,
	- SUM ((b.winlost - b.actual_stake + awinlost + comm ) * b.actualrate) AS AmtDueToBARM,
	--SUM ((comm - playercomm)*b.virtualrate) AS CommVirtual,
	SUM (comm *b.actualrate) AS CommRM,
	SUM( b.playercomm*b.actualrate  ) AS PlayerCommRM,
	COUNT(b.transid) AS BetCount	
FROM dbo.bettrans b WITH (NOLOCK,INDEX=PK_bettrans)   
	INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction_active BA WITH (NOLOCK) ON b.transid = BA.transid
	INNER JOIN bodb_Licensee.dbo.LicenseeCust lc WITH (NOLOCK) ON b.recommend = lc.custid
	INNER JOIN bodb_Licensee.dbo.Licensees l WITH (NOLOCK) ON l.LicenseeID = lc.LicenseeID
	INNER JOIN exchange e WITH (NOLOCK) ON lc.currency = e.exchangeid
	
WHERE 
	b.winlostdate = @Date AND
	b.ruben=1 AND   
	b.statusID NOT IN (101, 102, 103) AND
	lc.Currency <> 20
GROUP BY   
	l.LicenseeID,l.LicenseeName,b.currency,
	CASE WHEN b.Currency = 51 THEN 'INH' ELSE e.Code END,b.liveindicator
END   
GO
USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Task_DailyRptLicIPBetting_Archive]    Script Date: 12/23/2014 04:37:35 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.Task_DailyRptLicIPBetting_Archive    Script Date: 2/5/2013 11:07:19 PM ******/
/****** Object:  Stored Procedure dbo.Task_DailyRptLicIPBetting_Archive    Script Date: 2/4/2013 6:25:40 PM ******/
/****** Object:  Stored Procedure dbo.Task_DailyRptLicIPBetting_Archive    Script Date: 6/19/2012 11:25:08 AM ******/
ALTER PROCEDURE [dbo].[Task_DailyRptLicIPBetting_Archive]
	@winlostdate DATETIME
AS
/*
Created by:[Henry]
Date: 2012-05-30
Task: daily summary IP betting for Licensee
DB: DBLIC/BODB02
Revisions:
    - 20130124@Daniel: Change link server alias
    - 20141211@Daniel: Improve performance, use column countryCode

	
   
 */

SET NOCOUNT ON 


IF NOT EXISTS(SELECT top 1 (1) FROM DBARC.bodb_archive.dbo.bettrans_bk WITH(NOLOCK) WHERE winlostdate = @winlostdate) RETURN

DELETE FROM bodb_Licensee.dbo.rptLicIPBetting WHERE winlostdate = @winlostdate	

	
INSERT INTO bodb_Licensee.dbo.rptLicIPBetting
	(
		[winlostdate]
		,[LicenseeID]
		,[countrySHORT]
		,[currency]
		,[CustID]
		,[ip]
		,[turnover]
		,[winlost]
		,[betcount]
		,[statusID]
	)
SELECT @winlostdate,l.LicenseeID, CountryCode, bettrans.currency,bettrans.custid,bettrans.ip,
		SUM(
			case when bettrans.liveawayscore = 0 and bettrans.bettype IN(33,43) then ABS(bettrans.stake/2) else ABS(bettrans.stake) end
			) as TurnOver,
		SUM(winlost-actual_stake)  winlost,
		COUNT(bettrans.transid) BetCount,		
		--114: half win, 115: half lose
		CASE 
			WHEN bettrans.status = 'WON' AND bettrans.bettype IN(1,3,7,8,17,18) AND ABS(modds) = 0.25 THEN 114 
			WHEN bettrans.status = 'LOSE' AND bettrans.bettype IN(1,3,7,8,17,18) AND ABS(modds) = 0.25 THEN 115
			WHEN bettrans.status = 'WON' THEN 112
			WHEN bettrans.status = 'LOSE' THEN 113
			WHEN bettrans.status = 'DRAW' THEN 111
			END AS statusID
	
FROM
	DBARC.bodb_archive.dbo.bettrans_bk bettrans WITH (NOLOCK)
	INNER JOIN bodb02.dbo.customer WITH (NOLOCK) ON bettrans.custid=customer.custid
	INNER JOIN bodb02.dbo.dep_custsuper s WITH (NOLOCK) ON customer.srecommend = s.custid
	INNER JOIN bodb_licensee.dbo.Licensees l WITH (NOLOCK) ON s.site = l.LicenseeName
WHERE
	bettrans.winlostdate = @winlostdate AND
	bettrans.status IN ('WON','LOSE','DRAW') AND
	bettrans.bettype < 19000 AND
	bettrans.currency <> 20
	--AND bettrans.currency IN (2,4,13,15) --MYR,THB,RMB,IDR
GROUP BY
	l.LicenseeID,
	CountryCode,
	bettrans.currency,
	bettrans.custid,
	bettrans.ip,
	CASE 
	WHEN bettrans.status = 'WON' AND bettrans.bettype IN(1,3,7,8,17,18) AND ABS(modds) = 0.25 THEN 114 
	WHEN bettrans.status = 'LOSE' AND bettrans.bettype IN(1,3,7,8,17,18) AND ABS(modds) = 0.25 THEN 115
	WHEN bettrans.status = 'WON' THEN 112
	WHEN bettrans.status = 'LOSE' THEN 113
	WHEN bettrans.status = 'DRAW' THEN 111
	END

GO
GRANT EXECUTE ON [dbo].[Task_DailyRptLicIPBetting_Archive] TO [vnteam] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Task_DailyRptLicIPBetting_Archive] TO [vnteam] AS [dbo]
USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Task_DailyRptLicIPBetting_Archive]    Script Date: 01/24/2013 02:44:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.Task_DailyRptLicIPBetting_Archive    Script Date: 6/19/2012 11:25:08 AM ******/
ALTER PROCEDURE [dbo].[Task_DailyRptLicIPBetting_Archive]
	@winlostdate DATETIME
AS
/*
Created by:[Henry]
Date: 2012-05-30
Task: daily summary IP betting for Licensee
DB: DBRPT/BODB02
Revisions:
    - 20130124@Daniel: Change link server alias

	
   
 */

SET NOCOUNT ON 

DECLARE @BalanceUpDay smalldatetime

SELECT 
	TOP 1 @BalanceUpDay = winlostdate
FROM Bettrans WITH(NOLOCK)
WHERE bettype = 20000 AND matchid = 0	AND custid = 3




IF @winlostdate < @BalanceUpDay
BEGIN
	delete from DBLIC.bodb_Licensee.dbo.rptLicIPBetting with(ROWLOCK,UPDLOCK) where winlostdate = @winlostdate	
	
	
	INSERT INTO DBLIC.bodb_Licensee.dbo.rptLicIPBetting
		(
			[winlostdate]
			,[LicenseeID]
			,[currency]
			,[CustID]
			,[ip]
			,[turnover]
			,[winlost]
			,[betcount]
			,[statusID]
		)
	SELECT @winlostdate,l.LicenseeID,bettrans.currency,bettrans.custid,bettrans.ip,
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
			bodb_archive.dbo.bettrans_bk bettrans WITH (NOLOCK,INDEX(CIX_winlostdate))
			INNER JOIN bodb02.dbo.customer WITH (NOLOCK) ON bettrans.custid=customer.custid
			INNER JOIN bodb02.dbo.dep_custsuper s WITH (NOLOCK) ON customer.srecommend = s.custid
			INNER JOIN DBLIC.bodb_licensee.dbo.Licensees l WITH (NOLOCK) ON s.site = l.LicenseeName
		WHERE
			bettrans.winlostdate = @winlostdate AND
			bettrans.status IN ('WON','LOSE','DRAW') AND
			bettrans.bettype < 19000 AND
			bettrans.currency <> 20
			--AND bettrans.currency IN (2,4,13,15) --MYR,THB,RMB,IDR
		GROUP BY
			l.LicenseeID,
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
END


/*	
--1st map with table IPCountry to update countrySHORT
WHILE (1=1)
BEGIN	
	UPDATE TOP(1000) DBLIC.bodb_Licensee.dbo.rptLicIPBetting WITH (ROWLOCK,UPDLOCK) SET countrySHORT = i.countrySHORT
	FROM DBLIC.bodb_Licensee.dbo.rptLicIPBetting m INNER join DBLIC.bodb_Licensee.dbo.IPCountry i WITH (NOLOCK) ON m.ip=i.ip
	WHERE 
		m.winlostdate = @winlostdate
		AND ISNULL(m.countrySHORT,'') IN ('-','')
		AND ISNULL(i.countrySHORT,'') NOT IN ('-','')
	
	IF  @@ROWCOUNT < 1000
		BREAK       
END


--Update Country
CREATE TABLE #IPList (ip VARCHAR(15),  country VARCHAR(2))

INSERT INTO #IPList(ip)
SELECT DISTINCT ip FROM DBLIC.bodb_Licensee.dbo.rptLicIPBetting WITH (NOLOCK)
WHERE 
	winlostdate = @winlostdate
	AND ISNULL(countrySHORT,'') IN  ('','-')

IF (SELECT count(*) FROM #IPList) > 0
BEGIN
	CREATE INDEX IX_tmp ON #IPList (ip)  

	UPDATE #IPList
	SET country = bodb02.dbo.IP2Country(IP)

	DELETE FROM bodb_Licensee.dbo.IPCountry WITH (ROWLOCK, UPDLOCK)
	WHERE ISNULL(countrySHORT,'') IN  ('','-')

	INSERT INTO DBLIC.bodb_Licensee.dbo.IPCountry (ip,countrySHORT)
	SELECT 
		a.ip,a.country FROM #IPList a
		LEFT JOIN DBLIC.bodb_Licensee.dbo.IPCountry b WITH (NOLOCK)
		ON a.ip = b.ip
	WHERE b.ip IS NULL AND a.country <> ''

	--2nd map with IPCountry again to update countrySHORT
	WHILE (1=1)
	BEGIN	
		UPDATE TOP(1000) DBLIC.bodb_Licensee.dbo.rptLicIPBetting WITH (ROWLOCK,UPDLOCK) SET countrySHORT = i.countrySHORT
		FROM DBLIC.bodb_Licensee.dbo.rptLicIPBetting m INNER join DBLIC.bodb_Licensee.dbo.IPCountry i WITH (NOLOCK)  ON m.ip=i.ip
		WHERE 
			m.winlostdate = @winlostdate
			AND ISNULL(m.countrySHORT,'') IN ('-','')
			AND ISNULL(i.countrySHORT,'') NOT IN ('-','')
		
		IF  @@ROWCOUNT < 1000
			BREAK       
	END

	DROP TABLE #IPList
END

SELECT IP, countrySHORT as 'unknown Country' FROM DBLIC.bodb_Licensee.dbo.IPCountry WITH (NOLOCK)  WHERE ISNULL(countrySHORT,'') IN ('-','')

*/
GO
GRANT EXECUTE ON [dbo].[Task_DailyRptLicIPBetting_Archive] TO [vnteam] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Task_DailyRptLicIPBetting_Archive] TO [vnteam] AS [dbo]
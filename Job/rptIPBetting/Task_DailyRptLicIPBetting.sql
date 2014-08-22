ALTER PROCEDURE [dbo].[Task_DailyRptLicIPBetting]
	@winlostdate DATETIME
AS
/*
Created by:[Henry]
Date: 2012-05-30
Task: daily summary IP betting for Licensee
DB: DB052.BODB02
Revisions:
	
   
 */

SET NOCOUNT ON 

DECLARE @BalanceUpDay smalldatetime, @MoveBetsDay smalldatetime,@i INT, @max INT, @IP NVARCHAR(40), @country VARCHAR(2)

SELECT 
	TOP 1 @BalanceUpDay = winlostdate
FROM Bettrans WITH(NOLOCK)
WHERE bettype = 20000 AND matchid = 0	AND custid = 3

SELECT    
	@MoveBetsDay = MAX(eventdate)  
FROM match14 WITH(NOLOCK)  

	

	
	
IF @winlostdate > @MoveBetsDay
BEGIN	
	--Delete before inserting
	delete from bodb_Licensee.dbo.rptLicIPBetting with(ROWLOCK,UPDLOCK) where winlostdate = @winlostdate
	
	INSERT INTO bodb_Licensee.dbo.rptLicIPBetting
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
				WHEN bettrans.statusID = 112 AND bettrans.bettype IN(1,3,7,8,17,18) AND ABS(modds) = 0.25 THEN 114 
				WHEN bettrans.statusID = 113 AND bettrans.bettype IN(1,3,7,8,17,18) AND ABS(modds) = 0.25 THEN 115
				ELSE bettrans.statusID END AS statusID
		
		FROM
			bettrans bettrans WITH (NOLOCK)
			INNER JOIN customer WITH (NOLOCK) ON bettrans.custid=customer.custid
			INNER JOIN dep_custsuper s WITH (NOLOCK) ON customer.srecommend = s.custid
			INNER JOIN bodb_licensee.dbo.Licensees l WITH (NOLOCK) ON s.site = l.LicenseeName
		WHERE
			bettrans.winlostdate = @winlostdate AND
			bettrans.statusID IN (111,112,113) AND
			bettrans.bettype < 19000 AND
			bettrans.currency <> 20
			--AND bettrans.currency IN (2,4,13,15) --MYR,THB,RMB,IDR
		GROUP BY
			l.LicenseeID,
			bettrans.currency,
			bettrans.custid,
			bettrans.ip,
			CASE 
				WHEN bettrans.statusID = 112 AND bettrans.bettype IN(1,3,7,8,17,18) AND ABS(modds) = 0.25 THEN 114 
				WHEN bettrans.statusID = 113 AND bettrans.bettype IN(1,3,7,8,17,18) AND ABS(modds) = 0.25 THEN 115
				ELSE bettrans.statusID END 
END
ELSE IF @winlostdate <= @MoveBetsDay AND @winlostdate >= @BalanceUpDay
BEGIN
	--Delete before inserting
	delete from bodb_Licensee.dbo.rptLicIPBetting with(ROWLOCK,UPDLOCK) where winlostdate = @winlostdate
	
	INSERT INTO bodb_Licensee.dbo.rptLicIPBetting
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
				WHEN bettrans.statusID = 112 AND bettrans.bettype IN(1,3,7,8,17,18) AND ABS(modds) = 0.25 THEN 114 
				WHEN bettrans.statusID = 113 AND bettrans.bettype IN(1,3,7,8,17,18) AND ABS(modds) = 0.25 THEN 115
				ELSE bettrans.statusID END AS statusID
		
		FROM
			bettrans14 bettrans WITH (NOLOCK)
			INNER JOIN customer WITH (NOLOCK) ON bettrans.custid=customer.custid
			INNER JOIN dep_custsuper s WITH (NOLOCK) ON customer.srecommend = s.custid
			INNER JOIN bodb_licensee.dbo.Licensees l WITH (NOLOCK) ON s.site = l.LicenseeName
		WHERE
			bettrans.winlostdate = @winlostdate AND
			bettrans.statusID IN (111,112,113) AND
			bettrans.bettype < 19000 AND
			bettrans.currency <> 20
			--AND bettrans.currency IN (2,4,13,15) --MYR,THB,RMB,IDR
		GROUP BY
			l.LicenseeID,
			bettrans.currency,
			bettrans.custid,
			bettrans.ip,
			--114: half win, 115: half lose
			CASE 
				WHEN bettrans.statusID = 112 AND bettrans.bettype IN(1,3,7,8,17,18) AND ABS(modds) = 0.25 THEN 114 
				WHEN bettrans.statusID = 113 AND bettrans.bettype IN(1,3,7,8,17,18) AND ABS(modds) = 0.25 THEN 115
				ELSE bettrans.statusID END 
		
END

--1st map with table IPCountry to update countrySHORT
WHILE (1=1)
BEGIN	
	UPDATE TOP(1000) bodb_Licensee.dbo.rptLicIPBetting WITH (ROWLOCK,UPDLOCK) SET countrySHORT = i.countrySHORT
	FROM bodb_Licensee.dbo.rptLicIPBetting m INNER join bodb_Licensee.dbo.IPCountry i WITH (NOLOCK) ON m.ip=i.ip
	WHERE 
		m.winlostdate = @winlostdate
		AND ISNULL(m.countrySHORT,'') IN ('-','')
		AND ISNULL(i.countrySHORT,'') NOT IN ('-','')
	
	IF  @@ROWCOUNT < 1000
		BREAK       
END


--Update Country
CREATE TABLE #IPList (ID INT IDENTITY(1,1),ip NVARCHAR(40),  country VARCHAR(2))

INSERT INTO #IPList(ip)
SELECT DISTINCT ip FROM bodb_Licensee.dbo.rptLicIPBetting WITH (NOLOCK)
WHERE 
	winlostdate = @winlostdate
	AND ISNULL(countrySHORT,'') IN  ('','-')

IF (SELECT count(*) FROM #IPList) > 0
BEGIN
	SELECT @i = 1
	SELECT @max =  max(id) FROM #IPList
	CREATE INDEX IX_tmp ON #IPList (ip)  

	WHILE (@i <=@max)
	BEGIN
		SELECT @IP = IP FROM #IPList WHERE ID = @i
		IF (charindex( '.', @IP, 1)>0)
		BEGIN
			SELECT @country = bodb02.dbo.IP2Country(@IP)
			IF @@ERROR <> 0
			BEGIN
				PRINT @IP
				BREAK
			END
			
			UPDATE #IPList SET country = @country
			WHERE ID = @i
		END
		
		SET @i = @i + 1
	END
	/*
	WHILE (1=1)
	BEGIN
		UPDATE TOP (1000) #IPList
		SET country = bodb02.dbo.IP2Country(IP)
		WHERE ISNULL(country,'') = ''
		
		IF  @@ROWCOUNT < 1000
		BREAK    
	END
	*/
	DELETE FROM bodb_Licensee.dbo.IPCountry WITH (ROWLOCK, UPDLOCK)
	WHERE IP IN (SELECT IP FROM #IPList WHERE ISNULL(country,'') <> '')

	INSERT INTO bodb_Licensee.dbo.IPCountry (ip,countrySHORT)
	SELECT 
		a.ip,a.country FROM #IPList a
		LEFT JOIN bodb_Licensee.dbo.IPCountry b WITH (NOLOCK)
		ON a.ip = b.ip
	WHERE b.ip IS NULL AND a.country <> ''

	--2nd map with IPCountry again to update countrySHORT
	WHILE (1=1)
	BEGIN	
		UPDATE TOP(1000) bodb_Licensee.dbo.rptLicIPBetting WITH (ROWLOCK,UPDLOCK) SET countrySHORT = i.countrySHORT
		FROM bodb_Licensee.dbo.rptLicIPBetting m INNER join bodb_Licensee.dbo.IPCountry i WITH (NOLOCK)  ON m.ip=i.ip
		WHERE 
			m.winlostdate = @winlostdate
			AND ISNULL(m.countrySHORT,'') IN ('-','')
			AND ISNULL(i.countrySHORT,'') NOT IN ('-','')
		
		IF  @@ROWCOUNT < 1000
			BREAK       
	END

	DROP TABLE #IPList
END

--SELECT IP, countrySHORT as 'unknown Country' FROM bodb_Licensee.dbo.IPCountry WITH (NOLOCK)  WHERE ISNULL(countrySHORT,'') IN ('-','')


		
GO
GRANT EXECUTE ON [dbo].[Task_DailyRptLicIPBetting] TO [vnteam]
GO		  
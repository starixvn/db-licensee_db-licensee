ALTER PROCEDURE [dbo].[Task_RptLicIPBetting_UpdateCountry]
	@Fromdate DATETIME,
	@Todate	DATETIME
AS
/*
Created by:[Henry]
Date: 2012-06-11
Task: update country for table rptLicIPBetting
DB: DB052.BODB02
Revisions:
	
   
 */

SET NOCOUNT ON 

DECLARE @i INT, @max INT, @IP NVARCHAR(40), @country VARCHAR(2)


--1st map with table IPCountry to update countrySHORT
WHILE (1=1)
BEGIN	
	UPDATE TOP(1000) bodb_Licensee.dbo.rptLicIPBetting WITH (ROWLOCK,UPDLOCK) SET countrySHORT = i.countrySHORT
	FROM bodb_Licensee.dbo.rptLicIPBetting m INNER join bodb_Licensee.dbo.IPCountry i WITH (NOLOCK) ON m.ip=i.ip
	WHERE 
		m.winlostdate BETWEEN @Fromdate AND @Todate
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
	winlostdate BETWEEN @Fromdate AND @Todate
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
	SELECT DISTINCT
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
			m.winlostdate BETWEEN @Fromdate AND @Todate
			AND ISNULL(m.countrySHORT,'') IN ('-','')
			AND ISNULL(i.countrySHORT,'') NOT IN ('-','')
		
		IF  @@ROWCOUNT < 1000
			BREAK       
	END

	DROP TABLE #IPList
END

SELECT IP, countrySHORT as 'unknown Country' FROM bodb_Licensee.dbo.IPCountry WITH (NOLOCK)  WHERE ISNULL(countrySHORT,'') IN ('-','')








		
GO
GRANT EXECUTE ON [dbo].[Task_RptLicIPBetting_UpdateCountry] TO [vnteam]
GO		   
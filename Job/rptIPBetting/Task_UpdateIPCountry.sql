ALTER PROCEDURE [dbo].[Task_UpdateIPCountry]
	@inputdate DATETIME='',
	@updateUnknownCountry BIT = 0
AS
/*
Created by:[Henry]
Date: 2012-08-08
Task: update ip country 
DB: DBRPT/BODB02
Revisions:
- 20130124@Daniel: Change link server alias
	
   
 */

SET NOCOUNT ON 

DECLARE @BalanceUpDay smalldatetime, @MoveBetsDay smalldatetime, @i INT, @max INT, @IP NVARCHAR(40), @country VARCHAR(2), @affectedRows INT
CREATE TABLE #IPList (ID INT IDENTITY(1,1),ip NVARCHAR(40),  country VARCHAR(2))

SELECT @affectedRows = 0

SELECT 
	TOP 1 @BalanceUpDay = winlostdate
FROM Bettrans WITH(NOLOCK)
WHERE bettype = 20000 AND matchid = 0	AND custid = 3

SELECT    
	@MoveBetsDay = MAX(eventdate)  
FROM match14 WITH(NOLOCK)  

IF @updateUnknownCountry=1
BEGIN	
	INSERT INTO #IPList(ip)
	SELECT ip FROM DBLIC.bodb_Licensee.dbo.IPCountry WITH (NOLOCK)
	WHERE ISNULL(countrySHORT,'') IN ('-','')
	
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
				
				SELECT @affectedRows = @affectedRows + 1
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
	END
	
	DELETE FROM DBLIC.bodb_Licensee.dbo.IPCountry WITH (ROWLOCK,UPDLOCK)
	WHERE IP IN (SELECT IP FROM #IPList WHERE ISNULL(country,'') <> '')
	
	INSERT INTO DBLIC.bodb_Licensee.dbo.IPCountry (ip,countrySHORT)
	SELECT DISTINCT
		a.ip,a.country FROM #IPList a
		LEFT JOIN DBLIC.bodb_Licensee.dbo.IPCountry b WITH (NOLOCK)
		ON a.ip = b.ip
	WHERE b.ip IS NULL AND a.country <> ''
END
ELSE
BEGIN
	IF @inputdate > @MoveBetsDay
	BEGIN	
		INSERT INTO #IPList(ip)
		SELECT DISTINCT b.ip FROM bettrans b WITH (NOLOCK)
		LEFT JOIN DBLIC.bodb_Licensee.dbo.IPCountry i WITH (NOLOCK) ON i.ip = b.ip
		WHERE 
			winlostdate = @inputdate
			AND b.ip <> ''
			AND i.ip IS NULL
			
	END
	ELSE IF @inputdate <= @MoveBetsDay AND @inputdate >= @BalanceUpDay
	BEGIN
		INSERT INTO #IPList(ip)
		SELECT DISTINCT b.ip FROM bettrans14 b WITH (NOLOCK,INDEX=IX_winlostdate)
		LEFT JOIN DBLIC.bodb_Licensee.dbo.IPCountry i WITH (NOLOCK) ON i.ip = b.ip
		WHERE 
			winlostdate = @inputdate
			AND b.ip <> ''
			AND i.ip IS NULL
	END
	ELSE IF @inputdate < @BalanceUpDay
	BEGIN
		INSERT INTO #IPList(ip)
		SELECT DISTINCT b.ip FROM bodb_Archive.dbo.bettrans_bk b WITH (NOLOCK,INDEX=CIX_winlostdate)
		LEFT JOIN DBLIC.bodb_Licensee.dbo.IPCountry i WITH (NOLOCK) ON i.ip = b.ip
		WHERE 
			winlostdate = @inputdate
			AND b.ip <> ''
			AND i.ip IS NULL
	END

	IF (SELECT count(*) FROM #IPList) > 0
	BEGIN
		SELECT @i = 1
		CREATE INDEX IX_tmp ON #IPList (ip)  
		
		SELECT @max =  max(id) FROM #IPList
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
				SELECT @affectedRows = @affectedRows + 1
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
		
		
		INSERT INTO DBLIC.bodb_Licensee.dbo.IPCountry (ip,countrySHORT)
		SELECT DISTINCT
			a.ip,a.country FROM #IPList a
			LEFT JOIN DBLIC.bodb_Licensee.dbo.IPCountry b WITH (NOLOCK)
			ON a.ip = b.ip
		WHERE b.ip IS NULL AND a.country <> ''
	END	
	
	print @inputdate
	--SELECT IP, countrySHORT as 'unknown Country' FROM DBLIC.bodb_Licensee.dbo.IPCountry WITH (NOLOCK)  WHERE ISNULL(countrySHORT,'') IN ('-','')	
END

print '(' + CAST(@affectedRows as VARCHAR(50)) + ' row(s) affected' + ')'
DROP table #IPList

GO
GRANT EXECUTE ON [dbo].[Task_UpdateIPCountry] TO [vnteam]
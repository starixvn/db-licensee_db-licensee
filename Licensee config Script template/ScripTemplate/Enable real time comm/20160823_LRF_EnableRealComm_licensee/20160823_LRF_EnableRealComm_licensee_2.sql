USE bodb_licensee
GO
 /*
Created:20160823@Jim
Task : Enable real time comm and odds [RedmineID #62818]
DB: DBLIC.bodb_licensee

Revisions:
    
Param's Explanation:
*/
DECLARE @Functioncomm AS TABLE (functionid INT )
DECLARE @licenseeuser AS TABLE (id INT identity(1,1),userid INT)
DECLARE @licenseeid INT 
DECLARE @i INT 
		,@maxID  INT
		,@userid INT
		
SELECT @licenseeid = licenseeid
FROM dbo.licensees WITH (NOLOCK)
WHERE licenseename = 'IONClub'  ---- RUN ONE BY ONE Licensee IN below LIST
					/*
					('IONClub'
						,'Gampag'
						,'Webet138'
						,'HuangMa'
						,'Uwin18'
						,'DEWA'
						,'Emmyo'
						,'BigGaming'
						,'Boying'
						,'Brown888'
						,'GDC'
						,'TCL'
						)
					*/
INSERT INTO @Functioncomm
SELECT FunctionId 
FROM dbo.Functions (NOLOCK)
WHERE ParentId = 4 

INSERT INTO  dbo.LicenseeFunctions (LicenseeId
								,FunctionId
								)
SELECT @licenseeid
		,functionid
FROM @Functioncomm
WHERE functionid NOT IN (SELECT functionid 
							 FROM dbo.LicenseeFunctions (NOLOCK) 
							 WHERE licenseeid = @licenseeid 
						 )

INSERT INTO  @licenseeuser (userid)
SELECT DISTINCT lu.userid
FROM dbo.LicenseeUser lu WITH (NOLOCK)
	INNER JOIN  dbo.users u WITH (NOLOCK) ON lu.userid=u.userid
WHERE lu.isactive = 1
	 AND lu.licenseeid = @licenseeid
	
SELECT @i = 1
		,@maxid = MAX(id)
FROM @licenseeuser		

WHILE @i <= @maxID
BEGIN 
	SELECT @userid = userid
	FROM   @licenseeuser 
	WHERE  id=@i

	INSERT INTO  dbo.LicenseeUserFunctions (userid
											,functionid
											,licenseeid
											)
	SELECT  DISTINCT @userid userid
				   ,lf.functionid
				   ,@licenseeid licenseeid
	FROM dbo.LicenseeFunctions lf WITH (NOLOCK)
		INNER JOIN @Functioncomm f ON lf.functionid = f.functionid
	WHERE lf.functionid NOT IN (SELECT functionid 
								FROM dbo.LicenseeUserFunctions WITH(NOLOCK)
								WHERE licenseeid = @licenseeid
									  AND userid = @userid
								)	
		AND licenseeid=@licenseeid							 
	SET @i=@i+1							 
END							 
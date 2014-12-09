USE bodb_licensee
GO
-- Remove real playercomm for Spondemo

 /*
Created: 20141113@JIm
Task : turnoff real playercomm for spond demo
DB: DBLIC.bodb_licensee

Revisions:
    
Param's Explanation:
*/
DECLARE @Functioncomm    INT 
		,@LicenseeId 	 INT 

SELECT  @licenseeid=licenseeid
FROM  dbo.licensees  WITH (NOLOCK)
WHERE  licenseename='spondemo'

SELECT @Functioncomm = Functionid
FROM dbo.Functions  WITH (NOLOCK)
WHERE Name ='Commission Group List'

 IF EXISTS (SELECT 1 FROM dbo.LicenseeFunctions WITH (NOLOCK) WHERE LicenseeId = @LicenseeId AND FunctionId = @Functioncomm)					 
	BEGIN 
		SELECT * 
		INTO #backup_function
		FROM dbo.LicenseeFunctions WITH (NOLOCK) 
		WHERE LicenseeId = @LicenseeId 
			AND FunctionId = @Functioncomm	
			
		DELETE 	dbo.LicenseeFunctions
		WHERE LicenseeId = @LicenseeId 
			AND FunctionId = @Functioncomm	
		SELECT * FROM #backup_function
		
		-- DROP TABLE #backup_function
	END 
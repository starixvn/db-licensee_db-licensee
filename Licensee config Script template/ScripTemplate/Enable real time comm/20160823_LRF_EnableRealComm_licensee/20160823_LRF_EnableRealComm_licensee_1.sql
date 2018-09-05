 

 /*
Created:20160823@Jim
Task : Enable real time comm and odds [RedmineID #62818]
DB: DBLIC.bodb_licensee

Revisions:
    
Param's Explanation:
*/
USE bodb_licensee
GO
DECLARE @i INT ,@max INT 
CREATE TABLE  #tblLicensee ([id] [int] IDENTITY(1,1) ,LicenseeID INT)

INSERT INTO #tblLicensee (LicenseeID)
SELECT l.LicenseeID
FROM dbo.Licensees l WITH (NOLOCK)
WHERE l.licenseename  in 
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

UPDATE dbo.Licensees WITH(ROWLOCK,UPDLOCK)
SET IsAllowedMemberComm = 1
FROM dbo.Licensees l
	INNER JOIN #tblLicensee t ON t.licenseeID = l.licenseeID
	
SELECT @i = 1,@max = max(ID) FROM  #tblLicensee
WHILE  (@i<@max+1)
	BEGIN 
		DECLARE @LicenseeID INT
		SELECT @LicenseeID = LicenseeID 
		FROM #tblLicensee
		WHERE ID = @i	
		IF NOT EXISTS (SELECT 1 FROM dbo.LicenseeCustComm (NOLOCK) WHERE LicenseeID = @LicenseeID)
		BEGIN 
			INSERT INTO  LicenseeCustComm (LicenseeID
											,CustID
											,SBComm
											,RacingComm
											,NGComm
											,GroupCommID
											,LCComm
											,RNGComm)
			SELECT t.LicenseeID
				  ,lci.CustID
				  ,0 as SBComm
				  ,0 as RacingComm
				  ,0 as NGComm
				  ,0 as GroupCommID
				  ,0 as LCComm
				  ,0 as RNGComm
			FROM #tblLicensee t
				INNER JOIN dbo.LicenseeCust  lc WITH (NOLOCK) ON t.LicenseeID  = lc.LicenseeID
				INNER JOIN dbo.LicenseeCustinfo lci WITH (NOLOCK) ON lc.CustID = lci.recommend
			WHERE t.ID=@i
		END
		SET @i=@i+1
	END	
DROP TABLE #tblLicensee	
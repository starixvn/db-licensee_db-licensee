USE CustDB
GO

CREATE PROCEDURE Lrf_CustBAActive_SynData
AS  
/*
Created: 20150305@Patrick
Task : Synchronize data from DB052 to CustDB when turn on/off BA occurs
DB: DBTXN/CustDB
Revisions:
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON
	CREATE TABLE #BAMemberTemp (CustId INT)
	DECLARE @sqlQuery VARCHAR(1024) 
	SELECT @sqlQuery =  'SELECT CustId
						FROM OPENQUERY(DBLIC, ''SELECT CustId 
						FROM bodb_Licensee.dbo.LicenseeBAHistory WITH (NOLOCK) 
						WHERE Status = ''''Running'''' 
						GROUP BY CustId 
						OPTION (MAXDOP 1)'')'
	--print @sqlQuery
	INSERT INTO #BAMemberTemp (CustId)
	EXEC (@sqlQuery)

	INSERT INTO dbo.Dep_CustBAActive(CustId)
	(
		SELECT tmp.CustId
		FROM #BAMemberTemp tmp
			LEFT JOIN dbo.Dep_CustBAActive ba WITH(NOLOCK) ON tmp.CustId = ba.CustId
		WHERE ba.CustId IS NULL
	)

	DROP TABLE #BAMemberTemp
END
GO
GRANT EXECUTE ON [dbo].[Lrf_CustBAActive_SynData] TO [bodbAdminNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Lrf_CustBAActive_SynData] TO [bodbLicenseeNet] AS [dbo]
GO


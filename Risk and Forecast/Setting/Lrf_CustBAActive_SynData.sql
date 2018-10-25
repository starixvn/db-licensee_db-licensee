/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet,bodbLicenseeNet" viewers="vnteam" isFunction="0"></info>*/
USE CustDB 
GO

ALTER PROCEDURE Lrf_CustBAActive_SynData
AS  
/*
	Created: 20150305@Patrick
	Task : Synchronize data from DB052 to CustDB when turn on/off BA occurs
	DB: DBCUST/CustDB
	Revisions:
		- 20180924@Elodie: Migrate bodb_Licensee to DBCUST [Redmine:#99855]

	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON
	CREATE TABLE #BAMemberTemp (CustId INT)
	DECLARE @sqlQuery VARCHAR(1024) 
	SELECT @sqlQuery =  'SELECT CustId
						FROM OPENQUERY(DBCUST, ''SELECT CustId 
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


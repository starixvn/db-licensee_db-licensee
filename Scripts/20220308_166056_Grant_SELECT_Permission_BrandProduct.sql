/*<info serverAlias="DBPLO-bodb_Ploutos"></info>*/
/*
	Created: 20220308@Sol
	DB: DBPLO-bodb_Ploutos
	Task: LAP - Grant select permission to bodbLicenseeNet
	RedmineID: #166056 - LAP - Auditing licensees - Daily Bets - Filter by Sport
*/

USE bodb_Ploutos

GO

GRANT SELECT ON bodb_Ploutos.dbo.BrandProduct TO bodbLicenseeNet

GO
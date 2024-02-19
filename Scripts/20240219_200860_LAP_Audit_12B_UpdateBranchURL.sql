/*<info serverAlias="DBPLO-bodb_Ploutos"></info>*/
/*
	Created: 20220219@Bobby
	DB: DBPLO-bodb_Ploutos
	Task: LAP Audit - 12B - Daily Bet Details [RedmineID: #200860]
*/

USE bodb_Ploutos
GO

UPDATE [dbo].[Brand] WITH(ROWLOCK,UPDLOCK)
SET BrandUrl='https://www.12betsports.com/'
WHERE BrandCode='12Bet'
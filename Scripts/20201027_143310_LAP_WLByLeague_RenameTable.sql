/*<info serverAlias="DBLIC-bodb_LicenseeReport"></info>*/

/*
	Created: 20201027@Kos
	DB: DBLIC-bodb_LicenseeReport
	Task: Rename temp tables rptWinlostbyLeague_New and rptCustomerMatch_New to main tables rptWinlostbyLeague and rptCustomerMatch
	RedmineID: #143310 - LAP - Win Loss By League - Change cluster index
*/

USE [bodb_LicenseeReport]
GO

EXEC sp_rename 'rptWinlostbyLeague', 'DEL_rptWinlostbyLeague'

GO

EXEC sp_rename 'rptWinlostbyLeague_New', 'rptWinlostbyLeague'

GO

EXEC sp_rename 'rptCustomerMatch', 'DEL_rptCustomerMatch'

GO

EXEC sp_rename 'rptCustomerMatch_New', 'rptCustomerMatch'

GO

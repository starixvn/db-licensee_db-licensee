/*<info serverAlias="DBACC-bodb_report"></info>*/
/*
	Created: 20240416@Eddie
	DB: DBACC-bodb_report
	Task: Grant permission to new account 'ow_12bet' [Redmine: #202118]
*/
USE bodb_report
GO

GRANT SELECT ON [dbo].[rptdepwinlost] TO [ow_12bet]
GO
GRANT SELECT ON [dbo].[rptDepWinlost_bk] TO [ow_12bet]
GO
GRANT SELECT ON [dbo].[rptDepWinlostByProduct] TO [ow_12bet]
GO
GRANT SELECT ON [dbo].[rptDepWinlostByProduct_BK] TO [ow_12bet]
GO
GRANT SELECT ON [dbo].[rptDepWinlost_Transfer3rdOthers] TO [ow_12bet]
GO
GRANT SELECT ON [dbo].[rptDepWinlost_Transfer3rdOthers_bk] TO [ow_12bet]
GO
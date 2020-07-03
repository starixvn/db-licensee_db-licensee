USE [bodb_PlaytechCS]
GO

/*
	 Creator: 20200106@Amanda
	 Task: Remove DBA SPs
	 Database: DBPTCS.bodb_PlaytechCS

	 Revisions:
	 -20200106@Amanda : Remove unused DBA SPs [redmine:#119443]
*/

-- DBA_Lrf_PullServiceSetting
EXEC sp_rename 'DBA_Lrf_PullServiceSetting', 'DEL_DBA_Lrf_PullServiceSetting', 'Object'

GO

-- DBA_EnableAGCasinoService
EXEC sp_rename 'DBA_EnableAGCasinoService', 'DEL_DBA_EnableAGCasinoService', 'Object'

GO

-- DBA_EnableGoldDeluxeService
EXEC sp_rename 'DBA_EnableGoldDeluxeService', 'DEL_DBA_EnableGoldDeluxeService', 'Object'

GO

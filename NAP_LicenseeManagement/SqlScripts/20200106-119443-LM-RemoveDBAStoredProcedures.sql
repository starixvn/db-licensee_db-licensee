USE [bodb_Licensee]
GO

/*
	 Creator: 20200106@Amanda
	 Task: Remove DBA SPs
	 Database: DBCUST.bodb_Licensee

	 Revisions:
	 -20200106@Amanda : Remove unused DBA SPs [redmine:#119443]
*/

-- DBA_Lrf_FunctionProduct
EXEC sp_rename 'DBA_Lrf_FunctionProduct', 'DEL_DBA_Lrf_FunctionProduct', 'Object'

GO

-- DBA_Lrf_ActiveLicenseeSystem
EXEC sp_rename 'DBA_Lrf_ActiveLicenseeSystem', 'DEL_DBA_Lrf_ActiveLicenseeSystem', 'Object'

GO

-- DBA_CreateLicenseeAgent
EXEC sp_rename 'DBA_CreateLicenseeAgent', 'DEL_DBA_CreateLicenseeAgent', 'Object'

GO

-- DBA_Lrf_EnablePlayerComm
EXEC sp_rename 'DBA_Lrf_EnablePlayerComm', 'DEL_DBA_Lrf_EnablePlayerComm', 'Object'

GO

-- DBA_Lrf_OfferProduct
EXEC sp_rename 'DBA_Lrf_OfferProduct', 'DEL_DBA_Lrf_OfferProduct', 'Object'

GO

-- DBA_LicenseeBAConfig_Ins
EXEC sp_rename 'DBA_LicenseeBAConfig_Ins', 'DEL_DBA_LicenseeBAConfig_Ins', 'Object'

GO

-- DBA_Lrf_CreateNewLicensee
EXEC sp_rename 'DBA_Lrf_CreateNewLicensee', 'DEL_DBA_Lrf_CreateNewLicensee', 'Object'

GO

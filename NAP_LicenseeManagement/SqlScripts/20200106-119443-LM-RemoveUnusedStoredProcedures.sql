USE [CustDB]
GO

/*
	 Creator: 20200106@Amanda
	 Task: Remove unused SPs
	 Database: DBCUST.CustDB

	 Revisions:
	 -20200106@Amanda : Remove unused SPs [redmine:#119443]
*/

-- NAP_LM_LicenseeCommissionUpd
EXEC sp_rename 'NAP_LM_LicenseeCommissionUpd', 'DEL_NAP_LM_LicenseeCommissionUpd', 'Object'

GO
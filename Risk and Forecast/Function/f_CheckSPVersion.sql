/*<info serverAlias="DBEXT-bodb02,DBLIC-bodb_licensee" executers="" viewers="" isFunction="1" isNested="1"></info>*/
USE [bodb_licensee]
GO

ALTER FUNCTION [dbo].[f_CheckSPVersion]
(
	@PROCID INT
)

/*
	Creator: Percy
	Date: 2016-03-23
	Task: Check SP Version
	DB:
		DBAGE.bodb02, DBAGE.bodb_Age, DBEXT.bodb02, DBDWH.bodb02, DBDWH.bodb_dwrs, DBEAS.bodb_EAS, DBLIC.bodb_licensee
		DBACC.bodb02, DBACC.bodb_ACC, DBRPT.bodb_Report,
		DBPRO.bodb02
	Revision:
		- 20160505@Percy: Remove 2 versions UAT3, UAT4 (for hotfix only)
	Remark: use function at database local - not link server or link database
*/

RETURNS BIT
AS
BEGIN
	IF	OBJECT_NAME(@PROCID) LIKE '%_xtest%'
		OR OBJECT_NAME(@PROCID) LIKE '%_xpre%'
		OR OBJECT_NAME(@PROCID) LIKE '%_UAT1%'
		OR OBJECT_NAME(@PROCID) LIKE '%_UAT2%'
		RETURN 1
	RETURN 0
END
GO
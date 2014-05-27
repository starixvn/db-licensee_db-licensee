IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Task_Stdby_Sync_Dep_KPI]') AND type in (N'P', N'PC'))
	DROP PROCEDURE [dbo].[Task_Stdby_Sync_Dep_KPI]
GO

CREATE PROCEDURE [dbo].[Task_Stdby_Sync_Dep_KPI]
AS
/*
Created	: 20140527@Don
Task	: KPI - Sync data 
DB		: DB054.bodb_Licensee

Revisions:
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @ServCurrent SYSNAME	= ''
	DECLARE @ServRemote SYSNAME		= ''
 
	SELECT @ServCurrent = @@SERVERNAME
	SELECT @ServRemote  = (SELECT sn FROM OPENQUERY(DBLIC,'SELECT @@SERVERNAME sn'))

	IF @@ERROR != 0
		RETURN

	IF ISNULL(@ServCurrent, '') = ISNULL(@ServRemote, '')
		RETURN

	/* Sync data */	TRUNCATE TABLE bodb_Licensee.dbo.KPI_Branches	SET IDENTITY_INSERT bodb_Licensee.dbo.KPI_Branches ON	INSERT INTO bodb_Licensee.dbo.KPI_Branches(BranchID,BranchName,BranchType,OrderNo,ReportType,IsActive)	SELECT BranchID,BranchName,BranchType,OrderNo,ReportType,IsActive FROM DBLIC.bodb_Licensee.dbo.KPI_Branches WITH(NOLOCK)	SET IDENTITY_INSERT bodb_Licensee.dbo.KPI_Branches OFF	---------------------------	TRUNCATE TABLE bodb_Licensee.dbo.KPI_BranchGroup	INSERT INTO bodb_Licensee.dbo.KPI_BranchGroup(BranchID,GroupID,ProductID)	SELECT BranchID,GroupID,ProductID FROM DBLIC.bodb_Licensee.dbo.KPI_BranchGroup WITH(NOLOCK)	---------------------------	TRUNCATE TABLE bodb_Licensee.dbo.KPI_Groups	SET IDENTITY_INSERT bodb_Licensee.dbo.KPI_Groups ON	INSERT INTO bodb_Licensee.dbo.KPI_Groups(GroupID,GroupName,GroupType,SiteID,OrderNo,RelatedBranch,IsActive)	SELECT GroupID,GroupName,GroupType,SiteID,OrderNo,RelatedBranch,IsActive FROM DBLIC.bodb_Licensee.dbo.KPI_Groups WITH(NOLOCK)	SET IDENTITY_INSERT bodb_Licensee.dbo.KPI_Groups OFF	---------------------------	TRUNCATE TABLE bodb_Licensee.dbo.KPI_Sections	SET IDENTITY_INSERT bodb_Licensee.dbo.KPI_Sections ON	INSERT INTO bodb_Licensee.dbo.KPI_Sections(SectionID,SectionName,IsDisplayed,SectionType,OrderNo,IsActive)	SELECT SectionID,SectionName,IsDisplayed,SectionType,OrderNo,IsActive FROM DBLIC.bodb_Licensee.dbo.KPI_Sections WITH(NOLOCK)	SET IDENTITY_INSERT bodb_Licensee.dbo.KPI_Sections OFF	---------------------------	TRUNCATE TABLE bodb_Licensee.dbo.KPI_SectionStatistic	INSERT INTO bodb_Licensee.dbo.KPI_SectionStatistic(StatID,SectionID)	SELECT StatID,SectionID FROM DBLIC.bodb_Licensee.dbo.KPI_SectionStatistic WITH(NOLOCK)	---------------------------	TRUNCATE TABLE bodb_Licensee.dbo.KPI_StatisticConfig	INSERT INTO bodb_Licensee.dbo.KPI_StatisticConfig(BranchID,StatID,IndexName,Template,StatisticName)	SELECT BranchID,StatID,IndexName,Template,StatisticName FROM DBLIC.bodb_Licensee.dbo.KPI_StatisticConfig WITH(NOLOCK)	---------------------------	TRUNCATE TABLE bodb_Licensee.dbo.KPI_Statistics	INSERT INTO bodb_Licensee.dbo.KPI_Statistics(StatID,StatisticType,OrderNo,MathType,OriginalName,IsActive)	SELECT StatID,StatisticType,OrderNo,MathType,OriginalName,IsActive FROM DBLIC.bodb_Licensee.dbo.KPI_Statistics WITH(NOLOCK)	---------------------------
END



GO
GRANT VIEW DEFINITION ON [dbo].[Task_Stdby_Sync_Dep_KPI] TO [vnteam]
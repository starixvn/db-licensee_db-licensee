IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Task_Stdby_Sync_Dep_OA]') AND type in (N'P', N'PC'))
	DROP PROCEDURE [dbo].[Task_Stdby_Sync_Dep_OA]
GO

CREATE PROCEDURE [dbo].[Task_Stdby_Sync_Dep_OA]
AS
/*
Created	: 20140527@Don
Task	: OA - Sync data 
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
	/* Sync data */
	TRUNCATE TABLE bodb_Licensee.dbo.OA_FunctionLicensees	INSERT INTO bodb_Licensee.dbo.OA_FunctionLicensees(FunctionID,ResellerID,LicenseeID)	SELECT FunctionID,ResellerID,LicenseeID FROM DBLIC.bodb_Licensee.dbo.OA_FunctionLicensees WITH(NOLOCK)	---------------------------	TRUNCATE TABLE bodb_Licensee.dbo.OA_FunctionResellers	INSERT INTO bodb_Licensee.dbo.OA_FunctionResellers(FunctionID,ResellerID)	SELECT FunctionID,ResellerID FROM DBLIC.bodb_Licensee.dbo.OA_FunctionResellers WITH(NOLOCK)	---------------------------	TRUNCATE TABLE bodb_Licensee.dbo.OA_Functions	INSERT INTO bodb_Licensee.dbo.OA_Functions(FunctionID,FunctionName,FunctionDesc,ParentID,ParentName,URL,CreatedDate,ModifiedDate,DisplayOrder,Creator,IsActive,FunctionKey)	SELECT FunctionID,FunctionName,FunctionDesc,ParentID,ParentName,URL,CreatedDate,ModifiedDate,DisplayOrder,Creator,IsActive,FunctionKey FROM DBLIC.bodb_Licensee.dbo.OA_Functions WITH(NOLOCK)	---------------------------	TRUNCATE TABLE bodb_Licensee.dbo.OA_GroupFunctions	INSERT INTO bodb_Licensee.dbo.OA_GroupFunctions(GroupID,FunctionID,LicenseeID,ResellerID,Policy)	SELECT GroupID,FunctionID,LicenseeID,ResellerID,Policy FROM DBLIC.bodb_Licensee.dbo.OA_GroupFunctions WITH(NOLOCK)	---------------------------	TRUNCATE TABLE bodb_Licensee.dbo.OA_GroupLicensees	INSERT INTO bodb_Licensee.dbo.OA_GroupLicensees(GroupID,ResellerID,LicenseeID)	SELECT GroupID,ResellerID,LicenseeID FROM DBLIC.bodb_Licensee.dbo.OA_GroupLicensees WITH(NOLOCK)	---------------------------	TRUNCATE TABLE bodb_Licensee.dbo.OA_GroupResellers	INSERT INTO bodb_Licensee.dbo.OA_GroupResellers(GroupID,ResellerID)	SELECT GroupID,ResellerID FROM DBLIC.bodb_Licensee.dbo.OA_GroupResellers WITH(NOLOCK)	---------------------------	TRUNCATE TABLE bodb_Licensee.dbo.OA_Groups	SET IDENTITY_INSERT bodb_Licensee.dbo.OA_Groups ON	INSERT INTO bodb_Licensee.dbo.OA_Groups(GroupID,GroupName,GroupDesc,IsActive,CreatedDate,ModifiedDate,Creator)	SELECT GroupID,GroupName,GroupDesc,IsActive,CreatedDate,ModifiedDate,Creator FROM DBLIC.bodb_Licensee.dbo.OA_Groups WITH(NOLOCK)	SET IDENTITY_INSERT bodb_Licensee.dbo.OA_Groups OFF	---------------------------	TRUNCATE TABLE bodb_Licensee.dbo.OA_LogAction	INSERT INTO bodb_Licensee.dbo.OA_LogAction(ActionID,ActionTypeID,SPName,ActionNameEN,ActionNameCH,ActionNameCS,ActionNameJP,ActionNameIT,ActionNameTH,ActionNameKO,XsltContent,IsInternal)	SELECT ActionID,ActionTypeID,SPName,ActionNameEN,ActionNameCH,ActionNameCS,ActionNameJP,ActionNameIT,ActionNameTH,ActionNameKO,XsltContent,IsInternal FROM DBLIC.bodb_Licensee.dbo.OA_LogAction WITH(NOLOCK)	---------------------------	TRUNCATE TABLE bodb_Licensee.dbo.OA_LogActionType	INSERT INTO bodb_Licensee.dbo.OA_LogActionType(ActionTypeID,ActionTypeNameEN,ActionTypeNameCH,ActionTypeNameCS,ActionTypeNameJP,ActionTypeNameIT,ActionTypeNameTH,ActionTypeNameKO)	SELECT ActionTypeID,ActionTypeNameEN,ActionTypeNameCH,ActionTypeNameCS,ActionTypeNameJP,ActionTypeNameIT,ActionTypeNameTH,ActionTypeNameKO FROM DBLIC.bodb_Licensee.dbo.OA_LogActionType WITH(NOLOCK)	---------------------------	TRUNCATE TABLE bodb_Licensee.dbo.OA_Menus	INSERT INTO bodb_Licensee.dbo.OA_Menus(MenuID,MenuName,MenuDesc,ParentID,ParentName,URL,CreatedDate,ModifiedDate,DisplayOrder,Creator,IsActive,FunctionID,Policy)	SELECT MenuID,MenuName,MenuDesc,ParentID,ParentName,URL,CreatedDate,ModifiedDate,DisplayOrder,Creator,IsActive,FunctionID,Policy FROM DBLIC.bodb_Licensee.dbo.OA_Menus WITH(NOLOCK)	---------------------------	TRUNCATE TABLE bodb_Licensee.dbo.OA_UserFunctions	INSERT INTO bodb_Licensee.dbo.OA_UserFunctions(UserID,FunctionID,LicenseeID,ResellerID,Policy)	SELECT UserID,FunctionID,LicenseeID,ResellerID,Policy FROM DBLIC.bodb_Licensee.dbo.OA_UserFunctions WITH(NOLOCK)	---------------------------	TRUNCATE TABLE bodb_Licensee.dbo.OA_UserLicensees	INSERT INTO bodb_Licensee.dbo.OA_UserLicensees(UserID,ResellerID,LicenseeID)	SELECT UserID,ResellerID,LicenseeID FROM DBLIC.bodb_Licensee.dbo.OA_UserLicensees WITH(NOLOCK)	---------------------------	TRUNCATE TABLE bodb_Licensee.dbo.OA_UserLog_Login	SET IDENTITY_INSERT bodb_Licensee.dbo.OA_UserLog_Login ON	INSERT INTO bodb_Licensee.dbo.OA_UserLog_Login(LogID,UserID,IP,LogDate,Doing,DomainName,BrowserName,Platform,CountryCode,Duration)	SELECT LogID,UserID,IP,LogDate,Doing,DomainName,BrowserName,Platform,CountryCode,Duration FROM DBLIC.bodb_Licensee.dbo.OA_UserLog_Login WITH(NOLOCK)	SET IDENTITY_INSERT bodb_Licensee.dbo.OA_UserLog_Login OFF	---------------------------	TRUNCATE TABLE bodb_Licensee.dbo.OA_UserLog_RunSP	SET IDENTITY_INSERT bodb_Licensee.dbo.OA_UserLog_RunSP ON	INSERT INTO bodb_Licensee.dbo.OA_UserLog_RunSP(LogID,UserID,SPName,Doing,LogDate,CustID,ActionID,TrackingValue,Duration,TrackingValue2)	SELECT LogID,UserID,SPName,Doing,LogDate,CustID,ActionID,TrackingValue,Duration,TrackingValue2 FROM DBLIC.bodb_Licensee.dbo.OA_UserLog_RunSP WITH(NOLOCK)	SET IDENTITY_INSERT bodb_Licensee.dbo.OA_UserLog_RunSP OFF	---------------------------	TRUNCATE TABLE bodb_Licensee.dbo.OA_UserResellers	INSERT INTO bodb_Licensee.dbo.OA_UserResellers(UserID,ResellerID)	SELECT UserID,ResellerID FROM DBLIC.bodb_Licensee.dbo.OA_UserResellers WITH(NOLOCK)	---------------------------	TRUNCATE TABLE bodb_Licensee.dbo.OA_Users	SET IDENTITY_INSERT bodb_Licensee.dbo.OA_Users ON	INSERT INTO bodb_Licensee.dbo.OA_Users(UserID,GroupID,Username,UserPwd,DisplayName,UserSalt,IsActive,Creator,CreatedDate,ModifiedDate)	SELECT UserID,GroupID,Username,UserPwd,DisplayName,UserSalt,IsActive,Creator,CreatedDate,ModifiedDate FROM DBLIC.bodb_Licensee.dbo.OA_Users WITH(NOLOCK)	SET IDENTITY_INSERT bodb_Licensee.dbo.OA_Users OFF	---------------------------
END



GO
GRANT VIEW DEFINITION ON [dbo].[Task_Stdby_Sync_Dep_OA] TO [vnteam]
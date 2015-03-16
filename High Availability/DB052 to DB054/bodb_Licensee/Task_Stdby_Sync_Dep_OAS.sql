IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Task_Stdby_Sync_Dep_OAS]') AND type in (N'P', N'PC'))
	DROP PROCEDURE [dbo].[Task_Stdby_Sync_Dep_OAS]
GO

CREATE PROCEDURE [dbo].[Task_Stdby_Sync_Dep_OAS]
AS
/*
Created	: 20140527@Don
Task	: OAS - Sync data 
DB		: DB054.bodb_Licensee

Revisions:
	-20150225@Don: Modified OAS_ChargeInfo
		
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
	TRUNCATE TABLE bodb_Licensee.dbo.OAS_ChargeInfo	SET IDENTITY_INSERT bodb_Licensee.dbo.OAS_ChargeInfo ON	INSERT INTO bodb_Licensee.dbo.OAS_ChargeInfo(ChargeID,ProductID,FromParty,ToParty,ParentChargeID,Rate,ChargeType,FromDate,ToDate,MinAmount,MaxAmount,Remark)	SELECT ChargeID,ProductID,FromParty,ToParty,ParentChargeID,Rate,ChargeType,FromDate,ToDate,MinAmount,MaxAmount,Remark FROM DBLIC.bodb_Licensee.dbo.OAS_ChargeInfo WITH(NOLOCK)	SET IDENTITY_INSERT bodb_Licensee.dbo.OAS_ChargeInfo OFF
	---------------------------
	TRUNCATE TABLE bodb_Licensee.dbo.OAS_LogAction

	INSERT INTO bodb_Licensee.dbo.OAS_LogAction(ActionID,ActionTypeID,SPName,ActionNameEN,ActionNameCH,ActionNameCS,ActionNameJP,ActionNameIT,ActionNameTH,ActionNameKO,XsltContent,IsInternal)
	SELECT ActionID,ActionTypeID,SPName,ActionNameEN,ActionNameCH,ActionNameCS,ActionNameJP,ActionNameIT,ActionNameTH,ActionNameKO,XsltContent,IsInternal FROM DBLIC.bodb_Licensee.dbo.OAS_LogAction WITH(NOLOCK)

	---------------------------
	TRUNCATE TABLE bodb_Licensee.dbo.OAS_LogActionType

	INSERT INTO bodb_Licensee.dbo.OAS_LogActionType(ActionTypeID,ActionTypeNameEN,ActionTypeNameCH,ActionTypeNameCS,ActionTypeNameJP,ActionTypeNameIT,ActionTypeNameTH,ActionTypeNameKO)
	SELECT ActionTypeID,ActionTypeNameEN,ActionTypeNameCH,ActionTypeNameCS,ActionTypeNameJP,ActionTypeNameIT,ActionTypeNameTH,ActionTypeNameKO FROM DBLIC.bodb_Licensee.dbo.OAS_LogActionType WITH(NOLOCK)

	---------------------------
	TRUNCATE TABLE bodb_Licensee.dbo.OAS_Party
	SET IDENTITY_INSERT bodb_Licensee.dbo.OAS_Party ON
	INSERT INTO bodb_Licensee.dbo.OAS_Party(PartyID,PartyName,Description,PartyType,OldRefID)
	SELECT PartyID,PartyName,Description,PartyType,OldRefID FROM DBLIC.bodb_Licensee.dbo.OAS_Party WITH(NOLOCK)
	SET IDENTITY_INSERT bodb_Licensee.dbo.OAS_Party OFF
	---------------------------
	TRUNCATE TABLE bodb_Licensee.dbo.OAS_PartyDetail

	INSERT INTO bodb_Licensee.dbo.OAS_PartyDetail(PartyID,IsDeposit,BrandName,CompanyName,IsAllowedMemberComm)
	SELECT PartyID,IsDeposit,BrandName,CompanyName,IsAllowedMemberComm FROM DBLIC.bodb_Licensee.dbo.OAS_PartyDetail WITH(NOLOCK)

	---------------------------
	TRUNCATE TABLE bodb_Licensee.dbo.OAS_UserLog_Login
	SET IDENTITY_INSERT bodb_Licensee.dbo.OAS_UserLog_Login ON
	INSERT INTO bodb_Licensee.dbo.OAS_UserLog_Login(LogID,UserID,IP,LogDate,Doing,DomainName,BrowserName,Platform,CountryCode,Duration)
	SELECT LogID,UserID,IP,LogDate,Doing,DomainName,BrowserName,Platform,CountryCode,Duration FROM DBLIC.bodb_Licensee.dbo.OAS_UserLog_Login WITH(NOLOCK)
	SET IDENTITY_INSERT bodb_Licensee.dbo.OAS_UserLog_Login OFF
	---------------------------
	TRUNCATE TABLE bodb_Licensee.dbo.OAS_UserLog_RunSP
	SET IDENTITY_INSERT bodb_Licensee.dbo.OAS_UserLog_RunSP ON
	INSERT INTO bodb_Licensee.dbo.OAS_UserLog_RunSP(LogID,UserID,SPName,Doing,LogDate,CustID,ActionID,TrackingValue,Duration,TrackingValue2)
	SELECT LogID,UserID,SPName,Doing,LogDate,CustID,ActionID,TrackingValue,Duration,TrackingValue2 FROM DBLIC.bodb_Licensee.dbo.OAS_UserLog_RunSP WITH(NOLOCK)
	SET IDENTITY_INSERT bodb_Licensee.dbo.OAS_UserLog_RunSP OFF
	---------------------------
	TRUNCATE TABLE bodb_Licensee.dbo.OAS_Users
	SET IDENTITY_INSERT bodb_Licensee.dbo.OAS_Users ON
	INSERT INTO bodb_Licensee.dbo.OAS_Users(UserID,Username,UserPwd,DisplayName,Role,UserSalt,IsActive,Creator,CreatedDate,ModifiedDate,IsTest)
	SELECT UserID,Username,UserPwd,DisplayName,Role,UserSalt,IsActive,Creator,CreatedDate,ModifiedDate,IsTest FROM DBLIC.bodb_Licensee.dbo.OAS_Users WITH(NOLOCK)
	SET IDENTITY_INSERT bodb_Licensee.dbo.OAS_Users OFF
	---------------------------

END



GO
GRANT VIEW DEFINITION ON [dbo].[Task_Stdby_Sync_Dep_OAS] TO [vnteam]
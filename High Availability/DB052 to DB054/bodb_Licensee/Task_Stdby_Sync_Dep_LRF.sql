IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Task_Stdby_Sync_Dep_LRF]') AND type in (N'P', N'PC'))
	DROP PROCEDURE [dbo].[Task_Stdby_Sync_Dep_LRF]
GO

CREATE PROCEDURE [dbo].[Task_Stdby_Sync_Dep_LRF]
AS
/*
Created	: 20140527@Don
Task	: LRF - Sync data 
DB		: DB054.bodb_Licensee

Revisions:
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @ServCurrent SYSNAME
	DECLARE @ServRemote SYSNAME
 
	SELECT @ServCurrent = @@SERVERNAME
	SELECT @ServRemote  = (SELECT sn FROM OPENQUERY(DBLIC,'SELECT @@SERVERNAME sn'))

	IF @@ERROR != 0
		RETURN;

	IF @ServCurrent = @ServRemote
		RETURN;

	/* Sync data - part 1 */
	TRUNCATE TABLE bodb_Licensee.dbo.Functions
	SET IDENTITY_INSERT bodb_Licensee.dbo.Functions ON
	INSERT INTO bodb_Licensee.dbo.Functions(FunctionId,Name,Description,ParentId,Url,IsMenu,IsActive,DisplayOrder,IsNew)
	SELECT FunctionId,Name,Description,ParentId,Url,IsMenu,IsActive,DisplayOrder,IsNew FROM DBLIC.bodb_Licensee.dbo.Functions WITH(NOLOCK)
	SET IDENTITY_INSERT bodb_Licensee.dbo.Functions OFF
	---------------------------
	TRUNCATE TABLE bodb_Licensee.dbo.Labels

	INSERT INTO bodb_Licensee.dbo.Labels(LicenseeID,LabelID,LabelName,AffectedDate,IsKPISummary)
	SELECT LicenseeID,LabelID,LabelName,AffectedDate,IsKPISummary FROM DBLIC.bodb_Licensee.dbo.Labels WITH(NOLOCK)

	---------------------------
	TRUNCATE TABLE bodb_Licensee.dbo.LicenseeBAConfig

	INSERT INTO bodb_Licensee.dbo.LicenseeBAConfig(LicenseeID,[1x2Comm],OtherComm,EnableBA,ModifyBy,ModifyDate,groupa,groupb,groupc,groupd)
	SELECT LicenseeID,[1x2Comm],OtherComm,EnableBA,ModifyBy,ModifyDate,groupa,groupb,groupc,groupd FROM DBLIC.bodb_Licensee.dbo.LicenseeBAConfig WITH(NOLOCK)

	---------------------------
	TRUNCATE TABLE bodb_Licensee.dbo.LicenseeBAHistory
	SET IDENTITY_INSERT bodb_Licensee.dbo.LicenseeBAHistory ON
	INSERT INTO bodb_Licensee.dbo.LicenseeBAHistory(ID,LicenseeID,CustID,OnDate,OffDate,OnBy,OffBy,GroupComm,[1x2Comm],OtherComm,Status,Ugroup)
	SELECT ID,LicenseeID,CustID,OnDate,OffDate,OnBy,OffBy,GroupComm,[1x2Comm],OtherComm,Status,Ugroup FROM DBLIC.bodb_Licensee.dbo.LicenseeBAHistory WITH(NOLOCK)
	SET IDENTITY_INSERT bodb_Licensee.dbo.LicenseeBAHistory OFF
	---------------------------
	TRUNCATE TABLE bodb_Licensee.dbo.LicenseeCurrencyBAGroup

	INSERT INTO bodb_Licensee.dbo.LicenseeCurrencyBAGroup(LicenseeID,Currency,ugroup,ModifyBy,ModifyDate)
	SELECT LicenseeID,Currency,ugroup,ModifyBy,ModifyDate FROM DBLIC.bodb_Licensee.dbo.LicenseeCurrencyBAGroup WITH(NOLOCK)

	---------------------------
	TRUNCATE TABLE bodb_Licensee.dbo.LicenseeCust

	INSERT INTO bodb_Licensee.dbo.LicenseeCust(LicenseeID,CustID,RoleID,Currency,CurrencyName,Description)
	SELECT LicenseeID,CustID,RoleID,Currency,CurrencyName,Description FROM DBLIC.bodb_Licensee.dbo.LicenseeCust WITH(NOLOCK)

	---------------------------
	TRUNCATE TABLE bodb_Licensee.dbo.LicenseeCustComm

	INSERT INTO bodb_Licensee.dbo.LicenseeCustComm(LicenseeID,CustID,SBComm,RacingComm,NGComm,GroupCommID,LCComm,RNGComm)
	SELECT LicenseeID,CustID,SBComm,RacingComm,NGComm,GroupCommID,LCComm,RNGComm FROM DBLIC.bodb_Licensee.dbo.LicenseeCustComm WITH(NOLOCK)

	---------------------------
	TRUNCATE TABLE bodb_Licensee.dbo.LicenseeEventLog

	INSERT INTO bodb_Licensee.dbo.LicenseeEventLog(ObjectID,SystemID,ProductID,ActionID,FromDate,ToDate,AdditionData1,LogDate)
	SELECT ObjectID,SystemID,ProductID,ActionID,FromDate,ToDate,AdditionData1,LogDate FROM DBLIC.bodb_Licensee.dbo.LicenseeEventLog WITH(NOLOCK)

	---------------------------
	TRUNCATE TABLE bodb_Licensee.dbo.LicenseeFunctions
	SET IDENTITY_INSERT bodb_Licensee.dbo.LicenseeFunctions ON
	INSERT INTO bodb_Licensee.dbo.LicenseeFunctions(LicenseeFunctionId,LicenseeId,FunctionId)
	SELECT LicenseeFunctionId,LicenseeId,FunctionId FROM DBLIC.bodb_Licensee.dbo.LicenseeFunctions WITH(NOLOCK)
	SET IDENTITY_INSERT bodb_Licensee.dbo.LicenseeFunctions OFF
	---------------------------
	TRUNCATE TABLE bodb_Licensee.dbo.LicenseeGroupComm
	SET IDENTITY_INSERT bodb_Licensee.dbo.LicenseeGroupComm ON
	INSERT INTO bodb_Licensee.dbo.LicenseeGroupComm(id,Licenseeid,GroupName,IsActive,SBComm,RacingComm,NGComm,color,IsDefault,LCComm,RNGComm)
	SELECT id,Licenseeid,GroupName,IsActive,SBComm,RacingComm,NGComm,color,IsDefault,LCComm,RNGComm FROM DBLIC.bodb_Licensee.dbo.LicenseeGroupComm WITH(NOLOCK)
	SET IDENTITY_INSERT bodb_Licensee.dbo.LicenseeGroupComm OFF
	---------------------------
	TRUNCATE TABLE bodb_Licensee.dbo.LicenseeProduct3rd

	INSERT INTO bodb_Licensee.dbo.LicenseeProduct3rd(LicenseeID,ProductID,Comm,Winloss,EffectiveDate)
	SELECT LicenseeID,ProductID,Comm,Winloss,EffectiveDate FROM DBLIC.bodb_Licensee.dbo.LicenseeProduct3rd WITH(NOLOCK)

	---------------------------
	TRUNCATE TABLE bodb_Licensee.dbo.LicenseeReseller

	INSERT INTO bodb_Licensee.dbo.LicenseeReseller(ResellerID,LicenseeID,TnxRate)
	SELECT ResellerID,LicenseeID,TnxRate FROM DBLIC.bodb_Licensee.dbo.LicenseeReseller WITH(NOLOCK)

	---------------------------
	TRUNCATE TABLE bodb_Licensee.dbo.Licensees

	INSERT INTO bodb_Licensee.dbo.Licensees(LicenseeID,LicenseeName,Description,IsDeposit,AffectedDate,BrandName,CompanyName,IsAllowedMemberComm)
	SELECT LicenseeID,LicenseeName,Description,IsDeposit,AffectedDate,BrandName,CompanyName,IsAllowedMemberComm FROM DBLIC.bodb_Licensee.dbo.Licensees WITH(NOLOCK)

	---------------------------
	TRUNCATE TABLE bodb_Licensee.dbo.LicenseeSpecialCust

	INSERT INTO bodb_Licensee.dbo.LicenseeSpecialCust(Licenseeid,Custid,ugroup,ugroup_old,modifyby,modifydate)
	SELECT Licenseeid,Custid,ugroup,ugroup_old,modifyby,modifydate FROM DBLIC.bodb_Licensee.dbo.LicenseeSpecialCust WITH(NOLOCK)

	---------------------------
	TRUNCATE TABLE bodb_Licensee.dbo.LicenseeUser

	INSERT INTO bodb_Licensee.dbo.LicenseeUser(LicenseeID,UserID,isActive,PageAccess,ModifyDate,ModifyBy)
	SELECT LicenseeID,UserID,isActive,PageAccess,ModifyDate,ModifyBy FROM DBLIC.bodb_Licensee.dbo.LicenseeUser WITH(NOLOCK)

	---------------------------
	TRUNCATE TABLE bodb_Licensee.dbo.LrfDomain

	INSERT INTO bodb_Licensee.dbo.LrfDomain(Id,DomainName,IsActive)
	SELECT Id,DomainName,IsActive FROM DBLIC.bodb_Licensee.dbo.LrfDomain WITH(NOLOCK)

	/* Sync data - part 2 */
	TRUNCATE TABLE bodb_Licensee.dbo.Party
	SET IDENTITY_INSERT bodb_Licensee.dbo.Party ON
	INSERT INTO bodb_Licensee.dbo.Party(ID,PartyName)
	SELECT ID,PartyName FROM DBLIC.bodb_Licensee.dbo.Party WITH(NOLOCK)
	SET IDENTITY_INSERT bodb_Licensee.dbo.Party OFF
	---------------------------
	TRUNCATE TABLE bodb_Licensee.dbo.Product3rd
	SET IDENTITY_INSERT bodb_Licensee.dbo.Product3rd ON
	INSERT INTO bodb_Licensee.dbo.Product3rd(Productid,ProductName,Description,ProductPrefix)
	SELECT Productid,ProductName,Description,ProductPrefix FROM DBLIC.bodb_Licensee.dbo.Product3rd WITH(NOLOCK)
	SET IDENTITY_INSERT bodb_Licensee.dbo.Product3rd OFF
	---------------------------
	TRUNCATE TABLE bodb_Licensee.dbo.ResellerProductChargeByDateRange
	SET IDENTITY_INSERT bodb_Licensee.dbo.ResellerProductChargeByDateRange ON
	INSERT INTO bodb_Licensee.dbo.ResellerProductChargeByDateRange(ID,PartyID,ProductID,ResellerID,FromDate,ToDate,ChargeRate)
	SELECT ID,PartyID,ProductID,ResellerID,FromDate,ToDate,ChargeRate FROM DBLIC.bodb_Licensee.dbo.ResellerProductChargeByDateRange WITH(NOLOCK)
	SET IDENTITY_INSERT bodb_Licensee.dbo.ResellerProductChargeByDateRange OFF
	---------------------------
	TRUNCATE TABLE bodb_Licensee.dbo.Resellers
	SET IDENTITY_INSERT bodb_Licensee.dbo.Resellers ON
	INSERT INTO bodb_Licensee.dbo.Resellers(ResellerID,ResellerName,Description,ResellerType)
	SELECT ResellerID,ResellerName,Description,ResellerType FROM DBLIC.bodb_Licensee.dbo.Resellers WITH(NOLOCK)
	SET IDENTITY_INSERT bodb_Licensee.dbo.Resellers OFF
	---------------------------
	TRUNCATE TABLE bodb_Licensee.dbo.ResellerTransactionRate
	SET IDENTITY_INSERT bodb_Licensee.dbo.ResellerTransactionRate ON
	INSERT INTO bodb_Licensee.dbo.ResellerTransactionRate(ID,ResellerID,MinTrans,MaxTrans,Rate,FromYearMonth,ToYearMonth)
	SELECT ID,ResellerID,MinTrans,MaxTrans,Rate,FromYearMonth,ToYearMonth FROM DBLIC.bodb_Licensee.dbo.ResellerTransactionRate WITH(NOLOCK)
	SET IDENTITY_INSERT bodb_Licensee.dbo.ResellerTransactionRate OFF
	---------------------------
	TRUNCATE TABLE bodb_Licensee.dbo.SystemLicensee

	INSERT INTO bodb_Licensee.dbo.SystemLicensee(SystemID,LicenseeID,IsActive)
	SELECT SystemID,LicenseeID,IsActive FROM DBLIC.bodb_Licensee.dbo.SystemLicensee WITH(NOLOCK)

	---------------------------
	TRUNCATE TABLE bodb_Licensee.dbo.Systems
	SET IDENTITY_INSERT bodb_Licensee.dbo.Systems ON
	INSERT INTO bodb_Licensee.dbo.Systems(id,SystemName,Description)
	SELECT id,SystemName,Description FROM DBLIC.bodb_Licensee.dbo.Systems WITH(NOLOCK)
	SET IDENTITY_INSERT bodb_Licensee.dbo.Systems OFF
	---------------------------
	TRUNCATE TABLE bodb_Licensee.dbo.UserLog_LicenseeBAConfig
	SET IDENTITY_INSERT bodb_Licensee.dbo.UserLog_LicenseeBAConfig ON
	INSERT INTO bodb_Licensee.dbo.UserLog_LicenseeBAConfig(LogID,LicenseeID,[1x2Comm],OtherComm,EnableBA,IP,ActionID,ModifyBy,ModifyDate,groupa,groupb,groupc,groupd)
	SELECT LogID,LicenseeID,[1x2Comm],OtherComm,EnableBA,IP,ActionID,ModifyBy,ModifyDate,groupa,groupb,groupc,groupd FROM DBLIC.bodb_Licensee.dbo.UserLog_LicenseeBAConfig WITH(NOLOCK)
	SET IDENTITY_INSERT bodb_Licensee.dbo.UserLog_LicenseeBAConfig OFF
	---------------------------
	TRUNCATE TABLE bodb_Licensee.dbo.UserLog_LicenseeCurrencyBAGroup
	SET IDENTITY_INSERT bodb_Licensee.dbo.UserLog_LicenseeCurrencyBAGroup ON
	INSERT INTO bodb_Licensee.dbo.UserLog_LicenseeCurrencyBAGroup(LogID,LicenseeID,Currency,ugroup,ModifyBy,ModifyDate,IP)
	SELECT LogID,LicenseeID,Currency,ugroup,ModifyBy,ModifyDate,IP FROM DBLIC.bodb_Licensee.dbo.UserLog_LicenseeCurrencyBAGroup WITH(NOLOCK)
	SET IDENTITY_INSERT bodb_Licensee.dbo.UserLog_LicenseeCurrencyBAGroup OFF
	---------------------------
	TRUNCATE TABLE bodb_Licensee.dbo.UserLog_LicenseeSpecialCust
	SET IDENTITY_INSERT bodb_Licensee.dbo.UserLog_LicenseeSpecialCust ON
	INSERT INTO bodb_Licensee.dbo.UserLog_LicenseeSpecialCust(LogID,LicenseeID,CustID,ugroup,ugroup_old,modifyby,modifydate,IP,ActionType)
	SELECT LogID,LicenseeID,CustID,ugroup,ugroup_old,modifyby,modifydate,IP,ActionType FROM DBLIC.bodb_Licensee.dbo.UserLog_LicenseeSpecialCust WITH(NOLOCK)
	SET IDENTITY_INSERT bodb_Licensee.dbo.UserLog_LicenseeSpecialCust OFF
	---------------------------
	TRUNCATE TABLE bodb_Licensee.dbo.UserLog_Login
	SET IDENTITY_INSERT bodb_Licensee.dbo.UserLog_Login ON
	INSERT INTO bodb_Licensee.dbo.UserLog_Login(LogID,UserID,ServerID,IP,LogDate,ActionID,Doing,DomainName,BrowserName,Platform,CountryCode,Duration)
	SELECT LogID,UserID,ServerID,IP,LogDate,ActionID,Doing,DomainName,BrowserName,Platform,CountryCode,Duration FROM DBLIC.bodb_Licensee.dbo.UserLog_Login WITH(NOLOCK)
	SET IDENTITY_INSERT bodb_Licensee.dbo.UserLog_Login OFF
	---------------------------
	TRUNCATE TABLE bodb_Licensee.dbo.Users
	SET IDENTITY_INSERT bodb_Licensee.dbo.Users ON
	INSERT INTO bodb_Licensee.dbo.Users(UserID,Username,UserPwd,UserSalt,UserRole,FirstName,LastName,Email,Status,Creator,CreateDate,LicenseeName,isInternal)
	SELECT UserID,Username,UserPwd,UserSalt,UserRole,FirstName,LastName,Email,Status,Creator,CreateDate,LicenseeName,isInternal FROM DBLIC.bodb_Licensee.dbo.Users WITH(NOLOCK)
	SET IDENTITY_INSERT bodb_Licensee.dbo.Users OFF
	
	/* Sync data for some tables with large volumes */
	EXEC dbo.Task_Stdby_Sync_Dep_LRF_LicenseeCustinfo

	EXEC dbo.Task_Stdby_Sync_Dep_LRF_CurrencyUser

	EXEC dbo.Task_Stdby_Sync_Dep_LRF_LicenseeUserFunctions

END



GO
GRANT VIEW DEFINITION ON [dbo].[Task_Stdby_Sync_Dep_LRF] TO [vnteam]
/*<info serverAlias="DBLOG-bodb_CustomerLog,DBCUST-bodb_CustomerLog" executers="bodbLicenseeNet,bodbAdminNet,Dot_Member" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[WriteLog_UserLog_UpdMemComm_RunSP]
		@UserID INT,
		@strCustID VARCHAR(MAX) = NULL,
		@ActionID INT = 2612,	
		@LogSPData nvarchar(4000) = NULL,
		@LogSPData2 nvarchar(4000) = NULL,
		@Duration INT = NULL
/*  
	Created: 20140703@Francis
    Task: Write log for updating member's commission using batch by batch method
    DB: DBLOG/bodb_CustomerLog,DBCUST-bodb_CustomerLog

	Revisions:
		- 20171026@Johnson: offer Allbet commision [Redmine: #82036]
		- 20180228@Vicky: Remove LC from product list [Redmine: #85965]
		- 20180809@Amanda: Remove Racing [RedmineID: #99378]
		- 20180924@Elodie: Migrate bodb_Licensee to DBCUST [Redmine:#99855]
		- 20180927@Winnie: Remove AllBet [RedmineID: #99378]
		- 20181029@Lukas: remove linked-server DBcust for performance issue
		- 20200410@Johnson: Add comm for AB,Macau,PP,GD,AG [redmine:#131774] 
		- 20200511@Max: Add comm for FW, Remove AG, GD - [Redmine: #131774]
		- 20200518@Helen: Add comm for FW, Remove AG, GD - Tuning performance - [Redmine: #131774]      
		
    Param's Explaination:    	
		- @UserID: UserId perform this action
		- @@strCustID: A string of individual CustId separated by ","
		- @ActionID: Log action ID
		- @LogSPData: New value of in string
		- @LogSPData2: Common info (IP, ErrCode, ErrMsg) in string 
*/
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
		-- interfering with SELECT statements.
	SET NOCOUNT ON;   

	IF @strCustID IS NOT NULL AND @LogSPData IS NOT NULL AND @LogSPData2 IS NOT NULL
	BEGIN
	
		DECLARE @CustIDTempTable AS TABLE (CustID INT)
		DECLARE @LogTempTable AS TABLE (CustID INT, TrackingValue VARCHAR(MAX), TrackingValue2 VARCHAR(MAX))

		INSERT INTO @CustIDTempTable (CustID)
		SELECT RTRIM(LTRIM(VAL)) 
		FROM dbo.f_SplitString(@strCustID,',')
		OPTION (MAXRECURSION 0)
		
		INSERT INTO @LogTempTable (CustID, TrackingValue, TrackingValue2)
		SELECT a.CustID,
			   '<Lrf_CustomerUpdMemberComm custid="'+ COALESCE(CAST(a.CustID as VARCHAR(50)),SPACE(1)) + '" ' + 
			   @LogSPData +  
			   'UserID="'+ COALESCE(CAST(@UserID as VARCHAR(50)),SPACE(1)) + '" ' +
			   @LogSPData2 AS TrackingValue,
			   '<Lrf_CustomerUpdMemberComm custid="'+ COALESCE(CAST(a.CustID as VARCHAR(50)),SPACE(1)) + '" ' +
			   'GroupCommID="'+ COALESCE(CAST(ISNULL(lcc.GroupCommID,0) as VARCHAR(50)),SPACE(1)) + '" ' +
			   'LicenseeID="'+ COALESCE(CAST(ISNULL(lcc.LicenseeID,0) as VARCHAR(50)),SPACE(1)) + '" ' +
			   'SBComm="'+ COALESCE(CAST(ISNULL(lcc.SBComm,0) as VARCHAR(50)),SPACE(1)) + '" ' +
			   'ParlayComm="'+ COALESCE(CAST(ISNULL(lcc.ParlayComm,0) as VARCHAR(50)),SPACE(1)) + '" ' +
			   'NGComm="'+ COALESCE(CAST(ISNULL(lcc.NGComm,0) as VARCHAR(50)),SPACE(1)) + '" ' +
			   --'LCComm="'+ COALESCE(CAST(ISNULL(lcc.LCComm,0) as VARCHAR(50)),SPACE(1)) + '" ' +
			   'RNGComm="'+ COALESCE(CAST(ISNULL(lcc.RNGComm,0) as VARCHAR(50)),SPACE(1)) + '" ' +			 
			   'AllbetComm="'+ COALESCE(CAST(ISNULL(lcc.AllbetComm,0) as VARCHAR(50)),SPACE(1)) + '" ' +
			   'MacauComm="'+ COALESCE(CAST(ISNULL(lcc.MacauComm,0) as VARCHAR(50)),SPACE(1)) + '" ' +
			   'PPComm="'+ COALESCE(CAST(ISNULL(lcc.PPComm,0) as VARCHAR(50)),SPACE(1)) + '" ' +
			   --'GDComm="'+ COALESCE(CAST(ISNULL(lcc.GDComm,0) as VARCHAR(50)),SPACE(1)) + '" ' +
			   --'AGComm="'+ COALESCE(CAST(ISNULL(lcc.AGComm,0) as VARCHAR(50)),SPACE(1)) + '" ' +
			   'FWComm="'+ COALESCE(CAST(ISNULL(lcc.FWComm,0) as VARCHAR(50)),SPACE(1)) + '" ' +
			   'UserID="'+ COALESCE(CAST(@UserID as VARCHAR(50)),SPACE(1)) + '" ' +
			   @LogSPData2 AS TrackingValue2
		FROM @CustIDTempTable a
			LEFT JOIN bodb_licensee.dbo.LicenseeCustComm lcc WITH (NOLOCK) ON a.CustID = lcc.CustID
			
		INSERT INTO dbo.UserLog_RunSP (UserID, CustID, SPName, Doing, ActionID, TrackingValue, TrackingValue2, Duration)
		SELECT @UserID, CustID, NULL, NULL, @ActionID, TrackingValue, TrackingValue2, @Duration
		FROM @LogTempTable					  
	END
END
GO


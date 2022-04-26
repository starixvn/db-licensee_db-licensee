/*<info serverAlias="DBLOG-bodb_CustomerLog,DBCUST-bodb_CustomerLog" executers="bodbLicenseeNet,bodbAdminNet,Dot_Member" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[WriteLog_UserLog_UpdMemComm_RunSP]
(
	@UserID INT,
	@strCustID VARCHAR(MAX) = NULL,
	@ActionID INT = 2612,	
	@LogSPData nvarchar(4000) = NULL, -- new value
	@LogSPData2 nvarchar(4000) = NULL, -- old value
	@Duration INT = NULL
)	
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
		- 20200701@Helen: Remove Allbet - [Redmine: #131774] 
		- 20200814@Helen: LAP - Offer commission to 3rd party products - Phase 2 - [Redmine: #139238] 
		- 20201111@Helen: LAP - Offer commission to 3rd party products - Phase 3 - [Redmine: #145012] 
		- 20210603@Eden: LAP - Support commission for 3rd party products - Phase 4 [Redmine: #154048]   
		- 20211101@Winfred: Merge Sports Lottery under Sportsbook when turn on BA [redmine:#163191]
		- 20220422@Winfred: LAP - Support commission for 3rd party products - Phase 4.2 [Redmine: #171586]   
		
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
		SELECT VAL
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
			   -- phase 2
				'SexyGamingComm="'+ COALESCE(CAST(ISNULL(lcc.SexyGamingComm,0) as VARCHAR(50)),SPACE(1)) + '" ' +
				'SpadeGamingComm="'+ COALESCE(CAST(ISNULL(lcc.SpadeGamingComm,0) as VARCHAR(50)),SPACE(1)) + '" ' +
				'KenoComm="'+ COALESCE(CAST(ISNULL(lcc.KenoComm,0) as VARCHAR(50)),SPACE(1)) + '" ' +
				'LotteryComm="'+ COALESCE(CAST(ISNULL(lcc.LotteryComm,0) as VARCHAR(50)),SPACE(1)) + '" ' +
				'VSComm="'+ COALESCE(CAST(ISNULL(lcc.VSComm,0) as VARCHAR(50)),SPACE(1)) + '" ' +
				'VS2Comm="'+ COALESCE(CAST(ISNULL(lcc.VS2Comm,0) as VARCHAR(50)),SPACE(1)) + '" ' +
				'TableGameComm="'+ COALESCE(CAST(ISNULL(lcc.TableGameComm,0) as VARCHAR(50)),SPACE(1)) + '" ' +
				--phase 3
				'VirtualGamesComm="'+ COALESCE(CAST(ISNULL(lcc.VirtualGamesComm,0) as VARCHAR(50)),SPACE(1)) + '" ' +
				'ArcadiaGamingComm="'+ COALESCE(CAST(ISNULL(lcc.ArcadiaGamingComm,0) as VARCHAR(50)),SPACE(1)) + '" ' +
				'SabaclubComm="'+ COALESCE(CAST(ISNULL(lcc.SabaclubComm,0) as VARCHAR(50)),SPACE(1)) + '" ' +
				'SAGamingComm="'+ COALESCE(CAST(ISNULL(lcc.SAGamingComm,0) as VARCHAR(50)),SPACE(1)) + '" ' +
				'PGSoftComm="'+ COALESCE(CAST(ISNULL(lcc.PGSoftComm,0) as VARCHAR(50)),SPACE(1)) + '" ' +
				-- phase 4
				'WMCasinoComm="'+ COALESCE(CAST(ISNULL(lcc.WMCasinoComm,0) as VARCHAR(50)),SPACE(1)) + '" '+
				'BigGamingComm="'+ COALESCE(CAST(ISNULL(lcc.BigGamingComm,0) as VARCHAR(50)),SPACE(1)) + '" '+
				'JokerComm="'+ COALESCE(CAST(ISNULL(lcc.JokerComm,0) as VARCHAR(50)),SPACE(1)) + '" '+
				'GDGComm="'+ COALESCE(CAST(ISNULL(lcc.GDGComm,0) as VARCHAR(50)),SPACE(1)) + '" '+
				'HabaneroComm="'+ COALESCE(CAST(ISNULL(lcc.HabaneroComm,0) as VARCHAR(50)),SPACE(1)) + '" '+
				-- phase 4.2
				'CGComm="'+ COALESCE(CAST(ISNULL(lcc.CGComm,0) as VARCHAR(50)),SPACE(1)) + '" '+
				'AdvantComm="'+ COALESCE(CAST(ISNULL(lcc.AdvantComm,0) as VARCHAR(50)),SPACE(1)) + '" '+
				'AdvantMiniComm="'+ COALESCE(CAST(ISNULL(lcc.AdvantMiniComm,0) as VARCHAR(50)),SPACE(1)) + '" '+
				'VS3Comm="'+ COALESCE(CAST(ISNULL(lcc.VS3Comm,0) as VARCHAR(50)),SPACE(1)) + '" '+

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

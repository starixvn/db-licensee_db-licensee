/*<info serverAlias="DBLOG-bodb_CustomerLog,DBCUST-bodb_CustomerLog" executers="bodbLicenseeNet,bodbAdminNet,Dot_Member" isNested="1" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[WriteLog_UserLog_UpdMemComm_RunSP]
(
	@Log xml = NULL	
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
		- 20220614@Elodie: DBCUST - modify sp syntax to adapt with the SQL Server upgrade to 2019 [Redmine: #171831] 
		- 20230412@Tacy: Non-sports products - Remove GDG and Fishing World [RedmineID: #174511]
		- 20230313@Johnson: Add MaxGame, FGG, Jili Comm [redmine:#182922]
		- 20230426@Johnson: missing version PRO [redmine:#182922]
		- 20230804@Tacy: LAP - Offer Player Commission to Yeebet, MG-RNG [redmine: #192203]
		- 20240111@Tacy: LAP - Merge VS1, VS2, VS3 as Virtual Sports [Redmine: #199523]
		- 20240322@Johnson: Restructure Commission [redmine:#179088]
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
	
	DECLARE @handle INT
	
	DECLARE @tmpLog TABLE(UserID  INT,  
						  CustID INT,						 
						  TrackingValue VARCHAR(MAX),
						  TrackingValue2 VARCHAR(MAX),
						  ActionID INT,
						  Duration INT,
						  logdate DATETIME,
						  Isfinished BIT
						  )
		
	DECLARE @tmpLog_batch TABLE(UserID  INT,  
						  CustID INT,						 
						  TrackingValue VARCHAR(MAX),
						  TrackingValue2 VARCHAR(MAX),
						  ActionID INT,
						  Duration INT,
						  logdate DATETIME
						  )					  
		
	EXECUTE sys.sp_xml_preparedocument @handle OUTPUT, @log
	
	INSERT INTO @tmpLog	(UserID, CustID, ActionID, TrackingValue, TrackingValue2, Duration,LogDate)
	SELECT UserID, CustID,  ActionID, TrackingValue, TrackingValue2, Duration, LogDate	
	FROM OPENXML(@handle,'/Root/Row',1) 
			WITH (UserID  int,  
				  CustID int,
				  ActionID INT,
				  TrackingValue NVARCHAR(MAX),
				  TrackingValue2 NVARCHAR(MAX),
				  Duration INT,
				  LogDate DATETIME
				  ); 
			  
	EXEC sp_xml_removedocument @handle; 
	
	WHILE (1=1)
	BEGIN	
		DELETE @tmpLog_batch
		
		UPDATE TOP (2000) t
			SET Isfinished = 1
		OUTPUT deleted.UserID, deleted.CustID,  deleted.ActionID, deleted.TrackingValue, deleted.TrackingValue2, deleted.Duration, deleted.LogDate
		INTO @tmpLog_batch(UserID, CustID, ActionID, TrackingValue, TrackingValue2, Duration,LogDate)	
		FROM @tmpLog t
		WHERE t.Isfinished IS NULL

		IF @@ROWCOUNT = 0 BREAK
		
		INSERT INTO dbo.UserLog_RunSP (UserID, CustID, SPName, Doing, ActionID, TrackingValue, TrackingValue2, Duration,LogDate,CreatedDate)
		SELECT UserID, CustID, NULL, NULL, ActionID, TrackingValue, TrackingValue2, Duration,LogDate,GETDATE()
		FROM @tmpLog_batch
		
		WAITFOR DELAY '00:00:0.100'
		
	END				
END

GO

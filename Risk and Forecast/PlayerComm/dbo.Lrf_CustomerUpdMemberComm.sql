/*<info serverAlias="DBCUST-bodb_Licensee" executers="wsv_lap,wsv_nap,svc_tig" viewers="" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE [dbo].[Lrf_CustomerUpdMemberComm]
(
	@LicenseeID INT,
	@strCustID VARCHAR(MAX) = '',--member
	@UserID INT,
	@GroupDiscountID INT = 0,	
	@DiscountSettings VARCHAR(MAX) = '',
	@isClearGroupDiscount BIT = 0,
	@ClearGroupDiscountGroupID INT = 0,
	@IsUpdateDiscount BIT=1,
	@IsUpdateGroupDiscount BIT=1,
	@IP VARCHAR(40),
	@Langkey VARCHAR(10) = 'en-US',
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg NVARCHAR(4000) = '' OUTPUT
)
AS
/*
	Created: 20120726@Henry
	Task : Update Commission of Player
	DB: DBCUST/bodb_licensee

	Revisions:
		- 20130124@Daniel: Change link server alias & failover writelog to DBTXN 
		- 20130413@Jim: support multi language
		- 20131023@Hannah: offer Live Casino commission
		- 20131126@Hannah: offer RNG Casino commission
		- 20131226@winnie: Change to DBTXN.CustDB
		- 20140612@Victor: fix VARCHAR(4000) issue
		- 20140618@Francis: Enhance performance
		- 20140618@Francis: Update Comm info and write logs using batch by batch in stead of row by row method
		- 20150513@Jim: force BA member get SB comm zero
		- 20151005@Jim:HotFix #45031
		- 20160805@Jim: LRF - Offer different member commission for parlay tickets [RedmineID:#61897]	
		- 20171017@Johnson: offer Allbet commision [Redmine: #82036]
		- 20180228@Vicky: Remove LC from product list [Redmine: #85965]
		- 20180704@Winnie:  LAP - There is a locking DB resource when doing 1st deposit many sessions at same time [Redmine: #97829]
		- 20180809@Sophia: HA - remove LicenseeCustInfo table [Redmine: #99464]
		- 20180809@Amanda: Remove Racing [RedmineID: #99378]
		- 20180827@Elodie: Change to use DBCUST.CustDB.dbo.Customer [Redmine: #99464]
		- 20180927@Winnie: Remove AllBet [RedmineID: #99378]
		- 20180924@Elodie: Migrate bodb_Licensee to DBCUST [Redmine:#99855]
		- 20181205@Winnie: LAP-Security Risks found_settings [RedmineID: #105701]
		- 20200409@Johnson: Add comm for AB,Macau,PP,GD,AG [redmine:#131774]
		- 20200416@Max: Move Code Update LicenseeCustComm to Execrep SP [Redmine: #131774]
		- 20200511@Max: Add comm for FW, Remove AG, GD - [Redmine: #131774]
		- 20200518@Helen: Add comm for FW, Remove AG, GD - Tuning performance - [Redmine: #131774]
		- 20200701@Helen: Remove Allbet - [Redmine: #131774]
		- 20200814@Helen: LAP - Offer commission to 3rd party products - Phase 2 - [Redmine: #139238] 
		- 20201111@Helen: LAP - Offer commission to 3rd party products - Phase 3 - [Redmine: #145012] 
		- 20210603@Eden: LAP - Support commission for 3rd party products - Phase 4 [Redmine: #154048]   
		- 20210813@Johnson: Add VGaming [redmine: #159696]
		- 20211101@Winfred: Merge Sports Lottery under Sportsbook when turn on BA [redmine:#163191]
		- 20220112@Eden: LAP - RNG Casino - Implement DCS Settings [Redmine: #166217] 
		- 20220422@Winfred: LAP - Support commission for 3rd party products - Phase 4.2 [Redmine: #171586] 
		- 20220614@Eden: DBCUST - modify sp syntax to adapt with the SQL Server upgrade to 2019 [Redmine: #171831] 
		- 20221201@Tacy: Non-sports products - Remove GDG and Fishing World [RedmineID: #174511]
		- 20230313@Johnson: Add MaxGame, FGG, Jili Comm [redmine:#182922]
		- 20230804@Tacy: LAP - Offer Player Commission to Yeebet, MG-RNG [redmine: #192203]
		- 20230814@Luke: LAP - SEA Localization [Redmine: #187132]
		- 20240111@Tacy: LAP - Merge VS1, VS2, VS3 as Virtual Sports [Redmine: #199523]
		- 20240220@Johnson: Restructure Commission [redmine:#179088]
	Param's Explanation:
		1. To update a member/batch members without GroupCommID
EXEC [Lrf_CustomerUpdMemberComm_907] @LicenseeID=xx,@strCustID,xx,@UserID=xx,@SBComm=xx,@NGComm=xx,@RNGComm=xx, @IsUpdateNG=xx,@IsUpdateRNG=xx,@IP=xx,@ErrCode=@ErrCode OUTPUT,@ErrMsg=@ErrMsg OUTPUT
		2. To update a member/batch members with GroupCommID
EXEC [Lrf_CustomerUpdMemberComm_907] @LicenseeID=xx,@strCustID,xx,@UserID=xx,@GroupDiscountID=xx,@SBComm=xx,@NGComm=xx,@RNGComm=xx,@IsUpdateNG=xx,@IsUpdateRNG=xx,@IP=xx,@ErrCode=@ErrCode OUTPUT,@ErrMsg=@ErrMsg OUTPUT
		3. To update member group without update commission
EXEC [Lrf_CustomerUpdMemberComm_907] @IsUpdateDiscount=0,@LicenseeID=xx,@strCustID,xx,@UserID=xx,@GroupDiscountID=xx,@SBComm=xx,@NGComm=xx,@RNGComm=xx,@IsUpdateNG=xx,@IsUpdateRNG=xx,@IP=xx,@ErrCode=@ErrCode OUTPUT,@ErrMsg=@ErrMsg OUTPUT
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @startRun DATETIME
	DECLARE @endRun DATETIME
	DECLARE @duration INT
	DECLARE	@GroupDiscountID_tmp INT
	DECLARE @CustID_Direct INT

	SET @startRun = GETDATE()

	DECLARE @TotalMemCount INT

	DECLARE @LogSPData VARCHAR(4000)
	DECLARE @LogSPData2 VARCHAR(4000)
	DECLARE @MacauLicenseeID INT
	
	DECLARE @tblSettings TABLE(SportType SMALLINT, BetType SMALLINT, Discount DECIMAL(9,8), Discount_Old DECIMAL(9,8))
	CREATE TABLE #Dep_CustSetting(CustID INT, SportType SMALLINT, BetType SMALLINT, Discount DECIMAL(9,8)
								PRIMARY KEY (CustID,SportType,BetType)
								)
	
	DECLARE @xmlDiscountSettings XML
	
	SELECT @xmlDiscountSettings = CAST(@DiscountSettings as XML)
	
	INSERT INTO @tblSettings (SportType,BetType,Discount)
	SELECT t.c.value('@SportType[1]','smallint'),
		t.c.value('@BetType[1]','smallint'),
		ISNULL(t.c.value('@Discount[1]','DECIMAL(9,8)'),0)
	FROM @xmlDiscountSettings.nodes('/Root/r') as T(c)
		
	SELECT  @MacauLicenseeID =  LicenseeID
	FROM dbo.Licensees WITH (NOLOCK)
	WHERE LicenseeName ='Macaubet'
		
	SELECT @strCustID = ltrim(rtrim(@strCustID))

	IF @strCustID = '' AND @IsUpdateGroupDiscount = 0
	BEGIN
		SELECT @ErrCode=101
		SELECT @ErrMsg = CASE @Langkey WHEN 'en-US'THEN 'Wrong input, please check again!'
										ELSE  CustDB.[dbo].[Lrf_f_Get_MsgNamebyMsgID](200003,@Langkey)
						END 	
		RETURN
	END

	IF @GroupDiscountID>0 --Get SBComm,NGComm,RNGComm From Group
	BEGIN
		--Check existence
		IF NOT EXISTS (SELECT 1 FROM dbo.LicenseeGroupDiscount WITH (NOLOCK) WHERE LicenseeID = @LicenseeID AND GroupDiscountID = @GroupDiscountID AND IsActive=1)
		BEGIN
			SELECT @ErrCode=101
			SELECT @ErrMsg = CASE @Langkey WHEN 'en-US' THEN  'The Group Commission does not exist, please check again!'
										   ELSE CustDB.[dbo].[Lrf_f_Get_MsgNamebyMsgID](200001,@Langkey)		
										   END
			RETURN
		END
	
		UPDATE t
		SET t.Discount = ISNULL(g.Discount,0)
		FROM LicenseeGroupDiscountDetail g WITH(NOLOCK)
			INNER JOIN @tblSettings t ON g.SportType = t.SportType
										AND g.Bettype = t.Bettype
		WHERE LicenseeID = @LicenseeID 
			AND GroupDiscountID = @GroupDiscountID 			
	END

	--Validate data
	IF EXISTS (SELECT 1 FROM @tblSettings WHERE Discount > 0.15)	
	BEGIN
		SELECT @ErrCode=101
		SELECT @ErrMsg = CASE @Langkey WHEN 'en-US' THEN 'Player commission should not be greater than'
										ELSE 	CustDB.[dbo].[Lrf_f_Get_MsgNamebyMsgID](200002,@Langkey)
										END +' 0.15'
		RETURN
	END
	
	DECLARE @TempLicenseeBA AS TABLE (CustID INT)
	
	DECLARE @TempCustID AS TABLE (CustID INT, AgentID INT, IsGroupedComm BIT, IsFinished BIT)
	DECLARE @TempList_batch AS TABLE (CustID INT, AgentID INT, IsGroupedComm BIT)
	
	IF @isClearGroupDiscount = 1
		SET @GroupDiscountID_tmp = @ClearGroupDiscountGroupID
	ELSE
		SET @GroupDiscountID_tmp = @GroupDiscountID
			
	IF @IsUpdateGroupDiscount = 1 AND @strCustID = ''
	BEGIN
		INSERT INTO @TempCustID (CustID,AgentID)
		SELECT ls.custid, c.recommend
		FROM LicenseeCustDiscount ls WITH (NOLOCK)
			INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON ls.CustID = c.custid
		WHERE ls.LicenseeID = @LicenseeID AND ls.GroupDiscountID = @GroupDiscountID_tmp
		
		SELECT @TotalMemCount=@@ROWCOUNT
		
	END
	ELSE IF @strCustID <> ''
	BEGIN
		INSERT INTO @TempCustID (CustID,AgentID)
		SELECT c.CustID, c.recommend
		FROM CustDB.dbo.Customer c WITH (NOLOCK) 
			INNER JOIN STRING_SPLIT (@strCustID,',') AS tmp ON RTRIM(LTRIM(tmp.value)) = c.custid
		
		SELECT @TotalMemCount=@@ROWCOUNT
		
	END
	
	UPDATE t
	SET t.IsGroupedComm = csm.IsGroupedComm
	FROM CustDB.dbo.Dep_CustSettingMode csm WITH(NOLOCK)
		INNER JOIN @TempCustID t ON csm.CustID = t.custid
	
	INSERT INTO #Dep_CustSetting(CustID,SportType,BetType,Discount)
	SELECT CustID, cs.SportType,cs.BetType,cs.PlayerDiscount
	FROM CustDB.dbo.Dep_CustDiscountSetting_Member cs (NOLOCK)
		INNER JOIN @tblSettings t ON t.SportType = cs.SportType
									AND t.Bettype = cs.Bettype
	WHERE custid IN (SELECT r.custid
					FROM @TempCustID r
					WHERE isGroupedComm = 0
				)
	
	SELECT @DiscountSettings = CAST((SELECT SportType,BetType,Discount
									FROM @tblSettings
									FOR XML RAW('r'), ROOT('Root')		
									) AS VARCHAR(MAX))
	
	--Call execrep to update player commission
	IF @IsUpdateDiscount=1
	BEGIN
		IF @TotalMemCount=1
		BEGIN
			SET @CustID_Direct =  (SELECT TOP 1 CustID FROM @TempCustID)
			
			EXEC CustDB.dbo.[Lrf_CustomerUpdMemberComm_Direct] 
				@CustID=@CustID_Direct,
				@DiscountSettings = @DiscountSettings
		END		
		ELSE
		BEGIN	
			--- separate BA member with Non-BA
			--BA and not belong Macaubet have got SBcomm=0	
			
			DECLARE @strBA 	VARCHAR(MAX)
			
			IF @LicenseeID <> @MacauLicenseeID
			BEGIN 
				INSERT INTO @TempLicenseeBA (CustID)
				SELECT t.CustID 
				FROM @TempCustID  t
					INNER JOIN dbo.LicenseeBAHistory ba WITH (NOLOCK) ON t.CustID=ba.CustID
				WHERE ba.Status ='Running' AND ba.LicenseeID = @LicenseeID 
				ORDER BY t.[CustID]
			END	 
				 
			SELECT @strBA = STUFF((SELECT ',' + CAST(CustID AS VARCHAR(20))
							FROM @TempLicenseeBA
							FOR XML PATH('')
							),1,1,'')
			IF @strBA  <> ''
			BEGIN				
				SELECT @DiscountSettings = CAST((SELECT SportType,BetType,
												CASE WHEN SportType = 1 THEN 0 ELSE Discount END Discount
									FROM @tblSettings
									FOR XML RAW('r'), ROOT('Root')		
									) AS VARCHAR(MAX))
									
				EXEC CustDB.dbo.[Lrf_CustomerUpdMemberComm_Main] 
					@strCustID=@strBA,
					@DiscountSettings = @DiscountSettings
					
			END					
			-- Non-BA and BA under Macaubet have got SBcomm=@SBcomm
			DECLARE  @strNonBA 	VARCHAR(MAX)
			
			SELECT @strNonBA = STUFF((SELECT ',' + CAST(t.[CustID] AS VARCHAR(20))
								FROM @TempCustID  t
									LEFT JOIN @TempLicenseeBA ba ON t.CustID = ba.CustID
								WHERE ba.CustID IS NULL
								ORDER BY t.[CustID]
								FOR XML PATH('')
							),1,1,'')
			
			IF @strNonBA  <> ''
			BEGIN
				SELECT @DiscountSettings = CAST((SELECT SportType,BetType,Discount
									FROM @tblSettings
									FOR XML RAW('r'), ROOT('Root')		
									) AS VARCHAR(MAX))
									
				EXEC CustDB.dbo.[Lrf_CustomerUpdMemberComm_Main] 
					@strCustID=@strNonBA,
					@DiscountSettings = @DiscountSettings					
			END
		END
	END	
	
	SET @endRun = GETDATE()
	SET @duration  = DATEDIFF (millisecond,@startRun,@endRun)	

	--Write Log
	-- new value
	SELECT @LogSPData = 'GroupDiscountID="'+ COALESCE(CAST(@GroupDiscountID as VARCHAR(50)),SPACE(1)) + '" ' +
		'LicenseeID="'+ COALESCE(CAST(@LicenseeID as VARCHAR(50)),SPACE(1)) + '" ' + 		 
		'IP="'+ COALESCE(CAST(@IP as VARCHAR(40)),SPACE(1)) + '" ' +
		'ErrCode="'+ COALESCE(CAST(@ErrCode as VARCHAR(50)),SPACE(1)) + '" ' +
		'ErrMsg="'+ COALESCE(CAST(@ErrMsg as VARCHAR(8000)),SPACE(1))+ '">'
	
	DECLARE @runningCNT INT = 0
	WHILE (1=1)
	BEGIN
		SELECT @runningCNT = @runningCNT + 1

		DELETE FROM @TempList_batch
		
		UPDATE TOP (1000) t
			SET IsFinished = 1
		OUTPUT deleted.CustID, deleted.AgentID, deleted.IsGroupedComm
		INTO @TempList_batch (custID,AgentID,IsGroupedComm)
		FROM @TempCustID t
		WHERE IsFinished IS NULL
		
		--Check empty batches
		IF (@@ROWCOUNT = 0)
			BREAK

		SET @strCustID = STUFF((SELECT ',' + CAST(custid AS VARCHAR(20))
						FROM @TempList_batch
						FOR XML PATH('')
						),1,1,'')
		---------- write log for servicebroker
		DECLARE @log xml, @SB_Error BIT = 0, @currentdate DATETIME = GETDATE ()
		
		;WITH T AS (
			SELECT a.CustID
				,CAST((SELECT SportType,BetType,Discount
										FROM @tblSettings
										ORDER BY SportType,BetType
										FOR XML RAW('r')		
										) AS VARCHAR(MAX)) AS TrackingValue
				,CAST((SELECT SportType,BetType,Discount
						FROM #Dep_CustSetting
						WHERE custid = a.custid
						FOR XML RAW('r')		
						) AS VARCHAR(MAX)) AS TrackingValue2
			FROM @TempList_batch a
			WHERE a.IsGroupedComm = 0
			UNION ALL
			SELECT a.CustID
				,CAST((SELECT SportType,BetType,Discount
						FROM @tblSettings
						ORDER BY SportType,BetType
						FOR XML RAW('r')		
						) AS VARCHAR(MAX)) AS TrackingValue
				,CAST((SELECT SportType,BetType,Discount
						FROM CustDB.dbo.Dep_CustDiscountGroupSetting_Member (NOLOCK)
						WHERE AgentID = a.AgentID									
						FOR XML RAW('r')		
						) AS VARCHAR(MAX)) AS TrackingValue2
			FROM @TempList_batch a
			WHERE a.IsGroupedComm = 1
		)
		SELECT @log = (
					SELECT CustID AS '@CustID'
							, @UserID AS	'@UserID'	
							, 2612 '@ActionID'
							, '<Lrf_CustomerUpdMemberComm custid="'+ COALESCE(CAST(CustID as VARCHAR(50)),SPACE(1)) + '" ' + 
							@LogSPData + 
							TrackingValue + 		
						    '</Lrf_CustomerUpdMemberComm>' AS '@TrackingValue'
							
							,'<Lrf_CustomerUpdMemberComm custid="'+ COALESCE(CAST(CustID as VARCHAR(50)),SPACE(1)) + '" ' + 
							@LogSPData + 
							TrackingValue2 + 		
						    '</Lrf_CustomerUpdMemberComm>' AS '@TrackingValue2'							
							,@currentdate AS '@LogDate'
						    ,@duration AS '@Duration'							
					FROM T 					
					FOR XML PATH('Row'), ROOT('Root')	
					)
	
		EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @log, 
													@MessageType='MessageType_CustomerLog_UserLog_RunSP', 
													@functionName = 'UserLog_Others',
													@SB_Error = @SB_Error OUT


		--SELECT @SB_Error
		IF @SB_Error = 1
		BEGIN
			BEGIN TRY
			
				EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_UpdMemComm_RunSP
						@Log = @Log
			END TRY
			BEGIN CATCH
				EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_UpdMemComm_RunSP
						@Log = @Log
			END CATCH
		END
		
		--Update LicenseeCustDiscount
		IF (@IsUpdateDiscount = 1)
		BEGIN
			BEGIN TRY
			
			EXEC dbo.Lrf_ExecRep_00
					@strCustId = @strCustID,
					@LicenseeID = @LicenseeID,
					@GroupDiscountID = @GroupDiscountID,
					@IsUpdateGroupDiscount = @IsUpdateGroupDiscount					
			END TRY
			BEGIN CATCH
				SELECT @ErrCode = ERROR_NUMBER()
					, @ErrMsg = ERROR_MESSAGE()
			END CATCH
			
		END
		IF @runningCNT % 5 = 0 
			WAITFOR DELAY '00:00:00.280'

	END	
END

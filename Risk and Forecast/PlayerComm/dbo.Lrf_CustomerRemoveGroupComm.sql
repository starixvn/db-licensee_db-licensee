/*<info serverAlias="DBCUST-bodb_Licensee" executers="wsv_lap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_CustomerRemoveGroupComm]
	@LicenseeID INT,
	@strCustIDOriginal VARCHAR(MAX),--member
	@strCustID VARCHAR(MAX) OUTPUT,--member
	@UserID INT,
	@IP varchar(40),
	@IsRemovePlayercomm BIT,
	@Langkey VARCHAR(10) = 'en-US',
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg NVARCHAR(4000) = '' OUTPUT
AS  
/*  
	Created: 20120801@Henry
	Task : Remove Group Comm
	DB: DBCUST/bodb_Licensee  
   
	Revisions:     
		- 20130413@Jim: support multi langueges
		- 20131025@Hannah: offer Live Casino commission
		- 20131126@Hannah: offer RNG Casino commission
		- 20140115@Hannah: separate @strCustID INPUT and OUTPUT parameter
		- 20140612@Victor: fix VARCHAR(4000) issue
		- 20160805@Jim: LRF - Offer different member commission for parlay tickets [RedmineID:#61897]
		- 20171024@Johnson: offer Allbet commision [Redmine: #82036]
		- 20180228@Vicky: Remove LC from product list [Redmine: #85965]
		- 20180809@Amanda: Remove Racing [RedmineID: #99378]
		- 20180924@Elodie: Migrate bodb_Licensee to DBCUST [Redmine:#99855]
		- 20180924@Winnie: Remove Allbet [RedmineID: #99378]
		- 20200409@Johnson: Add comm for AB,Macau,PP,AG,GD [redmine:#131774] 
		- 20200511@Max: Add comm for FW, Remove AG, GD - [Redmine: #131774]
		- 20200701@Helen: Remove Allbet - [Redmine: #131774]
		- 20200814@Helen: LAP - Offer commission to 3rd party products - Phase 2 - [Redmine: #139238] 
		- 20201111@Helen: LAP - Offer commission to 3rd party products - Phase 3 - [Redmine: #145012]   
		- 20210603@Eden: LAP - Support commission for 3rd party products - Phase 4 [Redmine: #154048] 
		- 20210817@Johnson: Add VGaming [redmine: #159696] 
		- 20211101@Winfred: Merge Sports Lottery under Sportsbook when turn on BA [redmine:#163191]
		- 20220112@Eden: LAP - RNG Casino - Implement DCS Settings [Redmine: #166217] 
		- 20220422@Winfred: LAP - Support commission for 3rd party products - Phase 4.2 [Redmine: #171586] 
		- 20220614@Eden: DBCUST - modify sp syntax to adapt with the SQL Server upgrade to 2019 [Redmine: #171831] 
		- 20221201@Tacy: Non-sports products - Remove GDG and Fishing World [RedmineID: #174511]
		- 20230315@Johnson: Add MaxGame, FGG, Jili Comm [redmine:#182922]
		- 20230804@Tacy: LAP - Offer Player Commission to Yeebet, MG-RNG [redmine: #192203]
		- 20240111@Tacy: LAP - Merge VS1, VS2, VS3 as Virtual Sports [Redmine: #199523]
		- 20240329@Johnson: Restructure Commission [redmine:#179088]
*/  
BEGIN  
	SET NOCOUNT ON
	
	DECLARE @SBComm DECIMAL(9,8), 
			@NGComm DECIMAL(9,8),
			@RNGComm DECIMAL(9,8),
			@ParlayComm DECIMAL(9,8),
			@AllbetComm DECIMAL(9,8),
			@MacauComm DECIMAL(9,8),
			@PPComm DECIMAL(9,8),
			--phase 2
			@SexyGamingComm DECIMAL(9,8),
			@SpadeGamingComm DECIMAL(9,8),
			@KenoComm DECIMAL(9,8),
			@LotteryComm DECIMAL(9,8),
			@VSComm DECIMAL(9,8),
			@TableGameComm DECIMAL(9,8),
			-- phase 3
			@VirtualGamesComm DECIMAL(9,8) = 0,
			@ArcadiaGamingComm DECIMAL(9,8) = 0,
			@SabaclubComm DECIMAL(9,8) = 0,
			@SAGamingComm DECIMAL(9,8) = 0,
			@PGSoftComm DECIMAL(9,8) = 0,
			-->phase 4
			@WMCasinoComm		DECIMAL(9,8) = 0,
			@BigGamingComm		DECIMAL(9,8) = 0,
			@JokerComm			DECIMAL(9,8) = 0,
			@HabaneroComm		DECIMAL(9,8) = 0,
			@VGamingComm		DECIMAL(9,8) = 0,
			-- phase 4.2
			@CGComm				DECIMAL(9,8) = 0,
			@AdvantComm			DECIMAL(9,8) = 0,
			@AdvantMiniComm		DECIMAL(9,8) = 0,
			
			@MaxGameComm		DECIMAL(9,8) = 0,
			@FGGComm			DECIMAL(9,8) = 0,
			@JiliComm			DECIMAL(9,8) = 0,

			@YeeBetComm			DECIMAL(9,8) = 0,
			@MgRNGComm			DECIMAL(9,8) = 0,

			@CustID INT, 
			@i INT	
	
	SELECT @strCustIDOriginal = ltrim(rtrim(@strCustIDOriginal))
	
	IF @strCustIDOriginal = ''
	BEGIN
		SELECT @ErrMsg = CASE @Langkey WHEN 'en-US' THEN 'Wrong input, please check again!'
				ELSE CustDB.[dbo].[Lrf_f_Get_MsgNamebyMsgID](200003,@Langkey)
				END
				,@ErrCode = 100
		RETURN
	END
	
	DECLARE @TempCustID  AS TABLE (ID int IDENTITY(1,1),CustID INT)
	INSERT INTO @TempCustID (CustID)
	SELECT cs.CustID 
	FROM dbo.LicenseeCustComm cs WITH (NOLOCK) 
		INNER JOIN STRING_SPLIT(@strCustIDOriginal,',') AS t ON RTRIM(LTRIM(t.value)) = cs.CustID
	WHERE LicenseeID = @LicenseeID 
			AND GroupCommID > 0
	OPTION (MAXRECURSION 0)
	
	IF NOT EXISTS(SELECT TOP 1 1 FROM @TempCustID)
	BEGIN
		SELECT @ErrMsg= CASE @Langkey WHEN 'en-US' THEN 'Selected customer(s) do not belong to any group.'
									  ELSE CustDB.[dbo].[Lrf_f_Get_MsgNamebyMsgID](200004,@Langkey)
									  END
				,@ErrCode = 100					  			
		RETURN	
	END
	
	IF @IsRemovePlayercomm=0
	BEGIN
		UPDATE dbo.LicenseeCustComm WITH (ROWLOCK,UPDLOCK) 
		SET GroupCommID=0
		WHERE LicenseeID = @LicenseeID 
			AND CustID IN (SELECT CustID FROM @TempCustID)
	END
	ELSE IF @IsRemovePlayercomm=1
	BEGIN
		DECLARE @DiscountSettings VARCHAR(MAX) = ''
		DECLARE @tblSettingDCS AS TABLE (IsUpdate BIT,sporttype SMALLINT,Bettype SMALLINT)
		DECLARE @IsUpdate BIT = 1
		
		INSERT INTO @tblSettingDCS (IsUpdate,sporttype,Bettype)
		VALUES (@IsUpdate, 212,4001)
			, (@IsUpdate,248,4101)
			-- phase 2
			,(@IsUpdate,243,3101)
			,(@IsUpdate ,247,4301)
			,(@IsUpdate ,220,1021)
			,(@IsUpdate ,9908,1201)
			,(@IsUpdate ,222,4901)
			-- Phase 3
			,(@IsUpdate,245,4601)
			,(@IsUpdate,165,1901)
			,(@IsUpdate,200,1611)
			,(@IsUpdate,244,3001)
			,(@IsUpdate,232,6001)
			,(@IsUpdate,211,2401)
			--Saba Casino
			,(@IsUpdate,208,2101)
			--> phase 4
			,(@IsUpdate,233,3401)
			,(@IsUpdate,239,3501)
			,(@IsUpdate,234,6401)
			,(@IsUpdate,238,7001)
			,(@IsUpdate,171,3801)				
			-- Phase 4.2
			,(@IsUpdate,167,7301)
			,(@IsUpdate,172,7701)
			,(@IsUpdate,174,7801)
			
			,(@IsUpdate,237,5401)
			,(@IsUpdate,176,8201)
			,(@IsUpdate,158,5100)

			,(@IsUpdate,159,3151)
			,(@IsUpdate,155,8400)

			--
			,(@IsUpdate,1,1)
			,(@IsUpdate,1,4)
			,(@IsUpdate,1,5)
			,(@IsUpdate,2,2)
			,(@IsUpdate,1,9)
			,(@IsUpdate,161,81)
			,(@IsUpdate,202,1501)
	
		SELECT @DiscountSettings = (
			SELECT SportType, BetType, 0 Discount
			FROM @tblSettingDCS			
			FOR XML PATH('r'), ROOT('Root')
		)		
			
		--Update List of affected Customers               
		EXEC [Lrf_CustomerUpdMemberComm] 
			@LicenseeID=@LicenseeID,
			@strCustID=@strCustIDOriginal,
			@UserID=@UserID,
			@GroupCommID=0,
			
			@GroupDiscountID=0,
			@DiscountSettings = @DiscountSettings,
			
			@IP=@IP,
			@Langkey=@Langkey,
			@ErrCode=@ErrCode OUTPUT,
			@ErrMsg=@ErrMsg OUTPUT
		
		IF @ErrCode<>0
			RETURN
		
		--Update players out of LicenseeCustComm GroupCommID
		UPDATE LicenseeCustComm WITH (ROWLOCK,UPDLOCK)
		SET GroupCommID = 0
		WHERE LicenseeID = @LicenseeID 
		AND CustID IN (SELECT CustID FROM @TempCustID)
	END
END
GO
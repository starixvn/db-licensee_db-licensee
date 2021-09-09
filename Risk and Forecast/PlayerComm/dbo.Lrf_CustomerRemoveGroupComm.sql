/*<info serverAlias="DBCUST-bodb_Licensee" executers="bodbLicenseeNet" viewers="" isFunction="0"></info>*/
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
			@GDComm DECIMAL(9,8),
			@AGComm DECIMAL(9,8),
			@FWComm DECIMAL(9,8),
			--phase 2
			@SexyGamingComm DECIMAL(9,8),
			@SpadeGamingComm DECIMAL(9,8),
			@KenoComm DECIMAL(9,8),
			@LotteryComm DECIMAL(9,8),
			@VSComm DECIMAL(9,8),
			@VS2Comm DECIMAL(9,8),
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
			@GDGComm			DECIMAL(9,8) = 0,
			@SportsLotteryComm	DECIMAL(9,8) = 0,
			@HabaneroComm		DECIMAL(9,8) = 0,
			@VGamingComm		DECIMAL(9,8) = 0,
			
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
		INNER JOIN dbo.f_SplitString(@strCustIDOriginal,',') AS t ON RTRIM(LTRIM(t.val)) = cs.CustID
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
		SELECT @i = 0
		WHILE (@i<(SELECT MAX(ID) FROM @TempCustID))
		BEGIN
			SET @i = @i + 1
			SELECT @CustID = CustID FROM @TempCustID WHERE ID=@i
			--Get current setting
			SELECT @SBComm=SBComm,
				@NGComm=NGComm,
				@RNGComm=RNGComm,
				@ParlayComm = ParlayComm,
				@AllbetComm=AllbetComm,				
				@MacauComm=MacauComm,
				@PPComm=PPComm,
				--@GDComm=GDComm,
				--@AGComm=AGComm
				@FWComm = FWComm,
				@SexyGamingComm = SexyGamingComm ,
				@SpadeGamingComm = SpadeGamingComm,
				@KenoComm = KenoComm,
				@LotteryComm = LotteryComm,
				@VSComm = VSComm,
				@VS2Comm = VS2Comm,
				@TableGameComm = TableGameComm,
				@VirtualGamesComm  = VirtualGamesComm,
				@ArcadiaGamingComm  = ArcadiaGamingComm,
				@SabaclubComm  = SabaclubComm,
				@SAGamingComm  = SAGamingComm,
				@PGSoftComm  = PGSoftComm,
				--Phase 4
				@WMCasinoComm		= WMCasinoComm,
				@BigGamingComm		= BigGamingComm,
				@JokerComm			= JokerComm,
				@GDGComm			= GDGComm,
				@SportsLotteryComm	= SportsLotteryComm,
				@HabaneroComm		= HabaneroComm,
				@VGamingComm		= VGamingComm
			FROM dbo.LicenseeCustComm WITH (NOLOCK)
			WHERE LicenseeID = @LicenseeID AND CustID = @CustID
					
			--Update List of affected Customers               
			EXEC [Lrf_CustomerUpdMemberComm] 
				@LicenseeID=@LicenseeID,
				@strCustID=@CustID,
				@UserID=@UserID,
				@IsUpdateComm=0,
				@GroupCommID=0,
				@SBComm=@SBComm,
				@NGComm=@NGComm,
				@RNGComm=@RNGComm,
				@ParlayComm = @ParlayComm,	
				@AllbetComm=@AllbetComm,
				@MacauComm=@MacauComm,
				@PPComm=@PPComm,
				--@GDComm=@GDComm,
				--@AGComm=@AGComm,
				@FWComm = @FWComm,
				@IsUpdateNG=1,
				@IsUpdateRNG=1,			
				@IsUpdateAllbet=1,
				@IsUpdateMacau=1,
				@IsUpdatePP=1,
				--@IsUpdateGD=1,
				--@IsUpdateAG=1,
				@IsUpdateFW=1,
				---start param of phase 2
				@IsUpdateSexyGaming = 1,	
				@SexyGamingComm = @SexyGamingComm,
				@IsUpdateSpadeGaming = 1,	
				@SpadeGamingComm = @SpadeGamingComm,
				@IsUpdateKeno = 1,
				@KenoComm = @KenoComm,
				@IsUpdateLottery = 1,	
				@LotteryComm = @LotteryComm,
				@IsUpdateVS = 1,
				@VSComm = @VSComm,
				@IsUpdateVS2 = 1,	
				@VS2Comm = @VS2Comm, 
				@IsUpdateTableGame = 1,
				@TableGameComm = @TableGameComm,
				-- phase 3
				@IsUpdateVirtualGames = 1,
				@IsUpdateArcadiaGaming = 1,
				@IsUpdateSabaclub  = 1,
				@IsUpdateSAGaming  = 1,
				@IsUpdatePGSoft  = 1,
				@VirtualGamesComm = @VirtualGamesComm,
				@ArcadiaGamingComm = @ArcadiaGamingComm,
				@SabaclubComm = @SabaclubComm,
				@SAGamingComm = @SAGamingComm,
				@PGSoftComm = @PGSoftComm,
				--> phase 4
				@IsUpdateWMCasino		= 1,		
				@IsUpdateBigGaming		= 1,		
				@IsUpdateJoker			= 1,			
				@IsUpdateGDG			= 1,			
				@IsUpdateSportsLottery	= 1,
				@IsUpdateHabanero		= 1,
				@IsUpdateVGaming		= 1,				
				@WMCasinoComm				= @WMCasinoComm	,	
				@BigGamingComm				= @BigGamingComm,		
				@JokerComm					= @JokerComm,			
				@GDGComm					= @GDGComm,			
				@SportsLotteryComm			= @SportsLotteryComm,	
				@HabaneroComm				= @HabaneroComm,
				@VGamingComm				= @VGamingComm,		
				
				@IP=@IP,
				@Langkey=@Langkey,
				@ErrCode=@ErrCode OUTPUT,
				@ErrMsg=@ErrMsg OUTPUT	
				
			IF @ErrCode<>0
			RETURN
		END
		
		UPDATE dbo.LicenseeCustComm WITH (ROWLOCK,UPDLOCK) 
		SET GroupCommID=0
		WHERE LicenseeID = @LicenseeID 
			AND CustID IN (SELECT CustID FROM @TempCustID)
	END
	ELSE IF @IsRemovePlayercomm=1
	BEGIN
		--Update List of affected Customers               
		EXEC [Lrf_CustomerUpdMemberComm] 
			@LicenseeID=@LicenseeID,
			@strCustID=@strCustIDOriginal,
			@UserID=@UserID,
			@GroupCommID=0,
			@SBComm=0,
			@NGComm=0,
			@RNGComm=0,
			@ParlayComm = 0,
			@AllbetComm= 0,
			@MacauComm= 0,
			@PPComm= 0,
			--@GDComm= 0,
			--@AGComm= 0,
			@FWComm= 0,
			@IsUpdateNG=1,
			@IsUpdateRNG=1,	
			@IsUpdateAllbet=1,
			@IsUpdateMacau=1,
			@IsUpdatePP=1,
			--@IsUpdateGD=1,
			--@IsUpdateAG=1,	
			@IsUpdateFW=1,
			---start param of phase 2
			@IsUpdateSexyGaming = 1,	
			@SexyGamingComm = 0,
			@IsUpdateSpadeGaming = 1,	
			@SpadeGamingComm = 0,
			@IsUpdateKeno = 1,
			@KenoComm = 0,
			@IsUpdateLottery = 1,	
			@LotteryComm = 0,
			@IsUpdateVS = 1,
			@VSComm = 0,
			@IsUpdateVS2 = 1,	
			@VS2Comm = 0, 
			@IsUpdateTableGame = 1,
			@TableGameComm = 0,
			
			-- phase 3
			@IsUpdateVirtualGames = 1,
			@IsUpdateArcadiaGaming = 1,
			@IsUpdateSabaclub  = 1,
			@IsUpdateSAGaming  = 1,
			@IsUpdatePGSoft  = 1,
			@VirtualGamesComm = 0,
			@ArcadiaGamingComm = 0,
			@SabaclubComm = 0,
			@SAGamingComm = 0,
			@PGSoftComm = 0,
			--> phase 4
			@IsUpdateWMCasino		= 1,		
			@IsUpdateBigGaming		= 1,		
			@IsUpdateJoker			= 1,			
			@IsUpdateGDG			= 1,			
			@IsUpdateSportsLottery	= 1,
			@IsUpdateHabanero		= 1,
			@IsUpdateVGaming		= 1,			
			@WMCasinoComm				= 0	,	
			@BigGamingComm				= 0,		
			@JokerComm					= 0,			
			@GDGComm					= 0,			
			@SportsLotteryComm			= 0,	
			@HabaneroComm				= 0,
			@VGamingComm				= 0,			

			@IP=@IP,
			@Langkey=@Langkey,
			@ErrCode=@ErrCode OUTPUT,
			@ErrMsg=@ErrMsg OUTPUT
		
		IF @ErrCode<>0
			RETURN
		
		--Update players out of LicenseeCustComm GroupCommID
		UPDATE LicenseeCustComm WITH (ROWLOCK,UPDLOCK)
		SET 
			SBComm = 0,
			ParlayComm = 0,
			NGComm = 0,
			RNGComm = 0,
			AllbetComm= 0,
			MacauComm= 0,
			PPComm= 0,
			--GDComm= 0,
			--AGComm= 0,
			FWComm = 0,
			-- phase 2
			SexyGamingComm = 0 ,
			SpadeGamingComm = 0,
			KenoComm = 0,
			LotteryComm = 0,
			VSComm = 0,
			VS2Comm = 0,
			TableGameComm = 0,
			--phase 3
			VirtualGamesComm = 0,	
			ArcadiaGamingComm = 0,	
			SabaclubComm = 0,	
			SAGamingComm = 0,	
			PGSoftComm = 0,
			-->phase 4
			WMCasinoComm		= 0	,	
			BigGamingComm		= 0,		
			JokerComm			= 0,			
			GDGComm				= 0,			
			SportsLotteryComm	= 0,	
			HabaneroComm		= 0,
			VGamingComm			= 0,

			GroupCommID = 0
		WHERE LicenseeID = @LicenseeID 
		AND CustID IN (SELECT CustID FROM @TempCustID)
	END
		
	SELECT @StrCustID = STUFF(
                    (   SELECT  ',' + CONVERT(NVARCHAR(20), b.CustID) 
                        FROM  @TempCustID b  
						INNER JOIN CustDB.dbo.custinfo a WITH (NOLOCK) ON a.custid = b.CustID
						WHERE a.SyncCasino = 1
                        FOR xml path('')
                    )
                    , 1
                    , 1
                    , '')
END
GO
/*<info serverAlias="DBCUST-bodb_Licensee" executers="bodbLicenseeNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_LicenseeCustCommUpd]
	@LicenseeID INT,
	@strCustIDOriginal VARCHAR(MAX),--member
	@strCustID VARCHAR(MAX)  OUTPUT,--member
	@UserID INT,
	@SBComm DECIMAL(9,8),
	@ParlayComm DECIMAL(9,8),
	@NGComm DECIMAL(9,8) = 0,	
	@RNGComm DECIMAL(9,8) = 0,
	@AllbetComm DECIMAL(9,8) = 0,
	@MacauComm DECIMAL(9,8) = 0,
	@PPComm DECIMAL(9,8) = 0,
	--@GDComm DECIMAL(9,8) = 0,
	--@AGComm DECIMAL(9,8) = 0,
	@IsUpdateNG BIT = 0,
	@IsUpdateRNG BIT = 0,
	@IsUpdateAllbet BIT = 0,
	@IsUpdateMacau BIT = 0,
	@IsUpdatePP BIT = 0,
	--@IsUpdateGD BIT = 0,
	--@IsUpdateAG BIT = 0,
	--start param of phase 2 
	@IsUpdateSexyGaming BIT = 0,	
	@SexyGamingComm DECIMAL(9,8) = 0,
	@IsUpdateSpadeGaming BIT = 0,	
	@SpadeGamingComm DECIMAL(9,8) = 0,
	@IsUpdateKeno BIT = 0,	
	@KenoComm DECIMAL(9,8) = 0,
	@IsUpdateLottery BIT = 0,	
	@LotteryComm DECIMAL(9,8) = 0,
	@IsUpdateVS BIT = 0,	
	@VSComm DECIMAL(9,8) = 0,
	@IsUpdateVS2 BIT = 0,	
	@VS2Comm DECIMAL(9,8) = 0,
	@IsUpdateTableGame BIT = 0,	
	@TableGameComm DECIMAL(9,8) = 0,
	-- end of phase 2
	-- phase 3
	@IsUpdateVirtualGames BIT = 0 ,
	@IsUpdateArcadiaGaming BIT = 0,
	@IsUpdateSabaclub BIT = 0,
	@IsUpdateSAGaming BIT = 0,
	@IsUpdatePGSoft BIT = 0,
	@VirtualGamesComm DECIMAL(9,8) = 0,
	@ArcadiaGamingComm DECIMAL(9,8) = 0,
	@SabaclubComm DECIMAL(9,8) = 0,
	@SAGamingComm DECIMAL(9,8) = 0,
	@PGSoftComm DECIMAL(9,8) = 0,
	-->phase 4
	@IsUpdateWMCasino		BIT = 0,
	@IsUpdateBigGaming		BIT = 0,
	@IsUpdateJoker			BIT = 0,
	@IsUpdateHabanero		BIT = 0,
	@IsUpdateVGaming		BIT = 0,
	-- phase 4.2
	@IsUpdateCG				BIT = 0,
	@IsUpdateAdvant			BIT = 0,
	@IsUpdateAdvantMini		BIT = 0,
	@IsUpdateVS3			BIT = 0,
	@WMCasinoComm		DECIMAL(9,8) = 0,
	@BigGamingComm		DECIMAL(9,8) = 0,
	@JokerComm			DECIMAL(9,8) = 0,
	@HabaneroComm		DECIMAL(9,8) = 0,
	@VGamingComm		DECIMAL(9,8) = 0,
	@CGComm				DECIMAL(9,8) = 0,
	@AdvantComm			DECIMAL(9,8) = 0,
	@AdvantMiniComm		DECIMAL(9,8) = 0,
	@VS3Comm			DECIMAL(9,8) = 0,

	@IP VARCHAR(40),
	@Langkey NVARCHAR(10)='en-US',
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg NVARCHAR(4000) = '' OUTPUT
AS
/*
	Created: 20120726@Henry
	Task : Update Commission of Player
	DB: DBCUST/bodb_Licensee

	Revisions:
		- 20130413@Jim: support multi language
		- 20131024@Hannah: offer Live Casino commission
		- 20131126@Hannah: offer RNG Casino commission
		- 20140116@Hannah: separate @strCustID INPUT and OUTPUT parameter
		- 20140612@Victor: fix VARCHAR(4000) issue
		- 20160805@Jim: LRF - Offer different member commission for parlay tickets [RedmineID:#61897]
		- 20171017@Johnson: offer Allbet commision [Redmine: #82036]
		- 20180228@Vicky: Remove LC from product list [Redmine: #85965]
		- 20180809@Amanda: Remove Racing [RedmineID: #99378]
		- 20180924@Elodie: Migrate bodb_Licensee to DBCUST [Redmine:#99855]
		- 20180927@Winnie: Remove AllBet [RedmineID: #99378]
		- 20181205@Winnie: LAP-Security Risks found_settings [RedmineID: #105701]
		- 20190417@Winnie: Customer Comm - Cannot move customer to selected group comm in case member have 'None' group [RedmineID: #111980]
		- 20200409@Johnson: Add comm for AB,Macau,PP,GD,AG [redmine:#131774]
		- 20200511@Max: Add comm for FW, Remove AG, GD - [Redmine: #131774]
		- 20200518@Helen: Add comm for FW, Remove AG, GD - Tuning performance - [Redmine: #131774]
		- 20200701@Helen: Remove Allbet - [Redmine: #131774]   
		- 20200814@Helen: LAP - Offer commission to 3rd party products - Phase 2 [Redmine: #139238]   
		- 20201111@Helen: LAP - Offer commission to 3rd party products - Phase 3 - [Redmine: #145012]   
		- 20210603@Eden: LAP - Support commission for 3rd party products - Phase 4 [Redmine: #154048]
		- 20210823@Johnson: Add VGaming [redmine: #159696]
		- 20211101@Winfred: Merge Sports Lottery under Sportsbook when turn on BA [redmine:#163191]
		- 20220112@Eden: LAP - RNG Casino - Implement DCS Settings [Redmine: #166217] 
		- 20220422@Winfred: LAP - Support commission for 3rd party products - Phase 4.2 [Redmine: #171586]  
		- 20220614@Eden: DBCUST - modify sp syntax to adapt with the SQL Server upgrade to 2019 [Redmine: #171831] 
		- 20221201@Tacy: Non-sports products - Remove GDG and Fishing World [RedmineID: #174511]

	Param's Explanation:
*/ 
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #tempCust (CustID INT)
	
	INSERT INTO #tempCust(CustID)
	SELECT RTRIM(LTRIM(value)) 
	FROM STRING_SPLIT(@strCustIDOriginal,',')
	WHERE value <> ''
		
	CREATE TABLE #tempAgent (CustID INT PRIMARY KEY)
	INSERT INTO #tempAgent(CustID)
	SELECT DISTINCT recommend
	FROM CustDB.dbo.Customer c WITH(NOLOCK) 
		INNER JOIN #tempCust t ON c.custid=t.CustID

	IF EXISTS(	
		SELECT 1
		FROM #tempAgent t
			LEFT JOIN LicenseeCust b WITH (NOLOCK) ON t.CustID=b.CustID AND b.LicenseeID=@LicenseeID
		WHERE b.CustID IS NULL)
	BEGIN
		SELECT @ErrCode=100
		SELECT @ErrMsg='Customer does not belong to licensee'
		RETURN 
	END

	DECLARE @TempCustID  AS TABLE (ID int IDENTITY(1,1),CustID INT)

	INSERT INTO @TempCustID (CustID)
	SELECT cs.CustID 
	FROM dbo.LicenseeCustComm cs WITH (NOLOCK) 
		INNER JOIN #tempCust t ON cs.CustID = t.CustID
	WHERE LicenseeID = @LicenseeID 

	EXEC [Lrf_CustomerUpdMemberComm] 
		@LicenseeID=@LicenseeID
		,@strCustID=@strCustIDOriginal
		,@UserID=@UserID
		,@SBComm=@SBComm
		,@ParlayComm = @ParlayComm
		,@NGComm=@NGComm
		,@RNGComm=@RNGComm	
		,@AllbetComm = @AllbetComm
		,@MacauComm = @MacauComm
		,@PPComm = @PPComm
		--,@GDComm = @GDComm
		--,@AGComm = @AGComm
		,@IsUpdateNG=@IsUpdateNG
		,@IsUpdateRNG=@IsUpdateRNG	
		,@IsUpdateAllbet=@IsUpdateAllbet
		,@IsUpdateMacau=@IsUpdateMacau
		,@IsUpdatePP=@IsUpdatePP
		--,@IsUpdateGD=@IsUpdateGD
		--,@IsUpdateAG=@IsUpdateAG
		---start param of phase 2
		,@IsUpdateSexyGaming = @IsUpdateSexyGaming	
		,@SexyGamingComm = @SexyGamingComm
		,@IsUpdateSpadeGaming = @IsUpdateSpadeGaming	
		,@SpadeGamingComm =  @SpadeGamingComm
		,@IsUpdateKeno = @IsUpdateKeno
		,@KenoComm =  @KenoComm
		,@IsUpdateLottery  = @IsUpdateLottery	
		,@LotteryComm =  @LotteryComm
		,@IsUpdateVS = @IsUpdateVS 	
		,@VSComm =  @VSComm
		,@IsUpdateVS2 =  @IsUpdateVS2	
		,@VS2Comm = @VS2Comm 
		,@IsUpdateTableGame = @IsUpdateTableGame
		,@TableGameComm = @TableGameComm
		---end of phase 2
		-- phase 3
		,@IsUpdateVirtualGames = @IsUpdateVirtualGames
		,@IsUpdateArcadiaGaming = @IsUpdateArcadiaGaming
		,@IsUpdateSabaclub  = @IsUpdateSabaclub
		,@IsUpdateSAGaming  = @IsUpdateSAGaming
		,@IsUpdatePGSoft  = @IsUpdatePGSoft
		,@VirtualGamesComm = @VirtualGamesComm
		,@ArcadiaGamingComm = @ArcadiaGamingComm
		,@SabaclubComm = @SabaclubComm
		,@SAGamingComm = @SAGamingComm
		,@PGSoftComm = @PGSoftComm
		--> phase 4
		,@IsUpdateWMCasino		= @IsUpdateWMCasino		
		,@IsUpdateBigGaming		= @IsUpdateBigGaming		
		,@IsUpdateJoker			= @IsUpdateJoker			
		,@IsUpdateHabanero		= @IsUpdateHabanero		
		,@IsUpdateVGaming		= @IsUpdateVGaming	
		-- phase 4.2
		,@IsUpdateCG			= @IsUpdateCG		
		,@IsUpdateAdvant		= @IsUpdateAdvant		
		,@IsUpdateAdvantMini	= @IsUpdateAdvantMini		
		,@IsUpdateVS3			= @IsUpdateVS3		
		,@WMCasinoComm				= @WMCasinoComm		
		,@BigGamingComm				= @BigGamingComm		
		,@JokerComm					= @JokerComm			
		,@HabaneroComm				= @HabaneroComm	
		,@VGamingComm				= @VGamingComm	
		,@CGComm					= @CGComm	
		,@AdvantComm				= @AdvantComm	
		,@AdvantMiniComm			= @AdvantMiniComm	
		,@VS3Comm					= @VS3Comm	

		,@IP=@IP
		,@Langkey=@Langkey
		,@ErrCode=@ErrCode OUTPUT
		,@ErrMsg=@ErrMsg OUTPUT

	UPDATE cs
		SET GroupCommID=0
	FROM dbo.LicenseeCustComm cs WITH (ROWLOCK,UPDLOCK)
		INNER JOIN @TempCustID t ON cs.CustID = t.CustID
	WHERE LicenseeID = @LicenseeID 
END	
GO